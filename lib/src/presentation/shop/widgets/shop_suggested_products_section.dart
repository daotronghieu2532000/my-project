import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';
import '../../../core/utils/format_utils.dart';
import '../../shared/widgets/product_badges.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../cart/cart_screen.dart';
import '../../checkout/checkout_screen.dart';
import '../../product/product_detail_screen.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/cached_api_service.dart';

class ShopSuggestedProductsSection extends StatelessWidget {
  final int shopId;
  final List<ShopProduct> suggestedProducts;

  const ShopSuggestedProductsSection({
    super.key,
    required this.shopId,
    required this.suggestedProducts,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Gợi ý tới bạn',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildSuggestedProductsList(context),
      ],
    );
  }

  Widget _buildSuggestedProductsList(BuildContext context) {
    // Tính toán chiều cao cho horizontal scroll - responsive
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding left/right - spacing giữa cards) / 2
    // Padding ListView: 4px mỗi bên = 8px, spacing (margin right): 8px
    // Width = (screenWidth - 8 - 8) / 2 = (screenWidth - 16) / 2
    final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)
    final imageHeight = cardWidth * 1.0; // Ảnh vuông
    // Chiều cao phần thông tin tự động
    final estimatedInfoHeight = screenWidth < 360 ? 100 : 106;
    final cardHeight = imageHeight + estimatedInfoHeight;
    
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: suggestedProducts.length,
        itemBuilder: (context, index) {
          final product = suggestedProducts[index];
          return Container(
            width: cardWidth, // Width cố định cho 2 cột
            margin: const EdgeInsets.only(right: 8), // Spacing giữa các card
            child: _buildSuggestedProductCard(
              product: product,
              context: context,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestedProductCard({
    required ShopProduct product,
    required BuildContext context,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final discountPercent = product.discountPercent;
    
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
                productId: product.id,
                title: product.name,
                image: product.image,
                price: product.price,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Box trên: Ảnh sản phẩm + Badges
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
                          onTap: () => _showPurchaseDialog(context, product.id),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
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
                      // Badges chỉ icon
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
                  // Rating and sold
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.star, size: screenWidth < 360 ? 11 : 13, color: Colors.amber),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          _buildRatingSoldText(product.rating, product.totalReviews, product.sold),
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
                  if (product.provinceName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    ProductLocationBadge(
                      locationText: null,
                      provinceName: product.provinceName,
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

  // Helper method để build text rating và sold
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
      // Dùng cache cho chi tiết sản phẩm
      final productDetail = await CachedApiService().getProductDetailCached(productId);
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
                    Navigator.pop(parentContext);
                  });
                },
                onAddToCart: (variant, quantity) {
                  _handleAddToCart(parentContext, productDetail, variant, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    Navigator.pop(parentContext);
                  });
                },
              );
            } else {
              return SimplePurchaseDialog(
                product: productDetail,
                onBuyNow: (product, quantity) {
                  _handleBuyNowSimple(parentContext, productDetail, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    Navigator.pop(parentContext);
                  });
                },
                onAddToCart: (product, quantity) {
                  _handleAddToCartSimple(parentContext, productDetail, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    Navigator.pop(parentContext);
                  });
                },
              );
            }
          },
        );
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _handleBuyNow(BuildContext context, ProductDetail product, ProductVariant variant, int quantity) {
    final cartService = CartService();
    final cartItem = CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: shopId,
      shopName: product.shopName ?? 'Shop',
      addedAt: DateTime.now(),
    );
    cartService.addItem(cartItem);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  void _handleAddToCart(BuildContext context, ProductDetail product, ProductVariant variant, int quantity) {
    final cartService = CartService();
    final cartItem = CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: shopId,
      shopName: product.shopName ?? 'Shop',
      addedAt: DateTime.now(),
    );
    cartService.addItem(cartItem);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã thêm vào giỏ hàng'),
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

  void _handleBuyNowSimple(BuildContext context, ProductDetail product, int quantity) {
    final cartService = CartService();
    final cartItem = CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: shopId,
      shopName: product.shopName ?? 'Shop',
      addedAt: DateTime.now(),
    );
    cartService.addItem(cartItem);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  void _handleAddToCartSimple(BuildContext context, ProductDetail product, int quantity) {
    final cartService = CartService();
    final cartItem = CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: shopId,
      shopName: product.shopName ?? 'Shop',
      addedAt: DateTime.now(),
    );
    cartService.addItem(cartItem);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã thêm vào giỏ hàng'),
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

