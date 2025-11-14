import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/banner.dart';
import '../../../core/services/cached_api_service.dart';
import '../../product/product_detail_screen.dart';
import '../../shop/shop_detail_screen.dart';

class PartnerBannerSlider extends StatefulWidget {
  const PartnerBannerSlider({super.key});

  @override
  State<PartnerBannerSlider> createState() => _PartnerBannerSliderState();
}

class _PartnerBannerSliderState extends State<PartnerBannerSlider> {
  final CachedApiService _cachedApiService = CachedApiService();
  List<BannerModel> _banners = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load ngay lập tức từ cache mà không gọi setState nhiều lần
    _loadBannersFromCache();
  }

  Future<void> _loadBannersFromCache() async {
    try {
      // Chỉ load từ cache, không gọi API
      final bannersData = await _cachedApiService.getHomePartnerBanners();
      
      if (mounted) {
        if (bannersData.isNotEmpty) {
          // Convert Map to BannerModel
          final banners = bannersData.map((data) => BannerModel.fromJson(data)).toList();
          
          setState(() {
            _banners = banners;
            _isLoading = false;
          });
          
          // print('✅ Partner banners loaded from cache (${banners.length} banners)');
        } else {
          // Fallback nếu không có cache
          setState(() {
            _isLoading = false;
          });
          // print('⚠️ No cached partner banners');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // print('❌ Error loading partner banners from cache: $e');
    }
  }

  Future<void> _handleBannerTap(BannerModel banner) async {
    try {
      // Nếu có product_id từ API (đã join với sanpham), dùng trực tiếp
      if (banner.productId != null && banner.productId! > 0) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: banner.productId,
            ),
          ),
        );
        return;
      }
      
      // Nếu không có product_id, parse từ link
      if (banner.link.isEmpty || banner.link.trim().isEmpty) return;
      
      final link = banner.link.trim();
      
      // Kiểm tra xem có phải link shop không
      if (link.contains('/shop/') && (link.startsWith('https://socdo.vn/shop/') || link.startsWith('https://www.socdo.vn/shop/'))) {
        // Extract shop username from URL
        // Example: https://socdo.vn/shop/username/san-pham.html
        final uri = Uri.parse(link);
        final segments = uri.pathSegments;
        
        if (segments.length >= 2 && segments[0] == 'shop') {
          final shopUsername = segments[1];
          // Navigate to shop detail screen
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
      
      // Kiểm tra xem có phải link sản phẩm không
      if (link.startsWith('https://socdo.vn/product/') || link.startsWith('https://www.socdo.vn/product/')) {
        // Extract product ID from URL
        // Examples: 
        // - https://socdo.vn/product/123 (old format with ID)
        // - https://socdo.vn/product/slug.html (new format with slug)
        
        final uri = Uri.parse(link);
        final segments = uri.pathSegments;
        
        if (segments.isNotEmpty && segments[0] == 'product') {
          if (segments.length >= 2) {
            // Try to parse as ID (old format)
            final productId = int.tryParse(segments[1]);
            if (productId != null) {
              // Navigate to product detail screen with ID
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    productId: productId,
                  ),
                ),
              );
              return;
            }
            // If not ID, could be slug - you might need to implement slug lookup
            // For now, just open in browser
          }
        }
      }
      
      // Mở link khác bằng web browser
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // print('❌ Lỗi khi mở link banner: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
  
    final screenWidth = MediaQuery.of(context).size.width;
    
    final bannerHeight = (screenWidth / 3).clamp(100.0, 150.0);

    // const double bannerHeight = 170.0;
    
    if (_isLoading) {
      return Container(
        height: bannerHeight,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          CarouselSlider.builder(
            itemCount: _banners.length,
            itemBuilder: (context, index, realIndex) {
              final banner = _banners[index];
              return GestureDetector(
                onTap: () => _handleBannerTap(banner),
                child: Container(
                  width: double.infinity,
                  height: bannerHeight,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: Image.network(
                      banner.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 40,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            options: CarouselOptions(
              height: bannerHeight,
              viewportFraction: 1.0,
              autoPlay: _banners.length > 1,
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
          
          // Dots indicator
          if (_banners.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _banners.length,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index 
                          ? Colors.white 
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}