import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/services/cached_api_service.dart';
import '../../../core/models/freeship_product.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/utils/format_utils.dart';
import '../../product/product_detail_screen.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../cart/cart_screen.dart';
import '../../checkout/checkout_screen.dart';
import '../../shared/widgets/product_badges.dart';

class FreeShipProductCardHorizontal extends StatelessWidget {
  final FreeShipProduct product;

  const FreeShipProductCardHorizontal({
    super.key,
    required this.product,
  });

  // Helper function to generate fake rating and sold data
  Map<String, dynamic> _generateFakeData(int price) {
    final random = Random(product.id);
    final isExpensive = price >= 1000000;
    
    final reviews = isExpensive 
        ? (random.nextInt(21) + 5)
        : (random.nextInt(95) + 10);
    
    final sold = isExpensive
        ? (random.nextInt(21) + 5)
        : (random.nextInt(90) + 15);
    
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
                              ? Image.network(
                                  product.imageUrl!,
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
                        if (product.oldPrice != null && product.oldPrice! > product.price)
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
                                _isFlashSale(product) ? 'SALE' : '${((product.oldPrice! - product.price) / product.oldPrice! * 100).round()}%',
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
                                locationText: null,
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
          image: product.imageUrl ?? '',
          price: product.price,
        ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) async {
    try {
      // Sử dụng cached API service cho product detail
      final cachedApiService = CachedApiService();
      final productDetail = await cachedApiService.getProductDetailCached(product.id);
      
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

  // Helper method để check flash sale
  bool _isFlashSale(FreeShipProduct product) {
    // Check trong badges từ API response (từ field is_flash_sale nếu có)
    // Vì FreeShipProduct không có badges list, có thể check từ is_flash_sale field trong future
    // Hiện tại check từ name hoặc description
    return false; // Placeholder, sẽ cần update khi có field is_flash_sale trong model
  }

  void _handleBuyNow(BuildContext context, ProductDetail product, ProductVariant variant, int quantity) {
    final cartItem = cart_service.CartItem(
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
    
    cart_service.CartService().addItem(cartItem);
    
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
    final cartItem = cart_service.CartItem(
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
    
    cart_service.CartService().addItem(cartItem);
    
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
    final cartItem = cart_service.CartItem(
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
    
    cart_service.CartService().addItem(cartItem);
    
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
    final cartItem = cart_service.CartItem(
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
    
    cart_service.CartService().addItem(cartItem);
    
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