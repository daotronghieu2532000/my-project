<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;
// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token
$expiration_time = 365*24*60*60*100; // Token có hiệu lực trong 100 năm (3600 giây)
// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(array("message" => "Không tìm thấy token"));
    exit;
}
$jwt = $matches[1]; // Lấy token từ Bearer
try {
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    // Kiểm tra issuer
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(array("message" => "Token không hợp lệ"));
        exit;
    }
    $data = json_decode(file_get_contents("php://input"));
    // Kiểm tra xem đã nhập đủ email và mật khẩu chưa
    if (!empty($data->user_id)) {
        $user_id = $data->user_id;
        // Kiểm tra tài khoản trong user_info
        // Lấy tất cả các cột trừ cột password
        $stmt = $conn->prepare("SELECT " . implode(',', array_filter(array_map(function($col) { return $col != 'password' ? $col : null; }, array_column($conn->query("SHOW COLUMNS FROM user_info")->fetch_all(MYSQLI_ASSOC), 'Field')))) . " FROM user_info WHERE user_id = ? LIMIT 1");
        $stmt->bind_param("s", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        // Nếu tìm thấy người dùng
        if ($result->num_rows > 0) {
            $user = $result->fetch_assoc();
            $stmt->close();
            http_response_code(200);
            echo json_encode([
                'success' => true,
                "message" => "Lấy thông tin thành công",
                "data" => $user
            ]);
        } else {
            // Không tìm thấy người dùng
            http_response_code(404);
            echo json_encode(["success" => false, "message" => "Không tìm thấy người dùng với user_id này"]);
        }
    } else {
        // Thiếu user_id
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng truyền user_id"]);
    }
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "message" => "Token không hợp lệ"
    ));
}
?>