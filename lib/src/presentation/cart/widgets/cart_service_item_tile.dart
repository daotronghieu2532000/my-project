import 'package:flutter/material.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../product/product_detail_screen.dart';
import 'qty_button.dart';

class CartServiceItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onChanged;
  final Function(CartItem) onDelete;
  final Function(CartItem, String?) onVariantChange;
  final Function(CartItem, int) onQuantityChange;
  final bool isEditMode;
  
  const CartServiceItemTile({
    super.key, 
    required this.item, 
    required this.onChanged,
    required this.onDelete,
    required this.onVariantChange,
    required this.onQuantityChange,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.isSelected,
            activeColor: Colors.red,
            onChanged: (v) {
              final cartService = CartService();
              cartService.toggleItemSelection(item.id, variant: item.variant);
              onChanged();
            },
          ),
          InkWell(
            onTap: () => _navigateToProductDetail(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFFF4F6FB),
                child: item.image.isNotEmpty
                    ? Image.network(
                        item.image,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
                      )
                    : const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _navigateToProductDetail(context),
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Hiển thị biến thể nếu có
                if (item.variant != null && item.variant!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showVariantDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.style_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                            item.variant!,
                            style: TextStyle(
                              fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                            const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      FormatUtils.formatCurrency(item.price),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.oldPrice != null && item.oldPrice! > item.price) ...[
                      const SizedBox(width: 8),
                      Text(
                        FormatUtils.formatCurrency(item.oldPrice!),
                        style: const TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    QtyButton(icon: Icons.remove, onTap: () {
                      if (item.quantity > 1) {
                        onQuantityChange(item, item.quantity - 1);
                      }
                    }),
                    const SizedBox(width: 4),
                    Container(
                      width: 40,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    QtyButton(icon: Icons.add, onTap: () {
                      onQuantityChange(item, item.quantity + 1);
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            onPressed: () => _showDeleteItemDialog(context),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showDeleteItemDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xóa sản phẩm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bạn có chắc muốn xóa sản phẩm này?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Product info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFFF4F6FB),
                        child: item.image.isNotEmpty
                            ? Image.network(
                                item.image,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                              )
                            : Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.variant != null && item.variant!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.variant!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: const Center(
                              child: Text(
                                'Hủy',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[500]!, Colors.red[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
              Navigator.pop(context);
              onDelete(item);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: const Center(
                              child: Text(
                                'Xóa',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
      ),
    );
  }

  void _showVariantDialog(BuildContext context) async {
    // Lấy thông tin sản phẩm để có danh sách biến thể
    final apiService = ApiService();
    final productDetail = await apiService.getProductDetail(item.id);
    
    if (productDetail == null || productDetail.variants.isEmpty) {
      // Nếu không có biến thể, hiển thị thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sản phẩm này không có biến thể khác'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.style_outlined,
                      color: Colors.grey[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chọn biến thể',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Variants list
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: productDetail.variants.length,
                  itemBuilder: (context, index) {
                    final variant = productDetail.variants[index];
                    final isSelected = item.variant == variant.name;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            // Chỉ cần gọi callback, CartService sẽ xử lý việc cập nhật giá
                            onVariantChange(item, variant.name);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.red[50] : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.red[400]! : Colors.grey[200]!,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Variant icon
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.red[600] : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.style,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Variant info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Variant name
                                      Text(
                                        variant.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.red[700] : Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Price info
                                      Row(
                                        children: [
                                          Text(
                                            FormatUtils.formatCurrency(variant.price),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.red[600],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            FormatUtils.formatCurrency(variant.oldPrice ?? 0),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Selection indicator
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.red[600],
                                    size: 20,
                                  )
                                else
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!, width: 1.5),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: const Center(
                        child: Text(
                          'Đóng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

  void _navigateToProductDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          productId: item.id,
          title: item.name,
          image: item.image,
          price: item.price,
        ),
      ),
    );
  }
}
