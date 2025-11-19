<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

// Lấy token từ header Authorization (optional)
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
    
    // Đơn giản: Lấy tất cả sản phẩm có affiliate campaign
    $current_time = time();
    
    // Đếm tổng số sản phẩm có affiliate
    $count_query = "SELECT COUNT(DISTINCT sanpham.id) as total 
                    FROM sanpham 
                    INNER JOIN sanpham_aff ON (FIND_IN_SET(sanpham.id, sanpham_aff.main_product) > 0 OR sanpham_aff.sub_product LIKE CONCAT('%\"', sanpham.id, '\"%'))
                    WHERE sanpham.status = 1 
                    AND sanpham_aff.date_start <= $current_time 
                    AND sanpham_aff.date_end >= $current_time";
    
    $count_result = mysqli_query($conn, $count_query);
    $total_records = 0;
    if ($count_result) {
        $count_row = mysqli_fetch_assoc($count_result);
        $total_records = $count_row['total'];
    }
    
    $total_pages = ceil($total_records / $limit);
    
    // Lấy danh sách sản phẩm affiliate
    $products_query = "SELECT DISTINCT sanpham.*, sanpham_aff.tieu_de as campaign_name
                       FROM sanpham 
                       INNER JOIN sanpham_aff ON (FIND_IN_SET(sanpham.id, sanpham_aff.main_product) > 0 OR sanpham_aff.sub_product LIKE CONCAT('%\"', sanpham.id, '\"%'))
                       WHERE sanpham.status = 1 
                       AND sanpham_aff.date_start <= $current_time 
                       AND sanpham_aff.date_end >= $current_time
                       ORDER BY sanpham.id DESC 
                       LIMIT $offset, $limit";
    
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
        // Format dữ liệu sản phẩm
        $product_data = array();
        $product_data['id'] = intval($product['id']);
        $product_data['name'] = $product['tieu_de'];
        $product_data['slug'] = $product['link'];
        $product_data['price'] = intval($product['gia_moi']);
        $product_data['old_price'] = intval($product['gia_cu']);
        $product_data['shop_id'] = intval($product['shop']);
        $product_data['campaign_name'] = $product['campaign_name'] ?? '';
        
        // Xử lý hình ảnh
        if (!empty($product['minh_hoa'])) {
            $product_data['image'] = 'https://' . $_SERVER['HTTP_HOST'] . '/' . $product['minh_hoa'];
        } else {
            $product_data['image'] = '';
        }
        
        // Tạo URL sản phẩm
        $product_data['product_url'] = 'https://' . $_SERVER['HTTP_HOST'] . '/san-pham/' . $product_data['id'] . '/' . $product_data['slug'] . '.html';
        
        // Format giá
        $product_data['price_formatted'] = number_format($product_data['price'], 0, ',', '.') . ' ₫';
        $product_data['old_price_formatted'] = $product_data['old_price'] > 0 ? number_format($product_data['old_price'], 0, ',', '.') . ' ₫' : '';
        
        $products[] = $product_data;
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy danh sách sản phẩm affiliate thành công",
        "data" => [
            "products" => $products,
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
?>
