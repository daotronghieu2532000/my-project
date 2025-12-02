import 'package:flutter/material.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/models/product_detail.dart';
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
    // ✅ Sử dụng API nhẹ hơn - chỉ lấy biến thể (nhanh hơn getProductDetail)
    final apiService = ApiService();
    
    // Thử dùng getProductVariants trước (API nhẹ nhất, chỉ lấy biến thể)
    ProductDetail? productDetail = await apiService.getProductVariants(item.id);
    
    // Nếu không có, fallback về getProductDetailBasic (nhẹ hơn getProductDetail)
    if (productDetail == null) {
      productDetail = await apiService.getProductDetailBasic(item.id);
    }
    
    // Nếu vẫn không có, mới dùng getProductDetail (API đầy đủ - chậm nhất)
    if (productDetail == null) {
      productDetail = await apiService.getProductDetail(item.id);
    }
    
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
    
    // ✅ Đảm bảo productDetail không null (đã check ở trên)
    final validProductDetail = productDetail;
    
    // Tìm biến thể hiện tại được chọn
    ProductVariant? currentSelectedVariant;
    if (item.variant != null) {
      currentSelectedVariant = validProductDetail.variants.firstWhere(
        (v) => v.name == item.variant,
        orElse: () => validProductDetail.variants.first,
      );
    } else {
      currentSelectedVariant = validProductDetail.variants.first;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VariantSelectionBottomSheet(
        productDetail: validProductDetail,
        currentSelectedVariant: currentSelectedVariant,
        item: item,
        onVariantChange: onVariantChange,
      ),
    );
  }
}

// ✅ Widget riêng để quản lý state cho dialog chọn biến thể
class _VariantSelectionBottomSheet extends StatefulWidget {
  final ProductDetail productDetail;
  final ProductVariant? currentSelectedVariant;
  final CartItem item;
  final Function(CartItem, String?) onVariantChange;

  const _VariantSelectionBottomSheet({
    required this.productDetail,
    required this.currentSelectedVariant,
    required this.item,
    required this.onVariantChange,
  });

  @override
  State<_VariantSelectionBottomSheet> createState() => _VariantSelectionBottomSheetState();
}

class _VariantSelectionBottomSheetState extends State<_VariantSelectionBottomSheet> {
  late ProductVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.currentSelectedVariant;
  }

  @override
  Widget build(BuildContext context) {
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
                  // Header với ảnh sản phẩm
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Product image - có thể click để xem toàn màn hình
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                insetPadding: const EdgeInsets.all(12),
                                child: InteractiveViewer(
                                  child: Image.network(
                                    _selectedVariant?.imageUrl ?? widget.productDetail.imageUrl,
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
                                _selectedVariant?.imageUrl ?? widget.productDetail.imageUrl,
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
                                widget.productDetail.name,
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
                                    FormatUtils.formatCurrency(_selectedVariant?.price ?? widget.productDetail.price),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  if (_selectedVariant?.oldPrice != null && _selectedVariant!.oldPrice! > _selectedVariant!.price) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      FormatUtils.formatCurrency(_selectedVariant!.oldPrice!),
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
                  
                  // Variant selection với Wrap layout
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
                            for (final variant in widget.productDetail.variants)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedVariant = variant;
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
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // ✅ Hiển thị ảnh biến thể nếu có
                                      if (variant.imageUrl != null && variant.imageUrl!.isNotEmpty) ...[
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: (_selectedVariant?.id == variant.id) ? Colors.red : Colors.grey[300]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: Image.network(
                                              variant.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.image_not_supported, size: 12, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        variant.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: (_selectedVariant?.id == variant.id) ? FontWeight.w600 : FontWeight.normal,
                                          color: (_selectedVariant?.id == variant.id) ? Colors.red : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action button
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_selectedVariant != null) {
                                Navigator.pop(context);
                                widget.onVariantChange(widget.item, _selectedVariant!.name);
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
                              'Xác nhận',
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
