<?php
/**
 * Ví dụ tích hợp NotificationMobileHelper vào các API hiện tại
 * 
 * 1. Tích hợp vào create_order.php
 * 2. Tích hợp vào order_status.php  
 * 3. Tích hợp vào affiliate_orders.php
 * 4. Tích hợp vào lichsu_chitieu.php
 */

// ========================================
// 1. TÍCH HỢP VÀO create_order.php
// ========================================

// Thêm vào cuối file create_order.php sau khi tạo đơn hàng thành công:

/*
require_once './notification_mobile_helper.php';

if ($order_created_successfully) {
    $notificationHelper = new NotificationMobileHelper($conn);
    
    // Tạo thông báo đơn hàng mới
    $notificationHelper->notifyNewOrder(
        $user_id, 
        $order_id, 
        $order_code, 
        $total_amount
    );
    
    echo "Thông báo đơn hàng mới đã được tạo\n";
}
*/

// ========================================
// 2. TÍCH HỢP VÀO order_status.php
// ========================================

// Thêm vào file order_status.php khi cập nhật trạng thái đơn hàng:

/*
require_once './notification_mobile_helper.php';

if ($status_updated_successfully) {
    $notificationHelper = new NotificationMobileHelper($conn);
    
    // Lấy thông tin đơn hàng
    $order_query = "SELECT user_id, ma_don, tongtien FROM donhang WHERE id = '$order_id'";
    $order_result = mysqli_query($conn, $order_query);
    $order_data = mysqli_fetch_assoc($order_result);
    
    // Tạo thông báo thay đổi trạng thái
    $notificationHelper->notifyOrderStatusChange(
        $order_data['user_id'],
        $order_id,
        $order_data['ma_don'],
        $old_status,
        $new_status
    );
    
    echo "Thông báo cập nhật trạng thái đã được tạo\n";
}
*/

// ========================================
// 3. TÍCH HỢP VÀO affiliate_orders.php
// ========================================

// Thêm vào file affiliate_orders.php khi có đơn hàng affiliate mới:

/*
require_once './notification_mobile_helper.php';

if ($affiliate_order_created) {
    $notificationHelper = new NotificationMobileHelper($conn);
    
    // Tạo thông báo đơn hàng affiliate mới
    $notificationHelper->notifyNewAffiliateOrder(
        $affiliate_user_id,
        $order_id,
        $order_code,
        $commission_amount
    );
    
    echo "Thông báo đơn hàng affiliate đã được tạo\n";
}
*/

// ========================================
// 4. TÍCH HỢP VÀO lichsu_chitieu.php
// ========================================

// Thêm vào file lichsu_chitieu.php khi có giao dịch nạp/rút tiền:

/*
require_once './notification_mobile_helper.php';

if ($transaction_created) {
    $notificationHelper = new NotificationMobileHelper($conn);
    
    // Xác định loại giao dịch
    if ($transaction_type == 'deposit') {
        $notificationHelper->notifyDeposit(
            $user_id,
            $amount,
            $payment_method
        );
    } elseif ($transaction_type == 'withdrawal') {
        $notificationHelper->notifyWithdrawal(
            $user_id,
            $amount,
            $withdrawal_status,
            $payment_method
        );
    }
    
    echo "Thông báo giao dịch đã được tạo\n";
}
*/

// ========================================
// 5. TÍCH HỢP VÀO coupon.php
// ========================================

// Thêm vào file coupon.php khi tạo voucher mới:

/*
require_once './notification_mobile_helper.php';

if ($coupon_created) {
    $notificationHelper = new NotificationMobileHelper($conn);
    
    // Lấy danh sách user của shop
    $users_query = "SELECT user_id FROM user_info WHERE shop = '{$coupon_data['shop']}'";
    $users_result = mysqli_query($conn, $users_query);
    
    while ($user = mysqli_fetch_assoc($users_result)) {
        $notificationHelper->notifyNewVoucher(
            $user['user_id'],
            $coupon_data['ma'],
            $coupon_data['giam'],
            $coupon_data['expired']
        );
    }
    
    echo "Thông báo voucher mới đã được tạo cho " . mysqli_num_rows($users_result) . " user\n";
}
*/

// ========================================
// 6. CẬP NHẬT API SERVICE TRONG MOBILE APP
// ========================================

/*
// Trong lib/src/core/services/api_service.dart
// Thay đổi endpoint từ notifications_list thành notifications_mobile

Future<Map<String, dynamic>?> getNotifications({
  required int userId,
  int page = 1,
  int limit = 20,
  String? type,
  bool unreadOnly = false,
}) async {
  try {
    final query = {
      'user_id': userId.toString(),
      'page': page.toString(),
      'limit': limit.toString(),
      if (type != null) 'type': type,
      if (unreadOnly) 'unread_only': 'true',
    };
    final uri = Uri.parse('$baseUrl/notifications_mobile').replace(queryParameters: query);
    final token = await getValidToken();
    final response = await http.get(uri, headers: {
      'Authorization': token != null ? 'Bearer $token' : '',
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    return null;
  }
}

Future<bool> markNotificationRead({
  required int userId,
  required int notificationId,
}) async {
  try {
    final uri = Uri.parse('$baseUrl/notification_mark_read_mobile');
    final token = await getValidToken();
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['user_id'] = userId.toString();
    request.fields['notification_id'] = notificationId.toString();
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    }
    return false;
  } catch (e) {
    return false;
  }
}
*/

// ========================================
// 7. CẤU HÌNH CRON JOB
// ========================================

/*
// Thêm vào crontab để chạy mỗi giờ:
// 0 * * * * /usr/bin/php /path/to/socdo_mobile/API_WEB/cron_check_voucher_expiring.php socdo_cron_2025

// Hoặc tạo file cron.sh:
#!/bin/bash
cd /path/to/socdo_mobile/API_WEB
php cron_check_voucher_expiring.php socdo_cron_2025

// Sau đó thêm vào crontab:
// 0 * * * * /path/to/socdo_mobile/API_WEB/cron.sh
*/

?>
