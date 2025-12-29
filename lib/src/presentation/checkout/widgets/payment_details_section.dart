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
  int? _cachedEligibleTotal;
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
            _cachedEligibleTotal = 0;
            _cachedBonusDiscount = 0;
          });
        }
        return;
      }
      
      final eligibleShopIds = config.eligibleShops.map((s) => s.shopId).toSet();
      
      // ✅ DEBUG: Log eligible shops và items
      // print('   🔍 [Bonus Debug] Eligible shop IDs from config: ${eligibleShopIds.toList()}');
      // print('   🔍 [Bonus Debug] All selected items: ${items.map((i) => 'shopId=${i.shopId}, price=${i.originalPrice ?? i.price}, qty=${i.quantity}').join('; ')}');
      
      // ✅ Lọc items chỉ lấy từ eligible shops
      final eligibleItems = items.where((i) => eligibleShopIds.contains(i.shopId)).toList();
      
      // print('   🔍 [Bonus Debug] Eligible items: ${eligibleItems.map((i) => 'shopId=${i.shopId}, price=${i.originalPrice ?? i.price}, qty=${i.quantity}').join('; ')}');
      
      if (eligibleItems.isEmpty) {
        if (mounted) {
          setState(() {
            _cachedEligibleTotal = 0;
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
      
      // ✅ DEBUG: Print chi tiết tính toán bonus
      final totalShipSupport = ShippingQuoteStore().shipSupport;
      // print('   🔍 [Bonus Calculation] totalGoods=${FormatUtils.formatCurrency(totalGoods)}, shipSupport=${FormatUtils.formatCurrency(totalShipSupport)}');
      // print('   🔍 [Bonus Calculation] eligibleTotal=${FormatUtils.formatCurrency(eligibleTotal)}, eligibleVoucherDiscount=${FormatUtils.formatCurrency(eligibleVoucherDiscount)}, eligibleShipSupport=${FormatUtils.formatCurrency(eligibleShipSupport)} (${totalShipSupport > 0 ? (eligibleShipSupport * 100 / totalShipSupport).toStringAsFixed(1) : 0}% của shipSupport)');
      // print('   🔍 [Bonus Calculation] baseAmount=${FormatUtils.formatCurrency(baseAmount)}, discountPercent=$discountPercent%, rawBonus=${FormatUtils.formatCurrency(rawBonus)}');
      // print('   🔍 [Bonus Calculation] remainingAmount=${FormatUtils.formatCurrency(remainingAmount)}, maxDiscountAmount=${FormatUtils.formatCurrency(maxDiscountAmount)}, finalBonus=${FormatUtils.formatCurrency(bonusDiscount)}');
      
      if (mounted) {
        setState(() {
          _cachedEligibleTotal = baseAmount;
          _cachedBonusDiscount = bonusDiscount;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _cachedEligibleTotal = 0;
          _cachedBonusDiscount = 0;
        });
      }
    }
  }

  void _onVoucherChanged() {
    if (mounted) setState(() {});
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

  
    
    // Tính giảm giá: cộng dồn voucher shop (đã áp dụng) + voucher sàn trên subtotal
    // ✅ QUAN TRỌNG: Dùng originalPrice khi tính voucher discount để đồng bộ với checkout
    final shopDiscount = voucherService.calculateTotalDiscount(
      totalGoods,
      items: items.map((e) => {'shopId': e.shopId, 'price': e.originalPrice ?? e.price, 'quantity': e.quantity}).toList(),
    );
   
    
    // ✅ DEBUG: Kiểm tra voucher shop đang được áp dụng
    final appliedVouchers = voucherService.appliedVouchers;
    if (appliedVouchers.isNotEmpty) {
   
      for (final entry in appliedVouchers.entries) {
        final shopId = entry.key;
        final voucher = entry.value;
        // print('      - Shop $shopId: ${voucher.code} (${voucher.discountType == 'percentage' ? '${voucher.discountValue}%' : FormatUtils.formatCurrency(voucher.discountValue?.round() ?? 0)})');
      }
    }


    // ✅ QUAN TRỌNG: Dùng originalPrice khi tính voucher discount để đồng bộ với checkout
    final platformDiscount = voucherService.calculatePlatformDiscountWithItems(
      totalGoods,
      items.map((e) => e.id).toList(),
      items: items.map((e) => {'id': e.id, 'price': e.originalPrice ?? e.price, 'quantity': e.quantity, 'shopId': e.shopId}).toList(),
    );
  
    final voucherDiscount = (shopDiscount + platformDiscount).clamp(0, totalGoods);
 
    // Lấy phí ship từ store đã cập nhật bởi OrderSummarySection
    final shipFee = ShippingQuoteStore().lastFee;
    final shipSupport = ShippingQuoteStore().shipSupport;

    // ✅ DEBUG: Print tính toán giá tiền trong PaymentDetailsSection
    // print('💳 [CHECKOUT - PaymentDetailsSection] ==========================================');
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
      for (final item in shopItems) {
        final basePrice = item.originalPrice ?? item.price;
        // print('         - ${item.name}: ${FormatUtils.formatCurrency(basePrice)} x ${item.quantity} = ${FormatUtils.formatCurrency(basePrice * item.quantity)}');
      }
    }
    // print('   💰 Tổng tiền hàng: ${FormatUtils.formatCurrency(totalGoods)}');
    // print('   🎫 Voucher shop discount: ${FormatUtils.formatCurrency(shopDiscount)}');
    // print('   🎫 Voucher platform discount: ${FormatUtils.formatCurrency(platformDiscount)}');
    // print('   🎫 Tổng voucher discount: ${FormatUtils.formatCurrency(voucherDiscount)}');
    // print('   🚚 Phí ship: ${FormatUtils.formatCurrency(shipFee)}');
    // print('   🚚 Hỗ trợ ship: ${FormatUtils.formatCurrency(shipSupport)}');
    // print('   💵 Subtotal sau voucher và ship: ${FormatUtils.formatCurrency(totalGoods + shipFee - shipSupport - voucherDiscount)}');

    // ✅ Tính tổng thanh toán trước bonus (sau voucher và ship)
    final subtotalAfterVoucher = (totalGoods + shipFee - shipSupport - voucherDiscount).clamp(0, 1 << 31);

    // ✅ Tính bonus discount: từ config động (discount_percent của ELIGIBLE_TOTAL)
    // Sử dụng cached value (đã tính trong _calculateBonus)
    final bonusDiscount = _cachedBonusDiscount ?? 0;
    
    final grandTotal = (subtotalAfterVoucher - bonusDiscount).clamp(0, 1 << 31);
    
    // print('   🎁 Bonus discount: ${FormatUtils.formatCurrency(bonusDiscount)}');
    // print('   💵 Tổng thanh toán cuối cùng: ${FormatUtils.formatCurrency(grandTotal)}');
    // print('   ✅ Applied vouchers: ${voucherService.appliedVouchers.length} shop vouchers');
    for (final entry in voucherService.appliedVouchers.entries) {
      // print('      - Shop ${entry.key}: ${entry.value.code} (${entry.value.discountType == 'percentage' ? '${entry.value.discountValue}%' : FormatUtils.formatCurrency(entry.value.discountValue?.round() ?? 0)})');
    }
    // print('   ✅ Platform vouchers: ${voucherService.platformVouchers.length} vouchers');
    for (final entry in voucherService.platformVouchers.entries) {
      // print('      - ${entry.key}: ${entry.value.discountType == 'percentage' ? '${entry.value.discountValue}%' : FormatUtils.formatCurrency(entry.value.discountValue?.round() ?? 0)}}');
    }
  
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
               
                if (shipSupport > 0) {
                 
                  return Column(
                    children: [
                      PaymentDetailRow('Tổng phí vận chuyển', FormatUtils.formatCurrency(shipFee)),
                      PaymentDetailRow('Hỗ trợ vận chuyển', '-${FormatUtils.formatCurrency(shipSupport)}', isRed: true),
                    ],
                  );
                } else {
                
                  return PaymentDetailRow('Tổng phí vận chuyển', FormatUtils.formatCurrency(shipFee));
                }
              } else {
                
                return const SizedBox.shrink();
              }
            },
          ),
          
          PaymentDetailRow('Tổng Voucher giảm giá', '${FormatUtils.formatCurrency(voucherDiscount)}', isRed: true),
          // ✅ Hiển thị bonus discount nếu có
          if (bonusDiscount > 0)
            PaymentDetailRow('🎁 Voucher giảm giá', '-${FormatUtils.formatCurrency(bonusDiscount)}', isRed: true),
          const Divider(height: 20),
          PaymentDetailRow('Tổng thanh toán', FormatUtils.formatCurrency(grandTotal), isBold: true),
        ],
      ),
    );
  }
}
