<?php
header('Content-Type: application/json; charset=utf-8');
header("Access-Control-Allow-Methods: POST, OPTIONS");
require_once './vendor/autoload.php';
require_once './includes/config.php';
// Include user_behavior_helper để lưu hành vi người dùng
$helper_path = __DIR__ . '/user_behavior_helper.php';
if (file_exists($helper_path)) {
    require_once $helper_path;
}
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Lấy token từ header Authorization
$headers = function_exists('apache_request_headers') ? apache_request_headers() : [];
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$jwt = null;
if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    $jwt = $matches[1];
}

// Đọc JSON body từ request (Flutter gửi JSON)
$json_body = file_get_contents('php://input');
$request_data = [];
if (!empty($json_body)) {
    $request_data = json_decode($json_body, true);
    if (!is_array($request_data)) {
        $request_data = [];
    }
}

// Lấy user_id từ JSON body hoặc POST hoặc GET parameter (ưu tiên JSON body)
$user_id = isset($request_data['user_id']) ? intval($request_data['user_id']) : (isset($_POST['user_id']) ? intval($_POST['user_id']) : (isset($_GET['user_id']) ? intval($_GET['user_id']) : 0));

error_log("🛒 [add_to_cart] Request received: method=" . $_SERVER['REQUEST_METHOD']);
error_log("🛒 [add_to_cart] JSON body: $json_body");
error_log("🛒 [add_to_cart] Request data: " . json_encode($request_data));
error_log("🛒 [add_to_cart] POST data: " . json_encode($_POST));
error_log("🛒 [add_to_cart] Initial user_id from JSON/POST/GET: $user_id");
error_log("🛒 [add_to_cart] JWT token present: " . ($jwt ? 'YES' : 'NO'));

try {
    // Nếu không có user_id từ POST/GET, thử lấy từ JWT token
    if ($user_id <= 0 && $jwt) {
        error_log("🛒 [add_to_cart] Attempting to decode JWT token...");
        try {
            $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
            error_log("🛒 [add_to_cart] JWT decoded successfully");
            error_log("🛒 [add_to_cart] JWT payload: " . json_encode($decoded));
            
            if (isset($decoded->iss) && $decoded->iss === $issuer) {
                $user_id = isset($decoded->user_id) ? intval($decoded->user_id) : 0;
                error_log("🛒 [add_to_cart] user_id from decoded->user_id: $user_id");
                
                // Thử lấy từ decoded->data->user_id (nested trong data)
                if ($user_id <= 0 && isset($decoded->data) && isset($decoded->data->user_id)) {
                    $user_id = intval($decoded->data->user_id);
                    error_log("🛒 [add_to_cart] user_id from decoded->data->user_id: $user_id");
                }
            } else {
                error_log("⚠️ [add_to_cart] JWT issuer mismatch: expected=$issuer, got=" . (isset($decoded->iss) ? $decoded->iss : 'NULL'));
            }
        } catch (Exception $e) {
            error_log("❌ [add_to_cart] Error decoding JWT: " . $e->getMessage());
        }
    }
    
    error_log("🛒 [add_to_cart] Final user_id: $user_id");
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode([
            "success" => false,
            "message" => "Chỉ hỗ trợ phương thức POST"
        ]);
        exit;
    }
    
    // Lấy thông tin sản phẩm từ JSON body hoặc POST (ưu tiên JSON body)
    $product_id = isset($request_data['product_id']) ? intval($request_data['product_id']) : (isset($_POST['product_id']) ? intval($_POST['product_id']) : 0);
    $quantity = isset($request_data['quantity']) ? intval($request_data['quantity']) : (isset($_POST['quantity']) ? intval($_POST['quantity']) : 1);
    $variant = isset($request_data['variant']) ? addslashes(trim($request_data['variant'])) : (isset($_POST['variant']) ? addslashes(trim($_POST['variant'])) : '');
    
    error_log("🛒 [add_to_cart] Product data: product_id=$product_id, quantity=$quantity, variant=$variant");
    
    // Validate
    if ($product_id <= 0) {
        error_log("❌ [add_to_cart] Validation failed: product_id <= 0");
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Thiếu product_id"
        ]);
        exit;
    }
    
    if ($user_id <= 0) {
        error_log("⚠️ [add_to_cart] user_id <= 0, but continuing to save cart behavior anyway (may fail)");
    }
    
    // Lấy thông tin sản phẩm từ database
    $product_query = "SELECT s.*, 
                     GROUP_CONCAT(DISTINCT s.cat) as categories
                     FROM sanpham s
                     WHERE s.id = $product_id 
                     AND s.active = 0
                     LIMIT 1";
    
    $product_result = mysqli_query($conn, $product_query);
    
    if (!$product_result || mysqli_num_rows($product_result) == 0) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "Không tìm thấy sản phẩm"
        ]);
        exit;
    }
    
    $product = mysqli_fetch_assoc($product_result);
    $product_title = $product['tieu_de'];
    $product_price = $product['gia_moi'];
    $shop_id = $product['shop'];
    
    // Lấy category_id (category đầu tiên nếu có)
    $category_id = null;
    if (!empty($product['categories'])) {
        $cat_array = explode(',', $product['categories']);
        if (!empty($cat_array)) {
            $category_id = intval(trim($cat_array[0]));
        }
    }
    
    // Lưu hành vi thêm vào giỏ hàng
    if (function_exists('saveUserBehavior') && $user_id > 0) {
        error_log("🛒 [add_to_cart] Attempting to save cart behavior: user_id=$user_id, product_id=$product_id, quantity=$quantity");
        
        $saved = saveUserBehavior($conn, $user_id, 'cart', $product_id, null, $category_id, [
            'product_title' => $product_title,
            'product_price' => $product_price,
            'quantity' => $quantity,
            'variant' => $variant,
            'shop_id' => $shop_id
        ]);
        
        if ($saved) {
            error_log("✅ [add_to_cart] Cart behavior saved successfully for user_id=$user_id, product_id=$product_id");
        } else {
            error_log("❌ [add_to_cart] Failed to save cart behavior for user_id=$user_id, product_id=$product_id");
        }
    } else {
        error_log("⚠️ [add_to_cart] Cannot save cart behavior: user_id=$user_id, function_exists=" . (function_exists('saveUserBehavior') ? 'YES' : 'NO'));
    }
    
    // Trả về response thành công
    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Đã thêm sản phẩm vào giỏ hàng",
        "data" => [
            "product_id" => $product_id,
            "quantity" => $quantity,
            "variant" => $variant
        ]
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Lỗi server: " . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
?>

