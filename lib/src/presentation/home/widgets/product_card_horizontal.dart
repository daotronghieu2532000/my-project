import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
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
import '../../shared/widgets/product_badges.dart';

class ProductCardHorizontal extends StatelessWidget {
  final ProductSuggest product;
  final int index;

  const ProductCardHorizontal({
    super.key,
    required this.product,
    required this.index,
  });

  // Helper function to generate fake rating and sold data
  Map<String, dynamic> _generateFakeData(int price) {
    // Sử dụng product ID làm seed để đảm bảo dữ liệu cố định
    final random = Random(product.id);
    
    // Check if it's expensive (>= 1,000,000)
    final isExpensive = price >= 1000000;
    
    // Generate fake data based on price with fixed seed
    final reviews = isExpensive 
        ? (random.nextInt(21) + 5) // 5-25 for expensive products
        : (random.nextInt(95) + 10); // 10-104 for normal products
    
    final sold = isExpensive
        ? (random.nextInt(21) + 5) // 5-25 for expensive products
        : (random.nextInt(90) + 15); // 15-104 for normal products
    
    return {
      'rating': '5.0',
      'reviews': reviews,
      'sold': sold,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fakeData = _generateFakeData(product.price);
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
                                  imageUrl: product.imageUrl!,
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
                              // Rating and sold with fake data
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.star, size: screenWidth < 360 ? 11 : 13, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                    '${fakeData['rating']} (${fakeData['reviews']}) | Đã bán ${fakeData['sold']}',
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
      final productDetail = await ApiService().getProductDetail(product.id);
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
    
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${variant.name} vào giỏ hàng'),
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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${product.name} (${variant.name}) x$quantity vào giỏ hàng'),
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