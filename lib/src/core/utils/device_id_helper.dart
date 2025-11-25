import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdHelper {
  static const String _deviceIdKey = 'device_id';
  
  /// Lấy device ID duy nhất (UUID)
  /// - Android: sử dụng Android ID
  /// - iOS: sử dụng identifierForVendor
  /// - Nếu không có, tạo UUID mới và lưu vào SharedPreferences
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedDeviceId = prefs.getString(_deviceIdKey);
    
    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      return savedDeviceId;
    }
    
    // Tạo mới device ID
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId;
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? _generateUUID();
      } else {
        deviceId = _generateUUID();
      }
    } catch (e) {
      // Fallback: tạo UUID
      deviceId = _generateUUID();
    }
    
    // Lưu vào SharedPreferences
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }
  
  /// Tạo UUID đơn giản (fallback)
  static String _generateUUID() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           '_' + 
           (1000000 + (9999999 - 1000000) * (DateTime.now().microsecond / 1000000)).round().toString();
  }
}

