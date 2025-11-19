<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
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
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        $product_id = isset($_GET['product_id']) ? intval($_GET['product_id']) : 0;
        $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : 0;
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
        $category_id = isset($_GET['category_id']) ? intval($_GET['category_id']) : 0;
        $sort = isset($_GET['sort']) ? trim($_GET['sort']) : 'time-desc'; // time-desc, time-asc, price-asc, price-desc
        $exclude_product_id = isset($_GET['exclude_product_id']) ? intval($_GET['exclude_product_id']) : 0;
        
        // Validate parameters
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        if ($page < 1) $page = 1;
        if ($limit < 1 || $limit > 500) $limit = 500;
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        
        // Phải có product_id hoặc shop_id
        if ($product_id <= 0 && $shop_id <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Phải cung cấp product_id hoặc shop_id"
            ]);
            exit;
        }
        
        $offset = ($page - 1) * $limit;
        
        // Nếu có product_id, lấy shop_id từ sản phẩm đó
        if ($product_id > 0) {
            $product_query = "SELECT shop FROM sanpham WHERE id = '$product_id' LIMIT 1";
            $product_result = mysqli_query($conn, $product_query);
            
            if (!$product_result || mysqli_num_rows($product_result) == 0) {
                http_response_code(404);
                echo json_encode([
                    "success" => false,
                    "message" => "Không tìm thấy sản phẩm"
                ]);
                exit;
            }
            
            $product_info = mysqli_fetch_assoc($product_result);
            $shop_id = intval($product_info['shop']);
        }
        
        // Xây dựng WHERE clause
        // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
        //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
        $where_conditions = array(
            "sanpham.status = 1", 
            "sanpham.shop = '$shop_id'", 
            "sanpham.active = 0",
            "sanpham.kho >= 0",
            "((NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id) AND sanpham.kho > 0) OR EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id AND pl.kho_sanpham_socdo > 0))"
        );
    
        // Loại trừ sản phẩm hiện tại nếu có
        if ($exclude_product_id > 0) {
            $where_conditions[] = "sanpham.id != '$exclude_product_id'";
        } elseif ($product_id > 0) {
            $where_conditions[] = "sanpham.id != '$product_id'";
        }
        
        // Lọc theo danh mục
        if ($category_id > 0) {
            $where_conditions[] = "FIND_IN_SET('$category_id', sanpham.cat) > 0";
        }
        
        $where_clause = "WHERE " . implode(" AND ", $where_conditions);
        
        // Đếm tổng số sản phẩm
        $count_query = "SELECT COUNT(*) as total FROM sanpham $where_clause";
        $count_result = mysqli_query($conn, $count_query);
        $total_records = 0;
        if ($count_result) {
            $count_row = mysqli_fetch_assoc($count_result);
            $total_records = $count_row['total'];
        }
        
        $total_pages = ceil($total_records / $limit);
        
        // Xử lý sắp xếp
        $allowed_sorts = ['time-desc', 'time-asc', 'price-asc', 'price-desc'];
        $sort = in_array($sort, $allowed_sorts) ? $sort : 'time-desc';
        
        switch ($sort) {
            case 'time-desc':
                $order_by = "ORDER BY sanpham.id DESC";
                break;
            case 'time-asc':
                $order_by = "ORDER BY sanpham.id ASC";
                break;
            case 'price-asc':
                $order_by = "ORDER BY sanpham.gia_moi ASC";
                break;
            case 'price-desc':
                $order_by = "ORDER BY sanpham.gia_moi DESC";
                break;
            default:
                $order_by = "ORDER BY sanpham.id DESC";
        }
        
        // Lấy thông tin shop
        $shop_query = "SELECT user_id, username, name, avatar, dia_chi FROM user_info WHERE user_id = '$shop_id' LIMIT 1";
        $shop_result = mysqli_query($conn, $shop_query);
        $shop_info = null;
        if ($shop_result && mysqli_num_rows($shop_result) > 0) {
            $shop_info = mysqli_fetch_assoc($shop_result);
            $shop_info['id'] = intval($shop_info['user_id']);
            $shop_info['fullname'] = $shop_info['name']; // Map name thành fullname
            $shop_info['address'] = $shop_info['dia_chi']; // Map dia_chi thành address
            if (!empty($shop_info['avatar'])) {
                $shop_info['avatar_url'] = getImageUrlWithCDN($shop_info['avatar']);
            } else {
                $shop_info['avatar_url'] = '';
            }
        }
        
        // Lấy danh sách sản phẩm cùng shop
        // Sử dụng LEFT JOIN với product_rating_stats (đã có index) thay vì subquery để tối ưu performance
        $products_query = "
            SELECT 
                sanpham.*,
                th.tieu_de as brand_name,
                th.anh_thuong_hieu as brand_logo,
                t.ten_kho AS warehouse_name,
                tm.tieu_de AS province_name,
                COALESCE(prs.total_reviews, 0) AS total_reviews,
                COALESCE(prs.average_rating, 0) AS average_rating
            FROM sanpham 
            LEFT JOIN thuong_hieu th ON th.id = sanpham.thuong_hieu
            LEFT JOIN transport t ON sanpham.kho_id = t.id
            LEFT JOIN tinh_moi tm ON t.province = tm.id
            LEFT JOIN product_rating_stats prs ON sanpham.id = prs.product_id AND sanpham.shop = prs.shop_id
            $where_clause 
            $order_by 
            LIMIT $offset, $limit
        ";
        
        $products_result = mysqli_query($conn, $products_query);
        
        if (!$products_result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database"
            ]);
            exit;
        }
        
        $products = array();
        
        while ($product = mysqli_fetch_assoc($products_result)) {
            // Format dữ liệu sản phẩm
            $product_data = array();
            $product_data['id'] = intval($product['id']);
            $product_data['name'] = $product['tieu_de'];
            $product_data['slug'] = $product['link'];
            $product_data['price'] = intval($product['gia_moi']);
            $product_data['old_price'] = intval($product['gia_cu']);
            $product_data['discount_percent'] = 0;
            
            // Tính % giảm giá
            if ($product['gia_cu'] > 0 && $product['gia_moi'] < $product['gia_cu']) {
                $product_data['discount_percent'] = round((($product['gia_cu'] - $product['gia_moi']) / $product['gia_cu']) * 100);
            }
            
            $product_data['shop_id'] = intval($product['shop']);
            $product_data['category_ids'] = explode(',', $product['cat']);
            $product_data['category_ids'] = array_filter(array_map('intval', $product_data['category_ids']));
            $product_data['brand_id'] = intval($product['thuong_hieu']);
            $product_data['brand_name'] = $product['brand_name'] ?: '';
            $product_data['brand_logo'] = $product['brand_logo'] ? getImageUrlWithCDN($product['brand_logo']) : '';
            
            // Xử lý hình ảnh
            if (!empty($product['minh_hoa'])) {
                $product_data['image'] = getImageUrlWithCDN($product['minh_hoa']);
                
                // Tạo thumbnail
                $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/sanpham_anh_340x340/', $product['minh_hoa']);
                $product_data['thumb'] = getImageUrlWithCDN($thumb_image);
            } else {
                $product_data['image'] = '';
                $product_data['thumb'] = '';
            }
            
            // Tạo URL sản phẩm
            $product_data['product_url'] = 'https://socdo.vn/san-pham/' . $product_data['id'] . '/' . $product_data['slug'] . '.html';
            
            // Thông tin voucher
            $voucher_info = array();
            $voucher_info['has_voucher'] = false;
            $voucher_info['voucher_details'] = '';
            
            $current_time = time();
            
            // Kiểm tra voucher cho sản phẩm cụ thể - Logic chuẩn với hệ thống
            $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('{$product['id']}', sanpham) AND shop = '$shop_id' AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
            $voucher_icon = '';
            if (mysqli_num_rows($check_coupon) > 0) {
                $voucher_icon = 'Voucher';
            } else {
                // Kiểm tra voucher cho toàn shop
                $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$shop_id' AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                if (mysqli_num_rows($check_coupon_all) > 0) {
                    $voucher_icon = 'Voucher';
                }
            }
            
            $product_data['voucher_info'] = $voucher_info;
            
            // Thông tin ship - Logic chuẩn với 4 mode
            $shipping_info = array();
            $shipping_info['has_free_shipping'] = false;
            $shipping_info['free_ship_details'] = '';
            
            $check_freeship = mysqli_query($conn, "SELECT id, free_ship_all, free_ship_discount, free_ship_min_order, fee_ship_products FROM transport WHERE user_id = '$shop_id' AND (free_ship_all > 0 OR free_ship_discount > 0) LIMIT 1");
            $freeship_icon = '';
            if ($check_freeship && mysqli_num_rows($check_freeship) > 0) {
                $ship_data = mysqli_fetch_assoc($check_freeship);
                $mode = intval($ship_data['free_ship_all'] ?? 0);
                $discount = intval($ship_data['free_ship_discount'] ?? 0);
                $minOrder = intval($ship_data['free_ship_min_order'] ?? 0);
                
                // Lấy giá sản phẩm để kiểm tra điều kiện min_order
                $base_price = $product_data['price'];
                
                // Mode 0: Giảm cố định (VD: -15,000đ) - Cần kiểm tra điều kiện min_order
                if ($mode === 0 && $discount > 0 && $base_price >= $minOrder) {
                    $freeship_icon = 'Giảm ' . number_format($discount) . 'đ ship';
                }
                // Mode 1: Freeship toàn bộ (100%)
                elseif ($mode === 1) {
                    $freeship_icon = 'Freeship 100%';
                }
                // Mode 2: Giảm theo % (VD: -50%) - Cần kiểm tra điều kiện min_order
                elseif ($mode === 2 && $discount > 0 && $base_price >= $minOrder) {
                    $freeship_icon = 'Giảm ' . intval($discount) . '% ship';
                }
                // Mode 3: Ưu đãi ship theo sản phẩm cụ thể - cần kiểm tra fee_ship_products
                elseif ($mode === 3) {
                    $fee_ship_products = $ship_data['fee_ship_products'] ?? '';
                    $ship_discount_amount = 0;
                    
                    if (!empty($fee_ship_products)) {
                        $fee_ship_products_array = json_decode($fee_ship_products, true);
                        if (is_array($fee_ship_products_array)) {
                            foreach ($fee_ship_products_array as $ship_item) {
                                if (isset($ship_item['sp_id']) && $ship_item['sp_id'] == $product['id']) {
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
                        $freeship_icon = 'Hỗ trợ ship ' . number_format($ship_discount_amount) . '₫';
                    }
                }
                // Mode 0 với discount = 0: Freeship cơ bản
                elseif ($mode === 0 && $discount == 0) {
                    $freeship_icon = 'Freeship';
                }
                
                $shipping_info['has_free_shipping'] = !empty($freeship_icon);
                $shipping_info['free_ship_details'] = $freeship_icon;
                $shipping_info['min_order_for_free_ship'] = $minOrder;
            }
            
            $chinhhang_icon = 'Chính hãng';
            
            $product_data['shipping_info'] = $shipping_info;
            
            // Tags/Badges
            $badges = array();
            if ($product_data['discount_percent'] > 0) {
                $badges[] = 'Giảm ' . $product_data['discount_percent'] . '%';
            }
            if (!empty($voucher_icon)) {
                $badges[] = $voucher_icon;
            }
            if (!empty($freeship_icon)) {
                $badges[] = $freeship_icon;
            }
            if ($product['box_flash'] == 1) {
                $badges[] = 'Flash Sale';
            }
            $badges[] = $chinhhang_icon;
            $product_data['badges'] = $badges;
            
            // Thêm các field mới
            $product_data['voucher_icon'] = $voucher_icon;
            $product_data['freeship_icon'] = $freeship_icon;
            $product_data['chinhhang_icon'] = $chinhhang_icon;
            $product_data['warehouse_name'] = $product['warehouse_name'] ?? '';
            $product_data['province_name'] = $product['province_name'] ?? '';
            
            // Thông tin bổ sung
            $product_data['is_authentic'] = 0; // Không có trường chinhhang trong DB thực tế
            $product_data['is_featured'] = intval($product['box_noibat']);
            $product_data['is_trending'] = 0; // Không có trường xu_huong trong DB thực tế
            $product_data['is_flash_sale'] = intval($product['box_flash']);
            $product_data['created_at'] = intval($product['date_post']);
            $product_data['updated_at'] = intval($product['date_post']); // Không có trường date_update trong DB thực tế
            
            // Lấy rating và reviews từ product_rating_stats (đã JOIN ở trên)
            $product_data['rating'] = floatval($product['average_rating']);
            $product_data['reviews_count'] = intval($product['total_reviews']);
            
            // Lấy số lượng đã bán từ cột ban trong bảng sanpham (dữ liệu thật)
            $product_data['sold_count'] = intval($product['ban']);
            
            // Format giá
            $product_data['price_formatted'] = number_format($product_data['price'], 0, ',', '.') . ' ₫';
            $product_data['old_price_formatted'] = $product_data['old_price'] > 0 ? number_format($product_data['old_price'], 0, ',', '.') . ' ₫' : '';
            
            $products[] = $product_data;
        }
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách sản phẩm cùng shop thành công",
            "data" => [
                "shop_info" => $shop_info,
                "products" => $products,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_records" => $total_records,
                    "per_page" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                ],
                "filters" => [
                    "product_id" => $product_id,
                    "shop_id" => $shop_id,
                    "category_id" => $category_id,
                    "sort" => $sort,
                    "exclude_product_id" => $exclude_product_id
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
