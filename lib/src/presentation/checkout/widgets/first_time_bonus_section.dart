import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/services/first_time_bonus_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cart_service.dart' as cart_service;
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
    // ✅ Lắng nghe thay đổi cart để cập nhật real-time
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      _calculateBonus(); // Recalculate khi cart thay đổi
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
    // ✅ Dùng originalPrice (giá gốc) để tính toán đúng trong checkout
    final eligibleItems = items.map((i) => {
      'shopId': i.shopId,
      'price': i.originalPrice ?? i.price,
      'quantity': i.quantity,
    }).toList();

    final eligibleTotal = await _bonusService.calculateEligibleTotal(eligibleItems);
    final remainingAmount = _bonusInfo!['remaining_amount'] as int? ?? 0;
    final bonusAmount = await _bonusService.calculateBonusAmount(eligibleTotal, remainingAmount);
    
    // Lấy discount_percent từ config để hiển thị
    final config = await _bonusService.getBonusConfig();
    final discountPercent = config?.discountPercent ?? 10.0;

    if (mounted) {
      setState(() {
        _eligibleTotal = eligibleTotal;
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
                  'Bạn được giảm: ${_formatPrice(_bonusAmount!)} ($discountPercentText%)',
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

