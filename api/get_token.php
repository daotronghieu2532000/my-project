<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token
$expiration_time = 365*24*60*60*100; // Token có hiệu lực trong 100 năm (3600 giây)
// Lấy dữ liệu gửi lên từ client (POST dạng JSON)
$data = json_decode(file_get_contents("php://input"));
// Kiểm tra xem đã nhập đủ api_key và api_secret chưa
if (!empty($data->api_key) && !empty($data->api_secret)) {
    $api_key = $data->api_key;
    $api_secret = $data->api_secret;
    // Kiểm tra tài khoản trong app_api
    $stmt = $conn->prepare("SELECT * FROM app_api WHERE api_key = ? AND api_secret = ? LIMIT 1");
    $stmt->bind_param("ss", $api_key, $api_secret);
    $stmt->execute();
    $result = $stmt->get_result();

    // Nếu tìm thấy thông tin api_key và api_secret
    if ($result->num_rows > 0) {
        $r_tt = $result->fetch_assoc();
        $stmt->close();
        // Tạo dữ liệu cho JWT
        $payload = [
            "iss" => $issuer, // ai phát hành
            "iat" => time(), // thời điểm phát hành
            "exp" => time() + $expiration_time, // thời điểm hết hạn
            "api_key" => $api_key, // api_key người dùng
            "api_secret" => $api_secret // api_secret người dùng
        ];
        // Sinh ra token JWT
        $jwt = JWT::encode($payload, $key, 'HS256');
        // Trả về kết quả lấy token thành công và token
        http_response_code(200);
        echo json_encode([
            'success' => true,
            "message" => "Lấy token thành công",
            "token" => $jwt
        ]);
    } else {
        // Không tìm thấy thông tin api_key và api_secret
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Thông tin api_key và api_secret không hợp lệ"]);
    }
} else {
    // Thiếu api_key hoặc api_secret
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Vui lòng nhập đầy đủ api_key và api_secret"]);
}
?>