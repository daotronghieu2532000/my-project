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
$user_id = 0;

if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    $jwt = $matches[1]; // Lấy token từ Bearer
    
    try {
        // Giải mã JWT
        $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
        
        // Kiểm tra issuer
        if ($decoded->iss === $issuer) {
            $user_id = $decoded->data->user_id ?? 0;
        }
    } catch (Exception $e) {
        // JWT invalid, user_id remains 0
    }
}

// Fallback to GET parameter if no JWT
if ($user_id <= 0) {
    $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
}

if ($user_id <= 0) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "User ID is required"
    ]);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get parameters
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 500;
    $get_all = isset($_GET['all']) && $_GET['all'] == '1';
    
    // Validate parameters
    if ($page < 1) $page = 1;
    if ($limit < 1 || $limit > 1000) $limit = 500;
    
    // Override limit nếu get_all = true
    if ($get_all) {
        $limit = 999999;
        $page = 1;
    }

    $offset = ($page - 1) * $limit;
    
    // Đếm tổng số sản phẩm đang theo dõi
    $count_query = "SELECT COUNT(*) as total FROM follow_aff WHERE user_id = '$user_id'";
    $count_result = mysqli_query($conn, $count_query);
    $total_records = 0;
    if ($count_result) {
        $count_row = mysqli_fetch_assoc($count_result);
        $total_records = $count_row['total'];
    }
    
    $total_pages = ceil($total_records / $limit);
    
    // Lấy danh sách sản phẩm đang theo dõi với thông tin tổng hợp
    $followed_query = "SELECT 
                              f.sp_id, 
                              f.date_post,
                              s.tieu_de, 
                              s.minh_hoa, 
                              s.gia_moi, 
                              s.gia_cu, 
                              s.shop, 
                              s.link,
                              MAX(r.rut_gon) as rut_gon,
                              SUM(r.click) as total_clicks,
                              MAX(r.id) as link_id
                       FROM follow_aff f
                       LEFT JOIN sanpham s ON f.sp_id = s.id
                       LEFT JOIN rut_gon_shop r ON (f.sp_id = r.sp_id AND r.user_id = '$user_id' AND r.rut_gon != '')
                       WHERE f.user_id = '$user_id'
                       GROUP BY f.sp_id, f.date_post, s.tieu_de, s.minh_hoa, s.gia_moi, s.gia_cu, s.shop, s.link
                       ORDER BY f.date_post DESC
                       LIMIT $offset, $limit";
    $followed_result = mysqli_query($conn, $followed_query);
    
    if (!$followed_result) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
        ]);
        exit;
    }
    
    $followed_products = array();
    
    $current_time = time();
    while ($product = mysqli_fetch_assoc($followed_result)) {
        $sp_id = $product['sp_id'];
        
        // Get total orders from this product (if user has created links)
        $total_orders_for_product = 0;
        $total_commission_for_product = 0;
        
        if (!empty($product['rut_gon'])) {
            $orders_simple_query = "SELECT ma_don, sanpham FROM donhang WHERE utm_source = '$user_id' AND status = 5";
            $orders_result = mysqli_query($conn, $orders_simple_query);
            
            while ($order = mysqli_fetch_assoc($orders_result)) {
                $products_order = json_decode($order['sanpham'], true);
                if (is_array($products_order)) {
                    foreach ($products_order as $product_order) {
                        if (isset($product_order['sp_id']) && $product_order['sp_id'] == $sp_id && 
                            isset($product_order['utm_source']) && $product_order['utm_source'] == $user_id) {
                            $total_orders_for_product++;
                            $commission = str_replace(',', '', $product_order['hoa_hong'] ?? 0);
                            $total_commission_for_product += (float) $commission;
                        }
                    }
                }
            }
        }
        
        // Lấy thông tin chiến dịch affiliate (để có commission info)
        $commission_info = array();
        $aff_query = "SELECT tieu_de, sub_product 
                      FROM sanpham_aff 
                      WHERE (FIND_IN_SET($sp_id, main_product) > 0 OR sub_product LIKE '%\"$sp_id\"%')
                      AND date_start <= $current_time 
                      AND date_end >= $current_time 
                      ORDER BY date_post DESC 
                      LIMIT 1";
        $aff_result = mysqli_query($conn, $aff_query);
        $aff_info = mysqli_fetch_assoc($aff_result);
        if ($aff_info && !empty($aff_info['sub_product'])) {
            $sub_product = json_decode($aff_info['sub_product'], true);
            if (isset($sub_product[$sp_id]) && is_array($sub_product[$sp_id])) {
                foreach ($sub_product[$sp_id] as $commission) {
                    $commission_info[] = array(
                        'variant_id' => $commission['variant_id'] ?? 'main',
                        'type' => $commission['loai'] ?? 'tru',
                        'value' => (float) ($commission['hoa_hong'] ?? 0)
                    );
                }
            }
        }

        // Tạo full_link đúng định dạng
        $full_link = '';
        if (!empty($product['link'])) {
            $full_link = 'https://socdo.vn/product/' . $product['link'] . '.html?utm_source_shop=' . $user_id;
        }
        
        $product_data = array();
        $product_data['id'] = intval($product['link_id'] ?? 0); // ID của link rút gọn (nếu có)
        $product_data['sp_id'] = intval($product['sp_id']);
        $product_data['product_title'] = $product['tieu_de'] ?? '';
        $product_data['product_price'] = (float) ($product['gia_moi'] ?? 0);
        $product_data['shop_id'] = intval($product['shop'] ?? 0);
        $product_data['is_following'] = true; // Luôn true vì đây là sản phẩm đang theo dõi
        $product_data['product_price'] = (float) ($product['gia_moi'] ?? 0);
        $product_data['old_price'] = (float) ($product['gia_cu'] ?? 0);
        $product_data['discount_percent'] = 0;
        if ($product_data['old_price'] > 0 && $product_data['product_price'] < $product_data['old_price']) {
            $product_data['discount_percent'] = round((($product_data['old_price'] - $product_data['product_price']) / $product_data['old_price']) * 100);
        }
        
        // Lấy tổng click từ tất cả record (kể cả không có short link)
        $all_clicks_query = "SELECT SUM(click) as total_all_clicks FROM rut_gon_shop WHERE user_id = '$user_id' AND sp_id = '$sp_id'";
        $all_clicks_result = mysqli_query($conn, $all_clicks_query);
        $total_all_clicks = 0;
        if ($all_clicks_result) {
            $clicks_row = mysqli_fetch_assoc($all_clicks_result);
            $total_all_clicks = (int) ($clicks_row['total_all_clicks'] ?? 0);
        }
        
        // Thông tin link rút gọn (nếu có)
        if (!empty($product['rut_gon'])) {
            $product_data['has_short_link'] = true;
            $product_data['short_link'] = "https://socdo.xyz/x/" . $product['rut_gon'];
        } else {
            $product_data['has_short_link'] = false;
            $product_data['short_link'] = '';
        }
        $product_data['clicks'] = $total_all_clicks;
        
        $product_data['full_link'] = $full_link;
        $product_data['orders'] = $total_orders_for_product;
        $product_data['commission'] = $total_commission_for_product;
        $product_data['followed_at'] = date('Y-m-d H:i:s', $product['date_post']);
        $product_data['commission_info'] = $commission_info;
        
        // Xử lý hình ảnh
        if (!empty($product['minh_hoa'])) {
            $product_data['product_image'] = 'https://socdo.vn/' . $product['minh_hoa'];
        } else {
            $product_data['product_image'] = '';
        }
        
        $followed_products[] = $product_data;
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy danh sách sản phẩm affiliate đang theo dõi thành công",
        "data" => [
            "followed_products" => $followed_products,
            "pagination" => [
                "current_page" => $page,
                "total_pages" => $total_pages,
                "total_records" => $total_records,
                "per_page" => $limit,
                "has_next" => $page < $total_pages,
                "has_prev" => $page > 1
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

