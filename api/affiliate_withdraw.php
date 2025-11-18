<?php
/**
 * API: Affiliate Withdraw Request
 * Method: POST
 * URL: /v1/affiliate_withdraw
 * Body: {
 *   "user_id": 123,
 *   "amount": 500000,
 *   "bank_account": "1234567890",
 *   "bank_name": "Vietcombank",
 *   "account_holder": "NGUYEN VAN A"
 * }
 * 
 * Description: Create a withdrawal request for affiliate commission
 * 
 * Response: {
 *   "success": true,
 *   "message": "Yêu cầu rút tiền thành công",
 *   "data": {
 *     "amount": 500000,
 *     "remaining_balance": 3550000
 *   }
 * }
 */

require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

header('Content-Type: application/json; charset=utf-8');

// Get POST data
$input = json_decode(file_get_contents('php://input'), true);
$user_id = isset($input['user_id']) ? intval($input['user_id']) : 0;
$amount = isset($input['amount']) ? floatval($input['amount']) : 0;
$bank_account = isset($input['bank_account']) ? mysqli_real_escape_string($conn, trim($input['bank_account'])) : '';
$bank_name = isset($input['bank_name']) ? mysqli_real_escape_string($conn, trim($input['bank_name'])) : '';
$account_holder = isset($input['account_holder']) ? mysqli_real_escape_string($conn, trim($input['account_holder'])) : '';

if ($user_id <= 0) {
    // Fallback to JWT
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    
    if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        $jwt = $matches[1];
        
        try {
            $key_query = mysqli_query($conn, "SELECT value FROM index_setting WHERE name='key' LIMIT 1");
            $key_row = mysqli_fetch_assoc($key_query);
            $secret_key = $key_row['value'] ?? 'default_secret_key';
            
            $issuer_query = mysqli_query($conn, "SELECT value FROM index_setting WHERE name='issuer' LIMIT 1");
            $issuer_row = mysqli_fetch_assoc($issuer_query);
            $issuer = $issuer_row['value'] ?? 'default_issuer';
            
            $decoded = JWT::decode($jwt, new Key($secret_key, 'HS256'));
            
            if ($decoded->iss === $issuer) {
                $user_id = $decoded->data->user_id ?? 0;
            }
        } catch (Exception $e) {
            // JWT invalid
        }
    }
}

if ($user_id <= 0) {
    echo json_encode([
        'success' => false,
        'message' => 'User ID is required'
    ]);
    exit;
}

if ($amount <= 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid withdrawal amount'
    ]);
    exit;
}

if (empty($bank_account) || empty($bank_name) || empty($account_holder)) {
    echo json_encode([
        'success' => false,
        'message' => 'Bank information is required'
    ]);
    exit;
}

// Get user balance
$user_query = "SELECT user_money2 FROM user_info WHERE user_id = '$user_id' LIMIT 1";
$user_result = mysqli_query($conn, $user_query);
$user_info = mysqli_fetch_assoc($user_result);

if (!$user_info) {
    echo json_encode([
        'success' => false,
        'message' => 'User not found'
    ]);
    exit;
}

$current_balance = (float) $user_info['user_money2'];

if ($amount > $current_balance) {
    echo json_encode([
        'success' => false,
        'message' => 'Insufficient withdrawable balance. Current balance: ' . number_format($current_balance) . ' VND'
    ]);
    exit;
}

// Start transaction
mysqli_autocommit($conn, false);

try {
    // Deduct balance
    $new_balance = $current_balance - $amount;
    $update_query = "UPDATE user_info SET user_money2 = '$new_balance' WHERE user_id = '$user_id'";
    if (!mysqli_query($conn, $update_query)) {
        throw new Exception('Failed to update balance');
    }
    
    // Create withdrawal request
    $current_time = time();
    $insert_query = "INSERT INTO rut_tien (user_id, so_tien, chu_khoan, so_taikhoan, ngan_hang, status, date_post) 
                     VALUES ('$user_id', '$amount', '$account_holder', '$bank_account', '$bank_name', '0', '$current_time')";
    if (!mysqli_query($conn, $insert_query)) {
        throw new Exception('Failed to create withdrawal request');
    }
    
    mysqli_commit($conn);
    
    echo json_encode([
        'success' => true,
        'message' => 'Yêu cầu rút tiền ' . number_format($amount) . ' VND đã được gửi thành công',
        'data' => [
            'amount' => $amount,
            'remaining_balance' => $new_balance
        ]
    ]);
    
} catch (Exception $e) {
    mysqli_rollback($conn);
    echo json_encode([
        'success' => false,
        'message' => 'Transaction failed: ' . $e->getMessage()
    ]);
}

mysqli_autocommit($conn, true);

