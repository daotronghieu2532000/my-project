import 'api_service.dart';
import 'push_notification_service.dart';

class AppInitializationService {
  static final AppInitializationService _instance = AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  final ApiService _apiService = ApiService();
  final PushNotificationService _pushService = PushNotificationService();
  bool _isInitialized = false;

  /// Khởi tạo app - gọi khi app start
  Future<bool> initializeApp() async {
    if (_isInitialized) {
      return true;
    }

    
    try {
     
      final token = await _apiService.getValidToken();
      
      if (token != null) {
        // Khởi tạo push notification service
        _pushService.initialize().catchError((e) {
          // Không block app nếu push service lỗi
        });
        
        _isInitialized = true;
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Kiểm tra app đã được khởi tạo chưa
  bool get isInitialized => _isInitialized;

  /// Reset trạng thái khởi tạo (dùng khi logout)
  void resetInitialization() {
    _isInitialized = false;
  }

  /// Khởi tạo lại app (force refresh token)
  Future<bool> reinitializeApp() async {
    _isInitialized = false;
    await _apiService.refreshToken();
    return await initializeApp();
  }
}
