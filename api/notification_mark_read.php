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

// Lấy token từ header Authorization (tùy chọn nếu có user_id)
$headers = function_exists('apache_request_headers') ? apache_request_headers() : [];
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$jwt = null;
if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    $jwt = $matches[1];
}

// Cho phép truyền user_id qua body/query
$user_id = isset($_POST['user_id']) ? intval($_POST['user_id']) : (isset($_GET['user_id']) ? intval($_GET['user_id']) : 0);

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
        
        if (!$notification_id && !$mark_all) {
            http_response_code(400);
            echo json_encode(array(
                "success" => false,
                "message" => "Thiếu thông tin thông báo"
            ));
            exit;
        }
        
        $success = false;
        $affected_rows = 0;
        
        if ($mark_all) {
            // Mark all notifications as read
            $where_conditions = array("user_id = '$user_id'", "doc = ''");
            
            if ($type) {
                $where_conditions[] = "bo_phan = '$type'";
            }
            
            $where_clause = implode(' AND ', $where_conditions);
            $query = "UPDATE notification SET doc = '1' WHERE $where_clause";
            $result = mysqli_query($conn, $query);
            
            if ($result) {
                $affected_rows = mysqli_affected_rows($conn);
                $success = true;
            }
        } else {
            // Mark specific notification as read
            $query = "UPDATE notification SET doc = '1' WHERE id = '$notification_id' AND user_id = '$user_id'";
            $result = mysqli_query($conn, $query);
            
            if ($result && mysqli_affected_rows($conn) > 0) {
                $success = true;
                $affected_rows = 1;
            }
        }
        
        if ($success) {
            // Get updated unread count
            $unread_query = "SELECT COUNT(*) as unread_count FROM notification WHERE user_id = '$user_id' AND doc = ''";
            $unread_result = mysqli_query($conn, $unread_query);
            $unread_count = 0;
            if ($unread_result) {
                $unread_count = mysqli_fetch_assoc($unread_result)['unread_count'];
            }
            
            $response = array(
                'success' => true,
                'message' => $mark_all ? 'Đã đánh dấu tất cả thông báo là đã đọc' : 'Đã đánh dấu thông báo là đã đọc',
                'data' => array(
                    'unread_count' => intval($unread_count),
                    'affected_rows' => $affected_rows
                )
            );
        } else {
            http_response_code(400);
            $response = array(
                'success' => false,
                'message' => 'Không thể cập nhật trạng thái thông báo'
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

