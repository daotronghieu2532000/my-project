<?php
// Chat API theo chuẩn của các API khác
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Xử lý preflight request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Include vendor cho JWT
$vendor_path = '/home/api.socdo.vn/public_html/vendor/autoload.php';
require_once $vendor_path;

use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Kết nối database với config thật
$conn = new mysqli('localhost', 'socdo', 'Xdnt.qOPNz8!(cQi', 'socdo');
if ($conn->connect_error) {
    echo json_encode([
        'success' => false,
        'message' => 'Database connection error: ' . $conn->connect_error
    ]);
    exit;
}
$conn->set_charset('utf8mb4');

$key = 'Socdo123@2025';
$issuer = 'api.socdo.vn';

// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Không tìm thấy token']);
    exit;
}

$jwt = $matches[1]; // Lấy token từ Bearer

try {
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    
    // Kiểm tra issuer
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Issuer không hợp lệ']);
        exit;
    }
    
    // Token hợp lệ, tiếp tục xử lý request
    
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Token không hợp lệ: ' . $e->getMessage()
    ]);
    exit;
}

// Parse JSON body if Content-Type is application/json
$json_data = [];
if ($_SERVER['CONTENT_TYPE'] === 'application/json' || strpos($_SERVER['CONTENT_TYPE'], 'application/json') !== false) {
    $input = file_get_contents('php://input');
    if ($input) {
        $json_data = json_decode($input, true) ?? [];
    }
}

// Merge JSON data with POST data
if (!empty($json_data)) {
    $_POST = array_merge($_POST, $json_data);
}

// Lấy action từ request
$action = $_POST['action'] ?? $_GET['action'] ?? '';

// Debug log
error_log('[Chat API] Action: ' . $action . ', POST: ' . json_encode($_POST) . ', JSON: ' . json_encode($json_data));

// === LẤY DANH SÁCH TIN NHẮN ===
if ($action === 'get_messages') {
    $phien = $_POST['phien'] ?? $_GET['phien'] ?? '';
    $page = intval($_POST['page'] ?? $_GET['page'] ?? 1);
    $limit = intval($_POST['limit'] ?? $_GET['limit'] ?? 50);
    
    if (!$phien) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp phien'
        ]);
        exit;
    }
    
    if ($page < 1) $page = 1;
    if ($limit < 1 || $limit > 100) $limit = 50;
    
    $offset = ($page - 1) * $limit;
    
    try {
        // Kiểm tra phiên chat có tồn tại không
        $check_session = $conn->query("SELECT id, shop_id, customer_id FROM chat_sessions_ncc WHERE phien = '$phien' AND status = 'active' LIMIT 1");
        if (!$check_session || $check_session->num_rows == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Phiên chat không tồn tại hoặc đã đóng'
            ]);
            exit;
        }
        
        $session = $check_session->fetch_assoc();
        
        // Lấy tin nhắn
        $messages_query = "SELECT 
            c.id,
            c.phien,
            c.shop_id,
            c.customer_id,
            c.sender_id,
            c.sender_type,
            c.noi_dung,
            c.doc,
            c.date_post,
            c.product_id,
            c.variant_id,
            ui.name as sender_name,
            ui.avatar as sender_avatar
        FROM chat_ncc c
        LEFT JOIN user_info ui ON c.sender_id = ui.user_id
        WHERE c.phien = '$phien' AND c.active = 1
        ORDER BY c.date_post ASC
        LIMIT $limit OFFSET $offset";
        
        $messages_result = $conn->query($messages_query);
        $messages = [];
        
        if ($messages_result) {
            while ($row = $messages_result->fetch_assoc()) {
                $messages[] = [
                    'id' => $row['id'],
                    'phien' => $row['phien'],
                    'sender_id' => $row['sender_id'],
                    'sender_type' => $row['sender_type'],
                    'sender_name' => $row['sender_name'] ?: 'Unknown',
                    'sender_avatar' => $row['sender_avatar'] ?: '/images/user.png',
                    'content' => $row['noi_dung'],
                    'is_read' => (bool)$row['doc'],
                    'date_post' => $row['date_post'],
                    'date_formatted' => date('Y-m-d H:i:s', $row['date_post']),
                    'product_id' => $row['product_id'],
                    'variant_id' => $row['variant_id']
                ];
            }
        }
        
        // Đếm tổng số tin nhắn
        $count_query = "SELECT COUNT(*) as total FROM chat_ncc WHERE phien = '$phien' AND active = 1";
        $count_result = $conn->query($count_query);
        $total = $count_result ? $count_result->fetch_assoc()['total'] : 0;
        
        echo json_encode([
            'success' => true,
            'messages' => $messages,
            'pagination' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $total,
                'total_pages' => ceil($total / $limit)
            ]
        ]);
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === GỬI TIN NHẮN ===
if ($action === 'send_message') {
    $phien = $_POST['phien'] ?? '';
    $content = $_POST['content'] ?? '';
    $sender_type = $_POST['sender_type'] ?? 'customer'; // customer hoặc ncc
    $product_id = intval($_POST['product_id'] ?? 0);
    $variant_id = intval($_POST['variant_id'] ?? 0);
    
    if (!$phien) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp phien'
        ]);
        exit;
    }
    
    if (!$content) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng nhập nội dung tin nhắn'
        ]);
        exit;
    }
    
    if (!in_array($sender_type, ['customer', 'ncc'])) {
        echo json_encode([
            'success' => false,
            'message' => 'sender_type phải là customer hoặc ncc'
        ]);
        exit;
    }
    
    // Kiểm tra quyền gửi tin nhắn dựa trên sender_type
    if ($sender_type === 'customer') {
        // Chỉ khách hàng và dropship/nhân viên mới được gửi tin nhắn với sender_type = customer
        // CTV không được gửi tin nhắn với vai trò khách hàng
        $check_user = $conn->query("SELECT user_id, shop, ctv, dropship, nhan_vien FROM user_info WHERE user_id = $user_id AND active = 1 LIMIT 1");
        if ($check_user && $check_user->num_rows > 0) {
            $user_info = $check_user->fetch_assoc();
            if ($user_info['ctv'] > 0) {
                echo json_encode([
                    'success' => false,
                    'message' => 'Tài khoản cộng tác viên (CTV) không thể gửi tin nhắn với vai trò khách hàng'
                ]);
                exit;
            }
        }
    }
    
    try {
        // Kiểm tra phiên chat có tồn tại không
        $check_session = $conn->query("SELECT id, shop_id, customer_id FROM chat_sessions_ncc WHERE phien = '$phien' AND status = 'active' LIMIT 1");
        if (!$check_session || $check_session->num_rows == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Phiên chat không tồn tại hoặc đã đóng'
            ]);
            exit;
        }
        
        $session = $check_session->fetch_assoc();
        $shop_id = $session['shop_id'];
        $customer_id = $session['customer_id'];
        
        // Xác định sender_id dựa trên sender_type
        $sender_id = ($sender_type === 'customer') ? $customer_id : $shop_id;
        
        // Lưu tin nhắn
        $now = time();
        $content_escaped = $conn->real_escape_string($content);
        
        $insert_message = $conn->query("INSERT INTO chat_ncc (phien, shop_id, customer_id, sender_id, sender_type, noi_dung, date_post, product_id, variant_id) VALUES ('$phien', $shop_id, $customer_id, $sender_id, '$sender_type', '$content_escaped', $now, $product_id, $variant_id)");
        
        if ($insert_message) {
            $message_id = $conn->insert_id;
            
            // Cập nhật last_message_time trong session
            $conn->query("UPDATE chat_sessions_ncc SET last_message_time = $now WHERE phien = '$phien'");
            
            // Cập nhật unread count - chỉ tăng khi shop gửi tin cho customer
            if ($sender_type === 'ncc') {
                $conn->query("UPDATE chat_sessions_ncc SET unread_count_customer = unread_count_customer + 1 WHERE phien = '$phien'");
            } else {
                $conn->query("UPDATE chat_sessions_ncc SET unread_count_ncc = unread_count_ncc + 1 WHERE phien = '$phien'");
            }
            
            echo json_encode([
                'success' => true,
                'message_id' => $message_id,
                'message' => 'Tin nhắn đã được gửi thành công'
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => 'Không thể gửi tin nhắn: ' . $conn->error
            ]);
        }
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === ĐÁNH DẤU ĐÃ ĐỌC ===
if ($action === 'mark_read') {
    $phien = $_POST['phien'] ?? $_GET['phien'] ?? '';
    $message_ids = $_POST['message_ids'] ?? $_GET['message_ids'] ?? '';
    $mark_all = $_POST['mark_all'] ?? $_GET['mark_all'] ?? false;
    
    if (!$phien) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp phien'
        ]);
        exit;
    }
    
    try {
        // Kiểm tra phiên chat có tồn tại không
        $check_session = $conn->query("SELECT id FROM chat_sessions_ncc WHERE phien = '$phien' AND status = 'active' LIMIT 1");
        if (!$check_session || $check_session->num_rows == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Phiên chat không tồn tại hoặc đã đóng'
            ]);
            exit;
        }
        
        if ($mark_all) {
            // Đánh dấu tất cả tin nhắn trong phiên là đã đọc
            $update_result = $conn->query("UPDATE chat_ncc SET doc = 1 WHERE phien = '$phien' AND active = 1");
            
            if ($update_result) {
                // Reset unread count
                $conn->query("UPDATE chat_sessions_ncc SET unread_count_customer = 0, unread_count_ncc = 0 WHERE phien = '$phien'");
                
                echo json_encode([
                    'success' => true,
                    'message' => 'Đã đánh dấu tất cả tin nhắn là đã đọc'
                ]);
            } else {
                echo json_encode([
                    'success' => false,
                    'message' => 'Không thể cập nhật trạng thái đọc: ' . $conn->error
                ]);
            }
        } else {
            // Đánh dấu các tin nhắn cụ thể
            if (!$message_ids) {
                echo json_encode([
                    'success' => false,
                    'message' => 'Vui lòng cung cấp message_ids hoặc đặt mark_all = true'
                ]);
                exit;
            }
            
            $message_ids_array = is_array($message_ids) ? $message_ids : explode(',', $message_ids);
            $message_ids_escaped = array_map(function($id) use ($conn) {
                return intval($id);
            }, $message_ids_array);
            
            $ids_string = implode(',', $message_ids_escaped);
            $update_result = $conn->query("UPDATE chat_ncc SET doc = 1 WHERE id IN ($ids_string) AND phien = '$phien' AND active = 1");
            
            if ($update_result) {
                echo json_encode([
                    'success' => true,
                    'message' => 'Đã đánh dấu tin nhắn là đã đọc'
                ]);
            } else {
                echo json_encode([
                    'success' => false,
                    'message' => 'Không thể cập nhật trạng thái đọc: ' . $conn->error
                ]);
            }
        }
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === LẤY DANH SÁCH PHIÊN CHAT ===
if ($action === 'list_sessions') {
    $user_id = intval($_POST['user_id'] ?? $_GET['user_id'] ?? 0);
    $user_type = $_POST['user_type'] ?? $_GET['user_type'] ?? 'customer'; // customer hoặc ncc
    $page = intval($_POST['page'] ?? $_GET['page'] ?? 1);
    $limit = intval($_POST['limit'] ?? $_GET['limit'] ?? 20);
    
    if (!$user_id) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp user_id'
        ]);
        exit;
    }
    
    if (!in_array($user_type, ['customer', 'ncc'])) {
        echo json_encode([
            'success' => false,
            'message' => 'user_type phải là customer hoặc ncc'
        ]);
        exit;
    }
    
    if ($page < 1) $page = 1;
    if ($limit < 1 || $limit > 100) $limit = 20;
    
    $offset = ($page - 1) * $limit;
    
    try {
        // Xây dựng điều kiện WHERE dựa trên user_type
        if ($user_type === 'customer') {
            $where_condition = "s.customer_id = $user_id";
        } else {
            $where_condition = "s.shop_id = $user_id";
        }
        
        // Lấy danh sách phiên chat với unread count thực tế
        $sessions_query = "SELECT 
            s.id,
            s.phien,
            s.shop_id,
            s.customer_id,
            s.last_message_time,
            s.status,
            s.created_at,
            shop.name as shop_name,
            shop.avatar as shop_avatar,
            customer.name as customer_name,
            customer.avatar as customer_avatar,
            last_msg.noi_dung as last_message,
            last_msg.sender_type as last_sender_type,
            last_msg.date_post as last_message_time,
            COALESCE(unread_count.unread_count, 0) as unread_count_customer
        FROM chat_sessions_ncc s
        LEFT JOIN user_info shop ON s.shop_id = shop.user_id
        LEFT JOIN user_info customer ON s.customer_id = customer.user_id
        LEFT JOIN (
            SELECT phien, noi_dung, sender_type, date_post
            FROM chat_ncc 
            WHERE active = 1
            ORDER BY date_post DESC
        ) last_msg ON s.phien = last_msg.phien
        LEFT JOIN (
            SELECT phien, COUNT(*) as unread_count
            FROM chat_ncc 
            WHERE active = 1 AND doc = 0 AND sender_type = 'ncc'
            GROUP BY phien
        ) unread_count ON s.phien = unread_count.phien
        WHERE $where_condition AND s.status = 'active'
        ORDER BY s.last_message_time DESC
        LIMIT $limit OFFSET $offset";
        
        $sessions_result = $conn->query($sessions_query);
        $sessions = [];
        
        if ($sessions_result) {
            while ($row = $sessions_result->fetch_assoc()) {
                $sessions[] = [
                    'id' => $row['id'],
                    'phien' => $row['phien'],
                    'shop_id' => $row['shop_id'],
                    'customer_id' => $row['customer_id'],
                    'shop_name' => $row['shop_name'] ?: 'Unknown Shop',
                    'shop_avatar' => $row['shop_avatar'] ?: '/images/user.png',
                    'customer_name' => $row['customer_name'] ?: 'Unknown Customer',
                    'customer_avatar' => $row['customer_avatar'] ?: '/images/user.png',
                    'last_message' => $row['last_message'] ?: '',
                    'last_sender_type' => $row['last_sender_type'] ?: '',
                    'last_message_time' => $row['last_message_time'] ?: 0,
                    'last_message_formatted' => $row['last_message_time'] ? date('Y-m-d H:i:s', $row['last_message_time']) : '',
                    'unread_count_customer' => $row['unread_count_customer'],
                    'unread_count_ncc' => $row['unread_count_ncc'],
                    'status' => $row['status'],
                    'created_at' => $row['created_at'],
                    'created_formatted' => date('Y-m-d H:i:s', $row['created_at'])
                ];
            }
        }
        
        // Đếm tổng số phiên
        $count_query = "SELECT COUNT(*) as total FROM chat_sessions_ncc s WHERE $where_condition AND s.status = 'active'";
        $count_result = $conn->query($count_query);
        $total = $count_result ? $count_result->fetch_assoc()['total'] : 0;
        
        echo json_encode([
            'success' => true,
            'sessions' => $sessions,
            'pagination' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $total,
                'total_pages' => ceil($total / $limit)
            ]
        ]);
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === ĐẾM TIN NHẮN CHƯA ĐỌC ===
if ($action === 'get_unread_count') {
    $user_id = intval($_POST['user_id'] ?? $_GET['user_id'] ?? 0);
    $user_type = $_POST['user_type'] ?? $_GET['user_type'] ?? 'customer';
    
    if (!$user_id) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp user_id'
        ]);
        exit;
    }
    
    if (!in_array($user_type, ['customer', 'ncc'])) {
        echo json_encode([
            'success' => false,
            'message' => 'user_type phải là customer hoặc ncc'
        ]);
        exit;
    }
    
    try {
        if ($user_type === 'customer') {
            $count_query = "SELECT SUM(unread_count_customer) as total FROM chat_sessions_ncc WHERE customer_id = $user_id AND status = 'active'";
        } else {
            $count_query = "SELECT SUM(unread_count_ncc) as total FROM chat_sessions_ncc WHERE shop_id = $user_id AND status = 'active'";
        }
        
        $count_result = $conn->query($count_query);
        $total = $count_result ? $count_result->fetch_assoc()['total'] : 0;
        
        echo json_encode([
            'success' => true,
            'unread_count' => (int)$total
        ]);
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === ĐÓNG PHIÊN CHAT ===
if ($action === 'close_session') {
    $phien = $_POST['phien'] ?? $_GET['phien'] ?? '';
    
    if (!$phien) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp phien'
        ]);
        exit;
    }
    
    try {
        // Kiểm tra phiên chat có tồn tại không
        $check_session = $conn->query("SELECT id FROM chat_sessions_ncc WHERE phien = '$phien' AND status = 'active' LIMIT 1");
        if (!$check_session || $check_session->num_rows == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Phiên chat không tồn tại hoặc đã đóng'
            ]);
            exit;
        }
        
        // Đóng phiên chat
        $close_result = $conn->query("UPDATE chat_sessions_ncc SET status = 'closed' WHERE phien = '$phien'");
        
        if ($close_result) {
            echo json_encode([
                'success' => true,
                'message' => 'Phiên chat đã được đóng'
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => 'Không thể đóng phiên chat: ' . $conn->error
            ]);
        }
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === XÓA PHIÊN CHAT ===
if ($action === 'delete_session') {
    $phien = $_POST['phien'] ?? $_GET['phien'] ?? '';
    $user_type = $_POST['user_type'] ?? $_GET['user_type'] ?? 'customer';
    
    if (!$phien) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp phien'
        ]);
        exit;
    }
    
    if (!in_array($user_type, ['customer', 'ncc'])) {
        echo json_encode([
            'success' => false,
            'message' => 'user_type phải là customer hoặc ncc'
        ]);
        exit;
    }
    
    try {
        // Kiểm tra phiên chat có tồn tại không
        $check_session = $conn->query("SELECT id, shop_id, customer_id FROM chat_sessions_ncc WHERE phien = '$phien' AND status != 'deleted' LIMIT 1");
        if (!$check_session || $check_session->num_rows == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Phiên chat không tồn tại hoặc đã bị xóa'
            ]);
            exit;
        }
        
        $session = $check_session->fetch_assoc();
        
        // ✅ Xóa phiên chat (set status = 'deleted')
        // Lưu ý: Không xóa tin nhắn, chỉ đánh dấu session là deleted
        $delete_result = $conn->query("UPDATE chat_sessions_ncc SET status = 'deleted' WHERE phien = '$phien'");
        
        if ($delete_result) {
            echo json_encode([
                'success' => true,
                'message' => 'Cuộc trò chuyện đã được xóa'
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => 'Không thể xóa cuộc trò chuyện: ' . $conn->error
            ]);
        }
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === TẠO PHIÊN CHAT ===
if ($action === 'create_session') {
    // Lấy dữ liệu từ POST hoặc GET
    $user_id = 0;
    $shop_id = 0;
    
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // POST request - lấy từ JSON body
        $data = json_decode(file_get_contents('php://input'), true);
        $user_id = intval($data['user_id'] ?? 0);
        $shop_id = intval($data['shop_id'] ?? 0);
    } else {
        // GET request - lấy từ query string
        $user_id = intval($_GET['user_id'] ?? 0);
        $shop_id = intval($_GET['shop_id'] ?? 0);
    }
    
    if (!$user_id) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp user_id'
        ]);
        exit;
    }
    
    if (!$shop_id) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp shop_id'
        ]);
        exit;
    }
    
    try {
        // Kiểm tra user có tồn tại không và có phải là khách hàng không
        $check_user = $conn->query("SELECT user_id, name, shop, ctv, dropship, nhan_vien FROM user_info WHERE user_id = $user_id AND active = 1 LIMIT 1");
        if (!$check_user || $check_user->num_rows == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'User không tồn tại hoặc không hoạt động'
            ]);
            exit;
        }
        
        $user_info = $check_user->fetch_assoc();
        
        // Kiểm tra user có phải là CTV không (CTV không được chat với nhà bán khác)
        if ($user_info['ctv'] > 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Tài khoản cộng tác viên (CTV) không thể sử dụng chức năng chat khách hàng',
                'user_type' => 'ctv',
                'user_info' => [
                    'shop' => $user_info['shop'],
                    'ctv' => $user_info['ctv'],
                    'dropship' => $user_info['dropship'],
                    'nhan_vien' => $user_info['nhan_vien']
                ]
            ]);
            exit;
        }
        
        // Kiểm tra shop có tồn tại không và có phải là nhà bán không
        $check_shop = $conn->query("SELECT user_id, name, avatar, shop, ctv, dropship, nhan_vien FROM user_info WHERE user_id = $shop_id AND active = 1 LIMIT 1");
        if (!$check_shop || $check_shop->num_rows == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Shop không tồn tại hoặc không hoạt động'
            ]);
            exit;
        }
        
        $shop_info = $check_shop->fetch_assoc();
        
        // Kiểm tra shop có phải là nhà bán không (shop > 0 hoặc có vai trò đặc biệt)
        if ($shop_info['shop'] == 0 && $shop_info['ctv'] == 0 && $shop_info['dropship'] == 0 && $shop_info['nhan_vien'] == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Tài khoản này không phải là nhà bán',
                'shop_type' => 'customer'
            ]);
            exit;
        }
        
        // Kiểm tra phiên chat đã tồn tại chưa
        $check_session = $conn->query("SELECT id, phien FROM chat_sessions_ncc WHERE shop_id = $shop_id AND customer_id = $user_id AND status = 'active' LIMIT 1");
        
        if ($check_session && $check_session->num_rows > 0) {
            $session = $check_session->fetch_assoc();
            echo json_encode([
                'success' => true,
                'session_id' => $session['id'],
                'phien' => $session['phien'],
                'shop_info' => [
                    'shop_id' => $shop_info['user_id'],
                    'shop_name' => $shop_info['name'],
                    'shop_avatar' => $shop_info['avatar'] ?: '/images/user.png'
                ]
            ]);
            exit;
        }
        
        // Tạo phiên chat mới
        $phien = md5($shop_id . '_' . $user_id . '_' . time() . '_' . rand(1000, 9999));
        $now = time();
        
        $create_session = $conn->query("INSERT INTO chat_sessions_ncc (phien, shop_id, customer_id, last_message_time, created_at) VALUES ('$phien', $shop_id, $user_id, $now, $now)");
        
        if ($create_session) {
            $session_id = $conn->insert_id;
            echo json_encode([
                'success' => true,
                'session_id' => $session_id,
                'phien' => $phien,
                'shop_info' => [
                    'shop_id' => $shop_info['user_id'],
                    'shop_name' => $shop_info['name'],
                    'shop_avatar' => $shop_info['avatar'] ?: '/images/user.png'
                ]
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => 'Không thể tạo phiên chat: ' . $conn->error
            ]);
        }
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === WEBSOCKET CONNECT ACTION ===
if ($action === 'websocket_connect') {
    $phien = $_GET['phien'] ?? '';
    $session_id = $_GET['session_id'] ?? '';
    
    if (empty($phien)) {
        echo json_encode([
            'success' => false,
            'message' => 'Phien không được cung cấp'
        ]);
        exit;
    }
    
    // Return WebSocket connection info
    echo json_encode([
        'success' => true,
        'websocket_url' => 'ws://api.socdo.vn:8080',
        'phien' => $phien,
        'session_id' => $session_id,
        'status' => 'ready',
        'message' => 'WebSocket server ready'
    ]);
    exit;
}

// === SSE CONNECT ACTION ===
if ($action === 'sse_connect') {
    // Redirect to SSE endpoint
    $phien = $_GET['phien'] ?? '';
    $session_id = $_GET['session_id'] ?? '';
    
    if (empty($phien)) {
        echo json_encode([
            'success' => false,
            'message' => 'Phien không được cung cấp'
        ]);
        exit;
    }
    
    // Set SSE headers
    header('Content-Type: text/event-stream');
    header('Cache-Control: no-cache');
    header('Connection: keep-alive');
    
    // Send initial connection confirmation
    echo "data: " . json_encode([
        'type' => 'connection',
        'status' => 'connected',
        'session_id' => $session_id,
        'phien' => $phien,
        'timestamp' => time()
    ]) . "\n\n";
    
    // Flush output
    if (ob_get_level()) {
        ob_flush();
    }
    flush();
    
        // Simple SSE loop - just send test messages and close quickly
        echo "data: " . json_encode([
            'type' => 'new_message',
            'message' => [
                'id' => 999,
                'sender_id' => 23933,
                'sender_type' => 'shop',
                'sender_name' => 'Shop',
                'sender_avatar' => '/images/shop.png',
                'content' => 'Test message from SSE endpoint',
                'date_post' => time(),
                'date_formatted' => date('H:i'),
                'is_read' => false
            ],
            'timestamp' => time()
        ]) . "\n\n";
        
        if (ob_get_level()) {
            ob_flush();
        }
        flush();
        
        // Close connection after sending test message
        echo "data: " . json_encode([
            'type' => 'session_closed',
            'reason' => 'test_complete',
            'timestamp' => time()
        ]) . "\n\n";
    
    exit;
}

// === RESET UNREAD COUNT ===
if ($action === 'reset_unread') {
    $phien = $_POST['phien'] ?? $_GET['phien'] ?? '';
    $user_type = $_POST['user_type'] ?? $_GET['user_type'] ?? 'customer';
    
    if (!$phien) {
        echo json_encode([
            'success' => false,
            'message' => 'Vui lòng cung cấp phien'
        ]);
        exit;
    }
    
    try {
        // Kiểm tra phiên chat có tồn tại không
        $check_session = $conn->query("SELECT id FROM chat_sessions_ncc WHERE phien = '$phien' AND status = 'active' LIMIT 1");
        if (!$check_session || $check_session->num_rows == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Phiên chat không tồn tại hoặc đã đóng'
            ]);
            exit;
        }
        
        // Reset unread count dựa trên user_type
        if ($user_type === 'customer') {
            $conn->query("UPDATE chat_sessions_ncc SET unread_count_customer = 0 WHERE phien = '$phien'");
            $conn->query("UPDATE chat_ncc SET doc = 1 WHERE phien = '$phien' AND sender_type = 'ncc' AND active = 1");
        } else {
            $conn->query("UPDATE chat_sessions_ncc SET unread_count_ncc = 0 WHERE phien = '$phien'");
            $conn->query("UPDATE chat_ncc SET doc = 1 WHERE phien = '$phien' AND sender_type = 'customer' AND active = 1");
        }
        
        echo json_encode([
            'success' => true,
            'message' => 'Đã reset unread count'
        ]);
    } catch (Exception $e) {
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi hệ thống: ' . $e->getMessage()
        ]);
    }
    exit;
}

// === TEST ACTION ===
if ($action === 'test') {
    // Check if this is SSE request
    $phien = $_GET['phien'] ?? '';
    $session_id = $_GET['session_id'] ?? '';
    
    if (!empty($phien)) {
        // This is SSE request
        // Set SSE headers
        header('Content-Type: text/event-stream');
        header('Cache-Control: no-cache');
        header('Connection: keep-alive');
        header('Access-Control-Allow-Origin: *');
        
        // Send initial connection confirmation
        echo "data: " . json_encode([
            'type' => 'connection',
            'status' => 'connected',
            'session_id' => $session_id,
            'phien' => $phien,
            'timestamp' => time()
        ]) . "\n\n";
        
        // Flush output
        if (ob_get_level()) {
            ob_flush();
        }
        flush();
        
        // Database connection với config thật
        $conn = new mysqli('localhost', 'socdo', 'Xdnt.qOPNz8!(cQi', 'socdo');
        
        if ($conn->connect_error) {
            echo "data: " . json_encode(['type' => 'error', 'message' => 'Database connection failed']) . "\n\n";
            exit();
        }
        
        // SSE loop with database check
        $counter = 0;
        $last_message_id = 0;
        
        while (true) {
            // Check if client disconnected
            if (connection_aborted()) {
                break;
            }
            
            // Check for new messages every 2 seconds
            if ($counter % 2 == 0) {
                $messages_query = "SELECT * FROM chat_ncc WHERE phien = '$phien' AND id > $last_message_id AND active = 1 ORDER BY id ASC LIMIT 10";
                $messages_result = $conn->query($messages_query);
                
                if ($messages_result && $messages_result->num_rows > 0) {
                    while ($message = $messages_result->fetch_assoc()) {
                        echo "data: " . json_encode([
                            'type' => 'new_message',
                            'message' => [
                                'id' => $message['id'],
                                'sender_id' => $message['sender_id'],
                                'sender_type' => $message['sender_type'],
                                'sender_name' => $message['sender_type'] == 'customer' ? 'Bạn' : 'Shop',
                                'sender_avatar' => $message['sender_type'] == 'customer' ? '/images/user.png' : '/images/shop.png',
                                'content' => $message['noi_dung'],
                                'date_post' => $message['date_post'],
                                'date_formatted' => date('H:i', $message['date_post']),
                                'is_read' => $message['doc']
                            ],
                            'timestamp' => time()
                        ]) . "\n\n";
                        
                        $last_message_id = $message['id'];
                    }
                    
                    if (ob_get_level()) {
                        ob_flush();
                    }
                    flush();
                }
            }
            
            // Send heartbeat every 10 seconds
            if ($counter % 10 == 0) {
                echo "data: " . json_encode([
                    'type' => 'heartbeat',
                    'counter' => $counter,
                    'timestamp' => time()
                ]) . "\n\n";
                
                if (ob_get_level()) {
                    ob_flush();
                }
                flush();
            }
            
            // Sleep for 1 second
            sleep(1);
            $counter++;
            
            // Limit loop to prevent infinite running
            if ($counter > 300) { // 5 minutes max
                break;
            }
        }
        
        echo "data: " . json_encode([
            'type' => 'session_closed',
            'reason' => 'timeout',
            'timestamp' => time()
        ]) . "\n\n";
        
        exit;
    }
    
    // Regular test response
    echo json_encode([
        'success' => true,
        'message' => 'API hoạt động bình thường',
        'action' => $action,
        'timestamp' => time()
    ]);
    exit;
}

// Action không hợp lệ
echo json_encode([
    'success' => false,
    'message' => 'Action không hợp lệ',
    'available_actions' => [
        'create_session',
        'get_messages', 
        'send_message',
        'mark_read',
        'list_sessions',
        'get_unread_count',
        'close_session',
        'delete_session',
        'reset_unread',
        'sse_connect',
        'websocket_connect',
        'test'
    ]
]);

$conn->close();
?>
