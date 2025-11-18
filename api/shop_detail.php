<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

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
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : 0;
        $username = isset($_GET['username']) ? trim($_GET['username']) : '';
        $include_products = isset($_GET['include_products']) ? intval($_GET['include_products']) : 1;
        $include_flash_sale = isset($_GET['include_flash_sale']) ? intval($_GET['include_flash_sale']) : 1;
        $include_vouchers = isset($_GET['include_vouchers']) ? intval($_GET['include_vouchers']) : 1;
        $include_warehouses = isset($_GET['include_warehouses']) ? intval($_GET['include_warehouses']) : 1;
        $include_categories = isset($_GET['include_categories']) ? intval($_GET['include_categories']) : 1;
        $products_limit = isset($_GET['products_limit']) ? intval($_GET['products_limit']) : 500;
        $category_id = isset($_GET['category_id']) ? intval($_GET['category_id']) : 0;
        $search = isset($_GET['search']) ? trim($_GET['search']) : '';
        
        // Validate parameters
        // Cho phép shop_id = 0 (sàn) hoặc shop_id > 0 (shop thường) hoặc có username
        if ($shop_id < 0 && empty($username)) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Phải cung cấp shop_id hoặc username"
            ]);
            exit;
        }
        
        if ($products_limit < 1 || $products_limit > 100) $products_limit = 500;
        
        $current_time = time();
        
        // Lấy shop_id từ username nếu cần
        if ($shop_id <= 0 && !empty($username)) {
            // Kiểm tra nếu username là sàn (Sàn TMĐT hoặc các biến thể)
            $username_lower = mb_strtolower(trim($username), 'UTF-8');
            $marketplace_keywords = array('sàn tmđt', 'sàn thương mại điện tử', 'san tmdt', 'marketplace', 'sàn');
            
            $is_marketplace_username = false;
            foreach ($marketplace_keywords as $keyword) {
                if (strpos($username_lower, $keyword) !== false) {
                    $is_marketplace_username = true;
                    break;
                }
            }
            
            if ($is_marketplace_username) {
                // Username là sàn, set shop_id = 0 (KHÔNG check user_info)
                $shop_id = 0;
            } else {
                // Tìm shop thường trong user_info
            $username_query = "SELECT user_id FROM user_info WHERE username = '" . mysqli_real_escape_string($conn, $username) . "' AND ctv = '1' LIMIT 1";
            $username_result = mysqli_query($conn, $username_query);
            
            if (!$username_result || mysqli_num_rows($username_result) == 0) {
                http_response_code(404);
                echo json_encode([
                    "success" => false,
                    "message" => "Không tìm thấy shop với username: " . $username
                ]);
                exit;
            }
            
            $username_data = mysqli_fetch_assoc($username_result);
            $shop_id = intval($username_data['user_id']);
        }
        }
        
        // Xử lý shop sàn (shop_id = 0) và shop thường
        $is_marketplace = ($shop_id == 0);
        $shop_info = array();
        
        if ($is_marketplace) {
            // Sàn (shop_id = 0): Không có trong user_info
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
            
            $shop_info['shop_id'] = 0;
            $shop_info['parent_shop_id'] = 0;
            $shop_info['username'] = '';
            $shop_info['name'] = 'Sàn TMĐT';
            $shop_info['email'] = '';
            $shop_info['mobile'] = '';
            $shop_info['address'] = $warehouse_address;
            $shop_info['about'] = '';
            $shop_info['avatar_url'] = '';
            $shop_info['shop_url'] = 'https://socdo.vn';
            $shop_info['is_ctv'] = 0;
            $shop_info['is_dropship'] = 0;
            $shop_info['is_leader'] = 0;
            $shop_info['created_at'] = 0;
            $shop_info['created_at_formatted'] = '';
            $shop_info['updated_at'] = 0;
            $shop_info['last_login'] = 0;
            $shop_info['last_online'] = 0;
            $shop_info['total_products'] = $product_count;
            $shop_info['is_marketplace'] = true;
            $shop_info['hide_chat'] = true;
        } else {
            // Shop thường: Lấy từ user_info
        $shop_query = "SELECT user_id, shop, username, name, avatar, email, mobile, dia_chi, about, 
                              ctv, dropship, leader, created, date_update, ip_address, logined, end_online
                       FROM user_info 
                       WHERE user_id = '$shop_id' LIMIT 1";
        $shop_result = mysqli_query($conn, $shop_query);
        
        if (!$shop_result || mysqli_num_rows($shop_result) == 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Không tìm thấy shop"
            ]);
            exit;
        }
        
        $shop_data = mysqli_fetch_assoc($shop_result);
        
        // Format thông tin shop cơ bản
        $shop_info['shop_id'] = intval($shop_data['user_id']);
        $shop_info['parent_shop_id'] = intval($shop_data['shop']);
        $shop_info['username'] = $shop_data['username'];
        $shop_info['name'] = $shop_data['name'];
        $shop_info['email'] = $shop_data['email'];
        $shop_info['mobile'] = $shop_data['mobile'];
        $shop_info['address'] = $shop_data['dia_chi'];
        $shop_info['about'] = $shop_data['about'];
        $shop_info['avatar_url'] = !empty($shop_data['avatar']) ? 'https://socdo.vn/' . $shop_data['avatar'] : '';
        $shop_info['shop_url'] = 'https://socdo.vn/shop/' . $shop_data['username'];
        
        // Thông tin vai trò
        $shop_info['is_ctv'] = intval($shop_data['ctv']);
        $shop_info['is_dropship'] = intval($shop_data['dropship']);
        $shop_info['is_leader'] = intval($shop_data['leader']);
        
        // Thông tin thời gian
        $shop_info['created_at'] = intval($shop_data['created']);
        $shop_info['created_at_formatted'] = date('d/m/Y H:i:s', $shop_data['created']);
        $shop_info['updated_at'] = intval($shop_data['date_update']);
        $shop_info['last_login'] = intval($shop_data['logined']);
        $shop_info['last_online'] = intval($shop_data['end_online']);
        
        // Đếm tổng số sản phẩm
        $product_count_query = "SELECT COUNT(*) as total FROM sanpham WHERE shop = '$shop_id' AND status = 1 AND kho > 0 AND active = 0";
        $product_count_result = mysqli_query($conn, $product_count_query);
        $product_count = 0;
        if ($product_count_result) {
            $count_row = mysqli_fetch_assoc($product_count_result);
            $product_count = intval($count_row['total']);
        }
        $shop_info['total_products'] = $product_count;
            $shop_info['is_marketplace'] = false;
            $shop_info['hide_chat'] = false;
        }
        
        // Lấy sản phẩm shop với logic freeship đúng (SHOP LEVEL + PRODUCT LEVEL)
        $products = array();
        if ($include_products) {
            // Xây dựng điều kiện WHERE
            $where_conditions = array();
            $where_conditions[] = "s.shop = '$shop_id'";
            $where_conditions[] = "s.status = 1";
            $where_conditions[] = "s.kho > 0";
            $where_conditions[] = "s.active = 0";
            
            // Filter theo category nếu có
            if ($category_id > 0) {
                $where_conditions[] = "FIND_IN_SET('$category_id', s.cat) > 0";
            }
            
            // Filter theo search keyword nếu có
            if (!empty($search)) {
                $escaped_search = mysqli_real_escape_string($conn, $search);
                $where_conditions[] = "s.tieu_de LIKE '%$escaped_search%'";
            }
            
            $where_clause = implode(' AND ', $where_conditions);
            
            // Với sàn (shop = 0): lấy transport với user_id = 0
            // Với shop thường: lấy transport theo kho_id và shop
            $products_query = "SELECT s.id, s.ma_sanpham, s.tieu_de, s.minh_hoa, s.link, s.cat, s.gia_cu, s.gia_moi, s.gia_ctv,
                                     s.thuong_hieu, s.kho, s.ban, s.view, s.box_banchay, s.box_noibat, s.box_flash, 
                                     s.date_post, s.status,
                                     COALESCE(t.ten_kho, t_san.ten_kho) as warehouse_name, 
                                     COALESCE(tm.tieu_de, tm_san.tieu_de) as province_name,
                                     COALESCE(t.free_ship_all, t_san.free_ship_all) as product_freeship_all, 
                                     COALESCE(t.free_ship_min_order, t_san.free_ship_min_order) as product_freeship_min_order, 
                                     COALESCE(t.free_ship_discount, t_san.free_ship_discount) as product_freeship_discount,
                                     COALESCE(t_shop.free_ship_all, t_san_shop.free_ship_all) as shop_freeship_all, 
                                     COALESCE(t_shop.free_ship_min_order, t_san_shop.free_ship_min_order) as shop_freeship_min_order, 
                                     COALESCE(t_shop.free_ship_discount, t_san_shop.free_ship_discount) as shop_freeship_discount,
                                     COALESCE(prs.total_reviews, 0) AS total_reviews,
                                     COALESCE(prs.average_rating, 0.0) AS average_rating
                              FROM sanpham s
                              LEFT JOIN transport t ON s.kho_id = t.id AND s.shop > 0 AND t.user_id = s.shop
                              LEFT JOIN tinh_moi tm ON t.province = tm.id
                              LEFT JOIN transport t_shop ON s.shop = t_shop.user_id AND s.shop > 0 AND t_shop.is_default = 1
                              LEFT JOIN transport t_san ON t_san.user_id = 0 AND s.shop = 0 AND t_san.is_default = 1
                              LEFT JOIN tinh_moi tm_san ON t_san.province = tm_san.id
                              LEFT JOIN transport t_san_shop ON t_san_shop.user_id = 0 AND s.shop = 0
                              LEFT JOIN product_rating_stats prs ON s.id = prs.product_id AND s.shop = prs.shop_id
                              WHERE $where_clause
                              ORDER BY s.date_post DESC
                              LIMIT $products_limit";
            
            $products_result = mysqli_query($conn, $products_query);
            
            if ($products_result) {
                while ($product = mysqli_fetch_assoc($products_result)) {
                    $product_data = array();
                    $product_data['id'] = intval($product['id']);
                    $product_data['name'] = $product['tieu_de'];
                    $product_data['slug'] = $product['link'];
                    $product_data['price'] = intval($product['gia_moi']);
                    $product_data['old_price'] = intval($product['gia_cu']);
                    $product_data['ctv_price'] = intval($product['gia_ctv']);
                    $product_data['discount_percent'] = 0;
                    
                    // Tính % giảm giá
                    if ($product['gia_cu'] > 0 && $product['gia_moi'] < $product['gia_cu']) {
                        $product_data['discount_percent'] = round((($product['gia_cu'] - $product['gia_moi']) / $product['gia_cu']) * 100);
                    }
                    
                    $product_data['category_ids'] = explode(',', $product['cat']);
                    $product_data['category_ids'] = array_filter(array_map('intval', $product_data['category_ids']));
                    $product_data['brand_id'] = intval($product['thuong_hieu']);
                    $product_data['stock'] = intval($product['kho']);
                    $product_data['sold'] = intval($product['ban']);
                    $product_data['views'] = intval($product['view']);
                    
                    // Rating và reviews từ product_rating_stats (đã JOIN ở trên)
                    $product_data['rating'] = floatval($product['average_rating'] ?? 0.0);
                    $product_data['total_reviews'] = intval($product['total_reviews'] ?? 0);
                    $product_data['reviews_count'] = intval($product['total_reviews'] ?? 0);
                    
                    // Xử lý hình ảnh
                    if (!empty($product['minh_hoa'])) {
                        $product_data['image'] = 'https://socdo.vn/' . $product['minh_hoa'];
                        
                        // Tạo thumbnail
                        $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/sanpham_anh_340x340/', $product['minh_hoa']);
                        $product_data['thumb'] = 'https://socdo.vn/' . $thumb_image;
                    } else {
                        $product_data['image'] = '';
                        $product_data['thumb'] = '';
                    }
                    
                    // Tạo URL sản phẩm
                    $product_data['product_url'] = 'https://socdo.vn/san-pham/' . $product_data['id'] . '/' . $product_data['slug'] . '.html';
                    
                    // Logic voucher
                    $voucher_icon = '';
                    $id_sp = $product_data['id'];
                    $deal_shop = $shop_id;
                    
                    if ($deal_shop > 0) {
                        // Shop thường: Check voucher sản phẩm cụ thể
                    $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('$id_sp', sanpham) AND shop = '$deal_shop' AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                    if (mysqli_num_rows($check_coupon) > 0) {
                        $voucher_icon = 'Voucher';
                    } else {
                        // Check voucher shop
                        $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                        if (mysqli_num_rows($check_coupon_all) > 0) {
                            $voucher_icon = 'Voucher';
                            }
                        }
                    } else {
                        // Sàn (shop = 0): Lấy voucher sàn
                        $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('$id_sp', sanpham) AND shop = 0 AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                        if (mysqli_num_rows($check_coupon) > 0) {
                            $voucher_icon = 'Voucher';
                        } else {
                            // Check voucher sàn cho toàn bộ
                            $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = 0 AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                            if (mysqli_num_rows($check_coupon_all) > 0) {
                                $voucher_icon = 'Voucher';
                            }
                        }
                    }
                    
                    // Logic freeship đúng - kiểm tra cả SHOP LEVEL và PRODUCT LEVEL
                    $freeship_icon = '';
                    
                    // Lấy thông tin freeship từ cả 2 cấp độ
                    $product_mode = intval($product['product_freeship_all'] ?? 0);
                    $product_discount = intval($product['product_freeship_discount'] ?? 0);
                    $product_minOrder = intval($product['product_freeship_min_order'] ?? 0);
                    
                    $shop_mode = intval($product['shop_freeship_all'] ?? 0);
                    $shop_discount = intval($product['shop_freeship_discount'] ?? 0);
                    $shop_minOrder = intval($product['shop_freeship_min_order'] ?? 0);
                    
                    $base_price = $product_data['price'];
                    
                    // Ưu tiên PRODUCT LEVEL trước, nếu không có thì dùng SHOP LEVEL
                    $final_mode = 0;
                    $final_discount = 0;
                    $final_minOrder = 0;
                    
                    if ($product_mode > 0 || $product_discount > 0) {
                        // Có cấu hình PRODUCT LEVEL
                        $final_mode = $product_mode;
                        $final_discount = $product_discount;
                        $final_minOrder = $product_minOrder;
                    } elseif ($shop_mode > 0 || $shop_discount > 0) {
                        // Dùng SHOP LEVEL
                        $final_mode = $shop_mode;
                        $final_discount = $shop_discount;
                        $final_minOrder = $shop_minOrder;
                    }
                    
                    // Áp dụng logic freeship theo mode cuối cùng
                    if ($final_mode === 1) {
                        // Mode 1: Miễn phí ship hoàn toàn (không cần điều kiện)
                        $freeship_icon = 'Freeship 100%';
                    } elseif ($final_mode === 0 && $final_discount > 0 && $final_minOrder > 0) {
                        // Mode 0: Giảm ship theo số tiền cố định (cần đạt min_order)
                        $freeship_icon = 'Giảm ' . number_format($final_discount) . 'đ ship';
                    } elseif ($final_mode === 2 && $final_discount > 0 && $final_minOrder > 0) {
                        // Mode 2: Giảm ship theo % (cần đạt min_order)
                        $freeship_icon = 'Giảm ' . $final_discount . '% ship';
                    } elseif ($final_mode === 3) {
                        // Mode 3: Ưu đãi ship theo sản phẩm cụ thể - cần kiểm tra fee_ship_products
                        // Lấy fee_ship_products từ transport table
                        $fee_ship_query = "SELECT fee_ship_products FROM transport WHERE user_id = '$shop_id' AND is_default = 1 LIMIT 1";
                        $fee_ship_result = mysqli_query($conn, $fee_ship_query);
                        
                        $ship_discount_amount = 0;
                        if ($fee_ship_result && mysqli_num_rows($fee_ship_result) > 0) {
                            $fee_ship_row = mysqli_fetch_assoc($fee_ship_result);
                            $fee_ship_products = $fee_ship_row['fee_ship_products'] ?? '';
                            
                            if (!empty($fee_ship_products)) {
                                $fee_ship_products_array = json_decode($fee_ship_products, true);
                                if (is_array($fee_ship_products_array)) {
                                    foreach ($fee_ship_products_array as $ship_item) {
                                        if (isset($ship_item['sp_id']) && $ship_item['sp_id'] == $product_data['id']) {
                                            // Lấy số tiền hỗ trợ ship cụ thể
                                            if (isset($ship_item['ship_support'])) {
                                                $ship_discount_amount = intval($ship_item['ship_support']);
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Hiển thị số tiền hỗ trợ ship cụ thể
                        if ($ship_discount_amount > 0) {
                            $freeship_icon = 'Hỗ trợ ship ' . number_format($ship_discount_amount) . '₫';
                        }
                    }
                    // Không có freeship nếu không có cấu hình nào
                    
                    // Logic chính hãng - dựa vào thương hiệu có giá trị
                    $chinhhang_icon = '';
                    if (!empty($product['thuong_hieu']) && trim($product['thuong_hieu']) != '') {
                        $chinhhang_icon = 'Chính hãng';
                    }
                    
                    // Thông tin kho
                    $warehouse_name = $product['warehouse_name'] ?? '';
                    $province_name = $product['province_name'] ?? '';
                    
                    // Badges
                    $badges = array();
                    if ($product['box_banchay'] == 1) $badges[] = 'Bán chạy';
                    if ($product['box_noibat'] == 1) $badges[] = 'Nổi bật';
                    if ($product['box_flash'] == 1) $badges[] = 'Flash sale';
                    if ($product_data['discount_percent'] > 0) $badges[] = 'Giảm ' . $product_data['discount_percent'] . '%';
                    $product_data['badges'] = $badges;
                    
                    // Thêm các icon mới
                    $product_data['voucher_icon'] = $voucher_icon;
                    $product_data['freeship_icon'] = $freeship_icon;
                    $product_data['chinhhang_icon'] = $chinhhang_icon;
                    $product_data['warehouse_name'] = $warehouse_name;
                    $product_data['province_name'] = $province_name;
                    
                    // Thông tin bổ sung
                    $product_data['is_bestseller'] = intval($product['box_banchay']);
                    $product_data['is_featured'] = intval($product['box_noibat']);
                    $product_data['is_flash_sale'] = intval($product['box_flash']);
                    $product_data['created_at'] = intval($product['date_post']);
                    
                    // Format giá
                    $product_data['price_formatted'] = number_format($product_data['price'], 0, ',', '.') . ' ₫';
                    $product_data['old_price_formatted'] = $product_data['old_price'] > 0 ? number_format($product_data['old_price'], 0, ',', '.') . ' ₫' : '';
                    $product_data['ctv_price_formatted'] = number_format($product_data['ctv_price'], 0, ',', '.') . ' ₫';
                    
                    $products[] = $product_data;
                }
            }
        }
        
        // Lấy flash sale shop (bỏ flash sale cho sàn)
        $flash_sales = array();
        if ($include_flash_sale && $shop_id > 0) {
            $flash_sale_query = "SELECT id, tieu_de, main_product, sub_product, date_start, date_end, 
                                        loai, date_post, status, timeline
                                 FROM deal 
                                 WHERE shop = '$shop_id' AND loai = 'flash_sale' 
                                 AND '$current_time' BETWEEN date_start AND date_end
                                 AND status = '2'
                                 ORDER BY date_post DESC";
            
            $flash_sale_result = mysqli_query($conn, $flash_sale_query);
            
            if ($flash_sale_result) {
                while ($flash_sale = mysqli_fetch_assoc($flash_sale_result)) {
                    $flash_sale_data = array();
                    $flash_sale_data['id'] = intval($flash_sale['id']);
                    $flash_sale_data['title'] = $flash_sale['tieu_de'];
                    $flash_sale_data['main_products'] = explode(',', $flash_sale['main_product']);
                    $flash_sale_data['main_products'] = array_filter(array_map('intval', $flash_sale_data['main_products']));
                    $sub_products_raw = json_decode($flash_sale['sub_product'], true);
                    $sub_products_enhanced = array();
                    
                    // Lấy thông tin chi tiết sản phẩm cho flash sale
                    foreach ($sub_products_raw as $product_id => $variants) {
                        $product_detail_query = "SELECT s.id, s.tieu_de, s.minh_hoa, s.link, s.cat, s.gia_cu, s.gia_moi, s.gia_ctv,
                                                       s.thuong_hieu, s.kho, s.ban, s.view, s.box_banchay, s.box_noibat, s.box_flash, 
                                                       s.date_post, s.status,
                                                       t.ten_kho as warehouse_name, tm.tieu_de as province_name,
                                                       t.free_ship_all as product_freeship_all, t.free_ship_min_order as product_freeship_min_order, t.free_ship_discount as product_freeship_discount,
                                                       t_shop.free_ship_all as shop_freeship_all, t_shop.free_ship_min_order as shop_freeship_min_order, t_shop.free_ship_discount as shop_freeship_discount,
                                                       COALESCE(prs.total_reviews, 0) AS total_reviews,
                                                       COALESCE(prs.average_rating, 0.0) AS average_rating
                                                FROM sanpham s
                                                LEFT JOIN transport t ON s.kho_id = t.id AND t.user_id = s.shop
                                                LEFT JOIN transport t_shop ON s.shop = t_shop.user_id AND t_shop.is_default = 1
                                                LEFT JOIN tinh_moi tm ON t.province = tm.id
                                                LEFT JOIN product_rating_stats prs ON s.id = prs.product_id AND s.shop = prs.shop_id
                                                WHERE s.id = '$product_id' AND s.shop = '$shop_id'
                                                LIMIT 1";
                        
                        $product_detail_result = mysqli_query($conn, $product_detail_query);
                        if ($product_detail_result && mysqli_num_rows($product_detail_result) > 0) {
                            $product_detail = mysqli_fetch_assoc($product_detail_result);
                            
                            // Tính % giảm giá
                            $discount_percent = 0;
                            if ($product_detail['gia_cu'] > 0 && $product_detail['gia_moi'] < $product_detail['gia_cu']) {
                                $discount_percent = round((($product_detail['gia_cu'] - $product_detail['gia_moi']) / $product_detail['gia_cu']) * 100);
                            }
                            
                            // Logic voucher cho flash sale product
                            $voucher_icon = '';
                            $deal_shop = $shop_id;
                            
                            // Check voucher sản phẩm cụ thể
                            $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('$product_id', sanpham) AND shop = '$deal_shop' AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                            if (mysqli_num_rows($check_coupon) > 0) {
                                $voucher_icon = 'Voucher';
                            } else {
                                // Check voucher shop
                                $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                                if (mysqli_num_rows($check_coupon_all) > 0) {
                                    $voucher_icon = 'Voucher';
                                }
                            }
                            
                            // Logic freeship cho flash sale product - kiểm tra cả SHOP LEVEL và PRODUCT LEVEL
                            $freeship_icon = '';
                            
                            // Lấy thông tin freeship từ cả 2 cấp độ
                            $product_mode = intval($product_detail['product_freeship_all'] ?? 0);
                            $product_discount = intval($product_detail['product_freeship_discount'] ?? 0);
                            $product_minOrder = intval($product_detail['product_freeship_min_order'] ?? 0);
                            
                            $shop_mode = intval($product_detail['shop_freeship_all'] ?? 0);
                            $shop_discount = intval($product_detail['shop_freeship_discount'] ?? 0);
                            $shop_minOrder = intval($product_detail['shop_freeship_min_order'] ?? 0);
                            
                            $base_price = $product_detail['gia_moi'];
                            
                            // Ưu tiên PRODUCT LEVEL trước, nếu không có thì dùng SHOP LEVEL
                            $final_mode = 0;
                            $final_discount = 0;
                            $final_minOrder = 0;
                            
                            if ($product_mode > 0 || $product_discount > 0) {
                                // Có cấu hình PRODUCT LEVEL
                                $final_mode = $product_mode;
                                $final_discount = $product_discount;
                                $final_minOrder = $product_minOrder;
                            } elseif ($shop_mode > 0 || $shop_discount > 0) {
                                // Dùng SHOP LEVEL
                                $final_mode = $shop_mode;
                                $final_discount = $shop_discount;
                                $final_minOrder = $shop_minOrder;
                            }
                            
                            // Áp dụng logic freeship theo mode cuối cùng
                            if ($final_mode === 1) {
                                // Mode 1: Miễn phí ship hoàn toàn (không cần điều kiện)
                                $freeship_icon = 'Freeship 100%';
                            } elseif ($final_mode === 0 && $final_discount > 0 && $final_minOrder > 0) {
                                // Mode 0: Giảm ship theo số tiền cố định (cần đạt min_order)
                                $freeship_icon = 'Giảm ' . number_format($final_discount) . 'đ ship';
                            } elseif ($final_mode === 2 && $final_discount > 0 && $final_minOrder > 0) {
                                // Mode 2: Giảm ship theo % (cần đạt min_order)
                                $freeship_icon = 'Giảm ' . $final_discount . '% ship';
                            } elseif ($final_mode === 3) {
                                // Mode 3: Ưu đãi ship theo sản phẩm cụ thể - cần kiểm tra fee_ship_products
                                // Lấy fee_ship_products từ transport table
                                $fee_ship_query = "SELECT fee_ship_products FROM transport WHERE user_id = '$shop_id' AND is_default = 1 LIMIT 1";
                                $fee_ship_result = mysqli_query($conn, $fee_ship_query);
                                
                                $ship_discount_amount = 0;
                                if ($fee_ship_result && mysqli_num_rows($fee_ship_result) > 0) {
                                    $fee_ship_row = mysqli_fetch_assoc($fee_ship_result);
                                    $fee_ship_products = $fee_ship_row['fee_ship_products'] ?? '';
                                    
                                    if (!empty($fee_ship_products)) {
                                        $fee_ship_products_array = json_decode($fee_ship_products, true);
                                        if (is_array($fee_ship_products_array)) {
                                            foreach ($fee_ship_products_array as $ship_item) {
                                                if (isset($ship_item['sp_id']) && $ship_item['sp_id'] == $product_id) {
                                                    // Lấy số tiền hỗ trợ ship cụ thể
                                                    if (isset($ship_item['ship_support'])) {
                                                        $ship_discount_amount = intval($ship_item['ship_support']);
                                                    }
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Hiển thị số tiền hỗ trợ ship cụ thể
                                if ($ship_discount_amount > 0) {
                                    $freeship_icon = 'Hỗ trợ ship ' . number_format($ship_discount_amount) . '₫';
                                }
                            }
                            // Không có freeship nếu không có cấu hình nào
                            
                            // Logic chính hãng
                            $chinhhang_icon = '';
                            if (!empty($product_detail['thuong_hieu']) && trim($product_detail['thuong_hieu']) != '') {
                                $chinhhang_icon = 'Chính hãng';
                            }
                            
                            // Thông tin kho
                            $warehouse_name = $product_detail['warehouse_name'] ?? '';
                            $province_name = $product_detail['province_name'] ?? '';
                            
                            // Xử lý hình ảnh
                            $image_url = '';
                            if (!empty($product_detail['minh_hoa'])) {
                                $image_url = 'https://socdo.vn/' . $product_detail['minh_hoa'];
                            }
                            
                            // Tạo URL sản phẩm
                            $product_url = 'https://socdo.vn/san-pham/' . $product_id . '/' . $product_detail['link'] . '.html';
                            
                            $sub_products_enhanced[$product_id] = array(
                                'product_info' => array(
                                    'id' => intval($product_id),
                                    'name' => $product_detail['tieu_de'],
                                    'slug' => $product_detail['link'],
                                    'image' => $image_url,
                                    'product_url' => $product_url,
                                    'category_ids' => explode(',', $product_detail['cat']),
                                    'brand_id' => intval($product_detail['thuong_hieu']),
                                    'stock' => intval($product_detail['kho']),
                                    'sold' => intval($product_detail['ban']),
                                    'views' => intval($product_detail['view']),
                                    'discount_percent' => $discount_percent,
                                    'voucher_icon' => $voucher_icon,
                                    'freeship_icon' => $freeship_icon,
                                    'chinhhang_icon' => $chinhhang_icon,
                                    'warehouse_name' => $warehouse_name,
                                    'province_name' => $province_name,
                                    'rating' => floatval($product_detail['average_rating'] ?? 0.0),
                                    'total_reviews' => intval($product_detail['total_reviews'] ?? 0),
                                ),
                                'variants' => $variants
                            );
                        }
                    }
                    
                    $flash_sale_data['sub_products'] = $sub_products_enhanced;
                    $flash_sale_data['start_time'] = intval($flash_sale['date_start']);
                    $flash_sale_data['end_time'] = intval($flash_sale['date_end']);
                    $flash_sale_data['timeline'] = $flash_sale['timeline'];
                    $flash_sale_data['created_at'] = intval($flash_sale['date_post']);
                    
                    // Tính thời gian còn lại
                    $time_left = $flash_sale_data['end_time'] - $current_time;
                    $flash_sale_data['time_left'] = max(0, $time_left);
                    $flash_sale_data['is_active'] = $time_left > 0 ? true : false;
                    
                    $flash_sales[] = $flash_sale_data;
                }
            }
        }
        
        // Lấy voucher shop (hoặc voucher sàn nếu shop_id = 0)
        $vouchers = array();
        if ($include_vouchers) {
            $voucher_query = "SELECT id, ma, giam, giam_toi_da, loai, kieu, sanpham, dieu_kien,
                                     start, expired, status, mota, img_loai, min_price, max_price,
                                     allow_combination, max_uses_per_user, max_global_uses, 
                                     current_uses, date_post
                              FROM coupon 
                              WHERE shop = '$shop_id' AND status = '2'
                              AND '$current_time' BETWEEN start AND expired
                              ORDER BY date_post DESC";
            
            $voucher_result = mysqli_query($conn, $voucher_query);
            
            if ($voucher_result) {
                while ($voucher = mysqli_fetch_assoc($voucher_result)) {
                    $voucher_data = array();
                    $voucher_data['id'] = intval($voucher['id']);
                    $voucher_data['code'] = $voucher['ma'];
                    $voucher_data['discount_value'] = intval($voucher['giam']);
                    $voucher_data['max_discount'] = intval($voucher['giam_toi_da']);
                    $voucher_data['discount_type'] = $voucher['loai']; // 'phantram' hoặc 'tru'
                    $voucher_data['apply_type'] = $voucher['kieu']; // 'all' hoặc 'sanpham'
                    $voucher_data['product_ids'] = explode(',', $voucher['sanpham']);
                    $voucher_data['product_ids'] = array_filter(array_map('intval', $voucher_data['product_ids']));
                    $voucher_data['min_order_value'] = intval($voucher['dieu_kien']);
                    $voucher_data['start_time'] = intval($voucher['start']);
                    $voucher_data['end_time'] = intval($voucher['expired']);
                    $voucher_data['description'] = $voucher['mota'];
                    $voucher_data['image_url'] = !empty($voucher['img_loai']) ? 'https://socdo.vn/' . $voucher['img_loai'] : '';
                    $voucher_data['min_price'] = intval($voucher['min_price']);
                    $voucher_data['max_price'] = intval($voucher['max_price']);
                    $voucher_data['allow_combination'] = intval($voucher['allow_combination']);
                    $voucher_data['max_uses_per_user'] = intval($voucher['max_uses_per_user']);
                    $voucher_data['max_global_uses'] = intval($voucher['max_global_uses']);
                    $voucher_data['current_uses'] = intval($voucher['current_uses']);
                    $voucher_data['created_at'] = intval($voucher['date_post']);
                    
                    // Tính thời gian còn lại
                    $time_left = $voucher_data['end_time'] - $current_time;
                    $voucher_data['time_left'] = max(0, $time_left);
                    $voucher_data['is_active'] = $time_left > 0 ? true : false;
                    
                    // Format mô tả giảm giá
                    if ($voucher_data['discount_type'] == 'phantram') {
                        $voucher_data['discount_description'] = 'Giảm ' . $voucher_data['discount_value'] . '%';
                        if ($voucher_data['max_discount'] > 0) {
                            $voucher_data['discount_description'] .= ' (tối đa ' . number_format($voucher_data['max_discount']) . 'đ)';
                        }
                    } else {
                        $voucher_data['discount_description'] = 'Giảm ' . number_format($voucher_data['discount_value']) . 'đ';
                    }
                    
                    $vouchers[] = $voucher_data;
                }
            }
        }
        
        // Lấy địa chỉ kho (với sàn: user_id = 0)
        $warehouses = array();
        if ($include_warehouses) {
            $warehouse_query = "SELECT t.id, t.ma_kho, t.ten_kho, t.username, t.fullname, t.mobile,
                                       t.province, t.district, t.ward, t.address_detail, t.is_default,
                                       t.is_pickup, t.is_return, t.latitude, t.longitude,
                                       t.free_ship_all, t.free_ship_min_order, t.free_ship_discount,
                                       tm.tieu_de as province_name,
                                       hm.tieu_de as district_name,
                                       xm.tieu_de as ward_name
                                FROM transport t
                                LEFT JOIN tinh_moi tm ON t.province = tm.id
                                LEFT JOIN huyen_moi hm ON t.district = hm.id
                                LEFT JOIN xa_moi xm ON t.ward = xm.id
                                WHERE t.user_id = '$shop_id'
                                ORDER BY t.is_default DESC, t.id ASC";
            
            $warehouse_result = mysqli_query($conn, $warehouse_query);
            
            if ($warehouse_result) {
                while ($warehouse = mysqli_fetch_assoc($warehouse_result)) {
                    $warehouse_data = array();
                    $warehouse_data['id'] = intval($warehouse['id']);
                    $warehouse_data['warehouse_code'] = $warehouse['ma_kho'];
                    $warehouse_data['warehouse_name'] = $warehouse['ten_kho'];
                    $warehouse_data['contact_name'] = $warehouse['fullname'];
                    $warehouse_data['contact_phone'] = $warehouse['mobile'];
                    $warehouse_data['is_default'] = intval($warehouse['is_default']);
                    $warehouse_data['is_pickup'] = intval($warehouse['is_pickup']);
                    $warehouse_data['is_return'] = intval($warehouse['is_return']);
                    $warehouse_data['latitude'] = floatval($warehouse['latitude']);
                    $warehouse_data['longitude'] = floatval($warehouse['longitude']);
                    
                    // Địa chỉ
                    $warehouse_data['address_detail'] = $warehouse['address_detail'];
                    $warehouse_data['province_id'] = intval($warehouse['province']);
                    $warehouse_data['district_id'] = intval($warehouse['district']);
                    $warehouse_data['ward_id'] = intval($warehouse['ward']);
                    $warehouse_data['province_name'] = $warehouse['province_name'];
                    $warehouse_data['district_name'] = $warehouse['district_name'];
                    $warehouse_data['ward_name'] = $warehouse['ward_name'];
                    
                    // Tạo địa chỉ đầy đủ
                    $full_address = $warehouse['address_detail'];
                    if (!empty($warehouse['ward_name'])) $full_address .= ', ' . $warehouse['ward_name'];
                    if (!empty($warehouse['district_name'])) $full_address .= ', ' . $warehouse['district_name'];
                    if (!empty($warehouse['province_name'])) $full_address .= ', ' . $warehouse['province_name'];
                    $warehouse_data['full_address'] = $full_address;
                    
                    // Thông tin freeship
                    $warehouse_data['free_ship_mode'] = intval($warehouse['free_ship_all']);
                    $warehouse_data['free_ship_min_order'] = intval($warehouse['free_ship_min_order']);
                    $warehouse_data['free_ship_discount'] = intval($warehouse['free_ship_discount']);
                    
                    // Mô tả freeship
                    $freeship_description = '';
                    if ($warehouse['free_ship_all'] == 0 && $warehouse['free_ship_discount'] > 0) {
                        $freeship_description = 'Giảm ' . number_format($warehouse['free_ship_discount']) . 'đ ship';
                    } elseif ($warehouse['free_ship_all'] == 1) {
                        $freeship_description = 'Freeship 100%';
                    } elseif ($warehouse['free_ship_all'] == 2 && $warehouse['free_ship_discount'] > 0) {
                        $freeship_description = 'Giảm ' . $warehouse['free_ship_discount'] . '% ship';
                    } elseif ($warehouse['free_ship_all'] == 3) {
                        $freeship_description = 'Ưu đãi ship theo sản phẩm';
                    }
                    $warehouse_data['freeship_description'] = $freeship_description;
                    
                    $warehouses[] = $warehouse_data;
                }
            }
        }
        
        // Lấy danh mục sản phẩm shop (với sàn: lấy từ category_sanpham)
        $categories = array();
        if ($include_categories) {
            if ($shop_id > 0) {
                // Shop thường: Lấy từ category_sanpham_shop
            $category_query = "SELECT cs.cat_id, cs.cat_icon, cs.cat_tieude, cs.cat_noidung, 
                                      cs.cat_main, cs.cat_index, cs.cat_link, cs.cat_img, 
                                      cs.cat_img_banner, cs.cat_img_left, cs.cat_title, 
                                      cs.cat_description, cs.cat_thutu, cs.cat_id_socdo,
                                      c.cat_tieude as socdo_cat_name,
                                      c.cat_minhhoa as socdo_cat_image,
                                      (SELECT COUNT(*) FROM sanpham WHERE shop = '$shop_id' AND status = 1 AND kho > 0 AND active = 0 AND FIND_IN_SET(cs.cat_id, cat) > 0) as product_count
                               FROM category_sanpham_shop cs
                               LEFT JOIN category_sanpham c ON FIND_IN_SET(c.cat_id, cs.cat_id_socdo) > 0
                               WHERE cs.shop = '$shop_id'
                               ORDER BY product_count DESC, cs.cat_thutu ASC";
            } else {
                // Sàn: Lấy từ category_sanpham
                $category_query = "SELECT cat_id, cat_icon, cat_tieude as cat_tieude, cat_noidung, 
                                          cat_main as cat_main, cat_index, cat_link, cat_minhhoa as cat_img, 
                                          '' as cat_img_banner, '' as cat_img_left, cat_title, 
                                          cat_description, cat_thutu, '' as cat_id_socdo,
                                          cat_tieude as socdo_cat_name,
                                          cat_minhhoa as socdo_cat_image,
                                          (SELECT COUNT(*) FROM sanpham WHERE shop = 0 AND status = 1 AND kho > 0 AND active = 0 AND FIND_IN_SET(cat_id, cat) > 0) as product_count
                                   FROM category_sanpham
                                   ORDER BY product_count DESC, cat_thutu ASC";
            }
            
            $category_result = mysqli_query($conn, $category_query);
            
            if ($category_result) {
                while ($category = mysqli_fetch_assoc($category_result)) {
                    $category_data = array();
                    $category_data['id'] = intval($category['cat_id']);
                    $category_data['icon'] = $category['cat_icon'];
                    $category_data['title'] = $category['cat_tieude'];
                    $category_data['description'] = $category['cat_noidung'];
                    $category_data['parent_id'] = intval($category['cat_main']);
                    $category_data['is_index'] = intval($category['cat_index']);
                    $category_data['link'] = $category['cat_link'];
                    // Ưu tiên lấy ảnh từ category_sanpham.cat_minhhoa, nếu không có thì dùng category_sanpham_shop.cat_img
                    $category_image = '';
                    if (!empty($category['socdo_cat_image'])) {
                        $category_image = 'https://socdo.vn/' . $category['socdo_cat_image'];
                    } elseif (!empty($category['cat_img'])) {
                        $category_image = 'https://socdo.vn/' . $category['cat_img'];
                    }
                    $category_data['image'] = $category_image;
                    $category_data['banner_image'] = !empty($category['cat_img_banner']) ? 'https://socdo.vn/' . $category['cat_img_banner'] : '';
                    $category_data['left_image'] = !empty($category['cat_img_left']) ? 'https://socdo.vn/' . $category['cat_img_left'] : '';
                    $category_data['seo_title'] = $category['cat_title'];
                    $category_data['seo_description'] = $category['cat_description'];
                    $category_data['order'] = intval($category['cat_thutu']);
                    if (!empty($category['cat_id_socdo'])) {
                    $category_data['socdo_category_ids'] = explode(',', $category['cat_id_socdo']);
                    $category_data['socdo_category_ids'] = array_filter(array_map('intval', $category_data['socdo_category_ids']));
                    } else {
                        $category_data['socdo_category_ids'] = array();
                    }
                    $category_data['socdo_category_name'] = $category['socdo_cat_name'];
                    
                    // Tạo URL danh mục
                    if ($shop_id > 0) {
                        $category_data['category_url'] = 'https://socdo.vn/shop/' . $shop_info['username'] . '/danh-muc/' . $category_data['id'] . '.html';
                    } else {
                        $category_data['category_url'] = 'https://socdo.vn/danh-muc/' . $category_data['id'] . '/' . $category_data['link'] . '.html';
                    }
                    
                    // Đếm số lượng sản phẩm thuộc category
                    $category_data['product_count'] = intval($category['product_count']);
                    
                    $categories[] = $category_data;
                }
            }
        }
        
        $response = [
            "success" => true,
            "message" => "Lấy thông tin shop thành công",
            "data" => [
                "shop_info" => $shop_info,
                "products" => $products,
                "flash_sales" => $flash_sales,
                "vouchers" => $vouchers,
                "warehouses" => $warehouses,
                "categories" => $categories,
                "statistics" => [
                    "total_products" => $product_count,
                    "total_flash_sales" => count($flash_sales),
                    "total_vouchers" => count($vouchers),
                    "total_warehouses" => count($warehouses),
                    "total_categories" => count($categories)
                ],
                "parameters" => [
                    "shop_id" => $shop_id,
                    "username" => $username,
                    "include_products" => $include_products,
                    "include_flash_sale" => $include_flash_sale,
                    "include_vouchers" => $include_vouchers,
                    "include_warehouses" => $include_warehouses,
                    "include_categories" => $include_categories,
                    "products_limit" => $products_limit
                ]
            ]
        ];
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
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
