<?php
/**
 * Notification Queue Producer
 * 
 * Push notification vào Redis queue thay vì gửi trực tiếp
 * 
 * Usage:
 *   require_once 'notification_queue_producer.php';
 *   $producer = new NotificationQueueProducer($conn);
 *   $producer->pushNotification($notification_id);
 */

require_once __DIR__ . '/redis_queue_service.php';

class NotificationQueueProducer {
    private $queueService;
    private $conn;
    
    public function __construct($connection) {
        $this->conn = $connection;
        $this->queueService = new RedisQueueService($connection);
    }
    
    /**
     * Push notification vào queue từ notification_id
     * 
     * @param int $notification_id
     * @param int $delay (optional) - Delay in seconds
     * @return bool
     */
    public function pushNotification($notification_id, $delay = 0) {
        // Lấy thông tin notification từ database
        $query = "SELECT id, user_id, type, title, content, data, related_id, related_type, priority
                  FROM notification_mobile
                  WHERE id = " . intval($notification_id) . "
                  LIMIT 1";
        
        $result = mysqli_query($this->conn, $query);
        if (!$result || mysqli_num_rows($result) == 0) {
            return false;
        }
        
        $row = mysqli_fetch_assoc($result);
        
        // Parse data JSON
        $data = null;
        if (!empty($row['data'])) {
            $data = json_decode($row['data'], true);
        }
        
        // Push vào queue
        return $this->queueService->pushNotification([
            'notification_id' => intval($row['id']),
            'user_id' => intval($row['user_id']),
            'type' => $row['type'] ?? 'unknown',
            'title' => $row['title'] ?? '',
            'content' => $row['content'] ?? '',
            'data' => $data,
            'priority' => $row['priority'] ?? 'medium',
            'delay' => $delay,
        ]);
    }
    
    /**
     * Push notification trực tiếp từ data
     * 
     * @param array $notificationData
     * @return bool
     */
    public function pushNotificationData($notificationData) {
        return $this->queueService->pushNotification($notificationData);
    }
}

