<?php
/**
 * API: Claim Affiliate Commission
 * Method: POST
 * URL: /v1/affiliate_claim_commission
 * Body: {
 *   "user_id": 123
 * }
 * 
 * Description: Transfer commission from pending to withdrawable (after 7 days)
 * 
 * Response: {
 *   "success": true,
 *   "message": "Đã chuyển 450,000đ vào số dư có thể rút",
 *   "data": {
 *     "claimed_amount": 450000,
 *     "new_withdrawable_balance": 4500000
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

// Check if user is affiliate
$check_query = "SELECT dk_aff FROM user_info WHERE user_id = '$user_id' LIMIT 1";
$check_result = mysqli_query($conn, $check_query);
$user_info = mysqli_fetch_assoc($check_result);

if (!$user_info || (int)$user_info['dk_aff'] !== 1) {
    echo json_encode([
        'success' => false,
        'message' => 'User is not registered for affiliate program'
    ]);
    exit;
}

// Start transaction
mysqli_autocommit($conn, false);

try {
    $current_time = time();
    $seven_days_ago = $current_time - (7 * 24 * 60 * 60);
    
    $keywords = ['Hoa hồng affiliate', 'Hoa hồng nhóm affiliate'];
    
    $total_transferred = 0;
    $count_transactions = 0;
    
    foreach ($keywords as $keyword) {
        // Get eligible transactions
        $query = "SELECT id, sotien 
                  FROM lichsu_chitieu 
                  WHERE user_id = '$user_id' 
                  AND noidung LIKE '%$keyword%' 
                  AND transferred_to_withdrawable = 0 
                  AND date_post <= $seven_days_ago";
        $result = mysqli_query($conn, $query);
        
        while ($row = mysqli_fetch_assoc($result)) {
            $transaction_id = $row['id'];
            $amount = (float) $row['sotien'];
            
            // Mark as transferred
            $update_query = "UPDATE lichsu_chitieu 
                            SET transferred_to_withdrawable = 1 
                            WHERE id = '$transaction_id'";
            if (!mysqli_query($conn, $update_query)) {
                throw new Exception("Failed to update transaction $transaction_id");
            }
            
            $total_transferred += $amount;
            $count_transactions++;
        }
    }
    
    if ($total_transferred > 0) {
        // Add to withdrawable balance
        $update_balance = "UPDATE user_info 
                          SET user_money2 = user_money2 + $total_transferred 
                          WHERE user_id = '$user_id'";
        if (!mysqli_query($conn, $update_balance)) {
            throw new Exception("Failed to update withdrawable balance");
        }
        
        // Get new balance
        $balance_query = "SELECT user_money2 FROM user_info WHERE user_id = '$user_id' LIMIT 1";
        $balance_result = mysqli_query($conn, $balance_query);
        $balance_info = mysqli_fetch_assoc($balance_result);
        $new_balance = (float) $balance_info['user_money2'];
        
        mysqli_commit($conn);
        
        echo json_encode([
            'success' => true,
            'message' => "Đã chuyển " . number_format($total_transferred) . "đ vào số dư có thể rút",
            'data' => [
                'claimed_amount' => $total_transferred,
                'transactions_count' => $count_transactions,
                'new_withdrawable_balance' => $new_balance
            ]
        ]);
    } else {
        mysqli_commit($conn);
        
        echo json_encode([
            'success' => true,
            'message' => 'Không có hoa hồng nào đủ điều kiện để chuyển (phải sau 7 ngày)',
            'data' => [
                'claimed_amount' => 0,
                'transactions_count' => 0
            ]
        ]);
    }
    
} catch (Exception $e) {
    mysqli_rollback($conn);
    echo json_encode([
        'success' => false,
        'message' => 'Transaction failed: ' . $e->getMessage()
    ]);
}

mysqli_autocommit($conn, true);

