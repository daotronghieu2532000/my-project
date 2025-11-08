import 'package:flutter/material.dart';
import 'dart:async';
import '../../account/account_screen.dart';
import '../../auth/login_screen.dart';
import '../../search/search_screen.dart';
import '../../chat/chat_list_screen.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/socketio_service.dart';
import '../../../core/models/user.dart';
import '../../../core/models/chat.dart';
import '../../../core/services/api_service.dart';

class HomeAppBar extends StatefulWidget {
  const HomeAppBar({super.key});

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  final _authService = AuthService();
  final _api = ApiService();
  final _chatService = ChatService();
  final _socketIOService = SocketIOService();
  User? _currentUser;
  bool _isLoading = true;
  int _unread = 0;
  int _unreadChat = 0;
  Timer? _pollingTimer; // ✅ Chỉ dùng khi Socket.IO disconnect/error

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    
    // Thêm listener để cập nhật khi trạng thái đăng nhập thay đổi
    _authService.addAuthStateListener(_checkLoginStatus);
  }

  @override
  void dispose() {
    // Xóa listener khi dispose
    _authService.removeAuthStateListener(_checkLoginStatus);
    _stopPolling();
    _socketIOService.disconnect();
    super.dispose();
  }

  void _startPolling() {
    _stopPolling();
    // ✅ Chỉ polling khi Socket.IO disconnect/error (fallback)
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _currentUser != null && !_socketIOService.isConnected) {
        _loadUnread();
      }
    });
  }

  void _stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
        _loadUnread();
        _setupSocketIO(); // ✅ Setup Socket.IO để nhận realtime updates
      } else {
        setState(() {
          _currentUser = null;
          _isLoading = false;
        });
        setState(() => _unread = 0);
        _stopPolling();
        _socketIOService.disconnect();
      }
    } catch (e) {
      setState(() {
        _currentUser = null;
        _isLoading = false;
      });
    }
  }

  void _setupSocketIO() {
    // ✅ Setup Socket.IO để nhận realtime updates cho unread count
    _socketIOService.onConnected = () {
      _stopPolling(); // ✅ Dừng polling khi Socket.IO connect
      print('✅ [HomeAppBar] Socket.IO connected, stopped polling');
    };

    _socketIOService.onDisconnected = () {
      _startPolling(); // ✅ Start polling khi Socket.IO disconnect (fallback)
      print('🔄 [HomeAppBar] Socket.IO disconnected, started polling');
    };

    _socketIOService.onError = (error) {
      if (!_socketIOService.isConnected) {
        _startPolling(); // ✅ Start polling khi Socket.IO error (fallback)
        print('🔄 [HomeAppBar] Socket.IO error, started polling');
      }
    };

    _socketIOService.onMessage = (message) {
      // ✅ Khi nhận message mới, refresh unread count
      if (mounted && _currentUser != null) {
        _loadUnread();
      }
    };

    // ✅ Connect to Socket.IO với 'global' để nhận tất cả messages
    _socketIOService.connect('global');

    // ✅ Chỉ start polling nếu Socket.IO chưa connect (fallback)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_socketIOService.isConnected) {
        _startPolling();
        print('🔄 [HomeAppBar] Started polling - Socket.IO not connected yet');
      }
    });
  }

  Future<void> _loadUnread() async {
    if (_currentUser == null) return;
    
    // Load notifications
    final res = await _api.getNotifications(userId: _currentUser!.userId, page: 1, limit: 1, unreadOnly: true);
    if (!mounted) return;
    setState(() {
      _unread = (res?['data']?['unread_count'] as int?) ?? 0;
    });
    
    // Load chat unread count
    try {
      final chatRes = await _chatService.getSessions(
        userId: _currentUser!.userId,
        userType: 'customer',
      );
      if (!mounted) return;
      
      // Group sessions by shop_id and keep only the latest one for each shop (same logic as ChatListScreen)
      final Map<int, ChatSession> groupedSessions = {};
      
      for (final session in chatRes.sessions) {
        if (!groupedSessions.containsKey(session.shopId) || 
            session.lastMessageTime > groupedSessions[session.shopId]!.lastMessageTime) {
          groupedSessions[session.shopId] = session;
        }
      }
      
      // Calculate total unread count from grouped sessions only
      int totalUnread = 0;
      for (final session in groupedSessions.values) {
        totalUnread += session.unreadCount;
      }
      
      setState(() {
        _unreadChat = totalUnread;
      });
      // print('📊 [HomeAppBar] Chat unread count: $totalUnread (from ${groupedSessions.length} unique shops)');
    } catch (e) {
      // print('❌ [HomeAppBar] Error loading chat unread: $e');
      // Ignore chat errors
    }
  }

  void _handleSearchTap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _handleChatTap() {
    if (_currentUser != null) {
      // Đã đăng nhập - vào danh sách chat
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      ).then((_) => _loadUnread());
    } else {
      // Chưa đăng nhập - vào trang đăng nhập
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ).then((_) => _checkLoginStatus());
    }
  }

  Future<void> _handleAvatarTap() async {
    if (_currentUser != null) {
      // Đã đăng nhập - vào trang tài khoản
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      );
    } else {
      // Chưa đăng nhập - vào trang đăng nhập
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      
      // Nếu đăng nhập thành công, refresh trạng thái
      if (result == true) {
        _checkLoginStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _handleSearchTap,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tìm kiếm sản phẩm, nhà bán hàng...',
                          style: TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Bell icon with unread badge
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/notifications').then((_) => _loadUnread()),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.notifications_active, color: Colors.amber),
                  ),
                  if (_unread > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _unread > 99 ? '99+' : '$_unread',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Chat icon with unread badge
            GestureDetector(
              onTap: _handleChatTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.chat, color: Colors.blue),
                  ),
                  if (_unreadChat > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _unreadChat > 99 ? '99+' : '$_unreadChat',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Avatar hoặc nút đăng nhập
            GestureDetector(
              onTap: _handleAvatarTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _currentUser != null ? Colors.red[300]! : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _currentUser != null
                        ? CircleAvatar(
                            backgroundImage: _currentUser!.avatar != null && _currentUser!.avatar!.isNotEmpty
                                ? NetworkImage(_authService.getAvatarUrl(_currentUser!.avatar))
                                : const AssetImage('lib/src/core/assets/images/user_default.png') as ImageProvider,
                            backgroundColor: Colors.grey[200],
                            onBackgroundImageError: (exception, stackTrace) {
                              // Fallback to default image if network image fails
                            },
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.person_add,
                              color: const Color.fromARGB(255, 249, 1, 1),
                              size: 20,
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
