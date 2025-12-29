import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';
import '../../../core/utils/format_utils.dart';
import '../../shared/widgets/product_badges.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../cart/cart_screen.dart';
import '../../checkout/checkout_screen.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/services/api_service.dart';

class ShopProductsSection extends StatefulWidget {
  final int shopId;
  final int? categoryId;
  final Function(ShopProduct) onProductTap;
  final String? searchKeyword;

  const ShopProductsSection({
    super.key,
    required this.shopId,
    this.categoryId,
    required this.onProductTap,
    this.searchKeyword,
  });

  @override
  State<ShopProductsSection> createState() => _ShopProductsSectionState();
}

class _ShopProductsSectionState extends State<ShopProductsSection> {
  final CachedApiService _cachedApiService = CachedApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<ShopProduct> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProducts();
  }

  @override
  void didUpdateWidget(ShopProductsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload products khi searchKeyword thay đổi
    final oldKeyword = oldWidget.searchKeyword ?? '';
    final newKeyword = widget.searchKeyword ?? '';
    if (oldKeyword != newKeyword) {
      _loadProducts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final searchQuery = widget.searchKeyword?.isNotEmpty == true ? widget.searchKeyword : null;

      final result = await _cachedApiService.getShopProductsPaginatedCached(
        shopId: widget.shopId,
        categoryId: widget.categoryId?.toString(),
        searchQuery: searchQuery,
        page: loadMore ? _currentPage + 1 : 1,
        limit: 50,
      );

      if (mounted && result != null) {
        final productsData = result['products'] as List? ?? [];
        final pagination = result['pagination'] as Map<String, dynamic>? ?? {};
        
        final newProducts = productsData.map((data) => ShopProduct.fromJson(data)).toList();
        setState(() {
          if (loadMore) {
            _products.addAll(newProducts);
            _currentPage++;
          } else {
            _products = newProducts;
            _currentPage = 1;
          }
          
          _hasMore = pagination['has_next'] ?? false;
          _isLoading = false;
          _isLoadingMore = false;
        });
        
        
      } else if (mounted) {
     
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = 'Không thể tải sản phẩm';
        });
      }
    } catch (e) {
  
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (!_isLoadingMore && _hasMore) {
      await _loadProducts(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
   
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải sản phẩm...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadProducts(),
              child: Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Shop chưa có sản phẩm nào',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Align(
        alignment: Alignment.topLeft,
        child: _buildProductsGrid(),
      ),
    );
  }

  Widget _buildProductsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding left/right - spacing giữa 2 cột) / 2
    // Padding: 4px mỗi bên = 8px, spacing: 8px giữa 2 cột
    final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Căn trái toàn bộ nội dung
      children: [
        Wrap(
          alignment: WrapAlignment.start, // Căn trái khi chỉ có 1 sản phẩm
          spacing: 8, // Khoảng cách ngang giữa các card
          runSpacing: 8, // Khoảng cách dọc giữa các hàng
          children: _products.map((product) {
            return SizedBox(
              width: cardWidth, // Width cố định cho 2 cột, height tự co giãn
              child: _buildProductCard(product, context),
            );
          }).toList(),
        ),
        // Loading indicator khi loading more
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildProductCard(ShopProduct product, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      // Không set width ở đây - để parent SizedBox quản lý
      // Không dùng margin khi dùng trong Wrap (spacing đã được xử lý bởi Wrap)
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
        onTap: () => widget.onProductTap(product),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Quan trọng: tự co giãn theo nội dung
          children: [
            // Box trên: Ảnh sản phẩm + Label giảm giá
            LayoutBuilder(
              builder: (context, constraints) {
                // Sử dụng width thực tế từ parent constraint
                final imageWidth = constraints.maxWidth;
                return Container(
                  width: double.infinity,
                  height: imageWidth * 1.0, // Ảnh vuông - chiều cao = chiều rộng
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
                          child: product.image.isNotEmpty
                              ? Image.network(
                                  product.image,
                                width: double.infinity,
                                height: double.infinity,
                                  fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(imageWidth),
                                )
                            : _buildPlaceholderImage(imageWidth),
                        ),
                      // Flash sale icon (góc trái trên) - ưu tiên hiển thị trước
                        if (_isFlashSale(product))
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade700, Colors.red.shade700],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      // Discount badge (nổi lên trên ảnh góc phải)
                        if (product.discountPercent > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isFlashSale(product) ? Colors.orange : Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              ),
                              child: Text(
                                _isFlashSale(product) ? 'SALE' : '${product.discountPercent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ),
                      // Free Ship badge (góc trái dưới)
                      if (product.freeshipIcon.isNotEmpty)
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
                      // Icon giỏ hàng position nổi trên ảnh (góc dưới bên phải)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _showPurchaseDialog(context, product),
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
            // Box dưới: Thông tin sản phẩm - chỉ có padding bottom, left, right, tự co giãn
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4), // Giảm padding bottom
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Tự co giãn theo nội dung
                            children: [
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 12 : 14,
                      height: 1.2,
                                ),
                              ),
                  const SizedBox(height: 4),
                  // Giá và badges cùng hàng
                              Row(
                                children: [
                      Flexible(
                        child: Text(
                                    FormatUtils.formatCurrency(product.price),
                          style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                            fontSize: screenWidth < 360 ? 14 : 16,
                                    ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Badges chỉ hiển thị icon - cùng hàng với giá
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (product.voucherIcon.isNotEmpty)
                            _buildIconOnlyBadge(
                              icon: Icons.local_offer,
                              color: Colors.orange,
                              size: screenWidth < 360 ? 8 : 10,
                            ),
                          if (product.freeshipIcon.isNotEmpty) ...[
                            if (product.voucherIcon.isNotEmpty)
                              const SizedBox(width: 4),
                            _buildIconOnlyBadge(
                              icon: Icons.local_shipping,
                              color: Colors.green,
                              size: screenWidth < 360 ? 8 : 10,
                            ),
                          ],
                          if (product.chinhhangIcon.isNotEmpty) ...[
                            if (product.voucherIcon.isNotEmpty || product.freeshipIcon.isNotEmpty)
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
                              // Rating and sold - dữ liệu thật từ API
                              const SizedBox(height: 3),
                              Row(
                                children: [
                      Icon(Icons.star, size: screenWidth < 360 ? 11 : 13, color: Colors.amber),
                                  const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                                    _buildRatingSoldText(product),
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 10 : 11,
                            color: Colors.grey,
                          ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ),
                            ],
                          ),
                          // Badge kho ở đáy box
                  const SizedBox(height: 3),
                          ProductLocationBadge(
                            locationText: null,
                            provinceName: product.provinceName.isNotEmpty ? product.provinceName : null,
                    fontSize: screenWidth < 360 ? 8 : 9,
                            iconColor: Colors.black,
                            textColor: Colors.black,
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

  // Widget badge chỉ hiển thị icon - không có chữ
  Widget _buildIconOnlyBadge({
    required IconData icon,
    required Color color,
    required double size,
  }) {
    return Container(
      padding: const EdgeInsets.all(3), // Giảm padding giống flash sale
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3), // Giảm border radius giống flash sale
      ),
      child: Icon(
        icon,
        size: size,
        color: Colors.white,
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, ShopProduct product) async {
    try {
      // Lấy thông tin biến thể sản phẩm (nhẹ, chỉ cho dialog)
      final productDetail = await ApiService().getProductVariants(product.id);
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
  }

  // Helper method để check flash sale
  bool _isFlashSale(ShopProduct product) {
    // Check từ badges list
    for (var badge in product.badges) {
      if (badge.toLowerCase().contains('flash') || badge.toLowerCase().contains('sale')) {
        return true;
      }
    }
    return false;
  }

  // Helper method để build text rating và sold từ dữ liệu thật
  String _buildRatingSoldText(ShopProduct product) {
    final rating = product.rating;
    final reviews = product.totalReviews;
    final sold = product.sold;
    
    // Nếu có rating > 0, hiển thị rating và reviews
    if (rating > 0 && reviews > 0) {
      return '${rating.toStringAsFixed(1)} ($reviews) | Đã bán ${FormatUtils.formatNumber(sold)}';
    } else if (rating > 0) {
      return '${rating.toStringAsFixed(1)} | Đã bán ${FormatUtils.formatNumber(sold)}';
    } else {
      // Nếu không có rating, chỉ hiển thị sold
      return 'Đã bán ${FormatUtils.formatNumber(sold)}';
    }
  }
}