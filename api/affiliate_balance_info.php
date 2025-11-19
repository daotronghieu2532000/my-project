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
    // Lấy thông tin số dư từ user_info
    $balance_query = "SELECT user_money, user_money2 FROM user_info WHERE user_id = '$user_id' LIMIT 1";
    $balance_result = mysqli_query($conn, $balance_query);
    
    if (!$balance_result || mysqli_num_rows($balance_result) == 0) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "User not found"
        ]);
        exit;
    }
    
    $balance_info = mysqli_fetch_assoc($balance_result);
    
    $pending_balance = (float) $balance_info['user_money'];
    $withdrawable_balance = (float) $balance_info['user_money2'];
    $total_balance = $pending_balance + $withdrawable_balance;
    
    // Kiểm tra có hoa hồng nào đủ điều kiện claim không
    $current_time = time();
    $seven_days_ago = $current_time - (7 * 24 * 60 * 60);
    
    $claimable_query = "SELECT COUNT(*) as count, SUM(sotien) as total 
                       FROM lichsu_chitieu 
                       WHERE user_id = '$user_id' 
                       AND date_post <= '$seven_days_ago'
                       AND transferred_to_withdrawable = 0
                       AND (noidung LIKE '%Hoa hồng affiliate%' OR noidung LIKE '%Hoa hồng nhóm affiliate%')";
    
    $claimable_result = mysqli_query($conn, $claimable_query);
    $claimable_info = mysqli_fetch_assoc($claimable_result);
    
    $can_claim = $claimable_info['count'] > 0;
    $claimable_amount = (float) ($claimable_info['total'] ?? 0);
    
    $response = [
        "success" => true,
        "message" => "Lấy thông tin số dư thành công",
        "data" => [
            "balances" => [
                "total_balance" => $total_balance,
                "total_balance_formatted" => number_format($total_balance, 0, ',', '.') . ' ₫',
                "pending_balance" => $pending_balance,
                "pending_balance_formatted" => number_format($pending_balance, 0, ',', '.') . ' ₫',
                "withdrawable_balance" => $withdrawable_balance,
                "withdrawable_balance_formatted" => number_format($withdrawable_balance, 0, ',', '.') . ' ₫'
            ],
            "claim_info" => [
                "can_claim" => $can_claim,
                "claimable_amount" => $claimable_amount,
                "claimable_amount_formatted" => number_format($claimable_amount, 0, ',', '.') . ' ₫',
                "claimable_transactions_count" => (int) $claimable_info['count']
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
