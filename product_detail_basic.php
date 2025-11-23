<?php
/**
 * API: Product Detail Basic (Tối ưu - chỉ basic info)
 * Method: GET
 * URL: /v1/product_detail_basic?product_id={id}&user_id={user_id}
 * 
 * Description: Chỉ trả về thông tin cơ bản của sản phẩm để load nhanh:
 * - Product basic info (name, price, images, stock)
 * - Variants (chỉ id, name, price, stock)
 * - Shop basic info (id, name, avatar)
 * - Rating summary (avg_rating, total_reviews) - từ cache
 * - Flash sale basic (nếu có)
 * 
 * Không bao gồm:
 * - Reviews (load riêng qua product_reviews.php)
 * - Related products (load riêng qua related_products.php)
 * - Same shop products (load riêng qua products_same_shop.php)
 * - Full shop info
 * - Full coupon details
 */

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
        
        // Validate parameters
        if ($product_id <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu product_id"
            ]);
            exit;
        }
        
        // Query tối ưu: Gộp shop info vào query chính để giảm số lượng queries
        // Thêm noi_dung và noi_bat để hiển thị description và highlights
        $query = "SELECT s.id, s.tieu_de, s.link, s.minh_hoa, s.anh, s.gia_cu, s.gia_moi, s.gia_ctv, s.gia_drop,
                  s.kho, s.ban, s.view, s.shop, s.thuong_hieu, s.cat, s.date_post, s.active, s.kho_id,
                  s.box_banchay, s.box_noibat, s.box_flash, s.noi_dung, s.noi_bat,
                  COALESCE(prs.total_reviews, 0) AS total_reviews,
                  COALESCE(prs.average_rating, 0) AS avg_rating,
                  CASE WHEN y.id IS NOT NULL THEN 1 ELSE 0 END AS is_favorited,
                  ui.user_id AS shop_user_id, ui.name AS shop_name, ui.avatar AS shop_avatar
                  FROM sanpham s
                  LEFT JOIN product_rating_stats prs ON s.id = prs.product_id AND s.shop = prs.shop_id
                  LEFT JOIN yeu_thich_san_pham y ON s.id = y.product_id AND y.user_id = '$user_id'
                  LEFT JOIN user_info ui ON s.shop = ui.user_id
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
        
        // Xử lý giá: Ưu tiên dùng giá từ bảng sanpham, sau đó sẽ tính từ variants nếu cần
        // Loại bỏ query phanloai_sanpham MIN/MAX để giảm số lượng queries (tính từ variants sau)
        $gia_cu_main = (int) preg_replace('/[^0-9]/', '', $product['gia_cu']);
        $gia_moi_main = (int) preg_replace('/[^0-9]/', '', $product['gia_moi']);
        $gia_ctv_main = (int) preg_replace('/[^0-9]/', '', $product['gia_ctv']);
        $gia_drop_main = (int) preg_replace('/[^0-9]/', '', $product['gia_drop']);
        
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
        
        // Xử lý hình ảnh (chỉ lấy URLs, không xử lý phức tạp)
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
        
        // Check flash sale (simplified - chỉ check basic info, tối ưu query)
        $flash_sale_info = null;
        $deal_shop = intval($product['shop']);
        
        if ($deal_shop > 0 && $product['box_flash'] == 1) {
            // Chỉ check flash sale nếu box_flash = 1 (đã được đánh dấu)
            // Tối ưu query: Thêm điều kiện box_flash để giảm số lượng rows cần scan
            $check_flash_sale = mysqli_query($conn, "SELECT id, date_start, date_end, sub_product FROM deal WHERE loai = 'flash_sale' AND shop = '$deal_shop' AND status = 2 AND '$current_time' BETWEEN date_start AND date_end AND (FIND_IN_SET('$product_id', main_product) > 0 OR sub_product LIKE '%\"$product_id\"%') LIMIT 1");
        
            if ($check_flash_sale && mysqli_num_rows($check_flash_sale) > 0) {
                $flash_deal = mysqli_fetch_assoc($check_flash_sale);
                
                // Parse sub_product JSON để tìm giá flash sale
                $flash_price = null;
                $flash_old_price = null;
                
                if (!empty($flash_deal['sub_product'])) {
                    $sub_json = json_decode($flash_deal['sub_product'], true);
                    if (json_last_error() === JSON_ERROR_NONE && is_array($sub_json)) {
                        $product_id_str = (string)$product_id;
                        $product_id_int = intval($product_id);
                        
                        $product_variants = null;
                        if (isset($sub_json[$product_id_str])) {
                            $product_variants = $sub_json[$product_id_str];
                        } elseif (isset($sub_json[$product_id_int])) {
                            $product_variants = $sub_json[$product_id_int];
                        }
                        
                        if (!empty($product_variants) && is_array($product_variants)) {
                            $first_variant = reset($product_variants);
                            $flash_price = isset($first_variant['gia']) ? intval($first_variant['gia']) : null;
                            $flash_old_price = isset($first_variant['gia_cu']) ? intval($first_variant['gia_cu']) : null;
                        }
                    }
                }
                
                // Nếu không tìm thấy trong sub_product, sử dụng giá hiện tại
                if ($flash_price === null) {
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
            }
        }
        
        if ($flash_sale_info === null) {
            $flash_sale_info = array('is_flash_sale' => false);
        }
        
        $product['flash_sale_info'] = $flash_sale_info;
        
        // Tạo URL sản phẩm
        $product['product_url'] = 'https://socdo.vn/san-pham/' . $product['id'] . '/' . $product['link'] . '.html';
        
        // Coupon info (simplified - tối ưu: chỉ check EXISTS thay vì SELECT id)
        $coupon_info = array('has_coupon' => false);
        $coupon_shop = $deal_shop > 0 ? $deal_shop : 0;
        // Tối ưu: Sử dụng EXISTS thay vì SELECT id để nhanh hơn
        $check_coupon = mysqli_query($conn, "SELECT 1 FROM coupon WHERE (FIND_IN_SET('$product_id', sanpham) OR kieu = 'all') AND shop = '$coupon_shop' AND '$current_time' BETWEEN start AND expired LIMIT 1");
        if ($check_coupon && mysqli_num_rows($check_coupon) > 0) {
            $coupon_info['has_coupon'] = true;
        }
        $product['coupon_info'] = $coupon_info;
        
        // Shop basic info (đã được JOIN trong query chính, không cần query riêng)
        $shop_info = array();
        if ($deal_shop > 0 && !empty($product['shop_user_id'])) {
            $shop_info = array(
                'shop_id' => intval($product['shop_user_id']),
                'shop_name' => $product['shop_name'] ?? '',
                'shop_avatar' => !empty($product['shop_avatar']) ? getImageUrlWithCDN($product['shop_avatar']) : '',
                'is_marketplace' => false
            );
        } else {
            // Sản phẩm sàn (shop = 0)
            $shop_info = array(
                'shop_id' => 0,
                'shop_name' => 'Sàn TMĐT',
                'shop_avatar' => '',
                'is_marketplace' => true
            );
        }
        $product['shop_info'] = $shop_info;
        
        // Badges (simplified)
        $badges = array();
        if ($product['box_banchay'] == 1) $badges[] = 'Bán chạy';
        if ($product['box_noibat'] == 1) $badges[] = 'Nổi bật';
        if ($product['box_flash'] == 1) $badges[] = 'Flash sale';
        if ($discount_percent > 0) $badges[] = "-$discount_percent%";
        if ($coupon_info['has_coupon']) $badges[] = 'Voucher';
        $badges[] = 'Chính hãng';
        $product['badges'] = $badges;
        
        // Rating và reviews - lấy từ product_rating_stats (đã JOIN ở trên)
        $total_reviews_real = intval($product['total_reviews']);
        $avg_rating_real = $product['avg_rating'] ? round(floatval($product['avg_rating']), 1) : 0;
        
        // Giữ nguyên random nếu không có đánh giá thật
        $product['total_reviews'] = $total_reviews_real > 0 ? $total_reviews_real : rand(3, 99);
        $product['avg_rating'] = $avg_rating_real > 0 ? $avg_rating_real : rand(40, 50) / 10;
        $product['sold_count'] = $product['ban'] + rand(10, 100);
        
        // Kiểm tra user đã yêu thích sản phẩm này chưa (đã được JOIN trong query chính)
        $is_favorited = ($user_id > 0) ? (intval($product['is_favorited']) === 1) : false;
        $product['is_favorited'] = $is_favorited;
        
        // Lấy danh sách phân loại sản phẩm từ bảng phanloai_sanpham - CHỈ lấy phân loại còn hàng
        // Simplified: chỉ lấy id, name, price, stock
        $variants_query = "SELECT id, sp_id, ten_color, ten_size, gia_moi, gia_cu, kho_sanpham_socdo, image_phanloai 
                          FROM phanloai_sanpham 
                          WHERE sp_id = '$product_id' AND kho_sanpham_socdo > 0 
                          ORDER BY gia_moi ASC";
        $variants_result = mysqli_query($conn, $variants_query);
        $variants = array();
        
        if ($variants_result && mysqli_num_rows($variants_result) > 0) {
            while ($variant = mysqli_fetch_assoc($variants_result)) {
                // Format giá tiền
                $variant['gia_cu_formatted'] = number_format($variant['gia_cu']);
                $variant['gia_moi_formatted'] = number_format($variant['gia_moi']);
                
                // Thêm field stock
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
                    if (strlen($ten_color) > 1 || !in_array($ten_color, ['+', '-'])) {
                        $variant_name_parts[] = $ten_color;
                    }
                }
                if (!empty($variant['ten_size'])) {
                    $ten_size = trim($variant['ten_size']);
                    if (strlen($ten_size) > 1 || !in_array($ten_size, ['+', '-'])) {
                        $variant_name_parts[] = $ten_size;
                    }
                }
                $variant['variant_name'] = !empty($variant_name_parts) ? implode(' - ', $variant_name_parts) : 'Mặc định';
                
                $variants[] = $variant;
            }
        }
        $product['variants'] = $variants;
        
        // Response chỉ với basic info (gửi response trước)
        $response = [
            "success" => true,
            "message" => "Lấy thông tin sản phẩm thành công",
            "data" => $product
        ];
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
        // Cập nhật lượt xem (async - sau khi response đã được gửi, không block)
        // Sử dụng connection riêng hoặc ignore errors để không ảnh hưởng response
        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request(); // Gửi response ngay lập tức
        }
        $view_update = "UPDATE sanpham SET view = view + 1 WHERE id = $product_id";
        @mysqli_query($conn, $view_update); // @ để ignore errors
        
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

