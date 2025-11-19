<?php
header("Access-Control-Allow-Methods: GET");
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

// Cho phép nhận user_id từ query
$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;

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
    
    if ($method === 'GET') {
        $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
        $limit = isset($_GET['limit']) ? min(1000, max(1, intval($_GET['limit']))) : 20;
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        
        $type = isset($_GET['type']) ? addslashes(trim($_GET['type'])) : null;
        $unread_only = isset($_GET['unread_only']) ? filter_var($_GET['unread_only'], FILTER_VALIDATE_BOOLEAN) : false;
        
        $offset = ($page - 1) * $limit;
        
        // Build WHERE clause
        $where_conditions = array("user_id = '$user_id'");
        
        if ($type) {
            $where_conditions[] = "type = '$type'";
        }
        
        if ($unread_only) {
            $where_conditions[] = "is_read = 0";
        }
        
        $where_clause = implode(' AND ', $where_conditions);
        
        // Get total count
        $count_query = "SELECT COUNT(*) as total FROM notification_mobile WHERE $where_clause";
        $count_result = mysqli_query($conn, $count_query);
        $total_notifications = 0;
        if ($count_result) {
            $total_notifications = mysqli_fetch_assoc($count_result)['total'];
        }
        
        // Get notifications
        $query = "SELECT * FROM notification_mobile WHERE $where_clause ORDER BY created_at DESC LIMIT $offset, $limit";
        $result = mysqli_query($conn, $query);
        
        if (!$result) {
            http_response_code(500);
            echo json_encode(array(
                "success" => false,
                "message" => "Lỗi truy vấn database"
            ));
            exit;
        }
        
        $notifications = array();
        $type_map = array(
            'order' => array('name' => 'Đơn hàng', 'icon' => 'fa-shopping-cart', 'color' => '#007bff'),
            'affiliate_order' => array('name' => 'Đơn hàng Affiliate', 'icon' => 'fa-handshake', 'color' => '#28a745'),
            'deposit' => array('name' => 'Nạp tiền', 'icon' => 'fa-plus-circle', 'color' => '#17a2b8'),
            'withdrawal' => array('name' => 'Rút tiền', 'icon' => 'fa-minus-circle', 'color' => '#ffc107'),
            'voucher_new' => array('name' => 'Voucher mới', 'icon' => 'fa-gift', 'color' => '#dc3545'),
            'voucher_expiring' => array('name' => 'Voucher sắp hết hạn', 'icon' => 'fa-clock', 'color' => '#6f42c1')
        );
        
        while ($notification = mysqli_fetch_assoc($result)) {
            $type_info = isset($type_map[$notification['type']]) ? $type_map[$notification['type']] : $type_map['order'];
            
            // Parse JSON data if exists
            $data = null;
            if (!empty($notification['data'])) {
                $data = json_decode($notification['data'], true);
            }
            
            // Get time ago
            $time_difference = time() - $notification['created_at'];
            if ($time_difference < 60) {
                $time_ago = 'Vừa xong';
            } elseif ($time_difference < 3600) {
                $time_ago = floor($time_difference / 60) . ' phút trước';
            } elseif ($time_difference < 86400) {
                $time_ago = floor($time_difference / 3600) . ' giờ trước';
            } elseif ($time_difference < 2592000) {
                $time_ago = floor($time_difference / 86400) . ' ngày trước';
            } else {
                $time_ago = date('d/m/Y', $notification['created_at']);
            }
            
            // Get action URL based on type and related data
            $action_url = null;
            $related_id = $notification['related_id'];
            $notification_type = $notification['type'];
            
            switch ($notification_type) {
                case 'order':
                    $action_url = $related_id ? '/order-detail.html?id=' . $related_id : '/don-hang.html';
                    break;
                case 'affiliate_order':
                    $action_url = $related_id ? '/affiliate-order-detail.html?id=' . $related_id : '/affiliate-orders.html';
                    break;
                case 'deposit':
                case 'withdrawal':
                    $action_url = '/affiliate-balance.html';
                    break;
                case 'voucher_new':
                case 'voucher_expiring':
                    $action_url = '/voucher-list.html';
                    break;
            }
            
            $notifications[] = array(
                'id' => intval($notification['id']),
                'title' => $notification['title'],
                'content' => $notification['content'],
                'type' => $notification['type'],
                'type_name' => $type_info['name'],
                'type_icon' => $type_info['icon'],
                'type_color' => $type_info['color'],
                'is_read' => $notification['is_read'] == 1,
                'priority' => $notification['priority'],
                'related_id' => intval($notification['related_id']),
                'related_type' => $notification['related_type'],
                'data' => $data,
                'created_at' => intval($notification['created_at']),
                'created_at_formatted' => date('d/m/Y H:i', $notification['created_at']),
                'time_ago' => $time_ago,
                'action_url' => $action_url,
                'read_at' => $notification['read_at'] ? intval($notification['read_at']) : null
            );
        }
        
        // Get unread count
        $unread_query = "SELECT COUNT(*) as unread_count FROM notification_mobile WHERE user_id = '$user_id' AND is_read = 0";
        $unread_result = mysqli_query($conn, $unread_query);
        $unread_count = 0;
        if ($unread_result) {
            $unread_count = mysqli_fetch_assoc($unread_result)['unread_count'];
        }
        
        $total_pages = ceil($total_notifications / $limit);
        
        $response = array(
            'success' => true,
            'message' => 'Lấy danh sách thông báo thành công',
            'data' => array(
                'notifications' => $notifications,
                'unread_count' => intval($unread_count),
                'pagination' => array(
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total_notifications' => intval($total_notifications),
                    'total_pages' => $total_pages,
                    'has_next' => $page < $total_pages,
                    'has_prev' => $page > 1
                ),
                'type_map' => $type_map,
                'filters' => array(
                    'type' => $type,
                    'unread_only' => $unread_only
                )
            )
        );
    
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
    } else {
        http_response_code(405);
        echo json_encode(array(
            "success" => false,
            "message" => "Chỉ hỗ trợ phương thức GET"
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
