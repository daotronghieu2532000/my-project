import 'package:flutter/material.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/services/cart_animation_service.dart';

class SimplePurchaseDialog extends StatefulWidget {
  final ProductDetail product;
  final Function(ProductDetail, int) onBuyNow;
  final Function(ProductDetail, int) onAddToCart;
  final String? actionType; // 'buyNow' hoặc 'addToCart', null thì hiển thị cả 2

  const SimplePurchaseDialog({
    super.key,
    required this.product,
    required this.onBuyNow,
    required this.onAddToCart,
    this.actionType,
  });

  @override
  State<SimplePurchaseDialog> createState() => _SimplePurchaseDialogState();
}

class _SimplePurchaseDialogState extends State<SimplePurchaseDialog> {
  int _quantity = 1;
  final GlobalKey _imageKey = GlobalKey();
  final CartAnimationService _cartAnimationService = CartAnimationService();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
        minHeight: 220,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                // Product image (clickable)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        insetPadding: const EdgeInsets.all(12),
                        child: InteractiveViewer(
                          child: Image.network(
                            widget.product.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[200],
                              height: 300,
                              width: 300,
                              child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    key: _imageKey, // GlobalKey cho animation
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${widget.product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          if (widget.product.oldPrice != null && widget.product.oldPrice! > widget.product.price) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${widget.product.oldPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (widget.product.stock != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Còn lại: ${widget.product.stock} sản phẩm',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Close button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          
          // Quantity selector
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              children: [
                const Text(
                  'Số lượng',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  constraints: const BoxConstraints.tightFor(height: 28),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _quantity > 1 ? () {
                          setState(() {
                            _quantity--;
                          });
                        } : null,
                        icon: const Icon(Icons.remove, size: 14),
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                        width: 26,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          _quantity.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _quantity++;
                          });
                        },
                        icon: const Icon(Icons.add, size: 14),
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(
              children: [
                // Chỉ hiển thị nút Mua ngay nếu actionType là 'buyNow' hoặc null
                if (widget.actionType == null || widget.actionType == 'buyNow')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onBuyNow(widget.product, _quantity);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Mua ngay',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Khoảng cách giữa 2 nút (chỉ hiển thị khi có cả 2 nút)
                if (widget.actionType == null) const SizedBox(width: 6),
                // Chỉ hiển thị nút Thêm vào giỏ nếu actionType là 'addToCart' hoặc null
                if (widget.actionType == null || widget.actionType == 'addToCart')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        // Đóng dialog trước
                        Navigator.pop(context);
                        
                        // Trigger animation bay vào giỏ
                        await _cartAnimationService.animateToCart(
                          context: context,
                          imageUrl: widget.product.imageUrl,
                          startKey: _imageKey,
                        );
                        
                        // Sau đó mới gọi callback thêm vào giỏ (để bounce animation hoạt động)
                        widget.onAddToCart(widget.product, _quantity);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Thêm vào giỏ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
