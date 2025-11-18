<?php
/**
 * Zalo Notification Service (ZNS) - Service để gửi tin nhắn OTP qua Zalo
 * 
 * Tài liệu: https://developers.zalo.me/docs/zalo-notification-service/bat-dau/gioi-thieu-zalo-notification-service-api
 */

class ZNSService {
    private $accessToken;
    private $refreshToken;
    private $appId;
    private $appSecret;
    private $oaId;
    private $templateId;
    private $apiUrl = 'https://business.openapi.zalo.me/message/template';
    private $refreshTokenUrl = 'https://oauth.zaloapp.com/v4/oa/access_token';
    private $tokenCacheFile;
    
    /**
     * Constructor
     * 
     * @param string $accessToken Access Token từ Zalo Cloud
     * @param string $refreshToken Refresh Token từ Zalo Cloud
     * @param string $appId App ID từ Zalo Cloud
     * @param string $appSecret App Secret từ Zalo Cloud
     * @param string $oaId OA ID (Official Account ID)
     * @param string $templateId Template ID đã được duyệt
     * @param string $tokenCacheFile Đường dẫn file cache token (optional)
     */
    public function __construct($accessToken, $refreshToken, $appId, $appSecret, $oaId, $templateId, $tokenCacheFile = null) {
        $this->accessToken = $accessToken;
        $this->refreshToken = $refreshToken;
        $this->appId = $appId;
        $this->appSecret = $appSecret;
        $this->oaId = $oaId;
        $this->templateId = $templateId;
        $this->tokenCacheFile = $tokenCacheFile;
        
        // Load token từ cache nếu có
        $this->loadTokenFromCache();
    }
    
    /**
     * Gửi tin nhắn OTP qua ZNS
     * 
     * @param string $phoneNumber Số điện thoại người dùng (format: 84901234567)
     * @param string $otpCode Mã OTP 6 chữ số
     * @param string $userName Tên người dùng (optional)
     * @return array Kết quả gửi tin nhắn
     */
    public function sendOTP($phoneNumber, $otpCode, $userName = '') {
        try {
            // Format số điện thoại: chuyển từ 0xxx sang 84xxx
            $formattedPhone = $this->formatPhoneNumber($phoneNumber);
            
            if (!$formattedPhone) {
                return [
                    'success' => false,
                    'message' => 'Số điện thoại không hợp lệ'
                ];
            }
            
            // Chuẩn bị dữ liệu template
            // Template params phải khớp với template đã tạo trên Zalo Cloud
            // Template chỉ có tham số 'otp' (theo template đã tạo)
            $templateData = [
                'phone' => $formattedPhone,
                'template_id' => $this->templateId,
                'template_data' => [
                    'otp' => $otpCode
                ],
                'oa_id' => $this->oaId
            ];
            
            // TODO: Bỏ comment khi cần debug
            // Log request details để debug
            // error_log("ZNS Request Details:");
            // error_log("  - API URL: " . $this->apiUrl);
            // error_log("  - Phone: " . $formattedPhone);
            // error_log("  - Template ID: " . $this->templateId);
            // error_log("  - OA ID: " . $this->oaId);
            // error_log("  - Access Token (first 20 chars): " . substr($this->accessToken, 0, 20) . "...");
            // error_log("  - Template Data: " . json_encode($templateData, JSON_UNESCAPED_UNICODE));
            
            // Gửi request đến ZNS API
            $ch = curl_init($this->apiUrl);
            $headers = [
                'Content-Type: application/json',
                'access_token: ' . $this->accessToken
            ];
            
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => json_encode($templateData),
                CURLOPT_HTTPHEADER => $headers,
                CURLOPT_TIMEOUT => 30,
                CURLOPT_SSL_VERIFYPEER => true
            ]);
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);
            
            // TODO: Bỏ comment khi cần debug
            // Log response details
            // error_log("ZNS Response Details:");
            // error_log("  - HTTP Code: " . $httpCode);
            // error_log("  - CURL Error: " . ($curlError ?: 'None'));
            // error_log("  - Response: " . ($response ?: 'Empty'));
            
            if ($curlError) {
                error_log("ZNS CURL Error: " . $curlError);
                return [
                    'success' => false,
                    'message' => 'Lỗi kết nối đến ZNS: ' . $curlError
                ];
            }
            
            $responseData = json_decode($response, true);
            
            // TODO: Bỏ comment khi cần debug
            // Log parsed response
            // error_log("ZNS Parsed Response: " . json_encode($responseData, JSON_UNESCAPED_UNICODE));
            
            if ($httpCode == 200 && isset($responseData['error']) && $responseData['error'] == 0) {
                return [
                    'success' => true,
                    'message' => 'Gửi OTP thành công',
                    'data' => $responseData
                ];
            } else {
                // Kiểm tra nếu lỗi 401 (Unauthorized) - token hết hạn
                if ($httpCode == 401 || (isset($responseData['error']) && $responseData['error'] == -216)) {
                    error_log("ZNS Access Token hết hạn, đang refresh token...");
                    
                    // Thử refresh token
                    $refreshResult = $this->refreshAccessToken();
                    
                    if ($refreshResult['success']) {
                        // Thử gửi lại OTP với token mới
                        error_log("Token đã được refresh, thử gửi lại OTP...");
                        return $this->sendOTP($phoneNumber, $otpCode, $userName);
                    } else {
                        return [
                            'success' => false,
                            'message' => 'Access Token hết hạn và không thể refresh. Vui lòng liên hệ admin.',
                            'error_code' => 'TOKEN_EXPIRED',
                            'refresh_error' => $refreshResult['message']
                        ];
                    }
                }
                
                $errorMsg = isset($responseData['message']) ? $responseData['message'] : 'Lỗi không xác định';
                $errorCode = isset($responseData['error']) ? $responseData['error'] : $httpCode;
                
                error_log("ZNS API Error (HTTP $httpCode): " . json_encode($responseData));
                
                // TODO: Bỏ comment khi cần debug - Thêm thông tin debug chi tiết cho lỗi permission
                $debugInfo = '';
                // if (stripos($errorMsg, 'permission') !== false || stripos($errorMsg, 'quyền') !== false) {
                //     $debugInfo = "\n\n🔍 Debug Info:\n";
                //     $debugInfo .= "- Template ID: " . $this->templateId . "\n";
                //     $debugInfo .= "- OA ID: " . $this->oaId . "\n";
                //     $debugInfo .= "- App ID: " . $this->appId . "\n";
                //     $debugInfo .= "- Error Code: " . $errorCode . "\n";
                //     $debugInfo .= "\n💡 Gợi ý:\n";
                //     $debugInfo .= "1. Kiểm tra Template ID có đúng không\n";
                //     $debugInfo .= "2. Kiểm tra OA ID có đúng không\n";
                //     $debugInfo .= "3. Kiểm tra Template có được gán cho OA này không\n";
                //     $debugInfo .= "4. Kiểm tra Access Token có quyền gửi ZNS không\n";
                //     $debugInfo .= "5. Kiểm tra Template có được duyệt và kích hoạt chưa";
                // }
                
                $responseArray = [
                    'success' => false,
                    'message' => 'Lỗi gửi OTP: ' . $errorMsg,
                    'error' => $errorMsg,
                    'error_code' => $errorCode
                ];
                
                // TODO: Bỏ comment khi cần debug - Thêm debug info vào response
                // $responseArray['message'] .= $debugInfo;
                // $responseArray['response'] = $responseData;
                // $responseArray['debug'] = [
                //     'template_id' => $this->templateId,
                //     'oa_id' => $this->oaId,
                //     'app_id' => $this->appId,
                //     'http_code' => $httpCode,
                //     'zns_response' => $responseData
                // ];
                
                return $responseArray;
            }
            
        } catch (Exception $e) {
            error_log("ZNS Exception: " . $e->getMessage());
            return [
                'success' => false,
                'message' => 'Lỗi: ' . $e->getMessage()
            ];
        }
    }
    
    /**
     * Format số điện thoại từ 0xxx sang 84xxx
     * 
     * @param string $phoneNumber Số điện thoại
     * @return string|false Số điện thoại đã format hoặc false nếu không hợp lệ
     */
    private function formatPhoneNumber($phoneNumber) {
        // Loại bỏ khoảng trắng và ký tự đặc biệt
        $phone = preg_replace('/[^0-9]/', '', $phoneNumber);
        
        // Kiểm tra độ dài
        if (strlen($phone) < 10 || strlen($phone) > 11) {
            return false;
        }
        
        // Nếu bắt đầu bằng 0, chuyển sang 84
        if (substr($phone, 0, 1) == '0') {
            $phone = '84' . substr($phone, 1);
        }
        // Nếu chưa có mã quốc gia, thêm 84
        elseif (substr($phone, 0, 2) != '84') {
            $phone = '84' . $phone;
        }
        
        return $phone;
    }
    
    /**
     * Lấy access token mới từ refresh token
     * 
     * @return array Kết quả refresh token
     */
    public function refreshAccessToken() {
        try {
            if (empty($this->refreshToken) || empty($this->appId) || empty($this->appSecret)) {
                return [
                    'success' => false,
                    'message' => 'Thiếu thông tin refresh token, app_id hoặc app_secret'
                ];
            }
            
            // Chuẩn bị dữ liệu theo format x-www-form-urlencoded
            $postData = http_build_query([
                'app_id' => $this->appId,
                'app_secret' => $this->appSecret,
                'refresh_token' => $this->refreshToken,
                'grant_type' => 'refresh_token'
            ]);
            
            // Gửi request đến Zalo OAuth API
            $ch = curl_init($this->refreshTokenUrl);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => $postData,
                CURLOPT_HTTPHEADER => [
                    'Content-Type: application/x-www-form-urlencoded'
                ],
                CURLOPT_TIMEOUT => 30,
                CURLOPT_SSL_VERIFYPEER => true
            ]);
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);
            
            if ($curlError) {
                error_log("ZNS Refresh Token CURL Error: " . $curlError);
                return [
                    'success' => false,
                    'message' => 'Lỗi kết nối khi refresh token: ' . $curlError
                ];
            }
            
            $responseData = json_decode($response, true);
            
            if ($httpCode == 200 && isset($responseData['access_token'])) {
                // Cập nhật token mới
                $this->accessToken = $responseData['access_token'];
                
                // Cập nhật refresh token mới nếu có (Zalo có thể trả về refresh token mới)
                if (isset($responseData['refresh_token'])) {
                    $this->refreshToken = $responseData['refresh_token'];
                }
                
                // Lưu token vào cache
                $this->saveTokenToCache();
                
                error_log("ZNS Token đã được refresh thành công");
                return [
                    'success' => true,
                    'message' => 'Refresh token thành công',
                    'access_token' => $this->accessToken,
                    'expires_in' => isset($responseData['expires_in']) ? $responseData['expires_in'] : 3600
                ];
            } else {
                $errorMsg = isset($responseData['message']) ? $responseData['message'] : 'Lỗi không xác định';
                error_log("ZNS Refresh Token Error (HTTP $httpCode): " . json_encode($responseData));
                return [
                    'success' => false,
                    'message' => 'Lỗi refresh token: ' . $errorMsg,
                    'error_code' => isset($responseData['error']) ? $responseData['error'] : $httpCode,
                    'response' => $responseData
                ];
            }
            
        } catch (Exception $e) {
            error_log("ZNS Refresh Token Exception: " . $e->getMessage());
            return [
                'success' => false,
                'message' => 'Lỗi: ' . $e->getMessage()
            ];
        }
    }
    
    /**
     * Lưu token vào file cache
     */
    private function saveTokenToCache() {
        if (!$this->tokenCacheFile) {
            return;
        }
        
        try {
            $cacheData = [
                'access_token' => $this->accessToken,
                'refresh_token' => $this->refreshToken,
                'updated_at' => time()
            ];
            
            file_put_contents($this->tokenCacheFile, json_encode($cacheData, JSON_PRETTY_PRINT));
            error_log("ZNS Token đã được lưu vào cache: " . $this->tokenCacheFile);
        } catch (Exception $e) {
            error_log("ZNS Lỗi lưu token cache: " . $e->getMessage());
        }
    }
    
    /**
     * Load token từ file cache
     */
    private function loadTokenFromCache() {
        if (!$this->tokenCacheFile || !file_exists($this->tokenCacheFile)) {
            return;
        }
        
        try {
            $cacheContent = file_get_contents($this->tokenCacheFile);
            $cacheData = json_decode($cacheContent, true);
            
            if ($cacheData && isset($cacheData['access_token'])) {
                $this->accessToken = $cacheData['access_token'];
                
                // Cập nhật refresh token nếu có trong cache
                if (isset($cacheData['refresh_token'])) {
                    $this->refreshToken = $cacheData['refresh_token'];
                }
                
                error_log("ZNS Token đã được load từ cache");
            }
        } catch (Exception $e) {
            error_log("ZNS Lỗi load token cache: " . $e->getMessage());
        }
    }
    
    /**
     * Static method để refresh token (giữ lại để tương thích)
     * 
     * @param string $refreshToken Refresh token
     * @param string $appId App ID
     * @param string $appSecret App Secret
     * @return array Kết quả
     */
    public static function refreshAccessTokenStatic($refreshToken, $appId, $appSecret) {
        $service = new self('', $refreshToken, $appId, $appSecret, '', '', null);
        return $service->refreshAccessToken();
    }
}

