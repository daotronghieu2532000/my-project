<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
// Include user_behavior_helper để lưu hành vi người dùng
$helper_path = __DIR__ . '/user_behavior_helper.php';
if (file_exists($helper_path)) {
    require_once $helper_path;
}
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

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

// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(array("message" => "Không tìm thấy token"));
    exit;
}

$jwt = $matches[1]; // Lấy token từ Bearer

try {
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    
    // Kiểm tra issuer
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(array("message" => "Issuer không hợp lệ"));
        exit;
    }
    
    // Lấy user_id từ JWT token (nếu có)
    $jwt_user_id = isset($decoded->user_id) ? intval($decoded->user_id) : 0;
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        $product_id = isset($_GET['product_id']) ? intval($_GET['product_id']) : 0;
        $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
        $is_member = isset($_GET['is_member']) ? intval($_GET['is_member']) : 0;
        
        // Validate parameters
        if ($product_id <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu product_id"
            ]);
            exit;
        }
        
        // Lấy thông tin chi tiết sản phẩm
        // Với sàn (shop = 0): lấy transport với user_id = 0
        // Với shop thường: lấy transport theo kho_id
        $query = "SELECT s.*, 
                  COALESCE(pc.total_reviews, 0) AS total_reviews,
                  COALESCE(pc.avg_rating, 0) AS avg_rating,
                  COALESCE(t.ten_kho, t_san.ten_kho) AS warehouse_name,
                  COALESCE(tm.tieu_de, tm_san.tieu_de) AS province_name,
                  CASE WHEN y.id IS NOT NULL THEN 1 ELSE 0 END AS is_favorited
                  FROM sanpham s
                  LEFT JOIN (
                      SELECT product_id, COUNT(*) AS total_reviews, AVG(rating) AS avg_rating
                      FROM product_comments
                      WHERE status = 'approved' AND parent_id = 0
                      GROUP BY product_id
                  ) AS pc ON s.id = pc.product_id
                  LEFT JOIN transport t ON s.kho_id = t.id AND s.shop > 0
                  LEFT JOIN tinh_moi tm ON t.province = tm.id
                  LEFT JOIN transport t_san ON t_san.user_id = 0 AND s.shop = 0 AND t_san.is_default = 1
                  LEFT JOIN tinh_moi tm_san ON t_san.province = tm_san.id
                  LEFT JOIN yeu_thich_san_pham y ON s.id = y.product_id AND y.user_id = '$user_id'
                  WHERE s.id = $product_id AND s.kho > 0 AND s.active = 0
                  LIMIT 1";
        
        $result = mysqli_query($conn, $query);
        
        if (!$result || mysqli_num_rows($result) == 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Không tìm thấy sản phẩm"
            ]);
            exit;
        }
        
        $product = mysqli_fetch_assoc($result);
        $current_time = time();
        
        // Xử lý giá từ bảng phanloai_sanpham nếu có
        $sql_pl = "SELECT MIN(gia_moi) AS gia_moi_min, MAX(gia_cu) AS gia_cu_max, MIN(gia_ctv) AS gia_ctv_min, 
                   MIN(gia_drop) AS gia_drop_min FROM phanloai_sanpham WHERE sp_id = '$product_id'";
        $res_pl = mysqli_query($conn, $sql_pl);
        $row_pl = mysqli_fetch_assoc($res_pl);
        
        if ($row_pl && $row_pl['gia_moi_min'] !== null && $row_pl['gia_moi_min'] > 0) {
            $gia_moi_main = (int) $row_pl['gia_moi_min'];
            $gia_cu_main = (int) $row_pl['gia_cu_max'];
            $gia_ctv_main = (int) $row_pl['gia_ctv_min'];
            $gia_drop_main = (int) $row_pl['gia_drop_min'];
        } else {
            $gia_cu_main = (int) preg_replace('/[^0-9]/', '', $product['gia_cu']);
            $gia_moi_main = (int) preg_replace('/[^0-9]/', '', $product['gia_moi']);
            $gia_ctv_main = (int) preg_replace('/[^0-9]/', '', $product['gia_ctv']);
            $gia_drop_main = (int) preg_replace('/[^0-9]/', '', $product['gia_drop']);
        }
        
        // Tính phần trăm giảm giá
        $discount_percent = ($gia_cu_main > $gia_moi_main && $gia_cu_main > 0) ? 
                           ceil((($gia_cu_main - $gia_moi_main) / $gia_cu_main) * 100) : 0;
        
        // Format giá tiền
        $product['gia_cu_formatted'] = number_format($gia_cu_main);
        $product['gia_moi_formatted'] = number_format($gia_moi_main);
        $product['gia_ctv_formatted'] = number_format($gia_ctv_main);
        $product['gia_drop_formatted'] = number_format($gia_drop_main);
        $product['discount_percent'] = $discount_percent;
        $product['date_post_formatted'] = date('d/m/Y H:i:s', $product['date_post']);
        
        // Xử lý hình ảnh
        $images = array();
        $main_image = $product['minh_hoa'];
        
        // Hình ảnh chính (minh_hoa)
        if (!empty($main_image)) {
            $images['main'] = getImageUrlWithCDN($main_image);
            
            // Tạo thumbnail path
            $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/sanpham_anh_340x340/', $main_image);
            $images['thumb'] = getImageUrlWithCDN($thumb_image);
        } else {
            $images['main'] = 'https://socdo.vn/images/no-images.jpg';
            $images['thumb'] = $images['main'];
        }
        
        // Hình ảnh gallery từ cột 'anh' (chi tiết sản phẩm)
        $gallery_images = array();
        if (!empty($product['anh'])) {
            $image_list = explode(',', $product['anh']);
            foreach ($image_list as $img) {
                $img = trim($img);
                if (!empty($img)) {
                    $gallery_images[] = getImageUrlWithCDN($img);
                }
            }
        }
        
        // Nếu không có ảnh gallery, sử dụng ảnh chính
        if (empty($gallery_images)) {
            $gallery_images[] = $images['main'];
        }
        
        $images['gallery'] = $gallery_images;
        
        $product['images'] = $images;
        
        // Check if product is in flash sale
        // Bỏ flash sale cho sản phẩm sàn (shop = 0)
        $flash_sale_info = null;
        $deal_shop = intval($product['shop']);
        
        if ($deal_shop > 0) {
            // Chỉ check flash sale cho shop thường (shop > 0)
            // Check status IN (1,2) - status 1: web con, status 2: Đăng sàn
            $check_flash_sale = mysqli_query($conn, "SELECT * FROM deal WHERE loai = 'flash_sale' AND shop != 0 AND status = 2 AND '$current_time' BETWEEN date_start AND date_end LIMIT 50");
        
        if ($check_flash_sale && mysqli_num_rows($check_flash_sale) > 0) {
            // Loop through all active flash sales to find if this product is included
            while ($flash_deal = mysqli_fetch_assoc($check_flash_sale)) {
                $is_in_flash_sale = false;
                
                // Check main_product
                if (!empty($flash_deal['main_product'])) {
                    $main_product_ids = explode(',', $flash_deal['main_product']);
                    $main_product_ids_int = array_map('intval', $main_product_ids);
                    if (in_array(intval($product_id), $main_product_ids_int)) {
                        $is_in_flash_sale = true;
                    }
                }
                
                // Check sub_product (JSON) - product_id can be string or int in JSON
                if (!$is_in_flash_sale && !empty($flash_deal['sub_product'])) {
                    $sub_json = json_decode($flash_deal['sub_product'], true);
                    if (json_last_error() === JSON_ERROR_NONE && is_array($sub_json)) {
                        // Check both string and int keys - try all possible formats
                        $product_id_str = (string)$product_id;
                        $product_id_int = intval($product_id);
                        if (isset($sub_json[$product_id_str]) || isset($sub_json[$product_id_int])) {
                            $is_in_flash_sale = true;
                        }
                    }
                }
                
                // Also check if product has variants in sub_id (variant IDs comma separated)
                if (!$is_in_flash_sale && !empty($flash_deal['sub_id'])) {
                    // sub_id contains variant_id, so we need to check if product has any variants in this sub_id
                    // For now, if sub_id exists, consider it a potential match
                    // This will be more accurate once we get variant_id from product
                }
                
                if ($is_in_flash_sale) {
                    // Parse sub_product JSON để tìm giá flash sale cho sản phẩm này
                    $flash_price = null;
                    $flash_old_price = null;
                    $flash_stock = null;
                    $variant_id = null;
                    
                    if (!empty($flash_deal['sub_product'])) {
                        $sub_json = json_decode($flash_deal['sub_product'], true);
                        if (json_last_error() === JSON_ERROR_NONE && is_array($sub_json)) {
                            // Check both string and int keys - try all possible formats
                            $product_id_str = (string)$product_id;
                            $product_id_int = intval($product_id);
                            
                            $product_variants = null;
                            if (isset($sub_json[$product_id_str])) {
                                $product_variants = $sub_json[$product_id_str];
                            } elseif (isset($sub_json[$product_id_int])) {
                                $product_variants = $sub_json[$product_id_int];
                            }
                            
                            // Lấy giá đầu tiên (hoặc có thể chọn variant đầu tiên)
                            if (!empty($product_variants) && is_array($product_variants)) {
                                $first_variant = reset($product_variants);
                                $flash_price = isset($first_variant['gia']) ? intval($first_variant['gia']) : null;
                                $flash_old_price = isset($first_variant['gia_cu']) ? intval($first_variant['gia_cu']) : null;
                                $flash_stock = isset($first_variant['so_luong']) ? intval($first_variant['so_luong']) : null;
                                $variant_id = isset($first_variant['variant_id']) ? $first_variant['variant_id'] : null;
                            }
                        }
                    }
                    
                    // Nếu không tìm thấy trong sub_product, check main_product
                    if ($flash_price === null) {
                        // Sử dụng giá hiện tại của sản phẩm
                        $flash_price = $gia_moi_main;
                        $flash_old_price = $gia_cu_main;
                    }
                    
                    // Tính thời gian còn lại
                    $time_remaining = $flash_deal['date_end'] - $current_time;
                    
                    $flash_sale_info = array(
                        'is_flash_sale' => true,
                        'deal_id' => $flash_deal['id'],
                        'flash_price' => $flash_price,
                        'flash_old_price' => $flash_old_price,
                        'flash_stock' => $flash_stock,
                        'variant_id' => $variant_id,
                        'date_start' => $flash_deal['date_start'],
                        'date_end' => $flash_deal['date_end'],
                        'time_remaining' => $time_remaining,
                        'time_remaining_formatted' => gmdate('H:i:s', $time_remaining)
                    );
                    
                    // Update giá hiển thị nếu có flash sale
                    if ($flash_price !== null && $flash_price < $gia_moi_main) {
                        $product['gia_moi'] = $flash_price;
                        $product['gia_moi_formatted'] = number_format($flash_price);
                        $discount_percent = ($flash_old_price > $flash_price && $flash_old_price > 0) ? 
                                           ceil((($flash_old_price - $flash_price) / $flash_old_price) * 100) : 0;
                        $product['discount_percent'] = $discount_percent;
                        
                        $gia_cu_main = $flash_old_price;
                        $product['gia_cu_formatted'] = number_format($gia_cu_main);
                    }
                    
                    break; // Found matching flash sale, exit loop
                }
                }
            }
        }
        
        if ($flash_sale_info === null) {
            $flash_sale_info = array('is_flash_sale' => false);
        }
        
        $product['flash_sale_info'] = $flash_sale_info;
        
        // Tạo URL sản phẩm
        $product['product_url'] = 'https://socdo.vn/san-pham/' . $product['id'] . '/' . $product['link'] . '.html';
        
        // Xử lý voucher và freeship icons
        $voucher_icon = '';
        $freeship_icon = '';
        $coupon_info = array();
        
        if ($deal_shop > 0) {
            // Shop thường: Check voucher cho sản phẩm cụ thể
            $check_coupon = mysqli_query($conn, "SELECT id, ma, loai, giam, mo_ta FROM coupon WHERE FIND_IN_SET('$product_id', sanpham) AND shop = '$deal_shop' AND '$current_time' BETWEEN start AND expired LIMIT 1");
            if (mysqli_num_rows($check_coupon) > 0) {
                $voucher_data = mysqli_fetch_assoc($check_coupon);
                $voucher_icon = 'Voucher';
                $coupon_info = array(
                    'has_coupon' => true,
                    'coupon_code' => $voucher_data['ma'],
                    'coupon_type' => $voucher_data['loai'],
                    'coupon_discount' => $voucher_data['giam'],
                    'coupon_description' => $voucher_data['mo_ta'],
                    'coupon_details' => 'Mã: ' . $voucher_data['ma'] . ($voucher_data['loai'] == 'tru' ? ' - Giảm ' . number_format($voucher_data['giam']) . 'đ' : ' - Giảm ' . $voucher_data['giam'] . '%')
                );
            } else {
                // Check voucher cho toàn shop
                $check_coupon_all = mysqli_query($conn, "SELECT id, ma, loai, giam, mo_ta FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                if (mysqli_num_rows($check_coupon_all) > 0) {
                    $voucher_data = mysqli_fetch_assoc($check_coupon_all);
                    $voucher_icon = 'Voucher';
                    $coupon_info = array(
                        'has_coupon' => true,
                        'coupon_code' => $voucher_data['ma'],
                        'coupon_type' => $voucher_data['loai'],
                        'coupon_discount' => $voucher_data['giam'],
                        'coupon_description' => $voucher_data['mo_ta'],
                        'coupon_details' => 'Mã shop: ' . $voucher_data['ma'] . ($voucher_data['loai'] == 'tru' ? ' - Giảm ' . number_format($voucher_data['giam']) . 'đ' : ' - Giảm ' . $voucher_data['giam'] . '%')
                    );
                } else {
                    $coupon_info = array(
                        'has_coupon' => false,
                        'coupon_code' => '',
                        'coupon_type' => '',
                        'coupon_discount' => 0,
                        'coupon_description' => '',
                        'coupon_details' => ''
                    );
                }
            }
            
            // Check freeship từ transport của shop
            $check_freeship = mysqli_query($conn, "SELECT id FROM transport WHERE user_id = '$deal_shop' AND (free_ship_all = 1 OR free_ship_discount > 0) LIMIT 1");
            if (mysqli_num_rows($check_freeship) > 0) {
                $freeship_icon = 'Freeship';
            }
        } else {
            // Sản phẩm sàn (shop = 0): Lấy voucher sàn
            $check_coupon = mysqli_query($conn, "SELECT id, ma, loai, giam, mo_ta FROM coupon WHERE FIND_IN_SET('$product_id', sanpham) AND shop = 0 AND '$current_time' BETWEEN start AND expired LIMIT 1");
            if (mysqli_num_rows($check_coupon) > 0) {
                $voucher_data = mysqli_fetch_assoc($check_coupon);
                $voucher_icon = 'Voucher';
                $coupon_info = array(
                    'has_coupon' => true,
                    'coupon_code' => $voucher_data['ma'],
                    'coupon_type' => $voucher_data['loai'],
                    'coupon_discount' => $voucher_data['giam'],
                    'coupon_description' => $voucher_data['mo_ta'],
                    'coupon_details' => 'Mã sàn: ' . $voucher_data['ma'] . ($voucher_data['loai'] == 'tru' ? ' - Giảm ' . number_format($voucher_data['giam']) . 'đ' : ' - Giảm ' . $voucher_data['giam'] . '%')
                );
            } else {
                // Check voucher sàn cho toàn bộ
                $check_coupon_all = mysqli_query($conn, "SELECT id, ma, loai, giam, mo_ta FROM coupon WHERE shop = 0 AND kieu = 'all' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                if (mysqli_num_rows($check_coupon_all) > 0) {
                    $voucher_data = mysqli_fetch_assoc($check_coupon_all);
                    $voucher_icon = 'Voucher';
                    $coupon_info = array(
                        'has_coupon' => true,
                        'coupon_code' => $voucher_data['ma'],
                        'coupon_type' => $voucher_data['loai'],
                        'coupon_discount' => $voucher_data['giam'],
                        'coupon_description' => $voucher_data['mo_ta'],
                        'coupon_details' => 'Mã sàn: ' . $voucher_data['ma'] . ($voucher_data['loai'] == 'tru' ? ' - Giảm ' . number_format($voucher_data['giam']) . 'đ' : ' - Giảm ' . $voucher_data['giam'] . '%')
                    );
                } else {
                    $coupon_info = array(
                        'has_coupon' => false,
                        'coupon_code' => '',
                        'coupon_type' => '',
                        'coupon_discount' => 0,
                        'coupon_description' => '',
                        'coupon_details' => ''
                    );
                }
            }
            
            // Check freeship từ transport của sàn (user_id = 0)
            $check_freeship = mysqli_query($conn, "SELECT id FROM transport WHERE user_id = 0 AND (free_ship_all = 1 OR free_ship_discount > 0) LIMIT 1");
            if (mysqli_num_rows($check_freeship) > 0) {
                $freeship_icon = 'Freeship';
            }
        }
        
        $product['coupon_info'] = $coupon_info;
        
        // Lấy thông tin shop từ bảng user_info
        // Với sàn (shop = 0): tạo shop_info mặc định, không có trong user_info
        $shop_info = array();
        $is_marketplace = false;
        
        if ($deal_shop > 0) {
            // Shop thường: Lấy từ user_info
            $shop_query = "SELECT user_id, username, name, avatar, dia_chi, email, mobile FROM user_info WHERE user_id = '$deal_shop' LIMIT 1";
            $shop_result = mysqli_query($conn, $shop_query);
            if ($shop_result && mysqli_num_rows($shop_result) > 0) {
                $shop_data = mysqli_fetch_assoc($shop_result);
                
                // Đếm tổng số sản phẩm của shop
                $product_count_query = "SELECT COUNT(*) as total FROM sanpham WHERE shop = '$deal_shop' AND status = 1 AND kho > 0 AND active = 0";
                $product_count_result = mysqli_query($conn, $product_count_query);
                $product_count = 0;
                if ($product_count_result) {
                    $count_row = mysqli_fetch_assoc($product_count_result);
                    $product_count = intval($count_row['total']);
                }
                
                $shop_info = array(
                    'shop_id' => intval($shop_data['user_id']),
                    'shop_name' => $shop_data['name'],
                    'shop_username' => $shop_data['username'],
                    'shop_email' => $shop_data['email'],
                    'shop_mobile' => $shop_data['mobile'],
                    'shop_address' => $shop_data['dia_chi'],
                    'shop_avatar' => !empty($shop_data['avatar']) ? getImageUrlWithCDN($shop_data['avatar']) : '',
                    'shop_url' => 'https://socdo.vn/shop/' . $shop_data['username'],
                    'total_products' => $product_count,
                    'is_marketplace' => false,
                    'hide_chat' => false
                );
            }
        } else {
            // Sản phẩm sàn (shop = 0): Không có trong user_info
            // Đếm tổng số sản phẩm sàn
            $product_count_query = "SELECT COUNT(*) as total FROM sanpham WHERE shop = 0 AND status = 1 AND kho > 0 AND active = 0";
            $product_count_result = mysqli_query($conn, $product_count_query);
            $product_count = 0;
            if ($product_count_result) {
                $count_row = mysqli_fetch_assoc($product_count_result);
                $product_count = intval($count_row['total']);
            }
            
            // Lấy địa chỉ kho sàn từ transport với user_id = 0
            $warehouse_address = '';
            $warehouse_query = "SELECT t.address_detail, t.province, t.district, t.ward,
                                       tm.tieu_de as province_name,
                                       hm.tieu_de as district_name,
                                       xm.tieu_de as ward_name
                                FROM transport t
                                LEFT JOIN tinh_moi tm ON t.province = tm.id
                                LEFT JOIN huyen_moi hm ON t.district = hm.id
                                LEFT JOIN xa_moi xm ON t.ward = xm.id
                                WHERE t.user_id = 0 AND t.is_default = 1
                                LIMIT 1";
            $warehouse_result = mysqli_query($conn, $warehouse_query);
            if ($warehouse_result && mysqli_num_rows($warehouse_result) > 0) {
                $warehouse_data = mysqli_fetch_assoc($warehouse_result);
                $address_parts = array();
                if (!empty($warehouse_data['address_detail'])) {
                    $address_parts[] = $warehouse_data['address_detail'];
                }
                if (!empty($warehouse_data['ward_name'])) {
                    $address_parts[] = $warehouse_data['ward_name'];
                }
                if (!empty($warehouse_data['district_name'])) {
                    $address_parts[] = $warehouse_data['district_name'];
                }
                if (!empty($warehouse_data['province_name'])) {
                    $address_parts[] = $warehouse_data['province_name'];
                }
                $warehouse_address = implode(', ', $address_parts);
            }
            
            $shop_info = array(
                'shop_id' => 0,
                'shop_name' => 'Sàn TMĐT',
                'shop_username' => '',
                'shop_email' => '',
                'shop_mobile' => '',
                'shop_address' => $warehouse_address,
                'shop_avatar' => '',
                'shop_url' => 'https://socdo.vn',
                'total_products' => $product_count,
                'is_marketplace' => true,
                'hide_chat' => true
            );
            $is_marketplace = true;
        }
        $product['shop_info'] = $shop_info;
        $product['is_marketplace'] = $is_marketplace;
        
        // Thêm badges
        $badges = array();
        if ($product['box_banchay'] == 1) $badges[] = 'Bán chạy';
        if ($product['box_noibat'] == 1) $badges[] = 'Nổi bật';
        if ($product['box_flash'] == 1) $badges[] = 'Flash sale';
        if ($discount_percent > 0) $badges[] = "-$discount_percent%";
        if (!empty($voucher_icon)) $badges[] = $voucher_icon;
        if (!empty($freeship_icon)) $badges[] = $freeship_icon;
        $badges[] = 'Chính hãng';
        
        $product['badges'] = $badges;
        $product['voucher_icon'] = $voucher_icon;
        $product['freeship_icon'] = $freeship_icon;
        $product['chinhhang_icon'] = 'Chính hãng';
        
        // Rating và reviews - lấy từ product_comments
        $reviews_query = "SELECT COUNT(*) as total, AVG(rating) as avg_rating 
                         FROM product_comments 
                         WHERE product_id = $product_id AND status = 'approved' AND parent_id = 0";
        $reviews_result = mysqli_query($conn, $reviews_query);
        $reviews_data = mysqli_fetch_assoc($reviews_result);
        $total_reviews_real = intval($reviews_data['total'] ?? 0);
        $avg_rating_real = $reviews_data['avg_rating'] ? round(floatval($reviews_data['avg_rating']), 1) : 0;
        
        // Giữ nguyên random nếu không có đánh giá thật
        $product['total_reviews'] = $total_reviews_real > 0 ? $total_reviews_real : rand(3, 99);
        $product['avg_rating'] = $avg_rating_real > 0 ? $avg_rating_real : ($product['avg_rating'] > 0 ? round($product['avg_rating'], 1) : rand(40, 50) / 10);
        $product['sold_count'] = $product['ban'] + rand(10, 100);
        
        // Lấy 4 đánh giá đầu tiên với thông tin đầy đủ
        $reviews_list = array();
        if ($total_reviews_real > 0) {
            $reviews_detail_query = "SELECT 
                pc.id,
                pc.product_id,
                pc.variant_id,
                pc.user_id,
                pc.shop_id,
                pc.content,
                pc.rating,
                pc.delivery_rating,
                pc.shop_rating,
                pc.matches_description,
                pc.is_satisfied,
                pc.will_buy_again,
                pc.images,
                pc.is_verified_purchase,
                pc.order_id,
                pc.created_at,
                u.name as user_name,
                u.avatar as user_avatar
            FROM product_comments pc
            LEFT JOIN user_info u ON pc.user_id = u.user_id
            WHERE pc.product_id = $product_id 
                AND pc.status = 'approved' 
                AND pc.parent_id = 0
            ORDER BY pc.is_pinned DESC, pc.created_at DESC
            LIMIT 4";
            
            $reviews_detail_result = mysqli_query($conn, $reviews_detail_query);
            if ($reviews_detail_result) {
                while ($review_row = mysqli_fetch_assoc($reviews_detail_result)) {
                    // Xử lý images
                    $review_images = array();
                    if (!empty($review_row['images'])) {
                        $decoded_images = json_decode($review_row['images'], true);
                        if (is_array($decoded_images)) {
                            foreach ($decoded_images as $img) {
                                if (is_string($img)) {
                                    if (strpos($img, 'data:image/') === 0) {
                                        $review_images[] = $img;
                                    } elseif (strpos($img, 'http') === 0) {
                                        $review_images[] = $img;
                                    } elseif (strpos($img, '/uploads/') === 0) {
                                        $review_images[] = 'https://socdo.vn' . $img;
                                    } else {
                                        $review_images[] = 'https://socdo.vn/' . ltrim($img, '/');
                                    }
                                }
                            }
                        }
                    }
                    
                    // Xử lý avatar user
                    $user_avatar_url = '';
                    if (!empty($review_row['user_avatar']) && $review_row['user_avatar'] !== '0') {
                        $avatar = trim($review_row['user_avatar']);
                        $avatar = ltrim($avatar, '/');
                        $user_avatar_url = 'https://socdo.vn/' . $avatar;
                    }
                    
                    // Lấy thông tin biến thể nếu có
                    $variant_info = null;
                    if (!empty($review_row['variant_id'])) {
                        $variant_id_val = intval($review_row['variant_id']);
                        $variant_query = "SELECT id, sp_id, ten_color, ten_size, image_phanloai 
                                        FROM phanloai_sanpham 
                                        WHERE id = $variant_id_val AND sp_id = $product_id LIMIT 1";
                        $variant_result = mysqli_query($conn, $variant_query);
                        if ($variant_result && mysqli_num_rows($variant_result) > 0) {
                            $variant_row = mysqli_fetch_assoc($variant_result);
                            $variant_parts = array();
                            if (!empty($variant_row['ten_color'])) {
                                $variant_parts[] = $variant_row['ten_color'];
                            }
                            if (!empty($variant_row['ten_size'])) {
                                $variant_parts[] = $variant_row['ten_size'];
                            }
                            $variant_name = !empty($variant_parts) ? implode(' - ', $variant_parts) : '';
                            
                            $variant_info = array(
                                'id' => intval($variant_row['id']),
                                'name' => $variant_name,
                                'image' => !empty($variant_row['image_phanloai']) ? getImageUrlWithCDN($variant_row['image_phanloai']) : '',
                            );
                        }
                    }
                    
                    $reviews_list[] = array(
                        'id' => intval($review_row['id']),
                        'product_id' => intval($review_row['product_id']),
                        'variant_id' => $review_row['variant_id'] ? intval($review_row['variant_id']) : null,
                        'variant' => $variant_info,
                        'user_id' => intval($review_row['user_id']),
                        'user_name' => $review_row['user_name'] ?? 'Người dùng',
                        'user_avatar' => $user_avatar_url,
                        'content' => $review_row['content'],
                        'rating' => intval($review_row['rating']),
                        'delivery_rating' => $review_row['delivery_rating'] ? intval($review_row['delivery_rating']) : null,
                        'shop_rating' => $review_row['shop_rating'] ? intval($review_row['shop_rating']) : null,
                        'matches_description' => $review_row['matches_description'] !== null ? (intval($review_row['matches_description']) === 1) : null,
                        'is_satisfied' => $review_row['is_satisfied'] !== null ? (intval($review_row['is_satisfied']) === 1) : null,
                        'will_buy_again' => $review_row['will_buy_again'] ?? null,
                        'images' => $review_images,
                        'is_verified_purchase' => intval($review_row['is_verified_purchase']) === 1,
                        'order_id' => $review_row['order_id'] ? intval($review_row['order_id']) : null,
                        'created_at' => $review_row['created_at'],
                        'created_at_formatted' => date('d/m/Y', strtotime($review_row['created_at'])),
                    );
                }
            }
        }
        $product['reviews'] = $reviews_list;
        
        // Star HTML
        $avg_rating = $product['avg_rating'];
        $star_html = '';
        for ($i = 1; $i <= 5; $i++) {
            if ($i <= floor($avg_rating)) {
                $star_html .= '<i class="fa fa-star" style="color: #ffc107"></i>';
            } elseif ($i - $avg_rating < 1) {
                $star_html .= '<i class="fa fa-star-half-o" style="color: #ffc107"></i>';
            } else {
                $star_html .= '<i class="fa fa-star-o" style="color: #ffc107"></i>';
            }
        }
        $product['star_html'] = $star_html;
        
        // Label sale
        if ($discount_percent > 0) {
            $product['label_sale'] = '<div class="label_product"><div class="label_wrapper">-' . $discount_percent . '%</div></div>';
        } else {
            $product['label_sale'] = '';
        }
        
        // Price for members
        if ($is_member) {
            $product['price_thanhvien'] = '<span class="price-thanhvien"><i class="fa fa-user"></i>' . $product['gia_ctv_formatted'] . '₫</span>';
        } else {
            $product['price_thanhvien'] = '';
        }
        
        // Kiểm tra user đã yêu thích sản phẩm này chưa (đã được JOIN trong query chính)
        $is_favorited = ($user_id > 0) ? (intval($product['is_favorited']) === 1) : false;
        $product['is_favorited'] = $is_favorited;
        
        // Lấy danh sách phân loại sản phẩm từ bảng phanloai_sanpham - CHỈ lấy phân loại còn hàng
        $variants_query = "SELECT * FROM phanloai_sanpham WHERE sp_id = '$product_id' AND kho_sanpham_socdo > 0 ORDER BY gia_moi ASC";
        $variants_result = mysqli_query($conn, $variants_query);
        $variants = array();
        
        if ($variants_result && mysqli_num_rows($variants_result) > 0) {
            while ($variant = mysqli_fetch_assoc($variants_result)) {
                // Format giá tiền
                $variant['gia_cu_formatted'] = number_format($variant['gia_cu']);
                $variant['gia_moi_formatted'] = number_format($variant['gia_moi']);
                $variant['gia_ctv_formatted'] = number_format($variant['gia_ctv']);
                $variant['gia_drop_formatted'] = number_format($variant['gia_drop']);
                
                // Thêm field stock để app hiển thị
                $variant['stock'] = intval($variant['kho_sanpham_socdo']);
                
                // Tính phần trăm giảm giá
                $variant_discount = ($variant['gia_cu'] > $variant['gia_moi'] && $variant['gia_cu'] > 0) ? 
                                   ceil((($variant['gia_cu'] - $variant['gia_moi']) / $variant['gia_cu']) * 100) : 0;
                $variant['discount_percent'] = $variant_discount;
                
                // Xử lý hình ảnh biến thể
                if (!empty($variant['image_phanloai'])) {
                    $variant['image_url'] = getImageUrlWithCDN($variant['image_phanloai']);
                } else {
                    $variant['image_url'] = $images['main']; // Fallback về ảnh chính
                }
                
                // Tạo tên biến thể
                $variant_name_parts = array();
                if (!empty($variant['ten_color'])) {
                    $ten_color = trim($variant['ten_color']);
                    // Chỉ thêm nếu không phải là ký tự đơn lẻ như +, -
                    if (strlen($ten_color) > 1 || !in_array($ten_color, ['+', '-'])) {
                        $variant_name_parts[] = $ten_color;
                    }
                }
                if (!empty($variant['ten_size'])) {
                    $ten_size = trim($variant['ten_size']);
                    // Chỉ thêm nếu không phải là ký tự đơn lẻ như +, -
                    if (strlen($ten_size) > 1 || !in_array($ten_size, ['+', '-'])) {
                        $variant_name_parts[] = $ten_size;
                    }
                }
                $variant['variant_name'] = !empty($variant_name_parts) ? implode(' - ', $variant_name_parts) : 'Mặc định';
                
                // Thông tin thuộc tính
                $variant['attributes'] = array();
                if (!empty($variant['color'])) {
                    $variant['attributes']['color'] = $variant['color'];
                }
                if (!empty($variant['size'])) {
                    $variant['attributes']['size'] = $variant['size'];
                }
                if (!empty($variant['ma_mau'])) {
                    $variant['attributes']['ma_mau'] = $variant['ma_mau'];
                }
                
                $variants[] = $variant;
            }
        }
        $product['variants'] = $variants;
        
        // Lấy danh mục sản phẩm
        $categories = array();
        if (!empty($product['cat'])) {
            $cat_ids = explode(',', $product['cat']);
            foreach ($cat_ids as $cat_id) {
                $cat_id = intval(trim($cat_id));
                if ($cat_id > 0) {
                    $cat_query = "SELECT cat_id, cat_tieude, cat_link FROM category_sanpham WHERE cat_id = $cat_id LIMIT 1";
                    $cat_result = mysqli_query($conn, $cat_query);
                    if ($cat_result && mysqli_num_rows($cat_result) > 0) {
                        $category = mysqli_fetch_assoc($cat_result);
                        $category['category_url'] = 'https://socdo.vn/danh-muc/' . $category['cat_id'] . '/' . $category['cat_link'] . '.html';
                        $categories[] = $category;
                    }
                }
            }
        }
        $product['categories'] = $categories;
        
        // Cập nhật lượt xem
        $view_update = "UPDATE sanpham SET view = view + 1 WHERE id = $product_id";
        mysqli_query($conn, $view_update);
        $product['view'] = $product['view'] + 1;
        
        // Đảm bảo trả về cột 'anh' để Flutter có thể sử dụng
        $response = [
            "success" => true,
            "message" => "Lấy thông tin sản phẩm thành công",
            "data" => $product
        ];
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
        // Lưu hành vi xem sản phẩm (chạy sau khi response đã được gửi, không ảnh hưởng API)
        $final_user_id = ($user_id > 0) ? $user_id : $jwt_user_id;
        if (function_exists('saveUserBehavior') && $final_user_id > 0 && $product_id > 0) {
            try {
                // Lấy category_id từ sản phẩm
                $category_id = null;
                if (isset($product['cat']) && !empty($product['cat'])) {
                    $cat_string = $product['cat'];
                    $cat_array = explode(',', $cat_string);
                    if (!empty($cat_array)) {
                        $category_id = intval(trim($cat_array[0]));
                    }
                }
                
                saveUserBehavior($conn, $final_user_id, 'view', $product_id, null, $category_id, [
                    'product_title' => $product['tieu_de'] ?? '',
                    'product_price' => $product['gia_moi'] ?? 0,
                    'shop_id' => $product['shop'] ?? 0
                ]);
            } catch (Exception $e) {
                // Lỗi lưu hành vi không ảnh hưởng đến API
            }
        }
        
    } else {
        http_response_code(405);
        echo json_encode([
            "success" => false,
            "message" => "Chỉ hỗ trợ phương thức GET"
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "success" => false,
        "message" => "Token không hợp lệ",
        "error" => $e->getMessage()
    ));
}
?>

