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
    $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 100;
    $get_all = isset($_GET['all']) && $_GET['all'] == '1';
    
    // Validate parameters
    if ($page < 1) $page = 1;
    if ($limit < 1 || $limit > 500) $limit = 100;
    
    // Override limit nếu get_all = true
    if ($get_all) {
        $limit = 999999;
        $page = 1;
    }

    $offset = ($page - 1) * $limit;
    
    // Đếm tổng số bản ghi hoa hồng
    $count_query = "SELECT COUNT(*) as total FROM lichsu_chitieu WHERE user_id = '$user_id'";
    $count_result = mysqli_query($conn, $count_query);
    $total_records = 0;
    if ($count_result) {
        $count_row = mysqli_fetch_assoc($count_result);
        $total_records = $count_row['total'];
    }
    
    $total_pages = ceil($total_records / $limit);
    
    // Lấy danh sách lịch sử hoa hồng
    $history_query = "SELECT * FROM lichsu_chitieu 
                      WHERE user_id = '$user_id' 
                      ORDER BY date_post DESC 
                      LIMIT $offset, $limit";
    $history_result = mysqli_query($conn, $history_query);
    
    if (!$history_result) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
        ]);
        exit;
    }
    
    $commissions = array();
    
    while ($record = mysqli_fetch_assoc($history_result)) {
        $commission_data = array();
        $commission_data['id'] = intval($record['id']);
        $commission_data['description'] = $record['noidung'];
        $commission_data['amount'] = (float) $record['sotien'];
        $commission_data['amount_formatted'] = number_format($record['sotien'], 0, ',', '.') . ' ₫';
        $commission_data['balance_before'] = (float) $record['truoc'];
        $commission_data['balance_before_formatted'] = number_format($record['truoc'], 0, ',', '.') . ' ₫';
        $commission_data['balance_after'] = (float) $record['sau'];
        $commission_data['balance_after_formatted'] = number_format($record['sau'], 0, ',', '.') . ' ₫';
        $commission_data['created_at'] = date('d/m/Y H:i', intval($record['date_post']));
        $commission_data['created_timestamp'] = intval($record['date_post']);
        $commission_data['transferred_to_withdrawable'] = (int) $record['transferred_to_withdrawable'];
        
        $commissions[] = $commission_data;
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy lịch sử hoa hồng thành công",
        "data" => [
            "commissions" => $commissions,
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
