import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../../core/services/voucher_service.dart';
import '../../../core/services/shipping_quote_store.dart';

class BottomOrderBar extends StatefulWidget {
  final int totalPrice;
  final bool isProcessing;
  final VoidCallback onOrder;

  const BottomOrderBar({
    super.key,
    required this.totalPrice,
    this.isProcessing = false,
    required this.onOrder,
  });

  @override
  State<BottomOrderBar> createState() => _BottomOrderBarState();
}

class _BottomOrderBarState extends State<BottomOrderBar> {
  @override
  void initState() {
    super.initState();
    // Lắng nghe thay đổi giỏ hàng, voucher và phí ship để cập nhật real-time
    cart_service.CartService().addListener(_onCartChanged);
    VoucherService().addListener(_onVoucherChanged);
    ShippingQuoteStore().addListener(_onShippingChanged);
  }

  @override
  void dispose() {
    cart_service.CartService().removeListener(_onCartChanged);
    VoucherService().removeListener(_onVoucherChanged);
    ShippingQuoteStore().removeListener(_onShippingChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  void _onVoucherChanged() {
    if (mounted) setState(() {});
  }

  void _onShippingChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cart = cart_service.CartService();
    final voucherService = VoucherService();
    final items = cart.items.where((i) => i.isSelected).toList();
    final totalGoods = items.fold(0, (s, i) => s + i.price * i.quantity);
    final savingsFromOld = items.fold<int>(0, (s, i) {
      if (i.oldPrice != null && i.oldPrice! > i.price) {
        return s + (i.oldPrice! - i.price) * i.quantity;
      }
      return s;
    });
    // Cộng dồn giảm giá shop + sàn theo giỏ hàng hiện tại
    final shopDiscount = voucherService.calculateTotalDiscount(
      totalGoods,
      items: items.map((e) => {'shopId': e.shopId, 'price': e.price, 'quantity': e.quantity}).toList(),
    );
    final platformDiscount = voucherService.calculatePlatformDiscountWithItems(
      totalGoods,
      items.map((e) => e.id).toList(),
      items: items.map((e) => {'id': e.id, 'price': e.price, 'quantity': e.quantity}).toList(),
    );
    final voucherDiscount = (shopDiscount + platformDiscount).clamp(0, totalGoods);
    final shipFee = ShippingQuoteStore().lastFee;
    final shipSupport = ShippingQuoteStore().shipSupport;
    final grandTotal = (totalGoods + shipFee - shipSupport - voucherDiscount).clamp(0, 1 << 31);
    // Không để tiết kiệm vượt quá tổng tiền hàng (UX các sàn lớn)
    final totalSavings = (savingsFromOld + voucherDiscount).clamp(0, totalGoods);
    
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Tổng: ${FormatUtils.formatCurrency(grandTotal)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Tiết kiệm ${FormatUtils.formatCurrency(totalSavings)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: widget.isProcessing ? null : widget.onOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  // Giữ nguyên màu đỏ ngay cả khi disabled
                  disabledBackgroundColor: Colors.red,
                  // Giảm opacity khi disabled để có hiệu ứng mờ nhẹ
                  disabledForegroundColor: Colors.white,
                ),
                child: widget.isProcessing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Đang xử lý...',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                      )
                    : const Text(
                        'ĐẶT HÀNG',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}