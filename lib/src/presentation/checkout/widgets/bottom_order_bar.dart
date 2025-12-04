import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/utils/format_utils.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../../core/services/voucher_service.dart';
import '../../../core/services/first_time_bonus_service.dart';
import '../../../core/services/auth_service.dart';
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
  final FirstTimeBonusService _bonusService = FirstTimeBonusService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _bonusInfo;
  bool _bonusLoading = true;

  @override
  void initState() {
    super.initState();
    // Lắng nghe thay đổi giỏ hàng, voucher và phí ship để cập nhật real-time
    cart_service.CartService().addListener(_onCartChanged);
    VoucherService().addListener(_onVoucherChanged);
    ShippingQuoteStore().addListener(_onShippingChanged);
    _loadBonusInfo();
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

  Future<void> _loadBonusInfo() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _bonusLoading = false;
          _bonusInfo = null;
        });
      }
      return;
    }

    final user = await _authService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        setState(() {
          _bonusLoading = false;
          _bonusInfo = null;
        });
      }
      return;
    }

    // ✅ LUÔN gọi API để lấy thông tin bonus mới nhất (không dùng cache)
    // Vì bonus có thể đã hết sau khi đặt hàng thành công
    await _fetchBonusInfo(user.userId);
  }

  Future<void> _fetchBonusInfo(int userId) async {
    final bonusInfo = await _bonusService.getBonusInfo(userId);
    
    // ✅ Cập nhật SharedPreferences với thông tin mới nhất
    if (bonusInfo != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('first_time_bonus_info', jsonEncode(bonusInfo));
    }
    
    if (mounted) {
      setState(() {
        _bonusInfo = bonusInfo;
        _bonusLoading = false;
      });
    }
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

    // ✅ Tính tổng thanh toán trước bonus (sau voucher và ship)
    final subtotalAfterVoucher = (totalGoods + shipFee - shipSupport - voucherDiscount).clamp(0, 1 << 31);



    // ✅ Tính bonus discount: 10% của ELIGIBLE TOTAL (chỉ các shop hợp lệ), KHÔNG phải totalGoods
    int bonusDiscount = 0;

    if (!_bonusLoading && _bonusService.canUseBonus(_bonusInfo)) {
      final remainingAmount = _bonusInfo!['remaining_amount'] as int? ?? 0;
      
      // ✅ Tính eligibleTotal (chỉ các shop hợp lệ: 32373, 23933, 36893, 35683, 35681)
      final eligibleItems = items.map((e) => {
        'shopId': e.shopId,
        'price': e.price,
        'quantity': e.quantity,
      }).toList();
      final eligibleTotal = _bonusService.calculateEligibleTotal(eligibleItems);
      
    
      bonusDiscount = _bonusService.calculateBonusAmount(eligibleTotal, remainingAmount);
     
    
    } 
    
    final grandTotal = (subtotalAfterVoucher - bonusDiscount).clamp(0, 1 << 31);
  
    // ✅ DEBUG: Print tính toán giá tiền trong BottomOrderBar
    print('💰 [CHECKOUT - BottomOrderBar] ==========================================');
    print('   📦 Items: ${items.length} sản phẩm');
    final itemsByShop = <int, List<cart_service.CartItem>>{};
    for (final item in items) {
      if (!itemsByShop.containsKey(item.shopId)) {
        itemsByShop[item.shopId] = [];
      }
      itemsByShop[item.shopId]!.add(item);
    }
    for (final entry in itemsByShop.entries) {
      final shopId = entry.key;
      final shopItems = entry.value;
      final shopTotal = shopItems.fold(0, (s, i) => s + i.price * i.quantity);
      print('      Shop $shopId: ${shopItems.length} sản phẩm = ${FormatUtils.formatCurrency(shopTotal)}');
    }
    print('   💰 Tổng tiền hàng: ${FormatUtils.formatCurrency(totalGoods)}');
    print('   🎫 Voucher shop discount: ${FormatUtils.formatCurrency(shopDiscount)}');
    print('   🎫 Voucher platform discount: ${FormatUtils.formatCurrency(platformDiscount)}');
    print('   🎫 Tổng voucher discount: ${FormatUtils.formatCurrency(voucherDiscount)}');
    print('   🚚 Phí ship: ${FormatUtils.formatCurrency(shipFee)}');
    print('   🚚 Hỗ trợ ship: ${FormatUtils.formatCurrency(shipSupport)}');
    print('   💵 Subtotal sau voucher và ship: ${FormatUtils.formatCurrency(subtotalAfterVoucher)}');
    print('   🎁 Bonus discount: ${FormatUtils.formatCurrency(bonusDiscount)}');
    print('   💵 Tổng thanh toán cuối cùng: ${FormatUtils.formatCurrency(grandTotal)}');
    print('   💰 Tiết kiệm từ giá cũ: ${FormatUtils.formatCurrency(savingsFromOld)}');
    print('   💰 Tổng tiết kiệm: ${FormatUtils.formatCurrency((savingsFromOld + voucherDiscount + bonusDiscount).clamp(0, totalGoods + bonusDiscount))}');
    print('💰 ==========================================================');

    // Không để tiết kiệm vượt quá tổng tiền hàng (UX các sàn lớn)
    final totalSavings = (savingsFromOld + voucherDiscount + bonusDiscount).clamp(0, totalGoods + bonusDiscount);
 
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