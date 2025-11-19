<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;
// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token
$expiration_time = 365*24*60*60*100; // Token có hiệu lực trong 1 giờ (3600 giây)
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
    if (!empty($data->username) && !empty($data->password)) {
        $username = $data->username;
        $password = $data->password;
        $password=md5($password);
        // Kiểm tra tài khoản trong user_info
        $stmt = $conn->prepare("SELECT * FROM user_info WHERE (email = ? OR username = ? OR mobile = ?) AND shop = 0 LIMIT 1");
        $stmt->bind_param("sss", $username, $username, $username);
        $stmt->execute();
        $result = $stmt->get_result();
        // Nếu tìm thấy người dùng
        if ($result->num_rows > 0) {
            $user = $result->fetch_assoc();
            $stmt->close();
            // Kiểm tra mật khẩu nhập vào có đúng không
            if ($password==$user['password']) {
                // Tạo dữ liệu cho JWT
                // $payload = [
                //     "iss" => $issuer, // ai phát hành
                //     "iat" => time(), // thời điểm phát hành
                //     "exp" => time() + $expiration_time, // thời điểm hết hạn
                //     "api_key" => $api_key, // id người dùng
                //     "api_secret" => $api_secret // email người dùng
                // ];
                // Sinh ra token JWT
                //$jwt = JWT::encode($payload, $key, 'HS256');
                // Trả về kết quả đăng nhập thành công và token
                $info_return=array(
                    'user_id' => $user['user_id'],
                    'name' => $user['name'],
                    'username' => $user['username'],
                    'email' => $user['email'],
                    'mobile' => $user['mobile'],
                    'avatar'=>$user['avatar'],
                    'user_money'=>$user['user_money'],
                    'user_money2'=>$user['user_money2'],
                    'ctv'=>$user['ctv'],
                );
                http_response_code(200);
                echo json_encode([
                    'success' => true,
                    "message" => "Đăng nhập thành công",
                    "data" => $info_return
                ]);
            } else {
                // Sai mật khẩu
                http_response_code(401);
                echo json_encode(["success" => false, "message" => "Mật khẩu không đúng"]);
            }
        } else {
            // Không tìm thấy người dùng
            http_response_code(404);
            echo json_encode(["success" => false, "message" => "Không tìm thấy người dùng với username này"]);
        }
    } else {
        // Thiếu email hoặc mật khẩu
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng nhập đầy đủ username và mật khẩu"]);
    }
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "message" => "Token không hợp lệ"
    ));
}
?>