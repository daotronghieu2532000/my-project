<?php
/**
 * Database-Based Queue Processor (Event-Driven)
 * 
 * Cách hoạt động:
 * - Monitor database để phát hiện notification mới (push_sent = 0)
 * - Chỉ check notification vừa được tạo (created_at gần đây)
 * - Event-driven: Chỉ chạy khi có notification mới
 * 
 * Ưu điểm so với cron polling:
 * - Chỉ check notification mới (created_at >= last_check_time)
 * - Không scan toàn bộ database
 * - Hiệu quả hơn nhiều
 * 
 * Cách chạy:
 * - Daemon: php notification_queue_processor_db.php --daemon
 * - Single: php notification_queue_processor_db.php
 */

// Load config.php - thử nhiều đường dẫn
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
    $config_path = __DIR__ . '/../../../../../includes/config.php';
}
if (!file_exists($config_path)) {
    $config_path = __DIR__ . '/includes/config.php';
}
require_once $config_path;

require_once __DIR__ . '/notification_mobile_helper.php';
require_once __DIR__ . '/fcm_push_service_v1.php';

$logPath = __DIR__ . '/debug_push_notifications.log';
$daemonMode = in_array('--daemon', $argv);
$checkInterval = 1; // Kiểm tra mỗi 1 giây (event-driven)
$maxProcessPerRun = 50;

// State file để lưu last_check_time
$stateFile = __DIR__ . '/.notification_queue_state';

/**
 * Lấy last_check_time từ state file
 */
function getLastCheckTime($stateFile) {
    if (file_exists($stateFile)) {
        $lastTime = intval(file_get_contents($stateFile));
        // Chỉ check notification trong vòng 5 phút qua (tránh miss notification cũ)
        return max($lastTime, time() - 300);
    }
    // Lần đầu: check notification trong vòng 1 phút qua
    return time() - 60;
}

/**
 * Lưu last_check_time vào state file
 */
function saveLastCheckTime($stateFile, $time) {
    file_put_contents($stateFile, $time);
}

/**
 * Xử lý notification
 */
function processNotification($notification_id, $conn, $logPath) {
    try {
        // Lấy notification
        $query = "SELECT id, user_id, type, title, content, data, related_id, related_type, priority, push_sent
                  FROM notification_mobile
                  WHERE id = $notification_id
                  LIMIT 1";
        
        $result = mysqli_query($conn, $query);
        
        if (!$result || mysqli_num_rows($result) == 0) {
            return false;
        }
        
        $row = mysqli_fetch_assoc($result);
        
        // Nếu đã gửi push rồi, bỏ qua
        if (intval($row['push_sent']) == 1) {
            return true;
        }
        
        // ✅ FIX RACE CONDITION: Update push_sent = 1 NGAY SAU KHI QUERY (trước khi xử lý)
        // Để tránh 2 instance cùng xử lý 1 notification
        // Dùng UPDATE với WHERE push_sent = 0 để đảm bảo chỉ update được 1 lần
        $lockQuery = "UPDATE notification_mobile SET push_sent = 1, updated_at = " . time() . " WHERE id = $notification_id AND push_sent = 0";
        $lockResult = mysqli_query($conn, $lockQuery);
        
        // Kiểm tra xem có update được không (affected_rows > 0)
        // Nếu không update được (affected_rows = 0) → notification đã được xử lý bởi instance khác
        if (!$lockResult || mysqli_affected_rows($conn) == 0) {
            file_put_contents($logPath, date('c') . " | [QUEUE_DB] ⚠️ Notification $notification_id already being processed by another instance\n", FILE_APPEND);
            return true; // Đã được xử lý bởi instance khác
        }
        
        $user_id = intval($row['user_id']);
        
        // Kiểm tra device token
        $checkTokenQuery = "SELECT COUNT(*) as count FROM device_tokens WHERE user_id = $user_id AND is_active = 1";
        $checkTokenResult = mysqli_query($conn, $checkTokenQuery);
        $hasToken = false;
        if ($checkTokenResult) {
            $tokenRow = mysqli_fetch_assoc($checkTokenResult);
            $hasToken = intval($tokenRow['count']) > 0;
        }
        
        if (!$hasToken) {
            // Đã update push_sent = 1 rồi, không cần update lại
            file_put_contents($logPath, date('c') . " | [QUEUE_DB] ⚠️ Notification $notification_id: user has no device token\n", FILE_APPEND);
            return false;
        }
        
        // Gửi push notification
        $notificationHelper = new NotificationMobileHelper($conn);
        $pushResult = $notificationHelper->sendPushForNotification($notification_id);
        
        // push_sent đã được update = 1 ở trên, không cần update lại
        
        file_put_contents($logPath, date('c') . " | [QUEUE_DB] ✅ Notification $notification_id sent successfully\n", FILE_APPEND);
        return true;
        
    } catch (Exception $e) {
        file_put_contents($logPath, date('c') . " | [QUEUE_DB] ❌ Exception processing notification $notification_id: " . $e->getMessage() . "\n", FILE_APPEND);
        return false;
    }
}

/**
 * Scan và xử lý notification mới
 */
function processQueue($conn, $logPath, $stateFile, $maxProcess) {
    $lastCheckTime = getLastCheckTime($stateFile);
    $currentTime = time();
    
    // ✅ FIX: Query TẤT CẢ notification với push_sent = 0 (không chỉ notification mới)
    // Để xử lý cả notification cũ (như voucher notification đã tạo trước đó)
    // Điều kiện: created_at >= (lastCheckTime - 1 ngày) để xử lý notification cũ trong vòng 24h
    $oneDayAgo = $currentTime - (24 * 3600);
    $minCreatedAt = min($lastCheckTime, $oneDayAgo); // Lấy thời điểm nhỏ hơn
    
    // Query notification chưa gửi push
    $query = "SELECT id, created_at, type, user_id, title
              FROM notification_mobile
              WHERE push_sent = 0
              AND created_at >= $minCreatedAt
              AND created_at <= $currentTime
              ORDER BY created_at ASC
              LIMIT $maxProcess";
    
    // Debug: Log query và số lượng notification
    $countQuery = "SELECT type, COUNT(*) as count_by_type
                   FROM notification_mobile
                   WHERE push_sent = 0
                   AND created_at >= $minCreatedAt
                   AND created_at <= $currentTime
                   GROUP BY type";
    $countResult = mysqli_query($conn, $countQuery);
    if ($countResult) {
        $totalPending = 0;
        while ($countRow = mysqli_fetch_assoc($countResult)) {
            $totalPending += intval($countRow['count_by_type']);
            if ($countRow['type'] == 'voucher_new' || $countRow['type'] == 'affiliate_product') {
                file_put_contents($logPath, date('c') . " | [QUEUE_DB] Found {$countRow['count_by_type']} {$countRow['type']} notification(s) to process\n", FILE_APPEND);
            }
        }
        if ($totalPending > 0) {
            file_put_contents($logPath, date('c') . " | [QUEUE_DB] Total pending notifications: $totalPending (min_created_at=$minCreatedAt, last_check_time=$lastCheckTime)\n", FILE_APPEND);
        }
    }
    
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        file_put_contents($logPath, date('c') . " | [QUEUE_DB] Query failed: " . mysqli_error($conn) . "\n", FILE_APPEND);
        return 0;
    }
    
    $totalRows = mysqli_num_rows($result);
    if ($totalRows > 0) {
        file_put_contents($logPath, date('c') . " | [QUEUE_DB] Query returned $totalRows notification(s), min_created_at=$minCreatedAt, last_check_time=$lastCheckTime, current_time=$currentTime\n", FILE_APPEND);
    }
    
    $processed = 0;
    $maxCreatedAt = $lastCheckTime;
    
    while ($row = mysqli_fetch_assoc($result)) {
        $notification_id = intval($row['id']);
        $created_at = intval($row['created_at']);
        $notification_type = $row['type'] ?? 'unknown';
        $user_id = intval($row['user_id'] ?? 0);
        $title = $row['title'] ?? '';
        
        // Debug logging cho voucher và affiliate
        if ($notification_type == 'voucher_new' || $notification_type == 'affiliate_product') {
            file_put_contents($logPath, date('c') . " | [QUEUE_DB] Processing $notification_type notification: id=$notification_id, user_id=$user_id, title=$title\n", FILE_APPEND);
        }
        
        if (processNotification($notification_id, $conn, $logPath)) {
            $processed++;
        }
        
        // Update max created_at để lần sau chỉ check notification mới hơn
        if ($created_at > $maxCreatedAt) {
            $maxCreatedAt = $created_at;
        }
    }
    
    // Lưu last_check_time = max created_at (hoặc current_time nếu không có notification mới)
    saveLastCheckTime($stateFile, $maxCreatedAt > $lastCheckTime ? $maxCreatedAt : $currentTime);
    
    return $processed;
}

// Daemon mode
if ($daemonMode) {
    file_put_contents($logPath, date('c') . " | [QUEUE_DB] Starting daemon mode (event-driven)\n", FILE_APPEND);
    
    while (true) {
        $processed = processQueue($conn, $logPath, $stateFile, $maxProcessPerRun);
        
        if ($processed > 0) {
            file_put_contents($logPath, date('c') . " | [QUEUE_DB] Processed $processed notification(s)\n", FILE_APPEND);
        }
        
        // Chỉ sleep 1 giây (event-driven, check thường xuyên)
        sleep($checkInterval);
    }
} else {
    // Single run mode
    file_put_contents($logPath, date('c') . " | [QUEUE_DB] Starting single run mode\n", FILE_APPEND);
    $processed = processQueue($conn, $logPath, $stateFile, $maxProcessPerRun);
    file_put_contents($logPath, date('c') . " | [QUEUE_DB] Completed: processed $processed notification(s)\n", FILE_APPEND);
}

