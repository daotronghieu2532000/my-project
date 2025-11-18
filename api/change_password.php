<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";
$expiration_time = 3600; // Token có hiệu lực trong 1 giờ

// Kết nối cơ sở dữ liệu


// Hàm kiểm tra mật khẩu mạnh
function is_strong_password($password) {
    return preg_match('/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/', $password);
}

// Kiểm tra nếu đã đăng nhập qua cookie
if (isset($_COOKIE['user_id'])) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Thất bại! Bạn đã đăng nhập...']);
    exit;
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
    $data = json_decode(file_get_contents('php://input'));
    if (empty($data->email) || empty($data->password) || empty($data->re_password) || empty($data->otp)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Vui lòng cung cấp đầy đủ email, password, re_password và OTP']);
        exit;
    }

    $email = filter_var($data->email, FILTER_VALIDATE_EMAIL);
    if ($email === false) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Email không hợp lệ']);
        exit;
    }

    $password = $data->password;
    $re_password = $data->re_password;
    $otp = $data->otp;

    // Kiểm tra mật khẩu mạnh
    if (!is_strong_password($password)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt']);
        exit;
    }

    // Kiểm tra mật khẩu khớp
    if ($password !== $re_password) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Mật khẩu và xác nhận mật khẩu không khớp']);
        exit;
    }

    // Kiểm tra quyền sở hữu email (nếu JWT chứa email)
    if (isset($decoded->email) && $decoded->email !== $email) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Bạn không có quyền đổi mật khẩu cho email này']);
        exit;
    }

    // Xóa OTP cũ hết hạn
    $stmt = $conn->prepare("DELETE FROM code_otp WHERE dien_thoai = ? AND date_post < ?");
    $time_limit = (string)(time() - 600); // Chuyển thành chuỗi vì date_post là varchar
    $stmt->bind_param("ss", $email, $time_limit);
    $stmt->execute();

    // Kiểm tra email trong user_info
    $stmt = $conn->prepare("SELECT * FROM user_info WHERE email = ? AND shop = '0'");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($result->num_rows == 0) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Email không tồn tại']);
        $stmt->close();
        $conn->close();
        exit;
    }

    // Kiểm tra OTP
    $stmt = $conn->prepare("SELECT otp, date_post FROM code_otp WHERE dien_thoai = ? ORDER BY id DESC LIMIT 1");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($row = $result->fetch_assoc()) {
        $stored_otp = $row['otp'];
        $otp_time = (int)$row['date_post']; // Ép kiểu thành số

        if ($stored_otp !== $otp || (time() - $otp_time) > 600) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'OTP không hợp lệ hoặc đã hết hạn',
                // 'debug' => ['stored_otp' => $stored_otp, 'otp_time' => $otp_time, 'current_time' => time()]
            ]);
            $stmt->close();
            $conn->close();
            exit;
        }
    } else {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Không tìm thấy OTP cho email này',
            // 'debug' => ['email' => $email]
        ]);
        $stmt->close();
        $conn->close();
        exit;
    }

    // Mã hóa và cập nhật mật khẩu
    // $hashed_password = password_hash($password, PASSWORD_DEFAULT);
    $hashed_password = md5($password);
    $stmt = $conn->prepare("UPDATE user_info SET password = ? WHERE email = ?");
    $stmt->bind_param("ss", $hashed_password, $email);
    if ($stmt->execute()) {
        // Xóa OTP đã sử dụng
        $stmt = $conn->prepare("DELETE FROM code_otp WHERE dien_thoai = ? AND otp = ?");
        $stmt->bind_param("ss", $email, $otp);
        $stmt->execute();

        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Đổi mật khẩu thành công']);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Lỗi khi cập nhật mật khẩu']);
    }

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Token không hợp lệ: ' . $e->getMessage()]);
}
?>