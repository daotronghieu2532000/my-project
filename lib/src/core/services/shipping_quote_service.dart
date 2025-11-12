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
    // ✅ 1. Kiểm tra cache trước
    if (useCache) {
      final cached = await _getCachedQuote(userId, items);
      if (cached != null) {
        print('✅ [ShippingQuote] Sử dụng cache');
        return cached;
      }
    }

    // ✅ 2. Thử gọi API với retry
    Map<String, dynamic>? result;
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print('🔄 [ShippingQuote] Attempt $attempt/$_maxRetries');
        
        result = await _callApiWithTimeout(
          userId: userId,
          items: items,
        );

        if (result != null && result['success'] == true) {
          // ✅ Lưu vào cache khi thành công
          if (useCache) {
            await _saveCachedQuote(userId, items, result);
          }
          print('✅ [ShippingQuote] Thành công sau $attempt lần thử');
          return result;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('❌ [ShippingQuote] Attempt $attempt failed: $e');
        
        // Chờ trước khi retry (trừ lần cuối)
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt); // Exponential backoff
        }
      }
    }

    // ✅ 3. Nếu tất cả retry đều fail, dùng fallback
    if (enableFallback) {
      print('⚠️ [ShippingQuote] API failed, sử dụng fallback calculation');
      return _calculateFallbackQuote(userId, items, lastError);
    }

    print('❌ [ShippingQuote] Tất cả attempts đều failed và fallback bị tắt');
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
    print('🔄 [ShippingQuote] Tính toán fallback...');

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
    final etaText = 'Dự kiến từ ${_getEstimatedDeliveryDate(2)} - ${_getEstimatedDeliveryDate(4)}';

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

    print('✅ [ShippingQuote] Fallback calculated: $fallbackFee₫');
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
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(userId, items);
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null) {
        final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
        final timestamp = cached['timestamp'] as int? ?? 0;
        final expiryTime = timestamp + _cacheExpiry.inMilliseconds;

        if (DateTime.now().millisecondsSinceEpoch < expiryTime) {
          print('✅ [ShippingQuote] Cache hit');
          return cached['data'] as Map<String, dynamic>?;
        } else {
          // Cache đã hết hạn, xóa
          await prefs.remove(cacheKey);
          print('⏰ [ShippingQuote] Cache expired');
        }
      }
    } catch (e) {
      print('⚠️ [ShippingQuote] Cache read error: $e');
    }
    return null;
  }

  /// Lưu quote vào cache
  Future<void> _saveCachedQuote(
    int userId,
    List<Map<String, dynamic>> items,
    Map<String, dynamic> quote,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(userId, items);
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': quote,
      };
      await prefs.setString(cacheKey, jsonEncode(cacheData));
      print('💾 [ShippingQuote] Cached successfully');
    } catch (e) {
      print('⚠️ [ShippingQuote] Cache save error: $e');
    }
  }

  /// Tạo cache key từ userId và items
  String _generateCacheKey(int userId, List<Map<String, dynamic>> items) {
    // Sắp xếp items để đảm bảo cùng key cho cùng items
    final sortedItems = List<Map<String, dynamic>>.from(items)
      ..sort((a, b) => (a['product_id'] ?? 0).compareTo(b['product_id'] ?? 0));
    
    final itemsHash = sortedItems
        .map((i) => '${i['product_id']}_${i['quantity']}')
        .join(',');
    
    return '$_cachePrefix${userId}_$itemsHash';
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
      print('🗑️ [ShippingQuote] Cache cleared');
    } catch (e) {
      print('⚠️ [ShippingQuote] Cache clear error: $e');
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
      print('❌ [ShippingQuote] Health check failed: $e');
      return false;
    }
  }
}

