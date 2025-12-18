import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../product/product_detail_screen.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../cart/cart_screen.dart';
import '../../checkout/checkout_screen.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/image_optimizer.dart';
import '../../../core/models/product_suggest.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/api_service.dart';
import '../../shared/widgets/product_badges.dart';

class ProductCardHorizontal extends StatelessWidget {
  final ProductSuggest product;
  final int index;

  const ProductCardHorizontal({
    super.key,
    required this.product,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
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
        onTap: () => _navigateToProductDetail(context),
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
                          child: product.imageUrl != null
                              ? CachedNetworkImage(
                                  // Sử dụng optimized URL với CDN + resize
                                  imageUrl: ImageOptimizer.getOptimizedUrl(
                                    product.imageUrl!,
                                    width: ImageSizes.cardWidth,
                                    height: ImageSizes.cardHeight,
                                    quality: 80,
                                  ),
                                width: double.infinity,
                                height: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                    color: Colors.grey[200],
                                  ),
                                errorWidget: (context, url, error) => _buildPlaceholderImage(imageWidth),
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  fadeOutDuration: const Duration(milliseconds: 100),
                                  // Tối ưu memory cache
                                  memCacheWidth: ImageSizes.cardWidth,
                                  memCacheHeight: ImageSizes.cardHeight,
                                  maxWidthDiskCache: ImageSizes.cardWidth,
                                  maxHeightDiskCache: ImageSizes.cardHeight,
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
                        if (product.discount != null && product.discount! > 0)
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
                              // Hiển thị giá thành viên nếu có
                              if (product.priceThanhvien != null && product.priceThanhvien!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Giá thành viên: ${product.priceThanhvien}',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: screenWidth < 360 ? 10 : 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              // Rating and sold with real data
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.star, size: screenWidth < 360 ? 11 : 13, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      '${(product.rating ?? 0.0).toStringAsFixed(1)} (${product.totalReviews ?? 0}) | Đã bán ${product.sold ?? 0}',
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
                            locationText: product.locationText,
                            provinceName: product.provinceName,
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

  // Helper method để check flash sale
  bool _isFlashSale(ProductSuggest product) {
    // Check trong badges list
    if (product.badges != null) {
      for (var badge in product.badges!) {
        if (badge.toLowerCase().contains('flash') || badge.toLowerCase().contains('sale')) {
          return true;
        }
      }
    }
    return false;
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