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

  /// Download logo và convert thành File cho largeIcon
  Future<String?> _downloadLogoForNotification() async {
    try {
      const logoUrl = 'https://socdo.vn/uploads/logo/logo.png';
      final tempDir = await getTemporaryDirectory();
      final logoFile = File('${tempDir.path}/notification_logo.png');
      
      // Nếu file đã tồn tại và còn mới (trong 24h), dùng lại
      if (await logoFile.exists()) {
        final stat = await logoFile.stat();
        final now = DateTime.now();
        final age = now.difference(stat.modified);
        if (age.inHours < 24) {
          return logoFile.path;
        }
      }
      
      // Download logo mới
      final response = await http.get(
        Uri.parse(logoUrl),
        headers: {'User-Agent': 'SocdoApp/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        await logoFile.writeAsBytes(response.bodyBytes);
        return logoFile.path;
      }
    } catch (e) {
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

      // Download logo để dùng làm largeIcon (hiển thị bên cạnh notification)
      String? logoPath;
      try {
        logoPath = await _downloadLogoForNotification();
      } catch (e) {
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
        largeIcon: logoPath != null ? FilePathAndroidBitmap(logoPath) : null,
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

