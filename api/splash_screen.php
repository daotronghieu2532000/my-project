<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Kết nối database
$config_path = __DIR__ . '/config.php';
if (file_exists($config_path)) {
    require_once $config_path;
} else {
    // Fallback: kết nối trực tiếp nếu không có config.php
    $conn = mysqli_connect('localhost', 'socdo', 'Xdnt.qOPNz8!(cQi', 'socdo');
    if (!$conn) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Database connection error: " . mysqli_connect_error()
        ]);
        exit;
    }
    mysqli_set_charset($conn, "utf8mb4");
}

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

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
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        $current_time = time();
        $current_datetime = date('Y-m-d H:i:s');
        
        // Lấy splash screen đang active và trong thời gian hiển thị
        // Logic: 
        // - is_active = 1
        // - (start_at IS NULL OR start_at <= NOW())
        // - (end_at IS NULL OR end_at >= NOW())
        // - Sắp xếp theo priority DESC, id DESC (ưu tiên cao nhất)
        $query = "SELECT * FROM splash_screens 
                  WHERE is_active = 1 
                  AND (start_at IS NULL OR start_at <= '$current_datetime')
                  AND (end_at IS NULL OR end_at >= '$current_datetime')
                  ORDER BY priority DESC, id DESC 
                  LIMIT 1";
        
        $result = mysqli_query($conn, $query);
        
        if (!$result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database"
            ]);
            exit;
        }
        
        $splash_data = null;
        
        if (mysqli_num_rows($result) > 0) {
            $row = mysqli_fetch_assoc($result);
            
            // Format dữ liệu splash screen
            $splash_data = array();
            $splash_data['id'] = intval($row['id']);
            $splash_data['title'] = $row['title'];
            
            // Xử lý URL ảnh - thêm domain nếu là đường dẫn tương đối
            if (!empty($row['image_url'])) {
                if (strpos($row['image_url'], 'http://') === 0 || strpos($row['image_url'], 'https://') === 0) {
                    // URL tuyệt đối
                    $splash_data['image_url'] = $row['image_url'];
                } else {
                    // URL tương đối - thêm domain
                    $splash_data['image_url'] = 'https://socdo.vn' . (substr($row['image_url'], 0, 1) === '/' ? '' : '/') . $row['image_url'];
                }
            } else {
                $splash_data['image_url'] = '';
            }
            
            $splash_data['priority'] = intval($row['priority']);
            $splash_data['start_at'] = $row['start_at'] ? strtotime($row['start_at']) : null;
            $splash_data['end_at'] = $row['end_at'] ? strtotime($row['end_at']) : null;
            $splash_data['created_at'] = strtotime($row['created_at']);
            $splash_data['updated_at'] = strtotime($row['updated_at']);
        }
        
        $response = [
            "success" => true,
            "message" => "Lấy splash screen thành công",
            "data" => $splash_data // null nếu không có splash screen nào active
        ];
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
    } else {
        http_response_code(405);
        echo json_encode([
            "success" => false,
            "message" => "Chỉ hỗ trợ phương thức GET"
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "success" => false,
        "message" => "Token không hợp lệ",
        "error" => $e->getMessage()
    ));
}
?>

