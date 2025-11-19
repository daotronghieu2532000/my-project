<?php
/**
 * Cron Job: Kiểm tra voucher sắp hết hạn và tạo thông báo
 * Chạy mỗi giờ để kiểm tra voucher sắp hết hạn trong 24h
 */

$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;
require_once './notification_mobile_helper.php';

// Chỉ cho phép chạy từ command line hoặc với secret key
$secret_key = isset($argv[1]) ? $argv[1] : (isset($_GET['key']) ? $_GET['key'] : '');
$valid_key = 'socdo_cron_2025';

if ($secret_key !== $valid_key) {
    http_response_code(403);
    echo "Access denied\n";
    exit;
}

try {
    $notificationHelper = new NotificationMobileHelper($conn);
    
    echo "[" . date('Y-m-d H:i:s') . "] Bắt đầu kiểm tra voucher sắp hết hạn...\n";
    
    $notified_count = $notificationHelper->checkExpiringVouchers();
    
    echo "[" . date('Y-m-d H:i:s') . "] Hoàn thành! Đã tạo $notified_count thông báo voucher sắp hết hạn.\n";
    
    // Log kết quả
    $log_message = "[" . date('Y-m-d H:i:s') . "] Cron job voucher expiring: $notified_count notifications created\n";
    file_put_contents('./logs/notification_cron.log', $log_message, FILE_APPEND | LOCK_EX);
    
} catch (Exception $e) {
    echo "[" . date('Y-m-d H:i:s') . "] Lỗi: " . $e->getMessage() . "\n";
    
    // Log lỗi
    $error_message = "[" . date('Y-m-d H:i:s') . "] Cron job error: " . $e->getMessage() . "\n";
    file_put_contents('./logs/notification_cron.log', $error_message, FILE_APPEND | LOCK_EX);
}
?>
