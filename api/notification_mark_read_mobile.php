<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
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
$headers = function_exists('apache_request_headers') ? apache_request_headers() : [];
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$jwt = null;
if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    $jwt = $matches[1];
}

// Lấy user_id từ token hoặc POST data
$user_id = isset($_POST['user_id']) ? intval($_POST['user_id']) : 0;

try {
    if (!$user_id && $jwt) {
        $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
        if (!isset($decoded->iss) || $decoded->iss !== $issuer) {
            http_response_code(401);
            echo json_encode(array("message" => "Issuer không hợp lệ"));
            exit;
        }
        $user_id = isset($decoded->user_id) ? intval($decoded->user_id) : 0;
    }
    
    if ($user_id <= 0) {
        http_response_code(401);
        echo json_encode(array("message" => "Thông tin người dùng không hợp lệ"));
        exit;
    }
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'POST') {
        $notification_id = isset($_POST['notification_id']) ? intval($_POST['notification_id']) : 0;
        $mark_all = isset($_POST['mark_all']) ? filter_var($_POST['mark_all'], FILTER_VALIDATE_BOOLEAN) : false;
        $type = isset($_POST['type']) ? addslashes(trim($_POST['type'])) : null;
        
        if (!$mark_all && $notification_id <= 0) {
            http_response_code(400);
            echo json_encode(array(
                "success" => false,
                "message" => "ID thông báo không hợp lệ"
            ));
            exit;
        }
        
        $current_time = time();
        
        if ($mark_all) {
            // Đánh dấu tất cả thông báo đã đọc
            $where_conditions = array("user_id = '$user_id'", "is_read = 0");
            
            if ($type) {
                $where_conditions[] = "type = '$type'";
            }
            
            $where_clause = implode(' AND ', $where_conditions);
            
            $query = "UPDATE notification_mobile SET is_read = 1, read_at = '$current_time', updated_at = '$current_time' WHERE $where_clause";
            $result = mysqli_query($conn, $query);
            
            if (!$result) {
                http_response_code(500);
                echo json_encode(array(
                    "success" => false,
                    "message" => "Lỗi cập nhật database"
                ));
                exit;
            }
            
            $affected_rows = mysqli_affected_rows($conn);
            
            $response = array(
                'success' => true,
                'message' => "Đã đánh dấu $affected_rows thông báo đã đọc",
                'data' => array(
                    'affected_count' => $affected_rows,
                    'mark_all' => true,
                    'type' => $type
                )
            );
            
        } else {
            // Đánh dấu thông báo cụ thể đã đọc
            $query = "UPDATE notification_mobile SET is_read = 1, read_at = '$current_time', updated_at = '$current_time' WHERE id = '$notification_id' AND user_id = '$user_id'";
            $result = mysqli_query($conn, $query);
            
            if (!$result) {
                http_response_code(500);
                echo json_encode(array(
                    "success" => false,
                    "message" => "Lỗi cập nhật database"
                ));
                exit;
            }
            
            $affected_rows = mysqli_affected_rows($conn);
            
            if ($affected_rows == 0) {
                http_response_code(404);
                echo json_encode(array(
                    "success" => false,
                    "message" => "Không tìm thấy thông báo hoặc không có quyền truy cập"
                ));
                exit;
            }
            
            $response = array(
                'success' => true,
                'message' => 'Đã đánh dấu thông báo đã đọc',
                'data' => array(
                    'notification_id' => $notification_id,
                    'read_at' => $current_time,
                    'mark_all' => false
                )
            );
        }
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
    } else {
        http_response_code(405);
        echo json_encode(array(
            "success" => false,
            "message" => "Chỉ hỗ trợ phương thức POST"
        ));
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
