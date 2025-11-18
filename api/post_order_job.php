<?php
// Lightweight async job: send notification after order creation
// This endpoint is triggered internally by create_order via a fire-and-forget GET
header('Content-Type: text/plain; charset=utf-8');
ignore_user_abort(true);
set_time_limit(10);

require_once './includes/config.php';

$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
$ma_don = isset($_GET['ma_don']) ? trim($_GET['ma_don']) : '';
$tongtien = isset($_GET['tongtien']) ? intval($_GET['tongtien']) : 0;

if ($user_id <= 0 || $ma_don === '') {
    http_response_code(200);
    echo 'skip';
    exit;
}

// Lấy order_id theo ma_don
$order_id = 0;
if ($stmt = mysqli_prepare($conn, "SELECT id FROM donhang WHERE ma_don = ? LIMIT 1")) {
    mysqli_stmt_bind_param($stmt, 's', $ma_don);
    mysqli_stmt_execute($stmt);
    $res = mysqli_stmt_get_result($stmt);
    if ($row = mysqli_fetch_assoc($res)) { $order_id = intval($row['id']); }
    mysqli_stmt_close($stmt);
}

// An toàn: chỉ gửi push nếu đủ file FCM
$notification_file = __DIR__ . '/notification_mobile_helper.php';
$fcm_cfg = __DIR__ . '/fcm_config.php';
$fcm_svc = __DIR__ . '/fcm_push_service_v1.php';

try {
    if (file_exists($notification_file) && file_exists($fcm_cfg) && file_exists($fcm_svc)) {
        require_once $notification_file;
        $helper = new NotificationMobileHelper($conn);
        if ($order_id > 0) {
            $ok = $helper->notifyNewOrder($user_id, $order_id, $ma_don, $tongtien);
            file_put_contents(__DIR__ . '/debug_push_notifications.log', date('c') . " | JOB OK: order=$ma_don result=" . var_export($ok, true) . "\n", FILE_APPEND);
        }
    } else {
        file_put_contents(__DIR__ . '/debug_push_notifications.log', date('c') . " | JOB MISSING FCM FILES - skip\n", FILE_APPEND);
    }
} catch (Throwable $e) {
    file_put_contents(__DIR__ . '/debug_push_notifications.log', date('c') . " | JOB EXC: " . $e->getMessage() . "\n", FILE_APPEND);
}

http_response_code(200);
echo 'ok';
exit;


