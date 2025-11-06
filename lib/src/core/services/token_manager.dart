import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static const String _tokenKey = 'api_token';
  static const String _tokenExpiryKey = 'token_expiry';
  
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  /// Lưu token vào SharedPreferences
  Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Lưu token
      await prefs.setString(_tokenKey, token);
      
      // Decode JWT để lấy thời gian hết hạn
      final expiryTime = _getTokenExpiry(token);
      if (expiryTime != null) {
        await prefs.setInt(_tokenExpiryKey, expiryTime.millisecondsSinceEpoch);
        print('✅ Token được lưu, hết hạn: ${expiryTime.toString()}');
      } else {
        print('⚠️ Không thể decode thời gian hết hạn của token');
      }
    } catch (e) {
      print('❌ Lỗi khi lưu token: $e');
    }
  }

  /// Lấy token từ SharedPreferences
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('❌ Lỗi khi lấy token: $e');
      return null;
    }
  }

  /// Lấy userId từ token
  /// LƯU Ý: Method này KHÔNG hoạt động đúng với logic của dự án!
  /// Token trong TokenManager là API token (không có user_id), không phải user token.
  /// Để lấy user_id, nên dùng AuthService.getCurrentUser()?.userId thay vì method này.
  /// 
  /// @deprecated Sử dụng AuthService.getCurrentUser()?.userId thay vì method này
  Future<int?> getUserId() async {
    try {
      final token = await getToken();
      if (token == null) {
        print('⚠️ Token is null - user chưa đăng nhập');
        return null;
      }
      
      // Decode JWT payload
      final parts = token.split('.');
      if (parts.length != 3) {
        print('⚠️ Token không đúng format (không phải JWT)');
        return null;
      }
      
      // Decode payload (part 1)
      final payload = parts[1];
      // Add padding if needed
      final paddedPayload = payload + '=' * (4 - payload.length % 4);
      
      final decodedBytes = base64Url.decode(paddedPayload);
      final decodedPayload = utf8.decode(decodedBytes);
      final payloadMap = json.decode(decodedPayload) as Map<String, dynamic>;
      
      // Debug: In ra toàn bộ payload để kiểm tra
      print('🔍 JWT Payload: $payloadMap');
      
      // Thử lấy user_id từ nhiều vị trí có thể
      int? userId;
      
      // Thử 1: payloadMap['user_id'] (trực tiếp)
      if (payloadMap.containsKey('user_id')) {
        final val = payloadMap['user_id'];
        if (val is int) {
          userId = val;
        } else if (val is String) {
          userId = int.tryParse(val);
        }
      }
      
      // Thử 2: payloadMap['data']['user_id'] (nested trong data)
      if (userId == null && payloadMap.containsKey('data')) {
        final data = payloadMap['data'];
        if (data is Map<String, dynamic> && data.containsKey('user_id')) {
          final val = data['user_id'];
          if (val is int) {
            userId = val;
          } else if (val is String) {
            userId = int.tryParse(val);
          }
        }
      }
      
      if (userId != null) {
        print('✅ Lấy được userId từ token: $userId');
      } else {
        print('⚠️ Không tìm thấy user_id trong token payload');
      }
      
      return userId;
    } catch (e) {
      print('❌ Lỗi khi decode userId từ token: $e');
      return null;
    }
  }

  /// Kiểm tra token có hợp lệ không (chưa hết hạn)
  bool isTokenValid(String token) {
    try {
      final expiryTime = _getTokenExpiry(token);
      if (expiryTime == null) return false;
      
      final now = DateTime.now();
      final isValid = now.isBefore(expiryTime.subtract(const Duration(minutes: 5))); // Buffer 5 phút
      
      if (!isValid) {
        print('⚠️ Token đã hết hạn: ${expiryTime.toString()}');
      }
      
      return isValid;
    } catch (e) {
      print('❌ Lỗi khi kiểm tra token: $e');
      return false;
    }
  }

  /// Xóa token
  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenExpiryKey);
      await prefs.commit();
      
      // Verify token đã được xóa
      final afterToken = await getToken();
      if (afterToken != null) {
        await prefs.clear();
        await prefs.commit();
      }
      
      print('✅ Token đã được xóa');
    } catch (e) {
      print('❌ Lỗi khi xóa token: $e');
    }
  }

  /// Decode JWT token để lấy thời gian hết hạn
  DateTime? _getTokenExpiry(String token) {
    try {
      // JWT format: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      // Decode payload (base64url)
      String payload = parts[1];
      
      // Thêm padding nếu cần
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          throw Exception('Invalid base64url string');
      }
      
      // Decode base64
      final decoded = utf8.decode(base64Url.decode(payload));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;
      
      // Lấy exp (expiration time) - Unix timestamp
      final exp = payloadMap['exp'] as int?;
      if (exp != null) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      
      return null;
    } catch (e) {
      print('❌ Lỗi khi decode JWT: $e');
      return null;
    }
  }

  /// Lấy thông tin từ token (không cần validate)
  Map<String, dynamic>? getTokenPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      String payload = parts[1];
      
      // Thêm padding
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          return null;
      }
      
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Lỗi khi decode token payload: $e');
      return null;
    }
  }

  /// Kiểm tra token có tồn tại và hợp lệ không
  Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null && isTokenValid(token);
  }
}
