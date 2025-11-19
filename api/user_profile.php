<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(["success" => false, "message" => "Không tìm thấy token"]);
    exit;
}

$jwt = $matches[1];

try {
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(["success" => false, "message" => "Issuer không hợp lệ"]);
        exit;
    }

    // Hỗ trợ cả JSON body lẫn multipart
    $action = isset($_POST['action']) ? $_POST['action'] : null;
    if (!$action) {
        $json = json_decode(file_get_contents("php://input"), true);
        $action = isset($json['action']) ? $json['action'] : null;
    }

    if (!$action) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Thiếu action"]);
        exit;
    }

    switch ($action) {
        case 'get_info':
            handle_get_info();
            break;
        case 'update_info':
            handle_update_info();
            break;
        case 'upload_avatar':
            handle_upload_avatar();
            break;
        case 'address_set_default':
            handle_address_set_default();
            break;
        case 'address_add':
            handle_address_add();
            break;
        case 'address_update':
            handle_address_update();
            break;
        case 'address_delete':
            handle_address_delete();
            break;
        case 'register_affiliate':
            $user_id = isset($json['user_id']) ? (int)$json['user_id'] : 0;
            if (!$user_id) {
                http_response_code(400);
                echo json_encode(["success" => false, "message" => "Thiếu user_id"]);
                exit;
            }
            $stmt = $conn->prepare("UPDATE user_info SET dk_aff = 1 WHERE user_id = ?");
            $stmt->bind_param('i', $user_id);
            $ok = $stmt->execute();
            $stmt->close();
            if ($ok) {
                http_response_code(200);
                echo json_encode(["success" => true, "message" => "Đăng ký affiliate thành công"]);
            } else {
                http_response_code(500);
                echo json_encode(["success" => false, "message" => "Đăng ký affiliate thất bại"]);
            }
            break;
        default:
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "Action không hỗ trợ"]);
    }

} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(["success" => false, "message" => "Token không hợp lệ"]);
}

function handle_get_info() {
    global $conn;
    $data = json_decode(file_get_contents("php://input"), true);
    $user_id = isset($data['user_id']) ? (int)$data['user_id'] : 0;
    if (!$user_id) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng truyền user_id"]);
        return;
    }

    $columnsRes = $conn->query("SHOW COLUMNS FROM user_info");
    $cols = [];
    while ($row = $columnsRes->fetch_assoc()) {
        if ($row['Field'] !== 'password') { $cols[] = $row['Field']; }
    }
    $colList = implode(',', $cols);

    $stmt = $conn->prepare("SELECT $colList FROM user_info WHERE user_id = ? LIMIT 1");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($res->num_rows === 0) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Không tìm thấy người dùng"]);
        $stmt->close();
        return;
    }
    $user = $res->fetch_assoc();
    $stmt->close();

    $addrStmt = $conn->prepare("SELECT id, ho_ten, dien_thoai, dia_chi, email, xa, huyen, tinh, ten_tinh, ten_huyen, ten_xa, active FROM dia_chi WHERE user_id = ? ORDER BY active DESC, id ASC");
    $addrStmt->bind_param("i", $user_id);
    $addrStmt->execute();
    $addrRes = $addrStmt->get_result();
    $addresses = [];
    while ($r = $addrRes->fetch_assoc()) { $addresses[] = $r; }
    $addrStmt->close();

    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'Lấy thông tin thành công', 'data' => ['user' => $user, 'addresses' => $addresses]]);
}

function handle_update_info() {
    global $conn;
    $data = json_decode(file_get_contents("php://input"), true);
    if (empty($data['user_id'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng truyền user_id"]);
        return;
    }
    $user_id = (int)$data['user_id'];
    $allowed = ['name','email','mobile','ngaysinh','gioi_tinh','dia_chi'];
    $fields = [];
    $params = [];
    $types = '';
    foreach ($allowed as $field) {
        if (isset($data[$field])) { $fields[] = "$field = ?"; $params[] = $data[$field]; $types .= 's'; }
    }
    if (empty($fields)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Không có trường nào để cập nhật"]);
        return;
    }
    $sql = "UPDATE user_info SET " . implode(',', $fields) . ", date_update = ? WHERE user_id = ?";
    $now = time();
    $params[] = $now; $types .= 'i';
    $params[] = $user_id; $types .= 'i';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $ok = $stmt->execute();
    $stmt->close();
    if ($ok) {
        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Cập nhật thông tin thành công']);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Cập nhật thất bại']);
    }
}

function handle_upload_avatar() {
    global $conn;
    
    if (!isset($_POST['user_id'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng truyền user_id"]);
        return;
    }
    $user_id = (int)$_POST['user_id'];
    
    if (!isset($_FILES['avatar']) || $_FILES['avatar']['error'] !== UPLOAD_ERR_OK) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Không có file avatar hợp lệ"]);
        return;
    }
    $file = $_FILES['avatar'];
    
    $allowed = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    if (!isset($allowed[$file['type']])) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Định dạng ảnh không hỗ trợ"]);
        return;
    }
    $ext = $allowed[$file['type']];
    
    // Sửa đường dẫn upload để trỏ đúng đến thư mục chính của website
    $uploadDir = '/home/socdo.vn/public_html/uploads/avatar/';
    
    if (!is_dir($uploadDir)) { 
        if (!mkdir($uploadDir, 0755, true)) {
            http_response_code(500);
            echo json_encode(["success" => false, "message" => "Không thể tạo thư mục upload"]);
            return;
        }
    }
    
    // Kiểm tra quyền ghi
    if (!is_writable($uploadDir)) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Thư mục upload không có quyền ghi"]);
        return;
    }
    
    $filename = 'u' . $user_id . '_' . time() . '.' . $ext;
    $target = $uploadDir . $filename;
    
    if (!move_uploaded_file($file['tmp_name'], $target)) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Lưu file thất bại"]);
        return;
    }
    
    $relativePath = '/uploads/avatar/' . $filename;
    
    $stmt = $conn->prepare("UPDATE user_info SET avatar = ?, date_update = ? WHERE user_id = ?");
    $now = time();
    $stmt->bind_param('sii', $relativePath, $now, $user_id);
    $ok = $stmt->execute();
    $stmt->close();
    
    if ($ok) {
        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Cập nhật avatar thành công', 'data' => ['avatar' => $relativePath]]);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Cập nhật avatar thất bại']);
    }
}

function handle_address_add() {
    global $conn;
    $data = json_decode(file_get_contents("php://input"), true);
    $required = ['user_id','ho_ten','dien_thoai','dia_chi','ten_xa','ten_huyen','ten_tinh'];
    foreach ($required as $r) {
        if (empty($data[$r])) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Thiếu tham số: ' . $r]);
            return;
        }
    }
    $user_id = (int)$data['user_id'];
    $ho_ten = $data['ho_ten'];
    $dien_thoai = $data['dien_thoai'];
    $dia_chi = $data['dia_chi'];
    $email = isset($data['email']) ? $data['email'] : '';
    $ten_xa = $data['ten_xa'];
    $ten_huyen = $data['ten_huyen'];
    $ten_tinh = $data['ten_tinh'];
    $active = isset($data['active']) ? (int)$data['active'] : 0;

    // Nhận ID tỉnh/huyện/xã (lưu dạng string vì cột là varchar)
    $tinh = isset($data['tinh']) ? (string)$data['tinh'] : '';
    $huyen = isset($data['huyen']) ? (string)$data['huyen'] : '';
    $xa = isset($data['xa']) ? (string)$data['xa'] : '';

    if ($active === 1) {
        $stmt = $conn->prepare("UPDATE dia_chi SET active = 0 WHERE user_id = ?");
        $stmt->bind_param('i', $user_id);
        $stmt->execute();
        $stmt->close();
    }

    // Chèn đầy đủ cả mã ID tỉnh/huyện/xã
    $stmt2 = $conn->prepare("INSERT INTO dia_chi(user_id, ho_ten, dien_thoai, dia_chi, email, xa, huyen, tinh, ten_tinh, ten_huyen, ten_xa, active) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt2->bind_param('issssssssssi', $user_id, $ho_ten, $dien_thoai, $dia_chi, $email, $xa, $huyen, $tinh, $ten_tinh, $ten_huyen, $ten_xa, $active);
    $ok = $stmt2->execute();
    $newId = $stmt2->insert_id;
    $stmt2->close();

    if ($ok) {
        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Thêm địa chỉ thành công', 'data' => ['id' => $newId]]);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Thêm địa chỉ thất bại']);
    }
}

function handle_address_set_default() {
    global $conn;
    $data = json_decode(file_get_contents("php://input"), true);
    if (empty($data['user_id']) || empty($data['address_id'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Thiếu user_id hoặc address_id"]);
        return;
    }
    $user_id = (int)$data['user_id'];
    $address_id = (int)$data['address_id'];

    // Kiểm tra địa chỉ có thuộc về user không
    $chk = $conn->prepare("SELECT id FROM dia_chi WHERE id = ? AND user_id = ? LIMIT 1");
    $chk->bind_param('ii', $address_id, $user_id);
    $chk->execute();
    $res = $chk->get_result();
    $belongs = $res && $res->num_rows > 0;
    $chk->close();

    if (!$belongs) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Không tìm thấy địa chỉ hoặc thuộc user khác']);
        return;
    }

    // Bắt đầu cập nhật
    $stmt = $conn->prepare("UPDATE dia_chi SET active = 0 WHERE user_id = ?");
    $stmt->bind_param('i', $user_id);
    $stmt->execute();
    $stmt->close();

    $stmt2 = $conn->prepare("UPDATE dia_chi SET active = 1 WHERE id = ? AND user_id = ?");
    $stmt2->bind_param('ii', $address_id, $user_id);
    $stmt2->execute();
    $stmt2->close();

    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'Cập nhật địa chỉ mặc định thành công']);
}

function handle_address_update() {
    global $conn;
    $data = json_decode(file_get_contents("php://input"), true);
    
    $user_id = isset($data['user_id']) ? (int)$data['user_id'] : 0;
    $address_id = isset($data['address_id']) ? (int)$data['address_id'] : 0;
    $ho_ten = trim($data['ho_ten'] ?? '');
    $dien_thoai = trim($data['dien_thoai'] ?? '');
    $dia_chi = trim($data['dia_chi'] ?? '');
    $ten_tinh = trim($data['ten_tinh'] ?? '');
    $ten_huyen = trim($data['ten_huyen'] ?? '');
    $ten_xa = trim($data['ten_xa'] ?? '');
    // Nhận thêm id tỉnh/huyện/xã
    $tinh = isset($data['tinh']) ? (string)$data['tinh'] : '';
    $huyen = isset($data['huyen']) ? (string)$data['huyen'] : '';
    $xa = isset($data['xa']) ? (string)$data['xa'] : '';
    $active = isset($data['active']) ? (int)$data['active'] : 0;
    
    // Debug log
    error_log("🔧 address_update debug:");
    error_log("  - user_id: $user_id");
    error_log("  - address_id: $address_id");
    error_log("  - ho_ten: '$ho_ten'");
    error_log("  - dien_thoai: '$dien_thoai'");
    error_log("  - dia_chi: '$dia_chi'");
    error_log("  - ten_tinh: '$ten_tinh'");
    error_log("  - ten_huyen: '$ten_huyen'");
    error_log("  - ten_xa: '$ten_xa'");
    error_log("  - tinh: '$tinh' - huyen: '$huyen' - xa: '$xa'");
    
    if (!$user_id || !$address_id) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng truyền user_id và address_id"]);
        return;
    }
    
    if (!$ho_ten || !$dien_thoai || !$dia_chi || !$ten_tinh || !$ten_huyen || !$ten_xa) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng điền đầy đủ thông tin", "debug" => [
            "ho_ten_empty" => empty($ho_ten),
            "dien_thoai_empty" => empty($dien_thoai),
            "dia_chi_empty" => empty($dia_chi),
            "ten_tinh_empty" => empty($ten_tinh),
            "ten_huyen_empty" => empty($ten_huyen),
            "ten_xa_empty" => empty($ten_xa)
        ]]);
        return;
    }
    
    // Kiểm tra địa chỉ có thuộc về user này không
    $check = $conn->prepare("SELECT id FROM dia_chi WHERE id = ? AND user_id = ?");
    $check->bind_param('ii', $address_id, $user_id);
    $check->execute();
    $result = $check->get_result();
    
    if ($result->num_rows == 0) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Không tìm thấy địa chỉ"]);
        return;
    }
    
    // Cập nhật địa chỉ, bao gồm cả id tỉnh/huyện/xã
    $stmt = $conn->prepare("UPDATE dia_chi SET 
        ho_ten = ?, 
        dien_thoai = ?, 
        dia_chi = ?, 
        email = ?,
        xa = ?,
        huyen = ?,
        tinh = ?,
        ten_tinh = ?, 
        ten_huyen = ?, 
        ten_xa = ?,
        active = ?
        WHERE id = ? AND user_id = ?");
    $stmt->bind_param('ssssssssssiii', 
        $ho_ten, $dien_thoai, $dia_chi, $email, 
        $xa, $huyen, $tinh,
        $ten_tinh, $ten_huyen, $ten_xa,
        $active, $address_id, $user_id);
    
    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Cập nhật địa chỉ thành công']);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Lỗi khi cập nhật địa chỉ']);
    }
    $stmt->close();
}

function handle_address_delete() {
    global $conn;
    $data = json_decode(file_get_contents("php://input"), true);
    
    $user_id = isset($data['user_id']) ? (int)$data['user_id'] : 0;
    $address_id = isset($data['address_id']) ? (int)$data['address_id'] : 0;
    
    if (!$user_id || !$address_id) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng truyền user_id và address_id"]);
        return;
    }
    
    // Kiểm tra địa chỉ có thuộc về user này không
    $check = $conn->prepare("SELECT id, active FROM dia_chi WHERE id = ? AND user_id = ?");
    $check->bind_param('ii', $address_id, $user_id);
    $check->execute();
    $result = $check->get_result();
    
    if ($result->num_rows == 0) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Không tìm thấy địa chỉ"]);
        return;
    }
    
    $address = $result->fetch_assoc();
    
    // Nếu địa chỉ đang là mặc định, không cho xóa
    if ($address['active'] == 1) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Không thể xóa địa chỉ mặc định. Vui lòng đặt địa chỉ khác làm mặc định trước"]);
        return;
    }
    
    // Xóa địa chỉ
    $stmt = $conn->prepare("DELETE FROM dia_chi WHERE id = ? AND user_id = ?");
    $stmt->bind_param('ii', $address_id, $user_id);
    
    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Xóa địa chỉ thành công']);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Lỗi khi xóa địa chỉ']);
    }
    $stmt->close();
}
?>


