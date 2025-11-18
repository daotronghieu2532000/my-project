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

// Check if user is registered for affiliate
$check_aff = mysqli_query($conn, "SELECT dk_aff FROM user_info WHERE user_id = '$user_id' LIMIT 1");
$aff_info = mysqli_fetch_assoc($check_aff);

if (!$aff_info || $aff_info['dk_aff'] != 1) {
    echo json_encode([
        'success' => false,
        'message' => 'User is not registered for affiliate program'
    ]);
    exit;
}

// Get total clicks
$clicks_query = "SELECT SUM(click) as total_clicks FROM rut_gon_shop WHERE user_id = '$user_id'";
$clicks_result = mysqli_query($conn, $clicks_query);
$total_clicks = mysqli_fetch_assoc($clicks_result)['total_clicks'] ?? 0;

// Get orders and calculate commission
$orders_query = "SELECT sanpham, tongtien, date_post FROM donhang WHERE utm_source = '$user_id' AND status = 5";
$orders_result = mysqli_query($conn, $orders_query);
$total_commission = 0;
$total_orders = 0;
$monthly_revenue = 0;
$current_month = date('Y-m');

while ($order = mysqli_fetch_assoc($orders_result)) {
    $total_orders++;
    $products = json_decode($order['sanpham'], true);
    
    if (is_array($products)) {
        foreach ($products as $product) {
            $commission = str_replace(',', '', $product['hoa_hong'] ?? 0);
            $total_commission += (float) $commission;
        }
    }
    
    // Calculate monthly revenue
    if (date('Y-m', $order['date_post']) === $current_month) {
        $revenue = str_replace(',', '', $order['tongtien'] ?? 0);
        $monthly_revenue += (float) $revenue;
    }
}

// Calculate conversion rate
$conversion_rate = $total_clicks > 0 ? round(($total_orders / $total_clicks) * 100, 2) : 0;
$conversion_text = 'Cần cải thiện';
if ($conversion_rate >= 3) {
    $conversion_text = 'Tốt';
} elseif ($conversion_rate >= 1) {
    $conversion_text = 'Trung bình';
}

// Get total team members
$members_query = "SELECT COUNT(*) as total FROM user_info WHERE aff = '$user_id'";
$members_result = mysqli_query($conn, $members_query);
$total_members = mysqli_fetch_assoc($members_result)['total'] ?? 0;

// Get pending commission (not yet transferred to withdrawable after 7 days)
$seven_days_ago = time() - (7 * 24 * 60 * 60);
$pending_query = "SELECT COALESCE(SUM(sotien), 0) as pending 
                  FROM lichsu_chitieu 
                  WHERE user_id = '$user_id' 
                  AND (noidung LIKE '%Hoa hồng affiliate%' OR noidung LIKE '%Hoa hồng nhóm affiliate%')
                  AND transferred_to_withdrawable = 0 
                  AND date_post > $seven_days_ago";
$pending_result = mysqli_query($conn, $pending_query);
$pending_commission = mysqli_fetch_assoc($pending_result)['pending'] ?? 0;

// Get withdrawable balance (user_money2 or claimable commission after 7 days)
$withdrawable_query = "SELECT user_money2 FROM user_info WHERE user_id = '$user_id' LIMIT 1";
$withdrawable_result = mysqli_query($conn, $withdrawable_query);
$withdrawable_balance = mysqli_fetch_assoc($withdrawable_result)['user_money2'] ?? 0;

// Also get claimable amount (older than 7 days, not yet claimed)
$claimable_query = "SELECT COALESCE(SUM(sotien), 0) as claimable 
                    FROM lichsu_chitieu 
                    WHERE user_id = '$user_id' 
                    AND (noidung LIKE '%Hoa hồng affiliate%' OR noidung LIKE '%Hoa hồng nhóm affiliate%')
                    AND transferred_to_withdrawable = 0 
                    AND date_post <= $seven_days_ago";
$claimable_result = mysqli_query($conn, $claimable_query);
$claimable_amount = mysqli_fetch_assoc($claimable_result)['claimable'] ?? 0;

echo json_encode([
    'success' => true,
    'data' => [
        'total_clicks' => (int) $total_clicks,
        'total_orders' => $total_orders,
        'total_commission' => (float) $total_commission,
        'monthly_revenue' => (float) $monthly_revenue,
        'conversion_rate' => $conversion_rate,
        'conversion_text' => $conversion_text,
        'total_members' => $total_members,
        'pending_commission' => (float) $pending_commission,
        'withdrawable_balance' => (float) $withdrawable_balance,
        'claimable_amount' => (float) $claimable_amount
    ]
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

} else {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Method Not Allowed"
    ]);
    exit;
}