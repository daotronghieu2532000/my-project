import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'affiliate_tracking_service.dart';
import '../services/notification_handler.dart';
import '../services/api_service.dart';
import '../../presentation/product/product_detail_screen.dart';

/// Service để xử lý deep links và affiliate tracking
class DeepLinkService {
  StreamSubscription? _sub;
  final AppLinks _appLinks = AppLinks();
  final AffiliateTrackingService _affiliateTracking =
      AffiliateTrackingService();
  final ApiService _apiService = ApiService();
  static final GlobalKey<NavigatorState> navigatorKey =
      NotificationHandler.navigatorKey;
  // Đánh dấu app được mở lần đầu từ deeplink (để SplashScreen biết và không auto về RootShell)
  static bool hasInitialDeepLink = false;

  // Debounce để tránh xử lý duplicate deep links
  String? _lastHandledUrl;
  DateTime? _lastHandledTime;
  static const _debounceDuration = Duration(seconds: 2);

  /// Khởi tạo deep link handler
  Future<void> init() async {
    try {
      // Check initial link (app opened via link when closed)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        // Đánh dấu app được mở từ deeplink để SplashScreen không auto điều hướng về RootShell
        hasInitialDeepLink = true;
        _handleDeepLink(initialUri.toString());
      }

      // Listen to incoming links (app opened via link when running)
      _sub = _appLinks.uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null) {
            _handleDeepLink(uri.toString());
          }
        },
        onError: (err) {
          // print('❌ [DeepLink] Error listening to links: $err');
        },
      );
    } catch (e) {
      // print('❌ [DeepLink] Error initializing: $e');
    }
  }

  /// Xử lý deep link với debounce để tránh duplicate
  void _handleDeepLink(String url) {
    try {
      final now = DateTime.now();
      
      // Debounce: Nếu cùng một URL được handle trong vòng 2 giây, bỏ qua
      if (_lastHandledUrl == url && 
          _lastHandledTime != null && 
          now.difference(_lastHandledTime!) < _debounceDuration) {
        // print('⏭️ [DeepLink] Skipping duplicate deep link: $url');
        return;
      }
      
      _lastHandledUrl = url;
      _lastHandledTime = now;
      
      final uri = Uri.parse(url);
      
      // print('🔗 [DeepLink] Handling URL: $url');
      // print('🔗 [DeepLink] Query parameters: ${uri.queryParameters}');

      // Extract affiliate info from URL
      final affiliateId =
          uri.queryParameters['utm_source_shop'] ??
          uri.queryParameters['aff'] ??
          uri.queryParameters['ref'];
      
      // print('🔗 [DeepLink] Extracted affiliate ID: $affiliateId');

      // Handle custom URL scheme: socdo://product/123?aff=8050
      if (uri.scheme == 'socdo') {
        _handleCustomSchemeLink(uri, affiliateId);
        return;
      }

      // Handle different URL patterns
      if (uri.host.contains('socdo.vn') || uri.host.contains('www.socdo.vn')) {
        _handleSocdoVnLink(uri, affiliateId);
      } else if (uri.host.contains('socdo.xyz')) {
        _handleShortLink(uri, affiliateId);
      }
    } catch (e) {
      // print('❌ [DeepLink] Error handling deep link: $e');
    }
  }

  /// Xử lý custom URL scheme: socdo://product/123?aff=8050 hoặc socdo://product/slug?aff=8050
  Future<void> _handleCustomSchemeLink(Uri uri, String? affiliateId) async {
    try {
      // print('🔗 [DeepLink] Custom scheme link: ${uri.toString()}');
      // print('🔗 [DeepLink] URI query parameters: ${uri.queryParameters}');
      
      // Extract affiliate from URL or query params
      final aff =
          affiliateId ??
          uri.queryParameters['aff'] ??
          uri.queryParameters['utm_source_shop'];
      
      // print('🔗 [DeepLink] Extracted affiliate ID: $aff');

      // Format: socdo://product/123 hoặc socdo://product/slug?aff=8050
      if (uri.host == 'product') {
        String? productIdentifier;
        
        // Lấy product identifier từ path (có thể là ID hoặc slug)
        if (uri.pathSegments.isNotEmpty) {
          productIdentifier = uri.pathSegments.first;
        } else if (uri.path.isNotEmpty) {
          final pathParts = uri.path
              .split('/')
              .where((p) => p.isNotEmpty)
              .toList();
          if (pathParts.isNotEmpty) {
            productIdentifier = pathParts.first;
          }
        }
        
        // Nếu vẫn không có, thử parse từ toàn bộ URL
        if (productIdentifier == null || productIdentifier.isEmpty) {
          final fullPath = uri
              .toString()
              .replaceAll('socdo://product/', '')
              .split('?')
              .first
              .replaceAll('/', '');
          if (fullPath.isNotEmpty) {
            productIdentifier = fullPath;
          }
        }

        if (productIdentifier == null || productIdentifier.isEmpty) {
          // print('⚠️ [DeepLink] Invalid custom scheme: no product identifier');
          return;
        }

        // print('🔗 [DeepLink] Product identifier: $productIdentifier');

        // ✅ Thử parse như product ID trước (số)
        final productId = int.tryParse(productIdentifier);

        if (productId != null && productId > 0) {
          // Là product ID - navigate trực tiếp
          // print('🔗 [DeepLink] Detected product ID: $productId');
          await _navigateToProduct(productId: productId, affiliateId: aff);
          return;
        }

        // ✅ Nếu không phải số, thì là slug - cần resolve sang product ID
        // print('🔗 [DeepLink] Detected slug: $productIdentifier, resolving...');
        final resolvedProductId = await _resolveProductIdFromSlug(productIdentifier);

        if (resolvedProductId != null && resolvedProductId > 0) {
          // Đã tìm thấy product ID từ slug
          // print('✅ [DeepLink] Resolved slug to product ID: $resolvedProductId');
          // Thêm delay nhỏ để đảm bảo app đã sẵn sàng
          await Future.delayed(const Duration(milliseconds: 300));
          await _navigateToProduct(productId: resolvedProductId, affiliateId: aff);
          return;
        }

        // Nếu không tìm thấy product, lưu affiliate (nếu có) và mở browser
        // print('⚠️ [DeepLink] Cannot resolve slug: $productIdentifier');
        if (aff != null && aff.isNotEmpty) {
          await _affiliateTracking.trackAffiliateClick(
            affiliateId: aff,
            productId: null,
          );
        }
        // Mở web URL tương ứng
        final webUrl = 'https://socdo.vn/product/$productIdentifier${aff != null ? '?utm_source_shop=$aff' : ''}';
        _openWeb(webUrl);
      }
    } catch (e) {
      // print('❌ [DeepLink] Error handling custom scheme: $e');
    }
  }

  /// Xử lý link từ socdo.vn
  Future<void> _handleSocdoVnLink(Uri uri, String? affiliateId) async {
    try {
      // Example: /product/chi-ke-may-lau-troi-judydoll...html?utm_source_shop=8050
      if (uri.path.startsWith('/product/')) {
        // Extract slug from path
        // Path format: /product/slug.html hoặc /product/123
        final pathParts = uri.path.split('/');
        if (pathParts.length >= 3) {
          final productIdentifier = pathParts[2]; // slug.html hoặc 123

          // Try to parse as product ID (old format)
          final productId = int.tryParse(productIdentifier);

          if (productId != null && productId > 0) {
            // Navigate directly với product ID
            await _navigateToProduct(
              productId: productId,
              affiliateId: affiliateId,
            );
            return;
          }

          // If not ID, it's a slug - cần resolve sang product ID
          final slug = productIdentifier.replaceAll('.html', '');

          if (slug.isNotEmpty) {
          

            // Resolve slug thành product ID bằng search API
            final productId = await _resolveProductIdFromSlug(slug);

            if (productId != null && productId > 0) {
              // Đã tìm thấy product ID → navigate đến product
              await _navigateToProduct(
                productId: productId,
                affiliateId: affiliateId,
              );
              return;
            }

            // Nếu không tìm thấy, lưu affiliate_id và mở browser
            if (affiliateId != null && affiliateId.isNotEmpty) {
              await _affiliateTracking.trackAffiliateClick(
                affiliateId: affiliateId,
                productId: null,
              );
            }

            _openWeb(uri.toString());
          }
        }
      } else {
        // Other paths - open in browser
        _openWeb(uri.toString());
      }
    } catch (e) {
      _openWeb(uri.toString());
    }
  }

  /// Xử lý short link từ socdo.xyz
  /// Short link sẽ redirect về URL dài, nên mở browser để web xử lý
  Future<void> _handleShortLink(Uri uri, String? affiliateId) async {
    try {
      // Example: https://socdo.xyz/x/ktgNV9
      // Short link sẽ redirect về product URL thật trên web
      // User có thể click lại link từ web để mở app
      
      // print('🔗 [DeepLink] Short link: ${uri.toString()}');
      // print('🔗 [DeepLink] Query params: ${uri.queryParameters}');
      // print('🔗 [DeepLink] Extracted affiliate ID: $affiliateId');
// 
      // Nếu có affiliate_id trong query params, lưu lại
      if (affiliateId != null && affiliateId.isNotEmpty) {
        // print('✅ [DeepLink] Lưu affiliate ID từ short link: $affiliateId');
        await _affiliateTracking.trackAffiliateClick(
          affiliateId: affiliateId,
          productId: null,
        );
      } else {
        // print('⚠️ [DeepLink] Short link KHÔNG có affiliate ID trong query params!');
        // print('⚠️ [DeepLink] Có thể server redirect không preserve utm_source_shop');
      }

      _openWeb(uri.toString());
    } catch (e) {
      // print('❌ [DeepLink] Error handling short link: $e');
      _openWeb(uri.toString());
    }
  }

  /// Resolve product slug thành product ID
  /// Sử dụng API resolveProductIdBySlug để query trực tiếp với field 'link' (giống banner)
  Future<int?> _resolveProductIdFromSlug(String slug) async {
    try {
      // print('🔍 [DeepLink] Resolving slug: $slug');
      
      // ✅ Cách 1: Dùng API resolveProductIdBySlug (query trực tiếp với WHERE link = slug)
      final productId = await _apiService.resolveProductIdBySlug(slug);
      
      if (productId != null && productId > 0) {
        // print('✅ [DeepLink] Resolved slug to product ID: $productId');
        return productId;
      }
      
      // print('⚠️ [DeepLink] Cannot resolve slug with direct query, trying fallback...');
      
      // ✅ Cách 2: Fallback - Thử search với exact match
      final searchResult = await _apiService.searchProducts(
        keyword: slug,
        page: 1,
        limit: 50, // Tăng limit để có nhiều kết quả hơn
      );

      if (searchResult != null && searchResult['success'] == true) {
        final data = searchResult['data'] as Map<String, dynamic>?;
        if (data != null) {
          final products = data['products'] as List?;

          if (products != null && products.isNotEmpty) {
            // Tìm exact match với field 'link' (slug trong DB)
            final slugLower = slug.toLowerCase();

            for (var product in products) {
              final productMap = product as Map<String, dynamic>;
              final productId = productMap['id'] as int?;

              // Check field 'link' (slug trong DB) - exact match
              final productLink = productMap['link']?.toString().toLowerCase() ?? '';
              if (productLink.isNotEmpty && productLink == slugLower) {
                if (productId != null && productId > 0) {
                  // print('✅ [DeepLink] Found exact match in search results: $productId');
                  return productId;
                }
              }

              // Check field 'slug' (nếu có) - exact match
              final productSlug = productMap['slug']?.toString().toLowerCase() ?? '';
              if (productSlug.isNotEmpty && productSlug == slugLower) {
                if (productId != null && productId > 0) {
                  // print('✅ [DeepLink] Found exact match (slug field): $productId');
                  return productId;
                }
              }
            }
          }
        }
      }

      // ✅ Cách 3: Nếu slug quá dài, thử search với vài từ đầu (tên sản phẩm chính)
      // Ví dụ: "chi-ke-may-lau-troi-judydoll..." -> "chi-ke-may-lau-troi"
      if (slug.length > 50) {
        final words = slug.split('-');
        if (words.length > 5) {
          final shortSlug = words.take(8).join('-'); // Lấy 8 từ đầu
          
          // print('🔍 [DeepLink] Trying with shorter slug: $shortSlug');
          
          final searchResult2 = await _apiService.searchProducts(
            keyword: shortSlug,
            page: 1,
            limit: 20,
          );

          if (searchResult2 != null && searchResult2['success'] == true) {
            final data2 = searchResult2['data'] as Map<String, dynamic>?;
            if (data2 != null) {
              final products2 = data2['products'] as List?;
              if (products2 != null && products2.isNotEmpty) {
                // Tìm exact match với slug đầy đủ trong kết quả
                final slugLower = slug.toLowerCase();
                for (var product in products2) {
                  final productMap = product as Map<String, dynamic>;
                  final productId = productMap['id'] as int?;
                  final productLink = productMap['link']?.toString().toLowerCase() ?? '';
                  
                  if (productLink.isNotEmpty && productLink == slugLower) {
                    if (productId != null && productId > 0) {
                      // print('✅ [DeepLink] Found exact match with shorter search: $productId');
                      return productId;
                    }
                  }
                }
              }
            }
          }
        }
      }

      // print('❌ [DeepLink] Cannot resolve slug: $slug');
      return null;
    } catch (e) {
      // print('❌ [DeepLink] Error resolving slug: $e');
      return null;
    }
  }

  /// Navigate to product detail screen với affiliate tracking
  Future<void> _navigateToProduct({
    required int productId,
    String? affiliateId,
    int retryCount = 0,
  }) async {
    try {
      // print('🚀 [DeepLink] Navigating to product ID: $productId, affiliate: $affiliateId');
      
      // Track affiliate click (chỉ track 1 lần, không track khi retry)
      if (retryCount == 0 && affiliateId != null && affiliateId.isNotEmpty) {
        // print('📝 [DeepLink] Tracking affiliate: affiliateId=$affiliateId, productId=$productId');
        await _affiliateTracking.trackAffiliateClick(
          affiliateId: affiliateId,
          productId: productId,
        );
        // print('✅ [DeepLink] Affiliate tracking saved');
      } else if (affiliateId == null || affiliateId.isEmpty) {
        // print('⚠️ [DeepLink] Không có affiliate ID để track');
      }

      // Kiểm tra xem context đã sẵn sàng chưa
      var context = navigatorKey.currentContext;
      
      // Nếu context chưa sẵn sàng, đợi app init (SplashScreen: 3.5 giây)
      if (context == null) {
        // print('⏳ [DeepLink] App is starting, waiting 3500ms for initialization...');
        await Future.delayed(const Duration(milliseconds: 3500));
        context = navigatorKey.currentContext;
      } else {
        // App đã mở sẵn, chỉ đợi một chút để đảm bảo
        // print('✅ [DeepLink] App already running, waiting 500ms...');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Navigate to product detail
      if (context != null) {
        // print('✅ [DeepLink] Navigator context ready, pushing ProductDetailScreen...');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: productId),
          ),
        );
        // print('✅ [DeepLink] Navigation completed');
      } else {
        // Nếu context chưa sẵn sàng sau 4 giây, retry thêm 2 lần nữa
        if (retryCount < 2) {
          final delay = 1000; // 1 giây mỗi lần retry
          // print('⏳ [DeepLink] Navigator context not ready, retrying in ${delay}ms...');
          await Future.delayed(Duration(milliseconds: delay));
          await _navigateToProduct(
            productId: productId,
            affiliateId: affiliateId,
            retryCount: retryCount + 1,
          );
        } else {
          // print('❌ [DeepLink] Navigation failed - context not available');
        }
      }
    } catch (e, stackTrace) {
      // print('❌ [DeepLink] Error navigating to product: $e');
      // print('❌ [DeepLink] Stack trace: $stackTrace');
    }
  }

  /// Open URL in browser (fallback)
  Future<void> _openWeb(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // print('❌ [DeepLink] Error opening web: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _sub?.cancel();
  }
}
