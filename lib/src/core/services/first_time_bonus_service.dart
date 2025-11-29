import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/device_id_helper.dart';
import 'api_service.dart';

class FirstTimeBonusService {
  static const String baseUrl = 'https://api.socdo.vn/v1';
  
  /// ✅ Danh sách shop được hưởng first-time bonus (10% của tổng tiền hàng)
  /// Chỉ sản phẩm thuộc 5 shop này mới được tính vào eligible_total
  static const List<int> eligibleBonusShops = [32373, 23933, 36893, 35683, 35681];
  
  static final FirstTimeBonusService _instance = FirstTimeBonusService._internal();
  factory FirstTimeBonusService() => _instance;
  FirstTimeBonusService._internal();
  
  final ApiService _apiService = ApiService();
  
  /// Kiểm tra và tặng bonus khi đăng nhập lần đầu
  Future<Map<String, dynamic>?> checkAndGrantBonus(int userId) async {
    try {
      final deviceId = await DeviceIdHelper.getDeviceId();
      final token = await _apiService.getValidToken();
      
      if (token == null) {
        return null;
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/check_first_time_bonus?user_id=$userId&device_id=$deviceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Lấy thông tin bonus hiện tại
  Future<Map<String, dynamic>?> getBonusInfo(int userId) async {
    try {
      final deviceId = await DeviceIdHelper.getDeviceId();
      final token = await _apiService.getValidToken();
      
      if (token == null) {
        return null;
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/check_first_time_bonus?user_id=$userId&device_id=$deviceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Kiểm tra xem có thể áp dụng bonus không
  bool canUseBonus(Map<String, dynamic>? bonusInfo) {
    if (bonusInfo == null) return false;
    final hasBonus = bonusInfo['has_bonus'] as bool? ?? false;
    final remainingAmount = bonusInfo['remaining_amount'] as int? ?? 0;
    final isUsed = bonusInfo['is_used'] as bool? ?? true;
    
    return hasBonus && remainingAmount > 0 && !isUsed;
  }
  
  /// ✅ Tính tổng tiền hàng CHỈ từ các shop hợp lệ (32373, 23933, 36893)
  /// Bonus 10% chỉ tính trên eligible_total, KHÔNG tính trên toàn bộ giỏ hàng
  /// 
  /// [items] - Danh sách items với format: [{'shopId': int, 'price': int, 'quantity': int}]
  int calculateEligibleTotal(List<Map<String, dynamic>> items) {
    int eligible = 0;
    
    for (final item in items) {
      final shopId = item['shopId'] as int? ?? 0;
      final price = item['price'] as int? ?? 0;
      final quantity = item['quantity'] as int? ?? 1;
      
      if (eligibleBonusShops.contains(shopId)) {
        eligible += price * quantity;
      }
    }
    
    return eligible;
  }
  
  /// Tính số tiền bonus có thể dùng (10% của eligible_total, hoặc hết số còn lại nếu < 10%)
  /// 
  /// ⚠️ LƯU Ý: [orderTotal] bây giờ phải là ELIGIBLE_TOTAL (chỉ từ 3 shop hợp lệ)
  /// KHÔNG truyền tổng tiền hàng toàn bộ giỏ vào đây
  int calculateBonusAmount(int orderTotal, int remainingBonus) {
  
    
    final bonus10Percent = (orderTotal * 10 / 100).floor();
  
    
    int result;
    if (remainingBonus < bonus10Percent) {
      // Trừ hết số tiền còn lại
      result = remainingBonus;
      print('   - Result: Trừ hết số còn lại = $result (${result / 1000}k)');
    } else {
      // Trừ đúng 10%
      result = bonus10Percent;
      print('   - Result: Trừ đúng 10% = $result (${result / 1000}k)');
    }
    
    print('🔍 [BONUS DEBUG] calculateBonusAmount result: $result');
    return result;
  }
}

