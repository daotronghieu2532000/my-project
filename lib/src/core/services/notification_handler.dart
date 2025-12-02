import 'dart:convert';
import 'package:flutter/material.dart';
import '../../presentation/product/product_detail_screen.dart';
import '../../presentation/affiliate/affiliate_screen.dart';

/// Xử lý deep linking khi user tap vào notification
class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Handle notification data và navigate đến màn hình phù hợp
  void handleNotificationData(Map<String, dynamic> data) {
   
    try {
      final type = data['type'] as String?;
      final relatedId = data['related_id'] as String?;
    
      if (type == null) {
        return;
      }

      switch (type) {
        case 'order':
        case 'affiliate_order':
          // Navigate đến order detail
          if (relatedId != null) {
            final orderId = int.tryParse(relatedId);
            if (orderId != null) {
              _navigateToOrderDetail(orderId);
            }
          }
          break;

        case 'deposit':
        case 'withdrawal':
          _navigateToBalance();
          break;

        case 'voucher_new':
        case 'voucher_expiring':
          _navigateToVouchers();
          break;

        case 'affiliate_daily':
        case 'affiliate_product':
          
          // Navigate đến affiliate screen hoặc product detail nếu có product_id
          final affiliateId = data['affiliate_id'];
          final productId = data['product_id'];
          
          
          // Parse product_id (có thể là int, string, hoặc JSON string)
          int? productIdInt;
          if (productId != null) {
            if (productId is int) {
              productIdInt = productId;
            } else if (productId is String) {
              // Thử parse JSON string trước
              try {
                final parsed = jsonDecode(productId);
                if (parsed is int) {
                  productIdInt = parsed;
                } else if (parsed is String) {
                  productIdInt = int.tryParse(parsed);
                }
              } catch (e) {
                // Không phải JSON, parse trực tiếp
                productIdInt = int.tryParse(productId);
              }
            }
          }
          
          
          // Nếu có product_id, navigate đến product detail
          if (productIdInt != null && productIdInt > 0) {
            _navigateToProductDetail(productIdInt);
            return;
          }
          
          // Fallback: navigate đến affiliate screen
          _navigateToAffiliate();
          break;

        case 'admin_manual':
         
          // Xử lý notification từ admin manual
          final action = data['action'] as String?;
          final productId = data['product_id'];

          if (action == 'open_product') {
           
            if (productId != null) {
              final productIdInt = productId is int 
                  ? productId 
                  : (productId is String ? int.tryParse(productId) : null);
              
           
              
              if (productIdInt != null && productIdInt > 0) {
             
                _navigateToProductDetail(productIdInt);
                return;
              } else {
                print('⚠️ [NOTIFICATION] Invalid product_id: $productIdInt');
              }
            } else {
              print('⚠️ [NOTIFICATION] product_id is null');
            }
          } else {
            print('⚠️ [NOTIFICATION] Action is not open_product: $action');
          }
          // Fallback: navigate to notifications list
         
          _navigateToNotifications();
          break;

        default:
          // Navigate đến notifications list
          _navigateToNotifications();
          break;
      }
    } catch (e, stackTrace) {
      // Fallback: navigate to notifications list
      _navigateToNotifications();
    }
  }

  void _navigateToOrderDetail(int orderId) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Import và navigate đến OrderDetailScreen
      // Navigator.pushNamed(context, '/order-detail', arguments: orderId);
      // TODO: Implement navigation khi có OrderDetailScreen route
    }
  }

  void _navigateToBalance() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Navigate đến balance/transaction screen
      // TODO: Implement navigation
    }
  }

  void _navigateToVouchers() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Navigate đến voucher list
      // TODO: Implement navigation
    }
  }

  void _navigateToNotifications() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Navigate đến notifications list
      // TODO: Implement navigation khi có route
      // Navigator.pushNamed(context, '/notifications');
    }
  }

  void _navigateToAffiliate() {
    
    // Retry logic: Đợi context sẵn sàng (tối đa 3 giây)
    _tryNavigateAffiliateWithRetry(maxRetries: 30, delayMs: 100);
  }

  void _tryNavigateAffiliateWithRetry({int maxRetries = 30, int delayMs = 100}) async {
    for (int i = 0; i < maxRetries; i++) {
      final context = navigatorKey.currentContext;
      
      if (context != null) {
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AffiliateScreen(),
            ),
          );
          return;
        } catch (e, stackTrace) {
          return;
        }
      } else {
        if (i == 0) {
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    
  }

  void _navigateToProductDetail(int productId) {
    
    // Retry logic: Đợi context sẵn sàng (tối đa 3 giây)
    _tryNavigateWithRetry(productId, maxRetries: 30, delayMs: 100);
  }

  void _tryNavigateWithRetry(int productId, {int maxRetries = 30, int delayMs = 100}) async {
    for (int i = 0; i < maxRetries; i++) {
      final context = navigatorKey.currentContext;
      
      if (context != null) {
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: productId,
              ),
            ),
          );
          return;
        } catch (e, stackTrace) {
          return;
        }
      } else {
        if (i == 0) {
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    
  }
}

