<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
// Load config.php - pattern giống các file API khác
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(array("success" => false, "message" => "Không tìm thấy token"));
    exit;
}
$jwt = $matches[1];

try {
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(array("success" => false, "message" => "Token không hợp lệ"));
        exit;
    }

    // Lấy dữ liệu từ request body
    $data = json_decode(file_get_contents("php://input"), true);

    // Validate input
    if (empty($data['user_id']) || empty($data['device_token']) || empty($data['platform'])) {
        http_response_code(400);
        echo json_encode(array(
            "success" => false,
            "message" => "Thiếu thông tin bắt buộc: user_id, device_token, platform"
        ));
        exit;
    }

    $user_id = intval($data['user_id']);
    $device_token = trim($data['device_token']);
    $platform = strtolower(trim($data['platform']));
    $device_model = isset($data['device_model']) ? trim($data['device_model']) : null;
    $app_version = isset($data['app_version']) ? trim($data['app_version']) : null;

    // Validate platform
    if (!in_array($platform, ['android', 'ios'])) {
        http_response_code(400);
        echo json_encode(array(
            "success" => false,
            "message" => "Platform phải là 'android' hoặc 'ios'"
        ));
        exit;
    }

    // Validate device token length (max 191 chars để phù hợp với DB varchar(191))
    if (strlen($device_token) > 191) {
        http_response_code(400);
        echo json_encode(array(
            "success" => false,
            "message" => "Device token quá dài (tối đa 191 ký tự)"
        ));
        exit;
    }

    $current_time = time();

    // Check if token already exists for this user
    $check_query = "SELECT id, is_active FROM device_tokens 
                    WHERE user_id = '$user_id' AND device_token = '" . mysqli_real_escape_string($conn, $device_token) . "' 
                    LIMIT 1";
    $check_result = mysqli_query($conn, $check_query);

    if (mysqli_num_rows($check_result) > 0) {
        // Update existing token
        $row = mysqli_fetch_assoc($check_result);
        $token_id = $row['id'];
        
        $update_query = "UPDATE device_tokens SET 
                        is_active = 1,
                        platform = '" . mysqli_real_escape_string($conn, $platform) . "',
                        " . ($device_model ? "device_model = '" . mysqli_real_escape_string($conn, $device_model) . "'," : "") . "
                        " . ($app_version ? "app_version = '" . mysqli_real_escape_string($conn, $app_version) . "'," : "") . "
                        last_used_at = '$current_time',
                        updated_at = '$current_time'
                        WHERE id = '$token_id'";
        
        if (mysqli_query($conn, $update_query)) {
            http_response_code(200);
            echo json_encode(array(
                "success" => true,
                "message" => "Device token đã được cập nhật",
                "data" => array("token_id" => $token_id)
            ));
        } else {
            http_response_code(500);
            echo json_encode(array(
                "success" => false,
                "message" => "Lỗi cập nhật device token: " . mysqli_error($conn)
            ));
        }
    } else {
        // Insert new token
        $device_model_sql = $device_model ? "'" . mysqli_real_escape_string($conn, $device_model) . "'" : "NULL";
        $app_version_sql = $app_version ? "'" . mysqli_real_escape_string($conn, $app_version) . "'" : "NULL";
        
        $insert_query = "INSERT INTO device_tokens 
                        (user_id, device_token, platform, device_model, app_version, is_active, last_used_at, created_at, updated_at) 
                        VALUES 
                        ('$user_id', 
                         '" . mysqli_real_escape_string($conn, $device_token) . "', 
                         '" . mysqli_real_escape_string($conn, $platform) . "',
                         $device_model_sql,
                         $app_version_sql,
                         1,
                         '$current_time',
                         '$current_time',
                         '$current_time')";
        
        if (mysqli_query($conn, $insert_query)) {
            $token_id = mysqli_insert_id($conn);
            http_response_code(200);
            echo json_encode(array(
                "success" => true,
                "message" => "Device token đã được đăng ký thành công",
                "data" => array("token_id" => $token_id)
            ));
        } else {
            http_response_code(500);
            echo json_encode(array(
                "success" => false,
                "message" => "Lỗi đăng ký device token: " . mysqli_error($conn)
            ));
        }
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

