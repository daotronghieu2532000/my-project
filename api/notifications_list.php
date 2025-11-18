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
        $limit = isset($_GET['limit']) ? min(500, max(1, intval($_GET['limit']))) : 100;
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
            $where_conditions[] = "bo_phan = '$type'";
        }
        
        if ($unread_only) {
            $where_conditions[] = "doc = ''";
        }
        
        $where_clause = implode(' AND ', $where_conditions);
        
        // Get total count
        $count_query = "SELECT COUNT(*) as total FROM notification WHERE $where_clause";
        $count_result = mysqli_query($conn, $count_query);
        $total_notifications = 0;
        if ($count_result) {
            $total_notifications = mysqli_fetch_assoc($count_result)['total'];
        }
        
        // Get notifications
        $query = "SELECT * FROM notification WHERE $where_clause ORDER BY date_post DESC LIMIT $offset, $limit";
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
            'donhang' => array('name' => 'Đơn hàng', 'icon' => 'fa-shopping-cart', 'color' => '#007bff'),
            'san_pham' => array('name' => 'Sản phẩm', 'icon' => 'fa-box', 'color' => '#28a745'),
            'tai_khoan' => array('name' => 'Tài khoản', 'icon' => 'fa-user', 'color' => '#17a2b8'),
            'thanh_toan' => array('name' => 'Thanh toán', 'icon' => 'fa-credit-card', 'color' => '#ffc107'),
            'khuyen_mai' => array('name' => 'Khuyến mại', 'icon' => 'fa-gift', 'color' => '#dc3545'),
            'van_chuyen' => array('name' => 'Vận chuyển', 'icon' => 'fa-truck', 'color' => '#6f42c1')
        );
        
        while ($notification = mysqli_fetch_assoc($result)) {
            $type_info = isset($type_map[$notification['bo_phan']]) ? $type_map[$notification['bo_phan']] : $type_map['donhang'];
            
            // Get time ago
            $time_difference = time() - $notification['date_post'];
            if ($time_difference < 60) {
                $time_ago = 'Vừa xong';
            } elseif ($time_difference < 3600) {
                $time_ago = floor($time_difference / 60) . ' phút trước';
            } elseif ($time_difference < 86400) {
                $time_ago = floor($time_difference / 3600) . ' giờ trước';
            } elseif ($time_difference < 2592000) {
                $time_ago = floor($time_difference / 86400) . ' ngày trước';
            } else {
                $time_ago = date('d/m/Y', $notification['date_post']);
            }
            
            // Get action URL
            $action_url = null;
            $sp_id = $notification['sp_id'];
            $bo_phan = $notification['bo_phan'];
            
            switch ($bo_phan) {
                case 'donhang':
                    if (preg_match('/#(\w+)/', $notification['noi_dung'], $matches)) {
                        $action_url = '/order-detail.html?id=' . $matches[1];
                    } else {
                        $action_url = '/don-hang.html';
                    }
                    break;
                case 'san_pham':
                    $action_url = $sp_id > 0 ? '/sanpham.html?id=' . $sp_id : '/san-pham.html';
                    break;
                case 'tai_khoan':
                    $action_url = '/tai-khoan.html';
                    break;
                case 'thanh_toan':
                    $action_url = '/lich-su-thanh-toan.html';
                    break;
                case 'khuyen_mai':
                    $action_url = '/khuyen-mai.html';
                    break;
            }
            
            // Get priority
            $content = strtolower($notification['noi_dung']);
            $priority = 'low';
            $high_priority_keywords = array('hết hàng', 'hủy đơn', 'lỗi', 'thất bại', 'cảnh báo');
            foreach ($high_priority_keywords as $keyword) {
                if (strpos($content, $keyword) !== false) {
                    $priority = 'high';
                    break;
                }
            }
            if ($priority == 'low' && in_array($bo_phan, array('donhang', 'van_chuyen'))) {
                $priority = 'medium';
            }
            
            $notifications[] = array(
                'id' => intval($notification['id']),
                'title' => isset($notification['tieu_de']) ? $notification['tieu_de'] : '',
                'content' => $notification['noi_dung'],
                'type' => $notification['bo_phan'],
                'type_name' => $type_info['name'],
                'type_icon' => $type_info['icon'],
                'type_color' => $type_info['color'],
                'is_read' => !empty($notification['doc']),
                'is_admin' => $notification['admin'] == '1',
                'sp_id' => intval($notification['sp_id']),
                'date_post' => intval($notification['date_post']),
                'date_post_formatted' => date('d/m/Y H:i', $notification['date_post']),
                'time_ago' => $time_ago,
                'action_url' => $action_url,
                'priority' => $priority
            );
        }
        
        // Get unread count
        $unread_query = "SELECT COUNT(*) as unread_count FROM notification WHERE user_id = '$user_id' AND doc = ''";
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

