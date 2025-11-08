import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'auth_service.dart';

/// SocketIOService - Quản lý kết nối Socket.IO cho chat realtime
class SocketIOService {
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _phien;
  final AuthService _authService = AuthService();
  
  // Callbacks
  Function(Map<String, dynamic>)? onMessage;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String)? onError;

  bool get isConnected => _isConnected;

  Future<void> connect(String phien) async {
    try {
      // Disconnect existing connection if any
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }

      _phien = phien;
      
      final socketUrl = 'https://chat.socdo.vn';
      print('🔌 [SocketIO] Connecting to $socketUrl with phien: $phien');
      
      // ✅ Config giống website: chỉ dùng websocket, không polling
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
          .setTransports(['websocket']) // ✅ CHỈ DÙNG WEBSOCKET, KHÔNG POLLING
          .setTimeout(5000) // 5 seconds timeout
          .setReconnectionAttempts(5) // Số lần thử reconnect
          .setReconnectionDelay(1000) // Delay 1s giữa các lần reconnect
          .setReconnectionDelayMax(5000) // Max delay 5s
          .setExtraHeaders({}) // Có thể thêm headers nếu cần
          .enableAutoConnect() // Tự động connect
          .enableForceNew() // Force new connection
          .build()
      );

      print('✅ [SocketIO] Socket created with websocket transport only');
      
      // ✅ Setup event listeners TRƯỚC KHI connect
      _setupEventListeners();
      
      print('✅ [SocketIO] Socket setup complete, waiting for connection...');
      
      // ✅ Wait for connection với timeout
      int attempts = 0;
      while (attempts < 10 && (_socket?.connected != true)) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        if (_socket?.connected == true) {
          print('✅✅✅ [SocketIO] CONNECTED! ID: ${_socket!.id}');
          break;
        }
      }
      
      if (_socket?.connected != true) {
        print('❌ [SocketIO] Connection timeout after ${attempts * 500}ms');
        if (onError != null) onError!('Connection timeout');
      }
      
    } catch (e) {
      print('❌ [SocketIO] Setup error: $e');
      print('❌ [SocketIO] Error stack: ${StackTrace.current}');
      _isConnected = false;
      if (onError != null) onError!(e.toString());
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    // ✅ Connect event
    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅✅✅ [SocketIO] CONNECTED! ID: ${_socket!.id}');
      try {
        final transportName = _socket!.io.engine.transport?.name ?? 'unknown';
        print('✅✅✅ [SocketIO] Transport: $transportName');
      } catch (e) {
        print('⚠️ [SocketIO] Could not get transport name: $e');
      }
      if (onConnected != null) onConnected!();
    });

    // ✅ Disconnect event
    _socket!.onDisconnect((reason) {
      _isConnected = false;
      print('🔌 [SocketIO] Disconnected: $reason');
      if (onDisconnected != null) onDisconnected!();
    });

    // ✅ Connect error event - QUAN TRỌNG để debug
    _socket!.onConnectError((error) {
      _isConnected = false;
      print('❌ [SocketIO] Connect error: $error');
      print('❌ [SocketIO] Error type: ${error.runtimeType}');
      if (onError != null) onError!(error.toString());
    });

    // ✅ Generic error event
    _socket!.on('error', (error) {
      print('❌ [SocketIO] Socket error: $error');
      print('❌ [SocketIO] Error type: ${error.runtimeType}');
    });

    // ✅ Reconnect event
    _socket!.onReconnect((attempt) {
      _isConnected = true;
      print('🔄 [SocketIO] Reconnected after $attempt attempts');
      if (onConnected != null) onConnected!();
    });

    // ✅ Reconnect attempt event
    _socket!.onReconnectAttempt((attempt) {
      print('🔄 [SocketIO] Reconnect attempt #$attempt');
    });

    // ✅ Reconnect error event
    _socket!.onReconnectError((error) {
      print('❌ [SocketIO] Reconnect error: $error');
    });

    // ✅ Reconnect failed event
    _socket!.onReconnectFailed((_) {
      print('❌ [SocketIO] Reconnect failed after max attempts');
    });

    // ✅ Business logic: Listen for messages
    _socket!.on('server_send_message', (data) {
      print('📨 [SocketIO] Received server_send_message: $data');
      if (onMessage != null) {
        // Convert data to Map if needed
        if (data is Map) {
          onMessage!(data as Map<String, dynamic>);
        } else if (data is String) {
          try {
            onMessage!({'message': data});
          } catch (e) {
            print('❌ [SocketIO] Error parsing message: $e');
          }
        }
      }
    });

    // ✅ Debug: Listen for ping/pong để verify connection
    _socket!.on('ping', (_) {
      print('🏓 [SocketIO] Received ping');
    });

    _socket!.on('pong', (_) {
      print('🏓 [SocketIO] Received pong');
    });

    print('📝 [SocketIO] Event listeners setup complete');
  }

  Future<void> sendMessage(String message, {String senderType = 'customer'}) async {
    if (!_isConnected || _socket == null) {
      print('❌ [SocketIO] Cannot send - not connected');
      return;
    }

    final user = await _authService.getCurrentUser();
    if (user == null) {
      print('❌ [SocketIO] User not found');
      return;
    }

    final data = {
      'session_id': _phien,
      'customer_id': user.userId,
      'ncc_id': 0,
      'message': message,
    };

    print('📤 [SocketIO] Emitting client_send_message: $data');
    _socket!.emit('client_send_message', data);
    print('✅ [SocketIO] Message emitted');
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _phien = null;
    print('🔌 [SocketIO] Disconnected and disposed');
  }
}
