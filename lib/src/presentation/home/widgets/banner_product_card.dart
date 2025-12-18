import 'package:flutter/material.dart';
import '../../product/product_detail_screen.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../cart/cart_screen.dart';
import '../../checkout/checkout_screen.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/models/product_suggest.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/api_service.dart';

class BannerProductCard extends StatelessWidget {
  final ProductSuggest product;
  final int index;

  const BannerProductCard({
    super.key,
    required this.product,
    required this.index,
  });


  @override
  Widget build(BuildContext context) {
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
        onTap: () => _navigateToProductDetail(context),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Tự co giãn theo nội dung
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
                        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? Image.network(
                                product.imageUrl!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(imageWidth),
                              )
                            : _buildPlaceholderImage(imageWidth),
                      ),
                      // Flash Sale icon (góc trái trên) - ưu tiên hiển thị trước
                      if (_isFlashSale(product))
                        Positioned(
                          top: 8,
                          left: 8,
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
                      // Discount badge (góc phải trên)
                      if (product.discount != null && product.discount! > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                              _isFlashSale(product) ? 'SALE' : '${product.discount!.toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Icon giỏ hàng position nổi trên ảnh (góc dưới bên phải)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _showPurchaseDialog(context),
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
                  // Tên sản phẩm
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 12 : 14,
                      
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Giá và badges icon cùng hàng
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
                          if (product.voucherIcon != null && product.voucherIcon!.isNotEmpty)
                            _buildIconOnlyBadge(
                              icon: Icons.local_offer,
                              color: Colors.orange,
                              size: screenWidth < 360 ? 8 : 10,
                            ),
                          if (product.freeshipIcon != null && product.freeshipIcon!.isNotEmpty) ...[
                            if (product.voucherIcon != null && product.voucherIcon!.isNotEmpty)
                              const SizedBox(width: 4),
                            _buildIconOnlyBadge(
                              icon: Icons.local_shipping,
                              color: Colors.green,
                              size: screenWidth < 360 ? 8 : 10,
                            ),
                          ],
                          if (product.chinhhangIcon != null && product.chinhhangIcon!.isNotEmpty) ...[
                            if ((product.voucherIcon != null && product.voucherIcon!.isNotEmpty) ||
                                (product.freeshipIcon != null && product.freeshipIcon!.isNotEmpty))
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
                  const SizedBox(height: 3),
                  // Rating and sold with real data from API
                  Row(
                    children: [
                      Icon(Icons.star, size: screenWidth < 360 ? 11 : 13, color: Colors.amber),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          _buildRatingAndSoldText(),
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 10 : 11,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Vị trí kho
                  if ((product.provinceName != null && product.provinceName!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: screenWidth < 360 ? 10 : 12,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              _buildLocationText(),
                              style: TextStyle(
                                fontSize: screenWidth < 360 ? 9 : 10,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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

  bool _isFlashSale(ProductSuggest product) {
    if (product.badges != null) {
      return product.badges!.any((badge) => 
        badge.toLowerCase().contains('flash') || 
        badge.toLowerCase().contains('sale'));
    }
    return false;
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

  String _buildLocationText() {
    final parts = <String>[];
   
    if (product.provinceName != null && product.provinceName!.isNotEmpty) {
      parts.add(product.provinceName!);
    }
    return parts.join(' - ');
  }

  String _buildRatingAndSoldText() {
    final rating = product.rating ?? 0.0;
    final reviews = product.totalReviews ?? 0;
    final sold = product.sold ?? 0;
    
    final ratingText = rating > 0 ? rating.toStringAsFixed(1) : '0.0';
    final reviewsText = reviews > 0 ? '($reviews)' : '(0)';
    final soldText = sold > 0 ? 'Đã bán $sold' : 'Chưa bán';
    
    return '$ratingText $reviewsText | $soldText';
  }

  void _navigateToProductDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: product.id,
          title: product.name,
          image: product.imageUrl ?? 'lib/src/core/assets/images/product_1.png',
          price: product.price,
        ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) async {
    try {
      final productDetail = await ApiService().getProductVariants(product.id);
      
      if (!context.mounted || productDetail == null) return;
      
        showModalBottomSheet(
        context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
        builder: (dialogContext) {
            if (productDetail.variants.isNotEmpty) {
              return VariantSelectionDialog(
                product: productDetail,
                selectedVariant: productDetail.variants.first,
                onBuyNow: (variant, quantity) {
                // Dialog đã tự pop trước khi gọi callback
                // Sử dụng WidgetsBinding để đảm bảo navigate sau khi dialog đã đóng hoàn toàn
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    _handleBuyNow(context, productDetail, variant, quantity);
                    }
                  });
                },
                onAddToCart: (variant, quantity) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    _handleAddToCart(context, productDetail, variant, quantity);
                    }
                  });
                },
              );
            } else {
              return SimplePurchaseDialog(
                product: productDetail,
                onBuyNow: (product, quantity) {
                // Dialog đã tự pop trước khi gọi callback
                // Sử dụng WidgetsBinding để đảm bảo navigate sau khi dialog đã đóng hoàn toàn
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    _handleBuyNowSimple(context, product, quantity);
                    }
                  });
                },
                onAddToCart: (product, quantity) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    _handleAddToCartSimple(context, product, quantity);
                    }
                  });
                },
              );
            }
          },
        );
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
    // ✅ Sử dụng extension method để tự động lấy originalPrice
    final cartItem = product.toCartItemWithVariant(
      variant: variant,
      quantity: quantity,
    );
    
    CartService().addItem(cartItem);
  }

  void _handleBuyNowSimple(BuildContext context, ProductDetail product, int quantity) {
    // ✅ Sử dụng extension method để tự động lấy originalPrice
    final cartItem = product.toCartItem(quantity: quantity);
    
    CartService().addItem(cartItem);
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckoutScreen()),
    );
  }

  void _handleAddToCartSimple(BuildContext context, ProductDetail product, int quantity) {
    // ✅ Sử dụng extension method để tự động lấy originalPrice
    final cartItem = product.toCartItem(quantity: quantity);
    
    CartService().addItem(cartItem);
  }
}

