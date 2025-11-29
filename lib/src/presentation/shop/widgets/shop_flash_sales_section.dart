import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';
import '../../../core/utils/format_utils.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../product/product_detail_screen.dart';
import '../../cart/cart_screen.dart';
import '../../checkout/checkout_screen.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/cached_api_service.dart';
import '../../shared/widgets/product_badges.dart';
import 'shop_section_wrapper.dart';

class ShopFlashSalesSection extends StatefulWidget {
  final int shopId;

  const ShopFlashSalesSection({
    super.key,
    required this.shopId,
  });

  @override
  State<ShopFlashSalesSection> createState() => _ShopFlashSalesSectionState();
}

class _ShopFlashSalesSectionState extends State<ShopFlashSalesSection> {
  final CachedApiService _cachedApiService = CachedApiService();
  late Timer _timer;
  final Map<int, Duration> _timeLeftMap = {};
  final Map<int, bool> _expandedMap = {};
  
  List<ShopFlashSale> _flashSales = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFlashSales();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimers();
    });
  }

  Future<void> _loadFlashSales() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final flashSalesData = await _cachedApiService.getShopFlashSalesCached(
        shopId: widget.shopId,
      );

      if (mounted) {
        final flashSales = flashSalesData.map((data) => ShopFlashSale.fromJson(data)).toList();
        
        setState(() {
          _flashSales = flashSales;
          _isLoading = false;
        });
        
        _initializeTimers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  void _initializeTimers() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (var flashSale in _flashSales) {
      final timeLeft = flashSale.endTime - now;
      _timeLeftMap[flashSale.id] = Duration(seconds: timeLeft > 0 ? timeLeft : 0);
    }
  }

  void _updateTimers() {
    bool needsUpdate = false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    for (var flashSale in _flashSales) {
      final timeLeft = flashSale.endTime - now;
      final currentDuration = Duration(seconds: timeLeft > 0 ? timeLeft : 0);
      
      if (_timeLeftMap[flashSale.id] != currentDuration) {
        _timeLeftMap[flashSale.id] = currentDuration;
        needsUpdate = true;
      }
    }
    
    if (needsUpdate) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShopSectionWrapper(
      isLoading: _isLoading,
      error: _error,
      emptyMessage: 'Shop chưa có flash sale nào',
      emptyIcon: Icons.flash_on_outlined,
      onRetry: _loadFlashSales,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Tiêu đề FLASH SALE giống trang chủ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.pink, size: 20),
                    const SizedBox(width: 4),
                    Text('FLASH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.pink)),
                    const SizedBox(width: 4),
                    Text('SALE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.orange)),
                  ],
                ),
                // Bỏ countdown ở góc phải - chỉ giữ countdown trong từng flash sale
              ],
            ),
          ),
          // Danh sách flash sale cards
          ..._flashSales.map((flashSale) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildFlashSaleCard(flashSale, context),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildFlashSaleCard(ShopFlashSale flashSale, BuildContext context) {
    final timeLeft = _timeLeftMap[flashSale.id] ?? const Duration();
    final isActive = timeLeft.inSeconds > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với countdown và expand button (ẩn tiêu đề flash sale)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2F2), // Nền đỏ nhẹ giống trang chủ
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                // Countdown đẹp với format Ngày : Giờ : Phút : Giây
                if (isActive)
                  _buildCountdownTimer(timeLeft),
                const Spacer(),
                // Expand/Collapse button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedMap[flashSale.id] = !(_expandedMap[flashSale.id] ?? true);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      (_expandedMap[flashSale.id] ?? true) ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[700],
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Animated content
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: (_expandedMap[flashSale.id] ?? true) ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: (_expandedMap[flashSale.id] ?? true) ? 1.0 : 0.0,
              child: Column(
                children: [
                  // Danh sách sản phẩm - cuộn ngang như flash sale trang chủ
                  if (flashSale.subProducts.isNotEmpty) ...[
                    _buildFlashSaleProductsList(flashSale, context),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build countdown timer đẹp với format Ngày : Giờ : Phút : Giây
  Widget _buildCountdownTimer(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.red[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ngày
          _buildTimeUnit(days.toString().padLeft(2, '0'), 'Ngày'),
          _buildTimeSeparator(),
          // Giờ
          _buildTimeUnit(hours.toString().padLeft(2, '0'), 'Giờ'),
          _buildTimeSeparator(),
          // Phút
          _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'Phút'),
          _buildTimeSeparator(),
          // Giây
          _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'Giây'),
        ],
      ),
    );
  }
  
  /// Build box cho từng đơn vị thời gian với label
  Widget _buildTimeUnit(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 28,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.red[300]!,
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.red[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  /// Build separator giữa các số
  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.red[400],
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildFlashSaleProductsList(ShopFlashSale flashSale, BuildContext context) {
    // Lọc và chuẩn bị danh sách sản phẩm
    final products = <Map<String, dynamic>>[];
    
    for (var entry in flashSale.subProducts.entries) {
      final productId = int.tryParse(entry.key) ?? 0;
      final productData = entry.value;
      if (productData is! Map<String, dynamic>) continue;
      
      final productInfo = productData['product_info'] as Map<String, dynamic>?;
      final variants = productData['variants'] as List<dynamic>?;
      if (productInfo == null || variants == null || variants.isEmpty) continue;
      
      final variant = variants.first as Map<String, dynamic>;
      products.add({
        'productId': productId,
        'productInfo': productInfo,
        'variant': variant,
      });
    }
    
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Tính toán chiều cao cho horizontal scroll - responsive
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding left/right - spacing giữa cards) / 2
    // Padding ListView: 4px mỗi bên = 8px, spacing (margin right): 8px
    // Width = (screenWidth - 8 - 8) / 2 = (screenWidth - 16) / 2
    final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)
    final imageHeight = cardWidth * 1.0; // Ảnh vuông
    // Chiều cao phần thông tin tự động (mainAxisSize.min) - tính lại chính xác
    // Tên (2 dòng với height: 1.2): ~28-34px, Giá+Badge: ~20px, Rating: ~16px
    // Padding: 4px (top) + 4px (bottom) = 8px, Spacing: 4 + 4 = 8px
    // Tổng thực tế: ~80-86px, thêm buffer 20px để tránh overflow = 100-106px
    final estimatedInfoHeight = screenWidth < 360 ? 100 : 106;
    final cardHeight = imageHeight + estimatedInfoHeight;
    
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Container(
            width: cardWidth, // Width cố định cho 2 cột
            margin: const EdgeInsets.only(right: 8), // Spacing giữa các card
            child: _buildFlashSaleProductCard(
              productId: product['productId'] as int,
              productInfo: product['productInfo'] as Map<String, dynamic>,
              variant: product['variant'] as Map<String, dynamic>,
              context: context,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlashSaleProductCard({
    required int productId,
    required Map<String, dynamic> productInfo,
    required Map<String, dynamic> variant,
    required BuildContext context,
  }) {
    final price = int.tryParse(variant['gia']?.toString() ?? '0') ?? 0;
    final oldPrice = int.tryParse(variant['gia_cu']?.toString() ?? '0') ?? 0;
    final discountPercent = oldPrice > 0 && price < oldPrice 
        ? ((oldPrice - price) / oldPrice * 100).round() 
        : 0;
    
    // Get product info
    final productName = productInfo['name'] as String? ?? 'Sản phẩm #$productId';
    final productImage = productInfo['image'] as String? ?? '';
    final voucherIcon = productInfo['voucher_icon'] as String? ?? '';
    final freeshipIcon = productInfo['freeship_icon'] as String? ?? '';
    final chinhhangIcon = productInfo['chinhhang_icon'] as String? ?? '';
    final provinceName = productInfo['province_name'] as String? ?? '';
    final rating = (productInfo['rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = productInfo['total_reviews'] as int? ?? 0;
    final sold = productInfo['sold'] as int? ?? 0;
    
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
      onTap: () {
    Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: productId,
              title: productName,
              image: productImage,
              price: price,
            ),
          ),
        );
      },
          borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Quan trọng: tự co giãn theo nội dung
        children: [
            // Box trên: Ảnh sản phẩm + Label giảm giá
            LayoutBuilder(
              builder: (context, constraints) {
                final imageWidth = constraints.maxWidth;
                return Container(
                  width: double.infinity,
                  height: imageWidth * 1.0, // Ảnh vuông
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                      ),
                    ),
                  child: Stack(
              children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        child: productImage.isNotEmpty
                            ? Image.network(
                                productImage,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(imageWidth),
                              )
                            : _buildPlaceholderImage(imageWidth),
                ),
                      // Flash sale badge (góc trái trên)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.pink, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(4),
                ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                  children: [
                              Icon(Icons.flash_on, size: 12, color: Colors.white),
                              SizedBox(width: 2),
                    Text(
                                'FLASH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                        ),
                      ),
                      // Discount badge (góc phải trên)
                    if (discountPercent > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                              '$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                                fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                        ),
                      // Cart icon (góc dưới bên phải)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _showPurchaseDialog(context, productId),
                          child: Container(
                            width: 32,
                            height: 32,
                        decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                        ),
                            child: const Icon(
                              Icons.add_shopping_cart,
                              size: 18,
                            color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Box dưới: Thông tin sản phẩm
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Tự co giãn theo nội dung
                children: [
                  Text(
                    productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Giá và badges cùng hàng
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          FormatUtils.formatCurrency(price),
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth < 360 ? 14 : 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Badges chỉ icon
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (voucherIcon.isNotEmpty)
                            _buildIconOnlyBadge(
                              icon: Icons.local_offer,
                              color: Colors.orange,
                              size: screenWidth < 360 ? 8 : 10,
                            ),
                          if (freeshipIcon.isNotEmpty) ...[
                            if (voucherIcon.isNotEmpty)
                              const SizedBox(width: 4),
                            _buildIconOnlyBadge(
                              icon: Icons.local_shipping,
                              color: Colors.green,
                              size: screenWidth < 360 ? 8 : 10,
                        ),
                          ],
                          if (chinhhangIcon.isNotEmpty) ...[
                            if (voucherIcon.isNotEmpty || freeshipIcon.isNotEmpty)
                              const SizedBox(width: 4),
                            _buildIconOnlyBadge(
                              icon: Icons.verified,
                              color: const Color.fromARGB(255, 0, 140, 255),
                              size: screenWidth < 360 ? 8 : 10,
                          ),
                          ],
                        ],
                        ),
                      ],
                    ),
                  // Rating and sold
                  const SizedBox(height: 3), // Giảm từ 4 xuống 3
                Row(
                  children: [
                      Icon(Icons.star, size: screenWidth < 360 ? 11 : 13, color: Colors.amber),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          _buildRatingSoldText(rating, totalReviews, sold),
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 10 : 11,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                  // Location badge - chỉ hiển thị nếu có
                  if (provinceName.isNotEmpty) ...[
                    const SizedBox(height: 3), // Giảm từ 3 xuống 3 (giữ nguyên)
                    ProductLocationBadge(
                      locationText: null,
                      provinceName: provinceName,
                      fontSize: screenWidth < 360 ? 8 : 9,
                      iconColor: Colors.black,
                      textColor: Colors.black,
              ),
                  ],
                ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPlaceholderImage([double? height]) {
    return Container(
      width: double.infinity,
      height: height ?? 160,
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          size: 24,
          color: Colors.grey,
        ),
      ),
    );
  }

  // Widget badge chỉ hiển thị icon
  Widget _buildIconOnlyBadge({
    required IconData icon,
    required Color color,
    required double size,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Icon(
        icon,
        size: size,
        color: Colors.white,
      ),
    );
  }

  // Helper method để build text rating và sold từ dữ liệu thật
  String _buildRatingSoldText(double rating, int reviews, int sold) {
    if (rating > 0 && reviews > 0) {
      return '${rating.toStringAsFixed(1)} ($reviews) | Đã bán ${FormatUtils.formatNumber(sold)}';
    } else if (rating > 0) {
      return '${rating.toStringAsFixed(1)} | Đã bán ${FormatUtils.formatNumber(sold)}';
    } else {
      return 'Đã bán ${FormatUtils.formatNumber(sold)}';
    }
  }

  void _showPurchaseDialog(BuildContext context, int productId) async {
    try {
      // Lấy thông tin biến thể sản phẩm (nhẹ, chỉ cho dialog)
      final productDetail = await ApiService().getProductVariants(productId);
      final parentContext = Navigator.of(context).context;
      
      if (parentContext.mounted && productDetail != null) {
        showModalBottomSheet(
          context: parentContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            if (productDetail.variants.isNotEmpty) {
              return VariantSelectionDialog(
                product: productDetail,
                selectedVariant: productDetail.variants.first,
                onBuyNow: (variant, quantity) {
                  _handleBuyNow(parentContext, productDetail, variant, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) Navigator.of(context).pop();
                  });
                },
                onAddToCart: (variant, quantity) {
                  _handleAddToCart(parentContext, productDetail, variant, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) Navigator.of(context).pop();
                  });
                },
              );
    } else {
              return SimplePurchaseDialog(
                product: productDetail,
                onBuyNow: (product, quantity) {
                  _handleBuyNowSimple(parentContext, product, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) Navigator.of(context).pop();
                  });
                },
                onAddToCart: (product, quantity) {
                  _handleAddToCartSimple(parentContext, product, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) Navigator.of(context).pop();
                  });
                },
              );
            }
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleBuyNow(BuildContext context, ProductDetail product, ProductVariant variant, int quantity) {
    final cartItem = CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );
    
    CartService().addItem(cartItem);
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckoutScreen()),
    );
  }

  void _handleAddToCart(BuildContext context, ProductDetail product, ProductVariant variant, int quantity) {
    final cartItem = CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );
    
    CartService().addItem(cartItem);
  }

  void _handleBuyNowSimple(BuildContext context, ProductDetail product, int quantity) {
    final cartItem = CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );
    
    CartService().addItem(cartItem);
    
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${product.name} vào giỏ hàng'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckoutScreen()),
    );
  }

  void _handleAddToCartSimple(BuildContext context, ProductDetail product, int quantity) {
    final cartItem = CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );
    
    CartService().addItem(cartItem);
    
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${product.name} x$quantity vào giỏ hàng'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Xem giỏ hàng',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ),
      );
    }
  }
}
