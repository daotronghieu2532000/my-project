<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: POST');

// Tải thư viện JWT
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

// Kiểm tra và load file config.php
$config_path = __DIR__ . '../../../../../../../../../config.php'; // Điều chỉnh nếu cần
if (!file_exists($config_path)) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Không tìm thấy file config.php tại ' . $config_path
    ]);
    exit;
}
require_once $config_path;

// Kiểm tra kết nối cơ sở dữ liệu
if (mysqli_connect_errno()) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Lỗi kết nối cơ sở dữ liệu: ' . mysqli_connect_error()
    ]);
    exit;
}

// Chỉ cho phép phương thức POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Phương thức không được phép! Vui lòng sử dụng POST.'
    ]);
    exit;
}

// Lấy token từ header Authorization
$headers = getallheaders();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Không tìm thấy token'
    ]);
    exit;
}

$jwt = $matches[1];

try {
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    error_log("JWT decoded: " . print_r($decoded, true));

    // Kiểm tra issuer
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Issuer không hợp lệ'
        ]);
        exit;
    }

    // Lấy dữ liệu JSON từ body
    $rawData = file_get_contents('php://input');
    error_log("Raw input: " . $rawData);
    $data = json_decode($rawData, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Dữ liệu JSON không hợp lệ: ' . json_last_error_msg()
        ]);
        exit;
    }

    $email = isset($data['email']) ? addslashes(strip_tags($data['email'])) : '';
    $ip_address = $_SERVER['REMOTE_ADDR'];
    error_log("Email: $email, IP: $ip_address");

    // Kiểm tra email hợp lệ
    if (empty($email) || !$check->check_email($email)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Thất bại! Chưa nhập hoặc email không hợp lệ'
        ]);
        exit;
    }

    // Kiểm tra email tồn tại trong bảng user_info
    $stmt = $conn->prepare("SELECT * FROM user_info WHERE email = ? AND shop = '0'");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $thongtin_dienthoai = $stmt->get_result();
    $total_dienthoai = $thongtin_dienthoai->num_rows;

    if ($total_dienthoai == 0) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Thất bại! Địa chỉ email không tồn tại'
        ]);
        $stmt->close();
        exit;
    }

    // Lấy thông tin người dùng
    $r_dienthoai = $thongtin_dienthoai->fetch_assoc();
    $stmt->close();
    error_log("User info: " . print_r($r_dienthoai, true));

    // Kiểm tra số lượng yêu cầu OTP
    $stmt = $conn->prepare("SELECT * FROM code_otp WHERE dien_thoai = ? ORDER BY id DESC");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $thongtin = $stmt->get_result();
    $total = $thongtin->num_rows;
    $code_otp = $check->random_number(6);
    $hientai = time();
    error_log("OTP: $code_otp, Total requests: $total");

    // Xử lý logic OTP
    if ($total < 1) {
        // Kiểm tra giới hạn IP
        $stmt_ip = $conn->prepare("SELECT * FROM code_otp WHERE ip_address = ?");
        $stmt_ip->bind_param("s", $ip_address);
        $stmt_ip->execute();
        $thongtin_ip = $stmt_ip->get_result();
        $total_ip = $thongtin_ip->num_rows;
        $stmt_ip->close();

        if ($total_ip >= 2) {
            http_response_code(429);
            echo json_encode([
                'success' => false,
                'message' => 'Thất bại! Vui lòng thử lại sau 1 phút'
            ]);
            exit;
        }

        // Gửi email OTP
        try {
            $bien_otp = [
                'otp' => $code_otp,
                'name' => $r_dienthoai['name']
            ];
            $chu_de = "Mã OTP xác nhận lấy lại mật khẩu";
            $noi_dung = $skin->skin_replace('skin/mail_otp', $bien_otp);
            error_log("Nội dung email: $noi_dung");
            $kq = $check->send_email($email, 'Sóc đỏ', $chu_de, $noi_dung);
            error_log("Kết quả gửi email: $kq");

            if ($kq == 1) {
                // Lưu mã OTP vào cơ sở dữ liệu
                $stmt_insert = $conn->prepare("INSERT INTO code_otp (dien_thoai, otp, ip_address, date_post) VALUES (?, ?, ?, ?)");
                $stmt_insert->bind_param("sssi", $email, $code_otp, $ip_address, $hientai);
                if ($stmt_insert->execute()) {
                    http_response_code(200);
                    echo json_encode([
                        'success' => true,
                        'message' => 'Mã xác nhận đã được gửi tới địa chỉ email của bạn',
                        'data' => [
                            'email' => $email
                        ]
                    ]);
                } else {
                    error_log("Lỗi lưu OTP: " . $stmt_insert->error);
                    http_response_code(500);
                    echo json_encode([
                        'success' => false,
                        'message' => 'Lỗi lưu mã OTP vào cơ sở dữ liệu'
                    ]);
                }
                $stmt_insert->close();
            } else {
                http_response_code(500);
                echo json_encode([
                    'success' => false,
                    'message' => 'Gặp lỗi trong lúc gửi mail'
                ]);
            }
        } catch (Exception $e) {
            error_log("Lỗi gửi email: " . $e->getMessage());
            http_response_code(500);
            echo json_encode([
                'success' => false,
                'message' => 'Thất bại! Gặp lỗi gửi mã xác nhận'
            ]);
        }
    } else {
        if ($total >= 2) {
            http_response_code(429);
            echo json_encode([
                'success' => false,
                'message' => 'Thất bại! Bạn đã yêu cầu mã quá nhiều lần! Hãy liên hệ hotline để được hỗ trợ'
            ]);
            exit;
        }

        $r_tt = $thongtin->fetch_assoc();
        $stmt->close();
        if ((time() - $r_tt['date_post']) <= 60) {
            http_response_code(429);
            echo json_encode([
                'success' => false,
                'message' => 'Thất bại! Vui lòng thử lại sau 1 phút'
            ]);
            exit;
        }

        // Gửi email OTP mới
        try {
            $bien_otp = [
                'otp' => $code_otp,
                'name' => $r_dienthoai['name']
            ];
            $chu_de = "Mã OTP xác nhận lấy lại mật khẩu";
            $noi_dung = $skin->skin_replace('skin/mail_otp', $bien_otp);
            error_log("Nội dung email: $noi_dung");
            $kq = $check->send_email($email, 'Sóc đỏ', $chu_de, $noi_dung);
            error_log("Kết quả gửi email: $kq");

            if ($kq == 1) {
                // Lưu mã OTP vào cơ sở dữ liệu
                $stmt_insert = $conn->prepare("INSERT INTO code_otp (dien_thoai, otp, ip_address, date_post) VALUES (?, ?, ?, ?)");
                $stmt_insert->bind_param("sssi", $email, $code_otp, $ip_address, $hientai);
                if ($stmt_insert->execute()) {
                    http_response_code(200);
                    echo json_encode([
                        'success' => true,
                        'message' => 'Mã xác nhận đã được gửi tới địa chỉ email của bạn',
                        'data' => [
                            'email' => $email
                        ]
                    ]);
                } else {
                    error_log("Lỗi lưu OTP: " . $stmt_insert->error);
                    http_response_code(500);
                    echo json_encode([
                        'success' => false,
                        'message' => 'Lỗi lưu mã OTP vào cơ sở dữ liệu'
                    ]);
                }
                $stmt_insert->close();
            } else {
                http_response_code(500);
                echo json_encode([
                    'success' => false,
                    'message' => 'Gặp lỗi trong lúc gửi mail'
                ]);
            }
        } catch (Exception $e) {
            error_log("Lỗi gửi email: " . $e->getMessage());
            http_response_code(500);
            echo json_encode([
                'success' => false,
                'message' => 'Thất bại! Gặp lỗi gửi mã xác nhận'
            ]);
        }
    }

} catch (Exception $e) {
    error_log("Lỗi JWT: " . $e->getMessage());
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Token không hợp lệ'
    ]);
}
?>