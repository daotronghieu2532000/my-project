import 'dart:convert';
import 'dart:async';

/// Memory Cache Service để lưu trữ dữ liệu API trong RAM
/// Giúp giảm số lần gọi API và cải thiện trải nghiệm người dùng
class MemoryCacheService {
  static final MemoryCacheService _instance = MemoryCacheService._internal();
  factory MemoryCacheService() => _instance;
  MemoryCacheService._internal();

  // Cache storage - key: cacheKey, value: CacheItem
  final Map<String, CacheItem> _cache = {};
  
  // Default cache duration: 5 minutes
  static const Duration defaultCacheDuration = Duration(minutes: 5);
  
  // Cleanup timer để xóa cache hết hạn
  Timer? _cleanupTimer;

  /// Khởi tạo service
  void initialize() {
    // Chạy cleanup mỗi phút để xóa cache hết hạn
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupExpiredCache();
    });
    print('✅ MemoryCacheService initialized');
  }

  /// Dispose service
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
    print('🔄 MemoryCacheService disposed');
  }

  /// Lưu dữ liệu vào cache
  void set<T>(String key, T data, {Duration? duration}) {
    final cacheDuration = duration ?? defaultCacheDuration;
    final expiresAt = DateTime.now().add(cacheDuration);
    
    _cache[key] = CacheItem<T>(
      data: data,
      expiresAt: expiresAt,
      createdAt: DateTime.now(),
    );
    
    print('💾 Cached data for key: $key (expires in ${cacheDuration.inMinutes}m)');
  }

  /// Lấy dữ liệu từ cache
  T? get<T>(String key) {
    final item = _cache[key];
    
    if (item == null) {
      print('❌ Cache miss for key: $key');
      return null;
    }
    
    if (item.isExpired) {
      print('⏰ Cache expired for key: $key');
      _cache.remove(key);
      return null;
    }
    
    print('✅ Cache hit for key: $key');
    return item.data as T?;
  }

  /// Kiểm tra cache có tồn tại và chưa hết hạn không
  bool has(String key) {
    final item = _cache[key];
    if (item == null) return false;
    
    if (item.isExpired) {
      _cache.remove(key);
      return false;
    }
    
    return true;
  }

  /// Xóa cache theo key
  void remove(String key) {
    _cache.remove(key);
    print('🗑️ Removed cache for key: $key');
  }

  /// Xóa tất cả cache
  void clear() {
    _cache.clear();
    print('🧹 Cleared all cache');
  }

  /// Xóa cache hết hạn
  void _cleanupExpiredCache() {
    final expiredKeys = <String>[];
    
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      print('🧹 Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  /// Lấy thông tin cache (để debug)
  Map<String, dynamic> getCacheInfo() {
    final now = DateTime.now();
    final info = <String, dynamic>{
      'totalEntries': _cache.length,
      'expiredEntries': 0,
      'validEntries': 0,
      'entries': <String, dynamic>{},
    };
    
    for (final entry in _cache.entries) {
      final item = entry.value;
      final isExpired = item.isExpired;
      
      if (isExpired) {
        info['expiredEntries']++;
      } else {
        info['validEntries']++;
      }
      
      info['entries'][entry.key] = {
        'createdAt': item.createdAt.toIso8601String(),
        'expiresAt': item.expiresAt.toIso8601String(),
        'isExpired': isExpired,
        'timeToExpire': item.expiresAt.difference(now).inMinutes,
      };
    }
    
    return info;
  }

  /// Tạo cache key từ các tham số
  static String createKey(String baseKey, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) {
      return baseKey;
    }
    
    // Sắp xếp params để đảm bảo key nhất quán
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    final paramsString = jsonEncode(sortedParams);
    return '$baseKey:${paramsString.hashCode}';
  }
}

/// Cache item wrapper
class CacheItem<T> {
  final T data;
  final DateTime expiresAt;
  final DateTime createdAt;

  CacheItem({
    required this.data,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache keys constants
class CacheKeys {
  // Home screen cache keys
  static const String homeBanners = 'home_banners';
  static const String homeFlashSale = 'home_flash_sale';
  static const String homePartnerBanners = 'home_partner_banners';
  static const String homeSuggestions = 'home_suggestions';
  static const String homeFeaturedBrands = 'home_featured_brands';
  
  // Product cache keys
  static const String productDetail = 'product_detail';
  static const String productVariants = 'product_variants';
  static const String relatedProducts = 'related_products';
  static const String sameShopProducts = 'same_shop_products';
  
  // Shop cache keys
  static const String shopDetail = 'shop_detail';
  static const String shopProducts = 'shop_products';
  static const String shopFlashSales = 'shop_flash_sales';
  static const String shopVouchers = 'shop_vouchers';
  
  // Category cache keys
  static const String categories = 'categories';
  static const String categoryProducts = 'category_products';
  
  // User cache keys
  static const String userProfile = 'user_profile';
  static const String userAddresses = 'user_addresses';
  
        // Affiliate cache keys
        static const String affiliateDashboard = 'affiliate_dashboard';
        static const String affiliateLinks = 'affiliate_links';
        static const String affiliateProducts = 'affiliate_products';
        
        // Freeship cache keys
        static const String freeshipProducts = 'freeship_products';
        
        // Search cache keys
        static const String searchProducts = 'search_products';
        static const String searchSuggestions = 'search_suggestions';
        
        // Flash Sale cache keys
        static const String flashSaleDeals = 'flash_sale_deals';
        
        // Voucher cache keys
        static const String platformVouchers = 'platform_vouchers';
        static const String voucherShops = 'voucher_shops';
        
        // Favorite cache keys
        static const String favoriteProducts = 'favorite_products';
}
