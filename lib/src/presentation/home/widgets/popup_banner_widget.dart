import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/popup_banner.dart';
import '../../product/product_detail_screen.dart';

class PopupBannerWidget extends StatelessWidget {
  final PopupBanner popupBanner;
  final VoidCallback onClose;

  const PopupBannerWidget({
    super.key,
    required this.popupBanner,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.transparent,
            ),
          ),
          // Popup content
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 600,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Close button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Image
                  GestureDetector(
                    onTap: () {
                      // Nếu có target_url, xử lý navigation
                      if (popupBanner.targetUrl != null) {
                        _handleTargetUrl(context, popupBanner.targetUrl!);
                      }
                      onClose();
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: popupBanner.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          height: 400,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 400,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.error,
                            color: Colors.grey,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTargetUrl(BuildContext context, String targetUrl) {
    // Parse URL để xác định loại navigation
    if (targetUrl.contains('/product/') || targetUrl.contains('product_id=')) {
      // Extract product ID từ URL
      int? productId;
      
      // Try to extract from URL like: /product/123 or product_id=123
      final productIdMatch = RegExp(r'product[_\s/]?id[=:]?(\d+)', caseSensitive: false)
          .firstMatch(targetUrl);
      if (productIdMatch != null) {
        productId = int.tryParse(productIdMatch.group(1)!);
      } else {
        // Try to extract from slug URL: /product/slug.html
        final slugMatch = RegExp(r'/product/([^/\.]+)').firstMatch(targetUrl);
        if (slugMatch != null) {
          // TODO: Query product ID from slug if needed
          // For now, we'll just navigate to home
        }
      }
      
      if (productId != null && productId > 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: productId,
            ),
          ),
        );
      }
    } else if (targetUrl.startsWith('http://') || targetUrl.startsWith('https://')) {
      // External URL - có thể mở trong browser
      // TODO: Implement URL launcher if needed
      print('🔗 External URL: $targetUrl');
    }
  }
}

