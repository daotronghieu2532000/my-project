import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/socketio_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/blocked_users_service.dart';
import '../../core/utils/profanity_filter.dart';
import '../../core/models/chat.dart';
import '../shop/shop_detail_screen.dart';
import 'widgets/report_user_dialog.dart' show showReportUserDialog;
import 'widgets/block_user_dialog.dart' show showBlockUserDialog;

class ChatScreen extends StatefulWidget {
  final int shopId;
  final String shopName;
  final String? shopAvatar;
  final int? sessionId;
  final String? phien;

  const ChatScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    this.shopAvatar,
    this.sessionId,
    this.phien,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final SocketIOService _socketIOService = SocketIOService();
  final AuthService _authService = AuthService();
  final BlockedUsersService _blockedUsersService = BlockedUsersService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String? _phien;
  bool _isConnected = false;
  String? _searchQuery;
  List<ChatMessage> _filteredMessages = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Set<int> _blockedUserIds = {};
  
  // ✅ Mẫu chat tiêu biểu
  final List<String> _quickReplies = [
    'Xin chào',
    'Cảm ơn bạn',
    'Sản phẩm còn hàng không?',
    'Giá bao nhiêu?',
    'Có ship không?',
    'Tôi muốn đặt hàng',
    'Có thể tư vấn thêm không?',
    'Sản phẩm có bảo hành không?',
  ];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _initializeChat();
  }

  Future<void> _loadBlockedUsers() async {
    await _blockedUsersService.initialize();
    final blocked = await _blockedUsersService.getBlockedUsers();
    if (mounted) {
      setState(() {
        _blockedUserIds = blocked;
      });
    }
  }

  Timer? _pollingTimer;
  int _lastMessageCount = 0;

  void _startPolling() {
    _stopPolling();
    // ✅ Tăng interval từ 3s lên 5s để giảm tải server
    // 3s là quá nhanh và tốn băng thông
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _pollForNewMessages();
    });
  }

  void _stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> _pollForNewMessages() async {
    if (_phien == null || !mounted) return;
    
    try {
      final response = await _chatService.getMessages(_phien!);
      if (response.success && response.messages.length > _lastMessageCount) {
        _lastMessageCount = response.messages.length;
        
        // Get current user to determine isOwn for each message
        final currentUser = await _authService.getCurrentUser();
        
        // Update isOwn for each message
        final updatedMessages = response.messages.map((message) {
          final isOwn = currentUser != null && message.senderId == currentUser.userId;
          return ChatMessage(
            id: message.id,
            senderId: message.senderId,
            senderType: message.senderType,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            content: message.content,
            datePost: message.datePost,
            dateFormatted: message.dateFormatted,
            isRead: message.isRead,
            isOwn: isOwn,
          );
        }).toList();
        
        if (mounted) {
          setState(() {
            _messages = updatedMessages;
          });
        }
      }
    } catch (e) {
      // Polling error
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _socketIOService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      // Check if user is logged in first
      final isLoggedIn = await _authService.isLoggedIn();
      if (!isLoggedIn) {
        setState(() {
          _isLoading = false;
          _error = 'not_logged_in';
        });
        return;
      }
      
      // Use existing session or create new one
      if (widget.phien != null) {
        _phien = widget.phien;
      } else {
        // Create new session
        final response = await _chatService.createSession(
          shopId: widget.shopId,
        );
        
        if (response.success) {
          _phien = response.phien;
        } else {
          setState(() {
            _error = 'Failed to create session';
            _isLoading = false;
          });
          return;
        }
      }
      
      
      // Load existing messages
      await _loadMessages();
      
      // Connect to Socket.io
      _connectSocketIO();
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = 'Không thể khởi tạo chat: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    if (_phien == null) return;
    
    try {
      // Reset unread count khi vào chat
      await _chatService.resetUnreadCount(phien: _phien!, userType: 'customer');
      
      final response = await _chatService.getMessages(_phien!);
      
      if (response.success) {
        // Get current user to determine isOwn for each message
        final currentUser = await _authService.getCurrentUser();
        
        // Update isOwn for each message
        final updatedMessages = response.messages.map((message) {
          final isOwn = currentUser != null && message.senderId == currentUser.userId;
          return ChatMessage(
            id: message.id,
            senderId: message.senderId,
            senderType: message.senderType,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            content: message.content,
            datePost: message.datePost,
            dateFormatted: message.dateFormatted,
            isRead: message.isRead,
            isOwn: isOwn,
          );
        }).toList();
        
        setState(() {
          _messages = updatedMessages;
          _lastMessageCount = updatedMessages.length;
        });
        
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _connectSocketIO() {
    if (_phien == null) return;

    // Set up Socket.io callbacks
    _socketIOService.onConnected = () {
      if (!mounted) return; // ✅ Không làm gì nếu widget đã dispose
        setState(() { _isConnected = true; });
      // ✅ Dừng polling khi Socket.IO đã connect (realtime)
      _stopPolling();
    };

    _socketIOService.onDisconnected = () {
      if (!mounted) return; // ✅ Không làm gì nếu widget đã dispose
        setState(() { _isConnected = false; });
      // ✅ Start polling lại khi Socket.IO disconnect (fallback)
      _startPolling();
    };

    _socketIOService.onError = (error) {
      if (!mounted) return; // ✅ Không làm gì nếu widget đã dispose
        setState(() { _isConnected = false; });
      // ✅ Start polling khi Socket.IO có lỗi (fallback)
      if (!_socketIOService.isConnected) {
        _startPolling();
      }
    };

    _socketIOService.onMessage = (message) {
      _handleSocketIOMessage(message);
    };

    // Connect to Socket.io
    _socketIOService.connect(_phien!);
    
    // ✅ Chỉ start polling nếu Socket.IO chưa connect (fallback)
    // Polling sẽ tự động dừng khi Socket.IO connect thành công
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_socketIOService.isConnected) {
    _startPolling();
      }
    });
  }

  void _handleSocketIOMessage(Map<String, dynamic> message) {
    // Handle new message from Socket.io
    _handleNewMessage(message);
  }

  void _handleNewMessage(Map<String, dynamic> message) async {
    // Socket.io có thể gửi message trực tiếp hoặc trong 'message' field
    // ✅ Kiểm tra nếu message['message'] là Map thì dùng nó, nếu là String thì dùng message
    Map<String, dynamic> messageData;
    if (message['message'] != null && message['message'] is Map) {
      messageData = Map<String, dynamic>.from(message['message'] as Map);
    } else {
      messageData = message;
    }
    
    if (messageData.isEmpty) {
      return;
    }
    
    // Get current user to determine if message is own
    final currentUser = await _authService.getCurrentUser();
    final senderId = int.tryParse(messageData['sender_id']?.toString() ?? messageData['customer_id']?.toString() ?? '0') ?? 0;
    final isOwn = currentUser != null && senderId == currentUser.userId;
    
    // Create ChatMessage object
    // ✅ Lấy content từ message hoặc content field
    final content = messageData['message'] is String 
        ? messageData['message'] as String
        : (messageData['content'] ?? messageData['message'] ?? '') as String;
    
    // ✅ Lấy time từ time field hoặc date_formatted
    final timeStr = messageData['time'] ?? messageData['date_formatted'] ?? DateTime.now().toString();
    
    final messageId = int.tryParse(messageData['id']?.toString() ?? messageData['message_id']?.toString() ?? '0') ?? 0;
    
    // ✅ Kiểm tra xem message đã tồn tại chưa (tránh duplicate)
    // Kiểm tra theo id hoặc theo content trong 5 giây gần đây
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    bool isDuplicate = false;
    
    // Kiểm tra theo id nếu có
    if (messageId > 0) {
      isDuplicate = _messages.any((msg) => msg.id == messageId && msg.id > 0);
    }
    
    // Nếu chưa tìm thấy duplicate, kiểm tra theo content trong 5 giây gần đây
    // ✅ Quan trọng: Khi gửi message, nó được thêm với isOwn=true, senderId=0
    // Khi nhận từ Socket.IO, nó có isOwn=false, senderId=0 (hoặc customer_id)
    // Nên chỉ cần kiểm tra content + thời gian, không cần quan tâm isOwn hay senderId
    if (!isDuplicate) {
      isDuplicate = _messages.any((msg) {
        // Kiểm tra content giống nhau và thời gian gần đây (5 giây)
        // ✅ Bỏ qua kiểm tra isOwn và senderId vì chúng có thể khác nhau
        // khi gửi vs khi nhận từ Socket.IO
        if (msg.content == content && (now - msg.datePost).abs() < 5) {
          return true;
        }
        return false;
      });
    }
    
    // ✅ Nếu message đã tồn tại, bỏ qua
    if (isDuplicate) {
      return;
    }
    
    final chatMessage = ChatMessage(
      id: messageId,
      senderId: senderId,
      senderType: messageData['sender_type'] ?? 'customer',
      senderName: messageData['sender_name'] ?? 'Unknown',
      senderAvatar: messageData['sender_avatar'] ?? '',
      content: content,
      datePost: int.tryParse(messageData['date_post']?.toString() ?? '0') ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      dateFormatted: timeStr,
      isRead: messageData['is_read'] == 1 || messageData['is_read'] == '1' || messageData['is_read'] == true,
      isOwn: isOwn,
    );
    
    if (mounted) {
      setState(() {
        _messages.add(chatMessage);
      });
    }
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    // ✅ Update filtered messages nếu đang search
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      _filterMessages(_searchQuery!);
    }
  }


  void _navigateToShopDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDetailScreen(
          shopId: widget.shopId,
          shopName: widget.shopName,
          shopAvatar: widget.shopAvatar,
        ),
      ),
    );
  }

  Future<void> _handleBlockUser() async {
    // Hiển thị dialog xác nhận
    showBlockUserDialog(
      context,
      widget.shopName,
      () async {
        // Chặn người dùng
        final success = await _blockedUsersService.blockUser(widget.shopId);
        
        if (success && mounted) {
          // Cập nhật danh sách chặn
          await _loadBlockedUsers();
          
          // Lọc lại messages để ẩn nội dung của người bị chặn ngay lập tức
          setState(() {
            // Messages sẽ được lọc trong _buildChatScreen
          });
          
          // Hiển thị thông báo
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã chặn người dùng. Nội dung của họ đã bị ẩn.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }


  void _filterMessages(String query) {
    setState(() {
      _searchQuery = query;
      _filteredMessages = _messages.where((message) {
        return message.content.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
    
    // Scroll to first matching message
    if (_filteredMessages.isNotEmpty && _scrollController.hasClients) {
      final firstMatchIndex = _messages.indexOf(_filteredMessages.first);
      if (firstMatchIndex >= 0) {
        _scrollController.animateTo(
          firstMatchIndex * 80.0, // Approximate height per message
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending || _phien == null) return;
    
    // ✅ Lọc từ ngữ thô tục trước khi gửi
    final filterResult = ProfanityFilter.checkAndFilter(content);
    if (filterResult['containsProfanity'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tin nhắn chứa nội dung không phù hợp. Vui lòng chỉnh sửa.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() { _isSending = true; });
    
    try {
      // Send via API first (to save to database)
      final response = await _chatService.sendMessage(
        phien: _phien!,
        content: content,
        senderType: 'customer',
      );
      
      if (response.success) {
        // Clear input
        _messageController.clear();
        
        // Also send via Socket.io for real-time
        _socketIOService.sendMessage(content, senderType: 'customer');
        
        // Add message to UI immediately
        final newMessage = ChatMessage(
          id: response.message?.id ?? 0,
          senderId: 0, // Will be updated when received from server
          senderType: 'customer',
          senderName: 'Bạn',
          senderAvatar: '',
          content: content,
          datePost: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          dateFormatted: DateTime.now().toString(),
          isRead: false,
          isOwn: true,
        );
        
        if (mounted) {
          setState(() {
            _messages.add(newMessage);
          });
        }
        
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        throw Exception(response.message ?? 'Failed to send message');
      }
      
      setState(() { _isSending = false; });
      
    } catch (e) {
      setState(() { _isSending = false; });
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gửi tin nhắn: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tin nhắn...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = null;
                        _filteredMessages = [];
                        _searchController.clear();
                      });
                    },
                  ),
                ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      _searchQuery = null;
                      _filteredMessages = [];
                    });
                  } else {
                    _filterMessages(value);
                  }
                },
              )
            : Row(
          children: [
                  Expanded(
                    child: Text(
              widget.shopName,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
                  ),
                  const SizedBox(width: 8),
                  // ✅ Chấm tròn hiển thị trạng thái kết nối
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                color: _isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 8,
            onSelected: (value) {
              if (value == 'shop_profile') {
                _navigateToShopDetail();
              } else if (value == 'search') {
                setState(() {
                  _isSearching = true;
                });
              } else if (value == 'report') {
                showReportUserDialog(context);
              } else if (value == 'block') {
                _handleBlockUser();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'shop_profile',
                child: Row(
                  children: [
                    Icon(Icons.store, color: Colors.blue[600], size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Xem hồ sơ shop',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.orange[600], size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Tìm kiếm tin nhắn',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [ 
                    Icon(Icons.flag_outlined, size: 22, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Tố cáo ',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 22, color: Colors.red[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Chặn người dùng này',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error == 'not_logged_in'
              ? _buildLoginRequiredScreen()
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _initializeChat,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    )
                  : _buildChatScreen(),
    );
  }

  Widget _buildChatScreen() {
    // ✅ Lọc messages: ẩn tin nhắn từ người bị chặn và lọc profanity
    final filteredByBlock = _messages.where((message) {
      // Ẩn tin nhắn từ người dùng bị chặn (shopId)
      if (!message.isOwn && _blockedUserIds.contains(widget.shopId)) {
        return false;
      }
      // Ẩn tin nhắn từ sender bị chặn (nếu có senderId)
      if (!message.isOwn && message.senderId > 0 && _blockedUserIds.contains(message.senderId)) {
        return false;
      }
      return true;
    }).toList();
    
    // ✅ Sử dụng filtered messages nếu đang search, nếu không thì dùng messages đã lọc chặn
    final displayMessages = _searchQuery != null && _searchQuery!.isNotEmpty
        ? _filteredMessages.where((message) {
            // Cũng lọc chặn trong search results
            if (!message.isOwn && _blockedUserIds.contains(widget.shopId)) {
              return false;
            }
            if (!message.isOwn && message.senderId > 0 && _blockedUserIds.contains(message.senderId)) {
              return false;
            }
            return true;
          }).toList()
        : filteredByBlock;
    
    return Column(
      children: [
        // ✅ Hiển thị search bar nếu đang search
        if (_searchQuery != null && _searchQuery!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange[50],
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tìm thấy ${_filteredMessages.length} tin nhắn với "$_searchQuery"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchQuery = null;
                      _filteredMessages = [];
                    });
                  },
                  color: Colors.orange[700],
                ),
              ],
            ),
          ),
        // Messages list
        Expanded(
          child: displayMessages.isEmpty && _searchQuery != null && _searchQuery!.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Không tìm thấy tin nhắn nào',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
                  itemCount: displayMessages.length,
            itemBuilder: (context, index) {
                    final message = displayMessages[index];
                    final isHighlighted = _searchQuery != null && 
                        _searchQuery!.isNotEmpty &&
                        message.content.toLowerCase().contains(_searchQuery!.toLowerCase());
                    return _buildMessageBubble(message, isHighlighted: isHighlighted);
                  },
                ),
        ),
        
        // ✅ Quick reply messages (mẫu chat tiêu biểu)
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickReplies.length,
            itemBuilder: (context, index) {
              final reply = _quickReplies[index];
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    _messageController.text = reply;
                    _sendMessage();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Center(
                      child: Text(
                        reply,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _isSending ? Colors.grey : Colors.blue,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginRequiredScreen() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Chat icon with gradient
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red[50]!,
                      Colors.red[100]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(70),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 70,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 40),
              
              // Title
              const Text(
                'Vui lòng đăng nhập để trò chuyện',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Bạn cần đăng nhập để có thể trò chuyện với ${widget.shopName}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Login button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _navigateToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 4,
                    shadowColor: Colors.red.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Back button
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Quay lại',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin() async {
    final result = await Navigator.pushNamed(context, '/login');
    if (result == true) {
      // User logged in successfully, reset error and reinitialize chat
      setState(() {
        _error = null;
        _isLoading = true;
      });
      _initializeChat();
    }
  }

  Widget _buildMessageBubble(ChatMessage message, {bool isHighlighted = false}) {
    final isOwn = message.isOwn;
    
    // ✅ Lọc profanity trong nội dung hiển thị
    final filterResult = ProfanityFilter.checkAndFilter(message.content);
    final displayContent = filterResult['filteredText'] as String;
    
    // ✅ Highlight text nếu đang search
    Widget contentWidget;
    if (isHighlighted && _searchQuery != null && _searchQuery!.isNotEmpty) {
      final query = _searchQuery!.toLowerCase();
      final content = displayContent; // Sử dụng nội dung đã lọc
      final contentLower = content.toLowerCase();
      final queryIndex = contentLower.indexOf(query);
      
      if (queryIndex >= 0) {
        // Tìm tất cả các vị trí match
        final matches = <int>[];
        int startIndex = 0;
        while (startIndex < contentLower.length) {
          final index = contentLower.indexOf(query, startIndex);
          if (index == -1) break;
          matches.add(index);
          startIndex = index + query.length;
        }
        
        // Tạo TextSpan với highlight
        final spans = <TextSpan>[];
        int lastIndex = 0;
        for (final matchIndex in matches) {
          // Text trước match
          if (matchIndex > lastIndex) {
            spans.add(TextSpan(
              text: content.substring(lastIndex, matchIndex),
              style: TextStyle(
                color: isOwn ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ));
          }
          // Text match (highlight)
          spans.add(TextSpan(
            text: content.substring(matchIndex, matchIndex + query.length),
            style: TextStyle(
              color: isOwn ? Colors.white : Colors.black87,
              fontSize: 14,
              backgroundColor: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ));
          lastIndex = matchIndex + query.length;
        }
        // Text sau match cuối
        if (lastIndex < content.length) {
          spans.add(TextSpan(
            text: content.substring(lastIndex),
            style: TextStyle(
              color: isOwn ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ));
        }
        
        contentWidget = RichText(
          text: TextSpan(children: spans),
        );
      } else {
        contentWidget = Text(
          displayContent,
          style: TextStyle(
            color: isOwn ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
        );
      }
    } else {
      contentWidget = Text(
        displayContent,
        style: TextStyle(
          color: isOwn ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: isHighlighted
          ? BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: isHighlighted ? const EdgeInsets.all(4) : EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOwn) ...[
            _buildShopAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isOwn ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  contentWidget,
                  const SizedBox(height: 4),
                  Text(
                    message.dateFormatted,
                    style: TextStyle(
                      color: isOwn ? Colors.white70 : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 8),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildShopAvatar() {
    if (widget.shopAvatar != null && widget.shopAvatar!.isNotEmpty) {
      String avatarUrl = widget.shopAvatar!;
      // Fix avatar URL - add base URL if it's a relative path
      if (!avatarUrl.startsWith('http')) {
        avatarUrl = 'https://socdo.vn$avatarUrl';
      }
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: Colors.pink[100],
        onBackgroundImageError: (exception, stackTrace) {
          // Error loading shop avatar
        },
      );
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.pink[100],
      child: const Icon(Icons.store, size: 16, color: Colors.pink),
    );
  }

  Widget _buildUserAvatar() {
    return FutureBuilder(
      future: _authService.getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final avatarUrl = _authService.getAvatarUrl(user.avatar);
          
          return CircleAvatar(
            radius: 16,
            backgroundImage: avatarUrl.startsWith('http') 
                ? NetworkImage(avatarUrl)
                : null,
            backgroundColor: Colors.blue[100],
            child: avatarUrl.startsWith('http') 
                ? null 
                : const Icon(Icons.person, size: 16, color: Colors.blue),
          );
        }
        
        return CircleAvatar(
          radius: 16,
          backgroundColor: Colors.blue[100],
          child: const Icon(Icons.person, size: 16, color: Colors.blue),
        );
      },
    );
  }
}