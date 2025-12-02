import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Service chuyên nghiệp để lấy shipping quote với retry, fallback, và cache
class ShippingQuoteService {
  static final ShippingQuoteService _instance = ShippingQuoteService._internal();
  factory ShippingQuoteService() => _instance;
  ShippingQuoteService._internal();

  final ApiService _api = ApiService();
  static const String _cachePrefix = 'shipping_quote_cache_';
  static const Duration _cacheExpiry = Duration(minutes: 10); // Cache 10 phút
  static const Duration _requestTimeout = Duration(seconds: 15); // Timeout 15 giây
  static const int _maxRetries = 3; // Retry tối đa 3 lần
  static const Duration _retryDelay = Duration(seconds: 1); // Delay giữa các lần retry

  /// Lấy shipping quote với retry và fallback
  Future<Map<String, dynamic>?> getShippingQuote({
    required int userId,
    required List<Map<String, dynamic>> items,
    bool useCache = true,
    bool enableFallback = true,
  }) async {
    // ✅ Lấy tinh/huyen/xa để thêm vào cache key (quan trọng: API tính phí dựa trên tinh/huyen/xa, không phải Address ID)
    // API lấy địa chỉ từ: SELECT ten_tinh, ten_huyen, ten_xa FROM dia_chi WHERE user_id='$user_id' AND active='1'
    int? tinh;
    int? huyen;
    int? xa;
    String? tenTinh;
    String? tenHuyen;
    String? tenXa;
    try {
      final api = ApiService();
      final profile = await api.getUserProfile(userId: userId);
      final addresses = (profile?['addresses'] as List?)?.cast<Map<String, dynamic>?>() ?? [];
      
      // ✅ Ưu tiên 1: Tìm địa chỉ mặc định (active = 1)
      Map<String, dynamic>? addr = addresses.firstWhere(
              (a) => (a?['active'] == 1 || a?['active'] == '1'),
        orElse: () => null,
      );
      
      // ✅ Ưu tiên 2: Nếu không có địa chỉ mặc định, dùng địa chỉ đầu tiên (hoặc mới nhất)
      // Nếu chỉ có 1 địa chỉ, tự động dùng nó để tính ship
      if (addr == null && addresses.isNotEmpty) {
        addr = addresses.firstOrNull;
        print('   - ℹ️ Không có địa chỉ mặc định, sử dụng địa chỉ đầu tiên để tính ship');
      }
      
      if (addr != null) {
        tinh = int.tryParse('${addr['tinh'] ?? 0}') ?? 0;
        huyen = int.tryParse('${addr['huyen'] ?? 0}') ?? 0;
        xa = int.tryParse('${addr['xa'] ?? 0}');
        tenTinh = addr['ten_tinh']?.toString();
        tenHuyen = addr['ten_huyen']?.toString();
        tenXa = addr['ten_xa']?.toString();
        print('   - ✅ Địa chỉ để tính ship: ${tenTinh} - ${tenHuyen} - ${tenXa}');
      } else {
        print('   - ⚠️ Không tìm thấy địa chỉ nào để tính ship');
      }
    } catch (e) {
      print('   - ⚠️ Không lấy được địa chỉ: $e');
    }
    
    // ✅ 1. Kiểm tra cache trước
    if (useCache) {
      final cached = await _getCachedQuote(userId, items, tinh, huyen, xa);
      if (cached != null) {
       
        return cached;
      } else {
        print('❌ [ShippingQuoteService.getShippingQuote] Cache không có, sẽ gọi API');
      }
    }

    // ✅ 2. Thử gọi API với retry
    Map<String, dynamic>? result;
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        
        result = await _callApiWithTimeout(
          userId: userId,
          items: items,
        );

        if (result != null && result['success'] == true) {

          if (useCache) {
            await _saveCachedQuote(userId, items, result, tinh, huyen, xa);
          }
          return result;
        } else {
          print('⚠️ [ShippingQuoteService.getShippingQuote] API call không thành công (attempt $attempt)');
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        
        // Chờ trước khi retry (trừ lần cuối)
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt); // Exponential backoff
        }
      }
    }

    // ✅ 3. Nếu tất cả retry đều fail, dùng fallback
    if (enableFallback) {
      return _calculateFallbackQuote(userId, items, lastError);
    }

    return null;
  }

  /// Gọi API với timeout
  Future<Map<String, dynamic>?> _callApiWithTimeout({
    required int userId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _api.getShippingQuote(
        userId: userId,
        items: items,
      ).timeout(
        _requestTimeout,
        onTimeout: () {
          throw TimeoutException('Shipping quote request timeout', _requestTimeout);
        },
      );
      return response;
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw Exception('API call failed: $e');
    }
  }

  /// Tính toán fallback shipping quote (ước tính đơn giản)
  Map<String, dynamic> _calculateFallbackQuote(
    int userId,
    List<Map<String, dynamic>> items,
    Exception? error,
  ) {

    // ✅ Tính tổng giá trị đơn hàng từ giá thực tế (nếu có) hoặc ước tính
    int totalValue = 0;
    int totalWeight = 0; // gram

    for (final item in items) {
      final quantity = (item['quantity'] as int?) ?? 1;
      // ✅ Ưu tiên dùng giá thực tế từ item (nếu có), nếu không thì ước tính
      final price = (item['price'] as int?) ?? 
                    (item['gia_moi'] as int?) ?? 
                    100000; // Fallback: ước tính 100k/sản phẩm
      totalValue += price * quantity;
      // Ước tính trọng lượng: mỗi sản phẩm ~500g
      totalWeight += 500 * quantity;
    }

    // ✅ Tính phí ship fallback dựa trên giá trị đơn hàng
    // Công thức đơn giản:
    // - < 500k: 30k
    // - 500k - 1M: 25k
    // - 1M - 2M: 20k
    // - > 2M: 15k
    int fallbackFee = 30000;
    if (totalValue >= 2000000) {
      fallbackFee = 15000;
    } else if (totalValue >= 1000000) {
      fallbackFee = 20000;
    } else if (totalValue >= 500000) {
      fallbackFee = 25000;
    }

    // ✅ Tính ETA fallback
    final etaText = 'dự kiến trong ${_getEstimatedDeliveryDate(2)} - ${_getEstimatedDeliveryDate(4)}';

    final fallbackQuote = {
      'success': true,
      'fee': fallbackFee,
      'provider': 'Ước tính',
      'eta_text': etaText,
      'is_fallback': true, // ✅ Đánh dấu là fallback
      'error': error?.toString(),
      'data': {
        'best_simple': {
          'fee': fallbackFee,
          'provider': 'Ước tính',
          'eta_text': etaText,
        },
        'best': {
          'fee': fallbackFee,
          'provider': 'Ước tính',
          'ship_support': 0,
        },
        'warehouse_shipping': {
          'warehouse_details': [],
        },
      },
      'quotes': [],
      'input': {
        'value': totalValue,
        'weight': totalWeight,
      },
      'debug': {
        'fallback_mode': true,
        'error': error?.toString(),
        'calculated_fee': fallbackFee,
      },
    };

    return fallbackQuote;
  }

  /// Lấy ngày giao hàng ước tính
  String _getEstimatedDeliveryDate(int daysFromNow) {
    final date = DateTime.now().add(Duration(days: daysFromNow));
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  /// Lấy quote từ cache
  Future<Map<String, dynamic>?> _getCachedQuote(
    int userId,
    List<Map<String, dynamic>> items,
    int? tinh,
    int? huyen,
    int? xa,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(userId, items, tinh, huyen, xa);
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null) {
        final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
        final timestamp = cached['timestamp'] as int? ?? 0;
        final expiryTime = timestamp + _cacheExpiry.inMilliseconds;

        if (DateTime.now().millisecondsSinceEpoch < expiryTime) {
          return cached['data'] as Map<String, dynamic>?;
        } else {
          // Cache đã hết hạn, xóa
          await prefs.remove(cacheKey);
        }
      }
    } catch (e) {
    }
    return null;
  }

  /// Lưu quote vào cache
  Future<void> _saveCachedQuote(
    int userId,
    List<Map<String, dynamic>> items,
    Map<String, dynamic> quote,
    int? tinh,
    int? huyen,
    int? xa,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(userId, items, tinh, huyen, xa);
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': quote,
      };
      await prefs.setString(cacheKey, jsonEncode(cacheData));
    } catch (e) {
    }
  }

  /// Tạo cache key từ userId, items và tinh/huyen/xa (✅ Quan trọng: API tính phí dựa trên tinh/huyen/xa)
  /// Cache key format: shipping_quote_cache_{userId}_t{tinh}_h{huyen}_x{xa}_{itemsHash}
  String _generateCacheKey(
    int userId, 
    List<Map<String, dynamic>> items, 
    int? tinh, 
    int? huyen, 
    int? xa,
  ) {
    // Sắp xếp items để đảm bảo cùng key cho cùng items
    final sortedItems = List<Map<String, dynamic>>.from(items)
      ..sort((a, b) => (a['product_id'] ?? 0).compareTo(b['product_id'] ?? 0));
    
    final itemsHash = sortedItems
        .map((i) => '${i['product_id']}_${i['quantity']}')
        .join(',');
    
    // ✅ Thêm tinh/huyen/xa vào cache key (API tính phí dựa trên đây, không phải Address ID)
    // Format: t7_h83_x1434 (tỉnh 7, huyện 83, xã 1434)
    final tinhStr = tinh != null && tinh > 0 ? 't$tinh' : 't0';
    final huyenStr = huyen != null && huyen > 0 ? 'h$huyen' : 'h0';
    final xaStr = xa != null && xa > 0 ? 'x$xa' : 'x0';
    final addressPart = '_$tinhStr\_$huyenStr\_$xaStr';
    
    final cacheKey = '$_cachePrefix${userId}$addressPart\_$itemsHash';
   
    return cacheKey;
  }

  /// Xóa cache (dùng khi cần refresh)
  Future<void> clearCache({int? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          if (userId == null || key.contains('_${userId}_')) {
            await prefs.remove(key);
          }
        }
      }
    } catch (e) {
    }
  }

  /// Kiểm tra health của shipping quote service
  Future<bool> healthCheck() async {
    try {
      // Test với một request đơn giản
      final testItems = [
        {'product_id': 1, 'quantity': 1}
      ];
      final result = await _callApiWithTimeout(
        userId: 1,
        items: testItems,
      );
      return result != null;
    } catch (e) {
      return false;
    }
  }
}

