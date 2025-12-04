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

  /// Khởi tạo deep link handler
  Future<void> init() async {
    try {
      // Check initial link (app opened via link when closed)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
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
          print('❌ [DeepLink] Error listening to links: $err');
        },
      );
    } catch (e) {
      print('❌ [DeepLink] Error initializing: $e');
    }
  }

  /// Xử lý deep link
  void _handleDeepLink(String url) {
    try {
      final uri = Uri.parse(url);

      // Extract affiliate info from URL
      final affiliateId =
          uri.queryParameters['utm_source_shop'] ??
          uri.queryParameters['aff'] ??
          uri.queryParameters['ref'];

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
      print('❌ [DeepLink] Error handling deep link: $e');
    }
  }

  /// Xử lý custom URL scheme: socdo://product/123?aff=8050
  Future<void> _handleCustomSchemeLink(Uri uri, String? affiliateId) async {
    try {
      // Extract affiliate from URL or query params
      final aff =
          affiliateId ??
          uri.queryParameters['aff'] ??
          uri.queryParameters['utm_source_shop'];

      // Format: socdo://product/123 hoặc socdo://product/123?aff=8050
      // Custom scheme có thể có format: socdo://product/123 hoặc socdo://product/123/
      if (uri.host == 'product') {
        // Lấy product ID từ path
        int? productId;

        // Thử lấy từ pathSegments
        if (uri.pathSegments.isNotEmpty) {
          final productIdStr = uri.pathSegments.first;
          productId = int.tryParse(productIdStr);
        }

        // Nếu không có trong pathSegments, thử lấy từ path
        if (productId == null && uri.path.isNotEmpty) {
          final pathParts = uri.path
              .split('/')
              .where((p) => p.isNotEmpty)
              .toList();
          if (pathParts.isNotEmpty) {
            productId = int.tryParse(pathParts.first);
          }
        }

        // Nếu vẫn không có, thử parse từ toàn bộ host (backup)
        if (productId == null) {
          final fullPath = uri
              .toString()
              .replaceAll('socdo://product/', '')
              .split('?')
              .first;
          productId = int.tryParse(fullPath);
        }

        if (productId != null && productId > 0) {
          await _navigateToProduct(productId: productId, affiliateId: aff);
          return;
        }
      }
    } catch (e) {
      print('❌ [DeepLink] Error handling custom scheme: $e');
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

      // Nếu có affiliate_id trong query params, lưu lại
      if (affiliateId != null && affiliateId.isNotEmpty) {
        await _affiliateTracking.trackAffiliateClick(
          affiliateId: affiliateId,
          productId: null,
        );
      }

      _openWeb(uri.toString());
    } catch (e) {
      _openWeb(uri.toString());
    }
  }

  /// Resolve product slug thành product ID bằng search API
  /// Giống cách banner xử lý: search với slug để tìm product
  Future<int?> _resolveProductIdFromSlug(String slug) async {
    try {
      // Thử nhiều cách tìm kiếm:
      // 1. Search với toàn bộ slug
      // 2. Nếu không tìm thấy, thử search với vài từ đầu (tên sản phẩm chính)

      // Cách 1: Search với toàn bộ slug
      var searchResult = await _apiService.searchProducts(
        keyword: slug,
        page: 1,
        limit: 10, // Tăng limit để có nhiều kết quả hơn
      );

      if (searchResult != null && searchResult['success'] == true) {
        final data = searchResult['data'] as Map<String, dynamic>?;
        if (data != null) {
          final products = data['products'] as List?;

          if (products != null && products.isNotEmpty) {
            // Tìm product có slug match chính xác nhất
            // Slug trong URL affiliate: /product/{slug}.html
            // Trong DB, slug được lưu trong cột 'link'
            String slugLower = slug.toLowerCase();

            for (var product in products) {
              final productMap = product as Map<String, dynamic>;
              final productId = productMap['id'] as int?;

              // Check field 'link' (slug trong DB)
              final productLink =
                  productMap['link']?.toString().toLowerCase() ?? '';
              if (productLink.isNotEmpty && productLink == slugLower) {
                if (productId != null && productId > 0) {
                  return productId;
                }
              }

              // Check field 'slug' (nếu có)
              final productSlug =
                  productMap['slug']?.toString().toLowerCase() ?? '';
              if (productSlug.isNotEmpty && productSlug == slugLower) {
                if (productId != null && productId > 0) {
                  return productId;
                }
              }
            }

            // Fallback: Nếu không tìm thấy exact match, lấy product đầu tiên
            // (có thể là kết quả liên quan)
            final firstProduct = products.first as Map<String, dynamic>;
            final productId = firstProduct['id'] as int?;
            if (productId != null && productId > 0) {
              return productId;
            }
          }
        }
      }

      // Cách 2: Nếu slug quá dài, thử search với vài từ đầu (tên sản phẩm chính)
      // Ví dụ: "chi-ke-may-lau-troi-judydoll..." -> "chi-ke-may-lau-troi"
      if (slug.length > 30) {
        final words = slug.split('-');
        if (words.length > 3) {
          final shortSlug = words.take(5).join('-'); // Lấy 5 từ đầu
          print('🔍 [DeepLink] Trying shorter slug: $shortSlug');

          searchResult = await _apiService.searchProducts(
            keyword: shortSlug,
            page: 1,
            limit: 5,
          );

          if (searchResult != null && searchResult['success'] == true) {
            final data = searchResult['data'] as Map<String, dynamic>?;
            if (data != null) {
              final products = data['products'] as List?;
              if (products != null && products.isNotEmpty) {
                // Lấy product đầu tiên
                final firstProduct = products.first as Map<String, dynamic>;
                final productId = firstProduct['id'] as int?;
                if (productId != null && productId > 0) {
                  print(
                    '⚠️ [DeepLink] Using product ID from shorter slug: $productId',
                  );
                  return productId;
                }
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ [DeepLink] Error resolving slug: $e');
      return null;
    }
  }

  /// Navigate to product detail screen với affiliate tracking
  Future<void> _navigateToProduct({
    required int productId,
    String? affiliateId,
  }) async {
    try {
      // Track affiliate click
      if (affiliateId != null && affiliateId.isNotEmpty) {
        await _affiliateTracking.trackAffiliateClick(
          affiliateId: affiliateId,
          productId: productId,
        );
      }

      // Navigate to product detail
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: productId),
          ),
        );
      } else {
        // Retry after delay if context not ready
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToProduct(productId: productId, affiliateId: affiliateId);
      }
    } catch (e) {
      print('❌ [DeepLink] Error navigating to product: $e');
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
      print('❌ [DeepLink] Error opening web: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _sub?.cancel();
  }
}
