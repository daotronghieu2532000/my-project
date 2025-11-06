import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/socketio_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/chat.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String? _phien;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Timer? _pollingTimer;
  int _lastMessageCount = 0;

  void _startPolling() {
    _stopPolling();
    print('🔄 [ChatScreen] Starting polling for new messages...');
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
      print('⏹️ [ChatScreen] Stopped polling');
    }
  }

  Future<void> _pollForNewMessages() async {
    if (_phien == null || !mounted) return;
    
    try {
      final response = await _chatService.getMessages(_phien!);
      if (response.success && response.messages.length > _lastMessageCount) {
        print('📨 [ChatScreen] Polling found ${response.messages.length - _lastMessageCount} new messages');
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
      print('❌ [ChatScreen] Polling error: $e');
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _socketIOService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
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
      print('🔌 [Socket.io] Connected successfully');
      if (mounted) {
        setState(() { _isConnected = true; });
      }
    };

    _socketIOService.onDisconnected = () {
      print('🔌 [Socket.io] Disconnected');
      if (mounted) {
        setState(() { _isConnected = false; });
      }
    };

    _socketIOService.onError = (error) {
      print('❌ [Socket.io] Error: $error');
      if (mounted) {
        setState(() { _isConnected = false; });
      }
    };

    _socketIOService.onMessage = (message) {
      print('📨 [Socket.io] Received message: $message');
      _handleSocketIOMessage(message);
    };

    // Connect to Socket.io
    print('🔌 [Socket.io] Connecting to phien: $_phien');
    _socketIOService.connect(_phien!);
    
    // Start polling as backup
    _startPolling();
  }

  void _handleSocketIOMessage(Map<String, dynamic> message) {
    // Handle new message from Socket.io
    _handleNewMessage(message);
  }

  void _handleNewMessage(Map<String, dynamic> message) async {
    print('🔄 [ChatScreen] _handleNewMessage called with: $message');
    
    // Socket.io có thể gửi message trực tiếp hoặc trong 'message' field
    final messageData = message['message'] ?? message;
    if (messageData == null) {
      print('❌ [ChatScreen] messageData is null');
      return;
    }
    
    print('📝 [ChatScreen] Processing messageData: $messageData');
    
    // Get current user to determine if message is own
    final currentUser = await _authService.getCurrentUser();
    final senderId = int.tryParse(messageData['sender_id']?.toString() ?? '0') ?? 0;
    final isOwn = currentUser != null && senderId == currentUser.userId;
    
    print('👤 [ChatScreen] Current user: ${currentUser?.userId}, Sender: $senderId, IsOwn: $isOwn');
    
    // Create ChatMessage object
    final chatMessage = ChatMessage(
      id: int.tryParse(messageData['id']?.toString() ?? '0') ?? 0,
      senderId: senderId,
      senderType: messageData['sender_type'] ?? 'customer',
      senderName: messageData['sender_name'] ?? 'Unknown',
      senderAvatar: messageData['sender_avatar'] ?? '',
      content: messageData['content'] ?? messageData['message'] ?? '',
      datePost: int.tryParse(messageData['date_post']?.toString() ?? '0') ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      dateFormatted: messageData['date_formatted'] ?? DateTime.now().toString(),
      isRead: messageData['is_read'] == 1 || messageData['is_read'] == '1' || messageData['is_read'] == true,
      isOwn: isOwn,
    );
    
    print('💬 [ChatScreen] Created ChatMessage: ${chatMessage.content}');
    
    if (mounted) {
      setState(() {
        _messages.add(chatMessage);
        print('📊 [ChatScreen] Total messages: ${_messages.length}');
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
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending || _phien == null) return;
    
    print('📤 [ChatScreen] Sending message: $content');
    setState(() { _isSending = true; });
    
    try {
      // Send via API first (to save to database)
      print('🌐 [ChatScreen] Sending via API...');
      final response = await _chatService.sendMessage(
        phien: _phien!,
        content: content,
        senderType: 'customer',
      );
      
      if (response.success) {
        print('✅ [ChatScreen] API send successful');
        // Clear input
        _messageController.clear();
        
        // Also send via Socket.io for real-time
        print('📡 [ChatScreen] Sending via Socket.io...');
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
            print('📊 [ChatScreen] Added message to UI, total: ${_messages.length}');
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
      print('❌ [ChatScreen] Send message error: $e');
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.shopName,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _isConnected ? 'Socket.io Connected' : 'Connecting...',
              style: TextStyle(
                fontSize: 12,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show more options
            },
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
    return Column(
      children: [
        // Messages list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _buildMessageBubble(message);
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

  Widget _buildMessageBubble(ChatMessage message) {
    final isOwn = message.isOwn;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isOwn ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
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
        print('🔗 [ChatScreen] Fixed avatar URL: $avatarUrl');
      }
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: Colors.pink[100],
        onBackgroundImageError: (exception, stackTrace) {
          print('❌ Error loading shop avatar: $exception');
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