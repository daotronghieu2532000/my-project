import 'package:flutter/material.dart';
import '../../../core/models/product_detail.dart';

class VariantSelectionDialog extends StatefulWidget {
  final ProductDetail product;
  final ProductVariant? selectedVariant;
  final Function(ProductVariant, int) onBuyNow;
  final Function(ProductVariant, int) onAddToCart;
  final String? actionType; // 'buyNow' hoặc 'addToCart', null thì hiển thị cả 2

  const VariantSelectionDialog({
    super.key,
    required this.product,
    this.selectedVariant,
    required this.onBuyNow,
    required this.onAddToCart,
    this.actionType,
  });

  @override
  State<VariantSelectionDialog> createState() => _VariantSelectionDialogState();
}

class _VariantSelectionDialogState extends State<VariantSelectionDialog> {
  ProductVariant? _selectedVariant;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.selectedVariant ?? 
        (widget.product.variants.isNotEmpty ? widget.product.variants.first : null);
  }

  @override
  Widget build(BuildContext context) {
    // UI compact - bỏ tính toán chiều cao dư thừa
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
        minHeight: 240,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
           // Header
           Container(
             padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
             decoration: BoxDecoration(
               border: Border(
                 bottom: BorderSide(color: Colors.grey[200]!),
               ),
             ),
            child: Row(
              children: [
                 // Product image
                GestureDetector(
                   onTap: () {
                     showDialog(
                       context: context,
                       builder: (_) => Dialog(
                         insetPadding: const EdgeInsets.all(12),
                         child: InteractiveViewer(
                           child: Image.network(
                             _selectedVariant?.imageUrl ?? widget.product.imageUrl,
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
                    width: 78,
                    height: 78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _selectedVariant?.imageUrl ?? widget.product.imageUrl,
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
                            _selectedVariant != null 
                                ? '${_selectedVariant!.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫'
                                : '${widget.product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          if (_selectedVariant?.oldPrice != null && _selectedVariant!.oldPrice! > _selectedVariant!.price) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedVariant!.oldPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_selectedVariant?.stock != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Còn lại: ${_selectedVariant!.stock} sản phẩm',
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
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
           // Variant selection
           if (widget.product.variants.isNotEmpty) ...[
           Container(
             padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text(
                     'Phân loại',
                     style: TextStyle(
                       fontSize: 13,
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                   const SizedBox(height: 4),
                   Wrap(
                     spacing: 6,
                     runSpacing: 6,
                     children: [
                       for (final variant in widget.product.variants)
                         GestureDetector(
                           onTap: () {
                             setState(() {
                               _selectedVariant = variant;
                               _quantity = 1;
                             });
                           },
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                             decoration: BoxDecoration(
                               color: (_selectedVariant?.id == variant.id) ? Colors.red.withOpacity(0.1) : Colors.grey[100],
                               border: Border.all(
                                 color: (_selectedVariant?.id == variant.id) ? Colors.red : Colors.grey[300]!,
                                 width: (_selectedVariant?.id == variant.id) ? 1 : 1,
                               ),
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: Text(
                               variant.name,
                               style: TextStyle(
                                 fontSize: 13,
                                 fontWeight: (_selectedVariant?.id == variant.id) ? FontWeight.w600 : FontWeight.normal,
                                 color: (_selectedVariant?.id == variant.id) ? Colors.red : Colors.black87,
                               ),
                             ),
                           ),
                         ),
                     ],
                   ),
                 ],
               ),
             ),
           ],
          
           // Quantity selector
           Container(
             padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
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
                         onPressed: _selectedVariant?.stock != null && _quantity < _selectedVariant!.stock! ? () {
                           setState(() {
                             _quantity++;
                           });
                         } : null,
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
                         if (_selectedVariant != null) {
                           Navigator.pop(context);
                           widget.onBuyNow(_selectedVariant!, _quantity);
                         }
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
                       onPressed: () {
                         if (_selectedVariant != null) {
                           Navigator.pop(context);
                           widget.onAddToCart(_selectedVariant!, _quantity);
                         }
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
      ),
    );
  }
}
