import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service quản lý danh sách người dùng bị chặn
/// Lưu trữ local để ẩn nội dung ngay lập tức
class BlockedUsersService {
  static const String _blockedUsersKey = 'blocked_users';
  static final BlockedUsersService _instance = BlockedUsersService._internal();
  factory BlockedUsersService() => _instance;
  BlockedUsersService._internal();

  Set<int> _blockedUserIds = {};
  bool _isInitialized = false;

  /// Khởi tạo và load danh sách từ SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedUsersJson = prefs.getString(_blockedUsersKey);
      
      if (blockedUsersJson != null) {
        final List<dynamic> blockedList = jsonDecode(blockedUsersJson);
        _blockedUserIds = blockedList.map((id) => id as int).toSet();
      } else {
        _blockedUserIds = {};
      }
      
      _isInitialized = true;
    } catch (e) {
      _blockedUserIds = {};
      _isInitialized = true;
    }
  }

  /// Chặn một người dùng
  Future<bool> blockUser(int userId) async {
    await initialize();
    
    _blockedUserIds.add(userId);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedList = _blockedUserIds.toList();
      await prefs.setString(_blockedUsersKey, jsonEncode(blockedList));
      
      // TODO: Gửi thông báo cho developer về việc chặn
      // Có thể gọi API để thông báo cho backend
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Bỏ chặn một người dùng
  Future<bool> unblockUser(int userId) async {
    await initialize();
    
    _blockedUserIds.remove(userId);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedList = _blockedUserIds.toList();
      await prefs.setString(_blockedUsersKey, jsonEncode(blockedList));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Kiểm tra xem người dùng có bị chặn không
  Future<bool> isBlocked(int userId) async {
    await initialize();
    return _blockedUserIds.contains(userId);
  }

  /// Lấy danh sách tất cả người dùng bị chặn
  Future<Set<int>> getBlockedUsers() async {
    await initialize();
    return Set<int>.from(_blockedUserIds);
  }

  /// Xóa tất cả danh sách chặn (dùng khi logout)
  Future<void> clearAll() async {
    _blockedUserIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_blockedUsersKey);
    } catch (e) {
      // Ignore error
    }
  }
}

