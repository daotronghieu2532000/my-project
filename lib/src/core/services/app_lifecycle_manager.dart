import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Quản lý lifecycle của app và lưu trữ state khi app đi vào background
class AppLifecycleManager extends WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  // Keys cho SharedPreferences
  static const String _currentTabKey = 'app_current_tab';
  static const String _scrollPositionKey = 'app_scroll_position';
  static const String _lastActiveTimeKey = 'app_last_active_time';
  static const String _homeScrollPositionKey = 'home_scroll_position';
  static const String _categoryScrollPositionKey = 'category_scroll_position';
  static const String _affiliateScrollPositionKey = 'affiliate_scroll_position';

  // Timeout cho state preservation (3 phút = 180 giây)
  static const Duration _stateTimeout = Duration(minutes: 3);
  
  DateTime? _lastPauseTime;
  DateTime? _lastResumeTime;
  bool _isAppInBackground = false;

  /// Khởi tạo AppLifecycleManager
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    // Load pause time async (không block)
    _loadLastPauseTime();
  }

  /// Dispose AppLifecycleManager
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        // App đang chuyển đổi giữa foreground và background
        break;
      case AppLifecycleState.detached:
        // App bị terminate
        break;
      case AppLifecycleState.hidden:
        // App bị ẩn (Android)
        break;
    }
  }

  /// Xử lý khi app được resume
  void _handleAppResumed() {
    _lastResumeTime = DateTime.now();
    _isAppInBackground = false;
    
    // Kiểm tra nếu ở background quá lâu, clear state
    if (_lastPauseTime != null) {
      final backgroundDuration = _lastResumeTime!.difference(_lastPauseTime!);
      
      if (backgroundDuration > _stateTimeout) {
        // State đã hết hạn, clear để app reload
        clearAllState();
      }
    }
  }

  /// Xử lý khi app bị pause
  void _handleAppPaused() {
    _lastPauseTime = DateTime.now();
    _isAppInBackground = true;
    _saveLastPauseTime();
  }

  /// Lưu thời gian pause cuối cùng
  Future<void> _saveLastPauseTime() async {
    if (_lastPauseTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastActiveTimeKey, _lastPauseTime!.toIso8601String());
    }
  }

  /// Load thời gian pause cuối cùng
  Future<void> _loadLastPauseTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPauseString = prefs.getString(_lastActiveTimeKey);
      if (lastPauseString != null) {
        _lastPauseTime = DateTime.parse(lastPauseString);
        
        // Kiểm tra xem state có còn hợp lệ không (từ lúc pause đến hiện tại)
        final now = DateTime.now();
        final timeSincePause = now.difference(_lastPauseTime!);
        
        if (timeSincePause > _stateTimeout) {
          await clearAllState();
        }
      }
    } catch (e) {
      // Ignore error
    }
  }

  /// Kiểm tra xem state có còn hợp lệ không
  bool isStateValid() {
    if (_lastPauseTime == null) {
      return false;
    }
    
    // Tính thời gian từ pause đến hiện tại
    final now = DateTime.now();
    final timeSincePause = now.difference(_lastPauseTime!);
    
    // Nếu app đã resume, kiểm tra thời gian từ pause đến resume
    if (_lastResumeTime != null && !_isAppInBackground) {
      final backgroundDuration = _lastResumeTime!.difference(_lastPauseTime!);
      return backgroundDuration <= _stateTimeout;
    }
    
    // Nếu app đang trong background hoặc mới restart, kiểm tra từ pause đến hiện tại
    return timeSincePause <= _stateTimeout;
  }

  /// Lưu tab hiện tại
  Future<void> saveCurrentTab(int tabIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_currentTabKey, tabIndex);
    } catch (e) {
      // Ignore error
    }
  }

  /// Lấy tab đã lưu
  Future<int?> getSavedTab() async {
    final isValid = isStateValid();
    
    if (!isValid) {
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final tab = prefs.getInt(_currentTabKey);
      if (tab != null) {
        return tab;
      }
    } catch (e) {
      // Ignore error
    }
    return null;
  }

  /// Lưu vị trí scroll của một tab cụ thể
  Future<void> saveScrollPosition(int tabIndex, double scrollPosition) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String key;
      
      switch (tabIndex) {
        case 0:
          key = _homeScrollPositionKey;
          break;
        case 1:
          key = _categoryScrollPositionKey;
          break;
        case 2:
          key = _affiliateScrollPositionKey;
          break;
        default:
          return;
      }
      
      await prefs.setDouble(key, scrollPosition);
    } catch (e) {
      // Ignore error
    }
  }

  /// Lấy vị trí scroll đã lưu của một tab cụ thể
  Future<double?> getSavedScrollPosition(int tabIndex) async {
    final isValid = isStateValid();
    
    if (!isValid) {
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String key;
      
      switch (tabIndex) {
        case 0:
          key = _homeScrollPositionKey;
          break;
        case 1:
          key = _categoryScrollPositionKey;
          break;
        case 2:
          key = _affiliateScrollPositionKey;
          break;
        default:
          return null;
      }
      
      final position = prefs.getDouble(key);
      if (position != null) {
        return position;
      }
    } catch (e) {
      // Ignore error
    }
    return null;
  }

  /// Xóa tất cả state đã lưu
  Future<void> clearAllState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentTabKey);
      await prefs.remove(_scrollPositionKey);
      await prefs.remove(_lastActiveTimeKey);
      await prefs.remove(_homeScrollPositionKey);
      await prefs.remove(_categoryScrollPositionKey);
      await prefs.remove(_affiliateScrollPositionKey);
      
      // Clear in-memory state
      _lastPauseTime = null;
      _lastResumeTime = null;
    } catch (e) {
      // Ignore error
    }
  }

  /// Lưu state tổng quát (có thể mở rộng cho các state khác)
  Future<void> saveState(Map<String, dynamic> state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_general_state', jsonEncode(state));
    } catch (e) {
      // Ignore error
    }
  }

  /// Lấy state tổng quát
  Future<Map<String, dynamic>?> getSavedState() async {
    if (!isStateValid()) {
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final stateString = prefs.getString('app_general_state');
      if (stateString != null) {
        final state = jsonDecode(stateString) as Map<String, dynamic>;
        return state;
      }
    } catch (e) {
      // Ignore error
    }
    return null;
  }

  /// Kiểm tra xem app có đang trong background không
  bool get isInBackground => _isAppInBackground;

  /// Lấy thời gian cuối cùng app bị pause
  DateTime? get lastPauseTime => _lastPauseTime;
}
