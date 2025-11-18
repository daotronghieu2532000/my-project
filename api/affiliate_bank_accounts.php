<?php
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
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
    // Lấy danh sách tài khoản ngân hàng của user
    $accounts_query = "SELECT ba.*, b.name as bank_name, b.code as bank_code, b.logo as bank_logo
                      FROM bank_accounts ba
                      LEFT JOIN banks b ON ba.bank_id = b.id
                      WHERE ba.user_id = '$user_id'
                      ORDER BY ba.is_default DESC, ba.created_at DESC";
    
    $accounts_result = mysqli_query($conn, $accounts_query);
    
    if (!$accounts_result) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
        ]);
        exit;
    }
    
    $bank_accounts = array();
    
    while ($account = mysqli_fetch_assoc($accounts_result)) {
        $account_data = array();
        $account_data['id'] = intval($account['id']);
        $account_data['account_holder'] = $account['account_holder'];
        $account_data['account_number'] = $account['account_number'];
        $account_data['bank_id'] = intval($account['bank_id']);
        $account_data['bank_name'] = $account['bank_name'] ?: '';
        $account_data['bank_code'] = $account['bank_code'] ?: '';
        $account_data['bank_logo'] = $account['bank_logo'] ? 'https://' . $_SERVER['HTTP_HOST'] . '/' . $account['bank_logo'] : '';
        $account_data['is_default'] = (bool) $account['is_default'];
        $account_data['created_at'] = date('Y-m-d H:i:s', $account['created_at']);
        
        $bank_accounts[] = $account_data;
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy danh sách tài khoản ngân hàng thành công",
        "data" => [
            "bank_accounts" => $bank_accounts,
            "total_accounts" => count($bank_accounts)
        ]
    ];
    
    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} else if ($method === 'POST') {
    // Thêm tài khoản ngân hàng mới
    $input = json_decode(file_get_contents('php://input'), true);
    
    $account_holder = isset($input['account_holder']) ? mysqli_real_escape_string($conn, trim($input['account_holder'])) : '';
    $account_number = isset($input['account_number']) ? mysqli_real_escape_string($conn, trim($input['account_number'])) : '';
    $bank_id = isset($input['bank_id']) ? intval($input['bank_id']) : 0;
    $is_default = isset($input['is_default']) ? (bool) $input['is_default'] : false;
    
    if (empty($account_holder) || empty($account_number) || $bank_id <= 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Thông tin tài khoản không đầy đủ"
        ]);
        exit;
    }
    
    // Kiểm tra bank_id có tồn tại không
    $bank_check_query = "SELECT id FROM banks WHERE id = '$bank_id' AND status = 1 LIMIT 1";
    $bank_check_result = mysqli_query($conn, $bank_check_query);
    
    if (!$bank_check_result || mysqli_num_rows($bank_check_result) == 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Ngân hàng không hợp lệ"
        ]);
        exit;
    }
    
    // Kiểm tra tài khoản đã tồn tại chưa
    $duplicate_check_query = "SELECT id FROM bank_accounts WHERE user_id = '$user_id' AND account_number = '$account_number' LIMIT 1";
    $duplicate_check_result = mysqli_query($conn, $duplicate_check_query);
    
    if ($duplicate_check_result && mysqli_num_rows($duplicate_check_result) > 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Tài khoản này đã được thêm trước đó"
        ]);
        exit;
    }
    
    mysqli_autocommit($conn, false);
    
    try {
        $current_time = time();
        
        // Nếu đặt làm mặc định, bỏ mặc định của các tài khoản khác
        if ($is_default) {
            $unset_default_query = "UPDATE bank_accounts SET is_default = 0 WHERE user_id = '$user_id'";
            if (!mysqli_query($conn, $unset_default_query)) {
                throw new Exception('Failed to unset other default accounts');
            }
        }
        
        // Thêm tài khoản mới
        $insert_query = "INSERT INTO bank_accounts (user_id, bank_id, account_number, account_holder, is_default, created_at, updated_at) 
                        VALUES ('$user_id', '$bank_id', '$account_number', '$account_holder', '" . ($is_default ? 1 : 0) . "', '$current_time', '$current_time')";
        
        if (!mysqli_query($conn, $insert_query)) {
            throw new Exception('Failed to add bank account');
        }
        
        $new_account_id = mysqli_insert_id($conn);
        
        mysqli_commit($conn);
        
        http_response_code(201);
        echo json_encode([
            "success" => true,
            "message" => "Thêm tài khoản ngân hàng thành công",
            "data" => [
                "account_id" => $new_account_id
            ]
        ], JSON_UNESCAPED_UNICODE);
        
    } catch (Exception $e) {
        mysqli_rollback($conn);
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi: " . $e->getMessage()
        ]);
    }
    
    mysqli_autocommit($conn, true);
    
} else {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Chỉ hỗ trợ phương thức GET và POST"
    ]);
}
?>
