import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/services/api_service.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/utils/format_utils.dart';
import '../../product/product_detail_screen.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../checkout/checkout_screen.dart';
import '../../shared/widgets/product_badges.dart';

class CategoryProductCardHorizontal extends StatelessWidget {
  final Map<String, dynamic> product;

  const CategoryProductCardHorizontal({
    super.key,
    required this.product,
  });

  // Helper function to generate fake rating and sold data
  Map<String, dynamic> _generateFakeData(int price) {
    final random = Random(product['id'] ?? 0);
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
    final fakeData = _generateFakeData(product['price'] ?? 0);
    final image = product['image'] ?? '';
    final name = product['name'] ?? 'Sản phẩm';
    final price = product['price'] ?? 0;
    final oldPrice = product['old_price'] ?? 0;
    final discountPercent = product['discount_percent'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToProductDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Box trái: Ảnh sản phẩm + Label giảm giá
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: image.isNotEmpty
                              ? Image.network(
                                  image,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                                )
                              : _buildPlaceholderImage(),
                        ),
                        // Flash sale icon (góc trái trên)
                        if (_isFlashSale(product))
                          Positioned(
                            top: 6,
                            left: 6,
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
                        // Discount badge
                        if (discountPercent > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isFlashSale(product) ? Colors.orange : Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isFlashSale(product) ? 'SALE' : '-$discountPercent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Box phải: Thông tin sản phẩm
                  Expanded(
                    child: Container(
                      height: 140,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      FormatUtils.formatCurrency(price),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (oldPrice > 0 && oldPrice > price) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        FormatUtils.formatCurrency(oldPrice),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          decoration: TextDecoration.lineThrough,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star, size: 12, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        '${fakeData['rating']} (${fakeData['reviews']}) | Đã bán ${fakeData['sold']}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Badges row từ các icon riêng lẻ từ API
                                ProductIconsRow(
                                  voucherIcon: product['voucher_icon'] as String?,
                                  freeshipIcon: product['freeship_icon'] as String?,
                                  chinhhangIcon: product['chinhhang_icon'] as String?,
                                  iconSize: 9,
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                                ),
                              ],
                            ),
                          ),
                          // Badge kho ở đáy box
                          ProductLocationBadge(
                            locationText: null,
                            // warehouseName: product['warehouse_name'] as String?,
                            provinceName: product['province_name'] as String?,
                            fontSize: 10,
                            iconColor: Colors.black,
                            textColor: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Icon giỏ hàng được position
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => _showPurchaseDialog(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 140,
      height: 140,
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

  void _navigateToProductDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: product['id'] ?? 0,
          title: product['name'] ?? 'Sản phẩm',
          image: product['image'] ?? '',
          price: product['price'] ?? 0,
        ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) async {
    try {
      final productDetail = await ApiService().getProductDetail(product['id'] ?? 0);
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
    final shop = _resolveShop(null, fb: null);
    final item = cart_service.CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: int.tryParse(shop.id) ?? 0,
      shopName: shop.name,
      addedAt: DateTime.now(),
      isSelected: true,
    );
    cart_service.CartService().addItem(item);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  void _handleAddToCart(BuildContext context, ProductDetail product, ProductVariant variant, int quantity) {
    final shop = _resolveShop(null, fb: null);
    final item = cart_service.CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: int.tryParse(shop.id) ?? 0,
      shopName: shop.name,
      addedAt: DateTime.now(),
    );
    cart_service.CartService().addItem(item);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text('Đã thêm ${product.name} (${variant.name}) x$quantity vào giỏ hàng'), backgroundColor: Colors.green));
  }

  void _handleBuyNowSimple(BuildContext context, ProductDetail product, int quantity) {
    final shop = _resolveShop(null, fb: null);
    final item = cart_service.CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: int.tryParse(shop.id) ?? 0,
      shopName: shop.name,
      addedAt: DateTime.now(),
      isSelected: true,
    );
    cart_service.CartService().addItem(item);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  void _handleAddToCartSimple(BuildContext context, ProductDetail product, int quantity) {
    final shop = _resolveShop(null, fb: null);
    final item = cart_service.CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: int.tryParse(shop.id) ?? 0,
      shopName: shop.name,
      addedAt: DateTime.now(),
    );
    cart_service.CartService().addItem(item);
    final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text('Đã thêm ${product.name} x$quantity vào giỏ hàng'), backgroundColor: Colors.green));
  }

  ({String id, String name}) _resolveShop(Map<String, dynamic>? product, {Map<String, dynamic>? fb}) {
    String? id = product?['shop_id']?.toString() ?? fb?['shop_id']?.toString();
    String? name = product?['shop_name'] ?? fb?['shop_name'];
    id ??= '0';
    name ??= 'Sóc Đỏ';
    return (id: id, name: name);
  }

  // Helper method để check flash sale
  bool _isFlashSale(Map<String, dynamic> product) {
    // Check từ badges
    final badges = product['badges'];
    if (badges != null && badges is List) {
      for (var badge in badges) {
        final badgeStr = badge.toString().toLowerCase();
        if (badgeStr.contains('flash') || badgeStr.contains('sale')) {
          return true;
        }
      }
    }
    return false;
  }
}