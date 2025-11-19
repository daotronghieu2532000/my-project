<?php
/**
 * Test endpoint để debug forgot_password_sms
 * Truy cập: https://api.socdo.vn/v1/test_forgot_password
 */

// Bật debug mode
define('DEBUG_MODE', true);

// Tắt hiển thị errors
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);
ini_set('log_errors', 1);

// Output buffering
ob_start();

// Headers
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Helper function
function outputJson($data, $httpCode = 200) {
    if (ob_get_level() > 0) {
        ob_clean();
    }
    http_response_code($httpCode);
    $jsonFlags = JSON_UNESCAPED_UNICODE;
    if (defined('DEBUG_MODE') && DEBUG_MODE) {
        $jsonFlags |= JSON_PRETTY_PRINT;
    }
    echo json_encode($data, $jsonFlags);
    exit;
}

// Test 1: Kiểm tra file có tồn tại không
$testResults = [
    'test_time' => date('Y-m-d H:i:s'),
    'server_info' => [
        'php_version' => PHP_VERSION,
        'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
        'request_method' => $_SERVER['REQUEST_METHOD'],
        'request_uri' => $_SERVER['REQUEST_URI'] ?? 'Unknown',
        'script_name' => __FILE__,
        'current_dir' => __DIR__,
    ],
    'file_checks' => [],
    'config_checks' => [],
    'tests' => []
];

// Test file existence
$filesToCheck = [
    'config.php' => __DIR__ . '/config.php',
    'zns_config.php' => __DIR__ . '/zns_config.php',
    'zns_service.php' => __DIR__ . '/zns_service.php',
    'forgot_password_sms.php' => __DIR__ . '/forgot_password_sms.php',
    'vendor/autoload.php' => __DIR__ . '/vendor/autoload.php',
];

foreach ($filesToCheck as $name => $path) {
    $testResults['file_checks'][$name] = [
        'exists' => file_exists($path),
        'path' => $path,
        'readable' => is_readable($path),
        'size' => file_exists($path) ? filesize($path) : 0
    ];
}

// Test load config
try {
    if (file_exists(__DIR__ . '/config.php')) {
        require_once __DIR__ . '/config.php';
        $testResults['config_checks']['config.php'] = [
            'loaded' => true,
            'conn_exists' => isset($conn),
            'conn_type' => isset($conn) ? get_class($conn) : 'N/A'
        ];
    }
} catch (Exception $e) {
    $testResults['config_checks']['config.php'] = [
        'loaded' => false,
        'error' => $e->getMessage()
    ];
}

// Test load zns_config
try {
    if (file_exists(__DIR__ . '/zns_config.php')) {
        require_once __DIR__ . '/zns_config.php';
        $testResults['config_checks']['zns_config.php'] = [
            'loaded' => true,
            'ZNS_ACCESS_TOKEN' => defined('ZNS_ACCESS_TOKEN') ? (strlen(ZNS_ACCESS_TOKEN) > 0 ? 'SET (' . strlen(ZNS_ACCESS_TOKEN) . ' chars)' : 'EMPTY') : 'NOT DEFINED',
            'ZNS_REFRESH_TOKEN' => defined('ZNS_REFRESH_TOKEN') ? (strlen(ZNS_REFRESH_TOKEN) > 0 ? 'SET (' . strlen(ZNS_REFRESH_TOKEN) . ' chars)' : 'EMPTY') : 'NOT DEFINED',
            'ZNS_APP_ID' => defined('ZNS_APP_ID') ? ZNS_APP_ID : 'NOT DEFINED',
            'ZNS_APP_SECRET' => defined('ZNS_APP_SECRET') ? (strlen(ZNS_APP_SECRET) > 0 ? 'SET (' . strlen(ZNS_APP_SECRET) . ' chars)' : 'EMPTY') : 'NOT DEFINED',
            'ZNS_OA_ID' => defined('ZNS_OA_ID') ? ZNS_OA_ID : 'NOT DEFINED',
            'ZNS_TEMPLATE_ID' => defined('ZNS_TEMPLATE_ID') ? ZNS_TEMPLATE_ID : 'NOT DEFINED',
        ];
    }
} catch (Exception $e) {
    $testResults['config_checks']['zns_config.php'] = [
        'loaded' => false,
        'error' => $e->getMessage()
    ];
}

// Test load zns_service
try {
    if (file_exists(__DIR__ . '/zns_service.php')) {
        require_once __DIR__ . '/zns_service.php';
        $testResults['config_checks']['zns_service.php'] = [
            'loaded' => true,
            'class_exists' => class_exists('ZNSService')
        ];
    }
} catch (Exception $e) {
    $testResults['config_checks']['zns_service.php'] = [
        'loaded' => false,
        'error' => $e->getMessage()
    ];
}

// Test JWT library
try {
    if (file_exists(__DIR__ . '/vendor/autoload.php')) {
        require_once __DIR__ . '/vendor/autoload.php';
        $testResults['tests']['jwt_library'] = [
            'loaded' => true,
            'JWT_class_exists' => class_exists('\Firebase\JWT\JWT'),
            'Key_class_exists' => class_exists('\Firebase\JWT\Key')
        ];
    }
} catch (Exception $e) {
    $testResults['tests']['jwt_library'] = [
        'loaded' => false,
        'error' => $e->getMessage()
    ];
}

// Test actual API call simulation
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $rawData = file_get_contents('php://input');
    $testResults['tests']['post_data'] = [
        'raw_input' => $rawData,
        'content_type' => $_SERVER['CONTENT_TYPE'] ?? 'Not set',
        'headers' => function_exists('getallheaders') ? getallheaders() : 'getallheaders() not available'
    ];
    
    $data = json_decode($rawData, true);
    $testResults['tests']['post_data']['parsed'] = $data;
    $testResults['tests']['post_data']['json_error'] = json_last_error() !== JSON_ERROR_NONE ? json_last_error_msg() : 'None';
}

// Test headers
$testResults['tests']['headers'] = [
    'authorization' => $_SERVER['HTTP_AUTHORIZATION'] ?? 'Not set',
    'all_headers' => function_exists('getallheaders') ? getallheaders() : 'getallheaders() not available',
    'server_headers' => [
        'CONTENT_TYPE' => $_SERVER['CONTENT_TYPE'] ?? 'Not set',
        'REQUEST_METHOD' => $_SERVER['REQUEST_METHOD'] ?? 'Not set',
    ]
];

// Output results
outputJson([
    'success' => true,
    'message' => 'Test endpoint - Debug information',
    'data' => $testResults
], 200);

