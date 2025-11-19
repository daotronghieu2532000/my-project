<?php
/**
 * Notification Worker (Redis Queue Consumer)
 * 
 * Chạy như daemon để xử lý notification queue
 * 
 * Usage:
 *   php notification_worker_redis.php --daemon    # Chạy liên tục
 *   php notification_worker_redis.php            # Chạy 1 lần
 */

// Load config
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
    $config_path = __DIR__ . '/../../../../../includes/config.php';
}
if (!file_exists($config_path)) {
    $config_path = __DIR__ . '/includes/config.php';
}
require_once $config_path;

require_once __DIR__ . '/redis_queue_service.php';

$logPath = __DIR__ . '/debug_push_notifications.log';
$daemonMode = in_array('--daemon', $argv);
$checkInterval = 1; // Check mỗi 1 giây
$maxProcessPerRun = 50;

// Initialize queue service
$queueService = new RedisQueueService($conn);

if ($daemonMode) {
    file_put_contents($logPath, date('c') . " | [REDIS_WORKER] Starting daemon mode\n", FILE_APPEND);
    
    while (true) {
        $processed = 0;
        
        // Process jobs
        for ($i = 0; $i < $maxProcessPerRun; $i++) {
            $job = $queueService->popNotification();
            
            if (!$job) {
                break; // No more jobs
            }
            
            if ($queueService->processJob($job)) {
                $processed++;
            }
        }
        
        if ($processed > 0) {
            file_put_contents($logPath, date('c') . " | [REDIS_WORKER] Processed $processed job(s)\n", FILE_APPEND);
        }
        
        // Sleep before next check
        sleep($checkInterval);
    }
} else {
    // Single run mode
    file_put_contents($logPath, date('c') . " | [REDIS_WORKER] Starting single run mode\n", FILE_APPEND);
    
    $processed = 0;
    for ($i = 0; $i < $maxProcessPerRun; $i++) {
        $job = $queueService->popNotification();
        
        if (!$job) {
            break;
        }
        
        if ($queueService->processJob($job)) {
            $processed++;
        }
    }
    
    file_put_contents($logPath, date('c') . " | [REDIS_WORKER] Completed: processed $processed job(s)\n", FILE_APPEND);
    
    // Print stats
    $stats = $queueService->getStats();
    file_put_contents($logPath, date('c') . " | [REDIS_WORKER] Stats: " . json_encode($stats) . "\n", FILE_APPEND);
}

