<?php
/**
 * FCM Push Service
 * Service để gửi push notifications qua Firebase Cloud Messaging
 */

require_once './fcm_config.php';

class FCMPushService {
    private $serverKey;
    private $apiUrl;
    
    public function __construct() {
        $this->serverKey = getFCMServerKey();
        $this->apiUrl = getFCMApiUrl();
    }
    
    /**
     * Gửi push notification đến 1 user
     * Tự động lấy tất cả device tokens của user
     */
    public function sendToUser($conn, $user_id, $title, $body, $data = array(), $priority = 'high') {
        // Lấy tất cả device tokens active của user
        $query = "SELECT device_token, platform FROM device_tokens 
                  WHERE user_id = '$user_id' AND is_active = 1";
        $result = mysqli_query($conn, $query);
        
        if (!$result || mysqli_num_rows($result) == 0) {
            return array(
                'success' => false,
                'message' => 'User không có device token nào',
                'sent_count' => 0
            );
        }
        
        $tokens = array();
        while ($row = mysqli_fetch_assoc($result)) {
            $tokens[] = $row['device_token'];
        }
        
        return $this->sendToMultipleDevices($tokens, $title, $body, $data, $priority);
    }
    
    /**
     * Gửi push notification đến nhiều devices (tokens)
     */
    public function sendToMultipleDevices($tokens, $title, $body, $data = array(), $priority = 'high') {
        if (empty($tokens)) {
            return array(
                'success' => false,
                'message' => 'Không có device tokens',
                'sent_count' => 0
            );
        }
        
        // FCM hỗ trợ gửi đến tối đa 1000 devices/lần
        // Chvìa thành batches nếu có nhiều hơn 1000
        $batches = array_chunk($tokens, 1000);
        $totalSent = 0;
        $errors = array();
        
        foreach ($batches as $batch) {
            $result = $this->sendToDevicesBatch($batch, $title, $body, $data, $priority);
            
            if ($result['success']) {
                $totalSent += $result['sent_count'];
            } else {
                $errors[] = $result['message'];
            }
        }
        
        return array(
            'success' => $totalSent > 0,
            'sent_count' => $totalSent,
            'total_devices' => count($tokens),
            'errors' => $errors
        );
    }
    
    /**
     * Gửi đến 1 batch devices (tối đa 1000)
     */
    private function sendToDevicesBatch($tokens, $title, $body, $data = array(), $priority = 'high') {
        $notification = array(
            'title' => $title,
            'body' => $body,
            'sound' => 'default'
        );
        
        $payload = array(
            'registration_ids' => $tokens, // Gửi đến nhiều devices
            'notification' => $notification,
            'priority' => $priority,
        );
        
        // Thêm data nếu có
        if (!empty($data)) {
            $payload['data'] = $data;
        }
        
        $headers = array(
            'Authorization: key=' . $this->serverKey,
            'Content-Type: application/json'
        );
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $this->apiUrl);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
        
        if ($error) {
            return array(
                'success' => false,
                'message' => 'CURL Error: ' . $error,
                'sent_count' => 0
            );
        }
        
        if ($httpCode != 200) {
            return array(
                'success' => false,
                'message' => 'FCM API Error: HTTP ' . $httpCode . ' - ' . $response,
                'sent_count' => 0
            );
        }
        
        $pureResponse = json_decode($response, true);
        
        if (!$pureResponse) {
            return array(
                'success' => false,
                'message' => 'Invalid JSON response from FCM',
                'sent_count' => 0
            );
        }
        
        // Count thành công (success = 1)
        $successCount = 0;
        if (isset($pureResponse['results'])) {
            foreach ($pureResponse['results'] as $result) {
                if (isset($result['message_id'])) {
                    $successCount++;
                } else if (isset($result['error'])) {
                    // Handle invalid tokens
                    if (in_array($result['error'], ['InvalidRegistration', 'NotRegistered'])) {
                        // Có thể mark token as inactive ở đây
                    }
                }
            }
        }
        
        return array(
            'success' => $successCount > 0,
            'sent_count' => $successCount,
            'total_devices' => count($tokens),
            'response' => $pureResponse
        );
    }
    
    /**
     * Gửi push đến 1 device token cụ thể
     */
    public function sendToDevice($token, $title, $body, $data = array(), $priority = 'high') {
        return $this->sendToMultipleDevices(array($token), $title, $body, $data, $priority);
    }
    
    /**
     * Gửi push đến topic (ví dụ: 'all_users', 'promotions')
     */
    public function sendToTopic($topic, $title, $body, $data = array(), $priority = 'high') {
        $notification = array(
            'title' => $title,
            'body' => $body,
            'sound' => 'default'
        );
        
        $payload = array(
            'to' => '/topics/' . $topic,
            'notification' => $notification,
            'priority' => $priority,
        );
        
        if (!empty($data)) {
            $payload['data'] = $data;
        }
        
        $headers = array(
            'Authorization: key=' . $this->serverKey,
            'Content-Type: application/json'
        );
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $this->apiUrl);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
        
        if ($error || $httpCode != 200) {
            return array(
                'success' => false,
                'message' => $error ? $error : 'HTTP ' . $httpCode,
            );
        }
        
        return array(
            'success' => true,
            'message' => 'Sent to topic successfully',
        );
    }
}
?>

