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
    // Load từ cache ngay lập tức
    _loadBannerProductsFromCache();
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

    // Banner ngang
    if (banner.isHorizontalBanner) {
      final bannerHeight = 150.0;

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
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: SweepGradient(
                    center: Alignment.center,
                    startAngle: 0,
                    endAngle: 2 * 3.14159, // 360 độ
                    colors: const [
                      Color(0x99FF0080), // Hồng (mờ 60%)
                      Color(0x99FF8000), // Cam (mờ 60%)
                      Color(0x99FFD700), // Vàng (mờ 60%)
                      Color(0x9900FF80), // Xanh lá (mờ 60%)
                      Color(0x990080FF), // Xanh dương (mờ 60%)
                      Color(0x998000FF), // Tím (mờ 60%)
                      Color(0x99FF0080), // Hồng (lặp lại, mờ 60%)
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
            // Sản phẩm - cuộn ngang
            SizedBox(
              height: 290, // Tăng từ 256 lên 286 để tránh overflow
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                controller: _productsScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: banner.products.length,
                itemBuilder: (context, index) {
                  final product = banner.products[index];
                  final cardWidth = (screenWidth - 32) / 2;
                  return Container(
                    width: cardWidth,
                    margin: const EdgeInsets.only(right: 8),
                    child: BannerProductCard(
                      product: product,
                      index: index,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'NHÀ BÁN TIỀM NĂNG',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Future<void> _loadBannerProductsFromCache() async {
    try {
      // Nếu đã load rồi và có dữ liệu, không load lại (tránh gọi API khi scroll)
      if (_hasLoadedOnce && _bannerProducts != null) {
        print('🎯 Banner products already loaded, skipping reload');
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
          
          print('✅ Banner products loaded from cache (${widget.position})');
        } else {
          setState(() {
            _isLoading = false;
            _bannerProducts = null;
          });
          print('⚠️ No valid cached banner products for ${widget.position}');
        }
      } else {
        setState(() {
          _isLoading = false;
          _bannerProducts = null;
        });
        print('⚠️ No cached banner products for ${widget.position}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('❌ Error loading banner products from cache: $e');
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

      print(
        '🔍 Banner Products Widget [${widget.position}]: result = $result',
      );

      if (result != null && result.containsKey(widget.position)) {
        final bannerProduct = result[widget.position];
        print(
          '🔍 Banner Products Widget [${widget.position}]: bannerProduct = $bannerProduct',
        );

        // Kiểm tra banner còn hiệu lực không
        if (bannerProduct != null) {
          print(
            '🔍 Banner Products Widget [${widget.position}]: isValid = ${bannerProduct.isValid}, displayEnd = ${bannerProduct.displayEnd}, now = ${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
          );

          if (bannerProduct.isValid) {
            setState(() {
              _bannerProducts = bannerProduct;
              _isLoading = false;
              _hasLoadedOnce = true; // Đánh dấu đã load
            });
            print(
              '✅ Banner Products Widget [${widget.position}]: Loaded successfully',
            );
          } else {
            print(
              '⚠️ Banner Products Widget [${widget.position}]: Banner expired',
            );
            setState(() {
              _bannerProducts = null;
              _isLoading = false;
            });
          }
        } else {
          print(
            '⚠️ Banner Products Widget [${widget.position}]: bannerProduct is null',
          );
          setState(() {
            _bannerProducts = null;
            _isLoading = false;
          });
        }
      } else {
        print(
          '⚠️ Banner Products Widget [${widget.position}]: result is null or does not contain position',
        );
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
      print('❌ Error loading banner products: $e');
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
      print('❌ Lỗi khi mở link banner: $e');
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
    if (renderBox != null && mounted) {
      setState(() {
        _productCardHeight = renderBox.size.height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Đo height của product card nếu chưa đo
    if (_productCardHeight == null && widget.products.isNotEmpty) {
      // Hiển thị product card ẩn để đo height
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureProductCardHeight();
      });
    }

    // Khi đã đo được height, hiển thị banner và product list với cùng height
    final bannerHeight = _productCardHeight ?? 286.0; // Dùng height tạm thời nếu chưa đo được

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner dọc với height khớp product card
        GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: widget.bannerWidth,
            height: bannerHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: SweepGradient(
                center: Alignment.center,
                startAngle: 0,
                endAngle: 2 * 3.14159, // 360 độ
                colors: const [
                  Color(0xFFFF0080), // Hồng
                  Color(0xFFFF8000), // Cam
                  Color(0xFFFFD700), // Vàng
                  Color(0xFF00FF80), // Xanh lá
                  Color(0xFF0080FF), // Xanh dương
                  Color(0xFF8000FF), // Tím
                  Color(0xFFFF0080), // Hồng (lặp lại)
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
            padding: const EdgeInsets.all(2), // Border width
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
          ),
        ),
        const SizedBox(width: 8),
        // Sản phẩm - cuộn ngang với height đã đo
        Expanded(
          child: Stack(
            children: [
              // Product card ẩn để đo height (nếu chưa đo được)
              if (_productCardHeight == null && widget.products.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Offstage(
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
                  ),
                ),
              // ListView hiển thị sản phẩm
              SizedBox(
                height: bannerHeight,
                child: ListView.builder(
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper widget để đo height thực tế của card và hiển thị ListView ngang
class _BannerProductsHorizontalList extends StatefulWidget {
  final List<ProductSuggest> products;
  final double cardWidth;

  const _BannerProductsHorizontalList({
    required this.products,
    required this.cardWidth,
  });

  @override
  State<_BannerProductsHorizontalList> createState() => _BannerProductsHorizontalListState();
}

class _BannerProductsHorizontalListState extends State<_BannerProductsHorizontalList> {
  double? _measuredHeight;
  final GlobalKey _measureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Đo height sau khi widget được build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureCardHeight();
    });
  }

  void _measureCardHeight() {
    final RenderBox? renderBox = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      setState(() {
        _measuredHeight = renderBox.size.height;
      });
    }
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
      child: ListView.builder(
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
    );
  }
}
