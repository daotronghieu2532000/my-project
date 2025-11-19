<?php
/**
 * Cron Job: Gửi push notification cho các notification chưa được gửi
 * 
 * Chạy định kỳ (ví dụ: mỗi 1-2 phút) để kiểm tra và gửi push cho:
 * - Notification từ trigger (status change, deposit, withdrawal, voucher, affiliate)
 * - Notification từ các nguồn khác chưa được gửi push
 * 
 * Cách chạy:
 * - Crontab: */1 * * * * php /path/to/send_pending_push_notifications.php
 
 */

header('Content-Type: text/plain; charset=utf-8');
ignore_user_abort(true);
set_time_limit(60); // Tối đa 60 giây

require_once __DIR__ . '/includes/config.php';
require_once __DIR__ . '/notification_mobile_helper.php';
require_once __DIR__ . '/fcm_push_service_v1.php';

$logPath = __DIR__ . '/debug_push_notifications.log';
$maxProcessPerRun = 50; // Tối đa 50 notification mỗi lần chạy

try {
    file_put_contents($logPath, date('c') . " | [CRON] Starting send_pending_push_notifications.php\n", FILE_APPEND);
    
    // Kiểm tra file cần thiết
    $notification_file = __DIR__ . '/notification_mobile_helper.php';
    $fcm_cfg = __DIR__ . '/fcm_config.php';
    $fcm_svc = __DIR__ . '/fcm_push_service_v1.php';
    
    if (!file_exists($notification_file) || !file_exists($fcm_cfg) || !file_exists($fcm_svc)) {
        $missing = array();
        if (!file_exists($notification_file)) $missing[] = 'notification_mobile_helper.php';
        if (!file_exists($fcm_cfg)) $missing[] = 'fcm_config.php';
        if (!file_exists($fcm_svc)) $missing[] = 'fcm_push_service_v1.php';
        file_put_contents($logPath, date('c') . " | [CRON] MISSING FILES: " . implode(', ', $missing) . "\n", FILE_APPEND);
        exit(1);
    }
    
    // Lấy các notification chưa gửi push (push_sent = 0)
    // Chỉ lấy notification trong vòng 24h qua (tránh gửi lại notification cũ)
    $current_time = time();
    $one_day_ago = $current_time - (24 * 3600);
    
    $query = "SELECT id, user_id, type, title, content, data, related_id, related_type, priority, created_at
              FROM notification_mobile
              WHERE push_sent = 0
              AND created_at >= $one_day_ago
              ORDER BY created_at ASC
              LIMIT $maxProcessPerRun";
    
    file_put_contents($logPath, date('c') . " | [CRON] Query: $query\n", FILE_APPEND);
    
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        file_put_contents($logPath, date('c') . " | [CRON] Query failed: " . mysqli_error($conn) . "\n", FILE_APPEND);
        exit(1);
    }
    
    $totalFound = mysqli_num_rows($result);
    file_put_contents($logPath, date('c') . " | [CRON] Found $totalFound notification(s) to process\n", FILE_APPEND);
    
    if ($totalFound == 0) {
        file_put_contents($logPath, date('c') . " | [CRON] No pending notifications, exiting\n", FILE_APPEND);
        exit(0);
    }
    
    $notificationHelper = new NotificationMobileHelper($conn);
    $processed = 0;
    $success = 0;
    $failed = 0;
    
    while ($row = mysqli_fetch_assoc($result)) {
        $processed++;
        $notification_id = intval($row['id']);
        $user_id = intval($row['user_id']);
        $title = $row['title'];
        $content = $row['content'];
        $data = json_decode($row['data'], true);
        $related_id = $row['related_id'] ? intval($row['related_id']) : null;
        $related_type = $row['related_type'] ? $row['related_type'] : null;
        
        file_put_contents($logPath, date('c') . " | [CRON] Processing notification_id=$notification_id, user_id=$user_id, type={$row['type']}\n", FILE_APPEND);
        
        try {
            // Kiểm tra xem có device token không (nếu không có thì không thể gửi)
            $checkTokenQuery = "SELECT COUNT(*) as count FROM device_tokens WHERE user_id = $user_id AND is_active = 1";
            $checkTokenResult = mysqli_query($conn, $checkTokenQuery);
            $hasToken = false;
            if ($checkTokenResult) {
                $tokenRow = mysqli_fetch_assoc($checkTokenResult);
                $hasToken = intval($tokenRow['count']) > 0;
            }
            
            if (!$hasToken) {
                // Không có device token → không thể gửi push
                // Đánh dấu push_sent = 1 để không check lại
                $updateQuery = "UPDATE notification_mobile SET push_sent = 1, updated_at = $current_time WHERE id = $notification_id";
                mysqli_query($conn, $updateQuery);
                
                file_put_contents($logPath, date('c') . " | [CRON] ⚠️ Notification $notification_id: No device token for user $user_id, skipping\n", FILE_APPEND);
                $failed++;
                continue;
            }
            
            // Có device token → gửi push notification
            // Sử dụng method sendPushForNotification để gửi push cho notification đã tồn tại
            $pushResult = $notificationHelper->sendPushForNotification($notification_id);
            
            // Update push_sent = 1 sau khi đã gọi sendPushNotification
            // (sendPushNotification() sẽ tự xử lý việc gửi, kể cả khi fail)
            $updateQuery = "UPDATE notification_mobile SET push_sent = 1, updated_at = $current_time WHERE id = $notification_id";
            $updateResult = mysqli_query($conn, $updateQuery);
            
            if ($updateResult) {
                $success++;
                file_put_contents($logPath, date('c') . " | [CRON] ✅ Notification $notification_id sent successfully\n", FILE_APPEND);
            } else {
                file_put_contents($logPath, date('c') . " | [CRON] ❌ Failed to update push_sent for notification $notification_id: " . mysqli_error($conn) . "\n", FILE_APPEND);
                $failed++;
            }
            
        } catch (Exception $e) {
            $failed++;
            file_put_contents($logPath, date('c') . " | [CRON] ❌ Exception processing notification $notification_id: " . $e->getMessage() . "\n", FILE_APPEND);
            
            // Vẫn update push_sent = 1 để tránh retry vô hạn (hoặc có thể để = 0 để retry)
            // Ở đây ta sẽ để = 1 để tránh spam
            $updateQuery = "UPDATE notification_mobile SET push_sent = 1, updated_at = $current_time WHERE id = $notification_id";
            mysqli_query($conn, $updateQuery);
        }
    }
    
    file_put_contents($logPath, date('c') . " | [CRON] Completed: processed=$processed, success=$success, failed=$failed\n", FILE_APPEND);
    
} catch (Exception $e) {
    file_put_contents($logPath, date('c') . " | [CRON] FATAL ERROR: " . $e->getMessage() . "\n" . $e->getTraceAsString() . "\n", FILE_APPEND);
    exit(1);
}

exit(0);

