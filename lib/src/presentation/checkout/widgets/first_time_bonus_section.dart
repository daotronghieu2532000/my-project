import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/services/first_time_bonus_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../../core/services/voucher_service.dart';
import '../../../core/services/shipping_quote_store.dart';
import 'bonus_info_bottom_sheet.dart';

class FirstTimeBonusSection extends StatefulWidget {
  const FirstTimeBonusSection({super.key});

  @override
  State<FirstTimeBonusSection> createState() => _FirstTimeBonusSectionState();
}

class _FirstTimeBonusSectionState extends State<FirstTimeBonusSection> {
  final FirstTimeBonusService _bonusService = FirstTimeBonusService();
  final AuthService _authService = AuthService();
  final cart_service.CartService _cartService = cart_service.CartService();
  Map<String, dynamic>? _bonusInfo;
  bool _loading = true;
  int? _eligibleTotal;
  int? _bonusAmount;
  double? _discountPercent;

  @override
  void initState() {
    super.initState();
    _loadBonusInfo();
    // ✅ Lắng nghe thay đổi cart, voucher và phí ship để cập nhật real-time
    _cartService.addListener(_onCartChanged);
    VoucherService().addListener(_onVoucherChanged);
    ShippingQuoteStore().addListener(_onShippingChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    VoucherService().removeListener(_onVoucherChanged);
    ShippingQuoteStore().removeListener(_onShippingChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      _calculateBonus(); // Recalculate khi cart thay đổi
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

  Future<void> _calculateBonus() async {
    if (!_bonusService.canUseBonus(_bonusInfo)) {
      setState(() {
        _eligibleTotal = 0;
        _bonusAmount = 0;
      });
      return;
    }

    final items = _cartService.items.where((i) => i.isSelected).toList();
    
    // ✅ Lấy config để biết eligible shop IDs
    final config = await _bonusService.getBonusConfig();
    if (config == null || !config.status) {
      if (mounted) {
        setState(() {
          _eligibleTotal = 0;
          _bonusAmount = 0;
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
          _eligibleTotal = 0;
          _bonusAmount = 0;
        });
      }
      return;
    }
    
    // ✅ Tính tổng dựa trên originalPrice (giá gốc) CHỈ cho eligible shops
    final eligibleTotal = eligibleItems.fold(0, (s, i) => s + ((i.originalPrice ?? i.price) * i.quantity));
    final totalGoods = items.fold(0, (s, i) => s + ((i.originalPrice ?? i.price) * i.quantity));
    
    // ✅ Tính voucher discount CHỈ cho eligible shops
    final voucherService = VoucherService();
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
    final bonusAmount = rawBonus < remainingAmount 
        ? (rawBonus < maxDiscountAmount ? rawBonus : maxDiscountAmount)
        : (remainingAmount < maxDiscountAmount ? remainingAmount : maxDiscountAmount);

    if (mounted) {
      setState(() {
        _eligibleTotal = baseAmount;
        _bonusAmount = bonusAmount;
        _discountPercent = discountPercent;
      });
    }
  }

  Future<void> _loadBonusInfo() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      setState(() {
        _loading = false;
        _bonusInfo = null;
      });
      return;
    }

    final user = await _authService.getCurrentUser();
    if (user == null) {
      setState(() {
        _loading = false;
        _bonusInfo = null;
      });
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
        _loading = false;
      });
      // Tính bonus sau khi có bonusInfo
      await _calculateBonus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (!_bonusService.canUseBonus(_bonusInfo)) {
      return const SizedBox.shrink();
    }

    // Nếu chưa tính toán, hiển thị loading
    if (_eligibleTotal == null || _bonusAmount == null) {
      return const SizedBox.shrink();
    }

    if (_bonusAmount! <= 0) {
      return const SizedBox.shrink();
    }

    final remainingAmount = _bonusInfo!['remaining_amount'] as int? ?? 0;
    final discountPercentText = _discountPercent != null 
        ? _discountPercent!.toStringAsFixed(0) 
        : '10';
    

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.card_giftcard,
            color: Colors.green.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '🎁  Voucher giảm giá',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(27, 94, 32, 1),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // ✅ Icon chấm than để mở dialog
                    GestureDetector(
                      onTap: _showBonusInfoDialog,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 208, 248, 209),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          size: 19,
                          color: const Color.fromARGB(255, 18, 104, 201),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Số dư: ${_formatPrice(remainingAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Giảm: ${_formatPrice(_bonusAmount!)} ($discountPercentText%)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    // Hiển thị dạng tiền Việt đầy đủ, ví dụ: 200.000 đ, 22.400 đ
    final priceStr = price.toString();
    final buffer = StringBuffer();
    int count = 0;

    // Duyệt từ phải sang trái và chèn dấu chấm mỗi 3 chữ số
    for (int i = priceStr.length - 1; i >= 0; i--) {
      buffer.write(priceStr[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    final formatted = buffer.toString().split('').reversed.join();
    return '$formatted đ';
  }

  /// Hiển thị dialog thông tin bonus và danh sách shop
  Future<void> _showBonusInfoDialog() async {
    final config = await _bonusService.getBonusConfig();
    if (config == null) return;

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: BonusInfoBottomSheet(
              bonusConfig: config,
              remainingAmount: _bonusInfo?['remaining_amount'] as int? ?? 0,
              bonusAmount: _bonusAmount ?? 0,
              discountPercent: _discountPercent ?? 10.0,
            ),
          ),
        );
      },
    );
  }
}

