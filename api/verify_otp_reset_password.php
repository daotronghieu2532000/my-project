<?php
/**
 * API Xác thực OTP và đổi mật khẩu
 * 
 * Endpoint: POST /verify_otp_reset_password.php
 * Headers: Authorization: Bearer {JWT_TOKEN}
 * Body: {
 *   "phone_number": "0123456789",
 *   "otp": "123456",
 *   "new_password": "NewPass123!",
 *   "re_password": "NewPass123!"
 * }
 */

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Load config
require_once __DIR__ . '/config.php';

// Cấu hình thông tin JWT
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

// Hàm kiểm tra mật khẩu mạnh
function is_strong_password($password) {
    if (strlen($password) < 8) return false;
    if (!preg_match('/[A-Z]/', $password)) return false;
    if (!preg_match('/[a-z]/', $password)) return false;
    if (!preg_match('/[0-9]/', $password)) return false;
    if (!preg_match('/[!@#$%^&*()_+\-=\[\]{};\':"\\|,.<>\/?]/', $password)) return false;
    return true;
}

// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Không tìm thấy token']);
    exit;
}

$jwt = $matches[1];

try {
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Issuer không hợp lệ']);
        exit;
    }

    // Lấy dữ liệu từ body
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (empty($data['phone_number']) || empty($data['otp']) || empty($data['new_password']) || empty($data['re_password'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Vui lòng cung cấp đầy đủ số điện thoại, OTP, mật khẩu mới và xác nhận mật khẩu']);
        exit;
    }

    $phone_number = preg_replace('/[^0-9]/', '', $data['phone_number']);
    $otp = trim($data['otp']);
    $new_password = $data['new_password'];
    $re_password = $data['re_password'];

    // Validate số điện thoại
    if (strlen($phone_number) !== 10 || $phone_number[0] !== '0') {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Số điện thoại không hợp lệ']);
        exit;
    }

    // Validate OTP (6 chữ số)
    if (!preg_match('/^\d{6}$/', $otp)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Mã OTP phải là 6 chữ số']);
        exit;
    }

    // Kiểm tra mật khẩu mạnh
    if (!is_strong_password($new_password)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt']);
        exit;
    }

    // Kiểm tra mật khẩu khớp
    if ($new_password !== $re_password) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Mật khẩu và xác nhận mật khẩu không khớp']);
        exit;
    }

    // Kiểm tra số điện thoại tồn tại
    $stmt = $conn->prepare("SELECT * FROM user_info WHERE mobile = ? AND shop = '0' LIMIT 1");
    $stmt->bind_param("s", $phone_number);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows == 0) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Số điện thoại không tồn tại']);
        $stmt->close();
        exit;
    }
    
    $user = $result->fetch_assoc();
    $stmt->close();

    // Xóa OTP cũ hết hạn (quá 10 phút)
    $time_limit = time() - 600; // 10 phút
    $stmt = $conn->prepare("DELETE FROM code_otp WHERE dien_thoai = ? AND date_post < ?");
    $stmt->bind_param("si", $phone_number, $time_limit);
    $stmt->execute();
    $stmt->close();

    // Kiểm tra OTP
    $stmt = $conn->prepare("SELECT otp, date_post FROM code_otp WHERE dien_thoai = ? ORDER BY id DESC LIMIT 1");
    $stmt->bind_param("s", $phone_number);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($row = $result->fetch_assoc()) {
        $stored_otp = $row['otp'];
        $otp_time = (int)$row['date_post'];

        // Kiểm tra OTP hợp lệ và chưa hết hạn (10 phút)
        if ($stored_otp !== $otp || (time() - $otp_time) > 600) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'Mã OTP không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu mã mới'
            ]);
            $stmt->close();
            exit;
        }
    } else {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Không tìm thấy mã OTP. Vui lòng yêu cầu mã mới'
        ]);
        $stmt->close();
        exit;
    }
    $stmt->close();

    // Mã hóa và cập nhật mật khẩu
    $hashed_password = md5($new_password);
    $stmt = $conn->prepare("UPDATE user_info SET password = ? WHERE mobile = ? AND shop = '0'");
    $stmt->bind_param("ss", $hashed_password, $phone_number);
    
    if ($stmt->execute()) {
        // Xóa OTP đã sử dụng
        $stmt_delete = $conn->prepare("DELETE FROM code_otp WHERE dien_thoai = ? AND otp = ?");
        $stmt_delete->bind_param("ss", $phone_number, $otp);
        $stmt_delete->execute();
        $stmt_delete->close();

        http_response_code(200);
        echo json_encode([
            'success' => true, 
            'message' => 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại với mật khẩu mới'
        ]);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Lỗi khi cập nhật mật khẩu']);
    }

    $stmt->close();

} catch (Exception $e) {
    error_log("Lỗi verify OTP reset password: " . $e->getMessage());
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Token không hợp lệ: ' . $e->getMessage()]);
}
?>

