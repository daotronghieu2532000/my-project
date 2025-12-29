import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'notification_handler.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Khởi tạo local notifications
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

      // Tạo notification channel (Android 8.0+ yêu cầu)
      await _createNotificationChannel();

    _initialized = true;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// Tạo notification channel (Android 8.0+)
  Future<void> _createNotificationChannel() async {
    final androidChannel = AndroidNotificationChannel(
      'socdo_channel',
      'Socdo Notifications',
      description: 'Thông báo từ ứng dụng Socdo',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Download image (product hoặc logo) cho notification
  Future<String?> _downloadImageForNotification(String? imageUrl) async {
    try {
      // Nếu không có imageUrl, dùng logo mặc định
      final url = imageUrl ?? 'https://socdo.vn/uploads/logo/logo.png';
      
      final tempDir = await getTemporaryDirectory();
      // Tạo tên file unique dựa trên URL để cache riêng cho mỗi ảnh
      final fileName = url.hashCode.toString() + '.png';
      final imageFile = File('${tempDir.path}/$fileName');
      
      // Nếu file đã tồn tại và còn mới (trong 24h), dùng lại
      if (await imageFile.exists()) {
        final stat = await imageFile.stat();
        final now = DateTime.now();
        final age = now.difference(stat.modified);
        if (age.inHours < 24) {
         
          return imageFile.path;
        }
      }
      
      // Download image mới
    
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'SocdoApp/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        await imageFile.writeAsBytes(response.bodyBytes);
     
        return imageFile.path;
      } else {
        // print('❌ [LOCAL_NOTIFICATION] Failed to download image: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // print('❌ [LOCAL_NOTIFICATION] Error downloading image: $e');
      // Silent fail - không ảnh hưởng đến notification
    }
    return null;
  }

  /// Hiển thị notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
    if (!_initialized) {
      await initialize();
    }

      // Lấy product_image từ payload (nếu có), nếu không thì dùng logo
      String? imageUrl;
      if (payload != null && payload.containsKey('product_image')) {
        imageUrl = payload['product_image'] as String?;
      
      }

      // Download image (product hoặc logo) để dùng làm largeIcon
      String? imagePath;
      try {
        imagePath = await _downloadImageForNotification(imageUrl);
      } catch (e) {
        // print('❌ [LOCAL_NOTIFICATION] Failed to download image: $e');
        // Silent fail - không ảnh hưởng đến notification
      }

      final androidDetails = AndroidNotificationDetails(
      'socdo_channel',
      'Socdo Notifications',
      channelDescription: 'Thông báo từ ứng dụng Socdo',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
        icon: '@drawable/ic_notification',
        color: const Color(0xFFDC143C),
        // Dùng product image nếu có, nếu không thì dùng logo
        largeIcon: imagePath != null ? FilePathAndroidBitmap(imagePath) : null,
        // ✅ THÊM STYLE ĐỂ HIỂN THỊ NỘI DUNG DÀI VỚI NÚT "XEM THÊM"
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Nhấn để xem chi tiết',
        ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

      final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payloadJson = payload != null ? jsonEncode(payload) : null;

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payloadJson,
    );
    
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// Xử lý khi tap notification
  void _onNotificationTap(NotificationResponse response) {
    
    if (response.payload != null) {
      try {
        final payloadString = response.payload!;
        
        Map<String, dynamic> payloadMap;
        
        // Parse JSON string thành Map
        try {
          payloadMap = jsonDecode(payloadString) as Map<String, dynamic>;
          payloadMap.forEach((key, value) {
          });
        } catch (e) {
          // Nếu không phải JSON hợp lệ, log và return
          return;
        }
        
        // Gọi NotificationHandler để xử lý
        if (payloadMap.isNotEmpty) {
          final notificationHandler = NotificationHandler();
          notificationHandler.handleNotificationData(payloadMap);
        } else {
        }
      } catch (e, stackTrace) {
      }
    } else {
    }
  }
}

