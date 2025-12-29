import 'dart:convert';
import 'package:flutter/material.dart';
import '../../presentation/product/product_detail_screen.dart';
import '../../presentation/affiliate/affiliate_screen.dart';
import '../../presentation/orders/order_detail_screen.dart';
import '../../presentation/voucher/voucher_screen.dart';
import '../../presentation/orders/orders_screen.dart';
import '../../presentation/notifications/notifications_screen.dart';
import 'auth_service.dart';

/// Xử lý deep linking khi user tap vào notification
class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Handle notification data và navigate đến màn hình phù hợp
  void handleNotificationData(Map<String, dynamic> data) {
    // print('🔔 [NOTIFICATION] Handling notification data: $data');
    
    try {
      // Parse data nếu là JSON string
      Map<String, dynamic> parsedData = data;
      if (data.containsKey('data') && data['data'] is String) {
        try {
          final dataString = data['data'] as String;
          final parsed = jsonDecode(dataString) as Map<String, dynamic>;
          parsedData = {...data, ...parsed};
        } catch (e) {
          // Không phải JSON, giữ nguyên
        }
      }
      
      final type = parsedData['type'] as String?;
      final relatedId = parsedData['related_id'];
      final dataPayload = parsedData['data'];
      
      // Parse data payload nếu là JSON string
      Map<String, dynamic>? dataMap;
      if (dataPayload != null) {
        if (dataPayload is Map) {
          dataMap = Map<String, dynamic>.from(dataPayload);
        } else if (dataPayload is String) {
          try {
            dataMap = jsonDecode(dataPayload) as Map<String, dynamic>;
          } catch (e) {
            // Không phải JSON
          }
        }
      }
      
      if (type == null) {
        // print('⚠️ [NOTIFICATION] Type is null, navigating to notifications list');
        _navigateToNotifications();
        return;
      }

      // print('🔔 [NOTIFICATION] Type: $type, relatedId: $relatedId');

      switch (type) {
        case 'order':
        case 'affiliate_order':
          // Navigate đến order detail
          int? orderId;
          String? orderCode;
          
          // Lấy order_id từ related_id hoặc data
          if (relatedId != null) {
            orderId = relatedId is int ? relatedId : int.tryParse(relatedId.toString());
          }
          if (dataMap != null) {
            final orderIdFromData = dataMap['order_id'];
            if (orderIdFromData != null) {
              orderId = orderIdFromData is int ? orderIdFromData : int.tryParse(orderIdFromData.toString());
            }
            orderCode = dataMap['order_code']?.toString();
          }
          
          if (orderId != null && orderId > 0) {
            _navigateToOrderDetail(orderId, orderCode);
          } else {
            // Nếu không có order_id, navigate đến danh sách đơn hàng
            _navigateToOrders();
          }
          break;

        case 'deposit':
        case 'withdrawal':
        case 'transaction':
          // Navigate đến affiliate screen (có phần giao dịch)
          _navigateToAffiliate();
          break;

        case 'voucher_new':
        case 'voucher_expiring':
          _navigateToVouchers();
          break;

        case 'bonus_expiring':
        case 'promo_code_expired':
          // Navigate đến voucher screen (nơi hiển thị bonus)
          _navigateToVouchers();
          break;

        case 'birthday':
          // Navigate đến notifications screen để xem thông báo chúc mừng sinh nhật
          _navigateToNotifications();
          break;

        case 'affiliate_daily':
        case 'affiliate_product':
          final productId = _parseProductId(dataMap ?? parsedData);
          
          if (productId != null && productId > 0) {
            _navigateToProductDetail(productId);
          } else {
            _navigateToAffiliate();
          }
          break;

        case 'admin_manual':
          // Xử lý notification từ admin manual
          final action = dataMap?['action'] as String? ?? parsedData['action'] as String?;
          final productId = _parseProductId(dataMap ?? parsedData);

          if (action == 'open_product' && productId != null && productId > 0) {
            _navigateToProductDetail(productId);
          } else {
            _navigateToNotifications();
          }
          break;

        default:
          // Navigate đến notifications list
          _navigateToNotifications();
          break;
      }
    } catch (e, stackTrace) {
      // print('❌ [NOTIFICATION] Error handling notification: $e');
      // print('❌ [NOTIFICATION] Stack trace: $stackTrace');
      // Fallback: navigate to notifications list
      _navigateToNotifications();
    }
  }

  /// Parse product_id từ data (hỗ trợ nhiều format)
  int? _parseProductId(Map<String, dynamic> data) {
    final productId = data['product_id'];
    if (productId == null) return null;
    
    if (productId is int) {
      return productId;
    } else if (productId is String) {
      // Thử parse JSON string trước
      try {
        final parsed = jsonDecode(productId);
        if (parsed is int) {
          return parsed;
        } else if (parsed is String) {
          return int.tryParse(parsed);
        }
      } catch (e) {
        // Không phải JSON, parse trực tiếp
        return int.tryParse(productId);
      }
    }
    return null;
  }

  void _navigateToOrderDetail(int orderId, String? orderCode) {
    _tryNavigateWithRetry(
      maxRetries: 30,
      delayMs: 100,
      action: () async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        
        // Lấy userId từ AuthService
        final authService = AuthService();
        final user = await authService.getCurrentUser();
        if (user == null) {
          // print('⚠️ [NOTIFICATION] User not logged in, cannot navigate to order detail');
          return false;
        }
        
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(
                userId: user.userId,
                orderId: orderId,
                maDon: orderCode,
              ),
            ),
          );
          return true;
        } catch (e) {
          // print('❌ [NOTIFICATION] Error navigating to order detail: $e');
          return false;
        }
      },
    );
  }

  void _navigateToOrders() {
    _tryNavigateWithRetry(
      maxRetries: 30,
      delayMs: 100,
      action: () async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrdersScreen(),
            ),
          );
          return true;
        } catch (e) {
          // print('❌ [NOTIFICATION] Error navigating to orders: $e');
          return false;
        }
      },
    );
  }

  void _navigateToVouchers() {
    _tryNavigateWithRetry(
      maxRetries: 30,
      delayMs: 100,
      action: () async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VoucherScreen(),
            ),
          );
          return true;
        } catch (e) {
          // print('❌ [NOTIFICATION] Error navigating to vouchers: $e');
          return false;
        }
      },
    );
  }

  void _navigateToNotifications() {
    _tryNavigateWithRetry(
      maxRetries: 30,
      delayMs: 100,
      action: () async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          );
          return true;
        } catch (e) {
          // print('❌ [NOTIFICATION] Error navigating to notifications: $e');
          return false;
        }
      },
    );
  }

  void _navigateToAffiliate() {
    _tryNavigateWithRetry(
      maxRetries: 30,
      delayMs: 100,
      action: () async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AffiliateScreen(),
            ),
          );
          return true;
        } catch (e) {
          // print('❌ [NOTIFICATION] Error navigating to affiliate: $e');
          return false;
        }
      },
    );
  }

  void _navigateToProductDetail(int productId) {
    _tryNavigateWithRetry(
      maxRetries: 30,
      delayMs: 100,
      action: () async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: productId,
              ),
            ),
          );
          return true;
        } catch (e) {
          // print('❌ [NOTIFICATION] Error navigating to product detail: $e');
          return false;
        }
      },
    );
  }

  /// Helper function để retry navigation với delay
  void _tryNavigateWithRetry({
    required int maxRetries,
    required int delayMs,
    required Future<bool> Function() action,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      final success = await action();
      if (success) {
        return;
      }
      
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    
    // print('⚠️ [NOTIFICATION] Failed to navigate after $maxRetries retries');
  }
}

