<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
include_once "./class.phpmailer.php";
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;
// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token
$expiration_time = 365*24*60*60*100; // Token có hiệu lực trong 100 năm (3600 giây)
// Lấy token từ header Authorization
// Lấy headers theo nhiều cách để đảm bảo lấy được hết
// Không tìm thấy Authorization
$headers=apache_request_headers();
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
    if (!empty($data->email)) {
        $email = $data->email;
        $ip_address = $_SERVER['REMOTE_ADDR'];
        if ($check->check_email($email)==false) {
            $ok = 0;
            $thongbao = 'Thất bại! Chưa nhập địa chỉ email';
            http_response_code(400);
        } else {
            $thongtin_dienthoai = mysqli_query($conn, "SELECT * FROM user_info WHERE email='$email' AND shop='0'");
            $total_dienthoai = mysqli_num_rows($thongtin_dienthoai);
            if ($total_dienthoai == 0) {
                $ok = 0;
                $thongbao = 'Thất bại! Địa chỉ email không tồn tại';
                http_response_code(404);
            } else {
                $r_dienthoai=mysqli_fetch_assoc($thongtin_dienthoai);
                $thongtin = mysqli_query($conn, "SELECT * FROM code_otp WHERE dien_thoai='$email' ORDER BY id DESC");
                $total = mysqli_num_rows($thongtin);
                $code_otp = $check->random_number(6);
                $hientai = time();
                if ($total < 1) {
                    $thongtin_ip = mysqli_query($conn, "SELECT * FROM code_otp WHERE ip_address='$ip_address'");
                    $total_ip = mysqli_num_rows($thongtin_ip);
                    if ($total_ip < 2) {
                        try {
                            $bien_otp=array(
                                'otp'=>$code_otp,
                                'name'=>$r_dienthoai['name']
                            );
                            $chu_de="Mã OTP xác nhận lấy lại mật khẩu";
                            $noi_dung=$skin->skin_replace($themes,'box_action/mail_otp',$bien_otp);
                            $kq=$check->send_email($email,'Sóc đỏ',$chu_de,$noi_dung);
                            if($kq==1){
                                $thongbao = 'Mã xác nhận đã được gửi tới địa chỉ email của bạn';
                                $ok=1;
                                http_response_code(200);
                                mysqli_query($conn, "INSERT INTO code_otp(dien_thoai,otp,ip_address,date_post)VALUES('$email','$code_otp','$ip_address','$hientai')");
                            }else{
                                $ok=0;
                                $thongbao="Gặp lỗi trong lúc gửi mail";
                                http_response_code(500);
                            }
                        } catch (Exception $e) {
                            $ok = 0;
                            $thongbao = 'Thất bại! Gặp lỗi gửi mã xác nhận';
                            http_response_code(500);
                        }
                    } else {
                        $ok = 0;
                        $thongbao = 'Thất bại! Vui lòng thử lại sau 1 phút';
                        http_response_code(429);
                    }
                } else {
                    if ($total >= 2) {
                        $ok = 0;
                        $thongbao = 'Thất bại! Bạn đã yêu cầu mã quá nhiều lần!<br>Hãy liên hệ hotline để được hỗ trợ';
                        http_response_code(429);
                    } else {
                        $r_tt = mysqli_fetch_assoc($thongtin);
                        if ((time() - $r_tt['date_post']) > 60) {
                            try {
                                $chu_de="Mã OTP xác nhận lấy lại mật khẩu";
                                $bien_otp=array(
                                    'otp'=>$code_otp,
                                    'name'=>$r_dienthoai['name']
                                );
                                $chu_de="Mã OTP xác nhận lấy lại mật khẩu";
                                $noi_dung=$skin->skin_replace($themes,'box_action/mail_otp',$bien_otp);
                                $kq=$check->send_email($email,'Sóc đỏ',$chu_de,$noi_dung);
                                if($kq==1){
                                    mysqli_query($conn, "INSERT INTO code_otp(dien_thoai,otp,ip_address,date_post)VALUES('$email','$code_otp','$ip_address','$hientai')");
                                    $ok = 1;
                                    $thongbao = 'Mã xác nhận đã được gửi tới địa chỉ email của bạn';
                                    http_response_code(200);
                                }else{
                                    $ok = 0;
                                    $thongbao="Gặp lỗi trong lúc gửi mail";
                                    http_response_code(500);
                                }
                            } catch (Exception $e) {
                                $ok = 0;
                                $thongbao = 'Thất bại! Gặp lỗi gửi mã xác nhận';
                                http_response_code(500);
                            }
                        } else {
                            $ok = 0;
                            $thongbao = 'Thất bại! Vui lòng thử lại sau 1 phút';
                            http_response_code(429);
                        }
                    }
                }
            }
        }
        $info = array(
            'ok' => $ok,
            'message' => $thongbao
        );
        echo json_encode($info);
    } else {
        // Thiếu user_id
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Vui lòng truyền email"]);
    }
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "message" => "Token không hợp lệ"
    ));
}
?>