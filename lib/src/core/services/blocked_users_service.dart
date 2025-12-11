import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Service quản lý danh sách người dùng bị chặn
/// Lưu trữ local để ẩn nội dung ngay lập tức và sync với backend
class BlockedUsersService {
  static const String _blockedUsersKey = 'blocked_users';
  static const String _blockedShopsKey = 'blocked_shops';
  static final BlockedUsersService _instance = BlockedUsersService._internal();
  factory BlockedUsersService() => _instance;
  BlockedUsersService._internal();

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Set<int> _blockedUserIds = {};
  Set<int> _blockedShopIds = {};
  bool _isInitialized = false;

  /// Khởi tạo và load danh sách từ SharedPreferences và backend
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load từ local storage trước (để ẩn ngay lập tức)
      final prefs = await SharedPreferences.getInstance();
      final blockedUsersJson = prefs.getString(_blockedUsersKey);
      final blockedShopsJson = prefs.getString(_blockedShopsKey);
      
      if (blockedUsersJson != null) {
        final List<dynamic> blockedList = jsonDecode(blockedUsersJson);
        _blockedUserIds = blockedList.map((id) => id as int).toSet();
      } else {
        _blockedUserIds = {};
      }
      
      if (blockedShopsJson != null) {
        final List<dynamic> blockedList = jsonDecode(blockedShopsJson);
        _blockedShopIds = blockedList.map((id) => id as int).toSet();
      } else {
        _blockedShopIds = {};
      }
      
      // Sync với backend
      await _syncWithBackend();
      
      _isInitialized = true;
    } catch (e) {
      _blockedUserIds = {};
      _blockedShopIds = {};
      _isInitialized = true;
    }
  }

  /// Sync danh sách chặn với backend
  Future<void> _syncWithBackend() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) return;
      
      final blockedList = await _apiService.getBlockedUsers(userId: currentUser.userId);
      
      final Set<int> userIds = {};
      final Set<int> shopIds = {};
      
      for (final item in blockedList) {
        final blockedUserId = item['blocked_user_id'] as int? ?? 0;
        final blockedShopId = item['blocked_shop_id'] as int? ?? 0;
        final blockType = item['block_type'] as String? ?? 'user';
        
        if (blockType == 'shop' && blockedShopId > 0) {
          shopIds.add(blockedShopId);
        } else if (blockedUserId > 0) {
          userIds.add(blockedUserId);
        }
      }
      
      _blockedUserIds = userIds;
      _blockedShopIds = shopIds;
      
      // Lưu lại vào local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_blockedUsersKey, jsonEncode(_blockedUserIds.toList()));
      await prefs.setString(_blockedShopsKey, jsonEncode(_blockedShopIds.toList()));
    } catch (e) {
      // Ignore error, giữ nguyên local data
    }
  }

  /// Chặn một người dùng hoặc shop
  Future<bool> blockUser(int userId, {int? shopId, String? reason}) async {
    await initialize();
    
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) return false;
      
      // Gọi API để lưu vào backend
      final success = await _apiService.blockUser(
        userId: currentUser.userId,
        blockedUserId: userId,
        blockedShopId: shopId,
        reason: reason ?? 'User blocked',
      );
      
      if (success) {
        // Cập nhật local storage
        if (shopId != null && shopId > 0) {
          _blockedShopIds.add(shopId);
        } else {
          _blockedUserIds.add(userId);
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_blockedUsersKey, jsonEncode(_blockedUserIds.toList()));
        await prefs.setString(_blockedShopsKey, jsonEncode(_blockedShopIds.toList()));
        
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Bỏ chặn một người dùng hoặc shop
  Future<bool> unblockUser(int userId, {int? shopId}) async {
    await initialize();
    
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) return false;
      
      // Gọi API để xóa khỏi backend
      final success = await _apiService.unblockUser(
        userId: currentUser.userId,
        blockedUserId: userId,
        blockedShopId: shopId,
      );
      
      if (success) {
        // Cập nhật local storage
        if (shopId != null && shopId > 0) {
          _blockedShopIds.remove(shopId);
        } else {
          _blockedUserIds.remove(userId);
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_blockedUsersKey, jsonEncode(_blockedUserIds.toList()));
        await prefs.setString(_blockedShopsKey, jsonEncode(_blockedShopIds.toList()));
        
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Kiểm tra xem người dùng có bị chặn không
  Future<bool> isBlocked(int userId) async {
    await initialize();
    return _blockedUserIds.contains(userId);
  }

  /// Kiểm tra xem shop có bị chặn không
  Future<bool> isShopBlocked(int shopId) async {
    await initialize();
    return _blockedShopIds.contains(shopId);
  }

  /// Lấy danh sách tất cả người dùng bị chặn
  Future<Set<int>> getBlockedUsers() async {
    await initialize();
    return Set<int>.from(_blockedUserIds);
  }

  /// Lấy danh sách tất cả shop bị chặn
  Future<Set<int>> getBlockedShops() async {
    await initialize();
    return Set<int>.from(_blockedShopIds);
  }

  /// Xóa tất cả danh sách chặn (dùng khi logout)
  Future<void> clearAll() async {
    _blockedUserIds.clear();
    _blockedShopIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_blockedUsersKey);
      await prefs.remove(_blockedShopsKey);
    } catch (e) {
      // Ignore error
    }
  }
}

