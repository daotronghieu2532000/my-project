<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;
// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token
$expiration_time = 3600; // Token có hiệu lực trong 1 giờ (3600 giây)
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
        echo json_encode(array("message" => "Issuer không hợp lệ"));
        exit;
    }
    // Kiểm tra thời gian hết hạn (exp) tự động được xử lý bởi JWT::decode
    // Nếu token hợp lệ, trả về thông tin người dùng
    // http_response_code(200);
    // echo json_encode(array(
    //     "message" => "Token hợp lệ",
    //     "api_key" => $decoded->api_key,
    //     "api_secret" => $decoded->api_secret,
    //     "data" => (array)$decoded
    // ));
    // exit();
    // Lấy dữ liệu gửi lên từ client (POST dạng JSON)
    $data = json_decode(file_get_contents("php://input"));
    // Kiểm tra xem đã nhập đủ email và mật khẩu chưa
    
    // logic sổ địa chỉ ở đây
    if (empty($data->user_id)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng cung cấp user_id"]);
        exit;
    }

    // Kiểm tra user_id có hợp lệ (giả sử user_id là số nguyên)
    $user_id = filter_var($data->user_id, FILTER_VALIDATE_INT);
    if ($user_id === false) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "user_id không hợp lệ"]);
        exit;
    }

    // Truy vấn danh sách địa chỉ từ bảng dia_chi
    $stmt = $conn->prepare("SELECT * FROM yeu_thich_san_pham WHERE user_id = ?");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $addresses = [];
    while ($row = $result->fetch_assoc()) {
        $addresses[] = $row;
    }

    if (!empty($addresses)) {
        http_response_code(200);
        echo json_encode(["success" => true, "data" => $addresses]);
    } else {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Không tìm thấy địa chỉ nào cho user_id này"]);
    }

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "message" => "Token không hợp lệ"
    ));
}
?>