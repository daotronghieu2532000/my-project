import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/brand.dart';
import '../../../core/services/cached_api_service.dart';
import '../../product/product_detail_screen.dart';
import '../../shop/shop_detail_screen.dart';

class FeaturedBrandsSlider extends StatefulWidget {
  const FeaturedBrandsSlider({super.key});

  @override
  State<FeaturedBrandsSlider> createState() => _FeaturedBrandsSliderState();
}

class _FeaturedBrandsSliderState extends State<FeaturedBrandsSlider> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  final CachedApiService _cachedApiService = CachedApiService();
  List<Brand> _brands = [];
  bool _isLoading = true;
  bool _hasLoadedOnce = false; // Flag để tránh load lại khi rebuild
  
  // Auto scroll controller - khởi tạo ngay để tránh late initialization error
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _isUserScrolling = false;
  final bool _isPaused = false;
  
  // Item width + margin
  static const double _itemWidth = 80.0;
  static const double _itemMargin = 12.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load ngay lập tức từ cache mà không gọi setState nhiều lần
    _loadBrandsFromCache();
  }
  
  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  DateTime? _lastScrollTime;
  double _lastScrollOffset = 0;
  
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final now = DateTime.now();
    final currentOffset = _scrollController.offset;
    
    // Detect khi user scroll (không phải auto scroll)
    // Auto scroll tăng dần từ từ, user scroll thay đổi nhanh hoặc giảm
    if (_lastScrollTime != null) {
      final timeDiff = now.difference(_lastScrollTime!).inMilliseconds;
      final offsetDiff = (currentOffset - _lastScrollOffset).abs();
      
      // Nếu scroll quá nhanh hoặc scroll ngược (giảm offset) = user scroll
      if (timeDiff < 100 && (offsetDiff > 5 || currentOffset < _lastScrollOffset)) {
        if (!_isUserScrolling) {
          _isUserScrolling = true;
          _pauseAutoScroll();
        }
      }
    }
    
    _lastScrollTime = now;
    _lastScrollOffset = currentOffset;
  }
  
  void _startAutoScroll() {
    if (_brands.isEmpty || _isPaused) return;
    
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!_isUserScrolling && mounted && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        
        // Scroll từ từ (0.5 pixel mỗi 30ms = ~16.7 pixels/giây)
        double newOffset = currentScroll + 0.5;
        
        // Nếu đến cuối (vượt quá 1/3 chiều dài - tức là phần duplicate đầu tiên đã hết)
        // thì reset về đầu một cách mượt mà
        final oneThirdLength = maxScroll / 3;
        if (newOffset >= oneThirdLength * 2) {
          // Reset về đầu của phần duplicate đầu tiên (bỏ qua phần đầu tiên)
          _scrollController.jumpTo(oneThirdLength);
          newOffset = oneThirdLength;
        }
        
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            newOffset,
            duration: const Duration(milliseconds: 30),
            curve: Curves.linear,
          );
        }
      }
    });
  }
  
  void _pauseAutoScroll() {
    _autoScrollTimer?.cancel();
    // Resume sau 2 giây khi user không scroll nữa
    Timer(const Duration(seconds: 2), () {
      if (mounted && !_isUserScrolling) {
        _isUserScrolling = false;
        if (_scrollController.hasClients) {
          // Đảm bảo scroll position hợp lý trước khi resume
          final maxScroll = _scrollController.position.maxScrollExtent;
          final currentScroll = _scrollController.offset;
          final oneThirdLength = maxScroll / 3;
          
          // Nếu đang ở phần cuối, reset về phần giữa
          if (currentScroll >= oneThirdLength * 2) {
            _scrollController.jumpTo(oneThirdLength);
          }
        }
        _startAutoScroll();
      }
    });
  }

  Future<void> _loadBrandsFromCache() async {
    try {
      // Nếu đã load rồi và có dữ liệu, không load lại (tránh gọi API khi scroll)
      if (_hasLoadedOnce && _brands.isNotEmpty) {
        return;
      }
      
      // Chỉ load từ cache, không gọi API
      final brandsData = await _cachedApiService.getHomeFeaturedBrands(forceRefresh: false);
      
      if (mounted) {
        if (brandsData.isNotEmpty) {
          // Convert Map to Brand
          final brands = brandsData.map((data) => Brand.fromJson(data)).toList();
          
          setState(() {
            _brands = brands;
            _isLoading = false;
            _hasLoadedOnce = true; // Đánh dấu đã load
          });
          
          // Bắt đầu auto scroll sau khi load xong
          if (mounted && _brands.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                // Bắt đầu từ phần giữa (duplicate đầu tiên) để có thể scroll cả 2 hướng
                final maxScroll = _scrollController.position.maxScrollExtent;
                final oneThirdLength = maxScroll / 3;
                _scrollController.jumpTo(oneThirdLength);
              }
              _startAutoScroll();
            });
          }
          
          // print('✅ Featured brands loaded from cache (${brands.length} brands)');
        } else {
          // Fallback nếu không có cache
          setState(() {
            _isLoading = false;
          });
          // print('⚠️ No cached featured brands');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // print('❌ Error loading featured brands from cache: $e');
    }
  }

  Future<void> _handleBrandTap(Brand brand) async {
    try {
      // Lấy link từ brand (ưu tiên link, nếu không có thì dùng url)
      // Note: url field có thể có lỗi format (ví dụ: "https://socdo.vnhttps://socdo.vn")
      // nên ưu tiên dùng link field
      String link = brand.link.isNotEmpty ? brand.link : brand.url;
      
      if (link.isEmpty || link.trim().isEmpty) return;
      
      final linkTrimmed = link.trim();
      
      // Kiểm tra nếu là trang chủ socdo.vn - không cần làm gì cả (user đang ở trang chủ rồi)
      if (linkTrimmed == 'https://socdo.vn' || 
          linkTrimmed == 'https://socdo.vn/' ||
          linkTrimmed == 'https://www.socdo.vn' ||
          linkTrimmed == 'https://www.socdo.vn/') {
        // User đang ở trang chủ rồi, không cần navigate
        return;
      }
      
      // Kiểm tra xem có phải link shop không
      if (linkTrimmed.contains('/shop/') && 
          (linkTrimmed.startsWith('https://socdo.vn/shop/') || 
           linkTrimmed.startsWith('https://www.socdo.vn/shop/'))) {
        // Extract shop username from URL
        // Example: https://socdo.vn/shop/username/san-pham.html
        final uri = Uri.parse(linkTrimmed);
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
      if (linkTrimmed.startsWith('https://socdo.vn/product/') || 
          linkTrimmed.startsWith('https://www.socdo.vn/product/')) {
        // Extract product ID from URL
        // Examples: 
        // - https://socdo.vn/product/123 (old format with ID)
        // - https://socdo.vn/product/slug.html (new format with slug)
        
        final uri = Uri.parse(linkTrimmed);
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
      
      // Kiểm tra xem có phải link search không
      // Format: https://socdo.vn/tim-kiem.html?key=Chilux
      if (linkTrimmed.contains('/tim-kiem') || linkTrimmed.contains('/tim-kiem.html')) {
        // Xử lý link search - có thể navigate đến trang search trong app
        // Tạm thời mở bằng browser
        final fullUrl = linkTrimmed.startsWith('http') 
            ? linkTrimmed 
            : 'https://socdo.vn$linkTrimmed';
        final uri = Uri.parse(fullUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
      }
      
      // Kiểm tra xem có phải link danh mục sản phẩm theo brand không
      // Format: /san-pham?brand={id}
      if (linkTrimmed.contains('/san-pham') && linkTrimmed.contains('brand=')) {
        final uri = Uri.parse(linkTrimmed);
        final brandIdParam = uri.queryParameters['brand'];
        if (brandIdParam != null) {
          // Có thể navigate đến trang danh sách sản phẩm theo brand
          // Tạm thời mở bằng browser
          final fullUrl = linkTrimmed.startsWith('http') 
              ? linkTrimmed 
              : 'https://socdo.vn$linkTrimmed';
          final uri = Uri.parse(fullUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return;
        }
      }
      
      // Mở link khác bằng web browser (external links hoặc các link khác)
      final fullUrl = linkTrimmed.startsWith('http') 
          ? linkTrimmed 
          : 'https://socdo.vn$linkTrimmed';
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // print('❌ Lỗi khi mở link brand: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Bắt buộc cho AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return Container(
        height: 120,
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_brands.isEmpty) {
      return const SizedBox.shrink();
    }

    // Tạo infinite list bằng cách duplicate brands 3 lần
    final infiniteBrands = [..._brands, ..._brands, ..._brands];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'THƯƠNG HIỆU ƯA CHUỘNG',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Horizontal scrollable brands với auto scroll
          SizedBox(
            height: 110, // Tăng chiều cao để có chỗ cho tên thương hiệu
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const BouncingScrollPhysics(), // Hiệu ứng bounce
              itemCount: infiniteBrands.length,
              itemBuilder: (context, index) {
                final brand = infiniteBrands[index];
                
                return GestureDetector(
                  onTap: () => _handleBrandTap(brand),
                  child: Container(
                    width: _itemWidth,
                    margin: EdgeInsets.only(
                      right: index == infiniteBrands.length - 1 ? 12 : _itemMargin,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo container
                        Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: brand.logo.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: brand.logo,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[100],
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[100],
                                      child: const Icon(
                                        Icons.business,
                                        color: Colors.grey,
                                        size: 28,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[100],
                                    child: const Icon(
                                      Icons.business,
                                      color: Colors.grey,
                                      size: 28,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Tên thương hiệu
                        SizedBox(
                          width: _itemWidth,
                          child: Text(
                            brand.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

