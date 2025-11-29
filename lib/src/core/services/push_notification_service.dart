import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'local_notification_service.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'notification_handler.dart';

/// Top-level function để handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {

  
  // Với data-only message, cần hiển thị notification manually
  // Khởi tạo local notification service và hiển thị
  final localNotifications = LocalNotificationService();
  await localNotifications.initialize();
  
  final title = message.data['title'] ?? 'Thông báo';
  final body = message.data['body'] ?? '';
  
  await localNotifications.showNotification(
    id: message.hashCode,
    title: title,
    body: body,
    payload: message.data,
  );
  
  print('📱 [NOTIFICATION] Background notification shown');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final LocalNotificationService _localNotifications = LocalNotificationService();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final NotificationHandler _notificationHandler = NotificationHandler();
  
  bool _initialized = false;
  String? _currentToken;

  /// Khởi tạo push notification service
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {

      // Initialize local notifications
      await _localNotifications.initialize();

      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      } else {
        return;
      }

      // Setup message handlers
      _setupMessageHandlers();

      // Get token and register
      await _getAndRegisterToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_handleTokenRefresh);

      _initialized = true;
    } catch (e) {
    }
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    
      _handleForegroundMessage(message);
    });

    // Handle when app is opened from background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    
      _handleNotificationTap(message);
    });

    // Handle when app is opened from terminated state
    // Đợi một chút để đảm bảo Navigator đã sẵn sàng
    Future.delayed(const Duration(milliseconds: 500), () {
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
       
          // Đợi thêm một chút để Navigator context sẵn sàng
          Future.delayed(const Duration(milliseconds: 300), () {
        _handleNotificationTap(message);
          });
      }
      });
    });

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Handle foreground message (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
   
    final notification = message.notification;
    final data = message.data;
    // Với data-only message, notification sẽ null
    // Lấy title và body từ data
    final title = notification?.title ?? data['title'] ?? 'Thông báo';
    final body = notification?.body ?? data['body'] ?? '';
    // Hiển thị local notification (foreground không tự hiển thị)
      _localNotifications.showNotification(
        id: message.hashCode,
      title: title,
      body: body,
        payload: data,
      );
 
    // Update notification count nếu cần
    _updateNotificationBadge();
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
 
    // FCM data payload là Map<String, dynamic>, nhưng values có thể là string (JSON)
    // Cần parse lại nếu cần
    final data = Map<String, dynamic>.from(message.data);
    
    // Parse các giá trị JSON string thành object nếu cần
    data.forEach((key, value) {
      if (value is String) {
        // Thử parse JSON nếu là JSON string
        try {
          final parsed = jsonDecode(value);
          if (parsed is Map || parsed is List) {
            data[key] = parsed;
          
          }
        } catch (e) {
          // Không phải JSON, giữ nguyên string
        }
      }
    });
    
  
    _notificationHandler.handleNotificationData(data);
  }

  /// Get FCM token and register to server
  Future<void> _getAndRegisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _registerTokenToServer(token);
      } else {
      }
    } catch (e) {
    }
  }

  /// Handle token refresh
  void _handleTokenRefresh(String newToken) async {
    _currentToken = newToken;
    await _registerTokenToServer(newToken);
  }

  /// Register token to server
  Future<void> _registerTokenToServer(String token) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        return;
      }

      // Get device info
      String platform = 'android';
      String? deviceModel;
      
      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          platform = 'android';
          deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          platform = 'ios';
          deviceModel = '${iosInfo.name} ${iosInfo.model}';
        }
      } catch (e) {
      }

      // Get app version
      String? appVersion;
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (e) {
        appVersion = null;
      }

      // Register token via API
      final success = await _apiService.registerDeviceToken(
        userId: user.userId,
        deviceToken: token,
        platform: platform,
        deviceModel: deviceModel,
        appVersion: appVersion,
      );

      if (success) {
      } else {
      }
    } catch (e) {
    }
  }

  /// Update notification badge (số lượng thông báo chưa đọc)
  void _updateNotificationBadge() {
    // Có thể implement badge update logic ở đây
    // Hoặc trigger reload notification list
  }

  /// Get current token
  String? get currentToken => _currentToken;

  /// Check if initialized
  bool get isInitialized => _initialized;
}

