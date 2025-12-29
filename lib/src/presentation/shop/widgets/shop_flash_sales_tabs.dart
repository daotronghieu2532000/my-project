import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../product/product_detail_screen.dart';
import '../../cart/cart_screen.dart';
import '../../checkout/checkout_screen.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/services/cart_service.dart';
import '../../shared/widgets/product_badges.dart';

class ShopFlashSalesTabs extends StatefulWidget {
  final int shopId;

  const ShopFlashSalesTabs({
    super.key,
    required this.shopId,
  });

  @override
  State<ShopFlashSalesTabs> createState() => _ShopFlashSalesTabsState();
}

class _ShopFlashSalesTabsState extends State<ShopFlashSalesTabs>
    with SingleTickerProviderStateMixin {
  final CachedApiService _cachedApiService = CachedApiService();
  late TabController _tabController;
  late Timer _timer;
  final Map<int, Duration> _timeLeftMap = {};
  
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

  @override
  void dispose() {
    if (_flashSales.isNotEmpty) {
      _tabController.dispose();
    }
    _timer.cancel();
    super.dispose();
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
        
        if (flashSales.isNotEmpty) {
          _tabController = TabController(
            length: flashSales.length,
            vsync: this,
          );
        }
        
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

  /// Build countdown timer đẹp với format Ngày : Giờ : Phút : Giây (compact cho tab)
  Widget _buildCountdownTimer(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    // Version compact cho tab - chỉ hiển thị số, không có label
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ngày
        _buildCompactTimeBox(days.toString().padLeft(2, '0')),
        _buildTimeSeparator(),
        // Giờ
        _buildCompactTimeBox(hours.toString().padLeft(2, '0')),
        _buildTimeSeparator(),
        // Phút
        _buildCompactTimeBox(minutes.toString().padLeft(2, '0')),
        _buildTimeSeparator(),
        // Giây
        _buildCompactTimeBox(seconds.toString().padLeft(2, '0')),
      ],
    );
  }
  
  /// Build box compact cho tab (không có label)
  Widget _buildCompactTimeBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Colors.red[300]!,
          width: 1,
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.red,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  /// Build separator giữa các số
  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Colors.red[400],
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFlashSales,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_flashSales.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        // Nếu chỉ có 1 flash sale, hiển thị trực tiếp không cần tabs
        if (_flashSales.length == 1)
          ShopFlashSaleProductsList(
            flashSale: _flashSales[0],
            shopId: widget.shopId,
          )
        else
          // Nếu có nhiều flash sale, hiển thị dạng tabs
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tab bar - chỉ hiển thị countdown, ẩn tiêu đề
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      padding: const EdgeInsets.only(left: 0, right: 40),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      tabAlignment: TabAlignment.start,
                      labelColor: Colors.red,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.red,
                      indicatorWeight: 2,
                      tabs: _flashSales.map((flashSale) {
                        final timeLeft = _timeLeftMap[flashSale.id] ?? const Duration();
                        final isActive = timeLeft.inSeconds > 0;
                        return Tab(
                          child: Container(
                            margin: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tiêu đề flash sale
                                Flexible(
                                  child: Text(
                                    flashSale.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Countdown timer
                                if (isActive) ...[
                                  const SizedBox(width: 8),
                                  _buildCountdownTimer(timeLeft),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Icon ">" ở bên phải để chỉ ra có thể scroll
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.8),
                              Colors.white,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade600,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab content - sử dụng SizedBox với height cố định thay vì Expanded
              _ShopFlashSaleTabBarView(
                tabController: _tabController,
                flashSales: _flashSales,
                shopId: widget.shopId,
              ),
            ],
          ),
      ],
    );
  }
}

// Widget riêng để hiển thị flash sale products list
class ShopFlashSaleProductsList extends StatelessWidget {
  final ShopFlashSale flashSale;
  final int shopId;

  const ShopFlashSaleProductsList({
    super.key,
    required this.flashSale,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context) {
    // Sử dụng ShopFlashSalesSection để hiển thị sản phẩm
    // Tạo một instance tạm để sử dụng logic
    return _FlashSaleProductsListHelper(flashSale: flashSale);
  }
}

// Helper widget để hiển thị flash sale products list
class _FlashSaleProductsListHelper extends StatelessWidget {
  final ShopFlashSale flashSale;

  const _FlashSaleProductsListHelper({
    required this.flashSale,
  });

  @override
  Widget build(BuildContext context) {
    // Copy logic từ ShopFlashSalesSection._buildFlashSaleProductsList
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
    
    // Tính toán width cho card - responsive
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding left/right - spacing giữa cards) / 2
    // Padding ListView: 4px mỗi bên = 8px, spacing (margin right): 8px
    // Width = (screenWidth - 8 - 8) / 2 = (screenWidth - 16) / 2
    final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)

    // Sử dụng helper widget để đo height thực tế và hiển thị ListView
    return _ShopFlashSaleHorizontalList(
      products: products,
      cardWidth: cardWidth,
    );
  }
}

// Helper widget để hiển thị flash sale product card
class _FlashSaleProductCardHelper extends StatelessWidget {
  final int productId;
  final Map<String, dynamic> productInfo;
  final Map<String, dynamic> variant;

  const _FlashSaleProductCardHelper({
    required this.productId,
    required this.productInfo,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    // Copy logic từ ShopFlashSalesSection._buildFlashSaleProductCard
    final price = int.tryParse(variant['gia']?.toString() ?? '0') ?? 0;
    final oldPrice = int.tryParse(variant['gia_cu']?.toString() ?? '0') ?? 0;
    final discountPercent = oldPrice > 0 && price < oldPrice 
        ? ((oldPrice - price) / oldPrice * 100).round() 
        : 0;
    
    final productName = productInfo['name'] as String? ?? 'Sản phẩm #$productId';
    final productImage = productInfo['image'] as String? ?? '';
    final voucherIcon = productInfo['voucher_icon'] as String? ?? '';
    final freeshipIcon = productInfo['freeship_icon'] as String? ?? '';
    final chinhhangIcon = productInfo['chinhhang_icon'] as String? ?? '';
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
          mainAxisSize: MainAxisSize.min, // Tự co giãn theo nội dung
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final imageWidth = constraints.maxWidth;
                return Container(
                  width: double.infinity,
                  height: imageWidth * 1.0,
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
                      // Free Ship badge (góc trái dưới)
                      if (freeshipIcon.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: FreeShipBadge(
                            iconSize: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            backgroundColor: const Color.fromARGB(255, 254, 254, 254),
                            textColor: const Color.fromARGB(255, 0, 0, 0),
                            text: 'Miễn phí vận chuyển',
                          ),
                        ),
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
                  const SizedBox(height: 3), // Giảm từ 4 xuống 3
                  // Rating and sold - dữ liệu thật từ API
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

// Helper widget để đo height thực tế của card và hiển thị ListView
class _ShopFlashSaleHorizontalList extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final double cardWidth;

  const _ShopFlashSaleHorizontalList({
    required this.products,
    required this.cardWidth,
  });

  @override
  State<_ShopFlashSaleHorizontalList> createState() => _ShopFlashSaleHorizontalListState();
}

class _ShopFlashSaleHorizontalListState extends State<_ShopFlashSaleHorizontalList> {
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
    if (_measuredHeight == null) {
      return Offstage(
        child: SizedBox(
          width: widget.cardWidth,
          child: Container(
            key: _measureKey,
            child: _FlashSaleProductCardHelper(
              productId: widget.products.first['productId'] as int,
              productInfo: widget.products.first['productInfo'] as Map<String, dynamic>,
              variant: widget.products.first['variant'] as Map<String, dynamic>,
            ),
          ),
        ),
      );
    }

    // Hiển thị ListView với height đã đo được
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
            child: _FlashSaleProductCardHelper(
              productId: product['productId'] as int,
              productInfo: product['productInfo'] as Map<String, dynamic>,
              variant: product['variant'] as Map<String, dynamic>,
            ),
          );
        },
      ),
    );
  }
}

// Helper widget để đo height thực tế cho TabBarView
class _ShopFlashSaleTabBarView extends StatefulWidget {
  final TabController tabController;
  final List<ShopFlashSale> flashSales;
  final int shopId;

  const _ShopFlashSaleTabBarView({
    required this.tabController,
    required this.flashSales,
    required this.shopId,
  });

  @override
  State<_ShopFlashSaleTabBarView> createState() => _ShopFlashSaleTabBarViewState();
}

class _ShopFlashSaleTabBarViewState extends State<_ShopFlashSaleTabBarView> {
  double? _measuredHeight;
  final GlobalKey _measureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Đo height sau khi widget được build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureTabHeight();
    });
  }

  void _measureTabHeight() {
    final RenderBox? renderBox = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      setState(() {
        _measuredHeight = renderBox.size.height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tính toán width cho card để đo height
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 16) / 2;
    
    // Lấy products từ flash sale đầu tiên để đo height
    final firstFlashSale = widget.flashSales.isNotEmpty ? widget.flashSales.first : null;
    if (firstFlashSale == null) {
      return const SizedBox.shrink();
    }
    
    final products = <Map<String, dynamic>>[];
    for (var entry in firstFlashSale.subProducts.entries) {
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
    
    // Nếu chưa đo được height, hiển thị card mẫu để đo (ẩn bằng Offstage)
    if (_measuredHeight == null) {
      return Offstage(
        child: SizedBox(
          width: cardWidth,
          child: Container(
            key: _measureKey,
            child: _FlashSaleProductCardHelper(
              productId: products.first['productId'] as int,
              productInfo: products.first['productInfo'] as Map<String, dynamic>,
              variant: products.first['variant'] as Map<String, dynamic>,
            ),
          ),
        ),
      );
    }

    // Hiển thị TabBarView với height đã đo được
    return SizedBox(
      height: _measuredHeight,
      child: TabBarView(
        controller: widget.tabController,
        children: widget.flashSales.map((flashSale) {
          return ShopFlashSaleProductsList(
            flashSale: flashSale,
            shopId: widget.shopId,
          );
        }).toList(),
      ),
    );
  }
}

