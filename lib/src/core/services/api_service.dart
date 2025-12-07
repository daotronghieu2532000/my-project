import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'token_manager.dart';
import 'auth_service.dart';
import 'request_priority_queue.dart';
import '../models/freeship_product.dart';
import '../models/voucher.dart';
import '../models/flash_sale_product.dart';
import '../models/flash_sale_deal.dart';
import '../models/product_suggest.dart';
import '../models/product_detail.dart';
import '../models/related_product.dart';
import '../models/banner.dart';
import '../models/popup_banner.dart';
import '../models/brand.dart';
import '../models/banner_products.dart';
import '../models/shop_detail.dart';
import '../models/splash_screen.dart';

class ApiService {
  static const String baseUrl = 'https://api.socdo.vn/v1';
  static const String apiKey = 'zzz8m4rjxnvgogy1gr1htkncn7';
  static const String apiSecret = 'wz2yht03i0ag2ilib8gpfhbgusq2pw9ylo3sn2n2uqs4djugtf5nbgn1h0o3jx';
  
  // Timeout cho HTTP requests - tránh treo vô hạn
  static const Duration requestTimeout = Duration(seconds: 30);
  
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  final TokenManager _tokenManager = TokenManager();
  final RequestPriorityQueue _requestQueue = RequestPriorityQueue();

  /// Lấy token từ API
  Future<String?> _fetchToken() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_token'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'api_key': apiKey,
          'api_secret': apiSecret,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          final token = data['token'] as String;
          await _tokenManager.saveToken(token);
          return token;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Lấy token hợp lệ (từ cache hoặc fetch mới)
  Future<String?> getValidToken() async {
    // Kiểm tra token hiện tại
    String? currentToken = await _tokenManager.getToken();
    
    if (currentToken != null && _tokenManager.isTokenValid(currentToken)) {
      return currentToken;
    }
    
    return await _fetchToken();
  }

  // =============== USER PROFILE ===============
  Future<Map<String, dynamic>?> getUserProfile({required int userId}) async {
    try {
      final response = await post('/user_profile', body: {
        'action': 'get_info',
        'user_id': userId,
      });
      if (response != null) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['success'] == true) return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // =============== AFFILIATE REGISTRATION ===============
  Future<Map<String, dynamic>?> registerAffiliate({required int userId}) async {
    try {
      final response = await post('/user_profile', body: {
        'action': 'register_affiliate',
        'user_id': userId,
      });
      if (response != null) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // =============== ORDERS & NOTIFICATIONS ===============
  Future<Map<String, dynamic>?> getOrdersList({
    required int userId,
    int page = 1,
    int limit = 20,
    int? status,
  }) async {
    try {
      final query = {
        'user_id': userId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status.toString(),
      };
      final uri = Uri.parse('$baseUrl/orders_list').replace(queryParameters: query);
      final token = await getValidToken();
      final response = await http.get(uri, headers: {
        'Authorization': token != null ? 'Bearer $token' : '',
      }).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOrderDetail({
    required int userId,
    int? orderId,
    String? maDon,
  }) async {
    try {
      final query = {
        'user_id': userId.toString(),
        if (orderId != null) 'order_id': orderId.toString(),
        if (maDon != null) 'ma_don': maDon,
      };
      final uri = Uri.parse('$baseUrl/order_detail').replace(queryParameters: query);
      final token = await getValidToken();
      final response = await http.get(uri, headers: {
        'Authorization': token != null ? 'Bearer $token' : '',
      }).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getNotifications({
    required int userId,
    int page = 1,
    int limit = 20,
    String? type,
    bool unreadOnly = false,
  }) async {
    try {
      final query = {
        'user_id': userId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (type != null) 'type': type,
        if (unreadOnly) 'unread_only': 'true',
      };
      final uri = Uri.parse('$baseUrl/notifications_mobile').replace(queryParameters: query);
      final token = await getValidToken();
      final response = await http.get(uri, headers: {
        'Authorization': token != null ? 'Bearer $token' : '',
      }).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> markNotificationRead({
    required int userId,
    required int notificationId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/notification_mark_read_mobile');
      final token = await getValidToken();
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields['user_id'] = userId.toString();
      request.fields['notification_id'] = notificationId.toString();
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllNotificationsRead({
    required int userId,
    String? type,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/notification_mark_read_mobile');
      final token = await getValidToken();
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields['user_id'] = userId.toString();
      request.fields['mark_all'] = 'true';
      if (type != null) request.fields['type'] = type;
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Xóa tất cả thông báo
  Future<bool> deleteAllNotifications({required int userId}) async {
    try {
      final uri = Uri.parse('$baseUrl/notification_delete_mobile');
      final token = await getValidToken();
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields['user_id'] = userId.toString();
      request.fields['delete_all'] = 'true';
      
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Xóa thông báo cụ thể
  Future<bool> deleteNotification({required int userId, required int notificationId}) async {
    try {
      final uri = Uri.parse('$baseUrl/notification_delete_mobile');
      final token = await getValidToken();
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields['user_id'] = userId.toString();
      request.fields['notification_id'] = notificationId.toString();
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Lấy số lượng thông báo chưa đọc
  Future<int> getUnreadNotificationCount({required int userId}) async {
    try {
      final uri = Uri.parse('$baseUrl/notifications_mobile').replace(
        queryParameters: {
          'user_id': userId.toString(),
          'unread_only': 'true',
          'limit': '1',
        },
      );
      final token = await getValidToken();
      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['data']['unread_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // =============== ORDER ACTIONS ===============
  Future<Map<String, dynamic>?> createOrder({
    required int userId,
    required String hoTen,
    required String dienThoai,
    String? email,
    required String diaChi,
    required int tinh,
    required int huyen,
    int? xa,
    required List<Map<String, dynamic>> sanpham,
    String thanhtoan = 'COD',
    String? ghiChu,
    String? coupon,
    int? giam,
    int? voucherTmdt,
    int? phiShip,
    int? shipSupport,
    String? shippingProvider,
    String? utmSource,
    String? utmCampaign,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/create_order');
      final token = await getValidToken();
      final req = http.MultipartRequest('POST', uri);
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields['user_id'] = userId.toString();
      req.fields['ho_ten'] = hoTen;
      req.fields['dien_thoai'] = dienThoai;
      if (email != null) req.fields['email'] = email;
      req.fields['dia_chi'] = diaChi;
      req.fields['tinh'] = tinh.toString();
      req.fields['huyen'] = huyen.toString();
      if (xa != null) req.fields['xa'] = xa.toString();
      req.fields['sanpham'] = jsonEncode(sanpham);
      req.fields['thanhtoan'] = thanhtoan;
      if (ghiChu != null) req.fields['ghi_chu'] = ghiChu;
      if (coupon != null) req.fields['coupon'] = coupon;
      if (giam != null) req.fields['giam'] = giam.toString();
      if (voucherTmdt != null) req.fields['voucher_tmdt'] = voucherTmdt.toString();
      if (phiShip != null) req.fields['phi_ship'] = phiShip.toString();
      if (shipSupport != null) req.fields['ship_support'] = shipSupport.toString();
      if (shippingProvider != null) req.fields['shipping_provider'] = shippingProvider;
      if (utmSource != null) req.fields['utm_source'] = utmSource;
      if (utmCampaign != null) req.fields['utm_campaign'] = utmCampaign;
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {
        'success': false,
        'message': 'HTTP ${res.statusCode}',
        'raw': res.body,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> orderCancelRequest({
    required int userId,
    int? orderId,
    String? maDon,
    String? reason,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/order_cancel_request');
      final token = await getValidToken();
      final req = http.MultipartRequest('POST', uri);
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields['user_id'] = userId.toString();
      if (orderId != null) req.fields['order_id'] = orderId.toString();
      if (maDon != null) req.fields['ma_don'] = maDon;
      if (reason != null) req.fields['reason'] = reason;
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateOrderAddress({
    required int userId,
    int? orderId,
    String? maDon,
    required String hoTen,
    String? email,
    required String dienThoai,
    required String diaChi,
    required int tinh,
    required int huyen,
    required int xa,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/order_management');
      final token = await getValidToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      
      final body = {
        'action': 'update_address',
        'user_id': userId,
        if (orderId != null) 'order_id': orderId,
        if (maDon != null) 'ma_don': maDon,
        'ho_ten': hoTen,
        if (email != null) 'email': email,
        'dien_thoai': dienThoai,
        'dia_chi': diaChi,
        'tinh': tinh,
        'huyen': huyen,
        'xa': xa,
      };
      
      final response = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // =============== PRODUCT REVIEWS ===============
  Future<Map<String, dynamic>?> submitProductReview({
    required int userId,
    required int productId,
    required int shopId,
    required String content,
    required int rating,
    int? variantId,
    int? orderId,
    List<String>? images, // List of base64 strings or file paths
    bool? matchesDescription,
    bool? isSatisfied,
    int? deliveryRating, // Đánh giá tốc độ giao hàng (1-5)
    int? shopRating, // Đánh giá shop (1-5)
    String? willBuyAgain, // 'yes', 'no', 'maybe'
  }) async {
    try {
      // API POST để submit review
      final uri = Uri.parse('$baseUrl/product_reviews');
      final token = await getValidToken();
      
      // Build request body
      final body = <String, dynamic>{
        'user_id': userId,
        'product_id': productId,
        'shop_id': shopId,
        'content': content,
        'rating': rating,
      };
      
      if (variantId != null && variantId > 0) {
        body['variant_id'] = variantId;
      }
      if (orderId != null && orderId > 0) {
        body['order_id'] = orderId;
      }
      if (matchesDescription != null) {
        body['matches_description'] = matchesDescription ? 1 : 0;
      }
      if (isSatisfied != null) {
        body['is_satisfied'] = isSatisfied ? 1 : 0;
      }
      if (deliveryRating != null && deliveryRating >= 1 && deliveryRating <= 5) {
        body['delivery_rating'] = deliveryRating;
      }
      if (shopRating != null && shopRating >= 1 && shopRating <= 5) {
        body['shop_rating'] = shopRating;
      }
      if (willBuyAgain != null && ['yes', 'no', 'maybe'].contains(willBuyAgain)) {
        body['will_buy_again'] = willBuyAgain;
      }
      
      // Handle images - support both base64 and file uploads
      if (images != null && images.isNotEmpty) {
        final imageList = <String>[];
        for (var img in images) {
          if (img.startsWith('data:image/')) {
            // Base64 image
            imageList.add(img);
          } else if (img.startsWith('/uploads/') || img.startsWith('http')) {
            // Already uploaded URL
            imageList.add(img);
          }
        }
        if (imageList.isNotEmpty) {
          body['images'] = imageList;
        }
      }
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(requestTimeout);
      
      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return data;
        } catch (e) {
          return {
            'success': false,
            'message': 'Lỗi parse JSON: $e',
            'raw_response': res.body,
          };
        }
      } else {
        // Try to parse error response
        try {
          final errorData = jsonDecode(res.body) as Map<String, dynamic>;
          return errorData;
        } catch (e) {
          return {
            'success': false,
            'message': 'HTTP ${res.statusCode}',
            'raw_response': res.body,
          };
        }
      }
    } catch (e, stackTrace) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>?> getReviewHistory({
    required int userId,
    int page = 1,
    int limit = 20,
    String? status, // 'all', 'reviewed', 'pending'
  }) async {
    try {
      final query = {
        'user_id': userId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
      };
      final uri = Uri.parse('$baseUrl/product_reviews').replace(queryParameters: query);
      final token = await getValidToken();
      final response = await http.get(uri, headers: {
        'Authorization': token != null ? 'Bearer $token' : '',
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkProductReviewStatus({
    required int userId,
    required int orderId,
    required int productId,
    int? variantId,
  }) async {
    try {
      // Sử dụng product_reviews.php để check xem đã có review chưa
      final query = {
        'product_id': productId.toString(),
        'page': '1',
        'limit': '1',
        if (variantId != null && variantId > 0) 'variant_id': variantId.toString(),
      };
      final uri = Uri.parse('$baseUrl/product_reviews').replace(queryParameters: query);
      final token = await getValidToken();
      final response = await http.get(uri, headers: {
        'Authorization': token != null ? 'Bearer $token' : '',
      }).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final reviews = (data['data']?['reviews'] as List?) ?? [];
          // Check xem có review nào của user này với order_id này không
          final userReview = reviews.firstWhere(
            (r) => r['user_id'] == userId && r['order_id'] == orderId,
            orElse: () => null,
          );
          return {
            'success': true,
            'has_review': userReview != null,
            'review': userReview,
          };
        }
      }
      return {'success': false, 'has_review': false};
    } catch (e) {
      return {'success': false, 'has_review': false};
    }
  }

  // Lấy danh sách đánh giá của sản phẩm
  Future<Map<String, dynamic>?> getProductReviews({
    required int productId,
    int page = 1,
    int limit = 20,
    int rating = 0,
    int hasImages = 0,
    String isSatisfied = '',
    String matchesDescription = '',
    String sort = 'latest',
    int? variantId,
  }) async {
    try {
      final query = {
        'product_id': productId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
        if (rating > 0) 'rating': rating.toString(),
        if (hasImages > 0) 'has_images': hasImages.toString(),
        if (isSatisfied.isNotEmpty) 'is_satisfied': isSatisfied,
        if (matchesDescription.isNotEmpty) 'matches_description': matchesDescription,
        if (variantId != null && variantId > 0) 'variant_id': variantId.toString(),
      };
      final uri = Uri.parse('$baseUrl/product_reviews').replace(queryParameters: query);
      final response = await http.get(uri).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Lấy thống kê đánh giá sản phẩm
  Future<Map<String, dynamic>?> getProductRatingStats({
    required int productId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/product_rating_stats').replace(queryParameters: {
        'product_id': productId.toString(),
      });
      final response = await http.get(uri).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Cập nhật đánh giá
  Future<Map<String, dynamic>?> updateProductReview({
    required int commentId,
    required int userId,
    String? content,
    int? rating,
    List<String>? images,
    int? deliveryRating,
    int? shopRating,
    bool? matchesDescription,
    bool? isSatisfied,
    String? willBuyAgain,
  }) async {
    try {
      final token = await getValidToken();
      final uri = Uri.parse('$baseUrl/product_reviews');
      
      final body = <String, dynamic>{
        'comment_id': commentId,
        'user_id': userId,
      };
      if (content != null) body['content'] = content;
      if (rating != null) body['rating'] = rating;
      if (images != null) body['images'] = images;
      if (deliveryRating != null) body['delivery_rating'] = deliveryRating;
      if (shopRating != null) body['shop_rating'] = shopRating;
      if (matchesDescription != null) body['matches_description'] = matchesDescription ? 1 : 0;
      if (isSatisfied != null) body['is_satisfied'] = isSatisfied ? 1 : 0;
      if (willBuyAgain != null) body['will_buy_again'] = willBuyAgain;

 

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(requestTimeout);

 

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          return {
            'success': false,
            'message': 'Lỗi HTTP ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
      };
    }
  }

  // Xóa đánh giá
  Future<Map<String, dynamic>?> deleteProductReview({
    required int commentId,
  }) async {
    try {
      final token = await getValidToken();
      final uri = Uri.parse('https://api.socdo.vn/home/themes/socdo/action/process/product_review_delete.php').replace(queryParameters: {
        'comment_id': commentId.toString(),
      });

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': token != null ? 'Bearer $token' : '',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Like/Dislike đánh giá
  Future<Map<String, dynamic>?> likeProductReview({
    required int commentId,
    required String action, // 'like', 'dislike', 'unlike', 'undislike'
  }) async {
    try {
      final token = await getValidToken();
      final uri = Uri.parse('https://api.socdo.vn/home/themes/socdo/action/process/product_review_like.php');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
        body: jsonEncode({
          'comment_id': commentId,
          'action': action,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<bool> updateUserProfile({
    required int userId,
    String? name,
    String? email,
    String? mobile,
    String? ngaysinh,
    String? gioiTinh,
    String? diaChi,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'action': 'update_info',
        'user_id': userId,
      };
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (mobile != null) body['mobile'] = mobile;
      if (ngaysinh != null) body['ngaysinh'] = ngaysinh;
      if (gioiTinh != null) body['gioi_tinh'] = gioiTinh;
      if (diaChi != null) body['dia_chi'] = diaChi;

      final response = await post('/user_profile', body: body);
      if (response != null) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadAvatar({
    required int userId,
    required Uint8List bytes,
    String filename = 'avatar.jpg',
    String contentType = 'image/jpeg',
  }) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return null;
      }

      final uri = Uri.parse('$baseUrl/user_profile');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['action'] = 'upload_avatar';
      request.fields['user_id'] = userId.toString();
      
      request.files.add(http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final avatarPath = (data['data']?['avatar'] as String?) ?? '';
          return avatarPath;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> setDefaultAddress({required int userId, required int addressId}) async {
    try {
      final response = await post('/user_profile', body: {
        'action': 'address_set_default',
        'user_id': userId,
        'address_id': addressId,
      });
      if (response != null) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Shipping quote via server wrapper that uses existing carrier classes
  // ⚠️ Lưu ý: Nên sử dụng ShippingQuoteService thay vì gọi trực tiếp method này
  // ShippingQuoteService có retry, timeout, fallback, và cache
  Future<Map<String, dynamic>?> getShippingQuote({
    required int userId,
    required List<Map<String, dynamic>> items, // [{product_id, quantity}]
  }) async {
    try {
      final reqBody = {
        'user_id': userId,
        'items': items,
      };
      final response = await post('/shipping_quote', body: reqBody);
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final Map<String, dynamic> d = Map<String, dynamic>.from(data['data']);
          // Chuẩn hoá trả về đơn giản cho UI: fee/provider/eta_text
          final Map<String, dynamic> bestSimple = Map<String, dynamic>.from(
              (d['best_simple'] ?? const {'fee': 0, 'provider': '', 'eta_text': ''}) as Map
          );
          return {
            'success': true,
            'fee': bestSimple['fee'] ?? 0,
            'provider': bestSimple['provider']?.toString() ?? '',
            'eta_text': bestSimple['eta_text']?.toString() ?? '',
            // kèm theo dữ liệu chi tiết để debug nếu cần
            'data': d, // ✅ Trả về toàn bộ data để có thể truy cập warehouse_shipping
            'quotes': d['quotes'],
            'input': d['input'],
            'best': d['best'],
            'debug': d['debug'],
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Locations API: provinces/districts/wards
  Future<List<Map<String, dynamic>>?> getProvinces({String keyword = '', int page = 1, int limit = 100}) async {
    try {
      final qp = {
        'type': 'province',
        if (keyword.isNotEmpty) 'keyword': keyword,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final uri = '/locations?${qp.entries.map((e)=>'${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      final resp = await get(uri);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) return List<Map<String,dynamic>>.from(data['data']['items']);
      }
      return [];
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>?> getDistricts({required int provinceId, String keyword = '', int page = 1, int limit = 100}) async {
    try {
      final qp = {
        'type': 'district',
        'tinh': provinceId.toString(),
        if (keyword.isNotEmpty) 'keyword': keyword,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final uri = '/locations?${qp.entries.map((e)=>'${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      final resp = await get(uri);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) return List<Map<String,dynamic>>.from(data['data']['items']);
      }
      return [];
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>?> getWards({required int provinceId, required int districtId, String keyword = '', int page = 1, int limit = 100}) async {
    try {
      final qp = {
        'type': 'ward',
        'tinh': provinceId.toString(),
        'huyen': districtId.toString(),
        if (keyword.isNotEmpty) 'keyword': keyword,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final uri = '/locations?${qp.entries.map((e)=>'${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      final resp = await get(uri);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) return List<Map<String,dynamic>>.from(data['data']['items']);
      }
      return [];
    } catch (_) { return []; }
  }
  Future<bool> addAddress({
    required int userId,
    required String hoTen,
    required String dienThoai,
    required String diaChi,
    required String tenXa,
    required String tenHuyen,
    required String tenTinh,
    required int tinh,
    required int huyen,
    required int xa,
    String? email,
    bool isDefault = false,
  }) async {
    try {
      final response = await post('/user_profile', body: {
        'action': 'address_add',
        'user_id': userId,
        'ho_ten': hoTen,
        'dien_thoai': dienThoai,
        'dia_chi': diaChi,
        'ten_xa': tenXa,
        'ten_huyen': tenHuyen,
        'ten_tinh': tenTinh,
        'tinh': tinh,
        'huyen': huyen,
        'xa': xa,
        if (email != null && email.isNotEmpty) 'email': email,
        'active': isDefault ? 1 : 0,
      });
      if (response != null) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAddress({
    required int userId,
    required int addressId,
    required String hoTen,
    required String dienThoai,
    required String diaChi,
    required String tenTinh,
    required String tenHuyen,
    required String tenXa,
    required int tinh,
    required int huyen,
    required int xa,
    String? email,
  }) async {
    try {
      final body = {
        'action': 'address_update',
        'user_id': userId,
        'address_id': addressId,
        'ho_ten': hoTen,
        'dien_thoai': dienThoai,
        'dia_chi': diaChi,
        'ten_tinh': tenTinh,
        'ten_huyen': tenHuyen,
        'ten_xa': tenXa,
        'tinh': tinh,
        'huyen': huyen,
        'xa': xa,
        if (email != null && email.isNotEmpty) 'email': email,
      };
      final response = await post('/user_profile', body: body);
      if (response != null) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAddress({
    required int userId,
    required int addressId,
  }) async {
    try {
      final response = await post('/user_profile', body: {
        'action': 'address_delete',
        'user_id': userId,
        'address_id': addressId,
      });
      if (response != null) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Thực hiện API call với token và priority queue
  Future<http.Response?> apiCall({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    int priority = RequestPriority.normal, // Thêm priority parameter
  }) async {
    final token = await getValidToken();
    if (token == null) {
      return null;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      ...?additionalHeaders,
    };

    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      
      // Wrap request trong priority queue
      return await _requestQueue.execute(
        () async {
          switch (method.toUpperCase()) {
            case 'GET':
              return await http.get(uri, headers: headers);
            case 'POST':
              return await http.post(
                uri, 
                headers: headers, 
                body: body != null ? jsonEncode(body) : null,
              );
            case 'PUT':
              return await http.put(
                uri, 
                headers: headers, 
                body: body != null ? jsonEncode(body) : null,
              );
            case 'DELETE':
              return await http.delete(uri, headers: headers);
            default:
              throw Exception('Unsupported HTTP method: $method');
          }
        },
        priority: priority,
        timeout: requestTimeout,
      );
    } on TimeoutException {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GET request
  Future<http.Response?> get(String endpoint, {Map<String, String>? headers, int priority = RequestPriority.normal}) {
    return apiCall(endpoint: endpoint, method: 'GET', additionalHeaders: headers, priority: priority);
  }

  /// POST request
  Future<http.Response?> post(String endpoint, {Map<String, dynamic>? body, Map<String, String>? headers, int priority = RequestPriority.normal}) {
    return apiCall(endpoint: endpoint, method: 'POST', body: body, additionalHeaders: headers, priority: priority);
  }

  /// PUT request
  Future<http.Response?> put(String endpoint, {Map<String, dynamic>? body, Map<String, String>? headers, int priority = RequestPriority.normal}) {
    return apiCall(endpoint: endpoint, method: 'PUT', body: body, additionalHeaders: headers, priority: priority);
  }

  /// DELETE request
  Future<http.Response?> delete(String endpoint, {Map<String, String>? headers, int priority = RequestPriority.normal}) {
    return apiCall(endpoint: endpoint, method: 'DELETE', additionalHeaders: headers, priority: priority);
  }

  /// Làm mới token (force refresh)
  Future<String?> refreshToken() async {
    await _tokenManager.clearToken();
    return await _fetchToken();
  }

  /// Xóa token (logout)
  Future<void> clearToken() async {
    await _tokenManager.clearToken();
  }

  /// Lấy danh sách sản phẩm miễn phí ship
  Future<List<FreeShipProduct>?> getFreeShipProducts() async {
    try {
      final response = await get('/products_freeship');
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          // Kiểm tra kiểu dữ liệu trả về
          final dynamic dataField = data['data'];
          
          List<dynamic> productsJson;
          if (dataField is List) {
            // Nếu data là List trực tiếp
            productsJson = dataField;
          } else if (dataField is Map) {
            // Nếu data là Map, có thể có key 'products' hoặc 'items'
            if (dataField.containsKey('products')) {
              productsJson = dataField['products'] as List<dynamic>;
            } else if (dataField.containsKey('items')) {
              productsJson = dataField['items'] as List<dynamic>;
            } else {
              // Nếu Map không có key phù hợp, thử lấy tất cả values
              productsJson = dataField.values.toList();
            }
          } else {
            return null;
          }
          
          final List<FreeShipProduct> products = productsJson
              .map((json) {
                return FreeShipProduct.fromJson(json as Map<String, dynamic>);
              })
              .toList();
          
          return products;
        } else if (data['success'] == false) {
          return _getMockFreeShipProducts();
        } else {
          return null;
        }
      } else {
        return _getMockFreeShipProducts();
      }
    } catch (e) {
      return _getMockFreeShipProducts();
    }
  }

  /// Tạo dữ liệu mẫu cho sản phẩm miễn phí ship
  List<FreeShipProduct> _getMockFreeShipProducts() {
    return [
      FreeShipProduct(
        id: 1,
        name: 'Sữa tươi TH true MILK ít đường bịch 220ml',
        image: 'lib/src/core/assets/images/product_1.png',
        price: 15000,
        oldPrice: 18000,
        rating: 4.8,
        sold: 2100,
        brand: 'TH True Milk',
        category: 'Thực phẩm',
      ),
      FreeShipProduct(
        id: 2,
        name: 'Nước lon Hydrogen Quantum Nuwa Daily chai 500ml',
        image: 'lib/src/core/assets/images/product_2.png',
        price: 25000,
        oldPrice: 30000,
        rating: 4.5,
        sold: 1500,
        brand: 'Quantum',
        category: 'Đồ uống',
      ),
      FreeShipProduct(
        id: 3,
        name: 'Quả quất túi 200gr',
        image: 'lib/src/core/assets/images/product_3.png',
        price: 12000,
        oldPrice: 15000,
        rating: 4.2,
        sold: 800,
        brand: 'Fresh',
        category: 'Trái cây',
      ),
      FreeShipProduct(
        id: 4,
        name: 'Bột canh lot Hải Châu gói 190gr',
        image: 'lib/src/core/assets/images/product_4.png',
        price: 8000,
        oldPrice: 10000,
        rating: 4.6,
        sold: 3200,
        brand: 'Hải Châu',
        category: 'Gia vị',
      ),
      FreeShipProduct(
        id: 5,
        name: 'Kem đánh răng P/S Complete 170g',
        image: 'lib/src/core/assets/images/product_5.png',
        price: 35000,
        oldPrice: 40000,
        rating: 4.7,
        sold: 1800,
        brand: 'P/S',
        category: 'Chăm sóc cá nhân',
      ),
      FreeShipProduct(
        id: 6,
        name: 'Mì tôm Hảo Hảo tôm chua cay gói 75g',
        image: 'lib/src/core/assets/images/product_6.png',
        price: 5000,
        oldPrice: 6000,
        rating: 4.3,
        sold: 5500,
        brand: 'Hảo Hảo',
        category: 'Thực phẩm',
      ),
    ];
  }

  /// Lấy danh sách voucher sàn
  Future<List<Voucher>?> getPlatformVouchers({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await get('/voucher_list?type=platform&page=$page&limit=$limit');
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseVoucherResponse(data);
      } else {
        return _getMockPlatformVouchers();
      }
    } catch (e) {
      return _getMockPlatformVouchers();
    }
  }

  /// Lấy danh sách voucher shop
  Future<List<Voucher>?> getShopVouchers({
    String? shopId,
    String? userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String endpoint = '/voucher_list?type=shop&page=$page&limit=$limit';
      
      // Bắt buộc phải có shopId
      if (shopId != null && shopId.isNotEmpty) {
        endpoint += '&shop_id=$shopId';
      } else {
        return _getMockShopVouchers();
      }
      
      // Thêm user_id nếu có (để kiểm tra usage)
      if (userId != null) {
        endpoint += '&user_id=$userId';
      } else {
        // Dùng user_id mặc định để test
        endpoint += '&user_id=1';
      }
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final vouchers = _parseVoucherResponse(data);
        
        // Nếu không có voucher từ shop đầu tiên, thử shop khác
        if (vouchers == null || vouchers.isEmpty) {
          return _getMockShopVouchers();
        }
        
        return vouchers;
      } else {
        return _getMockShopVouchers();
      }
    } catch (e) {
      return _getMockShopVouchers();
    }
  }

  /// Lấy danh sách shop có voucher
  Future<List<Map<String, dynamic>>?> getShopsWithVouchers() async {
    try {
      // Sử dụng API voucher_list để lấy tất cả voucher shop
      final response = await get('/voucher_list?type=shop&page=1&limit=100');
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final vouchersData = data['data']['vouchers'] as List?;
          
          if (vouchersData != null && vouchersData.isNotEmpty) {
            // Tạo map để group voucher theo shop
            final Map<int, Map<String, dynamic>> shopMap = {};
            
            for (final voucherJson in vouchersData) {
              final voucher = voucherJson as Map<String, dynamic>;
              final shopId = voucher['shop'];
              final shopInfo = voucher['shop_info'] as Map<String, dynamic>?;
              
              if (shopId != null) {
                final shopIdInt = int.tryParse(shopId.toString());
                if (shopIdInt != null) {
                  if (!shopMap.containsKey(shopIdInt)) {
                    shopMap[shopIdInt] = {
                      'id': shopIdInt,
                      'name': shopInfo?['name'] ?? 'Shop $shopIdInt',
                      'voucher_count': 0,
                      'avatar': shopInfo?['avatar'],
                    };
                  }
                  shopMap[shopIdInt]!['voucher_count']++;
                }
              }
            }
            
            final shops = shopMap.values.toList();
            return shops;
          }
        }
      }
      
      
      // Fallback: Thử một số shop ID phổ biến
      final List<int> commonShopIds = [23933, 11100, 31503, 31504, 31505, 31506];
      final List<Map<String, dynamic>> shops = [];
      
      for (int shopId in commonShopIds) {
        try {
          final testResponse = await get('/voucher_list?type=shop&shop_id=$shopId&limit=1');
          
          if (testResponse != null && testResponse.statusCode == 200) {
            final testData = jsonDecode(testResponse.body);
            if (testData['success'] == true && testData['data'] != null) {
              final vouchers = testData['data']['vouchers'] as List?;
              
              if (vouchers != null && vouchers.isNotEmpty) {
                final firstVoucher = vouchers.first as Map<String, dynamic>;
                final shopInfo = firstVoucher['shop_info'] as Map<String, dynamic>?;
                final shopName = shopInfo?['name'] ?? 'Shop $shopId';
                
                shops.add({
                  'id': shopId,
                  'name': shopName,
                  'voucher_count': vouchers.length,
                  'avatar': shopInfo?['avatar'],
                });
                
              }
            }
          }
        } catch (e) {
          continue;
        }
      }
      
      if (shops.isNotEmpty) {
        return shops;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Khám phá danh sách shop id từ các API sản phẩm phổ biến để hiển thị voucher theo shop
  Future<List<int>> _discoverShopIdsFromProducts() async {
    final Set<int> ids = {};
    try {
      // 1) Lấy danh mục nổi bật (featured) sau đó lấy sản phẩm theo danh mục đầu tiên
      final catsRes = await get('/category_products?type=all&page=1&limit=1');
      if (catsRes != null && catsRes.statusCode == 200) {
        // không cần parse, chỉ là warm-up endpoint
      }

      // 2) Lấy sản phẩm nổi bật (featured)
      final prodsRes = await get('/products_by_category?type=featured&page=1&limit=50');
      if (prodsRes != null && prodsRes.statusCode == 200) {
        final data = jsonDecode(prodsRes.body);
        final products = (data['data']?['products'] as List?) ?? [];
        for (final p in products) {
          final shop = p['shop'];
          if (shop is int && shop > 0) ids.add(shop);
        }
      }

      // 3) Lấy sản phẩm bán chạy (bestseller)
      final bestRes = await get('/product_suggest?type=bestseller&limit=40');
      if (bestRes != null && bestRes.statusCode == 200) {
        final data = jsonDecode(bestRes.body);
        final products = (data['data']?['products'] as List?) ?? [];
        for (final p in products) {
          final shop = p['shop'];
          if (shop is int && shop > 0) ids.add(shop);
        }
      }
    } catch (e) {
    }
    return ids.toList();
  }

  /// Lấy tất cả voucher shop từ nhiều shop
  Future<List<Voucher>?> getAllShopVouchers({
    String? userId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      // Lấy danh sách shop có voucher
      final shops = await getShopsWithVouchers();
      
      if (shops == null || shops.isEmpty) {
        return _getMockShopVouchers();
      }
      
      List<Voucher> allVouchers = [];
      
      // Lấy voucher từ từng shop
      for (var shop in shops) {
        final shopId = shop['id'].toString();
        final shopName = shop['name'] ?? 'Unknown Shop';
        
        final vouchers = await getShopVouchers(
          shopId: shopId,
          userId: userId,
          page: page,
          limit: limit,
        );
        
        if (vouchers != null && vouchers.isNotEmpty) {
          allVouchers.addAll(vouchers);
        }
      }
      
      if (allVouchers.isNotEmpty) {
        return allVouchers;
      } else {
        return _getMockShopVouchers();
      }
    } catch (e) {
      return _getMockShopVouchers();
    }
  }

  /// Parse response từ API voucher
  List<Voucher>? _parseVoucherResponse(Map<String, dynamic> data) {
    if (data['success'] == true && data['data'] != null) {
      final dynamic dataField = data['data'];
      
      List<dynamic> vouchersJson;
      if (dataField is List) {
        vouchersJson = dataField;
      } else if (dataField is Map) {
        if (dataField.containsKey('vouchers')) {
          vouchersJson = dataField['vouchers'] as List<dynamic>;
        } else if (dataField.containsKey('items')) {
          vouchersJson = dataField['items'] as List<dynamic>;
        } else {
          vouchersJson = dataField.values.toList();
        }
      } else {
        return null;
      }
      
      final List<Voucher> vouchers = vouchersJson
          .map((json) => Voucher.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return vouchers;
    } else {
      return null;
    }
  }

  /// Tạo dữ liệu mẫu cho voucher sàn
  List<Voucher> _getMockPlatformVouchers() {
    return [
      Voucher(
        id: 1,
        code: 'SOCDO50',
        title: 'Giảm 50% đơn hàng đầu tiên',
        description: 'Áp dụng cho đơn hàng đầu tiên trên Socdo',
        type: 'platform',
        discountValue: 50,
        discountType: 'percentage',
        minOrderValue: 100000,
        maxDiscountValue: 50000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
        usageLimit: 1000,
        usedCount: 250,
        terms: 'Áp dụng cho đơn hàng đầu tiên, không áp dụng với sản phẩm khuyến mãi',
      ),
      Voucher(
        id: 2,
        code: 'FREESHIP99',
        title: 'Miễn phí ship đơn từ 99K',
        description: 'Miễn phí vận chuyển cho đơn hàng từ 99.000₫',
        type: 'platform',
        discountValue: 30000,
        discountType: 'fixed',
        minOrderValue: 99000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 15)),
        isActive: true,
        usageLimit: 500,
        usedCount: 180,
        terms: 'Áp dụng cho tất cả sản phẩm, không giới hạn số lần sử dụng',
      ),
      Voucher(
        id: 3,
        code: 'WELCOME30',
        title: 'Giảm 30% cho thành viên mới',
        description: 'Ưu đãi đặc biệt cho thành viên mới',
        type: 'platform',
        discountValue: 30,
        discountType: 'percentage',
        minOrderValue: 200000,
        maxDiscountValue: 100000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        isActive: true,
        usageLimit: 200,
        usedCount: 45,
        terms: 'Chỉ áp dụng cho thành viên mới, mỗi tài khoản chỉ sử dụng 1 lần',
      ),
    ];
  }

  /// Tạo dữ liệu mẫu cho voucher shop
  List<Voucher> _getMockShopVouchers() {
    return [
      Voucher(
        id: 4,
        code: 'GERMAN20',
        title: 'Giảm 20% tại German Goods',
        description: 'Ưu đãi đặc biệt từ shop German Goods',
        type: 'shop',
        shopId: '31503',
        shopName: 'German Goods',
        shopLogo: 'lib/src/core/assets/images/shop_1.png',
        discountValue: 20,
        discountType: 'percentage',
        minOrderValue: 500000,
        maxDiscountValue: 200000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 10)),
        isActive: true,
        usageLimit: 100,
        usedCount: 25,
        terms: 'Áp dụng cho tất cả sản phẩm tại German Goods',
      ),
      Voucher(
        id: 5,
        code: 'VITAGLOW15',
        title: 'Giảm 15% tại VitaGlow',
        description: 'Chăm sóc sức khỏe với giá tốt',
        type: 'shop',
        shopId: '31504',
        shopName: 'VitaGlow',
        shopLogo: 'lib/src/core/assets/images/shop_2.png',
        discountValue: 15,
        discountType: 'percentage',
        minOrderValue: 300000,
        maxDiscountValue: 150000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        isActive: true,
        usageLimit: 50,
        usedCount: 12,
        terms: 'Áp dụng cho sản phẩm chăm sóc sức khỏe',
      ),
      Voucher(
        id: 6,
        code: 'BEAUTY100',
        title: 'Giảm 100K đơn từ 500K',
        description: 'Làm đẹp với ưu đãi hấp dẫn',
        type: 'shop',
        shopId: '31505',
        shopName: 'Beauty Store',
        shopLogo: 'lib/src/core/assets/images/shop_3.png',
        discountValue: 100000,
        discountType: 'fixed',
        minOrderValue: 500000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        isActive: true,
        usageLimit: 30,
        usedCount: 8,
        terms: 'Áp dụng cho sản phẩm làm đẹp và chăm sóc da',
      ),
    ];
  }

  /// Lấy danh sách flash sale deals
  Future<List<FlashSaleDeal>?> getFlashSaleDeals({
    String? timeSlot,
    String? status = 'active',
    String? shop,
    int page = 1,
    int limit = 50, // Tăng từ 20 lên 50
  }) async {
    try {
      String endpoint = '/flash_sale?page=$page&limit=$limit';
      
      // Thêm các tham số theo API thực tế
      if (status != null) {
        endpoint += '&status=$status';
      }
      
      if (timeSlot != null) {
        endpoint += '&timeline=$timeSlot';
      }
      
      if (shop != null) {
        endpoint += '&shop=$shop';
      }
      
   
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
       
        
        final deals = _parseFlashSaleDealsResponse(data);
        if (deals != null) {
         
          final filteredDeals = deals.where((deal) => 
            timeSlot == null || deal.timeline == timeSlot
          ).toList();
         
          return filteredDeals;
        }
        return deals;
      } else {
       
        return _getMockFlashSaleDeals(timeSlot: timeSlot);
      }
    } catch (e) {
      
      return _getMockFlashSaleDeals(timeSlot: timeSlot);
    }
  }

  /// Lấy danh sách sản phẩm flash sale (từ deals)
  Future<List<FlashSaleProduct>?> getFlashSaleProducts({
    String? timeSlot,
    String? status = 'active',
    String? shop,
    int page = 1,
    int limit = 50, // Tăng từ 20 lên 50
  }) async {
    try {
      String endpoint = '/flash_sale?page=$page&limit=$limit';
      
      // Thêm các tham số theo API thực tế
      if (status != null) {
        endpoint += '&status=$status';
      }
      
      if (timeSlot != null) {
        endpoint += '&timeline=$timeSlot';
      }
      
      if (shop != null) {
        endpoint += '&shop=$shop';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return _parseFlashSaleResponse(data);
      } else {
        return _getMockFlashSaleProducts(timeSlot: timeSlot);
      }
    } catch (e) {
      return _getMockFlashSaleProducts(timeSlot: timeSlot);
    }
  }

  /// Lấy danh sách sản phẩm gợi ý
  Future<List<ProductSuggest>?> getProductSuggests({
    int page = 1,
    int limit = 500, // Tăng từ 10 lên 50
  }) async {
    try {
      final response = await get('/product_suggest?type=home_suggest&limit=$limit');
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        
        return _parseProductSuggestResponse(data);
      } else {
        return _getMockProductSuggests();
      }
    } catch (e) {
      return _getMockProductSuggests();
    }
  }

  /// Helper method để parse int an toàn từ String hoặc int
  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  /// Parse response từ API flash sale deals
  List<FlashSaleDeal>? _parseFlashSaleDealsResponse(Map<String, dynamic> data) {
    if (data['success'] == true && data['data'] != null) {
      final dynamic dataField = data['data'];
      
      List<dynamic> dealsJson;
      if (dataField is List) {
        dealsJson = dataField;
      } else if (dataField is Map) {
        if (dataField.containsKey('deals')) {
          dealsJson = dataField['deals'] as List<dynamic>;
        } else if (dataField.containsKey('products')) {
          dealsJson = dataField['products'] as List<dynamic>;
        } else if (dataField.containsKey('items')) {
          dealsJson = dataField['items'] as List<dynamic>;
        } else {
          dealsJson = dataField.values.toList();
        }
      } else {
        return null;
      }
      
      final List<FlashSaleDeal> deals = dealsJson
          .map((json) => FlashSaleDeal.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return deals;
    } else {
      return null;
    }
  }

  /// Parse response từ API flash sale
  List<FlashSaleProduct>? _parseFlashSaleResponse(Map<String, dynamic> data) {
    if (data['success'] == true && data['data'] != null) {
      final dynamic dataField = data['data'];
      
      List<dynamic> dealsJson;
      if (dataField is List) {
        dealsJson = dataField;
      } else if (dataField is Map) {
        if (dataField.containsKey('deals')) {
          // API trả về {deals: [...]}
          dealsJson = dataField['deals'] as List<dynamic>;
        } else if (dataField.containsKey('products')) {
          dealsJson = dataField['products'] as List<dynamic>;
        } else if (dataField.containsKey('items')) {
          dealsJson = dataField['items'] as List<dynamic>;
        } else {
          dealsJson = dataField.values.toList();
        }
      } else {
        return null;
      }
      
      List<FlashSaleProduct> products = [];
      
      // Parse từng deal và lấy sản phẩm bên trong
      for (var deal in dealsJson) {
        try {
          final dealMap = deal as Map<String, dynamic>;
          
          // Lấy thông tin cơ bản từ deal với safe parsing
          final dealId = _safeParseInt(dealMap['id']) ?? 0;
          final dealTitle = dealMap['tieu_de'] as String? ?? 'Flash Sale';
          
          
          // Parse main_product để lấy danh sách ID sản phẩm
          List<String> mainProductIds = [];
          if (dealMap['main_product'] is String) {
            final mainProductStr = dealMap['main_product'] as String;
            if (mainProductStr.isNotEmpty) {
              mainProductIds = mainProductStr.split(',').map((id) => id.trim()).toList();
            }
          }
          
          // Parse sub_product safely để lấy thông tin chi tiết sản phẩm
          Map<String, dynamic>? subProducts;
          try {
            if (dealMap['sub_product'] is String) {
              // Nếu là String thì parse JSON
              final subProductStr = dealMap['sub_product'] as String;
              if (subProductStr.isNotEmpty && subProductStr != 'null') {
                subProducts = jsonDecode(subProductStr) as Map<String, dynamic>?;
              }
            } else if (dealMap['sub_product'] is Map) {
              // Nếu đã là Map thì dùng trực tiếp
              subProducts = dealMap['sub_product'] as Map<String, dynamic>?;
            }
          } catch (e) {
            subProducts = null;
          }
          
          // Parse main_products từ API response nếu có
          List<Map<String, dynamic>> mainProducts = [];
          if (dealMap['main_products'] is List) {
            mainProducts = List<Map<String, dynamic>>.from(dealMap['main_products']);
          }
          
          // Parse sub_products từ API response nếu có (để sử dụng sau này)
          // List<Map<String, dynamic>> subProductsFromApi = [];
          // if (dealMap['sub_products'] is List) {
          //   subProductsFromApi = List<Map<String, dynamic>>.from(dealMap['sub_products']);
          // }
          
          // Ưu tiên sử dụng main_products và sub_products từ API response
          if (mainProducts.isNotEmpty) {
            for (var productData in mainProducts) {
              final product = FlashSaleProduct(
                id: _safeParseInt(productData['id']) ?? 0,
                name: productData['tieu_de'] as String? ?? dealTitle,
                image: productData['image_url'] as String? ?? 
                       productData['minh_hoa'] as String? ?? 
                       'https://socdo.vn/images/no-images.jpg',
                price: _safeParseInt(productData['gia_moi']) ?? 0,
                oldPrice: _safeParseInt(productData['gia_cu']),
                stock: null, // Sẽ lấy từ sub_products
                description: productData['tieu_de'] as String? ?? '',
                brand: dealTitle,
                category: 'Flash Sale',
                startTime: dealMap['date_start'] != null ? 
                          DateTime.fromMillisecondsSinceEpoch(_safeParseInt(dealMap['date_start'])! * 1000) : 
                          DateTime.now().subtract(const Duration(hours: 1)),
                endTime: dealMap['date_end'] != null ? 
                        DateTime.fromMillisecondsSinceEpoch(_safeParseInt(dealMap['date_end'])! * 1000) : 
                        DateTime.now().add(const Duration(hours: 2)),
                isActive: dealMap['deal_status'] == 'active',
                timeSlot: dealMap['timeline'] as String? ?? '00:00',
                status: dealMap['deal_status'] as String? ?? 'active',
                rating: 4.5,
                sold: 100,
              );
              
              products.add(product);
            }
          } else if (subProducts != null && mainProductIds.isNotEmpty) {
            // Fallback: parse từ sub_product JSON và main_product IDs
            for (var productId in mainProductIds) {
              if (productId.isEmpty) continue;
              
              final productVariants = subProducts[productId] as List<dynamic>?;
              if (productVariants != null && productVariants.isNotEmpty) {
                // Lấy variant đầu tiên làm đại diện với safe parsing
                final variantMap = productVariants.first;
                if (variantMap is! Map<String, dynamic>) {
                  continue;
                }
                final variant = variantMap;
                
                // Tạo tên sản phẩm từ thông tin variant
                String productName = dealTitle;
                if (variant['color'] != null && variant['color'].toString().isNotEmpty) {
                  productName += ' - ${variant['color']}';
                }
                if (variant['size'] != null && variant['size'].toString().isNotEmpty) {
                  productName += ' (${variant['size']})';
                }
                
                final product = FlashSaleProduct(
                  id: int.tryParse(productId) ?? dealId,
                  name: productName,
                  image: 'https://socdo.vn/images/no-images.jpg',
                  price: _safeParseInt(variant['gia']) ?? 0,
                  oldPrice: _safeParseInt(variant['gia_cu']),
                  stock: _safeParseInt(variant['so_luong']),
                  description: '${variant['color'] ?? ''} ${variant['size'] ?? ''}'.trim(),
                  brand: dealTitle,
                  category: 'Flash Sale',
                  startTime: dealMap['date_start'] != null ? 
                            DateTime.fromMillisecondsSinceEpoch(_safeParseInt(dealMap['date_start'])! * 1000) : 
                            DateTime.now().subtract(const Duration(hours: 1)),
                  endTime: dealMap['date_end'] != null ? 
                          DateTime.fromMillisecondsSinceEpoch(_safeParseInt(dealMap['date_end'])! * 1000) : 
                          DateTime.now().add(const Duration(hours: 2)),
                  isActive: dealMap['deal_status'] == 'active',
                  timeSlot: dealMap['timeline'] as String? ?? '00:00',
                  status: dealMap['deal_status'] as String? ?? 'active',
                  rating: 4.5,
                  sold: 100,
                );
                
                products.add(product);
                
                // Chỉ lấy 1 variant để tránh duplicate
                break;
              }
            }
          }
          
          // Nếu vẫn không có sản phẩm nào, tạo product cơ bản
          if (products.isEmpty) {
            final product = FlashSaleProduct(
              id: dealId,
              name: dealTitle,
              image: 'https://socdo.vn/images/no-images.jpg',
              price: 0,
              oldPrice: null,
              stock: 0,
              description: 'Flash sale product',
              brand: dealTitle,
              category: 'Flash Sale',
              startTime: dealMap['date_start'] != null ? 
                        DateTime.fromMillisecondsSinceEpoch(_safeParseInt(dealMap['date_start'])! * 1000) : 
                        DateTime.now().subtract(const Duration(hours: 1)),
              endTime: dealMap['date_end'] != null ? 
                      DateTime.fromMillisecondsSinceEpoch(_safeParseInt(dealMap['date_end'])! * 1000) : 
                      DateTime.now().add(const Duration(hours: 2)),
              isActive: dealMap['deal_status'] == 'active',
              timeSlot: dealMap['timeline'] as String? ?? '00:00',
              status: dealMap['deal_status'] as String? ?? 'active',
              rating: 4.5,
              sold: 0,
            );
            products.add(product);
          }
        } catch (e) {
          continue;
        }
      }
      
      
      // Nếu không parse được sản phẩm nào, dùng mock data
      if (products.isEmpty) {
        return _getMockFlashSaleProducts(timeSlot: null);
      }
      
      return products;
    } else {
      return null;
    }
  }

  /// Parse response từ API product suggest
  List<ProductSuggest>? _parseProductSuggestResponse(Map<String, dynamic> data) {
    if (data['success'] == true && data['data'] != null) {
      final dynamic dataField = data['data'];
      
      List<dynamic> productsJson;
      if (dataField is List) {
        productsJson = dataField;
      } else if (dataField is Map) {
        if (dataField.containsKey('products')) {
          productsJson = dataField['products'] as List<dynamic>;
        } else if (dataField.containsKey('items')) {
          productsJson = dataField['items'] as List<dynamic>;
        } else {
          productsJson = dataField.values.toList();
        }
      } else {
        return null;
      }
      
      final List<ProductSuggest> products = productsJson
          .map((json) => ProductSuggest.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return products;
    } else {
      return null;
    }
  }

  /// Tạo dữ liệu mẫu cho flash sale deals
  List<FlashSaleDeal> _getMockFlashSaleDeals({String? timeSlot}) {
    final now = DateTime.now();
    final hour = now.hour;
    
    // Xác định timeline hiện tại
    String currentTimeline;
    if (hour >= 0 && hour < 9) {
      currentTimeline = '00:00';
    } else if (hour >= 9 && hour < 16) {
      currentTimeline = '09:00';
    } else {
      currentTimeline = '16:00';
    }
    
    // Sử dụng timeline được yêu cầu hoặc timeline hiện tại
    final targetTimeline = timeSlot ?? currentTimeline;
    
    final List<FlashSaleDeal> allDeals = [
      // Deals cho timeline 00:00
      FlashSaleDeal(
        id: 1,
        shop: 8185,
        title: 'Flash Sale 00:00',
        mainProduct: '81011,81013,81014',
        subProduct: '{"81011":[{"variant_id":"5474","color":"Màu đen","size":"22 x 9 x 13cm","gia_cu":"390000","gia":"269000","so_luong":"5"}]}',
        subId: '5474,5471,5468',
        dateStart: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        dateEnd: now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
        type: 'flash_sale',
        datePost: now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
        status: 2,
        timeline: '00:00',
        dateStartFormatted: '02/10/2025 09:32:00',
        dateEndFormatted: '02/11/2025 09:32:00',
        datePostFormatted: '02/10/2025 09:30:46',
        mainProducts: [
          FlashSaleProduct(
            id: 81011,
            name: 'Chảo chống dính vân đá elmich EL4711OL',
            image: 'https://socdo.vn/images/no-images.jpg',
            price: 204820,
            oldPrice: 470000,
            discount: 31,
            stock: 5,
            description: 'Màu đen - 22 x 9 x 13cm',
            brand: 'Flashsale MB',
            category: 'Flash Sale',
            startTime: now.subtract(const Duration(hours: 1)),
            endTime: now.add(const Duration(hours: 2)),
            isActive: true,
            timeSlot: '00:00',
            status: 'active',
            rating: 4.5,
            sold: 100,
          ),
        ],
        subProducts: [],
        dealStatus: 'active',
        isTimelineActive: targetTimeline == '00:00',
        timeRemaining: 7200,
        timeRemainingFormatted: '02:00:00',
        timelineInfo: {
          'current_timeline': '00:00',
          'slot_status': {
            '00:00': 'active',
            '09:00': 'upcoming',
            '16:00': 'upcoming'
          }
        },
      ),
      // Deals cho timeline 09:00 (đang diễn ra)
      FlashSaleDeal(
        id: 2,
        shop: 8185,
        title: 'Flash Sale 09:00',
        mainProduct: '81021,81024',
        subProduct: '{"81021":[{"variant_id":"5706","color":"Màu trắng","size":"21.1 x 21.1cm","gia_cu":"425000","gia":"283220","so_luong":"5"}]}',
        subId: '5706,5460',
        dateStart: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        dateEnd: now.add(const Duration(hours: 4)).millisecondsSinceEpoch ~/ 1000,
        type: 'flash_sale',
        datePost: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        status: 2,
        timeline: '09:00',
        dateStartFormatted: '02/10/2025 10:00:00',
        dateEndFormatted: '02/10/2025 13:00:00',
        datePostFormatted: '02/10/2025 08:30:00',
        mainProducts: [
          FlashSaleProduct(
            id: 81021,
            name: 'Bộ 3 đĩa tròn Elmich RoseDesign EL-0230',
            image: 'https://socdo.vn/images/no-images.jpg',
            price: 283220,
            oldPrice: 425000,
            discount: 25,
            stock: 5,
            description: 'Màu đen - cỡ lớn',
            brand: 'Flashsale Buổi Sáng',
            category: 'Flash Sale',
            startTime: now.add(const Duration(hours: 1)),
            endTime: now.add(const Duration(hours: 4)),
            isActive: true,
            timeSlot: '09:00',
            status: 'upcoming',
            rating: 4.3,
            sold: 50,
          ),
        ],
        subProducts: [],
        dealStatus: 'active',
        isTimelineActive: targetTimeline == '09:00',
        timeRemaining: 3600,
        timeRemainingFormatted: '01:00:00',
        timelineInfo: {
          'current_timeline': targetTimeline,
          'slot_status': {
            '00:00': targetTimeline == '00:00' ? 'active' : (targetTimeline == '09:00' || targetTimeline == '16:00') ? 'expired' : 'upcoming',
            '09:00': targetTimeline == '09:00' ? 'active' : (targetTimeline == '16:00') ? 'expired' : 'upcoming',
            '16:00': targetTimeline == '16:00' ? 'active' : 'upcoming'
          }
        },
      ),
      // Deals cho timeline 16:00
      FlashSaleDeal(
        id: 3,
        shop: 8185,
        title: 'Flash Sale 16:00',
        mainProduct: '81031,81034',
        subProduct: '{"81031":[{"variant_id":"5806","color":"Inox","size":"Set ống hút","gia_cu":"70000","gia":"57820","so_luong":"10"}]}',
        subId: '5806,5461',
        dateStart: now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
        dateEnd: now.add(const Duration(hours: 6)).millisecondsSinceEpoch ~/ 1000,
        type: 'flash_sale',
        datePost: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        status: 2,
        timeline: '16:00',
        dateStartFormatted: '02/10/2025 16:00:00',
        dateEndFormatted: '02/10/2025 20:00:00',
        datePostFormatted: '02/10/2025 08:30:00',
        mainProducts: [
          FlashSaleProduct(
            id: 81031,
            name: 'Set ống hút inox Elmich OH304BK kèm cọ',
            image: 'https://socdo.vn/images/no-images.jpg',
            price: 57820,
            oldPrice: 70000,
            discount: 18,
            stock: 10,
            description: 'Inox - Set ống hút',
            brand: 'Flash Sale 16:00',
            category: 'Flash Sale',
            startTime: now.add(const Duration(hours: 2)),
            endTime: now.add(const Duration(hours: 6)),
            isActive: false,
            timeSlot: '16:00',
            status: 'upcoming',
            rating: 4.8,
            sold: 88,
          ),
        ],
        subProducts: [],
        dealStatus: 'active',
        isTimelineActive: targetTimeline == '16:00',
        timeRemaining: 7200,
        timeRemainingFormatted: '02:00:00',
        timelineInfo: {
          'current_timeline': targetTimeline,
          'slot_status': {
            '00:00': targetTimeline == '00:00' ? 'active' : (targetTimeline == '09:00' || targetTimeline == '16:00') ? 'expired' : 'upcoming',
            '09:00': targetTimeline == '09:00' ? 'active' : (targetTimeline == '16:00') ? 'expired' : 'upcoming',
            '16:00': targetTimeline == '16:00' ? 'active' : 'upcoming'
          }
        },
      ),
    ];

    // Filter theo timeSlot nếu có
    if (timeSlot != null) {
      final filteredDeals = allDeals.where((deal) => deal.timeline == timeSlot).toList();
      return filteredDeals;
    }
    final currentDeals = allDeals.where((deal) => deal.timeline == currentTimeline).toList();
    return currentDeals;
  }
  List<FlashSaleProduct> _getMockFlashSaleProducts({String? timeSlot}) {
    final now = DateTime.now();
    final List<FlashSaleProduct> allProducts = [
      FlashSaleProduct(
        id: 1,
        name: 'Sữa tươi ít đường TH true MILK bịch 220ml',
        image: 'lib/src/core/assets/images/product_1.png',
        price: 15000,
        oldPrice: 18000,
        discount: 17,
        stock: 100,
        brand: 'TH True Milk',
        category: 'Thực phẩm',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        isActive: true,
        timeSlot: '06:00',
        status: 'active',
        rating: 4.8,
        sold: 2100,
      ),
      FlashSaleProduct(
        id: 2,
        name: 'Nước lon Hydrogen Quantum Nuwa Daily chai 500ml',
        image: 'lib/src/core/assets/images/product_2.png',
        price: 25000,
        oldPrice: 30000,
        discount: 17,
        stock: 50,
        brand: 'Quantum',
        category: 'Đồ uống',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now.add(const Duration(hours: 1, minutes: 30)),
        isActive: true,
        timeSlot: '12:00',
        status: 'active',
        rating: 4.5,
        sold: 1500,
      ),
      FlashSaleProduct(
        id: 3,
        name: 'Quả quất túi 200gr',
        image: 'lib/src/core/assets/images/product_3.png',
        price: 12000,
        oldPrice: 15000,
        discount: 20,
        stock: 80,
        brand: 'Fresh',
        category: 'Trái cây',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 5)),
        isActive: true,
        timeSlot: '18:00',
        status: 'upcoming',
        rating: 4.2,
        sold: 800,
      ),
      FlashSaleProduct(
        id: 4,
        name: 'Bột canh lot Hải Châu gói 190gr',
        image: 'lib/src/core/assets/images/product_4.png',
        price: 8000,
        oldPrice: 10000,
        discount: 20,
        stock: 200,
        brand: 'Hải Châu',
        category: 'Gia vị',
        startTime: now.add(const Duration(hours: 6)),
        endTime: now.add(const Duration(hours: 9)),
        isActive: true,
        timeSlot: '00:00',
        status: 'upcoming',
        rating: 4.6,
        sold: 3200,
      ),
    ];

    // Filter theo timeSlot nếu có
    if (timeSlot != null) {
      return allProducts.where((p) => p.timeSlot == timeSlot).toList();
    }

    // Trả về tất cả sản phẩm đang active hoặc upcoming
    return allProducts.where((p) => p.status == 'active' || p.status == 'upcoming').toList();
  }

  /// Tạo dữ liệu mẫu cho product suggest
  List<ProductSuggest> _getMockProductSuggests() {
    return [
      ProductSuggest(
        id: 1,
        name: 'Kem đánh răng P/S Complete 170g',
        image: 'lib/src/core/assets/images/product_5.png',
        price: 35000,
        oldPrice: 40000,
        discount: 12,
        stock: 150,
        brand: 'P/S',
        category: 'Chăm sóc cá nhân',
        rating: 4.7,
        sold: 1800,
        shopId: '31503',
        shopName: 'German Goods',
        isFreeship: true,
        isRecommended: true,
      ),
      ProductSuggest(
        id: 2,
        name: 'Mì tôm Hảo Hảo tôm chua cay gói 75g',
        image: 'lib/src/core/assets/images/product_6.png',
        price: 5000,
        oldPrice: 6000,
        discount: 17,
        stock: 500,
        brand: 'Hảo Hảo',
        category: 'Thực phẩm',
        rating: 4.3,
        sold: 5500,
        shopId: '31504',
        shopName: 'VitaGlow',
        isFreeship: false,
        isRecommended: true,
      ),
      ProductSuggest(
        id: 3,
        name: 'Nước rửa tay Lifebuoy 250ml',
        image: 'lib/src/core/assets/images/product_7.png',
        price: 28000,
        oldPrice: 32000,
        discount: 12,
        stock: 120,
        brand: 'Lifebuoy',
        category: 'Chăm sóc cá nhân',
        rating: 4.5,
        sold: 2200,
        shopId: '31505',
        shopName: 'Beauty Store',
        isFreeship: true,
        isRecommended: true,
      ),
      ProductSuggest(
        id: 4,
        name: 'Dầu gội Clear Men 400ml',
        image: 'lib/src/core/assets/images/product_8.png',
        price: 65000,
        oldPrice: 75000,
        discount: 13,
        stock: 80,
        brand: 'Clear',
        category: 'Chăm sóc tóc',
        rating: 4.4,
        sold: 1600,
        shopId: '31503',
        shopName: 'German Goods',
        isFreeship: false,
        isRecommended: true,
      ),
      ProductSuggest(
        id: 5,
        name: 'Bánh quy Oreo gói 138g',
        image: 'lib/src/core/assets/images/product_9.png',
        price: 18000,
        oldPrice: 22000,
        discount: 18,
        stock: 300,
        brand: 'Oreo',
        category: 'Bánh kẹo',
        rating: 4.6,
        sold: 4200,
        shopId: '31504',
        shopName: 'VitaGlow',
        isFreeship: true,
        isRecommended: true,
      ),
      ProductSuggest(
        id: 6,
        name: 'Nước ngọt Coca Cola chai 500ml',
        image: 'lib/src/core/assets/images/product_10.png',
        price: 15000,
        oldPrice: 18000,
        discount: 17,
        stock: 250,
        brand: 'Coca Cola',
        category: 'Đồ uống',
        rating: 4.8,
        sold: 6800,
        shopId: '31505',
        shopName: 'Beauty Store',
        isFreeship: false,
        isRecommended: true,
      ),
    ];
  }

  /// Lấy danh sách danh mục sản phẩm
  Future<List<Map<String, dynamic>>?> getCategories() async {
    try {
      final response = await get('/category_products');
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final dataField = data['data'];
          
          List<dynamic> categoriesJson;
          if (dataField is List) {
            categoriesJson = dataField;
          } else if (dataField is Map) {
            if (dataField.containsKey('categories')) {
              categoriesJson = dataField['categories'] as List<dynamic>;
            } else {
              categoriesJson = dataField.values.toList();
            }
          } else {
            return _getMockCategories();
          }
          
          final categories = List<Map<String, dynamic>>.from(categoriesJson);
          return categories;
        } else {
          return _getMockCategories();
        }
      } else {
        return _getMockCategories();
      }
    } catch (e) {
      return _getMockCategories();
    }
  }

  /// Tạo dữ liệu mẫu cho danh mục
  List<Map<String, dynamic>> _getMockCategories() {
    return [
      {
        'id': 1,
        'name': 'Điện thoại & Phụ kiện',
        'slug': 'dien-thoai-phu-kien',
        'description': 'Điện thoại, tai nghe, sạc dự phòng...',
        'image': 'lib/src/core/assets/images/category_1.png',
        'parent_id': null,
        'sort_order': 1,
        'is_active': true,
        'product_count': 1250,
      },
      {
        'id': 2,
        'name': 'Thực phẩm & Đồ uống',
        'slug': 'thuc-pham-do-uong',
        'description': 'Thực phẩm tươi sống, đồ uống, bánh kẹo...',
        'image': 'lib/src/core/assets/images/category_2.png',
        'parent_id': null,
        'sort_order': 2,
        'is_active': true,
        'product_count': 890,
      },
      {
        'id': 3,
        'name': 'Mỹ phẩm & Chăm sóc da',
        'slug': 'my-pham-cham-soc-da',
        'description': 'Mỹ phẩm, kem dưỡng da, son môi...',
        'image': 'lib/src/core/assets/images/category_3.png',
        'parent_id': null,
        'sort_order': 3,
        'is_active': true,
        'product_count': 650,
      },
      {
        'id': 4,
        'name': 'Thời trang & Phụ kiện',
        'slug': 'thoi-trang-phu-kien',
        'description': 'Quần áo, giày dép, túi xách...',
        'image': 'lib/src/core/assets/images/category_4.png',
        'parent_id': null,
        'sort_order': 4,
        'is_active': true,
        'product_count': 1100,
      },
      {
        'id': 5,
        'name': 'Gia dụng & Nội thất',
        'slug': 'gia-dung-noi-that',
        'description': 'Đồ gia dụng, nội thất, trang trí nhà...',
        'image': 'lib/src/core/assets/images/category_5.png',
        'parent_id': null,
        'sort_order': 5,
        'is_active': true,
        'product_count': 780,
      },
      {
        'id': 6,
        'name': 'Sức khỏe & Y tế',
        'slug': 'suc-khoe-y-te',
        'description': 'Thực phẩm chức năng, dụng cụ y tế...',
        'image': 'lib/src/core/assets/images/category_6.png',
        'parent_id': null,
        'sort_order': 6,
        'is_active': true,
        'product_count': 420,
      },
    ];
  }

  /// Resolve product slug thành product ID
  /// Query trực tiếp với field 'link' trong database (giống cách banner xử lý)
  Future<int?> resolveProductIdBySlug(String slug) async {
    try {
      // URL encode slug để xử lý tiếng Việt
      final encodedSlug = Uri.encodeComponent(slug);
      
      // Call API endpoint để resolve slug
      final response = await get('/resolve_product_slug?slug=$encodedSlug');
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final productId = data['data']['product_id'] as int?;
          if (productId != null && productId > 0) {
            return productId;
          }
        }
      }
      
      // Fallback: Thử search với exact match
      // (Nếu API resolve_product_slug chưa có, dùng search nhưng tìm exact match)
      return await _resolveProductIdBySlugFallback(slug);
    } catch (e) {
      print('❌ [ApiService] Error resolving slug: $e');
      // Fallback
      return await _resolveProductIdBySlugFallback(slug);
    }
  }

  /// Fallback: Resolve bằng search với exact match
  Future<int?> _resolveProductIdBySlugFallback(String slug) async {
    try {
      final searchResult = await searchProducts(
        keyword: slug,
        page: 1,
        limit: 50, // Tăng limit để có nhiều kết quả hơn
      );

      if (searchResult != null && searchResult['success'] == true) {
        final data = searchResult['data'] as Map<String, dynamic>?;
        if (data != null) {
          final products = data['products'] as List?;

          if (products != null && products.isNotEmpty) {
            // Tìm exact match với field 'link' (slug trong DB)
            final slugLower = slug.toLowerCase();

            for (var product in products) {
              final productMap = product as Map<String, dynamic>;
              final productId = productMap['id'] as int?;

              // Check field 'link' (slug trong DB) - exact match
              final productLink = productMap['link']?.toString().toLowerCase() ?? '';
              if (productLink.isNotEmpty && productLink == slugLower) {
                if (productId != null && productId > 0) {
                  return productId;
                }
              }

              // Check field 'slug' (nếu có) - exact match
              final productSlug = productMap['slug']?.toString().toLowerCase() ?? '';
              if (productSlug.isNotEmpty && productSlug == slugLower) {
                if (productId != null && productId > 0) {
                  return productId;
                }
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ [ApiService] Error in fallback resolve slug: $e');
      return null;
    }
  }

  /// Tìm kiếm sản phẩm
  Future<Map<String, dynamic>?> searchProducts({
    required String keyword,
    int page = 1,
    int limit = 50, // Tăng từ 10 lên 50
    int? userId, // Thêm userId để lưu search behavior
  }) async {
    try {
      // URL encode keyword để xử lý tiếng Việt
      final encodedKeyword = Uri.encodeComponent(keyword);
      
      // Xây dựng endpoint với userId nếu có
      String endpoint = '/search_products?keyword=$encodedKeyword&page=$page&limit=$limit';
      if (userId != null && userId > 0) {
        endpoint += '&user_id=$userId';
      }
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final products = data['data']['products'] as List?;
          final pagination = data['data']['pagination'] as Map?;
          final shops = data['data']['shops'] as List?;
          
          
          if (shops != null && shops.isNotEmpty) {
            for (var shop in shops) {
            }
          } else {
          }
          
          // Nếu API trả về products rỗng nhưng có shops, vẫn return data gốc (có shops)
          // Chỉ dùng mock data khi cả products và shops đều rỗng
          if ((products == null || products.isEmpty) && (shops == null || shops.isEmpty)) {
            return _getMockSearchResult(keyword, page, limit);
          }
          
          // Nếu có shops hoặc products, return data gốc từ API
          return data;
        } else {
          return _getMockSearchResult(keyword, page, limit);
        }
      } else {
        return _getMockSearchResult(keyword, page, limit);
      }
    } catch (e) {
      return _getMockSearchResult(keyword, page, limit);
    }
  }

  /// Tạo dữ liệu mẫu cho kết quả tìm kiếm
  Map<String, dynamic> _getMockSearchResult(String keyword, int page, int limit) {
    // Danh sách sản phẩm mẫu để tìm kiếm (bao gồm flash sale và gợi ý)
    final mockProducts = [
      // Điện thoại
      {
        'id': 1,
        'name': 'iPhone 15 Pro Max 256GB',
        'image': 'lib/src/core/assets/images/product_1.png',
        'price': 28990000,
        'old_price': 32990000,
        'discount': 12,
        'rating': 4.8,
        'sold': 1250,
        'shop_id': '31503',
        'shop_name': 'German Goods',
        'is_freeship': true,
        'category': 'Điện thoại'
      },
      {
        'id': 2,
        'name': 'Samsung Galaxy S24 Ultra 512GB',
        'image': 'lib/src/core/assets/images/product_2.png',
        'price': 25990000,
        'old_price': 28990000,
        'discount': 10,
        'rating': 4.7,
        'sold': 980,
        'shop_id': '31504',
        'shop_name': 'VitaGlow',
        'is_freeship': false,
        'category': 'Điện thoại'
      },
      {
        'id': 3,
        'name': 'Xiaomi 14 Pro 256GB',
        'image': 'lib/src/core/assets/images/product_3.png',
        'price': 18990000,
        'old_price': 21990000,
        'discount': 14,
        'rating': 4.6,
        'sold': 750,
        'shop_id': '31505',
        'shop_name': 'Beauty Store',
        'is_freeship': true,
        'category': 'Điện thoại'
      },
      
      // Sản phẩm từ Flash Sale
      {
        'id': 1001,
        'name': 'Sữa tươi ít đường TH true MILK bịch 220ml',
        'image': 'lib/src/core/assets/images/product_1.png',
        'price': 15000,
        'old_price': 18000,
        'discount': 17,
        'rating': 4.8,
        'sold': 2100,
        'shop_id': '8185',
        'shop_name': 'Flash Sale Store',
        'is_freeship': true,
        'category': 'Thực phẩm'
      },
      {
        'id': 1002,
        'name': 'Nước lon Hydrogen Quantum Nuwa Daily chai 500ml',
        'image': 'lib/src/core/assets/images/product_2.png',
        'price': 25000,
        'old_price': 30000,
        'discount': 17,
        'rating': 4.5,
        'sold': 1500,
        'shop_id': '8185',
        'shop_name': 'Flash Sale Store',
        'is_freeship': false,
        'category': 'Đồ uống'
      },
      {
        'id': 1003,
        'name': 'Quả quất túi 200gr',
        'image': 'lib/src/core/assets/images/product_3.png',
        'price': 12000,
        'old_price': 15000,
        'discount': 20,
        'rating': 4.2,
        'sold': 800,
        'shop_id': '8185',
        'shop_name': 'Flash Sale Store',
        'is_freeship': true,
        'category': 'Trái cây'
      },
      
      // Sản phẩm gợi ý
      {
        'id': 2001,
        'name': 'Kem đánh răng P/S Complete 170g',
        'image': 'lib/src/core/assets/images/product_5.png',
        'price': 35000,
        'old_price': 40000,
        'discount': 12,
        'rating': 4.7,
        'sold': 1800,
        'shop_id': '31503',
        'shop_name': 'German Goods',
        'is_freeship': true,
        'category': 'Chăm sóc cá nhân'
      },
      {
        'id': 2002,
        'name': 'Mì tôm Hảo Hảo tôm chua cay gói 75g',
        'image': 'lib/src/core/assets/images/product_6.png',
        'price': 5000,
        'old_price': 6000,
        'discount': 17,
        'rating': 4.3,
        'sold': 5500,
        'shop_id': '31504',
        'shop_name': 'VitaGlow',
        'is_freeship': false,
        'category': 'Thực phẩm'
      },
      {
        'id': 2003,
        'name': 'Nước rửa tay Lifebuoy 250ml',
        'image': 'lib/src/core/assets/images/product_7.png',
        'price': 28000,
        'old_price': 32000,
        'discount': 12,
        'rating': 4.5,
        'sold': 2200,
        'shop_id': '31505',
        'shop_name': 'Beauty Store',
        'is_freeship': true,
        'category': 'Chăm sóc cá nhân'
      },
      
      // Thêm sản phẩm khác
      {
        'id': 3001,
        'name': 'Laptop Dell Inspiron 15 3000',
        'image': 'lib/src/core/assets/images/product_8.png',
        'price': 12990000,
        'old_price': 14990000,
        'discount': 13,
        'rating': 4.4,
        'sold': 320,
        'shop_id': '31503',
        'shop_name': 'German Goods',
        'is_freeship': true,
        'category': 'Laptop'
      },
      {
        'id': 3002,
        'name': 'Tai nghe AirPods Pro 2',
        'image': 'lib/src/core/assets/images/product_9.png',
        'price': 5490000,
        'old_price': 5990000,
        'discount': 8,
        'rating': 4.9,
        'sold': 890,
        'shop_id': '31504',
        'shop_name': 'VitaGlow',
        'is_freeship': false,
        'category': 'Phụ kiện điện tử'
      },
    ];

    // Lọc sản phẩm theo từ khóa với logic tìm kiếm thông minh
    final filteredProducts = mockProducts.where((product) {
      final productName = product['name'].toString().toLowerCase();
      final productCategory = product['category'].toString().toLowerCase();
      final searchKeyword = keyword.toLowerCase().trim();
      
      if (searchKeyword.isEmpty) return false;
      
      // Tìm kiếm trong tên sản phẩm
      final matchesName = productName.contains(searchKeyword);
      
      // Tìm kiếm trong category
      final matchesCategory = productCategory.contains(searchKeyword);
      
      // Tìm kiếm từ khóa liên quan
      final relatedKeywords = _getRelatedKeywords(searchKeyword);
      final matchesRelated = relatedKeywords.any((relatedKeyword) => 
        productName.contains(relatedKeyword) || productCategory.contains(relatedKeyword));
      
      // Tìm kiếm từng từ riêng lẻ (cho trường hợp "điện thoại iphone")
      final words = searchKeyword.split(' ').where((word) => word.isNotEmpty).toList();
      final matchesWords = words.every((word) => 
        productName.contains(word) || productCategory.contains(word));
      
      final isMatch = matchesName || matchesCategory || matchesRelated || matchesWords;
      
      if (isMatch) {
      }
      
      return isMatch;
    }).toList();
    
    if (filteredProducts.isNotEmpty) {
    } else {
    }

    // Phân trang
    final startIndex = (page - 1) * limit;
    final endIndex = startIndex + limit;
    final paginatedProducts = filteredProducts.length > startIndex 
        ? filteredProducts.sublist(
            startIndex, 
            endIndex > filteredProducts.length ? filteredProducts.length : endIndex
          )
        : <Map<String, dynamic>>[];

    return {
      'success': true,
      'data': {
        'products': paginatedProducts,
        'pagination': {
          'current_page': page,
          'per_page': limit,
          'total': filteredProducts.length,
          'total_pages': (filteredProducts.length / limit).ceil(),
          'has_next': endIndex < filteredProducts.length,
          'has_prev': page > 1,
        },
        'keyword': keyword,
        'search_time': DateTime.now().toIso8601String(),
      }
    };
  }

  /// Lấy gợi ý từ khóa tìm kiếm
  Future<List<String>?> getSearchSuggestions({
    required String keyword,
    int limit = 5,
  }) async {
    try {
      if (keyword.trim().isEmpty || keyword.length < 2) {
        return [];
      }
      
      final encodedKeyword = Uri.encodeComponent(keyword);
      final response = await get('/search_suggestions?keyword=$encodedKeyword&limit=$limit');
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final suggestions = data['data']['suggestions'] as List?;
          if (suggestions != null) {
            return suggestions.cast<String>();
          }
        }
      }
      
      // Fallback to mock suggestions if API fails
      return _getMockSuggestions(keyword, limit);
    } catch (e) {
      return _getMockSuggestions(keyword, limit);
    }
  }

  /// Mock suggestions fallback
  List<String> _getMockSuggestions(String keyword, int limit) {
    final keywordLower = keyword.toLowerCase();
    
    // Mapping từ khóa gợi ý
    final Map<String, List<String>> suggestionMap = {
      'điện': ['điện thoại', 'điện gia dụng', 'điện tử', 'điện máy'],
      'điện thoại': ['điện thoại iphone', 'điện thoại samsung', 'điện thoại oppo'],
      'laptop': ['laptop gaming', 'laptop dell', 'laptop hp', 'laptop asus'],
      'tai nghe': ['tai nghe bluetooth', 'tai nghe có dây', 'airpods'],
      'sữa': ['sữa tươi', 'sữa bột', 'sữa chua', 'sữa đậu nành'],
      'mỹ phẩm': ['mỹ phẩm hàn quốc', 'kem dưỡng da', 'son môi', 'phấn nền'],
      'thực phẩm': ['thực phẩm chức năng', 'thực phẩm sạch', 'đồ ăn nhanh'],
      'quần áo': ['quần áo nam', 'quần áo nữ', 'quần áo trẻ em'],
      'giày': ['giày thể thao', 'giày cao gót', 'giày boot'],
      'dầu gội': ['dầu gội đầu', 'dầu xả', 'dầu gội trị gàu'],
      'nước giặt': ['nước giặt tide', 'nước giặt omo', 'nước xả vải'],
      'chảo': ['chảo chống dính', 'chảo inox', 'chảo gang'],
      'kem': ['kem dưỡng da', 'kem chống nắng', 'kem đánh răng'],
      'bánh': ['bánh mì', 'bánh ngọt', 'bánh kẹo'],
    };
    
    // Tìm gợi ý phù hợp
    for (var entry in suggestionMap.entries) {
      if (keywordLower.contains(entry.key) || entry.key.contains(keywordLower)) {
        return entry.value.take(limit).toList();
      }
    }
    
    // Gợi ý mặc định nếu không tìm thấy
    return [
      '$keyword nam',
      '$keyword nữ', 
      '$keyword giá rẻ',
      '$keyword chính hãng',
      '$keyword tốt nhất'
    ].take(limit).toList();
  }

  /// Helper method để tìm từ khóa liên quan
  List<String> _getRelatedKeywords(String keyword) {
    final keywordLower = keyword.toLowerCase().trim();
    
    // Mapping từ khóa liên quan
    final Map<String, List<String>> relatedKeywords = {
      'điện thoại': ['phone', 'smartphone', 'mobile', 'đt', 'điện thoại di động'],
      'laptop': ['máy tính', 'computer', 'notebook', 'pc'],
      'tai nghe': ['headphone', 'earphone', 'airpods', 'bluetooth'],
      'sữa': ['milk', 'sữa tươi', 'sữa bò'],
      'mỹ phẩm': ['cosmetics', 'beauty', 'làm đẹp', 'chăm sóc da'],
      'thực phẩm': ['food', 'đồ ăn', 'món ăn', 'thức ăn'],
      'đồ uống': ['drink', 'nước', 'beverage'],
      'quần áo': ['clothes', 'fashion', 'thời trang', 'áo', 'quần'],
      'giày': ['shoes', 'sneaker', 'boots'],
      'túi': ['bag', 'handbag', 'backpack'],
      'kem': ['cream', 'lotion'],
      'dầu gội': ['shampoo', 'hair care'],
      'bánh': ['cake', 'cookie', 'snack'],
      'kẹo': ['candy', 'sweet'],
    };
    
    // Tìm từ khóa liên quan
    for (var entry in relatedKeywords.entries) {
      if (entry.key.contains(keywordLower) || keywordLower.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return [];
  }


  // Get products by parent category - TỐI ƯU: Chỉ gọi trực tiếp parent category
  Future<Map<String, dynamic>?> getProductsByParentCategory({
    required int parentCategoryId,
    int page = 1,
    int limit = 50,
    String sort = 'newest', // 'newest', 'price_asc', 'price_desc', 'popular'
  }) async {
    try {
      // Tối ưu: Chỉ gọi trực tiếp parent category (nhanh hơn nhiều)
      // Không cần load child categories và merge (giảm từ 5-6 API calls xuống 1)
        return await getProductsByCategory(
          categoryId: parentCategoryId,
          page: page,
          limit: limit,
          sort: sort,
        );
      
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể lấy danh sách sản phẩm: ${e.toString()}',
        'data': {
          'category': {'id': parentCategoryId, 'name': 'Danh mục $parentCategoryId'},
          'products': [],
          'pagination': {
            'current_page': page,
            'total_pages': 0,
            'total_products': 0,
            'limit': limit,
            'has_next': false,
            'has_prev': false,
          },
        },
      };
    }
  }

  // Load more products from remaining categories (for pagination)
  Future<Map<String, dynamic>?> loadMoreProductsFromParentCategory({
    required int parentCategoryId,
    required List<int> alreadyLoadedCategories,
    int page = 2,
    int limit = 20,
    String sort = 'newest',
  }) async {
    try {
      
      // Get all child categories
      final categoriesResponse = await getCategoriesList(
        type: 'children',
        parentId: parentCategoryId,
        includeChildren: false,
        includeProductsCount: true,
        page: 1,
        limit: 100,
      );
      
      if (categoriesResponse == null || categoriesResponse.isEmpty) {
        return null;
      }
      
      // Get remaining categories (not already loaded)
      final remainingCategories = categoriesResponse.where((category) {
        final categoryId = category['id'] as int?;
        return categoryId != null && !alreadyLoadedCategories.contains(categoryId);
      }).toList();
      
      if (remainingCategories.isEmpty) {
        return null;
      }
      
      // Prioritize by product count
      remainingCategories.sort((a, b) {
        final countA = (a['products_count'] as int?) ?? 0;
        final countB = (b['products_count'] as int?) ?? 0;
        return countB.compareTo(countA);
      });
      
      // Take next 5 categories
      final nextCategories = remainingCategories.take(5).toList();
      final List<int> nextCategoryIds = [];
      
      for (final category in nextCategories) {
        final categoryId = category['id'] as int?;
        if (categoryId != null) {
          nextCategoryIds.add(categoryId);
        }
      }
      
      
      // Load products in parallel
      final List<Future<Map<String, dynamic>?>> futures = nextCategoryIds.map((categoryId) {
        return getProductsByCategory(
          categoryId: categoryId,
          page: 1,
          limit: 15,
          sort: sort,
        );
      }).toList();
      
      final List<Map<String, dynamic>?> responses = await Future.wait(futures);
      
      // Process responses
      final List<Map<String, dynamic>> allProducts = [];
      for (final response in responses) {
        if (response != null && response['data'] != null) {
          final products = List<Map<String, dynamic>>.from(response['data']['products'] ?? []);
          allProducts.addAll(products);
        }
      }
      
      // Remove duplicates
      final uniqueProducts = <int, Map<String, dynamic>>{};
      for (final product in allProducts) {
        final productId = product['id'] as int?;
        if (productId != null) {
          uniqueProducts[productId] = product;
        }
      }
      
      final finalProducts = uniqueProducts.values.toList();
      
      // Sort products
      switch (sort) {
        case 'price_asc':
          finalProducts.sort((a, b) {
            final priceA = (a['gia_moi'] as num?) ?? 0;
            final priceB = (b['gia_moi'] as num?) ?? 0;
            return priceA.compareTo(priceB);
          });
          break;
        case 'price_desc':
          finalProducts.sort((a, b) {
            final priceA = (a['gia_moi'] as num?) ?? 0;
            final priceB = (b['gia_moi'] as num?) ?? 0;
            return priceB.compareTo(priceA);
          });
          break;
        case 'popular':
          finalProducts.sort((a, b) {
            final soldA = (a['ban'] as num?) ?? 0;
            final soldB = (b['ban'] as num?) ?? 0;
            if (soldA != soldB) return soldB.compareTo(soldA);
            final viewA = (a['view'] as num?) ?? 0;
            final viewB = (b['view'] as num?) ?? 0;
            return viewB.compareTo(viewA);
          });
          break;
        case 'newest':
        default:
          finalProducts.sort((a, b) {
            final dateA = a['date_post'] as String? ?? '';
            final dateB = b['date_post'] as String? ?? '';
            return dateB.compareTo(dateA);
          });
          break;
      }
      
      // Apply pagination
      final startIndex = (page - 1) * limit;
      final paginatedProducts = finalProducts.skip(startIndex).take(limit).toList();
      
      
      return {
        'success': true,
        'message': 'Load thêm sản phẩm thành công',
        'data': {
          'products': paginatedProducts,
          'pagination': {
            'current_page': page,
            'has_next': paginatedProducts.length == limit,
            'has_prev': page > 1
          },
          'filters': {
            'parent_category_id': parentCategoryId,
            'sort': sort,
            'included_categories': nextCategoryIds
          }
        }
      };
      
    } catch (e) {
      return null;
    }
  }

  // Get products by category
  Future<Map<String, dynamic>?> getProductsByCategory({
    required int categoryId,
    int page = 1,
    int limit = 50, // Tăng từ 20 lên 50
    String sort = 'newest', // 'newest', 'price_asc', 'price_desc', 'popular'
  }) async {
    try {
      final response = await get('/products_by_category?category_id=$categoryId&page=$page&limit=$limit&sort=$sort');
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
       
        
        if (data['success'] == true && data['data'] != null) {
          return data;
        }
        
        return {
          'success': false,
          'message': 'Không thể lấy danh sách sản phẩm',
          'data': {
            'category': {'id': categoryId, 'name': 'Danh mục $categoryId'},
            'products': [],
            'pagination': {
              'current_page': page,
              'total_pages': 0,
              'total_products': 0,
              'limit': limit,
              'has_next': false,
              'has_prev': false,
            },
          },
        };
      } else {
        return {
          'success': false,
          'message': 'Không thể lấy danh sách sản phẩm',
          'data': {
            'category': {'id': categoryId, 'name': 'Danh mục $categoryId'},
            'products': [],
            'pagination': {
              'current_page': page,
              'total_pages': 0,
              'total_products': 0,
              'limit': limit,
              'has_next': false,
              'has_prev': false,
            },
          },
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể lấy danh sách sản phẩm: ${e.toString()}',
        'data': {
          'category': {'id': categoryId, 'name': 'Danh mục $categoryId'},
          'products': [],
          'pagination': {
            'current_page': page,
            'total_pages': 0,
            'total_products': 0,
            'limit': limit,
            'has_next': false,
            'has_prev': false,
          },
        },
      };
    }
  }

 
  // Get categories list with different types
  Future<List<Map<String, dynamic>>?> getCategoriesList({
    String type = 'all', // 'all', 'parents', 'children'
    int parentId = 0,
    bool includeChildren = true,
    bool includeProductsCount = false,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      String url = '/categories_list?type=$type&include_children=${includeChildren ? 1 : 0}&include_products_count=${includeProductsCount ? 1 : 0}&page=$page&limit=$limit';
      
      if (parentId > 0) {
        url += '&parent_id=$parentId';
      }
      
      final response = await get(url);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
       
        
        if (data['success'] == true && data['data'] != null) {
          final categories = data['data']['categories'] as List?;
          if (categories != null) {
            final result = List<Map<String, dynamic>>.from(categories);
          
            return result;
          }
        }
        
        return _getMockCategoriesList(type, parentId);
      } else {
        return _getMockCategoriesList(type, parentId);
      }
    } catch (e) {
      return _getMockCategoriesList(type, parentId);
    }
  }

  // Mock categories data with children
  List<Map<String, dynamic>> _getMockCategoriesList(String type, int parentId) {
    final allCategories = [
      {
        'id': 1,
        'cat_id': 1,
        'name': 'Thực phẩm chức năng',
        'cat_tieude': 'Thực phẩm chức năng',
        'image': '/uploads/minh-hoa/thuc-pham-chuc-nang-1739954150.png',
        'cat_minhhoa': '/uploads/minh-hoa/thuc-pham-chuc-nang-1739954150.png',
        'cat_img': '/uploads/minh-hoa/icon-thuc-pham-chuc-nang-1744641209.png',
        'cat_main': 0,
        'children_count': 8,
        'products_count': 1250,
        'children': [
          {'cat_id': 11, 'cat_tieude': 'Vitamin A', 'cat_minhhoa': '/uploads/minh-hoa/vitamin-a.png'},
          {'cat_id': 12, 'cat_tieude': 'Vitamin E', 'cat_minhhoa': '/uploads/minh-hoa/vitamin-e.png'},
          {'cat_id': 13, 'cat_tieude': 'Vitamin C', 'cat_minhhoa': '/uploads/minh-hoa/vitamin-c.png'},
          {'cat_id': 14, 'cat_tieude': 'Vitamin B', 'cat_minhhoa': '/uploads/minh-hoa/vitamin-b.png'},
          {'cat_id': 15, 'cat_tieude': 'Sắt Bổ Máu', 'cat_minhhoa': '/uploads/minh-hoa/sat-bo-mau.png'},
          {'cat_id': 16, 'cat_tieude': 'Vitamin D', 'cat_minhhoa': '/uploads/minh-hoa/vitamin-d.png'},
          {'cat_id': 17, 'cat_tieude': 'Collagen', 'cat_minhhoa': '/uploads/minh-hoa/collagen.png'},
          {'cat_id': 18, 'cat_tieude': 'Bổ mắt', 'cat_minhhoa': '/uploads/minh-hoa/bo-mat.png'},
        ]
      },
      {
        'id': 2,
        'cat_id': 2,
        'name': 'Mẹ và Bé',
        'cat_tieude': 'Mẹ và Bé',
        'image': '/uploads/minh-hoa/me-va-be-1739954150.png',
        'cat_minhhoa': '/uploads/minh-hoa/me-va-be-1739954150.png',
        'cat_img': '/uploads/minh-hoa/icon-me-va-be-1744641209.png',
        'cat_main': 0,
        'children_count': 6,
        'products_count': 890,
        'children': [
          {'cat_id': 21, 'cat_tieude': 'Sữa công thức', 'cat_minhhoa': '/uploads/minh-hoa/sua-cong-thuc.png'},
          {'cat_id': 22, 'cat_tieude': 'Tã bỉm', 'cat_minhhoa': '/uploads/minh-hoa/ta-bim.png'},
          {'cat_id': 23, 'cat_tieude': 'Đồ chơi', 'cat_minhhoa': '/uploads/minh-hoa/do-choi.png'},
          {'cat_id': 24, 'cat_tieude': 'Quần áo trẻ em', 'cat_minhhoa': '/uploads/minh-hoa/quan-ao-tre-em.png'},
          {'cat_id': 25, 'cat_tieude': 'Đồ dùng học tập', 'cat_minhhoa': '/uploads/minh-hoa/do-dung-hoc-tap.png'},
          {'cat_id': 26, 'cat_tieude': 'Chăm sóc da bé', 'cat_minhhoa': '/uploads/minh-hoa/cham-soc-da-be.png'},
        ]
      },
      {
        'id': 3,
        'cat_id': 3,
        'name': 'Mỹ phẩm',
        'cat_tieude': 'Mỹ phẩm',
        'image': '/uploads/minh-hoa/my-pham-1739954150.png',
        'cat_minhhoa': '/uploads/minh-hoa/my-pham-1739954150.png',
        'cat_img': '/uploads/minh-hoa/icon-my-pham-1744641209.png',
        'cat_main': 0,
        'children_count': 5,
        'products_count': 650,
        'children': [
          {'cat_id': 31, 'cat_tieude': 'Chăm sóc da mặt', 'cat_minhhoa': '/uploads/minh-hoa/cham-soc-da-mat.png'},
          {'cat_id': 32, 'cat_tieude': 'Trang điểm', 'cat_minhhoa': '/uploads/minh-hoa/trang-diem.png'},
          {'cat_id': 33, 'cat_tieude': 'Nước hoa', 'cat_minhhoa': '/uploads/minh-hoa/nuoc-hoa.png'},
          {'cat_id': 34, 'cat_tieude': 'Chăm sóc tóc', 'cat_minhhoa': '/uploads/minh-hoa/cham-soc-toc.png'},
          {'cat_id': 35, 'cat_tieude': 'Son môi', 'cat_minhhoa': '/uploads/minh-hoa/son-moi.png'},
        ]
      },
      {
        'cat_id': 4,
        'cat_tieude': 'Thời trang',
        'cat_minhhoa': '/uploads/minh-hoa/thoi-trang-1739954150.png',
        'cat_img': '/uploads/minh-hoa/icon-thoi-trang-1744641209.png',
        'cat_main': 0,
        'children_count': 7,
        'products_count': 720,
        'children': [
          {'cat_id': 41, 'cat_tieude': 'Áo thun', 'cat_minhhoa': '/uploads/minh-hoa/ao-thun.png'},
          {'cat_id': 42, 'cat_tieude': 'Quần jean', 'cat_minhhoa': '/uploads/minh-hoa/quan-jean.png'},
          {'cat_id': 43, 'cat_tieude': 'Váy đầm', 'cat_minhhoa': '/uploads/minh-hoa/vay-dam.png'},
          {'cat_id': 44, 'cat_tieude': 'Giày dép', 'cat_minhhoa': '/uploads/minh-hoa/giay-dep.png'},
          {'cat_id': 45, 'cat_tieude': 'Túi xách', 'cat_minhhoa': '/uploads/minh-hoa/tui-xach.png'},
          {'cat_id': 46, 'cat_tieude': 'Phụ kiện', 'cat_minhhoa': '/uploads/minh-hoa/phu-kien.png'},
          {'cat_id': 47, 'cat_tieude': 'Đồ lót', 'cat_minhhoa': '/uploads/minh-hoa/do-lot.png'},
        ]
      },
      {
        'cat_id': 5,
        'cat_tieude': 'Đồ gia dụng nhà bếp',
        'cat_minhhoa': '/uploads/minh-hoa/do-gia-dung-1739954150.png',
        'cat_img': '/uploads/minh-hoa/icon-do-gia-dung-1744641209.png',
        'cat_main': 0,
        'children_count': 6,
        'products_count': 580,
        'children': [
          {'cat_id': 51, 'cat_tieude': 'Bếp gas', 'cat_minhhoa': '/uploads/minh-hoa/bep-gas.png'},
          {'cat_id': 52, 'cat_tieude': 'Nồi chảo', 'cat_minhhoa': '/uploads/minh-hoa/doi-chao.png'},
          {'cat_id': 53, 'cat_tieude': 'Máy xay', 'cat_minhhoa': '/uploads/minh-hoa/may-xay.png'},
          {'cat_id': 54, 'cat_tieude': 'Tủ lạnh', 'cat_minhhoa': '/uploads/minh-hoa/tu-lanh.png'},
          {'cat_id': 55, 'cat_tieude': 'Máy giặt', 'cat_minhhoa': '/uploads/minh-hoa/may-giat.png'},
          {'cat_id': 56, 'cat_tieude': 'Đồ dùng bếp', 'cat_minhhoa': '/uploads/minh-hoa/do-dung-bep.png'},
        ]
      },
      {
        'cat_id': 6,
        'cat_tieude': 'Thiết bị chăm sóc sức khoẻ',
        'cat_minhhoa': '/uploads/minh-hoa/thiet-bi-suc-khoe-1739954150.png',
        'cat_img': '/uploads/minh-hoa/icon-thiet-bi-suc-khoe-1744641209.png',
        'cat_main': 0,
        'children_count': 5,
        'products_count': 420,
        'children': [
          {'cat_id': 61, 'cat_tieude': 'Máy đo huyết áp', 'cat_minhhoa': '/uploads/minh-hoa/may-do-huyet-ap.png'},
          {'cat_id': 62, 'cat_tieude': 'Nhiệt kế', 'cat_minhhoa': '/uploads/minh-hoa/nhiet-ke.png'},
          {'cat_id': 63, 'cat_tieude': 'Máy massage', 'cat_minhhoa': '/uploads/minh-hoa/may-massage.png'},
          {'cat_id': 64, 'cat_tieude': 'Thiết bị tập luyện', 'cat_minhhoa': '/uploads/minh-hoa/thiet-bi-tap-luyen.png'},
          {'cat_id': 65, 'cat_tieude': 'Dụng cụ y tế', 'cat_minhhoa': '/uploads/minh-hoa/dung-cu-y-te.png'},
        ]
      },
    ];

    if (type == 'parents') {
      return allCategories;
    } else if (type == 'children' && parentId > 0) {
      final parent = allCategories.firstWhere(
        (cat) => cat['cat_id'] == parentId,
        orElse: () => {'children': <Map<String, dynamic>>[]},
      );
      final children = parent['children'] as List<dynamic>? ?? [];
      return List<Map<String, dynamic>>.from(children);
    } else {
      return allCategories;
    }
  }

  /// Lấy danh sách voucher
  Future<List<Voucher>?> getVouchers({
    String type = 'shop',
    int? shopId,
    int? userId,
    int? productId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      String endpoint = '/voucher_list?type=$type&page=$page&limit=$limit';
      
      if (shopId != null) {
        endpoint += '&shop_id=$shopId';
      }
      
      if (userId != null) {
        endpoint += '&user_id=$userId';
      }
      
      if (productId != null) {
        endpoint += '&product_id=$productId';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
    
        if (data['success'] == true && data['data'] != null) {
          final vouchersData = data['data']['vouchers'] as List?;
          if (vouchersData != null && vouchersData.isNotEmpty) {
            final vouchers = vouchersData
                .map((voucherJson) => Voucher.fromJson(voucherJson as Map<String, dynamic>))
                .toList();
            // Debug chi tiết từng voucher
            try {
              for (final v in vouchers) {
                if (v.applicableProductsDetail != null) {
                  final ids = v.applicableProductsDetail!.map((e) => e['id']).join(',');
                } else if (v.applicableProducts != null) {
                }
              }
            } catch (_) {}
            return vouchers;
          }
        } else {
        }
      } else {
      }
      
      // Fallback: trả về danh sách rỗng nếu API lỗi
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Lấy gợi ý sản phẩm
  Future<List<ProductSuggest>?> getProductSuggestions({
    String type = 'home_suggest',
    int? productId,
    int? categoryId,
    int? userId,
    int limit = 4,
    String? excludeIds,
    bool? isMember,
  }) async {
    try {
      String endpoint = '/product_suggest?type=$type&limit=$limit';
      
      if (productId != null) {
        endpoint += '&product_id=$productId';
      }
      
      if (categoryId != null) {
        endpoint += '&category_id=$categoryId';
      }
      
      if (userId != null) {
        endpoint += '&user_id=$userId';
      }
      
      if (excludeIds != null && excludeIds.isNotEmpty) {
        endpoint += '&exclude_ids=$excludeIds';
      }
      
      if (isMember != null) {
        endpoint += '&is_member=${isMember ? 1 : 0}';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
       
        if (data['success'] == true && data['data'] != null) {
          final productsData = data['data']['products'] as List?;
          if (productsData != null && productsData.isNotEmpty) {
            final products = productsData
                .map((productJson) => ProductSuggest.fromJson(productJson as Map<String, dynamic>))
                .toList();
            return products;
          }
        } else {
        }
      } else {
      }
      
      // Fallback: trả về danh sách rỗng nếu API lỗi
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Lấy danh sách category gợi ý dựa trên hành vi người dùng
  /// Nếu không có hành vi, fallback về random categories
  Future<List<Map<String, dynamic>>?> getUserCategoriesSuggestions({
    int? userId,
    int limit = 4,
  }) async {
    try {
      String endpoint = '/product_suggest?type=user_categories&limit=$limit';
      
      if (userId != null && userId > 0) {
        endpoint += '&user_id=$userId';
      }
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
       
        if (data['success'] == true && data['data'] != null) {
          final categoriesData = data['data']['categories'] as List?;
          if (categoriesData != null && categoriesData.isNotEmpty) {
            return List<Map<String, dynamic>>.from(categoriesData);
          }
        }
      }
      
      // Fallback: trả về danh sách rỗng nếu API lỗi
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Lấy chi tiết sản phẩm
  /// Lấy thông tin biến thể sản phẩm (nhẹ, chỉ cho dialog)
  Future<ProductDetail?> getProductVariants(int productId) async {
    try {
      String endpoint = '/product_variants?product_id=$productId';
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
     
        if (decoded is List) {
          if (decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
            final first = decoded.first as Map<String, dynamic>;
            return ProductDetail.fromJson(first);
          } else {
            return null;
          }
        }

        final success = decoded is Map<String, dynamic> ? (decoded['success'] == true) : false;
        final rawData = decoded is Map<String, dynamic> ? decoded['data'] : null;

        if (success && rawData != null) {
          if (rawData is List && rawData.isNotEmpty) {
            final first = rawData.first as Map<String, dynamic>;
            return ProductDetail.fromJson(first);
          } else if (rawData is Map<String, dynamic>) {
            // Map dữ liệu từ API mới sang format ProductDetail (đầy đủ thông tin)
            final productData = {
              'id': rawData['id'],
              'tieu_de': rawData['tieu_de'] ?? rawData['name'],
              'name': rawData['name'] ?? rawData['tieu_de'],
              'minh_hoa': rawData['minh_hoa'] ?? rawData['imageUrl'],
              'images': rawData['images'],
              'gia_moi': rawData['gia_moi'] ?? rawData['price'],
              'gia_cu': rawData['gia_cu'] ?? rawData['oldPrice'],
              'gia_ctv': rawData['gia_ctv'],
              'gia_drop': rawData['gia_drop'],
              'discount_percent': rawData['discount_percent'],
              'shop': rawData['shop'] ?? rawData['shop_id'],
              'shop_id': rawData['shop_id'] ?? rawData['shop'],
              'shop_info': rawData['shop_info'],
              'is_marketplace': rawData['is_marketplace'],
              'coupon_info': rawData['coupon_info'],
              'flash_sale_info': rawData['flash_sale_info'],
              'voucher_icon': rawData['voucher_icon'],
              'freeship_icon': rawData['freeship_icon'],
              'warehouse_name': rawData['warehouse_name'],
              'province_name': rawData['province_name'],
              'variants': rawData['variants'] ?? [],
            };
            return ProductDetail.fromJson(productData);
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Lấy thông tin cơ bản sản phẩm (tối ưu - chỉ basic info)
  /// Sử dụng API mới product_detail_basic.php để load nhanh hơn
  Future<ProductDetail?> getProductDetailBasic(int productId, {int? userId}) async {
    try {
      String endpoint = '/product_detail_basic?product_id=$productId';
      
      if (userId != null) {
        endpoint += '&user_id=$userId';
      }
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
     
        if (decoded is List) {
          if (decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
            final first = decoded.first as Map<String, dynamic>;
            return ProductDetail.fromJson(first);
          } else {
            return null;
          }
        }

        final success = decoded is Map<String, dynamic> ? (decoded['success'] == true) : false;
        final rawData = decoded is Map<String, dynamic> ? decoded['data'] : null;

        if (success && rawData != null) {
          if (rawData is List && rawData.isNotEmpty) {
            final first = rawData.first as Map<String, dynamic>;
            return ProductDetail.fromJson(first);
          } else if (rawData is Map<String, dynamic>) {
            return ProductDetail.fromJson(rawData);
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Lấy thông tin đầy đủ sản phẩm (API cũ - giữ nguyên để không ảnh hưởng mục khác)
  Future<ProductDetail?> getProductDetail(int productId, {int? userId, bool? isMember}) async {
    try {
      String endpoint = '/product_detail?product_id=$productId';
      
      if (userId != null) {
        endpoint += '&user_id=$userId';
      }
      
      if (isMember != null) {
        endpoint += '&is_member=${isMember ? 1 : 0}';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
     
        if (decoded is List) {
          if (decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
            final first = decoded.first as Map<String, dynamic>;
            return ProductDetail.fromJson(first);
          } else {
            return null;
          }
        }

        final success = decoded is Map<String, dynamic> ? (decoded['success'] == true) : false;
        final rawData = decoded is Map<String, dynamic> ? decoded['data'] : null;

        if (success && rawData != null) {
          if (rawData is List && rawData.isNotEmpty) {
            final first = rawData.first as Map<String, dynamic>;
            return ProductDetail.fromJson(first);
          } else if (rawData is Map<String, dynamic>) {
            return ProductDetail.fromJson(rawData);
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Lấy danh sách sản phẩm cùng shop
  Future<Map<String, dynamic>?> getProductsSameShop({
    int? productId,
    int? shopId,
    int page = 1,
    int limit = 20,
    int? categoryId,
    String sort = 'time-desc',
    int? excludeProductId,
  }) async {
    try {
      String endpoint = '/products_same_shop?page=$page&limit=$limit&sort=$sort';
      
      if (productId != null) {
        endpoint += '&product_id=$productId';
      }
      
      if (shopId != null) {
        endpoint += '&shop_id=$shopId';
      }
      
      if (categoryId != null) {
        endpoint += '&category_id=$categoryId';
      }
      
      if (excludeProductId != null) {
        endpoint += '&exclude_product_id=$excludeProductId';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
    
        if (data['success'] == true && data['data'] != null) {
          return data;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Lấy danh sách sản phẩm liên quan
  Future<List<RelatedProduct>?> getRelatedProducts({
    required int productId,
    int? shopId,
    int limit = 30, // Tăng từ 15 lên 30
    String type = 'auto', // auto, same_shop, same_category, same_brand
  }) async {
    try {
      String endpoint = '/related_products?product_id=$productId&limit=$limit&type=$type';
      
      if (shopId != null) {
        endpoint += '&shop_id=$shopId';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
     
        
        if (data['success'] == true && data['data'] != null) {
          final productsData = data['data']['products'] as List<dynamic>?;
          
          if (productsData != null) {
            final relatedProducts = productsData
                .map((product) => RelatedProduct.fromJson(product as Map<String, dynamic>))
                .toList();
            
            return relatedProducts;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
    
    return null;
  }

  /// Lấy danh sách banner
  Future<List<BannerModel>?> getBanners({
    required String position,
    int limit = 0,
    int shopId = 0,
  }) async {
    try {
      String endpoint = '/banners?position=$position';
      
      if (limit > 0) {
        endpoint += '&limit=$limit';
      }
      
      if (shopId > 0) {
        endpoint += '&shop_id=$shopId';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
     
        
        if (data['success'] == true && data['data'] != null) {
          final bannersData = data['data']['banners'] as List<dynamic>?;
          
          if (bannersData != null) {
            final banners = bannersData
                .map((banner) => BannerModel.fromJson(banner as Map<String, dynamic>))
                .toList();
            
            return banners;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
    
    return null;
  }

  /// Lấy splash screen đang active
  Future<SplashScreenModel?> getSplashScreen() async {
    try {
      const endpoint = '/splash_screen';
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          // data['data'] có thể là null nếu không có splash screen nào active
          if (data['data'] != null) {
            final splashData = data['data'] as Map<String, dynamic>;
            final splashScreen = SplashScreenModel.fromJson(splashData);
            
            return splashScreen;
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Lấy popup banner hiển thị trên app
  /// [excludeIds]: Danh sách ID của banner đã hiển thị (để luân phiên banner)
  Future<PopupBanner?> getPopupBanner({List<int>? excludeIds}) async {
    try {
      String endpoint = '/popup_banners';
      
      // Thêm tham số exclude_id nếu có (có thể là danh sách comma-separated)
      if (excludeIds != null && excludeIds.isNotEmpty) {
        final excludeIdsString = excludeIds.join(',');
        endpoint += '?exclude_id=$excludeIdsString';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final popupData = data['data'] as Map<String, dynamic>?;
          
          if (popupData != null) {
            final popupBanner = PopupBanner.fromJson(popupData);
            
            return popupBanner;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
    
    return null;
  }

  /// Tăng click_count khi user click vào popup banner
  Future<bool> incrementPopupBannerClick({required int popupId}) async {
    try {
      String endpoint = '/popup_banners';
      
      
      final response = await post(endpoint, body: {
        'popup_id': popupId,
      });
      
      if (response != null) {
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['success'] == true) {
            return true;
          } else {
            if (data['debug'] != null) {
            }
            return false;
          }
        } else {
          return false;
        }
      } else {
        return false;
      }
    } catch (e, stackTrace) {
      return false;
    }
  }

  // =============== FEATURED BRANDS ===============
  Future<List<Brand>?> getFeaturedBrands({
    int page = 1,
    int limit = 20,
    int shopId = 0,
    String sort = 'order',
    bool getAll = false,
  }) async {
    try {
      String endpoint = '/featured_brands?';
      
      if (getAll) {
        endpoint += 'all=1';
      } else {
        endpoint += 'page=$page&limit=$limit';
      }
      
      if (shopId > 0) {
        endpoint += '&shop_id=$shopId';
      }
      
      if (sort != 'order') {
        endpoint += '&sort=$sort';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final brandsData = data['data']['brands'] as List<dynamic>?;
          
          if (brandsData != null) {
            final brands = brandsData
                .map((brand) => Brand.fromJson(brand as Map<String, dynamic>))
                .toList();
            
            return brands;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
    
    return null;
  }

  // =============== BANNER PRODUCTS ===============
  /// Lấy banner và sản phẩm theo vị trí hiển thị
  /// Nếu viTriHienThi = null, trả về tất cả 3 vị trí (dau_trang, giua_trang, cuoi_trang)
  Future<Map<String, BannerProducts?>?> getBannerProducts({
    String? viTriHienThi,
  }) async {
    try {
      String endpoint = '/banner_products';
      
      if (viTriHienThi != null && viTriHienThi.isNotEmpty) {
        endpoint += '?vi_tri_hien_thi=$viTriHienThi';
      }
      
      
      final response = await get(endpoint);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final dataField = data['data'];
          
          // Nếu có vi_tri_hien_thi, trả về 1 item hoặc null
          if (viTriHienThi != null && viTriHienThi.isNotEmpty) {
            if (dataField == null) {
              return null;
            }
            try {
              final bannerProduct = BannerProducts.fromJson(dataField as Map<String, dynamic>);
              return {viTriHienThi: bannerProduct};
            } catch (e) {
              return null;
            }
          }
          
          // Nếu không có vi_tri_hien_thi, trả về theo cấu trúc 3 vị trí
          if (dataField is Map) {
            final result = <String, BannerProducts?>{};
            
            for (final position in ['dau_trang', 'giua_trang', 'cuoi_trang']) {
              final positionData = dataField[position];
              if (positionData != null) {
                result[position] = BannerProducts.fromJson(positionData as Map<String, dynamic>);
              } else {
                result[position] = null;
              }
            }
            
            return result;
          }
        } else {
          // Kiểm tra nếu message là thành công nhưng data null
          final message = data['message']?.toString() ?? '';
          if (message.contains('thành công')) {
          } else {
          }
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
    
    return null;
  }

  // =============== SHOP DETAIL ===============
  Future<ShopDetail?> getShopDetail({
    int? shopId,
    String? username,
    int includeProducts = 1,
    int includeFlashSale = 1,
    int includeVouchers = 1,
    int includeWarehouses = 1,
    int includeCategories = 1,
    int includeSuggestedProducts = 1,
    int productsLimit = 20,
  }) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return null;
      }

      final Map<String, String> queryParams = {
        'include_products': includeProducts.toString(),
        'include_flash_sale': includeFlashSale.toString(),
        'include_vouchers': includeVouchers.toString(),
        'include_warehouses': includeWarehouses.toString(),
        'include_categories': includeCategories.toString(),
        'include_suggested_products': includeSuggestedProducts.toString(),
        'products_limit': productsLimit.toString(),
      };

      if (shopId != null && shopId > 0) {
        queryParams['shop_id'] = shopId.toString();
      } else if (username != null && username.isNotEmpty) {
        queryParams['username'] = username;
      } else {
        return null;
      }

      // Thêm user_id nếu có để lấy suggested products
      // Lấy AuthService lazy để tránh circular dependency
      final user = await AuthService().getCurrentUser();
      if (user?.userId != null && user!.userId > 0) {
        queryParams['user_id'] = user.userId.toString();
      }



      final uri = Uri.parse('https://api.socdo.vn/v1/shop_detail').replace(
        queryParameters: queryParams,
      );


      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(requestTimeout);


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return ShopDetail.fromJson(data['data'] as Map<String, dynamic>);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // =============== FAVORITE PRODUCTS ===============
  
  /// Lấy danh sách sản phẩm yêu thích
  Future<Map<String, dynamic>?> getFavoriteProducts({
    required int userId,
    int page = 1,
    int limit = 50,
    bool getAll = false,
  }) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return null;
      }

      final Map<String, String> queryParams = {
        'user_id': userId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (getAll) {
        queryParams['all'] = '1';
      }

      final uri = Uri.parse('https://api.socdo.vn/v1/favorite_products').replace(
        queryParameters: queryParams,
      );


      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(requestTimeout);


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Thêm sản phẩm vào danh sách yêu thích
  Future<Map<String, dynamic>?> addFavoriteProduct({
    required int userId,
    required int productId,
  }) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return null;
      }


      final response = await http.post(
        Uri.parse('https://api.socdo.vn/v1/add_favorite'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'product_id': productId,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Xóa sản phẩm khỏi danh sách yêu thích
  Future<Map<String, dynamic>?> removeFavoriteProduct({
    required int userId,
    required int productId,
  }) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return null;
      }


      final response = await http.delete(
        Uri.parse('https://api.socdo.vn/v1/add_favorite'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'product_id': productId,
        }),
      ).timeout(requestTimeout);


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Thêm sản phẩm vào giỏ hàng (lưu cart behavior)
  Future<Map<String, dynamic>?> addToCart({
    required int userId,
    required int productId,
    int quantity = 1,
    String? variant,
  }) async {
    
    try {
      final token = await getValidToken();
      if (token == null) {
        return null;
      }
      


      final response = await post(
        '/add_to_cart',
        body: {
          'user_id': userId,
          'product_id': productId,
          'quantity': quantity,
          'variant': variant ?? '',
        },
      );

      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
        }
      } else {
      }
    } catch (e, stackTrace) {
    }
    return null;
  }

  /// Toggle favorite (thích/bỏ thích)
  Future<Map<String, dynamic>?> toggleFavoriteProduct({
    required int userId,
    required int productId,
  }) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return null;
      }


      final response = await http.put(
        Uri.parse('https://api.socdo.vn/v1/add_favorite'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'product_id': productId,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Lấy sản phẩm shop với pagination
  Future<Map<String, dynamic>?> getShopProductsPaginated({
    required int shopId,
    int page = 1,
    int limit = 50,
    String? sortBy,
    String? categoryId,
    String? searchQuery,
  }) async {
    try {
      String url = '/shop_detail?shop_id=$shopId&include_products=1&products_limit=$limit&page=$page';
      
      if (sortBy != null && sortBy.isNotEmpty) {
        url += '&sort_by=$sortBy';
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        url += '&category_id=$categoryId';
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(searchQuery)}';
      }
      
      final response = await get(url);
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data['data'] != null) {
          final shopData = data['data'];
          final products = shopData['products'] as List? ?? [];
          final shopInfo = shopData['shop_info'] as Map<String, dynamic>? ?? {};
          
          return {
            'products': products,
            'shop_info': shopInfo,
            'pagination': {
              'current_page': page,
              'per_page': limit,
              'total_products': shopInfo['total_products'] ?? products.length,
              'has_next': products.length == limit,
            }
          };
        }
        
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // =============== APP RATING & FEEDBACK ===============
  Future<Map<String, dynamic>?> submitAppRating({
    required int userId,
    required double rating,
    required String comment,
    String? deviceInfo,
    String? appVersion,
  }) async {
    try {
      final response = await post('/app_rating', body: {
        'user_id': userId,
        'rating': rating,
        'comment': comment,
        if (deviceInfo != null) 'device_info': deviceInfo,
        if (appVersion != null) 'app_version': appVersion,
      });
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> submitAppReport({
    required int userId,
    required String description,
    List<String>? imageUrls,
    String? deviceInfo,
    String? appVersion,
  }) async {
    try {
      final response = await post('/app_report', body: {
        'user_id': userId,
        'description': description,
        if (imageUrls != null && imageUrls.isNotEmpty) 'image_urls': imageUrls,
        if (deviceInfo != null) 'device_info': deviceInfo,
        if (appVersion != null) 'app_version': appVersion,
      });
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // =============== PUSH NOTIFICATIONS ===============
  
  /// Register device token (FCM) to server
  Future<bool> registerDeviceToken({
    required int userId,
    required String deviceToken,
    required String platform,
    String? deviceModel,
    String? appVersion,
  }) async {
    try {
      final response = await post('/register_device_token', body: {
        'user_id': userId,
        'device_token': deviceToken,
        'platform': platform,
        if (deviceModel != null) 'device_model': deviceModel,
        if (appVersion != null) 'app_version': appVersion,
      });

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}