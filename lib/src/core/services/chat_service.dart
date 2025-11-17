import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_manager.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/chat.dart';

class ChatService {
  static const String _baseUrl = 'https://api.socdo.vn/v1';
  
  final TokenManager _tokenManager = TokenManager();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  // Lấy token hợp lệ từ ApiService
  Future<String?> get _token async => await _apiService.getValidToken();
  
  // Public method để lấy token cho SSE
  Future<String?> getToken() async => await _token;

  // Headers cho API calls
  Future<Map<String, String>> get _headers async {
    final token = await _token;
    
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    return headers;
  }

  /// Tạo phiên chat mới với shop
  Future<ChatSessionResponse> createSession({required int shopId}) async {
    try {
      final headers = await _headers;
      final url = '$_baseUrl/chat_api_correct?action=create_session';
      
      // Lấy user_id từ AuthService
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      final userId = user.userId;
      
      final body = {
        'shop_id': shopId,
        'user_id': userId,
      };
      

   
      // Kiểm tra token validity
      await _token;
     
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body), // Gửi JSON body
      );

     
      
    
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatSessionResponse.fromJson(data);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi tạo phiên chat: $e');
    }
  }

  /// Lấy danh sách phiên chat
  Future<ChatListResponse> getSessions({required int userId, required String userType, int page = 1, int limit = 20}) async {
    try {
      final headers = await _headers;
      final body = json.encode({
        'action': 'list_sessions',
        'user_id': userId,
        'user_type': userType,
        'page': page,
        'limit': limit,
      });
      
      final response = await http.post(
        Uri.parse('$_baseUrl/chat_api_correct'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatListResponse.fromJson(data);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi lấy danh sách chat: $e');
    }
  }

  /// Lấy tin nhắn của phiên chat
  Future<ChatMessagesResponse> getMessages(String phien) async {
    try {
      final headers = await _headers;
      final url = '$_baseUrl/chat_api_correct?action=get_messages&phien=$phien&page=1&limit=50';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({}), // Empty JSON body
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatMessagesResponse.fromJson(data);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi lấy tin nhắn: $e');
    }
  }

  /// Gửi tin nhắn
  Future<ChatSendResponse> sendMessage({
    required String phien,
    required String content,
    required String senderType,
    int productId = 0,
    int variantId = 0,
  }) async {
    try {
      final headers = await _headers;
      final url = '$_baseUrl/chat_api_correct'; // Không có action trong URL
      final body = {
        'action': 'send_message', // Action trong body
        'phien': phien,
        'content': content,
        'sender_type': senderType,
        'product_id': productId,
        'variant_id': variantId,
      };
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );



      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatSendResponse.fromJson(data);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi gửi tin nhắn: $e');
    }
  }

  /// Đánh dấu tin nhắn đã đọc
  Future<bool> markAsRead({required String phien, bool markAll = true, String? messageIds}) async {
    try {
      final headers = await _headers;
      String url = '$_baseUrl/chat_api_correct?action=mark_read&phien=$phien&mark_all=$markAll';
      
      if (messageIds != null && messageIds.isNotEmpty) {
        url += '&message_ids=$messageIds';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi đánh dấu đã đọc: $e');
    }
  }

  /// Lấy số tin nhắn chưa đọc
  Future<ChatUnreadResponse> getUnreadCount({required int userId, required String userType}) async {
    try {
      final headers = await _headers;
      final url = '$_baseUrl/chat_api_correct?action=get_unread_count&user_id=$userId&user_type=$userType';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({}), // Empty JSON body
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatUnreadResponse.fromJson(data);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi lấy số tin nhắn chưa đọc: $e');
    }
  }

  /// Đóng phiên chat
  Future<bool> closeSession({required String phien}) async {
    try {
      final headers = await _headers;
      final url = '$_baseUrl/chat_api_correct?action=close_session';
      final body = {
        'phien': phien,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi đóng phiên chat: $e');
    }
  }

  /// Xóa phiên chat (xóa cả cuộc trò chuyện)
  Future<bool> deleteSession({required String phien, required String userType}) async {
    try {
      final headers = await _headers;
      final url = '$_baseUrl/chat_api_correct?action=delete_session';
      final body = {
        'phien': phien,
        'user_type': userType,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi xóa cuộc trò chuyện: $e');
    }
  }

  /// Tìm kiếm tin nhắn
  Future<ChatMessagesResponse> searchMessages({
    required String phien,
    required String keyword,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _headers;
      final url = '$_baseUrl/chat_api_correct?action=search_messages&phien=$phien&keyword=$keyword&page=$page&limit=$limit';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({}), // Empty JSON body
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatMessagesResponse.fromJson(data);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi tìm kiếm tin nhắn: $e');
    }
  }

  /// Reset unread count khi user vào chat
  Future<bool> resetUnreadCount({required String phien, required String userType}) async {
    try {
      final headers = await _headers;
      final url = '$_baseUrl/chat_api_correct?action=reset_unread';
      final body = {
        'phien': phien,
        'user_type': userType,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi reset unread count: $e');
    }
  }

  /// Tạo SSE connection URL (sử dụng SSE real-time mới)
  Future<String> getSseUrl({required String phien, int? sessionId}) async {
    final params = <String, String>{
      'phien': phien,
    };
    
    if (sessionId != null) {
      params['session_id'] = sessionId.toString();
    }

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    // Sử dụng SSE endpoint real-time thật sự
    return '$_baseUrl/sse_realtime_final?$queryString';
  }
}
