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
// print_r($headers);
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
    if (!empty($data->phone_number) && !empty($data->password)) {
        $phone_number = addslashes(strip_tags($data->phone_number));
        $password = addslashes(strip_tags($data->password));
        $re_password = isset($data->re_password) ? addslashes(strip_tags($data->re_password)) : '';
        $full_name = isset($data->full_name) ? addslashes(strip_tags($data->full_name)) : '';
        $dien_thoai = $phone_number;

        // Kiểm tra dữ liệu đầu vào
        function is_strong_password($password) {
            if (strlen($password) < 8) return false;
            if (!preg_match('/[A-Z]/', $password)) return false;
            if (!preg_match('/[a-z]/', $password)) return false;
            if (!preg_match('/[0-9]/', $password)) return false;
            if (!preg_match('/[!@#$%^&*()_+\-=\[\]{};\':"\\|,.<>\/?]/', $password)) return false;
            return true;
        }

        if (strlen($full_name) < 2) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Vui lòng nhập họ và tên']);
        } else if (strlen($dien_thoai) < 10) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Vui lòng nhập số điện thoại']);
        } else if (!is_numeric($dien_thoai)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Số điện thoại chỉ được chứa ký tự số']);
        } else if ($dien_thoai[0] !== '0') {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Số điện thoại phải bắt đầu bằng số 0!']);
        } else if (strlen($dien_thoai) !== 10) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Số điện thoại chỉ được chứa 10 ký số']);
        } else if (!is_strong_password($password)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt']);
        } else if ($password != $re_password) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Nhập lại mật khẩu không khớp']);
        } else {
            // Kiểm tra số điện thoại đã tồn tại
            $stmt = $conn->prepare("SELECT COUNT(*) AS total FROM user_info WHERE mobile = ? AND shop = '0'");
            $stmt->bind_param("s", $dien_thoai);
            $stmt->execute();
            $result = $stmt->get_result();
            $row = $result->fetch_assoc();
            $stmt->close();

            if ($row['total'] > 0) {
                http_response_code(409);
                echo json_encode(['success' => false, 'message' => 'Số điện thoại đã tồn tại trên hệ thống']);
            } else {
                // echo json_encode(['success' => true, 'message' => 'Đăng ký tài khoản thành công']);
                $pass = md5($password);
                $hientai = time();
                $ip_address = $_SERVER['REMOTE_ADDR'];
                $success=mysqli_query($conn, "INSERT INTO user_info(username,shop,user_money,user_money2,email,password,name,avatar,mobile,domain,ngaysinh,gioi_tinh,cmnd,ngaycap,noicap,tinh,huyen,xa,dia_chi,maso_thue,maso_thue_cap,maso_thue_noicap,dropship,ctv,leader,leader_start,code_active,active,nhan_vien,chinh_thuc,created,date_update,ip_address,logined,end_online,aff,doitac,about,nhom,gia_leader)VALUES('$dien_thoai','0','0','0','$email','$pass','$full_name','','$dien_thoai','$domain','$ngaysinh','','$cmnd','$ngaycap','$noicap','0','0','0','$dia_chi','$maso_thue','$maso_thue_cap','$maso_thue_noicap','0','0','0','','','1','0','0','$hientai','$hientai','$ip_address','','','$aff','$doitac','','$nhom','0')");
                
                $info_user = array(
                    'full_name' => $full_name,
                    // 'user_name' => $dien_thoai,
                    'phone_number' => $dien_thoai,
                    'password' => $password,   
                    // 'created' => $hientai,
                    // 'ip_address' => $ip_address
                );
                // Close the statement
                // $stmt->close();
                if ($success) {
                    http_response_code(201);
                    echo json_encode(['success' => true, 'message' => 'Đăng ký tài khoản thành công', 'data' => $info_user]);
                } else {
                    http_response_code(500);
                    echo json_encode(['success' => false, 'message' => 'Có lỗi xảy ra, vui lòng thử lại!']);
                }
            }
        }
    } else {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng nhập đầy đủ thông tin đăng ký"]);
    }
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "message" => "Token không hợp lệ",
        "error" => $e->getMessage()
    ));
}
?>






