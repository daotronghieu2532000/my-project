<?php
/**
 * File debug để kiểm tra lỗi API
 * Gọi: /debug_api.php?file=search_products.php
 */

header("Content-Type: application/json; charset=utf-8");
error_reporting(E_ALL);
ini_set('display_errors', 1);

$file = isset($_GET['file']) ? $_GET['file'] : '';

if (empty($file)) {
    echo json_encode([
        'error' => 'Thiếu tham số file',
        'usage' => '?file=search_products.php'
    ]);
    exit;
}

$file_path = __DIR__ . '/' . $file;

if (!file_exists($file_path)) {
    echo json_encode([
        'error' => "File không tồn tại: $file",
        'path' => $file_path
    ]);
    exit;
}

// Kiểm tra config.php
$config_paths = [
    '/home/api.socdo.vn/public_html/includes/config.php',
    __DIR__ . '/../../../../../includes/config.php',
    __DIR__ . '/includes/config.php',
    __DIR__ . '/config.php',
];

$config_found = false;
$config_path = null;

foreach ($config_paths as $path) {
    if (file_exists($path)) {
        $config_found = true;
        $config_path = $path;
        break;
    }
}

// Kiểm tra user_behavior_helper.php
$helper_path = __DIR__ . '/user_behavior_helper.php';
$helper_exists = file_exists($helper_path);

// Kiểm tra bảng user_behavior
$table_exists = false;
if ($config_found) {
    try {
        require_once $config_path;
        if (isset($conn) && $conn) {
            $check_table = mysqli_query($conn, "SHOW TABLES LIKE 'user_behavior'");
            $table_exists = mysqli_num_rows($check_table) > 0;
        }
    } catch (Exception $e) {
        // Ignore
    }
}

// Kiểm tra syntax PHP
$syntax_ok = true;
$syntax_error = null;

$output = shell_exec("php -l $file_path 2>&1");
if (strpos($output, 'No syntax errors') === false) {
    $syntax_ok = false;
    $syntax_error = $output;
}

$result = [
    'file' => $file,
    'file_exists' => file_exists($file_path),
    'file_path' => $file_path,
    'config' => [
        'found' => $config_found,
        'path' => $config_path,
        'paths_checked' => $config_paths,
    ],
    'helper' => [
        'exists' => $helper_exists,
        'path' => $helper_path,
    ],
    'database' => [
        'table_exists' => $table_exists,
        'connection' => isset($conn) && $conn ? 'OK' : 'FAILED',
    ],
    'syntax' => [
        'ok' => $syntax_ok,
        'error' => $syntax_error,
    ],
];

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>

