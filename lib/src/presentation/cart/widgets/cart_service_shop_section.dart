import 'package:flutter/material.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/voucher_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/format_utils.dart';
import 'cart_service_item_tile.dart';
import 'voucher_dialog.dart';

class CartServiceShopSection extends StatelessWidget {
  final String shopName;
  final List<CartItem> items;
  final VoidCallback onChanged;
  final bool isEditMode;
  
  const CartServiceShopSection({
    super.key, 
    required this.shopName, 
    required this.items, 
    required this.onChanged,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();
    final voucherService = VoucherService();
    
    // Tính tổng tiền của shop
    final shopTotal = items.fold(0, (sum, item) => sum + (item.price * item.quantity));
    final shopId = items.isNotEmpty ? items.first.shopId : 0;
    final appliedVoucher = voucherService.getAppliedVoucher(shopId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Shop header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: items.every((item) => item.isSelected),
                  activeColor: Colors.red,
                  onChanged: (v) {
                    final cartService = CartService();
                    for (final item in items) {
                      // Chỉ toggle nếu giá trị khác với giá trị mong muốn
                      if (item.isSelected != (v ?? false)) {
                        cartService.toggleItemSelection(item.id, variant: item.variant);
                      }
                    }
                    onChanged();
                  },
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shopName, 
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _showDeleteShopDialog(context, cartService);
                  }, 
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Xóa'),
                ),
              ],
            ),
          ),
          // Items
          for (final item in items)
            CartServiceItemTile(
              item: item, 
              onChanged: onChanged,
              onDelete: (item) {
                cartService.removeCartItem(item);
                onChanged();
              },
              onVariantChange: (item, newVariant) async {
                // Lấy thông tin sản phẩm để có giá của biến thể mới
                final apiService = ApiService();
                final productDetail = await apiService.getProductDetail(item.id);
                
                if (productDetail != null && productDetail.variants.isNotEmpty) {
                  // Tìm biến thể được chọn
                  final selectedVariant = productDetail.variants.firstWhere(
                    (v) => v.name == newVariant,
                    orElse: () => productDetail.variants.first,
                  );
                  
                  cartService.updateItemVariant(
                    item, 
                    newVariant,
                    newPrice: selectedVariant.price,
                    newOldPrice: selectedVariant.oldPrice ?? 0,
                  );
                } else {
                  // Fallback nếu không lấy được biến thể
                  cartService.updateItemVariant(item, newVariant);
                }
                onChanged();
              },
              onQuantityChange: (item, quantity) {
                cartService.updateQuantity(item.id, quantity, variant: item.variant);
                onChanged();
              },
              isEditMode: isEditMode,
            ),
          // ✅ Shop 0 (Sàn TMĐT) không có voucher shop, bỏ qua phần này
          if (shopId > 0) ...[
          const Divider(height: 1),
          // Shop discount code
          InkWell(
            onTap: () => _showVoucherDialog(context, shopId, shopTotal, appliedVoucher),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    appliedVoucher != null ? Icons.local_offer : Icons.local_offer_outlined, 
                    color: appliedVoucher != null ? Colors.red : Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appliedVoucher != null ? 'Đã áp dụng mã giảm giá' : 'Mã giảm giá của shop',
                          style: TextStyle(
                            color: appliedVoucher != null ? Colors.red : Colors.black87,
                            fontWeight: appliedVoucher != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (appliedVoucher != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${appliedVoucher.code} - Giảm ${_getDiscountText(appliedVoucher)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    appliedVoucher != null ? Icons.check_circle : Icons.chevron_right,
                    color: appliedVoucher != null ? Colors.red : Colors.grey,
                    size: appliedVoucher != null ? 20 : 16,
                  ),
                ],
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  void _showDeleteShopDialog(BuildContext context, CartService cartService) {
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
                        Icons.store_outlined,
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
                            'Xóa shop',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bạn có chắc muốn xóa tất cả sản phẩm của shop này?',
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
              
              // Shop info
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.store,
                        color: Colors.red[600],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${items.length} sản phẩm sẽ bị xóa',
                            style: TextStyle(
                              fontSize: 13,
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
              cartService.clearShopItems(items.first.shopId);
              onChanged();
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

  void _showVoucherDialog(BuildContext context, int shopId, int shopTotal, appliedVoucher) {
    // Get product IDs from cart items
    final cartProductIds = items.map((item) => item.id).toList();
    
    showDialog(
      context: context,
      builder: (context) => VoucherDialog(
        shopId: shopId,
        shopName: shopName,
        shopTotal: shopTotal,
        currentVoucher: appliedVoucher,
        cartProductIds: cartProductIds,
      ),
    ).then((result) {
      if (result != null) {
        onChanged(); // Refresh UI
      }
    });
  }

  String _getDiscountText(appliedVoucher) {
    if (appliedVoucher.discountType == 'percentage') {
      return '${appliedVoucher.discountValue?.toInt()}%';
    } else {
      return FormatUtils.formatCurrency(appliedVoucher.discountValue?.round() ?? 0);
    }
  }
}
