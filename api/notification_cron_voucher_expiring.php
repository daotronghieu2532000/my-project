<?php
/**
 * Cron Job: Gửi thông báo voucher sắp hết hạn (< 24h)
 * 
 * Chạy mỗi giờ: php notification_cron_voucher_expiring.php
 * 
 * Mục đích: Gửi notification đến TẤT CẢ user có ctv = 0, shop = 0 về voucher sắp hết hạn
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

$logPath = __DIR__ . '/debug_push_notifications.log';
$currentTime = time();
$expiringThreshold = $currentTime + (24 * 3600); // 24 giờ từ bây giờ

// Query voucher sắp hết hạn (< 24h) và chưa hết hạn
$query = "SELECT id, ma, giam, loai, shop, expired, dieu_kien
          FROM coupon
          WHERE expired > $currentTime
          AND expired <= $expiringThreshold
          AND status = 1
          ORDER BY expired ASC";

$result = mysqli_query($conn, $query);

if (!$result) {
    file_put_contents($logPath, date('c') . " | [VOUCHER_EXPIRING] Query failed: " . mysqli_error($conn) . "\n", FILE_APPEND);
    exit(1);
}

$processed = 0;

while ($row = mysqli_fetch_assoc($result)) {
    $coupon_id = intval($row['id']);
    $coupon_code = $row['ma'];
    $discount_amount = intval($row['giam']);
    $discount_type = $row['loai'];
    $shop_id = intval($row['shop']);
    $expired_timestamp = intval($row['expired']);
    $min_order = intval($row['dieu_kien']);
    
    // Format discount text
    if ($discount_type == 'phantram') {
        $discount_text = $discount_amount . '%';
    } else {
        $discount_text = number_format($discount_amount, 0, ',', '.') . '₫';
    }
    
    // Format expired date
    $expired_date = date('d/m/Y H:i', $expired_timestamp);
    $hours_left = floor(($expired_timestamp - $currentTime) / 3600);
    
    // Tạo notification cho TẤT CẢ user có ctv = 0
    $title = "Voucher sắp hết hạn: $coupon_code";
    $content = "Lưu ý! Voucher \"$coupon_code\" giảm $discount_text của bạn sẽ hết hạn sau $hours_left giờ (đến $expired_date). Hãy nhanh tay sử dụng để không bỏ lỡ cơ hội tiết kiệm tuyệt vời này nhé!";
    
    $data = json_encode(array(
        'voucher_code' => $coupon_code,
        'discount_amount' => $discount_amount,
        'discount_type' => $discount_type,
        'expired_date' => $expired_timestamp,
        'hours_left' => $hours_left,
        'shop_id' => $shop_id,
        'min_order' => $min_order,
        'voucher_type' => 'all'
    ));
    
    // Insert notification cho TẤT CẢ user có ctv = 0, shop = 0 VÀ CÓ DEVICE_TOKEN ACTIVE (KHÁCH HÀNG THỰC TẾ DÙNG APP)
    $insertQuery = "INSERT INTO notification_mobile (
        user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
    )
    SELECT DISTINCT
        u.user_id,
        'voucher_expiring',
        '$title',
        '$content',
        '" . mysqli_real_escape_string($conn, $data) . "',
        $coupon_id,
        'coupon',
        'high',
        0,
        0,
        $currentTime
    FROM user_info u
    INNER JOIN device_tokens dt ON u.user_id = dt.user_id
    WHERE u.ctv = 0 
    AND u.shop = 0
    AND u.active = 1
    AND dt.is_active = 1";
    // ✅ Điều kiện: 
    // - ctv = 0 (khách hàng, không phải CTV)
    // - shop = 0 (không phải shop owner, chỉ khách hàng thông thường)
    // - active = 1 (tài khoản hoạt động)
    // - có device_token active (user thực tế dùng app)
    
    if (mysqli_query($conn, $insertQuery)) {
        $affected = mysqli_affected_rows($conn);
        $processed += $affected;
        file_put_contents($logPath, date('c') . " | [VOUCHER_EXPIRING] ✅ Created $affected notifications for voucher $coupon_code (expires in $hours_left hours)\n", FILE_APPEND);
    } else {
        file_put_contents($logPath, date('c') . " | [VOUCHER_EXPIRING] ❌ Failed to create notifications for voucher $coupon_code: " . mysqli_error($conn) . "\n", FILE_APPEND);
    }
}

file_put_contents($logPath, date('c') . " | [VOUCHER_EXPIRING] Completed: processed $processed notifications for expiring vouchers\n", FILE_APPEND);

