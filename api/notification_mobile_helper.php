<?php
/**
 * Notification Helper cho Mobile App
 * Tự động tạo thông báo cho các sự kiện trong hệ thống
 */

class NotificationMobileHelper {
    private $conn;
    private $useRedisQueue = false; // Flag để bật/tắt Redis queue
    
    public function __construct($connection, $useRedisQueue = false) {
        $this->conn = $connection;
        $this->useRedisQueue = $useRedisQueue;
    }
    
    /**
     * Tạo thông báo mới
     */
    public function createNotification($user_id, $type, $title, $content, $data = null, $related_id = null, $related_type = null, $priority = 'medium') {
        $user_id = intval($user_id);
        $type = addslashes(trim($type));
        $title = addslashes(trim($title));
        $content = addslashes(trim($content));
        $priority = addslashes(trim($priority));
        $related_id = $related_id ? intval($related_id) : 'NULL';
        $related_type = $related_type ? "'" . addslashes(trim($related_type)) . "'" : 'NULL';
        $data_json = $data ? "'" . addslashes(json_encode($data)) . "'" : 'NULL';
        $current_time = time();
        
        $query = "INSERT INTO notification_mobile (user_id, type, title, content, data, related_id, related_type, priority, is_read, created_at) 
                  VALUES ('$user_id', '$type', '$title', '$content', $data_json, $related_id, $related_type, '$priority', 0, '$current_time')";
        
        $result = mysqli_query($this->conn, $query);
        
        // Gửi push notification nếu tạo notification thành công
        if ($result) {
            $notification_id = mysqli_insert_id($this->conn);
            
            // Nếu dùng Redis queue, push vào queue thay vì gửi trực tiếp
            if ($this->useRedisQueue) {
                $this->pushToRedisQueue($notification_id, $user_id, $type, $title, $content, $data, $priority);
            } else {
                // Gửi trực tiếp (backward compatibility)
                $this->sendPushNotification($user_id, $title, $content, $data, $related_id, $related_type);
            }
        }
        
        return $result;
    }
    
    /**
     * Gửi push notification sau khi tạo notification trong DB
     * Protected để có thể gọi từ sendPushForExistingNotification
     */
    protected function sendPushNotification($user_id, $title, $body, $data = null, $related_id = null, $related_type = null) {
        try {
            // Dùng FCM HTTP V1 API (an toàn: chỉ include khi tồn tại đủ file cấu hình)
            $svcFile = __DIR__ . '/fcm_push_service_v1.php';
            $cfgFile = __DIR__ . '/fcm_config.php';
            if (!file_exists($svcFile) || !file_exists($cfgFile)) {
                // Ghi log và bỏ qua push, không làm gián đoạn đơn hàng
                $logPath = __DIR__ . '/debug_push_notifications.log';
                $miss = [];
                if (!file_exists($svcFile)) $miss[] = 'fcm_push_service_v1.php';
                if (!file_exists($cfgFile)) $miss[] = 'fcm_config.php';
                file_put_contents($logPath, date('c') . ' | MISSING: ' . implode(',', $miss) . "\n", FILE_APPEND);
                return false;
            }
            require_once $svcFile;
            $fcmService = new FCMPushServiceV1();
            
            // Prepare data payload
            // Ưu tiên dùng 'type' từ $data (đã được set từ notification_mobile.type)
            // Nếu không có, fallback về $related_type
            $dataPayload = array();
            
            // Nếu $data đã có 'type', dùng nó (đã được set từ notification_mobile.type)
            if ($data && is_array($data) && isset($data['type'])) {
                $dataPayload['type'] = $data['type'];
            } else {
                // Fallback: dùng related_type hoặc 'general'
                $dataPayload['type'] = $related_type ? $related_type : 'general';
            }
            
            if ($related_id) {
                $dataPayload['related_id'] = (string)$related_id;
            }
            
            // Merge tất cả data vào payload (bao gồm cả type nếu đã có)
            if ($data && is_array($data)) {
                $dataPayload = array_merge($dataPayload, $data);
            }
            
            // Convert array values to strings (FCM requirement)
            foreach ($dataPayload as $key => $value) {
                if (!is_string($value)) {
                    $dataPayload[$key] = json_encode($value);
                }
            }
            
            // Send push
            $result = $fcmService->sendToUser(
                $this->conn,
                $user_id,
                $title,
                $body,
                $dataPayload,
                'high'
            );
            
            // Log to custom file for FTP access
            $logPath = '/home/api.socdo.vn/public_html/home/themes/socdo/action/process' . '/debug_push_notifications.log';
            $logMsg = date('c') . " | user_id={$user_id} | title={$title} | result: " . print_r($result, true) . "\n";
            file_put_contents($logPath, $logMsg, FILE_APPEND);
            
            if ($result['success']) {
                // Log success (optional)
                error_log("Push notification sent to user $user_id: {$result['sent_count']} device(s)");
            } else {
                // Log error (optional)
                error_log("Failed to send push notification to user $user_id: " . ($result['message'] ?? 'Unknown error'));
            }
        } catch (Exception $e) {
            // Log exception to the same debug file
            $logPath = __DIR__ . '/debug_push_notifications.log';
            $logMsg = date('c') . " | user_id={$user_id} | title={$title} | EXCEPTION: {$e->getMessage()}\n";
            file_put_contents($logPath, $logMsg, FILE_APPEND);
            // Không làm gián đoạn flow nếu push thất bại
            error_log("Error sending push notification: " . $e->getMessage());
        }
    }
    
    /**
     * Thông báo đơn hàng mới
     */
    public function notifyNewOrder($user_id, $order_id, $order_code, $total_amount) {
        $title = "Đơn hàng mới #$order_code";
        $content = "Bạn vừa đặt đơn hàng #$order_code với tổng giá trị " . number_format($total_amount) . "₫. Đơn hàng đang được xử lý.";
        
        $data = array(
            'order_id' => $order_id,
            'order_code' => $order_code,
            'total_amount' => $total_amount
        );
        
        return $this->createNotification($user_id, 'order', $title, $content, $data, $order_id, 'order', 'high');
    }
    
    /**
     * Push notification vào Redis queue
     */
    private function pushToRedisQueue($notification_id, $user_id, $type, $title, $content, $data, $priority = 'medium') {
        try {
            require_once __DIR__ . '/notification_queue_producer.php';
            $producer = new NotificationQueueProducer($this->conn);
            $producer->pushNotification($notification_id);
        } catch (Exception $e) {
            // Fallback: Gửi trực tiếp nếu queue fail
            $logPath = __DIR__ . '/debug_push_notifications.log';
            file_put_contents($logPath, date('c') . " | [REDIS_QUEUE] ❌ Failed to push to queue, fallback to direct send: " . $e->getMessage() . "\n", FILE_APPEND);
            $this->sendPushNotification($user_id, $title, $content, $data, null, null);
        }
    }
    
    /**
     * Gửi push notification cho notification đã tồn tại (public wrapper)
     * Dùng cho cron job và async job
     */
    public function sendPushForNotification($notification_id) {
        $logPath = __DIR__ . '/debug_push_notifications.log';
        try {
            file_put_contents($logPath, date('c') . " | [sendPushForNotification] Started: notification_id=$notification_id\n", FILE_APPEND);
            
            // Lấy notification (bao gồm type từ notification_mobile table)
            $query = "SELECT user_id, type, title, content, data, related_id, related_type 
                     FROM notification_mobile 
                     WHERE id = '$notification_id' 
                     LIMIT 1";
            
            $result = mysqli_query($this->conn, $query);
            
            if (!$result || mysqli_num_rows($result) == 0) {
                file_put_contents($logPath, date('c') . " | [sendPushForNotification] Notification not found: $notification_id\n", FILE_APPEND);
                return false;
            }
            
            $row = mysqli_fetch_assoc($result);
            $user_id = intval($row['user_id']);
            $notification_type = $row['type']; // Lấy type từ notification_mobile table
            $title = $row['title'];
            $content = $row['content'];
            $data = json_decode($row['data'], true);
            $related_id = $row['related_id'] ? intval($row['related_id']) : null;
            $related_type = $row['related_type'] ? $row['related_type'] : null;
            
            // Đảm bảo data là array
            if (!is_array($data)) {
                $data = array();
            }
            
            // Thêm type vào data payload (quan trọng để app biết loại notification)
            $data['type'] = $notification_type;
            
            // Gọi sendPushNotification (protected method)
            $this->sendPushNotification($user_id, $title, $content, $data, $related_id, $related_type);
            
            file_put_contents($logPath, date('c') . " | [sendPushForNotification] Completed: notification_id=$notification_id\n", FILE_APPEND);
            return true;
        } catch (Exception $e) {
            file_put_contents($logPath, date('c') . " | [sendPushForNotification] EXCEPTION: " . $e->getMessage() . "\n", FILE_APPEND);
            return false;
        }
    }
    
    /**
     * Chỉ gửi push notification cho notification đã tồn tại (không tạo notification mới)
     * Dùng cho async job sau khi notification đã được tạo
     */
    public function sendPushForExistingNotification($user_id, $related_id, $related_type = 'order') {
        $logPath = __DIR__ . '/debug_push_notifications.log';
        try {
            file_put_contents($logPath, date('c') . " | [sendPushForExisting] Started: user_id=$user_id, related_id=$related_id, type=$related_type\n", FILE_APPEND);
            
            // Lấy notification đã tồn tại
            $query = "SELECT title, content, data FROM notification_mobile 
                     WHERE user_id = '$user_id' 
                     AND related_id = '$related_id' 
                     AND related_type = '$related_type' 
                     ORDER BY created_at DESC LIMIT 1";
            
            file_put_contents($logPath, date('c') . " | [sendPushForExisting] Query: $query\n", FILE_APPEND);
            
            $result = mysqli_query($this->conn, $query);
            
            if (!$result) {
                file_put_contents($logPath, date('c') . " | [sendPushForExisting] Query failed: " . mysqli_error($this->conn) . "\n", FILE_APPEND);
                return false;
            }
            
            $numRows = mysqli_num_rows($result);
            file_put_contents($logPath, date('c') . " | [sendPushForExisting] Found $numRows notification(s)\n", FILE_APPEND);
            
            if ($numRows > 0) {
                $row = mysqli_fetch_assoc($result);
                $title = $row['title'];
                $content = $row['content'];
                $data = json_decode($row['data'], true);
                
                file_put_contents($logPath, date('c') . " | [sendPushForExisting] Notification found - title: $title\n", FILE_APPEND);
                file_put_contents($logPath, date('c') . " | [sendPushForExisting] Calling sendPushNotification()...\n", FILE_APPEND);
                
                // Gọi sendPushNotification trực tiếp
                $this->sendPushNotification($user_id, $title, $content, $data, $related_id, $related_type);
                
                file_put_contents($logPath, date('c') . " | [sendPushForExisting] sendPushNotification() completed\n", FILE_APPEND);
                return true;
            } else {
                file_put_contents($logPath, date('c') . " | [sendPushForExisting] No notification found in DB\n", FILE_APPEND);
            }
            return false;
        } catch (Exception $e) {
            $errorMsg = date('c') . " | [sendPushForExisting] EXCEPTION: " . $e->getMessage() . "\n";
            $errorMsg .= date('c') . " | [sendPushForExisting] STACK: " . $e->getTraceAsString() . "\n";
            file_put_contents($logPath, $errorMsg, FILE_APPEND);
            error_log("Error sending push for existing notification: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Thông báo thay đổi trạng thái đơn hàng
     */
    public function notifyOrderStatusChange($user_id, $order_id, $order_code, $old_status, $new_status) {
        $status_names = array(
            0 => 'Chờ xác nhận',
            1 => 'Đã xác nhận',
            2 => 'Đang giao hàng',
            3 => 'Đã giao hàng',
            4 => 'Đã hủy',
            5 => 'Hoàn trả'
        );
        
        $old_status_name = isset($status_names[$old_status]) ? $status_names[$old_status] : 'Không xác định';
        $new_status_name = isset($status_names[$new_status]) ? $status_names[$new_status] : 'Không xác định';
        
        $title = "Cập nhật đơn hàng #$order_code";
        $content = "Đơn hàng #$order_code đã chuyển từ '$old_status_name' sang '$new_status_name'.";
        
        $data = array(
            'order_id' => $order_id,
            'order_code' => $order_code,
            'old_status' => $old_status,
            'new_status' => $new_status,
            'old_status_name' => $old_status_name,
            'new_status_name' => $new_status_name
        );
        
        $priority = ($new_status == 2) ? 'high' : 'medium'; // Đang giao hàng = high priority
        
        return $this->createNotification($user_id, 'order', $title, $content, $data, $order_id, 'order', $priority);
    }
    
    /**
     * Thông báo đơn hàng affiliate mới
     */
    public function notifyNewAffiliateOrder($user_id, $order_id, $order_code, $commission_amount) {
        $title = "Đơn hàng Affiliate mới #$order_code";
        $content = "Bạn có đơn hàng affiliate #$order_code với hoa hồng " . number_format($commission_amount) . "₫.";
        
        $data = array(
            'order_id' => $order_id,
            'order_code' => $order_code,
            'commission_amount' => $commission_amount
        );
        
        return $this->createNotification($user_id, 'affiliate_order', $title, $content, $data, $order_id, 'affiliate_order', 'high');
    }
    
    /**
     * Thông báo nạp tiền
     */
    public function notifyDeposit($user_id, $amount, $method = 'Chuyển khoản') {
        $title = "Nạp tiền thành công";
        $content = "Bạn đã nạp " . number_format($amount) . "₫ vào tài khoản qua $method.";
        
        $data = array(
            'amount' => $amount,
            'method' => $method,
            'transaction_type' => 'deposit'
        );
        
        return $this->createNotification($user_id, 'deposit', $title, $content, $data, null, null, 'medium');
    }
    
    /**
     * Thông báo rút tiền
     */
    public function notifyWithdrawal($user_id, $amount, $status = 'pending', $method = 'Chuyển khoản') {
        $status_names = array(
            'pending' => 'Chờ duyệt',
            'approved' => 'Đã duyệt',
            'rejected' => 'Từ chối',
            'completed' => 'Hoàn thành'
        );
        
        $status_name = isset($status_names[$status]) ? $status_names[$status] : $status;
        
        $title = "Yêu cầu rút tiền " . $status_name;
        $content = "Yêu cầu rút " . number_format($amount) . "₫ qua $method đã được $status_name.";
        
        $data = array(
            'amount' => $amount,
            'status' => $status,
            'status_name' => $status_name,
            'method' => $method,
            'transaction_type' => 'withdrawal'
        );
        
        $priority = ($status == 'rejected') ? 'high' : 'medium';
        
        return $this->createNotification($user_id, 'withdrawal', $title, $content, $data, null, null, $priority);
    }
    
    /**
     * Thông báo voucher mới
     */
    public function notifyNewVoucher($user_id, $voucher_code, $discount_amount, $expired_date) {
        $title = "Voucher mới: $voucher_code";
        $content = "Bạn có voucher mới $voucher_code giảm " . number_format($discount_amount) . "₫. Hạn sử dụng đến " . date('d/m/Y', $expired_date) . ".";
        
        $data = array(
            'voucher_code' => $voucher_code,
            'discount_amount' => $discount_amount,
            'expired_date' => $expired_date
        );
        
        return $this->createNotification($user_id, 'voucher_new', $title, $content, $data, null, 'coupon', 'medium');
    }
    
    /**
     * Thông báo voucher sắp hết hạn
     */
    public function notifyVoucherExpiring($user_id, $voucher_code, $discount_amount, $expired_date) {
        $title = "Voucher sắp hết hạn: $voucher_code";
        $content = "Voucher $voucher_code giảm " . number_format($discount_amount) . "₫ sẽ hết hạn vào " . date('d/m/Y H:i', $expired_date) . ". Hãy sử dụng ngay!";
        
        $data = array(
            'voucher_code' => $voucher_code,
            'discount_amount' => $discount_amount,
            'expired_date' => $expired_date,
            'hours_left' => ceil(($expired_date - time()) / 3600)
        );
        
        return $this->createNotification($user_id, 'voucher_expiring', $title, $content, $data, null, 'coupon', 'high');
    }
    
    /**
     * Kiểm tra và tạo thông báo voucher sắp hết hạn (chạy cron job)
     */
    public function checkExpiringVouchers() {
        $current_time = time();
        $one_day_later = $current_time + (24 * 3600); // 1 ngày sau
        
        // Lấy danh sách voucher sắp hết hạn trong 24h
        $query = "SELECT c.*, u.user_id 
                  FROM coupon c 
                  JOIN user_info u ON c.shop = u.shop 
                  WHERE c.expired > '$current_time' 
                  AND c.expired <= '$one_day_later' 
                  AND c.status = 1";
        
        $result = mysqli_query($this->conn, $query);
        
        $notified_count = 0;
        while ($row = mysqli_fetch_assoc($result)) {
            // Kiểm tra xem đã thông báo chưa
            $check_query = "SELECT id FROM notification_mobile 
                           WHERE user_id = '{$row['user_id']}' 
                           AND type = 'voucher_expiring' 
                           AND related_id IS NULL 
                           AND data LIKE '%\"voucher_code\":\"{$row['ma']}\"%'
                           AND created_at > " . ($current_time - 3600); // Trong 1 giờ qua
            
            $check_result = mysqli_query($this->conn, $check_query);
            
            if (mysqli_num_rows($check_result) == 0) {
                $this->notifyVoucherExpiring(
                    $row['user_id'], 
                    $row['ma'], 
                    $row['giam'], 
                    $row['expired']
                );
                $notified_count++;
            }
        }
        
        return $notified_count;
    }
    
    /**
     * Lấy số lượng thông báo chưa đọc
     */
    public function getUnreadCount($user_id, $type = null) {
        $user_id = intval($user_id);
        $where_clause = "user_id = '$user_id' AND is_read = 0";
        
        if ($type) {
            $type = addslashes(trim($type));
            $where_clause .= " AND type = '$type'";
        }
        
        $query = "SELECT COUNT(*) as count FROM notification_mobile WHERE $where_clause";
        $result = mysqli_query($this->conn, $query);
        
        if ($result) {
            $row = mysqli_fetch_assoc($result);
            return intval($row['count']);
        }
        
        return 0;
    }
}

// Sử dụng:
// $notificationHelper = new NotificationMobileHelper($conn);
// $notificationHelper->notifyNewOrder($user_id, $order_id, $order_code, $total_amount);
// No closing tag to avoid stray output
