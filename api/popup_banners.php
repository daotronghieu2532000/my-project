<?php
/**
 * API: Popup Banners
 * Method: GET, POST
 * URL: /v1/popup_banners
 * 
 * Description: 
 * - GET: Lấy popup banner hiển thị trên app
 *   Popup sẽ xuất hiện khi người dùng mở app, có nút X để đóng
 *   Popup sẽ xuất hiện lại khi người dùng reload app
 * 
 * - POST: Tăng click_count khi user click vào popup banner
 *   Body: { "popup_id": 123 }
 */

header("Access-Control-Allow-Methods: GET, POST");
require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $current_time = date('Y-m-d H:i:s');
    
    // Lấy tham số exclude_id (banner đã hiển thị lần trước)
    // Có thể là 1 ID hoặc danh sách ID (comma-separated)
    $exclude_ids = [];
    if (isset($_GET['exclude_id'])) {
        $exclude_id_param = trim($_GET['exclude_id']);
        if (!empty($exclude_id_param)) {
            // Nếu là danh sách (comma-separated), split ra
            if (strpos($exclude_id_param, ',') !== false) {
                $exclude_ids_raw = explode(',', $exclude_id_param);
                foreach ($exclude_ids_raw as $id) {
                    $id = intval(trim($id));
                    if ($id > 0) {
                        $exclude_ids[] = $id;
                    }
                }
            } else {
                // Nếu là 1 ID
                $exclude_id = intval($exclude_id_param);
                if ($exclude_id > 0) {
                    $exclude_ids[] = $exclude_id;
                }
            }
        }
    }
    
    // Lấy popup banner đang active và trong thời gian hiển thị
    // Ưu tiên theo priority (số cao hơn = ưu tiên hơn)
    // Nếu có exclude_ids, loại trừ tất cả banner đó để lấy banner tiếp theo
    $where_conditions = [
        "is_active = 1",
        "(start_at IS NULL OR start_at <= '" . mysqli_real_escape_string($conn, $current_time) . "')",
        "(end_at IS NULL OR end_at >= '" . mysqli_real_escape_string($conn, $current_time) . "')"
    ];
    
    if (!empty($exclude_ids)) {
        // Loại trừ tất cả banner đã hiển thị
        $exclude_ids_escaped = array_map(function($id) use ($conn) {
            return intval($id);
        }, $exclude_ids);
        $exclude_ids_list = implode(',', $exclude_ids_escaped);
        $where_conditions[] = "id NOT IN ($exclude_ids_list)";
    }
    
    $where_clause = "WHERE " . implode(" AND ", $where_conditions);
    
    $query = "SELECT 
                id,
                title,
                image_url,
                target_url,
                start_at,
                end_at,
                is_active,
                priority,
                display_limit_per_user,
                click_count,
                created_at,
                updated_at
              FROM popup_banners 
              $where_clause
              ORDER BY priority DESC, id DESC
              LIMIT 1";
    
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi truy vấn database: ' . mysqli_error($conn)
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    $popup_banner = null;
    
    if ($row = mysqli_fetch_assoc($result)) {
        // Format image URL (thêm domain/CDN nếu chưa có)
        $image_url = $row['image_url'];
        if (!empty($image_url) && strpos($image_url, 'http') !== 0) {
            // Nếu là relative path, thêm CDN domain
            if (strpos($image_url, '/') === 0) {
                // Sử dụng CDN nếu có thể
                if (strpos($image_url, '/uploads/') !== false) {
                    $image_url = 'https://socdo.cdn.vccloud.vn' . $image_url;
                } else {
                    $image_url = 'https://socdo.vn' . $image_url;
                }
            } else {
                $image_url = 'https://socdo.vn/' . $image_url;
            }
        }
        
        // Extract product ID from target_url if it's a product link (giống banners.php)
        $product_id = null;
        $target_url = $row['target_url'] ?? '';
        
        if (!empty($target_url) && (strpos($target_url, 'https://socdo.vn/product/') !== false || 
                                     strpos($target_url, 'https://www.socdo.vn/product/') !== false ||
                                     strpos($target_url, 'http://socdo.vn/product/') !== false ||
                                     strpos($target_url, 'http://www.socdo.vn/product/') !== false)) {
            // Extract slug from URL: https://socdo.vn/product/slug.html -> slug
            $slug = '';
            if (preg_match('/product\/([^\.]+)\.html/', $target_url, $matches)) {
                $slug = $matches[1];
            } elseif (preg_match('/product\/([^\/\?]+)/', $target_url, $matches)) {
                $slug = $matches[1];
            }
            
            if (!empty($slug)) {
                // Query product ID from sanpham table using slug
                $product_query = "SELECT id FROM sanpham WHERE link = '" . mysqli_real_escape_string($conn, $slug) . "' LIMIT 1";
                $product_result = mysqli_query($conn, $product_query);
                if ($product_result && $product_row = mysqli_fetch_assoc($product_result)) {
                    $product_id = intval($product_row['id']);
                }
            }
        }
        
        $popup_banner = [
            'id' => intval($row['id']),
            'title' => $row['title'],
            'image_url' => $image_url,
            'target_url' => $row['target_url'] ?: null,
            'product_id' => $product_id, // Thêm product_id vào response
            'start_at' => $row['start_at'] ?: null,
            'end_at' => $row['end_at'] ?: null,
            'priority' => intval($row['priority']),
            'display_limit_per_user' => intval($row['display_limit_per_user']),
            'click_count' => intval($row['click_count']),
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at']
        ];
    }
    
    // Response
    $response = [
        'success' => true,
        'data' => $popup_banner, // null nếu không có popup nào
        'message' => $popup_banner ? 'Có popup banner' : 'Không có popup banner nào'
    ];
    
    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} else if ($method === 'POST') {
    // Tăng click_count khi user click vào popup banner
    // Đọc JSON body từ request
    $raw_input = file_get_contents('php://input');
    $post_data = null;
    
    if (!empty($raw_input)) {
        $post_data = json_decode($raw_input, true);
        // Nếu json_decode trả về null và có lỗi
        if ($post_data === null && json_last_error() !== JSON_ERROR_NONE) {
            $post_data = null;
        }
    }
    
    // Lấy popup_id từ JSON body hoặc $_POST (fallback)
    $popup_id = 0;
    if ($post_data && is_array($post_data) && isset($post_data['popup_id'])) {
        $popup_id = intval($post_data['popup_id']);
    } elseif (isset($_POST['popup_id'])) {
        $popup_id = intval($_POST['popup_id']);
    } elseif (isset($_REQUEST['popup_id'])) {
        $popup_id = intval($_REQUEST['popup_id']);
    }
    
    if ($popup_id <= 0) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'popup_id không hợp lệ'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Kiểm tra popup banner có tồn tại không
    $check_query = "SELECT id, click_count FROM popup_banners WHERE id = $popup_id LIMIT 1";
    $check_result = mysqli_query($conn, $check_query);
    
    if (!$check_result || mysqli_num_rows($check_result) == 0) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Popup banner không tồn tại'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Tăng click_count
    $update_query = "UPDATE popup_banners SET click_count = click_count + 1 WHERE id = $popup_id";
    $update_result = mysqli_query($conn, $update_query);
    
    if (!$update_result) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi truy vấn database: ' . mysqli_error($conn)
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Lấy click_count mới sau khi update
    $new_click_query = "SELECT click_count FROM popup_banners WHERE id = $popup_id LIMIT 1";
    $new_click_result = mysqli_query($conn, $new_click_query);
    $new_click_count = 0;
    if ($new_click_result && $row = mysqli_fetch_assoc($new_click_result)) {
        $new_click_count = intval($row['click_count']);
    }
    
    $response = [
        'success' => true,
        'message' => 'Click count đã được cập nhật',
        'data' => [
            'popup_id' => $popup_id,
            'click_count' => $new_click_count
        ]
    ];
    
    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} else {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Chỉ hỗ trợ phương thức GET và POST'
    ], JSON_UNESCAPED_UNICODE);
}
?>

