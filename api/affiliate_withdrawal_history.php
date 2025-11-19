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
    $status_filter = isset($_GET['status']) ? intval($_GET['status']) : -1; // -1 = all, 0 = pending, 1 = approved, 2 = rejected
    
    // Validate parameters
    if ($page < 1) $page = 1;
    if ($limit < 1 || $limit > 500) $limit = 400;
    
    // Override limit nếu get_all = true
    if ($get_all) {
        $limit = 999999;
        $page = 1;
    }

    $offset = ($page - 1) * $limit;
    
    // Xây dựng WHERE clause
    $where_conditions = array("user_id = '$user_id'");
    
    // Lọc theo trạng thái
    if ($status_filter >= 0) {
        $where_conditions[] = "status = '$status_filter'";
    }
    
    $where_clause = "WHERE " . implode(" AND ", $where_conditions);
    
    // Đếm tổng số yêu cầu rút tiền
    $count_query = "SELECT COUNT(*) as total FROM rut_tien $where_clause";
    $count_result = mysqli_query($conn, $count_query);
    $total_records = 0;
    if ($count_result) {
        $count_row = mysqli_fetch_assoc($count_result);
        $total_records = $count_row['total'];
    }
    
    $total_pages = ceil($total_records / $limit);
    
    // Lấy danh sách yêu cầu rút tiền
    $withdrawals_query = "SELECT * FROM rut_tien $where_clause ORDER BY date_post DESC LIMIT $offset, $limit";
    
    $withdrawals_result = mysqli_query($conn, $withdrawals_query);
    
    if (!$withdrawals_result) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
        ]);
        exit;
    }
    
    $withdrawals = array();
    
    $status_map = array(
        0 => array('text' => 'Chờ duyệt', 'color' => '#FFA500'),
        1 => array('text' => 'Đã duyệt', 'color' => '#4CAF50'),
        2 => array('text' => 'Từ chối', 'color' => '#F44336')
    );
    
    while ($withdrawal = mysqli_fetch_assoc($withdrawals_result)) {
        $status_info = $status_map[$withdrawal['status']] ?? $status_map[0];
        
        $withdrawal_data = array();
        $withdrawal_data['id'] = intval($withdrawal['id']);
        $withdrawal_data['amount'] = (float) $withdrawal['so_tien'];
        $withdrawal_data['amount_formatted'] = number_format($withdrawal_data['amount'], 0, ',', '.') . ' ₫';
        $withdrawal_data['account_holder'] = $withdrawal['chu_khoan'];
        $withdrawal_data['bank_account'] = $withdrawal['so_taikhoan'];
        $withdrawal_data['bank_name'] = $withdrawal['ngan_hang'];
        $withdrawal_data['status'] = array(
            'code' => (int) $withdrawal['status'],
            'text' => $status_info['text'],
            'color' => $status_info['color']
        );
        $withdrawal_data['created_at'] = date('Y-m-d H:i:s', $withdrawal['date_post']);
        $withdrawal_data['created_timestamp'] = intval($withdrawal['date_post']);
        
        $withdrawals[] = $withdrawal_data;
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy lịch sử rút tiền thành công",
        "data" => [
            "withdrawals" => $withdrawals,
            "pagination" => [
                "current_page" => $page,
                "total_pages" => $total_pages,
                "total_records" => $total_records,
                "per_page" => $limit,
                "has_next" => $page < $total_pages,
                "has_prev" => $page > 1
            ],
            "filters" => [
                "status" => $status_filter,
                "user_id" => $user_id
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
