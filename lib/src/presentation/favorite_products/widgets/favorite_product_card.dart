import 'package:flutter/material.dart';
import '../models/favorite_product.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/models/product_detail.dart';
import '../../product/product_detail_screen.dart';
import '../../product/widgets/variant_selection_dialog.dart';
import '../../product/widgets/simple_purchase_dialog.dart';
import '../../cart/cart_screen.dart';
import '../../checkout/checkout_screen.dart';
import '../../shared/widgets/product_badges.dart';

class FavoriteProductCard extends StatefulWidget {
  final FavoriteProduct product;
  final VoidCallback? onRemove;

  const FavoriteProductCard({
    super.key,
    required this.product,
    this.onRemove,
  });

  @override
  State<FavoriteProductCard> createState() => _FavoriteProductCardState();
}

class _FavoriteProductCardState extends State<FavoriteProductCard> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  bool _isRemoving = false;

  // Helper function to build full image URL
  String _buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://socdo.vn/images/no-images.jpg';
    }
    
    // If already has full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    
    // If starts with /, remove it and add domain
    if (imagePath.startsWith('/')) {
      return 'https://socdo.vn$imagePath';
    }
    
    // Otherwise add domain and /
    return 'https://socdo.vn/$imagePath';
  }

  void _showSnack(String message, {SnackBarAction? action, Color? background}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          duration: const Duration(seconds: 2),
          action: action,
        ),
      );
    });
  }

  Future<void> _removeFromFavorites() async {
    if (_isRemoving) return;

    setState(() {
      _isRemoving = true;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        _showSnack('Vui lòng đăng nhập để thực hiện thao tác này', background: Colors.red);
        return;
      }

      final result = await _apiService.removeFavoriteProduct(
        userId: currentUser.userId,
        productId: widget.product.id,
      );

      if (result != null && result['success'] == true) {
        _showSnack('Đã xóa sản phẩm khỏi danh sách yêu thích', background: Colors.green);
        widget.onRemove?.call();
      } else {
        _showSnack('Không thể xóa sản phẩm khỏi yêu thích', background: Colors.red);
      }
    } catch (e) {
      _showSnack('Lỗi khi xóa sản phẩm khỏi yêu thích: $e', background: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isRemoving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              // Layout chính với Row
              Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  // Box ảnh bên trái
                  Container(
                    width: 120,
                    height: 120,
              decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(8),
              ),
                    child: Stack(
                      children: [
                        ClipRRect(
                borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _buildImageUrl(widget.product.imageUrl),
                            width: 120,
                            height: 120,
                        fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                          ),
                        ),
                        // Discount badge (góc phải trên)
                        if (widget.product.discountPercent > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isFlashSale() ? Colors.orange : Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _isFlashSale() ? 'SALE' : '-${widget.product.discountPercent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        // Favorite button (góc trái trên)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: GestureDetector(
                            onTap: _removeFromFavorites,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isRemoving
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.favorite,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                            ),
                          ),
                        ),
                        // Flash sale icon (góc trái, dưới icon yêu thích)
                        if (_isFlashSale())
                          Positioned(
                            top: 32,
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
                      ],
            ),
          ),
          const SizedBox(width: 12),
                  // Box thông tin bên phải
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        // Tên sản phẩm
                  Text(
                    widget.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Giá
                  Row(
                    children: [
                      Text(
                        FormatUtils.formatCurrency(widget.product.price),
                        style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                            if (widget.product.oldPrice != null && widget.product.oldPrice! > widget.product.price) ...[
                              const SizedBox(width: 6),
                        Text(
                          FormatUtils.formatCurrency(widget.product.oldPrice!),
                          style: const TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                                  fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                        const SizedBox(height: 6),
                        // Rating và đã bán - sử dụng dữ liệu thật từ API
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '${widget.product.rating.toStringAsFixed(1)} (${widget.product.reviewCount}) | Đã bán ${widget.product.soldCount}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                  // Badges
                        ProductIconsRow(
                          voucherIcon: widget.product.voucherIcon,
                          freeshipIcon: widget.product.freeshipIcon,
                          chinhhangIcon: widget.product.chinhhangIcon,
                          iconSize: 9,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        ),
                        const SizedBox(height: 6),
                        // Location info
                        ProductLocationBadge(
                          locationText: null,
                          // warehouseName: widget.product.warehouseName,
                          provinceName: widget.product.provinceName,
                              fontSize: 10,
                          iconColor: Colors.black,
                          textColor: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Cart icon ở góc dưới bên phải
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showPurchaseDialog(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
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
                      size: 22,
                        color: Colors.white,
                    ),
                  ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 120,
      height: 120,
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
          productId: widget.product.id,
          title: widget.product.name,
          image: _buildImageUrl(widget.product.imageUrl),
          price: widget.product.price,
          initialShopId: widget.product.shopId,
          initialShopName: widget.product.shopName,
        ),
      ),
    );
  }

  // Hiển thị dialog mua hàng - giống product_suggest_card_vertical
  void _showPurchaseDialog(BuildContext context) async {
    try {
      // Lấy thông tin biến thể sản phẩm (nhẹ, chỉ cho dialog)
      final productDetail = await ApiService().getProductVariants(widget.product.id);
      
      // Sử dụng context từ parent để tránh vấn đề context hierarchy
      final parentContext = Navigator.of(context).context;
      
      if (parentContext.mounted && productDetail != null) {
        showModalBottomSheet(
          context: parentContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            // Nếu có biến thể, hiển thị dialog chọn biến thể
            if (productDetail.variants.isNotEmpty) {
              return VariantSelectionDialog(
                product: productDetail,
                selectedVariant: productDetail.variants.first,
                onBuyNow: (variant, quantity) {
                  _handleBuyNow(parentContext, productDetail, variant, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) {
        Navigator.of(context).pop();
                    }
                  });
      },
                onAddToCart: (variant, quantity) {
                  _handleAddToCart(parentContext, productDetail, variant, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) {
        Navigator.of(context).pop();
                    }
                  });
                },
              );
            } else {
              // Nếu không có biến thể, hiển thị dialog đơn giản
              return SimplePurchaseDialog(
                product: productDetail,
                onBuyNow: (product, quantity) {
                  _handleBuyNowSimple(parentContext, product, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) {
        Navigator.of(context).pop();
                    }
                  });
      },
                onAddToCart: (product, quantity) {
                  _handleAddToCartSimple(parentContext, product, quantity);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) {
        Navigator.of(context).pop();
                    }
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

  // Xử lý MUA NGAY cho sản phẩm có biến thể
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
    
    // Chuyển đến trang thanh toán
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  // Xử lý THÊM VÀO GIỎ cho sản phẩm có biến thể
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

  // Xử lý MUA NGAY cho sản phẩm không có biến thể
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
    
    // Chuyển đến trang thanh toán
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  // Xử lý THÊM VÀO GIỎ cho sản phẩm không có biến thể
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
  bool _isFlashSale() {
    // Check từ badges list
    for (var badge in widget.product.badges) {
      if (badge.toLowerCase().contains('flash') || badge.toLowerCase().contains('sale')) {
        return true;
      }
    }
    return false;
  }
}
