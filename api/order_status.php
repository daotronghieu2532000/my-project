
<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình JWT
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(["message" => "Không tìm thấy token"]);
    exit;
}
$jwt = $matches[1];

try {
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));

    // Kiểm tra issuer
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(["message" => "Issuer không hợp lệ"]);
        exit;
    }

    // Lấy dữ liệu từ client
    $data = json_decode(file_get_contents("php://input"));

    if (empty($data->user_id)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng cung cấp user_id"]);
        exit;
    }

    $user_id = filter_var($data->user_id, FILTER_VALIDATE_INT);
    if ($user_id === false) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "user_id không hợp lệ"]);
        exit;
    }

    // ===== Query linh hoạt =====
    if (isset($data->status) && $data->status !== '') {
        // Có status → lọc theo user_id + status
        $status = filter_var($data->status, FILTER_VALIDATE_INT);
        if ($status === false) {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "status không hợp lệ"]);
            exit;
        }

    $stmt = $conn->prepare("SELECT user_id, ho_ten, dien_thoai,email, ma_don, status, sanpham ,dia_chi,tinh,huyen,xa ,tamtinh, phi_ship,tongtien,kho,status,thanhtoan,ghi_chu,date_update,date_post,shop_id,ship_support FROM donhang WHERE user_id = ? AND status = ?");
    $stmt->bind_param("ii", $user_id, $data->status);

    } else {
        // Không có status → chỉ lọc theo user_id
    $stmt = $conn->prepare("SELECT user_id, ho_ten, dien_thoai,email, ma_don, status, sanpham ,dia_chi,tinh,huyen,xa ,tamtinh, phi_ship,tongtien,kho,status,thanhtoan,ghi_chu,date_update,date_post,shop_id,ship_support FROM donhang WHERE user_id = ?");
    $stmt->bind_param("i", $user_id);
    }

    // Thực thi query
    $stmt->execute();
    $result = $stmt->get_result();

    $orders = [];
    while ($row = $result->fetch_assoc()) {
        $orders[] = $row;
    }

    if (!empty($orders)) {
        http_response_code(200);
        echo json_encode(["success" => true, "data" => $orders]);
    } else {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Không tìm thấy đơn hàng"]);
    }

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(["message" => "Token không hợp lệ"]);
}
?>
