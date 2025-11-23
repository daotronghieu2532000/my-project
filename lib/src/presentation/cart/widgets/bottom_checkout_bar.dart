import 'package:flutter/material.dart';
import '../../checkout/checkout_screen.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/services/voucher_service.dart';
import '../../../core/services/cart_service.dart' as cart_service;

class BottomCheckoutBar extends StatelessWidget {
  final bool selectAll;
  final ValueChanged<bool> onToggleAll;
  final int totalPrice;
  final int selectedCount;
  final int totalSavings;
  final bool isEditMode;
  final VoidCallback? onDeleteSelected;
  
  const BottomCheckoutBar({
    super.key,
    required this.selectAll,
    required this.onToggleAll,
    required this.totalPrice,
    required this.selectedCount,
    this.totalSavings = 0,
    this.isEditMode = false,
    this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final voucherService = VoucherService();
    final cart = cart_service.CartService();
    
    // ✅ Lấy items đã chọn để tính voucher đúng (theo shop)
    final items = cart.items.where((i) => i.isSelected).toList();
    
    // ✅ Tính voucher discount đúng như checkout (theo shop và theo sản phẩm áp dụng)
    final shopDiscount = voucherService.calculateTotalDiscount(
      totalPrice,
      items: items.map((e) => {'shopId': e.shopId, 'price': e.price, 'quantity': e.quantity}).toList(),
    );
    final platformDiscount = voucherService.calculatePlatformDiscountWithItems(
      totalPrice,
      items.map((e) => e.id).toList(),
      items: items.map((e) => {'id': e.id, 'price': e.price, 'quantity': e.quantity}).toList(),
    );
    final voucherDiscount = (shopDiscount + platformDiscount).clamp(0, totalPrice);
    final finalPrice = totalPrice - voucherDiscount;
    
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Select all row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => onToggleAll(!selectAll),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: selectAll ? Colors.red : Colors.transparent,
                            border: Border.all(
                              color: selectAll ? Colors.red : Colors.grey[400]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: selectAll
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tất cả',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Savings info (compact)
                  if ((totalSavings + voucherDiscount) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.savings_outlined,
                            color: Colors.red[600],
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tiết kiệm ${FormatUtils.formatCurrency(totalSavings + voucherDiscount)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Main checkout row
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  // Price section (left)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total price
                        Row(
                          children: [
                            Text(
                              'Tổng: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                FormatUtils.formatCurrency(finalPrice),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        // Original price (if voucher applied)
                        if (voucherDiscount > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Giá gốc: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  FormatUtils.formatCurrency(totalPrice),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Checkout button (right)
                  Container(
                    height: 44,
                    constraints: const BoxConstraints(minWidth: 120),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: selectedCount > 0 
                            ? [Colors.red[500]!, Colors.red[600]!]
                            : [Colors.grey[400]!, Colors.grey[500]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: selectedCount > 0 ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: selectedCount == 0 ? null : () {
                          if (isEditMode && onDeleteSelected != null) {
                            onDeleteSelected!();
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CheckoutScreen(),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEditMode ? Icons.delete_outline : Icons.shopping_cart_checkout,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isEditMode ? 'XÓA ($selectedCount)' : 'THANH TOÁN ($selectedCount)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
    );
  }
}
