import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/device_id_helper.dart';
import 'api_service.dart';

class FirstTimeBonusService {
  static const String baseUrl = 'https://api.socdo.vn/v1';
  
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
  
  /// Tính số tiền bonus có thể dùng (10% của order total, hoặc hết số còn lại nếu < 10%)
  int calculateBonusAmount(int orderTotal, int remainingBonus) {
    final bonus10Percent = (orderTotal * 10 / 100).floor();
    int result;
    if (remainingBonus < bonus10Percent) {
      result = remainingBonus;
    } else {
      result = bonus10Percent;
    }
    return result;
  }
}

