import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/popup_banner.dart';
import '../../../core/services/api_service.dart';
import '../../product/product_detail_screen.dart';
import '../../shop/shop_detail_screen.dart';

class PopupBannerWidget extends StatefulWidget {
  final PopupBanner popupBanner;
  final VoidCallback onClose;

  const PopupBannerWidget({
    super.key,
    required this.popupBanner,
    required this.onClose,
  });

  @override
  State<PopupBannerWidget> createState() => _PopupBannerWidgetState();
}

class _PopupBannerWidgetState extends State<PopupBannerWidget> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Kích thước popup theo tỉ lệ 1:1.5 (width:height)
    // Popup dọc, height = width * 1.5
    // Căn giữa màn hình
    final popupWidth = screenWidth * 0.80; // 80% chiều rộng màn hình
    final popupHeight = popupWidth * 1.5; // Tỉ lệ 1:1.5 (width:height)
    
    // Đảm bảo không quá cao (tối đa 70% chiều cao màn hình)
    final maxHeight = screenHeight * 0.70;
    final finalHeight = popupHeight > maxHeight ? maxHeight : popupHeight;
    
    return Material(
      color: Colors.black.withOpacity(0.5), // Backdrop mờ
      child: Stack(
        children: [
          // Backdrop - click để đóng
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Popup content - căn giữa màn hình
          Center(
            child: Stack(
              clipBehavior: Clip.none, // Cho phép nút X nằm ngoài
              children: [
                // Banner container
                Container(
                  width: popupWidth,
                  height: finalHeight,
                  constraints: BoxConstraints(
                    maxWidth: screenWidth * 0.85,
                    maxHeight: maxHeight,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Banner image - click để mở link
                        GestureDetector(
                          onTap: () async {
                            if (_isLoading) return;
                            
                            setState(() {
                              _isLoading = true;
                            });
                            
                            // Tăng click_count
                            final clickSuccess = await _apiService.incrementPopupBannerClick(
                              popupId: widget.popupBanner.id,
                            );
                            
                            if (clickSuccess) {
                              print('✅ Click count updated successfully');
                            } else {
                              print('⚠️ Failed to update click count, but continuing...');
                            }
                            
                            // Xử lý navigation
                            if (widget.popupBanner.targetUrl != null && 
                                widget.popupBanner.targetUrl!.isNotEmpty) {
                              print('🔗 [DEBUG] Target URL exists: ${widget.popupBanner.targetUrl}');
                              await _handleTargetUrl(context, widget.popupBanner.targetUrl!);
                            } else {
                              print('⚠️ [DEBUG] No target URL provided');
                            }
                            
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                              widget.onClose();
                            }
                          },
                          child: CachedNetworkImage(
                            imageUrl: widget.popupBanner.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.error,
                                color: Colors.grey,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                        // Loading overlay khi click
                        if (_isLoading)
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Close button - nút X nằm ở góc trên bên phải, bên ngoài banner (giống Shopee)
                Positioned(
                  top: -12, // Nằm ngoài banner
                  right: -12,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF666666), // Màu xám đậm
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTargetUrl(BuildContext context, String? targetUrl) async {
    try {
      print('🔗 [DEBUG] Handling target URL: $targetUrl');
      
      // Nếu có product_id từ API (đã join với sanpham), dùng trực tiếp (giống partner_banner_slider.dart)
      if (widget.popupBanner.productId != null && widget.popupBanner.productId! > 0) {
        print('🔗 [DEBUG] Using productId from API: ${widget.popupBanner.productId}');
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: widget.popupBanner.productId,
              ),
            ),
          );
        }
        return;
      }
      
      // Nếu không có product_id, parse từ link
      if (targetUrl == null || targetUrl.isEmpty || targetUrl.trim().isEmpty) {
        print('⚠️ [DEBUG] Target URL is empty');
        return;
      }
      
      final link = targetUrl.trim();
      
      // Chuẩn hóa URL: thêm https:// nếu thiếu protocol và không phải relative path
      String normalizedUrl = link;
      if (!link.startsWith('http://') && 
          !link.startsWith('https://') && 
          !link.startsWith('/')) {
        // Nếu không có protocol và không phải relative path, thêm https://
        normalizedUrl = 'https://$link';
        print('🔗 [DEBUG] Added protocol, normalized URL: $normalizedUrl');
      } else {
        normalizedUrl = link;
      }
      
      // Kiểm tra xem có phải link shop không (giống partner_banner_slider.dart)
      if (normalizedUrl.contains('/shop/') && 
          (normalizedUrl.startsWith('https://socdo.vn/shop/') || 
           normalizedUrl.startsWith('https://www.socdo.vn/shop/') ||
           normalizedUrl.startsWith('http://socdo.vn/shop/') ||
           normalizedUrl.startsWith('http://www.socdo.vn/shop/'))) {
        // Extract shop username from URL
        // Example: https://socdo.vn/shop/username/san-pham.html
        final uri = Uri.parse(normalizedUrl);
        final segments = uri.pathSegments;
        
        if (segments.isNotEmpty && segments[0] == 'shop' && segments.length >= 2) {
          final shopUsername = segments[1];
          print('🔗 [DEBUG] Navigating to ShopDetailScreen with username: $shopUsername');
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ShopDetailScreen(
                  shopId: null, // Will be resolved by API using username
                  shopUsername: shopUsername,
                  shopName: shopUsername, // Temporary, will be loaded by API
                ),
              ),
            );
            return;
          }
        }
      }
      
      // Kiểm tra xem có phải link sản phẩm không (giống partner_banner_slider.dart)
      if (normalizedUrl.startsWith('https://socdo.vn/product/') || 
          normalizedUrl.startsWith('https://www.socdo.vn/product/') ||
          normalizedUrl.startsWith('http://socdo.vn/product/') ||
          normalizedUrl.startsWith('http://www.socdo.vn/product/')) {
        // Extract product ID from URL
        // Examples: 
        // - https://socdo.vn/product/123 (old format with ID)
        // - https://socdo.vn/product/slug.html (new format with slug)
        
        final uri = Uri.parse(normalizedUrl);
        final segments = uri.pathSegments;
        
        if (segments.isNotEmpty && segments[0] == 'product' && segments.length >= 2) {
          // Try to parse as ID (old format)
          final productId = int.tryParse(segments[1]);
          if (productId != null && productId > 0) {
            // Navigate to product detail screen with ID
            print('🔗 [DEBUG] Navigating to ProductDetailScreen with productId: $productId');
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    productId: productId,
                  ),
                ),
              );
              return;
            }
          }
          // If not ID, could be slug - for now, just open in browser
          print('⚠️ [DEBUG] Product slug detected, opening in browser: ${segments[1]}');
        }
      }
      
      // Mở link khác bằng web browser (fallback)
      print('🔗 [DEBUG] Opening external URL: $normalizedUrl');
      final uri = Uri.parse(normalizedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ [DEBUG] Successfully opened URL: $normalizedUrl');
      } else {
        print('❌ [DEBUG] Cannot launch URL: $normalizedUrl');
      }
    } catch (e, stackTrace) {
      print('❌ [DEBUG] Error handling target URL: $e');
      print('❌ [DEBUG] Stack trace: $stackTrace');
      print('❌ [DEBUG] Target URL: $targetUrl');
    }
  }
}

