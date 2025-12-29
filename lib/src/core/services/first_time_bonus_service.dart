import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import '../utils/device_id_helper.dart';
import 'api_service.dart';
import '../models/bonus_config.dart';

class FirstTimeBonusService {
  static const String baseUrl = 'https://api.socdo.vn/v1';
  
  static final FirstTimeBonusService _instance = FirstTimeBonusService._internal();
  factory FirstTimeBonusService() => _instance;
  FirstTimeBonusService._internal();
  
  final ApiService _apiService = ApiService();
  
  // ✅ Cache config trong memory (TTL 5 phút)
  BonusConfig? _cachedConfig;
  DateTime? _configCacheTime;
  static const Duration _configCacheTTL = Duration(minutes: 5);
  
  /// Kiểm tra và tặng bonus khi đăng nhập lần đầu
  /// [promoCodeId] - ID mã thưởng (optional, chỉ dùng khi đăng ký có mã thưởng)
  Future<Map<String, dynamic>?> checkAndGrantBonus(
    int userId, {
    int? promoCodeId,
  }) async {
    try {
      final deviceId = await DeviceIdHelper.getDeviceId();
      final token = await _apiService.getValidToken();

      if (token == null) {
        return null;
      }

      String url = '$baseUrl/check_first_time_bonus?user_id=$userId&device_id=$deviceId';
      if (promoCodeId != null) {
        url += '&promo_code_id=$promoCodeId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>?;
        } else {
          // ❌ API trả về success = false hoặc không có data
          // print('❌ [BONUS] API trả về success = false hoặc không có data: ${response.body}');
          return {
            'has_bonus': false,
            'message': data['message'] ?? data['data']?['message'] ?? 'Không thể tạo bonus'
          };
        }
      } else {
        // ❌ HTTP status code không phải 200
        // print('❌ [BONUS] HTTP ${response.statusCode}: ${response.body}');
        return {
          'has_bonus': false,
          'message': 'Lỗi kết nối API (${response.statusCode})'
        };
      }
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
  
  /// Lấy cấu hình bonus từ API (có cache)
  Future<BonusConfig?> getBonusConfig() async {
    // Kiểm tra cache
    if (_cachedConfig != null && _configCacheTime != null) {
      if (DateTime.now().difference(_configCacheTime!) < _configCacheTTL) {
        return _cachedConfig;
      }
    }

    try {
      final token = await _apiService.getValidToken();
      if (token == null) {
        // Fallback về config mặc định nếu không có token
        return BonusConfig.defaultConfig();
      }

      final response = await http.get(
        Uri.parse('$baseUrl/get_bonus_config'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // ✅ Kiểm tra response body có hợp lệ không trước khi parse
        if (response.body.isEmpty || response.body.trim().isEmpty) {
          // print('⚠️ [FirstTimeBonusService] Empty response body');
          return BonusConfig.defaultConfig();
        }
        
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            _cachedConfig = BonusConfig.fromJson(data['data']);
            _configCacheTime = DateTime.now();
            return _cachedConfig;
          }
        } catch (e) {
          // Lỗi parse JSON
          // print('⚠️ [FirstTimeBonusService] Error parsing JSON: $e');
          // print('⚠️ [FirstTimeBonusService] Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
          return BonusConfig.defaultConfig();
        }
      }
    } catch (e) {
      // Fallback: dùng config mặc định nếu API fail
      // print('⚠️ [FirstTimeBonusService] Error getting config: $e');
    }

    // Fallback về config mặc định
    return BonusConfig.defaultConfig();
  }

  /// Invalidate cache (gọi khi cần refresh config)
  void invalidateCache() {
    _cachedConfig = null;
    _configCacheTime = null;
  }

  /// ✅ Tính tổng tiền hàng CHỈ từ các shop hợp lệ (từ config)
  /// 
  /// [items] - Danh sách items với format: [{'shopId': int, 'price': int, 'quantity': int}]
  Future<int> calculateEligibleTotal(List<Map<String, dynamic>> items) async {
    final config = await getBonusConfig();
    if (config == null || !config.status) return 0;

    final eligibleShopIds = config.eligibleShops.map((s) => s.shopId).toList();
    int eligible = 0;

    for (final item in items) {
      final shopId = item['shopId'] as int? ?? 0;
      final price = item['price'] as int? ?? 0;
      final quantity = item['quantity'] as int? ?? 1;

      if (eligibleShopIds.contains(shopId)) {
        eligible += price * quantity;
      }
    }

    return eligible;
  }

  /// Tính số tiền bonus có thể dùng (từ config: discount_percent và max_discount_amount)
  /// 
  /// ⚠️ LƯU Ý: [eligibleTotal] phải là ELIGIBLE_TOTAL (chỉ từ shop hợp lệ)
  /// KHÔNG truyền tổng tiền hàng toàn bộ giỏ vào đây
  Future<int> calculateBonusAmount(int eligibleTotal, int remainingBonus) async {
    final config = await getBonusConfig();
    if (config == null || !config.status) return 0;
    if (eligibleTotal <= 0 || remainingBonus <= 0) return 0;

    // Tính bonus theo discount_percent từ config
    final rawBonus = (eligibleTotal * config.discountPercent / 100).floor();
    
    // Lấy min của: rawBonus, remainingBonus, max_discount_amount
    return math.min(math.min(rawBonus, remainingBonus), config.maxDiscountAmount);
  }
}

