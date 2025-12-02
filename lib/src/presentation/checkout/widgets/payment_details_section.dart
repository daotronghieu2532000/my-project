import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'payment_detail_row.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../../core/services/voucher_service.dart';
import '../../../core/services/first_time_bonus_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/services/shipping_quote_store.dart';

class PaymentDetailsSection extends StatefulWidget {
  const PaymentDetailsSection({super.key});

  @override
  State<PaymentDetailsSection> createState() => _PaymentDetailsSectionState();
}

class _PaymentDetailsSectionState extends State<PaymentDetailsSection> {
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

    // ✅ Tính eligible_total (CHỈ từ 3 shop hợp lệ: 32373, 23933, 36893)
    final eligibleItems = items.map((i) => {
      'shopId': i.shopId,
      'price': i.price,
      'quantity': i.quantity,
    }).toList();
    final eligibleTotal = _bonusService.calculateEligibleTotal(eligibleItems);

  
    
    // Tính giảm giá: cộng dồn voucher shop (đã áp dụng) + voucher sàn trên subtotal
    final shopDiscount = voucherService.calculateTotalDiscount(
      totalGoods,
      items: items.map((e) => {'shopId': e.shopId, 'price': e.price, 'quantity': e.quantity}).toList(),
    );
    print('   - shopDiscount: ${FormatUtils.formatCurrency(shopDiscount)}');
    
    // ✅ DEBUG: Kiểm tra voucher shop đang được áp dụng
    final appliedVouchers = voucherService.appliedVouchers;
    if (appliedVouchers.isNotEmpty) {
      print('   - ⚠️ Có ${appliedVouchers.length} voucher shop đang được áp dụng:');
      for (final entry in appliedVouchers.entries) {
        final shopId = entry.key;
        final voucher = entry.value;
        print('     + Shop $shopId: ${voucher.code} - ${FormatUtils.formatCurrency(voucher.discountValue?.round() ?? 0)}');
      }
    } else {
      print('   - ✅ Không có voucher shop nào được áp dụng');
    }

    final platformDiscount = voucherService.calculatePlatformDiscountWithItems(
      totalGoods,
      items.map((e) => e.id).toList(),
      items: items.map((e) => {'id': e.id, 'price': e.price, 'quantity': e.quantity}).toList(),
    );
    print('   - platformDiscount: ${FormatUtils.formatCurrency(platformDiscount)}');

    final voucherDiscount = (shopDiscount + platformDiscount).clamp(0, totalGoods);
    print('   - ✅ Tổng voucherDiscount: ${FormatUtils.formatCurrency(voucherDiscount)}');

    // Lấy phí ship từ store đã cập nhật bởi OrderSummarySection
    final shipFee = ShippingQuoteStore().lastFee;
    final shipSupport = ShippingQuoteStore().shipSupport;

   

    // ✅ Tính tổng thanh toán trước bonus (sau voucher và ship)
    final subtotalAfterVoucher = (totalGoods + shipFee - shipSupport - voucherDiscount).clamp(0, 1 << 31);

    // ✅ Tính bonus discount: 10% của ELIGIBLE_TOTAL (CHỈ 3 shop), KHÔNG phải totalGoods
    int bonusDiscount = 0;

    
    if (!_bonusLoading && _bonusService.canUseBonus(_bonusInfo)) {
      final remainingAmount = _bonusInfo!['remaining_amount'] as int? ?? 0;
     
      
      // ✅ Tính 10% của ELIGIBLE_TOTAL (CHỈ 3 shop), không phải totalGoods
      bonusDiscount = _bonusService.calculateBonusAmount(eligibleTotal, remainingAmount);
     
    } else {
      print('   - Skipping bonus calculation (loading=$_bonusLoading, canUse=${_bonusService.canUseBonus(_bonusInfo)})');
    }
    
    final grandTotal = (subtotalAfterVoucher - bonusDiscount).clamp(0, 1 << 31);

    // Debug log để so sánh với BottomOrderBar
   

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết thanh toán',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 16),
          PaymentDetailRow('Tổng tiền hàng', FormatUtils.formatCurrency(totalGoods)),
          // ✅ DEBUG: Kiểm tra logic hiển thị phí ship
          Builder(
            builder: (context) {
           
              
              // ✅ Vấn đề 2: Nếu không có hỗ trợ ship (shipSupport = 0) nhưng có phí ship (shipFee > 0)
              // thì vẫn cần hiển thị phí ship
              if (shipFee > 0) {
                print('   - ✅ Hiển thị phí vận chuyển: ${FormatUtils.formatCurrency(shipFee)}');
                if (shipSupport > 0) {
                  print('   - ✅ Hiển thị hỗ trợ ship: ${FormatUtils.formatCurrency(shipSupport)}');
                  return Column(
                    children: [
                      PaymentDetailRow('Tổng phí vận chuyển', FormatUtils.formatCurrency(shipFee)),
                      PaymentDetailRow('Hỗ trợ ship', '-${FormatUtils.formatCurrency(shipSupport)}', isRed: true),
                    ],
                  );
                } else {
                  print('   - ⚠️ Không có hỗ trợ ship nhưng vẫn hiển thị phí ship');
                  return PaymentDetailRow('Tổng phí vận chuyển', FormatUtils.formatCurrency(shipFee));
                }
              } else {
                print('   - ❌ Không hiển thị phí vận chuyển (shipFee = 0)');
                return const SizedBox.shrink();
              }
            },
          ),
          
          PaymentDetailRow('Tổng Voucher giảm giá', '-${FormatUtils.formatCurrency(voucherDiscount)}', isRed: true),
          // ✅ Hiển thị bonus discount nếu có
          if (bonusDiscount > 0)
            PaymentDetailRow('🎁 Quà tặng lần đầu tải ứng dụng', '-${FormatUtils.formatCurrency(bonusDiscount)}', isRed: true),
          const Divider(height: 20),
          PaymentDetailRow('Tổng thanh toán', FormatUtils.formatCurrency(grandTotal), isBold: true),
        ],
      ),
    );
  }
}
