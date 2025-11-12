import 'dart:convert';
import 'package:flutter/material.dart';
import '../../presentation/product/product_detail_screen.dart';
import '../../presentation/affiliate/affiliate_screen.dart';

/// Xử lý deep linking khi user tap vào notification
class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Handle notification data và navigate đến màn hình phù hợp
  void handleNotificationData(Map<String, dynamic> data) {
    print('🎯 [DEBUG] NotificationHandler.handleNotificationData called');
    print('🎯 [DEBUG] Data keys: ${data.keys.toList()}');
    
    try {
      final type = data['type'] as String?;
      final relatedId = data['related_id'] as String?;
      
      print('🎯 [DEBUG] Notification type: $type');
      print('🎯 [DEBUG] Related ID: $relatedId');
      
      if (type == null) {
        print('⚠️ [DEBUG] Type is null, returning');
        return;
      }

      switch (type) {
        case 'order':
        case 'affiliate_order':
          print('📦 [DEBUG] Handling order notification');
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
          print('💰 [DEBUG] Handling transaction notification');
          // Navigate đến transaction/balance screen
          _navigateToBalance();
          break;

        case 'voucher_new':
        case 'voucher_expiring':
          print('🎫 [DEBUG] Handling voucher notification');
          // Navigate đến voucher list
          _navigateToVouchers();
          break;

        case 'affiliate_daily':
        case 'affiliate_product':
          print('💼 [DEBUG] Handling affiliate notification');
          print('💼 [DEBUG] Full data: $data');
          
          // Navigate đến affiliate screen hoặc product detail nếu có product_id
          final affiliateId = data['affiliate_id'];
          final productId = data['product_id'];
          
          print('💼 [DEBUG] Affiliate ID: $affiliateId (type: ${affiliateId.runtimeType})');
          print('💼 [DEBUG] Product ID: $productId (type: ${productId.runtimeType})');
          
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
          
          print('💼 [DEBUG] Parsed product_id: $productIdInt');
          
          // Nếu có product_id, navigate đến product detail
          if (productIdInt != null && productIdInt > 0) {
            print('✅ [DEBUG] Valid product_id found, navigating to ProductDetailScreen');
            _navigateToProductDetail(productIdInt);
            return;
          }
          
          // Fallback: navigate đến affiliate screen
          print('📋 [DEBUG] No valid product_id, navigating to AffiliateScreen');
          _navigateToAffiliate();
          break;

        case 'admin_manual':
          print('👤 [DEBUG] Handling admin_manual notification');
          // Xử lý notification từ admin manual
          final action = data['action'] as String?;
          final productId = data['product_id'];
          
          print('👤 [DEBUG] Action: $action');
          print('👤 [DEBUG] Product ID: $productId (type: ${productId.runtimeType})');
          
          if (action == 'open_product') {
            print('🛍️ [DEBUG] Action is open_product, checking product_id...');
            if (productId != null) {
              final productIdInt = productId is int 
                  ? productId 
                  : (productId is String ? int.tryParse(productId) : null);
              
              print('🛍️ [DEBUG] Parsed product_id: $productIdInt');
              
              if (productIdInt != null && productIdInt > 0) {
                print('✅ [DEBUG] Valid product_id found, navigating to ProductDetailScreen');
                _navigateToProductDetail(productIdInt);
                return;
              } else {
                print('⚠️ [DEBUG] Invalid product_id: $productIdInt');
              }
            } else {
              print('⚠️ [DEBUG] product_id is null');
            }
          } else {
            print('⚠️ [DEBUG] Action is not open_product: $action');
          }
          // Fallback: navigate to notifications list
          print('📋 [DEBUG] Falling back to notifications list');
          _navigateToNotifications();
          break;

        default:
          print('📋 [DEBUG] Unknown type: $type, navigating to notifications list');
          // Navigate đến notifications list
          _navigateToNotifications();
          break;
      }
    } catch (e, stackTrace) {
      print('❌ [DEBUG] Error handling notification data: $e');
      print('❌ [DEBUG] Stack trace: $stackTrace');
      // Fallback: navigate to notifications list
      _navigateToNotifications();
    }
  }

  void _navigateToOrderDetail(int orderId) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Import và navigate đến OrderDetailScreen
      // Navigator.pushNamed(context, '/order-detail', arguments: orderId);
      print('📱 Navigate to order detail: $orderId');
      // TODO: Implement navigation khi có OrderDetailScreen route
    }
  }

  void _navigateToBalance() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Navigate đến balance/transaction screen
      print('📱 Navigate to balance screen');
      // TODO: Implement navigation
    }
  }

  void _navigateToVouchers() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Navigate đến voucher list
      print('📱 Navigate to vouchers');
      // TODO: Implement navigation
    }
  }

  void _navigateToNotifications() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Navigate đến notifications list
      print('📱 Navigate to notifications');
      // TODO: Implement navigation khi có route
      // Navigator.pushNamed(context, '/notifications');
    }
  }

  void _navigateToAffiliate() {
    print('🚀 [DEBUG] _navigateToAffiliate called');
    
    // Retry logic: Đợi context sẵn sàng (tối đa 3 giây)
    _tryNavigateAffiliateWithRetry(maxRetries: 30, delayMs: 100);
  }

  void _tryNavigateAffiliateWithRetry({int maxRetries = 30, int delayMs = 100}) async {
    for (int i = 0; i < maxRetries; i++) {
      final context = navigatorKey.currentContext;
      
      if (context != null) {
        print('✅ [DEBUG] Navigator context found (attempt ${i + 1}), navigating to AffiliateScreen');
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AffiliateScreen(),
            ),
          );
          print('✅ [DEBUG] Navigation to AffiliateScreen completed successfully');
          return;
        } catch (e, stackTrace) {
          print('❌ [DEBUG] Error during navigation: $e');
          print('❌ [DEBUG] Stack trace: $stackTrace');
          return;
        }
      } else {
        if (i == 0) {
          print('⚠️ [DEBUG] Navigator context is null, retrying... (attempt ${i + 1}/$maxRetries)');
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    
    print('❌ [DEBUG] Failed to get navigator context after $maxRetries attempts');
  }

  void _navigateToProductDetail(int productId) {
    print('🚀 [DEBUG] _navigateToProductDetail called with productId: $productId');
    
    // Retry logic: Đợi context sẵn sàng (tối đa 3 giây)
    _tryNavigateWithRetry(productId, maxRetries: 30, delayMs: 100);
  }

  void _tryNavigateWithRetry(int productId, {int maxRetries = 30, int delayMs = 100}) async {
    for (int i = 0; i < maxRetries; i++) {
      final context = navigatorKey.currentContext;
      
      if (context != null) {
        print('✅ [DEBUG] Navigator context found (attempt ${i + 1}), navigating to ProductDetailScreen');
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: productId,
              ),
            ),
          );
          print('✅ [DEBUG] Navigation to ProductDetailScreen completed successfully');
          return;
        } catch (e, stackTrace) {
          print('❌ [DEBUG] Error during navigation: $e');
          print('❌ [DEBUG] Stack trace: $stackTrace');
          return;
        }
      } else {
        if (i == 0) {
          print('⚠️ [DEBUG] Navigator context is null, retrying... (attempt ${i + 1}/$maxRetries)');
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    
    print('❌ [DEBUG] Failed to get navigator context after $maxRetries attempts');
  }
}

