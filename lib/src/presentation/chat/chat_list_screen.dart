import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/socketio_service.dart';
import '../../core/models/user.dart';
import '../../core/models/chat.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _authService = AuthService();
  final _chatService = ChatService();
  final _socketIOService = SocketIOService();
  User? _currentUser;
  List<ChatSession> _sessions = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _socketIOService.disconnect();
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    _stopPolling();
    print('🔄 [ChatListScreen] Starting polling for chat sessions...');
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      _loadChatSessionsSilently();
    });
  }

  Future<void> _loadChatSessionsSilently() async {
    if (_currentUser == null || !mounted) return;

    try {
      final response = await _chatService.getSessions(
        userId: _currentUser!.userId,
        userType: 'customer',
      );

      if (mounted) {
        // Group sessions by shop_id and keep only the latest one for each shop
        final Map<int, ChatSession> groupedSessions = {};
        
        for (final session in response.sessions) {
          if (!groupedSessions.containsKey(session.shopId) || 
              session.lastMessageTime > groupedSessions[session.shopId]!.lastMessageTime) {
            groupedSessions[session.shopId] = session;
          }
        }
        
        // Convert to list and sort by last message time
        final uniqueSessions = groupedSessions.values.toList()
          ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        
        print('📨 [ChatListScreen] Polling found ${response.sessions.length} sessions, grouped into ${uniqueSessions.length} unique shops');
        setState(() {
          _sessions = uniqueSessions;
        });
      }
    } catch (e) {
      print('❌ [ChatListScreen] Silent polling error: $e');
    }
  }

  void _stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      print('⏹️ [ChatListScreen] Stopped polling');
    }
  }

  void _setupSocketIO() {
    // Set up Socket.io callbacks for real-time updates
    _socketIOService.onConnected = () {
      print('🔌 [ChatListScreen] Socket.io connected');
      // ✅ Dừng polling khi Socket.IO đã connect (realtime)
      _stopPolling();
      print('✅ [ChatListScreen] Stopped polling - using Socket.IO realtime');
    };

    _socketIOService.onDisconnected = () {
      print('🔌 [ChatListScreen] Socket.io disconnected');
      // ✅ Start polling lại khi Socket.IO disconnect (fallback)
      _startPolling();
      print('🔄 [ChatListScreen] Started polling - Socket.IO disconnected');
    };

    _socketIOService.onError = (error) {
      print('❌ [ChatListScreen] Socket.io error: $error');
      // ✅ Start polling khi Socket.IO có lỗi (fallback)
      if (!_socketIOService.isConnected) {
        _startPolling();
        print('🔄 [ChatListScreen] Started polling - Socket.IO error');
      }
    };

    _socketIOService.onMessage = (message) {
      print('📨 [ChatListScreen] Received message: $message');
      // Refresh chat sessions when new message received
      _loadChatSessions();
    };

    // Connect to Socket.io (will connect to all sessions)
    _socketIOService.connect('global');
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        setState(() {
          _currentUser = user;
        });
        _loadChatSessions();
        _setupSocketIO();
        // ✅ Chỉ start polling nếu Socket.IO chưa connect (fallback)
        // Polling sẽ tự động dừng khi Socket.IO connect thành công
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_socketIOService.isConnected) {
            _startPolling();
            print('🔄 [ChatListScreen] Started polling - Socket.IO not connected yet');
          }
        });
      } else {
        setState(() {
          _currentUser = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentUser = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChatSessions() async {
    if (_currentUser == null) return;

    try {
      setState(() => _isLoading = true);
      
      final response = await _chatService.getSessions(
        userId: _currentUser!.userId,
        userType: 'customer',
      );

      if (mounted) {
        // Group sessions by shop_id and keep only the latest one for each shop
        final Map<int, ChatSession> groupedSessions = {};
        
        for (final session in response.sessions) {
          if (!groupedSessions.containsKey(session.shopId) || 
              session.lastMessageTime > groupedSessions[session.shopId]!.lastMessageTime) {
            groupedSessions[session.shopId] = session;
          }
        }
        
        // Convert to list and sort by last message time
        final uniqueSessions = groupedSessions.values.toList()
          ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        
        setState(() {
          _sessions = uniqueSessions;
          _isLoading = false;
        });
        
        print('📋 [ChatListScreen] Grouped ${response.sessions.length} sessions into ${uniqueSessions.length} unique shops');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách chat: $e')),
        );
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pushNamed(context, '/login').then((_) {
      _checkLoginStatus();
    });
  }

  void _openChat(ChatSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          phien: session.phien,
          shopId: session.shopId,
          shopName: session.shopName,
          shopAvatar: session.shopAvatar,
        ),
      ),
    ).then((_) {
      _loadChatSessions(); // Refresh after returning
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tin nhắn',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: _currentUser == null ? _buildNotLoggedInView() : _buildChatListView(),
    );
  }

  Widget _buildNotLoggedInView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8F9FA),
            Color(0xFFE9ECEF),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Socdo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'lib/src/core/assets/images/logo_socdo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF8F9FA),
                              Color(0xFFE9ECEF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Chưa đăng nhập',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              const Text(
                'Vui lòng đăng nhập để xem tin nhắn\nvà trò chuyện với shop',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              
              // Login Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _navigateToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Đăng nhập ngay',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatListView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có tin nhắn nào',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bắt đầu trò chuyện với shop ngay!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChatSessions,
      color: Colors.red,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return _buildChatItem(session);
        },
      ),
    );
  }

  Widget _buildChatItem(ChatSession session) {
    return Dismissible(
      key: Key(session.phien),
      direction: DismissDirection.endToStart, // ✅ Chỉ swipe từ phải sang trái
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        // ✅ Hiển thị dialog xác nhận
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa cuộc trò chuyện'),
            content: Text('Bạn có chắc chắn muốn xóa cuộc trò chuyện với ${session.shopName}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        // ✅ Xóa session khỏi UI ngay lập tức
        setState(() {
          _sessions.removeWhere((s) => s.phien == session.phien);
        });
        // ✅ Gọi API xóa
        _deleteSession(session);
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChat(session),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Shop Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: session.shopAvatar.isNotEmpty
                        ? Image.network(
                            _authService.getAvatarUrl(session.shopAvatar),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.store,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.store,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Chat Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.shopName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.lastMessage ?? 'Chưa có tin nhắn',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Unread Badge
                if (session.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      session.unreadCount > 99 ? '99+' : '${session.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSession(ChatSession session) async {
    try {
      final success = await _chatService.deleteSession(
        phien: session.phien,
        userType: 'customer',
      );
      
      if (success) {
        // ✅ Đã xóa thành công, refresh list
        _loadChatSessions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa cuộc trò chuyện'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // ✅ Nếu xóa thất bại, reload lại list để hiển thị lại
        _loadChatSessions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể xóa cuộc trò chuyện'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        } 
      } 
    } catch (e) {
      _loadChatSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa cuộc trò chuyện: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
