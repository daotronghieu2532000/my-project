import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/banner_products.dart';
import '../../../core/models/product_suggest.dart';
import '../../../core/services/cached_api_service.dart';
import '../../product/product_detail_screen.dart';
import '../../shop/shop_detail_screen.dart';
import '../widgets/banner_product_card.dart';

class BannerProductsWidget extends StatefulWidget {
  final String position; // dau_trang, giua_trang, cuoi_trang

  const BannerProductsWidget({super.key, required this.position});

  @override
  State<BannerProductsWidget> createState() => _BannerProductsWidgetState();
}

class _BannerProductsWidgetState extends State<BannerProductsWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  final CachedApiService _cachedApiService = CachedApiService();
  BannerProducts? _bannerProducts;
  bool _isLoading = true;
  bool _hasLoadedOnce = false; // Flag để tránh load lại khi rebuild
  final ScrollController _productsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Chỉ load ngay nếu là banner đầu trang, các vị trí khác load lazy
    if (widget.position == 'dau_trang') {
      _loadBannerProductsFromCache();
    } else {
      // Delay load cho banner giữa/cuối trang để tăng tốc trang chủ
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
    _loadBannerProductsFromCache();
        }
      });
    }
  }

  @override
  void didUpdateWidget(BannerProductsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu key thay đổi (refresh), reset và load lại
    if (oldWidget.key != widget.key) {
      setState(() {
        _hasLoadedOnce = false;
        _bannerProducts = null;
        _isLoading = true;
      });
      // Load lại với force refresh
      _loadBannerProducts();
    }
  }

  @override
  void dispose() {
    _productsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Bắt buộc cho AutomaticKeepAliveClientMixin
    return _buildContent();
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox.shrink(); // Không hiển thị loading để tránh flash
    }

    if (_bannerProducts == null) {
      return const SizedBox.shrink(); // Không hiển thị nếu không có banner
    }

    final banner = _bannerProducts!;
    final screenWidth = MediaQuery.of(context).size.width;

    // Banner dọc
    if (banner.isVerticalBanner) {
      final bannerWidth = (screenWidth - 16) / 2;

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề
            _buildTitle(),
            const SizedBox(height: 8),
            // Banner và sản phẩm
            _BannerVerticalWithHeight(
          bannerUrl: banner.bannerUrl,
          bannerWidth: bannerWidth,
          onTap: _handleBannerTap,
          products: banner.products,
          cardWidth: bannerWidth,
            ),
          ],
        ),
      );
    }

    //Chiều cao Banner ngang 
    if (banner.isHorizontalBanner) {
      final bannerHeight = 105.0;

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề
            _buildTitle(),
            const SizedBox(height: 8),
            // Banner ngang
            GestureDetector(
              onTap: _handleBannerTap,
              child: Container(
                width: double.infinity,
                height: bannerHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2), // Border width
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    banner.bannerUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
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
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Sản phẩm - cuộn ngang với height tự động
            _BannerProductsHorizontalList(
              key: ValueKey('banner_products_horizontal_${widget.position}'),
              products: banner.products,
              cardWidth: (screenWidth - 16) / 2,
              showNextArrow: false,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTitle() {
    // Lấy tiêu đề dựa trên position
    String title = _getTitleByPosition();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  String _getTitleByPosition() {
    if (_bannerProducts == null) {
      return 'SOCDO CHOICE'; // Default
    }
    
    switch (_bannerProducts!.position) {
      case 'dau_trang':
        return 'NHÀ BÁN TIỀM NĂNG';
      case 'giua_trang':
        return 'SOCDO CHOICE';
      case 'cuoi_trang':
        return 'NHÀ BÁN MỚI LÊN SÀN';
      default:
        return 'SOCDO CHOICE';
    }
  }

  Future<void> _loadBannerProductsFromCache() async {
    try {
      // Nếu đã load rồi và có dữ liệu, không load lại (tránh gọi API khi scroll)
      if (_hasLoadedOnce && _bannerProducts != null) {
    
        return;
      }
      
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      // Chỉ load từ cache (không force refresh)
      final result = await _cachedApiService.getBannerProductsCached(
        viTriHienThi: widget.position,
        forceRefresh: false,
      );
      
      if (!mounted) return;
      
      if (result != null && result.containsKey(widget.position)) {
        final bannerProduct = result[widget.position];
        
        if (bannerProduct != null && bannerProduct.isValid) {
          setState(() {
            _isLoading = false;
            _bannerProducts = bannerProduct;
            _hasLoadedOnce = true; // Đánh dấu đã load
          });
        
        } else {
          setState(() {
            _isLoading = false;
            _bannerProducts = null;
          });
         
        }
      } else {
        setState(() {
          _isLoading = false;
          _bannerProducts = null;
        });
       
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
     
    }
  }

  Future<void> _loadBannerProducts() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      // Sử dụng cached API service với force refresh
      final result = await _cachedApiService.getBannerProductsCached(
        viTriHienThi: widget.position,
        forceRefresh: true,
      );

      if (!mounted) return;

    

      if (result != null && result.containsKey(widget.position)) {
        final bannerProduct = result[widget.position];
      

        // Kiểm tra banner còn hiệu lực không
        if (bannerProduct != null) {
         

          if (bannerProduct.isValid) {
            setState(() {
              _bannerProducts = bannerProduct;
              _isLoading = false;
              _hasLoadedOnce = true; // Đánh dấu đã load
            });
          
          } else {
          
            setState(() {
              _bannerProducts = null;
              _isLoading = false;
            });
          }
        } else {
         
          setState(() {
            _bannerProducts = null;
            _isLoading = false;
          });
        }
      } else {
       
        setState(() {
          _bannerProducts = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    
    }
  }

  Future<void> _handleBannerTap() async {
    if (_bannerProducts?.bannerLink == null ||
        _bannerProducts!.bannerLink!.isEmpty) {
      return;
    }

    try {
      final link = _bannerProducts!.bannerLink!.trim();

      // Kiểm tra xem có phải link shop không
      if (link.contains('/shop/') &&
          (link.startsWith('https://socdo.vn/shop/') ||
              link.startsWith('https://www.socdo.vn/shop/'))) {
        final uri = Uri.parse(link);
        final segments = uri.pathSegments;

        if (segments.length >= 2 && segments[0] == 'shop') {
          final shopUsername = segments[1];
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ShopDetailScreen(
                shopId: null,
                shopUsername: shopUsername,
                shopName: shopUsername,
              ),
            ),
          );
          return;
        }
      }

      // Kiểm tra xem có phải link sản phẩm không
      if (link.startsWith('https://socdo.vn/product/') ||
          link.startsWith('https://www.socdo.vn/product/')) {
        final uri = Uri.parse(link);
        final segments = uri.pathSegments;

        if (segments.isNotEmpty && segments[0] == 'product') {
          if (segments.length >= 2) {
            final productId = int.tryParse(segments[1]);
            if (productId != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ProductDetailScreen(productId: productId),
                ),
              );
              return;
            }
          }
        }
      }

      // Mở link khác bằng web browser
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
     
    }
  }
}

// Helper widget để banner dọc tự động khớp chiều cao với product card
class _BannerVerticalWithHeight extends StatefulWidget {
  final String bannerUrl;
  final double bannerWidth;
  final VoidCallback onTap;
  final List<ProductSuggest> products;
  final double cardWidth;

  const _BannerVerticalWithHeight({
    required this.bannerUrl,
    required this.bannerWidth,
    required this.onTap,
    required this.products,
    required this.cardWidth,
  });

  @override
  State<_BannerVerticalWithHeight> createState() => _BannerVerticalWithHeightState();
}

class _BannerVerticalWithHeightState extends State<_BannerVerticalWithHeight> {
  double? _productCardHeight;
  final GlobalKey _productCardKey = GlobalKey();
  final GlobalKey<_BannerProductsHorizontalListState> _productsListKey = GlobalKey<_BannerProductsHorizontalListState>();

  @override
  void initState() {
    super.initState();
    // Đo height của product card sau khi build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureProductCardHeight();
    });
  }

  void _measureProductCardHeight() {
    final RenderBox? renderBox = _productCardKey.currentContext?.findRenderObject() as RenderBox?;
    // Kiểm tra renderBox đã được laid out và có size chưa
    if (renderBox != null && renderBox.hasSize && mounted) {
      setState(() {
        _productCardHeight = renderBox.size.height;
      });
    } else if (mounted) {
      // Nếu chưa laid out, đợi thêm một frame nữa
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureProductCardHeight();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trường hợp không có sản phẩm, vẫn hiển thị banner dọc
    if (widget.products.isEmpty) {
      final fallbackHeight = widget.bannerWidth * 1.2; // tỷ lệ dọc
      return _buildBannerOnly(fallbackHeight);
    }

    // Nếu chưa đo được height, hiển thị card mẫu để đo (ẩn bằng Offstage)
    if (_productCardHeight == null && widget.products.isNotEmpty) {
      return Offstage(
        child: SizedBox(
          width: widget.cardWidth,
          child: Container(
            key: _productCardKey,
            child: BannerProductCard(
              product: widget.products.first,
              index: 0,
            ),
          ),
        ),
      );
    }

    // Hiển thị banner và ListView với height đã đo được
    if (_productCardHeight == null) {
      return const SizedBox.shrink();
    }

    final bannerHeight = _productCardHeight!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner dọc với height khớp product card
        _buildBannerWithNextButton(bannerHeight),
        const SizedBox(width: 8),
        // Sản phẩm - cuộn ngang với height đã đo
        Expanded(
          child: SizedBox(
            height: bannerHeight,
            child: _BannerProductsHorizontalList(
              key: _productsListKey,
              products: widget.products,
              cardWidth: widget.cardWidth,
              showNextArrow: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerOnly(double bannerHeight) {
    return Container(
      width: widget.bannerWidth,
      height: bannerHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: SweepGradient(
          center: Alignment.center,
          startAngle: 0,
          endAngle: 2 * 3.14159,
          colors: const [
            Color(0xFFFF0080),
            Color(0xFFFF8000),
            Color(0xFFFFD700),
            Color(0xFF00FF80),
            Color(0xFF0080FF),
            Color(0xFF8000FF),
            Color(0xFFFF0080),
          ],
          stops: const [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          widget.bannerUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.fill,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: double.infinity,
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
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBannerWithNextButton(double bannerHeight) {
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: _buildBannerOnly(bannerHeight),
        ),
      ],
    );
  }
}

// Helper widget để đo height thực tế của card và hiển thị ListView ngang
class _BannerProductsHorizontalList extends StatefulWidget {
  final List<ProductSuggest> products;
  final double cardWidth;
  final bool showNextArrow;

  const _BannerProductsHorizontalList({
    super.key,
    required this.products,
    required this.cardWidth,
    this.showNextArrow = true,
  });

  @override
  State<_BannerProductsHorizontalList> createState() => _BannerProductsHorizontalListState();
}

class _BannerProductsHorizontalListState extends State<_BannerProductsHorizontalList> {
  double? _measuredHeight;
  final GlobalKey _measureKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  int _measureAttempts = 0;
  static const int _maxMeasureAttempts = 5;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    // Reset scroll về đầu khi init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetScrollPosition();
      _measureCardHeight();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset scroll mỗi khi widget được build lại (khi app resume hoặc widget được giữ lại)
    // Đảm bảo scroll luôn bắt đầu từ đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetScrollPosition();
    });
  }

  void _resetScrollPosition() {
    if (_scrollController.hasClients && mounted) {
      _scrollController.jumpTo(0);
    } else if (mounted) {
      // Nếu chưa có clients, thử lại sau
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _measureCardHeight() {
    final RenderBox? renderBox = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize && mounted) {
      setState(() {
        _measuredHeight = renderBox.size.height;
        _measureAttempts = 0; // Reset counter khi đo thành công
      });
      // Sau khi đo xong, cập nhật trạng thái hiển thị mũi tên
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    } else if (renderBox != null && !renderBox.hasSize && mounted && _measureAttempts < _maxMeasureAttempts) {
      // Nếu chưa có size, đợi thêm một frame nữa (giới hạn số lần thử)
      _measureAttempts++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _measureCardHeight();
        }
      });
    } else if (_measureAttempts >= _maxMeasureAttempts && mounted) {
      // Nếu đã thử quá nhiều lần mà vẫn không đo được, sử dụng giá trị mặc định
      setState(() {
        _measuredHeight = 200.0; // Giá trị mặc định
      });
    }
  }

  void _handleScroll() {
    _updateScrollIndicators();
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    final offset = position.pixels;

    final canScrollRight = offset < maxExtent - 4;

    if (canScrollRight != _canScrollRight) {
      setState(() {
        _canScrollRight = canScrollRight;
      });
    }
  }

  Future<void> scrollNext() async {
    if (!_scrollController.hasClients || !_canScrollRight) return;
    final position = _scrollController.position;
    final step = widget.cardWidth + 8; // card width + margin
    final target = (position.pixels + step).clamp(0.0, position.maxScrollExtent);
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nếu chưa đo được height, hiển thị card mẫu để đo (ẩn bằng Offstage)
    if (_measuredHeight == null && widget.products.isNotEmpty) {
      return Offstage(
        child: SizedBox(
          width: widget.cardWidth,
          child: Container(
            key: _measureKey,
            child: BannerProductCard(
              product: widget.products.first,
              index: 0,
            ),
          ),
        ),
      );
    }

    // Hiển thị ListView với height đã đo được
    if (_measuredHeight == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: _measuredHeight,
      child: Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: widget.products.length,
            itemBuilder: (context, index) {
              final product = widget.products[index];
              return Container(
                width: widget.cardWidth,
                margin: const EdgeInsets.only(right: 8),
                child: BannerProductCard(
                  product: product,
                  index: index,
                ),
              );
            },
          ),
          if (widget.showNextArrow && _canScrollRight && widget.products.length > 1)
            Positioned(
              right: 4,
              top: 78, // Hạ thấp để tránh lệch vào icon giỏ hàng
              child: GestureDetector(
                onTap: scrollNext,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
