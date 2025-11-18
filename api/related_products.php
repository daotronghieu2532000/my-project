<?php
/**
 * API: Related Products (Sản phẩm liên quan)
 * Method: GET
 * URL: /v1/related_products?product_id={id}&limit=15
 * 
 * Description: Lấy danh sách sản phẩm liên quan dựa trên:
 * - Cùng shop
 * - Cùng danh mục
 * - Cùng thương hiệu
 * - Khoảng giá tương đương (±30%)
 */

header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;

use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình JWT
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

// Helper function để tạo URL ảnh với CDN domain
// Sử dụng CDN: https://socdo.cdn.vccloud.vn/
// Fallback sẽ được xử lý ở phía Flutter app
function getImageUrlWithCDN($image_path) {
    if (empty($image_path)) return '';
    
    // Nếu đã là URL đầy đủ, trả về nguyên
    if (strpos($image_path, 'http://') === 0 || strpos($image_path, 'https://') === 0) {
        return $image_path;
    }
    
    // Loại bỏ dấu / ở đầu nếu có
    $image_path = ltrim($image_path, '/');
    
    // Sử dụng CDN domain cho ảnh
    return 'https://socdo.cdn.vccloud.vn/' . $image_path;
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get parameters
    $product_id = isset($_GET['product_id']) ? intval($_GET['product_id']) : 0;
    $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : 0;
    $limit = isset($_GET['limit']) ? max(1, min(50, intval($_GET['limit']))) : 45;
    $type = isset($_GET['type']) ? $_GET['type'] : 'auto'; // auto, same_shop, same_category, same_brand
    
    if ($product_id <= 0) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Product ID is required'
        ]);
        exit;
    }
    
    // Lấy thông tin sản phẩm gốc
    $product_query = "SELECT cat, thuong_hieu, gia_moi, shop FROM sanpham WHERE id = $product_id LIMIT 1";
    $product_result = mysqli_query($conn, $product_query);
    
    if (!$product_result || mysqli_num_rows($product_result) == 0) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Product not found'
        ]);
        exit;
    }
    
    $product_info = mysqli_fetch_assoc($product_result);
    $categories = $product_info['cat'];
    $brand = $product_info['thuong_hieu'];
    $price = $product_info['gia_moi'];
    
    if ($shop_id == 0) {
        $shop_id = $product_info['shop'];
    }
    
    // Tính khoảng giá ±30%
    $price_min = $price * 0.7;
    $price_max = $price * 1.3;
    
    // Xây dựng WHERE conditions
    // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
    //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
    $where_conditions = [
        "s.id != $product_id",
        "s.active = 0",
        "s.kho >= 0",
        "((NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = s.id) AND s.kho > 0) OR EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = s.id AND pl.kho_sanpham_socdo > 0))"
    ];
    
    // ORDER BY logic (ưu tiên giảm dần)
    $order_parts = [];
    
    switch ($type) {
        case 'same_shop':
            $where_conditions[] = "s.shop = $shop_id";
            $order_parts[] = "s.id DESC";
            break;
            
        case 'same_category':
            if (!empty($categories)) {
                $cat_array = explode(',', $categories);
                $cat_conditions = [];
                foreach ($cat_array as $cat) {
                    $cat_conditions[] = "FIND_IN_SET('$cat', s.cat) > 0";
                }
                $where_conditions[] = '(' . implode(' OR ', $cat_conditions) . ')';
            }
            $order_parts[] = "s.view DESC";
            $order_parts[] = "s.ban DESC";
            break;
            
        case 'same_brand':
            $where_conditions[] = "s.thuong_hieu = $brand";
            $order_parts[] = "s.view DESC";
            $order_parts[] = "s.ban DESC";
            break;
            
        case 'auto':
        default:
            // Logic ưu tiên: Cùng shop > Cùng brand + category > Cùng category + giá > Cùng brand
            $order_parts[] = "(s.shop = $shop_id) DESC";
            $order_parts[] = "(s.thuong_hieu = $brand AND FIND_IN_SET('$categories', s.cat) > 0) DESC";
            $order_parts[] = "(FIND_IN_SET('$categories', s.cat) > 0 AND s.gia_moi BETWEEN $price_min AND $price_max) DESC";
            $order_parts[] = "(s.thuong_hieu = $brand) DESC";
            $order_parts[] = "s.view DESC";
            $order_parts[] = "s.ban DESC";
            break;
    }
    
    $where_clause = "WHERE " . implode(" AND ", $where_conditions);
    $order_by = "ORDER BY " . implode(", ", $order_parts);
    
    // Xác định timeline flash sale
    $hientai = time();
    $now = new DateTime('now', new DateTimeZone('Asia/Ho_Chi_Minh'));
    $hour = (int) $now->format('H');
    
    if ($hour >= 0 && $hour < 9) {
        $timeline = "00:00";
    } elseif ($hour >= 9 && $hour < 16) {
        $timeline = "09:00";
    } else {
        $timeline = "16:00";
    }
    
    // Query sản phẩm liên quan
    // Sử dụng LEFT JOIN với product_rating_stats (đã có index) thay vì subquery để tối ưu performance
    $products_query = "
        SELECT 
            s.*,
            th.tieu_de as brand_name,
            th.anh_thuong_hieu as brand_logo,
            u.name as shop_name,
            t.ten_kho AS warehouse_name,
            tm.tieu_de AS province_name,
            COALESCE(prs.total_reviews, 0) AS total_reviews,
            COALESCE(prs.average_rating, 0) AS avg_rating
        FROM sanpham s
        LEFT JOIN thuong_hieu th ON th.id = s.thuong_hieu
        LEFT JOIN user_info u ON u.user_id = s.shop
        LEFT JOIN transport t ON s.kho_id = t.id
        LEFT JOIN tinh_moi tm ON t.province = tm.id
        LEFT JOIN product_rating_stats prs ON s.id = prs.product_id AND s.shop = prs.shop_id
        $where_clause
        $order_by
        LIMIT $limit
    ";
    
    $products_result = mysqli_query($conn, $products_query);
    
    if (!$products_result) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi truy vấn database: ' . mysqli_error($conn)
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Lấy giá flash sale
    $product_ids = [];
    mysqli_data_seek($products_result, 0);
    while ($row = mysqli_fetch_assoc($products_result)) {
        $product_ids[] = $row['id'];
    }
    
    $flash_prices = [];
    if (!empty($product_ids)) {
        $ids_string = implode(',', $product_ids);
        
        $flash_query = "
            SELECT d.sub_product, s.id AS product_id
            FROM deal d
            JOIN sanpham s ON FIND_IN_SET(s.id, d.main_product) > 0
            WHERE s.id IN ($ids_string)
            AND d.date_start <= '$hientai'
            AND d.date_end >= '$hientai'
            AND d.status = '2'
            AND (d.timeline = '$timeline' OR d.timeline = '0' OR d.timeline IS NULL)
            AND d.loai = 'flash_sale'
            GROUP BY s.id
        ";
        
        $flash_result = mysqli_query($conn, $flash_query);
        
        while ($flash = mysqli_fetch_assoc($flash_result)) {
            $pid = $flash['product_id'];
            $sub_product = json_decode($flash['sub_product'], true);
            $min_price = null;
            
            if (isset($sub_product[$pid]) && is_array($sub_product[$pid])) {
                foreach ($sub_product[$pid] as $variant) {
                    if (isset($variant['gia'])) {
                        $p = intval(str_replace(',', '', $variant['gia']));
                        if ($min_price === null || $p < $min_price) {
                            $min_price = $p;
                        }
                    }
                }
            }
            
            if ($min_price !== null) {
                $flash_prices[$pid] = $min_price;
            }
        }
    }
    
    $products = [];
    mysqli_data_seek($products_result, 0);
    
    while ($product = mysqli_fetch_assoc($products_result)) {
        $sp_id = $product['id'];
        
        // Lấy giá min/max từ phân loại
        $pl_query = "SELECT MIN(gia_moi) AS gia_moi_min, MAX(gia_cu) AS gia_cu_max 
                     FROM phanloai_sanpham WHERE sp_id = '$sp_id'";
        $pl_result = mysqli_query($conn, $pl_query);
        $pl_data = mysqli_fetch_assoc($pl_result);
        
        $gia_moi = $product['gia_moi'];
        $gia_cu = $product['gia_cu'];
        
        if ($pl_data && $pl_data['gia_moi_min'] > 0) {
            $gia_moi = $pl_data['gia_moi_min'];
            if ($pl_data['gia_cu_max'] > 0) {
                $gia_cu = $pl_data['gia_cu_max'];
            }
        }
        
        // Áp dụng giá flash sale nếu có
        $is_flash = false;
        if (isset($flash_prices[$sp_id])) {
            $gia_cu = $gia_moi;
            $gia_moi = $flash_prices[$sp_id];
            $is_flash = true;
        }
        
        // Tính % giảm giá
        $discount_percent = 0;
        if ($gia_cu > 0 && $gia_moi < $gia_cu) {
            $discount_percent = round((($gia_cu - $gia_moi) / $gia_cu) * 100);
        }
        
        // Kiểm tra voucher và freeship theo logic chuẩn
        $current_time = time();
        $deal_shop = $product['shop'];
        
        // Check voucher - Logic chuẩn với hệ thống
        $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('$sp_id', sanpham) AND shop = '$deal_shop' AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
        $voucher_icon = '';
        if (mysqli_num_rows($check_coupon) > 0) {
            $voucher_icon = 'Voucher';
        } else {
            $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
            if (mysqli_num_rows($check_coupon_all) > 0) {
                $voucher_icon = 'Voucher';
            }
        }
        
        // Check freeship - Logic chuẩn với 4 mode
        $freeship_query = "SELECT free_ship_all, free_ship_discount, free_ship_min_order, fee_ship_products FROM transport WHERE user_id = '$deal_shop' AND (free_ship_all > 0 OR free_ship_discount > 0) LIMIT 1";
        $freeship_result = mysqli_query($conn, $freeship_query);
        $has_free_ship = false;
        $freeship_label = '';
        
        if ($freeship_result && mysqli_num_rows($freeship_result) > 0) {
            $freeship_data = mysqli_fetch_assoc($freeship_result);
            $mode = intval($freeship_data['free_ship_all'] ?? 0);
            $discount = intval($freeship_data['free_ship_discount'] ?? 0);
            $minOrder = intval($freeship_data['free_ship_min_order'] ?? 0);
            
            // Lấy giá sản phẩm để kiểm tra điều kiện min_order
            $base_price = $gia_moi;
            
            // Mode 0: Giảm cố định (VD: -15,000đ) - Cần kiểm tra điều kiện min_order
            if ($mode === 0 && $discount > 0 && $base_price >= $minOrder) {
                $freeship_label = 'Giảm ' . number_format($discount) . 'đ ship';
            }
            // Mode 1: Freeship toàn bộ (100%)
            elseif ($mode === 1) {
                $freeship_label = 'Freeship 100%';
            }
            // Mode 2: Giảm theo % (VD: -50%) - Cần kiểm tra điều kiện min_order
            elseif ($mode === 2 && $discount > 0 && $base_price >= $minOrder) {
                $freeship_label = 'Giảm ' . intval($discount) . '% ship';
            }
            // Mode 3: Ưu đãi ship theo sản phẩm cụ thể - cần kiểm tra fee_ship_products
            elseif ($mode === 3) {
                $fee_ship_products = $freeship_data['fee_ship_products'] ?? '';
                $ship_discount_amount = 0;
                
                if (!empty($fee_ship_products)) {
                    $fee_ship_products_array = json_decode($fee_ship_products, true);
                    if (is_array($fee_ship_products_array)) {
                        foreach ($fee_ship_products_array as $ship_item) {
                            if (isset($ship_item['sp_id']) && $ship_item['sp_id'] == $sp_id) {
                                // Lấy số tiền hỗ trợ ship cụ thể
                                if (isset($ship_item['ship_support'])) {
                                    $ship_discount_amount = intval($ship_item['ship_support']);
                                }
                                break;
                            }
                        }
                    }
                }
                
                // Hiển thị số tiền hỗ trợ ship cụ thể
                if ($ship_discount_amount > 0) {
                    $freeship_label = 'Hỗ trợ ship ' . number_format($ship_discount_amount) . '₫';
                }
            }
            // Mode 0 với discount = 0: Freeship cơ bản
            elseif ($mode === 0 && $discount == 0) {
                $freeship_label = 'Freeship';
            }
        }
        
        $freeship_icon = $freeship_label ?: '';
        $chinhhang_icon = 'Chính hãng';
        
        // Format image URL với CDN
        $image_url = $product['minh_hoa'];
        if ($image_url && strpos($image_url, 'http') !== 0) {
            $image_url = getImageUrlWithCDN($image_url);
        }
        
        // Badges
        $badges = [];
        if ($discount_percent > 0) {
            $badges[] = 'Giảm ' . $discount_percent . '%';
        }
        if ($is_flash) {
            $badges[] = 'Flash Sale';
        }
        if (!empty($voucher_icon)) {
            $badges[] = $voucher_icon;
        }
        if (!empty($freeship_icon)) {
            $badges[] = $freeship_icon;
        }
        if ($product['box_noibat'] == 1) {
            $badges[] = 'Nổi bật';
        }
        $badges[] = $chinhhang_icon;
        
        $products[] = [
            'id' => intval($sp_id),
            'name' => $product['tieu_de'],
            'slug' => $product['link'],
            'price' => intval($gia_moi),
            'old_price' => intval($gia_cu),
            'discount_percent' => $discount_percent,
            'image' => $image_url,
            'shop_id' => intval($product['shop']),
            'shop_name' => $product['shop_name'] ?? '',
            'brand_id' => intval($product['thuong_hieu']),
            'brand_name' => $product['brand_name'] ?? '',
            'category_ids' => array_filter(array_map('intval', explode(',', $product['cat']))),
            'total_reviews' => intval($product['total_reviews']),
            'avg_rating' => round(floatval($product['avg_rating']), 1),
            'total_sold' => intval($product['ban']),
            'total_views' => intval($product['view']),
            'is_flash_sale' => $is_flash,
            'has_free_shipping' => !empty($freeship_icon),
            'voucher_icon' => $voucher_icon,
            'freeship_icon' => $freeship_icon,
            'chinhhang_icon' => $chinhhang_icon,
            'warehouse_name' => $product['warehouse_name'] ?? '',
            'province_name' => $product['province_name'] ?? '',
            'badges' => $badges,
            'product_url' => 'https://socdo.vn/product/' . $product['link'] . '.html',
            'price_formatted' => number_format($gia_moi) . 'đ',
            'old_price_formatted' => $gia_cu > 0 ? number_format($gia_cu) . 'đ' : ''
        ];
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Lấy danh sách sản phẩm liên quan thành công',
        'data' => [
            'products' => $products,
            'total_products' => count($products),
            'product_id' => $product_id,
            'type' => $type
        ]
    ], JSON_UNESCAPED_UNICODE);
    
} else {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Chỉ hỗ trợ phương thức GET'
    ]);
}

