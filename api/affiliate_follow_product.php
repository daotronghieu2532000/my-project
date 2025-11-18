<?php
header("Access-Control-Allow-Methods: POST");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$user_id = 0;

if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    $jwt = $matches[1]; // Lấy token từ Bearer
    
    try {
        // Giải mã JWT
        $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
        
        // Kiểm tra issuer
        if ($decoded->iss === $issuer) {
            $user_id = $decoded->data->user_id ?? 0;
        }
    } catch (Exception $e) {
        // JWT invalid, user_id remains 0
    }
}

// Get POST data
$input = json_decode(file_get_contents('php://input'), true);

// Ưu tiên user_id từ body, fallback từ JWT
if (isset($input['user_id'])) {
    $user_id = intval($input['user_id']);
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'POST') {
    if ($user_id <= 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "User ID is required"
        ]);
        exit;
    }

    $sp_id = isset($input['sp_id']) ? intval($input['sp_id']) : 0;
    $shop = isset($input['shop']) ? intval($input['shop']) : 0;
    $action = isset($input['action']) ? $input['action'] : ''; // 'follow' hoặc 'unfollow'
    
    if ($sp_id <= 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Product ID is required"
        ]);
        exit;
    }
    
    if (!in_array($action, ['follow', 'unfollow'])) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Action must be 'follow' or 'unfollow'"
        ]);
        exit;
    }
    
    $current_time = time();
    $checked = ($action === 'follow') ? 1 : 0;
    
    if ($checked == 1) {
        // Thêm theo dõi nếu chưa có
        $check_query = "SELECT id FROM follow_aff WHERE sp_id='$sp_id' AND user_id='$user_id'";
        $check_result = mysqli_query($conn, $check_query);
        
        if (!$check_result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Database error: " . mysqli_error($conn)
            ]);
            exit;
        }
        
        if (mysqli_num_rows($check_result) == 0) {
            // Chưa có, thêm mới
            $insert_query = "INSERT INTO follow_aff (user_id, sp_id, shop, date_post) 
                            VALUES ('$user_id', '$sp_id', '$shop', '$current_time')";
            
            if (!mysqli_query($conn, $insert_query)) {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Failed to follow product: " . mysqli_error($conn)
                ]);
                exit;
            }
            
            $message = "Đã theo dõi sản phẩm thành công";
        } else {
            // Đã có rồi, cập nhật thời gian
            $update_query = "UPDATE follow_aff SET date_post='$current_time' WHERE sp_id='$sp_id' AND user_id='$user_id'";
            
            if (!mysqli_query($conn, $update_query)) {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Failed to update follow: " . mysqli_error($conn)
                ]);
                exit;
            }
            
            $message = "Đã cập nhật theo dõi sản phẩm";
        }
    } else {
        // Bỏ theo dõi
        $delete_query = "DELETE FROM follow_aff WHERE sp_id='$sp_id' AND user_id='$user_id'";
        
        if (!mysqli_query($conn, $delete_query)) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Failed to unfollow product: " . mysqli_error($conn)
            ]);
            exit;
        }
        
        $message = "Đã bỏ theo dõi sản phẩm thành công";
    }
    
    // Đếm lại tổng số sản phẩm đang theo dõi
    $count_query = "SELECT COUNT(*) as total FROM follow_aff WHERE user_id='$user_id'";
    $count_result = mysqli_query($conn, $count_query);
    $total_following = 0;
    if ($count_result) {
        $count_row = mysqli_fetch_assoc($count_result);
        $total_following = $count_row['total'];
    }
    
    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => $message,
        "data" => [
            "sp_id" => $sp_id,
            "shop_id" => $shop,
            "action" => $action,
            "is_following" => ($action === 'follow'),
            "total_following" => $total_following,
            "followed_at" => ($action === 'follow') ? date('Y-m-d H:i:s', $current_time) : null
        ]
    ], JSON_UNESCAPED_UNICODE);
    
} else {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Chỉ hỗ trợ phương thức POST"
    ]);
}
?>
