<?php
/**
 * FCM Configuration - HTTP V1 API
 * Sử dụng Service Account JSON để authenticate
 * 
 * QUAN TRỌNG: File này chứa thông tin bảo mật, KHÔNG commit vào Git!
 * Thêm vào .gitignore: 
 * - API_WEB/fcm_config.php
 * - API_WEB/socdomobile-*.json
 */

// Đường dẫn đến Service Account JSON file
// File JSON phải nằm cùng thư mục với fcm_config.php
// Trên server: /home/api.socdo.vn/public_html/home/themes/socdo/action/process/socdomobile-36bf021cb402.json

// Tìm file JSON ở nhiều vị trí (để đảm bảo tìm được trong mọi trường hợp)
$jsonFileName = 'socdomobile-36bf021cb402.json';
$possiblePaths = array(
    __DIR__ . '/' . $jsonFileName,  // Cùng thư mục với fcm_config.php
    dirname(__FILE__) . '/' . $jsonFileName,  // Backup cách khác
    '/home/api.socdo.vn/public_html/home/themes/socdo/action/process/' . $jsonFileName,  // Đường dẫn tuyệt đối trên server
);

$FCM_SERVICE_ACCOUNT_JSON_PATH = null;
foreach ($possiblePaths as $path) {
    if (file_exists($path)) {
        $FCM_SERVICE_ACCOUNT_JSON_PATH = $path;
        break;
    }
}

// Nếu không tìm thấy, dùng mặc định
if ($FCM_SERVICE_ACCOUNT_JSON_PATH === null) {
    $FCM_SERVICE_ACCOUNT_JSON_PATH = __DIR__ . '/' . $jsonFileName;
}

// Project ID - Tự động lấy từ Service Account JSON file
// Fallback: nếu không lấy được từ JSON, dùng giá trị mặc định 'socdomobile'
$FCM_PROJECT_ID = null;
try {
    $jsonPath = null;
    $jsonFileName = 'socdomobile-36bf021cb402.json';
    $possiblePaths = array(
        __DIR__ . '/' . $jsonFileName,
        dirname(__FILE__) . '/' . $jsonFileName,
        '/home/api.socdo.vn/public_html/home/themes/socdo/action/process/' . $jsonFileName,
    );
    
    foreach ($possiblePaths as $path) {
        if (file_exists($path)) {
            $jsonPath = $path;
            break;
        }
    }
    
    if ($jsonPath && file_exists($jsonPath)) {
        $jsonContent = file_get_contents($jsonPath);
        $jsonData = json_decode($jsonContent, true);
        if ($jsonData && isset($jsonData['project_id'])) {
            $FCM_PROJECT_ID = $jsonData['project_id'];
        }
    }
} catch (Exception $e) {
    // Nếu lỗi, dùng giá trị mặc định
}

// Nếu không lấy được từ JSON, dùng giá trị mặc định
if (empty($FCM_PROJECT_ID)) {
    $FCM_PROJECT_ID = 'socdomobile';
}

// FCM API URL (HTTP v1) - Tự động tạo từ Project ID
$FCM_API_URL = 'https://fcm.googleapis.com/v1/projects/' . $FCM_PROJECT_ID . '/messages:send';

/**
 * Lấy Service Account JSON data
 */
function getFCMServiceAccountData() {
    global $FCM_SERVICE_ACCOUNT_JSON_PATH;
    
    // Log để debug
    $logPath = dirname(__FILE__) . '/debug_push_notifications.log';
    file_put_contents($logPath, date('c') . " | [FCM_CONFIG] Looking for JSON file at: $FCM_SERVICE_ACCOUNT_JSON_PATH\n", FILE_APPEND);
    file_put_contents($logPath, date('c') . " | [FCM_CONFIG] File exists: " . (file_exists($FCM_SERVICE_ACCOUNT_JSON_PATH) ? 'YES' : 'NO') . "\n", FILE_APPEND);
    file_put_contents($logPath, date('c') . " | [FCM_CONFIG] __DIR__ = " . __DIR__ . "\n", FILE_APPEND);
    
    if (!file_exists($FCM_SERVICE_ACCOUNT_JSON_PATH)) {
        // Thử tìm lại ở các vị trí khác
        $jsonFileName = 'socdomobile-36bf021cb402.json';
        $alternativePaths = array(
            __DIR__ . '/' . $jsonFileName,
            dirname(__FILE__) . '/' . $jsonFileName,
            '/home/api.socdo.vn/public_html/home/themes/socdo/action/process/' . $jsonFileName,
        );
        
        foreach ($alternativePaths as $altPath) {
            file_put_contents($logPath, date('c') . " | [FCM_CONFIG] Trying alternative path: $altPath (exists: " . (file_exists($altPath) ? 'YES' : 'NO') . ")\n", FILE_APPEND);
            if (file_exists($altPath)) {
                $FCM_SERVICE_ACCOUNT_JSON_PATH = $altPath;
                file_put_contents($logPath, date('c') . " | [FCM_CONFIG] Found JSON file at alternative path: $altPath\n", FILE_APPEND);
                break;
            }
        }
    }
    
    if (!file_exists($FCM_SERVICE_ACCOUNT_JSON_PATH)) {
        // Danh sách các đường dẫn đã thử
        $jsonFileName = 'socdomobile-36bf021cb402.json';
        $checkedPaths = array(
            __DIR__ . '/' . $jsonFileName,
            dirname(__FILE__) . '/' . $jsonFileName,
            '/home/api.socdo.vn/public_html/home/themes/socdo/action/process/' . $jsonFileName,
        );
        $error = 'Service Account JSON file không tồn tại: ' . $FCM_SERVICE_ACCOUNT_JSON_PATH . ' (checked paths: ' . implode(', ', $checkedPaths) . ')';
        file_put_contents($logPath, date('c') . " | [FCM_CONFIG] ERROR: $error\n", FILE_APPEND);
        throw new Exception($error);
    }
    
    $jsonContent = file_get_contents($FCM_SERVICE_ACCOUNT_JSON_PATH);
    $data = json_decode($jsonContent, true);
    
    if (!$data) {
        throw new Exception('Không thể parse Service Account JSON file');
    }
    
    return $data;
}

/**
 * Lấy Project ID
 */
function getFCMProjectId() {
    global $FCM_PROJECT_ID;
    
    // Nếu PROJECT_ID rỗng, set lại giá trị mặc định
    if (empty($FCM_PROJECT_ID)) {
        $FCM_PROJECT_ID = 'socdomobile';
        $logPath = dirname(__FILE__) . '/debug_push_notifications.log';
        file_put_contents($logPath, date('c') . " | [getFCMProjectId] PROJECT_ID was empty, set to default: $FCM_PROJECT_ID\n", FILE_APPEND);
    }
    
    return $FCM_PROJECT_ID;
}

/**
 * Lấy FCM API URL
 */
function getFCMApiUrl() {
    global $FCM_API_URL, $FCM_PROJECT_ID;
    
    // Debug logging
    $logPath = dirname(__FILE__) . '/debug_push_notifications.log';
    file_put_contents($logPath, date('c') . " | [getFCMApiUrl] Initial FCM_PROJECT_ID: " . ($FCM_PROJECT_ID ?: 'EMPTY') . "\n", FILE_APPEND);
    file_put_contents($logPath, date('c') . " | [getFCMApiUrl] Initial FCM_API_URL: " . ($FCM_API_URL ?: 'EMPTY') . "\n", FILE_APPEND);
    
    // Nếu PROJECT_ID rỗng, set lại giá trị mặc định
    if (empty($FCM_PROJECT_ID)) {
        $FCM_PROJECT_ID = 'socdomobile';
        file_put_contents($logPath, date('c') . " | [getFCMApiUrl] PROJECT_ID was empty, set to default: $FCM_PROJECT_ID\n", FILE_APPEND);
    }
    
    // Nếu URL rỗng, tạo lại (luôn tạo lại nếu rỗng, không cần check PROJECT_ID vì đã set ở trên)
    if (empty($FCM_API_URL)) {
        $FCM_API_URL = 'https://fcm.googleapis.com/v1/projects/' . $FCM_PROJECT_ID . '/messages:send';
        file_put_contents($logPath, date('c') . " | [getFCMApiUrl] Regenerated URL: $FCM_API_URL\n", FILE_APPEND);
    }
    
    file_put_contents($logPath, date('c') . " | [getFCMApiUrl] Final FCM_PROJECT_ID: $FCM_PROJECT_ID\n", FILE_APPEND);
    file_put_contents($logPath, date('c') . " | [getFCMApiUrl] Final FCM_API_URL: $FCM_API_URL\n", FILE_APPEND);
    
    return $FCM_API_URL;
}

/**
 * Lấy Access Token từ Service Account
 * Sử dụng Google Auth Library hoặc JWT để authenticate
 */
function getFCMAccessToken() {
    // Sẽ được implement trong fcm_push_service.php
    // Sử dụng Google Auth Library hoặc manual JWT signing
    return null;
}
?>
