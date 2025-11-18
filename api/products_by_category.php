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
        $category_id = isset($_GET['category_id']) ? intval($_GET['category_id']) : 0;
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 500;
        $sort = isset($_GET['sort']) ? addslashes($_GET['sort']) : 'newest'; // newest, price_asc, price_desc, popular
        
        // Validate parameters
        if ($category_id <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Category ID không hợp lệ"
            ]);
            exit;
        }
        
        
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        if ($limit > 500) $limit = 1000;
        if ($limit < 1) $limit = 420;
        if ($page < 1) $page = 1;
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        
        $start = ($page - 1) * $limit;
        
        // Kiểm tra danh mục có tồn tại không
        $category_check = "SELECT cat_id, cat_tieude FROM category_sanpham WHERE cat_id = $category_id LIMIT 1";
        $category_result = mysqli_query($conn, $category_check);
        
        if (!$category_result || mysqli_num_rows($category_result) == 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Không tìm thấy danh mục"
            ]);
            exit;
        }
        
        $category_info = mysqli_fetch_assoc($category_result);
        
        // Xây dựng query sắp xếp
        $order_by = "ORDER BY ";
        switch ($sort) {
            case 'price_asc':
                $order_by .= "gia_moi ASC";
                break;
            case 'price_desc':
                $order_by .= "gia_moi DESC";
                break;
            case 'popular':
                $order_by .= "ban DESC, view DESC";
                break;
            case 'newest':
            default:
                $order_by .= "date_post DESC, id DESC";
                break;
        }
        
        // Đếm tổng số sản phẩm trong danh mục
        // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
        //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
        $count_query = "SELECT COUNT(DISTINCT s.id) as total 
                        FROM sanpham s
                        WHERE FIND_IN_SET($category_id, s.cat) > 0 
                        AND s.active = 0
                        AND s.kho >= 0
                        AND (
                            -- Sản phẩm không có phân loại: check kho chính
                            (NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = s.id) AND s.kho > 0)
                            OR
                            -- Sản phẩm có phân loại: check kho phân loại (không check kho chính)
                            EXISTS (
                                SELECT 1 FROM phanloai_sanpham pl 
                                WHERE pl.sp_id = s.id 
                                AND pl.kho_sanpham_socdo > 0
                            )
                        )";
        $count_result = mysqli_query($conn, $count_query);
        $total_products = mysqli_fetch_assoc($count_result)['total'];
        
        // Lấy danh sách sản phẩm
        // Với sàn (shop = 0): lấy transport với user_id = 0
        // Với shop thường: lấy transport theo kho_id
        // Sử dụng LEFT JOIN với product_rating_stats (đã có index) thay vì subquery để tối ưu performance
        $products_query = "SELECT DISTINCT s.*, 
                          COALESCE(t.ten_kho, t_san.ten_kho) AS warehouse_name,
                          COALESCE(tm.tieu_de, tm_san.tieu_de) AS province_name,
                          COALESCE(prs.total_reviews, 0) AS total_reviews,
                          COALESCE(prs.average_rating, 0) AS average_rating
                          FROM sanpham s
                          LEFT JOIN transport t ON s.kho_id = t.id AND s.shop > 0 AND t.user_id = s.shop
                          LEFT JOIN tinh_moi tm ON t.province = tm.id
                          LEFT JOIN transport t_san ON t_san.user_id = 0 AND s.shop = 0 AND t_san.is_default = 1
                          LEFT JOIN tinh_moi tm_san ON t_san.province = tm_san.id
                          LEFT JOIN product_rating_stats prs ON s.id = prs.product_id AND s.shop = prs.shop_id
                          WHERE FIND_IN_SET($category_id, s.cat) > 0 
                          AND s.active = 0
                          AND s.kho >= 0
                          AND (
                              -- Sản phẩm không có phân loại: check kho chính
                              (NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = s.id) AND s.kho > 0)
                              OR
                              -- Sản phẩm có phân loại: check kho phân loại (không check kho chính)
                              EXISTS (
                                  SELECT 1 FROM phanloai_sanpham pl 
                                  WHERE pl.sp_id = s.id 
                                  AND pl.kho_sanpham_socdo > 0
                              )
                          )
                          $order_by LIMIT $start, $limit";
        $products_result = mysqli_query($conn, $products_query);
        
        if (!$products_result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
            ]);
            exit;
        }
        
        $products = array();
        while ($product = mysqli_fetch_assoc($products_result)) {
            // Xử lý hình ảnh sản phẩm với CDN
            $image_url = '';
            if (!empty($product['minh_hoa'])) {
                $image_url = getImageUrlWithCDN($product['minh_hoa']);
            } else {
                $image_url = 'https://socdo.vn/images/no-images.jpg';
            }
            
            // Tính phần trăm giảm giá
            $discount_percent = 0;
            if ($product['gia_cu'] > 0 && $product['gia_moi'] > 0) {
                $discount_percent = round((($product['gia_cu'] - $product['gia_moi']) / $product['gia_cu']) * 100);
            }
            
            // Kiểm tra voucher và freeship theo logic chuẩn
            $current_time = time();
            $deal_shop = $product['shop'];
            
            // Check voucher - Logic chuẩn với hệ thống
            $voucher_icon = '';
            if ($deal_shop > 0) {
                // Shop thường
                $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('{$product['id']}', sanpham) AND shop = '$deal_shop' AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
            if (mysqli_num_rows($check_coupon) > 0) {
                $voucher_icon = 'Voucher';
            } else {
                $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                if (mysqli_num_rows($check_coupon_all) > 0) {
                    $voucher_icon = 'Voucher';
                    }
                }
            } else {
                // Sàn (shop = 0)
                $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('{$product['id']}', sanpham) AND shop = 0 AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                if (mysqli_num_rows($check_coupon) > 0) {
                    $voucher_icon = 'Voucher';
                } else {
                    $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = 0 AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                    if (mysqli_num_rows($check_coupon_all) > 0) {
                        $voucher_icon = 'Voucher';
                    }
                }
            }
            
            // Check freeship - Logic chuẩn với 4 mode
            $freeship_query = "SELECT free_ship_all, free_ship_discount, free_ship_min_order, fee_ship_products FROM transport WHERE user_id = '$deal_shop' AND (free_ship_all > 0 OR free_ship_discount > 0) LIMIT 1";
            $freeship_result = mysqli_query($conn, $freeship_query);
            $is_freeship = false;
            $freeship_label = '';
            
            if ($freeship_result && mysqli_num_rows($freeship_result) > 0) {
                $freeship_data = mysqli_fetch_assoc($freeship_result);
                $mode = intval($freeship_data['free_ship_all'] ?? 0);
                $discount = intval($freeship_data['free_ship_discount'] ?? 0);
                $minOrder = intval($freeship_data['free_ship_min_order'] ?? 0);
                
                // Lấy giá sản phẩm để kiểm tra điều kiện min_order
                $base_price = $product['gia_moi'];
                
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
            
            // Format dữ liệu sản phẩm
            $product_data = array(
                'id' => intval($product['id']),
                'tieu_de' => $product['tieu_de'],
                'minh_hoa' => $image_url,
                'gia_cu' => intval($product['gia_cu']),
                'gia_moi' => intval($product['gia_moi']),
                'discount_percent' => $discount_percent,
                'kho' => intval($product['kho']),
                'ban' => intval($product['ban']),
                'view' => intval($product['view']),
                'thuong_hieu' => $product['thuong_hieu'],
                'noi_ban' => $product['noi_ban'],
                'cat' => $product['cat'],
                'link' => $product['link'],
                'date_post' => $product['date_post'],
                'shop' => $product['shop'] ? intval($product['shop']) : null,
                'status' => $product['status'] ? intval($product['status']) : null,
                'box_banchay' => intval($product['box_banchay']),
                'box_noibat' => intval($product['box_noibat']),
                'box_flash' => intval($product['box_flash']),
                'warehouse_name' => $product['warehouse_name'] ?? '',
                'province_name' => $product['province_name'] ?? '',
                'voucher_icon' => $voucher_icon,
                'freeship_icon' => $freeship_icon,
                'chinhhang_icon' => $chinhhang_icon,
                'badges' => array(),
                // Lấy rating và reviews từ product_rating_stats (đã JOIN ở trên)
                'rating' => floatval($product['average_rating']),
                'reviews_count' => intval($product['total_reviews']),
                // Lấy số lượng đã bán từ cột ban trong bảng sanpham (dữ liệu thật)
                'sold_count' => intval($product['ban']),
            );
            
            // Tạo badges
            $badges = array();
            
            // Discount badge
            if ($discount_percent > 0) {
                $badges[] = "Giảm $discount_percent%";
            }
            
            // Flash sale badge
            if ($product['box_flash'] == 1) {
                $badges[] = "FLASH SALE";
            }
            
            // Bestseller badge
            if ($product['box_banchay'] == 1) {
                $badges[] = "BÁN CHẠY";
            }
            
            // Featured badge
            if ($product['box_noibat'] == 1) {
                $badges[] = "NỔI BẬT";
            }
            
            // Voucher badge
            if (!empty($voucher_icon)) {
                $badges[] = $voucher_icon;
            }
            
            // Freeship badge
            if (!empty($freeship_icon)) {
                $badges[] = $freeship_icon;
            }
            
            // Chính hãng badge
            $badges[] = $chinhhang_icon;
            
            $product_data['badges'] = $badges;
            
            $products[] = $product_data;
        }
        
        // Tính toán thông tin phân trang
        $total_pages = ceil($total_products / $limit);
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách sản phẩm theo danh mục thành công",
            "data" => [
                "category" => [
                    "id" => intval($category_info['cat_id']),
                    "name" => $category_info['cat_tieude']
                ],
                "products" => $products,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_products" => $total_products,
                    "limit" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                ],
                "filters" => [
                    "category_id" => $category_id,
                    "sort" => $sort
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
