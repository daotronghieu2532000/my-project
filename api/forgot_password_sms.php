<?php
/**
 * API Quên mật khẩu - Gửi OTP qua SMS (ZNS Zalo)
 * 
 * Endpoint: POST /forgot_password_sms.php
 * Headers: Authorization: Bearer {JWT_TOKEN}
 * Body: {
 *   "phone_number": "0123456789"
 * }
 */

// Bật debug mode (set = true để xem chi tiết lỗi trong response)
// TODO: Bỏ comment khi cần debug
// define('DEBUG_MODE', true);
define('DEBUG_MODE', false);

// Tắt hiển thị errors ra output (chỉ log vào error_log)
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);
ini_set('log_errors', 1);

// Bắt đầu output buffering để bắt mọi output không mong muốn
ob_start();

// Set headers trước khi load bất kỳ file nào
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Error handler để catch mọi lỗi và trả về JSON
function handleError($errno, $errstr, $errfile, $errline) {
    error_log("PHP Error [$errno]: $errstr in $errfile on line $errline");
    if (ob_get_level() > 0) {
        ob_clean();
    }
    http_response_code(500);
    $response = [
        'success' => false,
        'message' => 'Lỗi hệ thống',
        'error' => $errstr,
        'file' => basename($errfile),
        'line' => $errline
    ];
    
    // Thêm thông tin debug nếu bật debug mode
    if (defined('DEBUG_MODE') && DEBUG_MODE) {
        $response['debug'] = [
            'error_type' => 'PHP Error',
            'error_code' => $errno,
            'full_file' => $errfile,
            'stack_trace' => debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 5)
        ];
    }
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

// Fatal error handler
function handleFatalError() {
    $error = error_get_last();
    if ($error !== NULL && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        error_log("Fatal Error: " . print_r($error, true));
        if (ob_get_level() > 0) {
            ob_clean();
        }
        http_response_code(500);
        $response = [
            'success' => false,
            'message' => 'Lỗi nghiêm trọng trong hệ thống',
            'error' => $error['message'],
            'file' => basename($error['file']),
            'line' => $error['line']
        ];
        
        // Thêm thông tin debug nếu bật debug mode
        if (defined('DEBUG_MODE') && DEBUG_MODE) {
            $response['debug'] = [
                'error_type' => 'Fatal Error',
                'error_code' => $error['type'],
                'full_file' => $error['file'],
                'full_error' => $error
            ];
        }
        
        echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }
}

// Exception handler
function handleException($exception) {
    error_log("Uncaught Exception: " . $exception->getMessage() . " in " . $exception->getFile() . ":" . $exception->getLine());
    error_log("Stack trace: " . $exception->getTraceAsString());
    if (ob_get_level() > 0) {
        ob_clean();
    }
    http_response_code(500);
    $response = [
        'success' => false,
        'message' => 'Lỗi xử lý: ' . $exception->getMessage(),
        'error' => $exception->getMessage(),
        'file' => basename($exception->getFile()),
        'line' => $exception->getLine()
    ];
    
    // Thêm thông tin debug nếu bật debug mode
    if (defined('DEBUG_MODE') && DEBUG_MODE) {
        $response['debug'] = [
            'error_type' => get_class($exception),
            'full_file' => $exception->getFile(),
            'stack_trace' => $exception->getTraceAsString(),
            'previous' => $exception->getPrevious() ? $exception->getPrevious()->getMessage() : null
        ];
    }
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

// Đăng ký error handlers
set_error_handler('handleError');
set_exception_handler('handleException');
register_shutdown_function('handleFatalError');

// Tải thư viện JWT
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Helper function để output JSON (luôn clean buffer trước)
function outputJson($data, $httpCode = 200) {
    // Clean output buffer
    if (ob_get_level() > 0) {
        ob_clean();
    }
    
    // Set response code
    http_response_code($httpCode);
    
    // Encode JSON với pretty print nếu debug mode
    $jsonFlags = JSON_UNESCAPED_UNICODE;
    if (defined('DEBUG_MODE') && DEBUG_MODE) {
        $jsonFlags |= JSON_PRETTY_PRINT;
    }
    $json = json_encode($data, $jsonFlags);
    
    // Kiểm tra JSON encoding có lỗi không
    if ($json === false) {
        error_log("JSON Encode Error: " . json_last_error_msg());
        $json = json_encode([
            'success' => false,
            'message' => 'Lỗi encode JSON: ' . json_last_error_msg(),
            'debug' => defined('DEBUG_MODE') && DEBUG_MODE ? [
                'json_error' => json_last_error(),
                'data_being_encoded' => substr(print_r($data, true), 0, 500)
            ] : null
        ], $jsonFlags);
    }
    
    // TODO: Bỏ comment khi cần debug
    // Log response để debug
    // error_log("API Response (HTTP $httpCode): " . substr($json, 0, 1000));
    
    echo $json;
    exit;
}

// Load config và ZNS service với error handling
// Thử load config từ nhiều đường dẫn khác nhau
$config_paths = [
    '/home/api.socdo.vn/public_html/includes/config.php', // Đường dẫn production
    __DIR__ . '/config.php', // Đường dẫn local
    __DIR__ . '/../../includes/config.php', // Fallback relative
];

$config_loaded = false;
$config_path_used = null;

foreach ($config_paths as $config_path) {
    if (file_exists($config_path)) {
        try {
            // TODO: Bỏ comment khi cần debug
            // error_log("Trying to load config from: $config_path");
            require_once $config_path;
            $config_loaded = true;
            $config_path_used = $config_path;
            // error_log("Config loaded successfully from: $config_path");
            break;
        } catch (Exception $e) {
            // TODO: Bỏ comment khi cần debug
            // error_log("Error loading config from $config_path: " . $e->getMessage());
        } catch (Error $e) {
            // TODO: Bỏ comment khi cần debug
            // error_log("Fatal error loading config from $config_path: " . $e->getMessage());
        }
    }
}

// Fallback: Kết nối database trực tiếp nếu không load được config
if (!$config_loaded || !isset($conn)) {
    // TODO: Bỏ comment khi cần debug
    // error_log("Config not loaded or \$conn not set, using direct database connection");
    try {
        // Set timezone (thường có trong config.php)
        date_default_timezone_set('Asia/Saigon');
        
        $conn = mysqli_connect('localhost', 'socdo', 'Xdnt.qOPNz8!(cQi', 'socdo');
        if (!$conn) {
            throw new Exception('Database connection failed: ' . mysqli_connect_error());
        }
        mysqli_set_charset($conn, 'utf8mb4');
        // TODO: Bỏ comment khi cần debug
        // error_log("Direct database connection established successfully");
    } catch (Exception $e) {
        // TODO: Bỏ comment khi cần debug
        // error_log("Failed to establish direct database connection: " . $e->getMessage());
        outputJson([
            'success' => false,
            'message' => 'Lỗi kết nối database: ' . $e->getMessage()
        ], 500);
    }
}

// Load ZNS config và service
try {
    // TODO: Bỏ comment khi cần debug
    // error_log("Loading zns_config.php...");
    require_once __DIR__ . '/zns_config.php';
    // error_log("ZNS config loaded successfully");
    
    // error_log("Loading zns_service.php...");
    require_once __DIR__ . '/zns_service.php';
    // error_log("ZNS service loaded successfully");
} catch (Exception $e) {
    // TODO: Bỏ comment khi cần debug
    // error_log("Error loading ZNS files: " . $e->getMessage());
    outputJson([
        'success' => false,
        'message' => 'Lỗi load ZNS cấu hình: ' . $e->getMessage()
    ], 500);
} catch (Error $e) {
    // TODO: Bỏ comment khi cần debug
    // error_log("Fatal error loading ZNS files: " . $e->getMessage());
    outputJson([
        'success' => false,
        'message' => 'Lỗi nghiêm trọng load ZNS cấu hình: ' . $e->getMessage()
    ], 500);
}

// Kiểm tra các constants ZNS đã được define chưa
if (!defined('ZNS_ACCESS_TOKEN') || !defined('ZNS_REFRESH_TOKEN') || 
    !defined('ZNS_APP_ID') || !defined('ZNS_APP_SECRET') || 
    !defined('ZNS_OA_ID') || !defined('ZNS_TEMPLATE_ID')) {
    outputJson([
        'success' => false,
        'message' => 'Cấu hình ZNS chưa đầy đủ. Vui lòng kiểm tra file zns_config.php'
    ], 500);
}

// Cấu hình thông tin JWT
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

// Kiểm tra kết nối cơ sở dữ liệu (nếu chưa có $conn thì tạo mới)
if (!isset($conn) || !$conn) {
    // TODO: Bỏ comment khi cần debug
    // error_log("Database connection not found, creating new connection...");
    try {
        // Set timezone nếu chưa set
        date_default_timezone_set('Asia/Saigon');
        
        $conn = mysqli_connect('localhost', 'socdo', 'Xdnt.qOPNz8!(cQi', 'socdo');
        if (!$conn) {
            throw new Exception('Database connection failed: ' . mysqli_connect_error());
        }
        mysqli_set_charset($conn, 'utf8mb4');
        // TODO: Bỏ comment khi cần debug
        // error_log("New database connection established");
    } catch (Exception $e) {
        outputJson([
            'success' => false,
            'message' => 'Lỗi kết nối cơ sở dữ liệu: ' . $e->getMessage()
        ], 500);
    }
}

// Kiểm tra lỗi kết nối
if (mysqli_connect_errno()) {
    outputJson([
        'success' => false,
        'message' => 'Lỗi kết nối cơ sở dữ liệu: ' . mysqli_connect_error()
    ], 500);
}

// Chỉ cho phép phương thức POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    outputJson([
        'success' => false,
        'message' => 'Phương thức không được phép! Vui lòng sử dụng POST.'
    ], 405);
}

// Lấy token từ header Authorization
$headers = getallheaders();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    outputJson([
        'success' => false,
        'message' => 'Không tìm thấy token'
    ], 401);
}

$jwt = $matches[1];

try {
    // TODO: Bỏ comment khi cần debug
    // error_log("Decoding JWT token...");
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    // error_log("JWT decoded successfully");
    
    // Kiểm tra issuer
    if ($decoded->iss !== $issuer) {
        outputJson([
            'success' => false,
            'message' => 'Issuer không hợp lệ'
        ], 401);
    }

    // Lấy dữ liệu JSON từ body
    $rawData = file_get_contents('php://input');
    // TODO: Bỏ comment khi cần debug
    // error_log("Forgot Password SMS - Raw input: " . $rawData);
    $data = json_decode($rawData, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        outputJson([
            'success' => false,
            'message' => 'Dữ liệu JSON không hợp lệ: ' . json_last_error_msg()
        ], 400);
    }

    $phone_number = isset($data['phone_number']) ? trim($data['phone_number']) : '';
    $ip_address = $_SERVER['REMOTE_ADDR'];
    // TODO: Bỏ comment khi cần debug
    // error_log("Phone: $phone_number, IP: $ip_address");

    // Kiểm tra số điện thoại hợp lệ
    if (empty($phone_number)) {
        outputJson([
            'success' => false,
            'message' => 'Vui lòng nhập số điện thoại'
        ], 400);
    }

    // Validate số điện thoại: 10 số, bắt đầu bằng 0
    $phone_number = preg_replace('/[^0-9]/', '', $phone_number);
    if (strlen($phone_number) !== 10 || $phone_number[0] !== '0') {
        outputJson([
            'success' => false,
            'message' => 'Số điện thoại không hợp lệ. Vui lòng nhập số điện thoại 10 chữ số bắt đầu bằng 0'
        ], 400);
    }

    // Kiểm tra số điện thoại tồn tại trong bảng user_info
    $stmt = $conn->prepare("SELECT * FROM user_info WHERE mobile = ? AND shop = '0' LIMIT 1");
    $stmt->bind_param("s", $phone_number);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows == 0) {
        $stmt->close();
        outputJson([
            'success' => false,
            'message' => 'Số điện thoại không tồn tại trong hệ thống'
        ], 404);
    }

    // Lấy thông tin người dùng
    $user = $result->fetch_assoc();
    $stmt->close();
    // TODO: Bỏ comment khi cần debug
    // error_log("User info: " . print_r($user, true));

    // Kiểm tra số lượng yêu cầu OTP
    $stmt = $conn->prepare("SELECT * FROM code_otp WHERE dien_thoai = ? ORDER BY id DESC");
    $stmt->bind_param("s", $phone_number);
    $stmt->execute();
    $otpHistory = $stmt->get_result();
    $total = $otpHistory->num_rows;
    
    // Tạo mã OTP 6 chữ số
    $code_otp = str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
    $hientai = time();
    // TODO: Bỏ comment khi cần debug
    // error_log("OTP: $code_otp, Total requests: $total");

    // Xử lý logic OTP
    if ($total < 1) {
        // Lần đầu yêu cầu OTP - kiểm tra giới hạn IP
        $stmt_ip = $conn->prepare("SELECT COUNT(*) as total FROM code_otp WHERE ip_address = ?");
        $stmt_ip->bind_param("s", $ip_address);
        $stmt_ip->execute();
        $ipResult = $stmt_ip->get_result();
        $ipRow = $ipResult->fetch_assoc();
        $total_ip = $ipRow['total'];
        $stmt_ip->close();

        if ($total_ip >= 2) {
            outputJson([
                'success' => false,
                'message' => 'Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau 1 phút'
            ], 429);
        }

        // Gửi OTP qua ZNS
        // TODO: Bỏ comment khi cần debug
        // error_log("Creating ZNS Service instance...");
        try {
            $znsService = new ZNSService(
                ZNS_ACCESS_TOKEN, 
                ZNS_REFRESH_TOKEN, 
                ZNS_APP_ID, 
                ZNS_APP_SECRET, 
                ZNS_OA_ID, 
                ZNS_TEMPLATE_ID,
                ZNS_TOKEN_CACHE_FILE
            );
            // error_log("ZNS Service created, sending OTP...");
            $znsResult = $znsService->sendOTP($phone_number, $code_otp, $user['name']);
            // error_log("ZNS sendOTP result: " . json_encode($znsResult));
        } catch (Exception $e) {
            // TODO: Bỏ comment khi cần debug
            // error_log("Error creating/sending ZNS: " . $e->getMessage());
            outputJson([
                'success' => false,
                'message' => 'Lỗi gửi OTP: ' . $e->getMessage()
            ], 500);
        }
        
        if ($znsResult['success']) {
            // Lưu mã OTP vào cơ sở dữ liệu
            $stmt_insert = $conn->prepare("INSERT INTO code_otp (dien_thoai, otp, ip_address, date_post) VALUES (?, ?, ?, ?)");
            $stmt_insert->bind_param("sssi", $phone_number, $code_otp, $ip_address, $hientai);
            
            if ($stmt_insert->execute()) {
                $stmt_insert->close();
                outputJson([
                    'success' => true,
                    'message' => 'Mã OTP đã được gửi đến số điện thoại của bạn',
                    'data' => [
                        'phone_number' => substr($phone_number, 0, 3) . '****' . substr($phone_number, -3) // Ẩn số điện thoại
                    ]
                ], 200);
            } else {
                // TODO: Bỏ comment khi cần debug
                // error_log("Lỗi lưu OTP: " . $stmt_insert->error);
                $stmt_insert->close();
                outputJson([
                    'success' => false,
                    'message' => 'Lỗi lưu mã OTP vào cơ sở dữ liệu'
                ], 500);
            }
        } else {
            outputJson([
                'success' => false,
                'message' => $znsResult['message'] ?? 'Gặp lỗi khi gửi mã OTP'
            ], 500);
        }
    } else {
        // Đã có lịch sử OTP
        if ($total >= 2) {
            outputJson([
                'success' => false,
                'message' => 'Bạn đã yêu cầu mã quá nhiều lần! Hãy liên hệ hotline để được hỗ trợ'
            ], 429);
        }

        $lastOtp = $otpHistory->fetch_assoc();
        $stmt->close();
        
        // Kiểm tra thời gian giữa các lần gửi (tối thiểu 60 giây)
        if ((time() - (int)$lastOtp['date_post']) <= 60) {
            outputJson([
                'success' => false,
                'message' => 'Vui lòng thử lại sau 1 phút'
            ], 429);
        }

        // Gửi OTP mới qua ZNS
        // TODO: Bỏ comment khi cần debug
        // error_log("Creating ZNS Service instance (retry)...");
        try {
            $znsService = new ZNSService(
                ZNS_ACCESS_TOKEN, 
                ZNS_REFRESH_TOKEN, 
                ZNS_APP_ID, 
                ZNS_APP_SECRET, 
                ZNS_OA_ID, 
                ZNS_TEMPLATE_ID,
                ZNS_TOKEN_CACHE_FILE
            );
            // error_log("ZNS Service created (retry), sending OTP...");
            $znsResult = $znsService->sendOTP($phone_number, $code_otp, $user['name']);
            // error_log("ZNS sendOTP result (retry): " . json_encode($znsResult));
        } catch (Exception $e) {
            // TODO: Bỏ comment khi cần debug
            // error_log("Error creating/sending ZNS (retry): " . $e->getMessage());
            outputJson([
                'success' => false,
                'message' => 'Lỗi gửi OTP: ' . $e->getMessage()
            ], 500);
        }
        
        if ($znsResult['success']) {
            // Lưu mã OTP vào cơ sở dữ liệu
            $stmt_insert = $conn->prepare("INSERT INTO code_otp (dien_thoai, otp, ip_address, date_post) VALUES (?, ?, ?, ?)");
            $stmt_insert->bind_param("sssi", $phone_number, $code_otp, $ip_address, $hientai);
            
            if ($stmt_insert->execute()) {
                $stmt_insert->close();
                outputJson([
                    'success' => true,
                    'message' => 'Mã OTP đã được gửi đến số điện thoại của bạn',
                    'data' => [
                        'phone_number' => substr($phone_number, 0, 3) . '****' . substr($phone_number, -3)
                    ]
                ], 200);
            } else {
                // TODO: Bỏ comment khi cần debug
                // error_log("Lỗi lưu OTP: " . $stmt_insert->error);
                $stmt_insert->close();
                outputJson([
                    'success' => false,
                    'message' => 'Lỗi lưu mã OTP vào cơ sở dữ liệu'
                ], 500);
            }
        } else {
            outputJson([
                'success' => false,
                'message' => $znsResult['message'] ?? 'Gặp lỗi khi gửi mã OTP'
            ], 500);
        }
    }

} catch (Exception $e) {
    // TODO: Bỏ comment khi cần debug
    // error_log("Exception caught: " . $e->getMessage());
    // error_log("Exception file: " . $e->getFile() . ":" . $e->getLine());
    // error_log("Exception trace: " . $e->getTraceAsString());
    
    $response = [
        'success' => false,
        'message' => 'Lỗi xử lý: ' . $e->getMessage(),
        'error' => $e->getMessage(),
        'error_type' => get_class($e),
        'file' => basename($e->getFile()),
        'line' => $e->getLine()
    ];
    
    // Thêm debug info nếu bật debug mode
    if (defined('DEBUG_MODE') && DEBUG_MODE) {
        $response['debug'] = [
            'full_file' => $e->getFile(),
            'stack_trace' => $e->getTraceAsString(),
            'previous' => $e->getPrevious() ? $e->getPrevious()->getMessage() : null
        ];
    }
    
    outputJson($response, 500);
} catch (Error $e) {
    // TODO: Bỏ comment khi cần debug
    // error_log("Fatal Error caught: " . $e->getMessage());
    // error_log("Error file: " . $e->getFile() . ":" . $e->getLine());
    // error_log("Error trace: " . $e->getTraceAsString());
    
    $response = [
        'success' => false,
        'message' => 'Lỗi nghiêm trọng: ' . $e->getMessage(),
        'error' => $e->getMessage(),
        'error_type' => get_class($e),
        'file' => basename($e->getFile()),
        'line' => $e->getLine()
    ];
    
    // Thêm debug info nếu bật debug mode
    if (defined('DEBUG_MODE') && DEBUG_MODE) {
        $response['debug'] = [
            'full_file' => $e->getFile(),
            'stack_trace' => $e->getTraceAsString()
        ];
    }
    
    outputJson($response, 500);
}

// Kết thúc output buffering (nếu chưa exit)
if (ob_get_level() > 0) {
    ob_end_flush();
}
?>

