import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/services/first_time_bonus_service.dart';
import '../../../core/services/auth_service.dart';

class FirstTimeBonusSection extends StatefulWidget {
  final int orderTotal;
  
  const FirstTimeBonusSection({
    super.key,
    required this.orderTotal,
  });

  @override
  State<FirstTimeBonusSection> createState() => _FirstTimeBonusSectionState();
}

class _FirstTimeBonusSectionState extends State<FirstTimeBonusSection> {
  final FirstTimeBonusService _bonusService = FirstTimeBonusService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _bonusInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBonusInfo();
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

    final remainingAmount = _bonusInfo!['remaining_amount'] as int? ?? 0;
    final bonusAmount = _bonusService.calculateBonusAmount(widget.orderTotal, remainingAmount);
   
    if (bonusAmount <= 0) {
     
      return const SizedBox.shrink();
    }
    

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
                Text(
                  '🎁 Quà tặng lần đầu tải ứng dụng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tiền thưởng đang có: ${_formatPrice(remainingAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bạn được giảm: -${_formatPrice(bonusAmount)} (10%)',
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
    // Hiển thị chính xác, không làm tròn lên
    if (price >= 1000) {
      final thousands = price / 1000;
      // Nếu là số nguyên thì hiển thị không có .0
      if (thousands == thousands.floor()) {
        return '${thousands.floor()}k';
      } else {
        // Hiển thị 1 chữ số thập phân nếu cần
        return '${thousands.toStringAsFixed(1)}k';
      }
    }
    return '${price}đ';
  }
}

