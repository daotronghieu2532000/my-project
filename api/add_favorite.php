<?php
header("Access-Control-Allow-Methods: POST, DELETE, PUT");
require_once './vendor/autoload.php';
// Include user_behavior_helper để lưu hành vi người dùng
$helper_path = __DIR__ . '/user_behavior_helper.php';
if (file_exists($helper_path)) {
    require_once $helper_path;
}
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

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
    
    if ($method === 'POST') {
        // Thêm sản phẩm vào danh sách yêu thích
        $data = json_decode(file_get_contents("php://input"), true);
        
        // Validate required fields
        if (!isset($data['user_id']) || !isset($data['product_id'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu user_id hoặc product_id"
            ]);
            exit;
        }
        
        $user_id = intval($data['user_id']);
        $product_id = intval($data['product_id']);
        
        if ($user_id <= 0 || $product_id <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "user_id và product_id phải lớn hơn 0"
            ]);
            exit;
        }
        
        // Kiểm tra sản phẩm có tồn tại không
        $product_check = mysqli_query($conn, "SELECT id, tieu_de, shop, thuong_hieu FROM sanpham WHERE id = $product_id LIMIT 1");
        if (!$product_check || mysqli_num_rows($product_check) == 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Không tìm thấy sản phẩm"
            ]);
            exit;
        }
        
        $product_info = mysqli_fetch_assoc($product_check);
        
        // Kiểm tra đã yêu thích chưa
        $favorite_check = mysqli_query($conn, "SELECT id FROM yeu_thich_san_pham WHERE user_id = '$user_id' AND product_id = '$product_id' LIMIT 1");
        if (mysqli_num_rows($favorite_check) > 0) {
            http_response_code(409);
            echo json_encode([
                "success" => false,
                "message" => "Sản phẩm đã có trong danh sách yêu thích"
            ]);
            exit;
        }
        
        // Thêm vào danh sách yêu thích
        $insert_query = "INSERT INTO yeu_thich_san_pham (user_id, product_id) VALUES ('$user_id', '$product_id')";
        $result = mysqli_query($conn, $insert_query);
        
        if ($result) {
            $favorite_id = mysqli_insert_id($conn);
            
            http_response_code(201);
            echo json_encode([
                "success" => true,
                "message" => "Thêm sản phẩm vào danh sách yêu thích thành công",
                "data" => [
                    "favorite_id" => $favorite_id,
                    "user_id" => $user_id,
                    "product_id" => $product_id,
                    "product_name" => $product_info['tieu_de'],
                    "shop_id" => $product_info['shop'],
                    "is_authentic" => !empty($product_info['thuong_hieu']) ? 1 : 0
                ]
            ]);
            
            // Lưu hành vi yêu thích (chạy sau khi response đã được gửi, không ảnh hưởng API)
            if (function_exists('saveUserBehavior') && $user_id > 0 && $product_id > 0) {
                try {
                    // Lấy category_id từ sản phẩm
                    $category_id = null;
                    $cat_query = "SELECT cat FROM sanpham WHERE id = $product_id LIMIT 1";
                    $cat_result = mysqli_query($conn, $cat_query);
                    if ($cat_result && mysqli_num_rows($cat_result) > 0) {
                        $cat_row = mysqli_fetch_assoc($cat_result);
                        if (!empty($cat_row['cat'])) {
                            $cat_array = explode(',', $cat_row['cat']);
                            if (!empty($cat_array)) {
                                $category_id = intval(trim($cat_array[0]));
                            }
                        }
                    }
                    
                    saveUserBehavior($conn, $user_id, 'favorite', $product_id, null, $category_id, [
                        'product_title' => $product_info['tieu_de'],
                        'product_price' => 0, // Có thể lấy từ product_info nếu cần
                        'shop_id' => $product_info['shop']
                    ]);
                } catch (Exception $e) {
                    error_log("Error saving favorite behavior: " . $e->getMessage());
                }
            }
        } else {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi thêm sản phẩm yêu thích: " . mysqli_error($conn)
            ]);
        }
        
    } elseif ($method === 'DELETE') {
        // Xóa sản phẩm khỏi danh sách yêu thích
        $data = json_decode(file_get_contents("php://input"), true);
        
        // Validate required fields
        if (!isset($data['user_id']) || !isset($data['product_id'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu user_id hoặc product_id"
            ]);
            exit;
        }
        
        $user_id = intval($data['user_id']);
        $product_id = intval($data['product_id']);
        
        if ($user_id <= 0 || $product_id <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "user_id và product_id phải lớn hơn 0"
            ]);
            exit;
        }
        
        // Kiểm tra có trong danh sách yêu thích không
        $favorite_check = mysqli_query($conn, "SELECT id FROM yeu_thich_san_pham WHERE user_id = '$user_id' AND product_id = '$product_id' LIMIT 1");
        if (mysqli_num_rows($favorite_check) == 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Sản phẩm không có trong danh sách yêu thích"
            ]);
            exit;
        }
        
        // Xóa khỏi danh sách yêu thích
        $delete_query = "DELETE FROM yeu_thich_san_pham WHERE user_id = '$user_id' AND product_id = '$product_id'";
        $result = mysqli_query($conn, $delete_query);
        
        if ($result) {
            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => "Xóa sản phẩm khỏi danh sách yêu thích thành công",
                "data" => [
                    "user_id" => $user_id,
                    "product_id" => $product_id,
                    "action" => "removed"
                ]
            ]);
        } else {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi xóa sản phẩm yêu thích: " . mysqli_error($conn)
            ]);
        }
        
    } elseif ($method === 'PUT') {
        // Toggle favorite (thích/bỏ thích)
        $data = json_decode(file_get_contents("php://input"), true);
        
        // Validate required fields
        if (!isset($data['user_id']) || !isset($data['product_id'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu user_id hoặc product_id"
            ]);
            exit;
        }
        
        $user_id = intval($data['user_id']);
        $product_id = intval($data['product_id']);
        
        if ($user_id <= 0 || $product_id <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "user_id và product_id phải lớn hơn 0"
            ]);
            exit;
        }
        
        // Kiểm tra sản phẩm có tồn tại không
        $product_check = mysqli_query($conn, "SELECT id, tieu_de, shop, thuong_hieu FROM sanpham WHERE id = $product_id LIMIT 1");
        if (!$product_check || mysqli_num_rows($product_check) == 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Không tìm thấy sản phẩm"
            ]);
            exit;
        }
        
        $product_info = mysqli_fetch_assoc($product_check);
        
        // Kiểm tra đã yêu thích chưa
        $favorite_check = mysqli_query($conn, "SELECT id FROM yeu_thich_san_pham WHERE user_id = '$user_id' AND product_id = '$product_id' LIMIT 1");
        $is_favorite = mysqli_num_rows($favorite_check) > 0;
        
        if ($is_favorite) {
            // Đã thích -> Bỏ thích
            $delete_query = "DELETE FROM yeu_thich_san_pham WHERE user_id = '$user_id' AND product_id = '$product_id'";
            $result = mysqli_query($conn, $delete_query);
            
            if ($result) {
                http_response_code(200);
                echo json_encode([
                    "success" => true,
                    "message" => "Đã bỏ thích sản phẩm",
                    "data" => [
                        "user_id" => $user_id,
                        "product_id" => $product_id,
                        "is_favorite" => false,
                        "action" => "removed",
                        "product_name" => $product_info['tieu_de']
                    ]
                ]);
            } else {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Lỗi bỏ thích sản phẩm: " . mysqli_error($conn)
                ]);
            }
        } else {
            // Chưa thích -> Thích
            $insert_query = "INSERT INTO yeu_thich_san_pham (user_id, product_id) VALUES ('$user_id', '$product_id')";
            $result = mysqli_query($conn, $insert_query);
            
            if ($result) {
                $favorite_id = mysqli_insert_id($conn);
                
                http_response_code(200);
                echo json_encode([
                    "success" => true,
                    "message" => "Đã thích sản phẩm",
                    "data" => [
                        "favorite_id" => $favorite_id,
                        "user_id" => $user_id,
                        "product_id" => $product_id,
                        "is_favorite" => true,
                        "action" => "added",
                        "product_name" => $product_info['tieu_de'],
                        "shop_id" => $product_info['shop'],
                        "is_authentic" => !empty($product_info['thuong_hieu']) ? 1 : 0
                    ]
                ]);
                
                // Lưu hành vi yêu thích (chạy sau khi response đã được gửi, không ảnh hưởng API)
                if (function_exists('saveUserBehavior') && $user_id > 0 && $product_id > 0) {
                    try {
                        // Lấy category_id từ sản phẩm
                        $category_id = null;
                        $cat_query = "SELECT cat FROM sanpham WHERE id = $product_id LIMIT 1";
                        $cat_result = mysqli_query($conn, $cat_query);
                        if ($cat_result && mysqli_num_rows($cat_result) > 0) {
                            $cat_row = mysqli_fetch_assoc($cat_result);
                            if (!empty($cat_row['cat'])) {
                                $cat_array = explode(',', $cat_row['cat']);
                                if (!empty($cat_array)) {
                                    $category_id = intval(trim($cat_array[0]));
                                }
                            }
                        }
                        
                        saveUserBehavior($conn, $user_id, 'favorite', $product_id, null, $category_id, [
                            'product_title' => $product_info['tieu_de'],
                            'shop_id' => $product_info['shop']
                        ]);
                    } catch (Exception $e) {
                        error_log("Error saving favorite behavior: " . $e->getMessage());
                    }
                }
            } else {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Lỗi thích sản phẩm: " . mysqli_error($conn)
                ]);
            }
        }
        
    } else {
        http_response_code(405);
        echo json_encode([
            "success" => false,
            "message" => "Chỉ hỗ trợ phương thức POST, DELETE và PUT"
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


