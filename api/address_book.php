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
    $dataRaw = file_get_contents("php://input");
    $data = json_decode($dataRaw);
    // Debug log toàn bộ input
    file_put_contents('/home/api.socdo.vn/public_html/home/themes/socdo/action/process/debug_address.log', date('Y-m-d H:i:s') . ' - INPUT: ' . $dataRaw . "\n", FILE_APPEND);
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

    // Thêm hoặc sửa địa chỉ
    if (isset($data->ho_ten) && isset($data->dia_chi)) {
        // Validate đầu vào đơn giản
        $ho_ten = addslashes($data->ho_ten ?? '');
        $dien_thoai = addslashes($data->dien_thoai ?? '');
        $dia_chi = addslashes($data->dia_chi ?? '');
        $email = addslashes($data->email ?? '');
        $xa = (string)($data->xa ?? '0');
        $huyen = (string)($data->huyen ?? '0');
        $tinh = (string)($data->tinh ?? '0');
        $ten_xa = addslashes($data->ten_xa ?? '');
        $ten_huyen = addslashes($data->ten_huyen ?? '');
        $ten_tinh = addslashes($data->ten_tinh ?? '');
        $active = strval($data->active ?? 0);
        $id = isset($data->id) ? intval($data->id) : 0;
        
        // Debug giá trị biến trước khi thêm/sửa
        $debugVars = json_encode([
            'id' => $id,
            'user_id' => $user_id,
            'ho_ten' => $ho_ten,
            'dien_thoai' => $dien_thoai,
            'dia_chi' => $dia_chi,
            'email' => $email,
            'xa' => $xa,
            'huyen' => $huyen,
            'tinh' => $tinh,
            'ten_xa' => $ten_xa,
            'ten_huyen' => $ten_huyen,
            'ten_tinh' => $ten_tinh,
            'active' => $active
        ], JSON_UNESCAPED_UNICODE);
        file_put_contents(__DIR__ . '/debug_address.log', date('Y-m-d H:i:s') . ' - VARS: ' . $debugVars . "\n", FILE_APPEND);

        if ($id > 0) {
            // Sửa địa chỉ
            $stmt = $conn->prepare("UPDATE dia_chi SET ho_ten=?, dien_thoai=?, dia_chi=?, email=?, xa=?, huyen=?, tinh=?, ten_xa=?, ten_huyen=?, ten_tinh=?, active=? WHERE id=? AND user_id=?");
            $stmt->bind_param("sssssssssssii", $ho_ten, $dien_thoai, $dia_chi, $email, $xa, $huyen, $tinh, $ten_xa, $ten_huyen, $ten_tinh, $active, $id, $user_id);
            $ok = $stmt->execute();
            $debugResult = json_encode(['update_ok'=>$ok, 'stmt_error'=>$stmt->error, 'params'=>[$ho_ten, $dien_thoai, $dia_chi, $email, $xa, $huyen, $tinh, $ten_xa, $ten_huyen, $ten_tinh, $active, $id, $user_id]], JSON_UNESCAPED_UNICODE);
            file_put_contents(__DIR__ . '/debug_address.log', date('Y-m-d H:i:s') . ' - UPDATE: ' . $debugResult . "\n", FILE_APPEND);
            if ($ok) {
                http_response_code(200);
                echo json_encode(["success"=>true, "message"=>"Sửa địa chỉ thành công", "id"=>$id]);
                $stmt->close();
                $conn->close();
                exit;
            } else {
                http_response_code(500);
                echo json_encode(["success"=>false, "message"=>"Lỗi sửa địa chỉ", "error"=>$stmt->error]);
                $stmt->close();
                $conn->close();
                exit;
            }
        } else {
            // Thêm địa chỉ mới
            $stmt = $conn->prepare("INSERT INTO dia_chi (user_id, ho_ten, dien_thoai, dia_chi, email, xa, huyen, tinh, ten_xa, ten_huyen, ten_tinh, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->bind_param("isssssssssss", $user_id, $ho_ten, $dien_thoai, $dia_chi, $email, $xa, $huyen, $tinh, $ten_xa, $ten_huyen, $ten_tinh, $active);
            $ok = $stmt->execute();
            $debugResult = json_encode(['insert_ok'=>$ok, 'stmt_error'=>$stmt->error, 'params'=>[$user_id, $ho_ten, $dien_thoai, $dia_chi, $email, $xa, $huyen, $tinh, $ten_xa, $ten_huyen, $ten_tinh, $active]], JSON_UNESCAPED_UNICODE);
            file_put_contents(__DIR__ . '/debug_address.log', date('Y-m-d H:i:s') . ' - INSERT: ' . $debugResult . "\n", FILE_APPEND);
            if ($ok) {
                $new_id = $stmt->insert_id > 0 ? $stmt->insert_id : $conn->insert_id;
                http_response_code(200);
                echo json_encode(["success"=>true, "message"=>"Thêm địa chỉ thành công", "id"=>$new_id]);
                $stmt->close();
                $conn->close();
                exit;
            } else {
                http_response_code(500);
                echo json_encode(["success"=>false, "message"=>"Lỗi thêm địa chỉ", "error"=>$stmt->error]);
                $stmt->close();
                $conn->close();
                exit;
            }
        }
    }

    // Truy vấn danh sách địa chỉ
    $stmt = $conn->prepare("SELECT id, user_id, ho_ten, dien_thoai, dia_chi, email, xa, huyen, tinh, ten_tinh, ten_huyen, ten_xa, active FROM dia_chi WHERE user_id = ?");
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