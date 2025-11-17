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

      
      // ✅ Setup event listeners TRƯỚC KHI connect
      _setupEventListeners();
      
      
      // ✅ Wait for connection với timeout
      int attempts = 0;
      while (attempts < 10 && (_socket?.connected != true)) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        if (_socket?.connected == true) {
          break;
        }
      }
      
      if (_socket?.connected != true) {
        if (onError != null) onError!('Connection timeout');
      }
      
    } catch (e) {
      _isConnected = false;
      if (onError != null) onError!(e.toString());
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    // ✅ Connect event
    _socket!.onConnect((_) {
      _isConnected = true;
      try {
        final transportName = _socket!.io.engine.transport?.name ?? 'unknown';
      } catch (e) {
      }
      if (onConnected != null) onConnected!();
    });

    // ✅ Disconnect event
    _socket!.onDisconnect((reason) {
      _isConnected = false;
      if (onDisconnected != null) onDisconnected!();
    });

    // ✅ Connect error event - QUAN TRỌNG để debug
    _socket!.onConnectError((error) {
      _isConnected = false;
      if (onError != null) onError!(error.toString());
    });

    // ✅ Generic error event
    _socket!.on('error', (error) {
    });

    // ✅ Reconnect event
    _socket!.onReconnect((attempt) {
      _isConnected = true;
      if (onConnected != null) onConnected!();
    });

    // ✅ Reconnect attempt event
    _socket!.onReconnectAttempt((attempt) {
    });

    // ✅ Reconnect error event
    _socket!.onReconnectError((error) {
    });

    // ✅ Reconnect failed event
    _socket!.onReconnectFailed((_) {
    });

    // ✅ Business logic: Listen for messages
    _socket!.on('server_send_message', (data) {
      if (onMessage != null) {
        // Convert data to Map if needed
        if (data is Map) {
          onMessage!(data as Map<String, dynamic>);
        } else if (data is String) {
          try {
            onMessage!({'message': data});
          } catch (e) {
          }
        }
      }
    });

    // ✅ Debug: Listen for ping/pong để verify connection
    _socket!.on('ping', (_) {
    });

    _socket!.on('pong', (_) {
    });

  }

  Future<void> sendMessage(String message, {String senderType = 'customer'}) async {
    if (!_isConnected || _socket == null) {
      return;
    }

    final user = await _authService.getCurrentUser();
    if (user == null) {
      return;
    }

    final data = {
      'session_id': _phien,
      'customer_id': user.userId,
      'ncc_id': 0,
      'message': message,
    };

    _socket!.emit('client_send_message', data);
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _phien = null;
  }
}
