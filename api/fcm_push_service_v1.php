<?php
/**
 * FCM Push Service - HTTP V1 API
 * Sử dụng Service Account JSON để authenticate
 * 
 * Thay thế cho fcm_push_service.php (Legacy API)
 */

// Dùng __DIR__ để đảm bảo tìm đúng file config khi được require từ bất kỳ đâu
$fcmConfigPath = __DIR__ . '/fcm_config.php';
if (!file_exists($fcmConfigPath)) {
    throw new Exception('FCM config file not found: ' . $fcmConfigPath);
}
require_once $fcmConfigPath;

class FCMPushServiceV1 {
    private $serviceAccountData;
    private $projectId;
    private $apiUrl;
    private $accessTokenCache = null;
    private $accessTokenExpiry = 0;
    private $conn = null; // Lưu connection để dùng trong deactivateUnregisteredTokens
    
    public function __construct() {
        $this->serviceAccountData = getFCMServiceAccountData();
        $this->projectId = getFCMProjectId();
        $this->apiUrl = getFCMApiUrl();
        
        // Debug logging
        $logPath = dirname(__FILE__) . '/debug_push_notifications.log';
        file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] Constructor - apiUrl: " . ($this->apiUrl ?: 'EMPTY') . "\n", FILE_APPEND);
        file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] Constructor - projectId: " . ($this->projectId ?: 'EMPTY') . "\n", FILE_APPEND);
    }
    
    /**
     * Lấy Access Token từ Service Account (sử dụng JWT)
     * Access token có thời hạn 1 giờ
     */
    private function getAccessToken() {
        // Sử dụng cache nếu token chưa hết hạn
        if ($this->accessTokenCache && time() < $this->accessTokenExpiry) {
            return $this->accessTokenCache;
        }
        
        // Tạo JWT để request access token
        $now = time();
        $jwtHeader = array(
            'alg' => 'RS256',
            'typ' => 'JWT'
        );
        
        $jwtPayload = array(
            'iss' => $this->serviceAccountData['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'exp' => $now + 3600, // 1 hour
            'iat' => $now
        );
        
        // Sign JWT với private key sử dụng OpenSSL
        // JWT library có sẵn không hỗ trợ RS256, nên dùng OpenSSL trực tiếp
        $privateKeyString = $this->serviceAccountData['private_key'];
        
        // Parse private key từ PEM string
        $privateKeyResource = openssl_pkey_get_private($privateKeyString);
        if (!$privateKeyResource) {
            throw new Exception('Invalid private key: ' . openssl_error_string());
        }
        
        // Encode header và payload (base64url)
        $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode(json_encode($jwtHeader)));
        $base64UrlPayload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode(json_encode($jwtPayload)));
        
        // Create signature với RS256
        $dataToSign = $base64UrlHeader . '.' . $base64UrlPayload;
        $signature = '';
        $success = openssl_sign($dataToSign, $signature, $privateKeyResource, OPENSSL_ALGO_SHA256);
        openssl_free_key($privateKeyResource);
        
        if (!$success) {
            throw new Exception('Failed to sign JWT: ' . openssl_error_string());
        }
        
        $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
        
        // Create JWT
        $jwt = $base64UrlHeader . '.' . $base64UrlPayload . '.' . $base64UrlSignature;
        
        // Request access token
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, 'https://oauth2.googleapis.com/token');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query(array(
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt
        )));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/x-www-form-urlencoded'));
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode != 200) {
            throw new Exception('Failed to get access token: HTTP ' . $httpCode . ' - ' . $response);
        }
        
        $tokenData = json_decode($response, true);
        if (!isset($tokenData['access_token'])) {
            throw new Exception('Invalid token response: ' . $response);
        }
        
        // Cache token
        $this->accessTokenCache = $tokenData['access_token'];
        $this->accessTokenExpiry = $now + intval($tokenData['expires_in']) - 60; // Trừ 60s để đảm bảo
        
        return $this->accessTokenCache;
    }
    
    /**
     * Gửi push notification đến 1 user
     */
    public function sendToUser($conn, $user_id, $title, $body, $data = array(), $priority = 'high') {
        // Lưu connection để dùng trong deactivateUnregisteredTokens
        $this->conn = $conn;
        
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
     * Gửi push notification đến nhiều devices
     */
    public function sendToMultipleDevices($tokens, $title, $body, $data = array(), $priority = 'high') {
        if (empty($tokens)) {
            return array(
                'success' => false,
                'message' => 'Không có device tokens',
                'sent_count' => 0
            );
        }
        
        // HTTP V1 API chỉ gửi 1 message/lần, không hỗ trợ batch
        // Cần gửi từng message
        $results = array();
        $successCount = 0;
        $unregisteredTokens = array(); // Lưu tokens bị UNREGISTERED để deactivate
        
        foreach ($tokens as $token) {
            $result = $this->sendToDevice($token, $title, $body, $data, $priority);
            $results[] = $result;
            
            if ($result['success']) {
                $successCount++;
            } elseif (isset($result['error_code']) && $result['error_code'] === 'UNREGISTERED') {
                // Token không còn hợp lệ, cần deactivate
                $unregisteredTokens[] = $token;
            }
        }
        
        // Deactivate UNREGISTERED tokens trong database
        if (!empty($unregisteredTokens)) {
            $this->deactivateUnregisteredTokens($unregisteredTokens);
        }
        
        return array(
            'success' => $successCount > 0,
            'sent_count' => $successCount,
            'total_devices' => count($tokens),
            'unregistered_count' => count($unregisteredTokens),
            'results' => $results
        );
    }
    
    /**
     * Deactivate UNREGISTERED tokens trong database
     */
    private function deactivateUnregisteredTokens($tokens) {
        if (empty($tokens) || !$this->conn) {
            return;
        }
        
        $logPath = dirname(__FILE__) . '/debug_push_notifications.log';
        
        try {
            // Escape tokens để tránh SQL injection
            $escapedTokens = array();
            foreach ($tokens as $token) {
                $escapedTokens[] = "'" . mysqli_real_escape_string($this->conn, $token) . "'";
            }
            $tokensList = implode(',', $escapedTokens);
            
            // Update is_active = 0 cho UNREGISTERED tokens
            $updateQuery = "UPDATE device_tokens 
                           SET is_active = 0, 
                               last_used_at = UNIX_TIMESTAMP() 
                           WHERE device_token IN ($tokensList) 
                           AND is_active = 1";
            
            $updateResult = mysqli_query($this->conn, $updateQuery);
            
            if ($updateResult) {
                $affectedRows = mysqli_affected_rows($this->conn);
                file_put_contents($logPath, date('c') . " | [DEACTIVATE_TOKENS] ✅ Deactivated $affectedRows UNREGISTERED token(s)\n", FILE_APPEND);
            } else {
                file_put_contents($logPath, date('c') . " | [DEACTIVATE_TOKENS] ❌ ERROR: " . mysqli_error($this->conn) . "\n", FILE_APPEND);
            }
        } catch (Exception $e) {
            file_put_contents($logPath, date('c') . " | [DEACTIVATE_TOKENS] ❌ EXCEPTION: " . $e->getMessage() . "\n", FILE_APPEND);
        }
    }
    
    /**
     * Gửi push notification đến 1 device token
     */
    public function sendToDevice($token, $title, $body, $data = array(), $priority = 'high') {
        try {
            $accessToken = $this->getAccessToken();
            
            // Build message theo format FCM HTTP V1 API
            $message = array(
                'message' => array(
                    'token' => $token,
                    'notification' => array(
                        'title' => $title,
                        'body' => $body
                    ),
                    'data' => array()
                )
            );
            
            // Add data payload (phải là string)
            if (!empty($data)) {
                foreach ($data as $key => $value) {
                    $message['message']['data'][$key] = is_string($value) ? $value : json_encode($value);
                }
            }
            
            // Logo URL - từ server socdo.vn
            // Lưu ý: Server PHP có thể không check được HTTPS (Connection refused)
            // NHƯNG FCM sẽ tự download image từ URL này, không phụ thuộc vào server PHP check
            // Logo URL: https://socdo.vn/uploads/logo/logo.png
            // Server path: /home/socdo.vn/public_html/uploads/logo/logo.png
            $logoUrl = 'https://socdo.vn/uploads/logo/logo.png';
            
            // ⚠️ Bỏ qua logo check vì server backend không thể truy cập HTTPS từ socdo.vn
            // FCM sẽ tự download image từ URL này khi render notification
            // Nếu logo không accessible, FCM sẽ bỏ qua và vẫn hiển thị notification bình thường
            $logoAccessible = true; // Assume accessible, FCM will handle it
            $logoCheckError = '';
            
            // Add Android config với logo/image
            $message['message']['android'] = array(
                'priority' => $priority === 'high' ? 'high' : 'normal',
                'notification' => array(
                    // Icon: sử dụng app icon mặc định (đã được set trong AndroidManifest)
                    // Image: hiển thị logo từ URL (large notification image)
                    'image' => $logoUrl,
                    'channel_id' => 'socdo_channel', // Phải match với channel trong Flutter app
                    'sound' => 'default',
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                )
            );
            
            // Add APNS config với image
            $message['message']['apns'] = array(
                'headers' => array(
                    'apns-priority' => $priority === 'high' ? '10' : '5'
                ),
                'payload' => array(
                    'aps' => array(
                        'sound' => 'default',
                        'badge' => 1,
                        'mutable-content' => 1 // Phải là số 0 hoặc 1, không phải boolean. Cần cho notification service extension để hiển thị image
                    ),
                    // iOS có thể hiển thị image qua notification service extension
                    'fcm_options' => array(
                        'image' => $logoUrl
                    )
                )
            );
            
            // Debug logging - Chi tiết hơn
            $logPath = dirname(__FILE__) . '/debug_push_notifications.log';
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - apiUrl: " . ($this->apiUrl ?: 'EMPTY') . "\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - token: " . substr($token, 0, 20) . "...\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - accessToken: " . (isset($accessToken) && $accessToken ? substr($accessToken, 0, 20) . "..." : 'EMPTY') . "\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - logoUrl: $logoUrl\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - logoAccessible: " . ($logoAccessible ? 'YES' : 'NO') . ($logoCheckError ? " (Error: $logoCheckError)" : '') . "\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - android.notification.image: " . ($message['message']['android']['notification']['image'] ?? 'NOT SET') . "\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - android.notification.channel_id: " . ($message['message']['android']['notification']['channel_id'] ?? 'NOT SET') . "\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - full message payload: " . json_encode($message, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . "\n", FILE_APPEND);
            
            // Validate URL before sending
            if (empty($this->apiUrl)) {
                $logPath = dirname(__FILE__) . '/debug_push_notifications.log';
                file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] ERROR: apiUrl is empty!\n", FILE_APPEND);
                return array(
                    'success' => false,
                    'message' => 'FCM API URL is empty'
                );
            }
            
            // Send request
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $this->apiUrl);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, array(
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json'
            ));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $error = curl_error($ch);
            curl_close($ch);
            
            if ($error) {
                return array(
                    'success' => false,
                    'message' => 'CURL Error: ' . $error
                );
            }
            
            if ($httpCode != 200) {
                $responseData = json_decode($response, true);
                $errorCode = null;
                
                // Parse error code từ FCM response
                if (isset($responseData['error']['details'][0]['errorCode'])) {
                    $errorCode = $responseData['error']['details'][0]['errorCode'];
                }
                
                return array(
                    'success' => false,
                    'message' => 'FCM API Error: HTTP ' . $httpCode . ' - ' . $response,
                    'error_code' => $errorCode, // UNREGISTERED, INVALID_ARGUMENT, etc.
                    'token' => $token // Return token để xử lý deactivate
                );
            }
            
            $responseData = json_decode($response, true);
            
            // Debug: Log FCM response chi tiết
            $logPath = dirname(__FILE__) . '/debug_push_notifications.log';
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - FCM Response HTTP Code: $httpCode\n", FILE_APPEND);
            file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - FCM Response: " . json_encode($responseData, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . "\n", FILE_APPEND);
            
            // Check if FCM accepted the message
            if (isset($responseData['name'])) {
                file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - Message sent successfully! FCM Message ID: " . $responseData['name'] . "\n", FILE_APPEND);
            } else {
                file_put_contents($logPath, date('c') . " | [FCMPushServiceV1] sendToDevice - WARNING: FCM response missing 'name' field\n", FILE_APPEND);
            }
            
            return array(
                'success' => true,
                'message' => 'Sent successfully',
                'response' => $responseData
            );
            
        } catch (Exception $e) {
            return array(
                'success' => false,
                'message' => 'Exception: ' . $e->getMessage()
            );
        }
    }
}
?>

