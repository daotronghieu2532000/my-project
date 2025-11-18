<?php
/**
 * Cron Job: Gửi thông báo affiliate hàng ngày
 * 
 * Chạy mỗi 24h: php notification_cron_affiliate_daily.php
 * 
 * Mục đích: 
 * - Gửi sản phẩm affiliate có hoa hồng cao nhất
 * - Gửi sản phẩm affiliate được bán nhiều nhất
 */

// Load config.php - thử nhiều đường dẫn
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
    $config_path = __DIR__ . '/../../../../../includes/config.php';
}
if (!file_exists($config_path)) {
    $config_path = __DIR__ . '/includes/config.php';
}
require_once $config_path;

require_once __DIR__ . '/notification_mobile_helper.php';

$logPath = __DIR__ . '/debug_push_notifications.log';
$currentTime = time();

// Log bắt đầu chạy script
file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ========== STARTING ==========\n", FILE_APPEND);
file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] Current time: $currentTime (" . date('Y-m-d H:i:s', $currentTime) . ")\n", FILE_APPEND);

// ========================================
// 1. SẢN PHẨM AFFILIATE CÓ HOA HỒNG CAO NHẤT
// ========================================
// Logic: Parse JSON sub_product từ sanpham_aff để tìm max hoa_hong
// Format sub_product: {"product_id": [{"variant_id": "main", "loai": "phantram", "hoa_hong": 10}, ...]}
$query = "SELECT sa.id, sa.tieu_de, sa.shop, sa.date_start, sa.date_end, sa.sub_product
          FROM sanpham_aff sa
          WHERE sa.date_start <= $currentTime
          AND sa.date_end >= $currentTime
          AND sa.sub_product IS NOT NULL
          AND sa.sub_product != ''
          ORDER BY sa.date_post DESC";

$result = mysqli_query($conn, $query);

if (!$result) {
    file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ❌ Query failed: " . mysqli_error($conn) . "\n", FILE_APPEND);
} else {
    $row_count = mysqli_num_rows($result);
    file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] Found $row_count affiliate products to check for highest commission\n", FILE_APPEND);
    $max_commission = 0;
    $best_aff = null;
    
    while ($row = mysqli_fetch_assoc($result)) {
        $sub_product = json_decode($row['sub_product'], true);
        if (!$sub_product || !is_array($sub_product)) {
            continue;
        }
        
        // Tìm max hoa_hong trong tất cả sản phẩm và variant
        foreach ($sub_product as $product_id => $variants) {
            if (!is_array($variants)) {
                continue;
            }
            
            foreach ($variants as $variant) {
                if (!is_array($variant)) {
                    continue;
                }
                
                $hoa_hong = 0;
                if (isset($variant['hoa_hong'])) {
                    $hoa_hong = floatval($variant['hoa_hong']);
                }
                
                // Nếu loai là "phantram", cần tính theo % của giá
                if (isset($variant['loai']) && $variant['loai'] == 'phantram' && $hoa_hong > 0) {
                    // Lấy giá sản phẩm để tính hoa hồng
                    $sp_id = intval($product_id);
                    $price_query = "SELECT gia_moi FROM sanpham WHERE id = $sp_id LIMIT 1";
                    $price_result = mysqli_query($conn, $price_query);
                    if ($price_result && $price_row = mysqli_fetch_assoc($price_result)) {
                        $price = intval($price_row['gia_moi']);
                        $hoa_hong = ($price * $hoa_hong) / 100; // Tính % thành số tiền
                    }
                }
                
                if ($hoa_hong > $max_commission) {
                    $max_commission = $hoa_hong;
                    $best_aff = $row;
                }
            }
        }
    }
    
    if ($best_aff && $max_commission > 0) {
        $aff_id = intval($best_aff['id']);
        $product_title = $best_aff['tieu_de'];
        $shop_id = intval($best_aff['shop']);
        
        // Lấy product_id đầu tiên từ sub_product để navigate đến product detail
        $first_product_id = null;
        $sub_product = json_decode($best_aff['sub_product'], true);
        if ($sub_product && is_array($sub_product)) {
            foreach ($sub_product as $product_id => $variants) {
                if (is_numeric($product_id)) {
                    $first_product_id = intval($product_id);
                    break; // Lấy product_id đầu tiên
                }
            }
        }
        
        $title = "Sản phẩm Affiliate Hot: $product_title";
        $content = "Sản phẩm \"$product_title\" đang có hoa hồng cao nhất với mức hưởng lợi hấp dẫn lên đến " . number_format($max_commission, 0, ',', '.') . "₫. Đây là cơ hội vàng để bạn kiếm thêm thu nhập! Hãy chia sẻ ngay và bắt đầu kiếm tiền thôi nào!";
        
        $data = json_encode(array(
            'product_title' => $product_title,
            'shop_id' => $shop_id,
            'max_commission' => $max_commission,
            'affiliate_id' => $aff_id,
            'product_id' => $first_product_id, // Thêm product_id để navigate
            'notification_type' => 'affiliate_highest_commission'
        ));
        
        // Insert notification cho TẤT CẢ user có device_token ACTIVE VÀ user_id hợp lệ trong user_info (CHỈ GỬI CHO USER THỰC TẾ DÙNG APP)
        $insertQuery = "INSERT INTO notification_mobile (
            user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
        )
        SELECT DISTINCT
            dt.user_id,
            'affiliate_daily',
            '" . mysqli_real_escape_string($conn, $title) . "',
            '" . mysqli_real_escape_string($conn, $content) . "',
            '" . mysqli_real_escape_string($conn, $data) . "',
            $aff_id,
            'affiliate_product',
            'high',
            0,
            0,
            $currentTime
        FROM device_tokens dt
        INNER JOIN user_info u ON dt.user_id = u.user_id
        WHERE dt.is_active = 1
        AND dt.user_id > 0
        AND u.active = 1
        AND (dt.last_used_at IS NULL OR dt.last_used_at >= ($currentTime - 90*24*3600))";
        // ✅ Điều kiện:
        // - device_token active (is_active = 1)
        // - user_id > 0 (không phải unregistered user)
        // - user_id tồn tại trong user_info (JOIN để tránh FK constraint error)
        // - user active = 1 (tài khoản hoạt động)
        // - last_used_at trong vòng 90 ngày qua (hoặc NULL - token mới) để tránh gửi cho token cũ không dùng nữa
        
        file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] Executing insert query for highest commission product: $product_title\n", FILE_APPEND);
        if (mysqli_query($conn, $insertQuery)) {
            $affected = mysqli_affected_rows($conn);
            file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ✅ Created $affected notifications for highest commission product: $product_title (max_commission: " . number_format($max_commission, 0, ',', '.') . "₫)\n", FILE_APPEND);
        } else {
            file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ❌ Failed to create notifications: " . mysqli_error($conn) . "\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] Query: " . substr($insertQuery, 0, 500) . "...\n", FILE_APPEND);
        }
    } else {
        file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ⚠️ No affiliate products with commission found\n", FILE_APPEND);
    }
}

// ========================================
// 2. SẢN PHẨM AFFILIATE ĐƯỢC BÁN NHIỀU NHẤT
// ========================================
// Logic: Tìm đơn hàng có affiliate (utm_source) trong 24h qua, đếm số đơn hàng theo sản phẩm
// Format donhang.sanpham: JSON array [{"id": 123, "hoa_hong": 5000}, ...] hoặc {"123_456": {"id": 123, ...}}
$query2 = "SELECT sa.id, sa.tieu_de, sa.shop, sa.date_start, sa.date_end, sa.main_product
           FROM sanpham_aff sa
           WHERE sa.date_start <= $currentTime
           AND sa.date_end >= $currentTime
           ORDER BY sa.date_post DESC";

$result2 = mysqli_query($conn, $query2);

if (!$result2) {
    file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ❌ Query 2 failed: " . mysqli_error($conn) . "\n", FILE_APPEND);
} else {
    $row_count2 = mysqli_num_rows($result2);
    file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] Found $row_count2 affiliate products to check for best seller\n", FILE_APPEND);
    $best_seller = null;
    $max_orders = 0;
    
    while ($aff_row = mysqli_fetch_assoc($result2)) {
        // Parse main_product (CSV string) thành array of integers
        $main_products_raw = explode(',', $aff_row['main_product']);
        $main_products = array_map('intval', array_filter($main_products_raw));
        $total_orders = 0;
        
        // Lấy tất cả đơn hàng affiliate trong 24h qua (status = 5: Giao thành công)
        // Theo orders_list.php: status 3 = "Yêu cầu hủy đơn", status 5 = "Giao thành công"
        $orders_query = "SELECT id, sanpham, utm_source 
                        FROM donhang 
                        WHERE status = 5 
                        AND date_post >= ($currentTime - 86400)
                        AND utm_source IS NOT NULL 
                        AND utm_source != '' 
                        AND utm_source != '0'";
        
        $orders_result = mysqli_query($conn, $orders_query);
        
        if ($orders_result) {
            while ($order = mysqli_fetch_assoc($orders_result)) {
                $sanpham = json_decode($order['sanpham'], true);
                if (!$sanpham || !is_array($sanpham)) {
                    continue;
                }
                
                // Kiểm tra đơn hàng có chứa sản phẩm affiliate này không
                $has_product = false;
                foreach ($sanpham as $key => $product) {
                    $sp_id = 0;
                    
                    // Parse sp_id từ nhiều format khác nhau (giống affiliate_orders.php)
                    if (is_string($key) && strpos($key, '_') !== false) {
                        $parts = explode('_', $key);
                        $sp_id = intval($parts[0]);
                    } elseif (isset($product['id'])) {
                        $sp_id = intval($product['id']);
                    } elseif (is_int($key) || ctype_digit($key)) {
                        $sp_id = intval($key);
                    } elseif (isset($product['sp_id'])) {
                        $sp_id = intval($product['sp_id']);
                    }
                    
                    // Kiểm tra sp_id có trong main_product của affiliate campaign không
                    if ($sp_id > 0 && in_array($sp_id, $main_products)) {
                        $has_product = true;
                        break;
                    }
                }
                
                if ($has_product) {
                    $total_orders++;
                }
            }
        }
        
        if ($total_orders > $max_orders) {
            $max_orders = $total_orders;
            $best_seller = $aff_row;
        }
    }
    
    if ($best_seller && $max_orders > 0) {
        $aff_id2 = intval($best_seller['id']);
        $product_title2 = $best_seller['tieu_de'];
        $shop_id2 = intval($best_seller['shop']);
        
        // Lấy product_id đầu tiên từ main_product để navigate đến product detail
        $first_product_id = null;
        $main_products_raw = explode(',', $best_seller['main_product']);
        $main_products = array_map('intval', array_filter($main_products_raw));
        if (!empty($main_products)) {
            $first_product_id = $main_products[0]; // Lấy product_id đầu tiên
        }
        
        $title2 = "Sản phẩm Affiliate Bán Chạy: $product_title2";
        $content2 = "Sản phẩm \"$product_title2\" đang là sản phẩm affiliate được bán chạy nhất với $max_orders đơn hàng thành công trong 24h qua. Nhiều người đã kiếm được thu nhập từ sản phẩm này - bạn cũng đừng bỏ lỡ cơ hội này nhé!";
        
        $data2 = json_encode(array(
            'product_title' => $product_title2,
            'shop_id' => $shop_id2,
            'total_orders' => $max_orders,
            'affiliate_id' => $aff_id2,
            'product_id' => $first_product_id, // Thêm product_id để navigate
            'notification_type' => 'affiliate_best_seller'
        ));
        
        // Insert notification cho TẤT CẢ user có device_token ACTIVE VÀ user_id hợp lệ trong user_info (CHỈ GỬI CHO USER THỰC TẾ DÙNG APP)
        $insertQuery2 = "INSERT INTO notification_mobile (
            user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
        )
        SELECT DISTINCT
            dt.user_id,
            'affiliate_daily',
            '" . mysqli_real_escape_string($conn, $title2) . "',
            '" . mysqli_real_escape_string($conn, $content2) . "',
            '" . mysqli_real_escape_string($conn, $data2) . "',
            $aff_id2,
            'affiliate_product',
            'high',
            0,
            0,
            $currentTime
        FROM device_tokens dt
        INNER JOIN user_info u ON dt.user_id = u.user_id
        WHERE dt.is_active = 1
        AND dt.user_id > 0
        AND u.active = 1
        AND (dt.last_used_at IS NULL OR dt.last_used_at >= ($currentTime - 90*24*3600))";
        // ✅ Điều kiện:
        // - device_token active (is_active = 1)
        // - user_id > 0 (không phải unregistered user)
        // - user_id tồn tại trong user_info (JOIN để tránh FK constraint error)
        // - user active = 1 (tài khoản hoạt động)
        // - last_used_at trong vòng 90 ngày qua (hoặc NULL - token mới) để tránh gửi cho token cũ không dùng nữa
        
        file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] Executing insert query for best seller product: $product_title2\n", FILE_APPEND);
        if (mysqli_query($conn, $insertQuery2)) {
            $affected2 = mysqli_affected_rows($conn);
            file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ✅ Created $affected2 notifications for best seller product: $product_title2 ($max_orders orders)\n", FILE_APPEND);
        } else {
            file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ❌ Failed to create notifications: " . mysqli_error($conn) . "\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] Query: " . substr($insertQuery2, 0, 500) . "...\n", FILE_APPEND);
        }
    } else {
        file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ⚠️ No affiliate orders found in last 24h\n", FILE_APPEND);
    }
}

file_put_contents($logPath, date('c') . " | [AFFILIATE_DAILY] ========== COMPLETED ==========\n", FILE_APPEND);

