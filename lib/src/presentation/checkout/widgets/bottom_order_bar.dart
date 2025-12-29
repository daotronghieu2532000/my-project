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
  int? _cachedBonusDiscount;

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
    if (mounted) {
      _calculateBonus(); // Recalculate khi cart thay đổi
    }
  }

  Future<void> _calculateBonus() async {
    final cart = cart_service.CartService();
    final voucherService = VoucherService();
    final items = cart.items.where((i) => i.isSelected).toList();
    
    if (!_bonusLoading && _bonusService.canUseBonus(_bonusInfo)) {
      // ✅ Lấy config để biết eligible shop IDs
      final config = await _bonusService.getBonusConfig();
      if (config == null || !config.status) {
        if (mounted) {
          setState(() {
            _cachedBonusDiscount = 0;
          });
        }
        return;
      }
      
      final eligibleShopIds = config.eligibleShops.map((s) => s.shopId).toSet();
      
      // ✅ Lọc items chỉ lấy từ eligible shops
      final eligibleItems = items.where((i) => eligibleShopIds.contains(i.shopId)).toList();
      
      if (eligibleItems.isEmpty) {
        if (mounted) {
          setState(() {
            _cachedBonusDiscount = 0;
          });
        }
        return;
      }
      
      // ✅ Tính tổng dựa trên originalPrice (giá gốc) CHỈ cho eligible shops
      final eligibleTotal = eligibleItems.fold(0, (s, i) => s + ((i.originalPrice ?? i.price) * i.quantity));
      final totalGoods = items.fold(0, (s, i) => s + ((i.originalPrice ?? i.price) * i.quantity));
      
      // ✅ Tính voucher discount CHỈ cho eligible shops
      final eligibleItemsForVoucher = eligibleItems.map((e) => {'shopId': e.shopId, 'price': e.originalPrice ?? e.price, 'quantity': e.quantity}).toList();
      final eligibleShopDiscount = voucherService.calculateTotalDiscount(
        eligibleTotal,
        items: eligibleItemsForVoucher,
      );
      final eligiblePlatformDiscount = voucherService.calculatePlatformDiscountWithItems(
        eligibleTotal,
        eligibleItems.map((e) => e.id).toList(),
        items: eligibleItems.map((e) => {'id': e.id, 'price': e.originalPrice ?? e.price, 'quantity': e.quantity, 'shopId': e.shopId}).toList(),
      );
      final eligibleVoucherDiscount = (eligibleShopDiscount + eligiblePlatformDiscount).clamp(0, eligibleTotal);
      
      // ✅ Lấy ship support TRỰC TIẾP từ eligible shops (giống API), KHÔNG phân bổ theo tỷ lệ
      final shopShipSupportMap = ShippingQuoteStore().shopShipSupport;
      int eligibleShipSupport = 0;
      final Set<int> processedShops = {}; // Để đảm bảo mỗi shop chỉ tính 1 lần
      for (final item in eligibleItems) {
        final shopId = item.shopId;
        if (!processedShops.contains(shopId) && shopShipSupportMap.containsKey(shopId)) {
          // ✅ Lấy ship support từ map (mỗi shop chỉ lấy 1 lần, giống API logic)
          eligibleShipSupport += shopShipSupportMap[shopId]!;
          processedShops.add(shopId);
        }
      }
      // ✅ Nếu không có trong map, fallback về phân bổ theo tỷ lệ (tạm thời)
      if (eligibleShipSupport == 0) {
        final shipSupport = ShippingQuoteStore().shipSupport;
        eligibleShipSupport = totalGoods > 0 
            ? ((shipSupport * eligibleTotal / totalGoods).round())
            : 0;
      }
      
      // ✅ Tính base amount: eligibleTotal - eligibleVoucherDiscount - eligibleShipSupport
      final baseAmount = (eligibleTotal - eligibleVoucherDiscount - eligibleShipSupport).clamp(0, 1 << 31);
      
      // ✅ Lấy discount percent từ config
      final discountPercent = config.discountPercent;
      
      // ✅ Tính bonus discount: baseAmount * discountPercent / 100
      final rawBonus = (baseAmount * discountPercent / 100).floor();
      
      // ✅ Lấy min của: rawBonus, remainingAmount, maxDiscountAmount
      final remainingAmount = _bonusInfo!['remaining_amount'] as int? ?? 0;
      final maxDiscountAmount = config.maxDiscountAmount;
      final bonusDiscount = rawBonus < remainingAmount 
          ? (rawBonus < maxDiscountAmount ? rawBonus : maxDiscountAmount)
          : (remainingAmount < maxDiscountAmount ? remainingAmount : maxDiscountAmount);
      
      if (mounted) {
        setState(() {
          _cachedBonusDiscount = bonusDiscount;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _cachedBonusDiscount = 0;
        });
      }
    }
  }

  void _onVoucherChanged() {
    if (mounted) {
      _calculateBonus(); // Recalculate khi voucher thay đổi
    }
  }

  void _onShippingChanged() {
    if (mounted) {
      _calculateBonus(); // Recalculate khi shipping thay đổi
    }
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
      // Tính bonus sau khi có bonusInfo
      await _calculateBonus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = cart_service.CartService();
    final voucherService = VoucherService();
    final items = cart.items.where((i) => i.isSelected).toList();
    // ✅ Tính tổng dựa trên originalPrice (giá gốc) để tính toán đúng trong checkout
    final totalGoods = items.fold(0, (s, i) => s + ((i.originalPrice ?? i.price) * i.quantity));
    final savingsFromOld = items.fold<int>(0, (s, i) {
      final basePrice = i.originalPrice ?? i.price;
      if (i.oldPrice != null && i.oldPrice! > basePrice) {
        return s + (i.oldPrice! - basePrice) * i.quantity;
      }
      return s;
    });
    // Cộng dồn giảm giá shop + sàn theo giỏ hàng hiện tại - ✅ Dùng originalPrice
    final shopDiscount = voucherService.calculateTotalDiscount(
      totalGoods,
      items: items.map((e) => {'shopId': e.shopId, 'price': e.originalPrice ?? e.price, 'quantity': e.quantity}).toList(),
    );
    final platformDiscount = voucherService.calculatePlatformDiscountWithItems(
      totalGoods,
      items.map((e) => e.id).toList(),
      items: items.map((e) => {'id': e.id, 'price': e.originalPrice ?? e.price, 'quantity': e.quantity, 'shopId': e.shopId}).toList(),
    );
    final voucherDiscount = (shopDiscount + platformDiscount).clamp(0, totalGoods);
    final shipFee = ShippingQuoteStore().lastFee;
    final shipSupport = ShippingQuoteStore().shipSupport;

    // ✅ Tính tổng thanh toán trước bonus (sau voucher và ship)
    final subtotalAfterVoucher = (totalGoods + shipFee - shipSupport - voucherDiscount).clamp(0, 1 << 31);



    // ✅ Tính bonus discount: từ config động (discount_percent của ELIGIBLE_TOTAL)
    // Sử dụng cached value (đã tính trong _calculateBonus)
    final bonusDiscount = _cachedBonusDiscount ?? 0;
    
    final grandTotal = (subtotalAfterVoucher - bonusDiscount).clamp(0, 1 << 31);
  
    // ✅ DEBUG: Print tính toán giá tiền trong BottomOrderBar
    // print('💰 [CHECKOUT - BottomOrderBar] ==========================================');
    // print('   📦 Items: ${items.length} sản phẩm');
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
      // ✅ Tính tổng dựa trên originalPrice (giá gốc) để tính toán đúng trong checkout
      final shopTotal = shopItems.fold(0, (s, i) => s + ((i.originalPrice ?? i.price) * i.quantity));
      // print('      Shop $shopId: ${shopItems.length} sản phẩm = ${FormatUtils.formatCurrency(shopTotal)}');
    }
    // print('   💰 Tổng tiền hàng: ${FormatUtils.formatCurrency(totalGoods)}');
    // print('   🎫 Voucher shop discount: ${FormatUtils.formatCurrency(shopDiscount)}');
    // print('   🎫 Voucher platform discount: ${FormatUtils.formatCurrency(platformDiscount)}');
    // print('   🎫 Tổng voucher discount: ${FormatUtils.formatCurrency(voucherDiscount)}');
    // print('   🚚 Phí ship: ${FormatUtils.formatCurrency(shipFee)}');
    // print('   🚚 Hỗ trợ ship: ${FormatUtils.formatCurrency(shipSupport)}');
    // print('   💵 Subtotal sau voucher và ship: ${FormatUtils.formatCurrency(subtotalAfterVoucher)}');
    // print('   🎁 Bonus discount: ${FormatUtils.formatCurrency(bonusDiscount)}');
    // print('   💵 Tổng thanh toán cuối cùng: ${FormatUtils.formatCurrency(grandTotal)}');
    // print('   💰 Tiết kiệm từ giá cũ: ${FormatUtils.formatCurrency(savingsFromOld)}');
    // print('   💰 Tổng tiết kiệm: ${FormatUtils.formatCurrency((savingsFromOld + voucherDiscount + bonusDiscount).clamp(0, totalGoods + bonusDiscount))}');
    // print('💰 ==========================================================');

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