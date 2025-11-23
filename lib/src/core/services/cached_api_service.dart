import 'dart:async';
import 'api_service.dart';
import 'affiliate_service.dart';
import 'auth_service.dart';
import 'memory_cache_service.dart';
import '../models/product_detail.dart';
import '../models/product_suggest.dart';
import '../models/voucher.dart';
import '../models/shop_detail.dart';
import '../models/banner_products.dart';

/// Enhanced API Service với Memory Cache
/// Tự động cache dữ liệu API để giảm số lần gọi và cải thiện performance
class CachedApiService {
  static final CachedApiService _instance = CachedApiService._internal();
  factory CachedApiService() => _instance;
  CachedApiService._internal();

  final ApiService _apiService = ApiService();
  final AffiliateService _affiliateService = AffiliateService();
  final AuthService _authService = AuthService();
  final MemoryCacheService _cache = MemoryCacheService();
  
  // Cache duration cho từng loại API
  static const Duration _defaultCacheDuration = Duration(minutes: 5);
  static const Duration _longCacheDuration = Duration(minutes: 30);
  static const Duration _shortCacheDuration = Duration(minutes: 2);

  /// Khởi tạo service
  void initialize() {
    _cache.initialize();
  }

  /// Dispose service
  void dispose() {
    _cache.dispose();
  }

  /// Lấy chi tiết shop với cache
  Future<ShopDetail?> getShopDetailCached({
    int? shopId,
    String? username,
    int includeProducts = 1,
    int includeFlashSale = 1,
    int includeVouchers = 1,
    int includeWarehouses = 1,
    int includeCategories = 1,
    int includeSuggestedProducts = 1,
    int productsLimit = 50, // Tăng từ 20 lên 50
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    // Nếu có suggested products, cần lấy userId để phân biệt cache theo user
    int? userId;
    if (includeSuggestedProducts == 1) {
      final user = await _authService.getCurrentUser();
      userId = user?.userId;
    }
    
    final cacheKey = MemoryCacheService.createKey(
      CacheKeys.shopDetail,
      {
        if (shopId != null) 'shopId': shopId,
        if (username != null) 'username': username,
        'p': includeProducts,
        'fs': includeFlashSale,
        'v': includeVouchers,
        'w': includeWarehouses,
        'c': includeCategories,
        'sp': includeSuggestedProducts,
        'limit': productsLimit,
        // Thêm userId vào cache key khi có suggested products để phân biệt cache theo user
        if (includeSuggestedProducts == 1 && userId != null) 'userId': userId,
      },
    );

    if (!forceRefresh && _cache.has(cacheKey)) {
      final cached = _cache.get<ShopDetail>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    try {
      final detail = await _apiService.getShopDetail(
        shopId: shopId,
        username: username,
        includeProducts: includeProducts,
        includeFlashSale: includeFlashSale,
        includeVouchers: includeVouchers,
        includeWarehouses: includeWarehouses,
        includeCategories: includeCategories,
        includeSuggestedProducts: includeSuggestedProducts,
        productsLimit: productsLimit,
      );

      if (detail != null) {
        _cache.set(cacheKey, detail, duration: cacheDuration ?? _defaultCacheDuration);
      }
      return detail;
    } catch (e) {
      final cached = _cache.get<ShopDetail>(cacheKey);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Lấy banners cho trang chủ với cache
  Future<List<Map<String, dynamic>>> getHomeBanners({
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    const cacheKey = CacheKeys.homeBanners;
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final banners = await _apiService.getBanners(
        position: 'banner_index_mobile',
        limit: 10,
      );
      
      // Convert BannerModel to Map
      final bannersData = banners?.map((banner) => banner.toJson()).toList() ?? [];
      
      // Lưu vào cache
      _cache.set(cacheKey, bannersData, duration: cacheDuration ?? _defaultCacheDuration);
      
      return bannersData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy flash sale cho trang chủ với cache (theo khung giờ hiện tại)
  Future<List<Map<String, dynamic>>> getHomeFlashSale({
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    // Xác định timeline hiện tại giống UI
    final now = DateTime.now();
    final hour = now.hour;
    final String currentTimeline = (hour >= 0 && hour < 9)
        ? '00:00'
        : (hour >= 9 && hour < 16)
            ? '09:00'
            : '16:00';

    // Bao gồm timeline trong cache key để tránh lẫn dữ liệu giữa các khung giờ
    final cacheKey = MemoryCacheService.createKey(
      CacheKeys.homeFlashSale,
      {'slot': currentTimeline},
    );
    
    // Migration: Xóa cache cũ dùng key cố định nếu còn tồn tại để tránh dùng nhầm dữ liệu slot khác
    if (_cache.has(CacheKeys.homeFlashSale)) {
      _cache.remove(CacheKeys.homeFlashSale);
    }

    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final flashSaleDeals = await _apiService.getFlashSaleDeals(
        timeSlot: currentTimeline,
        status: 'active',
        limit: 100,
      );
      
      // Convert FlashSaleDeal to Map
      final flashSaleData = flashSaleDeals?.map((deal) => deal.toJson()).toList() ?? [];
      
      // Lưu vào cache với thời gian ngắn hơn vì flash sale thay đổi nhanh
      _cache.set(cacheKey, flashSaleData, duration: cacheDuration ?? _shortCacheDuration);
      
      return flashSaleData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy banner đối tác cho trang chủ với cache
  Future<List<Map<String, dynamic>>> getHomePartnerBanners({
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    const cacheKey = CacheKeys.homePartnerBanners;
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final banners = await _apiService.getBanners(
        position: 'banner_doitac',
        limit: 10,
      );
      
      // Convert BannerModel to Map
      final bannersData = banners?.map((banner) => banner.toJson()).toList() ?? [];
      
      // Lưu vào cache
      _cache.set(cacheKey, bannersData, duration: cacheDuration ?? _longCacheDuration);
      
      return bannersData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy thương hiệu nổi bật cho trang chủ với cache
  Future<List<Map<String, dynamic>>> getHomeFeaturedBrands({
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    const cacheKey = CacheKeys.homeFeaturedBrands;
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final brands = await _apiService.getFeaturedBrands(
        getAll: true, // Lấy tất cả thương hiệu
        sort: 'order',
      );
      
      // Convert Brand to Map
      final brandsData = brands?.map((brand) => brand.toJson()).toList() ?? [];
      
      // Lưu vào cache
      _cache.set(cacheKey, brandsData, duration: cacheDuration ?? _longCacheDuration);
      
      return brandsData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy sản phẩm gợi ý cho trang chủ với cache
  /// Hỗ trợ personalized suggestions dựa trên userId (nếu có)
  Future<List<Map<String, dynamic>>> getHomeSuggestions({
    int limit = 20,
    bool forceRefresh = false,
    Duration? cacheDuration,
    int? userId, // Thêm userId để hỗ trợ personalized suggestions
  }) async {
    // Cache key bao gồm userId để phân biệt cache cho từng user
    final cacheKey = MemoryCacheService.createKey(
      CacheKeys.homeSuggestions, 
      {
        'limit': limit,
        if (userId != null) 'userId': userId,
      }
    );
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      
      // Nếu có userId, sử dụng personalized suggestions (user_based)
      // Nếu không có userId, sử dụng home_suggest như cũ
      List<ProductSuggest>? suggestions;
      
      if (userId != null) {
        suggestions = await _apiService.getProductSuggestions(
          type: 'user_based',
          userId: userId,
          limit: limit,
        );
      } else {
        suggestions = await _apiService.getProductSuggests(limit: limit);
      }
      
      // Convert ProductSuggest to Map
      final suggestionsData = (suggestions ?? []).map((suggestion) => suggestion.toJson()).toList();
      
      // Lưu vào cache
      _cache.set(cacheKey, suggestionsData, duration: cacheDuration ?? _defaultCacheDuration);
      
      return suggestionsData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }


  /// Lấy danh sách sản phẩm theo danh mục với cache
  Future<List<Map<String, dynamic>>> getCategoryProducts(
    int categoryId, {
    int page = 1,
    int limit = 20,
    String sort = 'relevance',
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.categoryProducts, {
      'categoryId': categoryId,
      'page': page,
      'limit': limit,
      'sort': sort,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      // Note: Cần implement method getCategoryProducts trong ApiService
      // Tạm thời return empty list
      final products = <Map<String, dynamic>>[];
      
      // Lưu vào cache
      _cache.set(cacheKey, products, duration: cacheDuration ?? _defaultCacheDuration);
      
      return products;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Xóa cache theo pattern
  void clearCachePattern(String pattern) {
    final keysToRemove = <String>[];
    
    // Access private _cache through public method
    final cacheInfo = _cache.getCacheInfo();
    for (final key in cacheInfo['entries'].keys) {
      if (key.contains(pattern)) {
        keysToRemove.add(key);
      }
    }
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    
  }

  /// Xóa tất cả cache
  void clearAllCache() {
    _cache.clear();
  }

  /// Lấy thông tin cache (để debug)
  Map<String, dynamic> getCacheInfo() {
    return _cache.getCacheInfo();
  }

  /// Lấy danh sách categories với cache
  Future<List<Map<String, dynamic>>> getCategoriesList({
    String type = 'parents',
    int? parentId,
    bool includeChildren = false,
    bool includeProductsCount = false,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.categories, {
      'type': type,
      'parentId': parentId,
      'includeChildren': includeChildren,
      'includeProductsCount': includeProductsCount,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final categories = await _apiService.getCategoriesList(
        type: type,
        parentId: parentId ?? 0,
        includeChildren: includeChildren,
        includeProductsCount: includeProductsCount,
      );
      
      // Convert to Map list - categories đã là List<Map<String, dynamic>>
      final categoriesData = categories ?? [];
      
      // Lưu vào cache với thời gian dài vì categories ít thay đổi
      _cache.set(cacheKey, categoriesData, duration: cacheDuration ?? _longCacheDuration);
      
      return categoriesData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy sản phẩm theo danh mục với cache và pagination
  Future<Map<String, dynamic>?> getCategoryProductsWithPagination({
    required int categoryId,
    int page = 1,
    int limit = 50,
    String sort = 'relevance',
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.categoryProducts, {
      'categoryId': categoryId,
      'page': page,
      'limit': limit,
      'sort': sort,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final response = await _apiService.getProductsByCategory(
        categoryId: categoryId,
        page: page,
        limit: limit,
        sort: sort,
      );
      
      // Lưu vào cache
      _cache.set(cacheKey, response, duration: cacheDuration ?? _defaultCacheDuration);
      
      return response;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Xóa cache của category cụ thể
  void clearCategoryCache(int categoryId) {
    clearCachePattern('category_products:{"categoryId":$categoryId');
  }

  /// Lấy affiliate dashboard với cache
  Future<Map<String, dynamic>?> getAffiliateDashboard({
    required int? userId,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.affiliateDashboard, {
      'userId': userId,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final dashboard = await _affiliateService.getDashboard(userId: userId);
      
      if (dashboard != null) {
        // Convert AffiliateDashboard object to Map for caching
        final dashboardMap = {
          'success': true,
          'data': dashboard.toJson(),
        };
        
        // Lưu vào cache với thời gian ngắn vì dashboard thay đổi thường xuyên
        _cache.set(cacheKey, dashboardMap, duration: cacheDuration ?? _shortCacheDuration);
        return dashboardMap;
      }
      
      return null;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy affiliate links với cache và pagination
  Future<Map<String, dynamic>?> getAffiliateLinks({
    required int? userId,
    int page = 1,
    int limit = 50,
    String? search,
    String sortBy = 'newest',
    bool onlyHasLink = false,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.affiliateLinks, {
      'userId': userId,
      'page': page,
      'limit': limit,
      'search': search,
      'sortBy': sortBy,
      'onlyHasLink': onlyHasLink,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final result = await _affiliateService.getMyLinks(
        userId: userId,
        page: page,
        limit: limit,
        search: search,
        sortBy: sortBy,
        onlyHasLink: onlyHasLink,
      );
      
      if (result != null) {
        // Lưu vào cache
        _cache.set(cacheKey, result, duration: cacheDuration ?? _defaultCacheDuration);
      }
      
      return result;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy affiliate products với cache và pagination
  Future<Map<String, dynamic>?> getAffiliateProducts({
    required int? userId,
    int page = 1,
    int limit = 50,
    String? search,
    String sortBy = 'newest',
    bool onlyFollowing = false,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.affiliateProducts, {
      'userId': userId,
      'page': page,
      'limit': limit,
      'search': search,
      'sortBy': sortBy,
      'onlyFollowing': onlyFollowing,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      
      final result = await _affiliateService.getProducts(
        userId: userId,
        page: page,
        limit: limit,
        search: search,
        sortBy: sortBy,
        onlyFollowing: onlyFollowing,
      );
      
      
      if (result != null) {
        // Lưu vào cache
        _cache.set(cacheKey, result, duration: cacheDuration ?? _defaultCacheDuration);
      } else {
      }
      
      return result;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Xóa cache của affiliate cụ thể
  void clearAffiliateCache(int userId) {
    clearCachePattern('affiliate_dashboard:{"userId":$userId');
    clearCachePattern('affiliate_links:{"userId":$userId');
    clearCachePattern('affiliate_products:{"userId":$userId');
  }

  /// Xóa cache của affiliate links cụ thể
  void clearAffiliateLinksCache(int userId) {
    clearCachePattern('affiliate_links:{"userId":$userId');
  }

  /// Xóa cache của affiliate products cụ thể
  void clearAffiliateProductsCache(int userId) {
    clearCachePattern('affiliate_products:{"userId":$userId');
  }

  /// Xóa tất cả cache của affiliate
  void clearAllAffiliateCache() {
    clearCachePattern('affiliate_dashboard');
    clearCachePattern('affiliate_links');
    clearCachePattern('affiliate_products');
  }

  /// Lấy chi tiết sản phẩm cơ bản với cache (tối ưu - load nhanh)
  Future<ProductDetail?> getProductDetailBasicCached(
    int productId, {
    int? userId,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey('product_detail_basic', {
      'id': productId,
      'userId': userId ?? 'anonymous',
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedProduct = _cache.get<ProductDetail>(cacheKey);
      if (cachedProduct != null) {
        return cachedProduct;
      }
    }

    try {
      final product = await _apiService.getProductDetailBasic(productId, userId: userId);
      
      // Lưu trực tiếp ProductDetail object vào cache
      if (product != null) {
        _cache.set(cacheKey, product, duration: cacheDuration ?? _longCacheDuration);
      }
      
      return product;
    } catch (e) {
      // Fallback về cache nếu có lỗi
      final cachedProduct = _cache.get<ProductDetail>(cacheKey);
      if (cachedProduct != null) {
        return cachedProduct;
      }
      
      rethrow;
    }
  }

  /// Lấy chi tiết sản phẩm đầy đủ với cache (API cũ - giữ nguyên)
  Future<ProductDetail?> getProductDetailCached(
    int productId, {
    int? userId,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.productDetail, {
      'id': productId,
      'userId': userId ?? 'anonymous',
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedProduct = _cache.get<ProductDetail>(cacheKey);
      if (cachedProduct != null) {
        return cachedProduct;
      }
    }

    try {
      final product = await _apiService.getProductDetail(productId, userId: userId);
      
      // Lưu trực tiếp ProductDetail object vào cache
      if (product != null) {
        _cache.set(cacheKey, product, duration: cacheDuration ?? _longCacheDuration);
      }
      
      return product;
    } catch (e) {
    
      final cachedProduct = _cache.get<ProductDetail>(cacheKey);
      if (cachedProduct != null) {
        return cachedProduct;
      }
      
      rethrow;
    }
  }

  /// Lấy sản phẩm cùng gian hàng với cache
  Future<Map<String, dynamic>?> getSameShopProductsCached(
    int productId, {
    int limit = 10,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.sameShopProducts, {
      'productId': productId,
      'limit': limit,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final response = await _apiService.getProductsSameShop(
        productId: productId,
        limit: limit,
      );
      
      // Lưu vào cache
      _cache.set(cacheKey, response, duration: cacheDuration ?? _defaultCacheDuration);
      
      return response;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy sản phẩm liên quan với cache
  Future<List<Map<String, dynamic>>?> getRelatedProductsCached(
    int productId, {
    int limit = 8,
    String type = 'auto',
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.relatedProducts, {
      'productId': productId,
      'limit': limit,
      'type': type,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final relatedProducts = await _apiService.getRelatedProducts(
        productId: productId,
        limit: limit,
        type: type,
      );
      
      // Convert RelatedProduct to Map list
      final relatedProductsData = relatedProducts?.map((product) => product.toJson()).toList();
      
      // Lưu vào cache
      _cache.set(cacheKey, relatedProductsData, duration: cacheDuration ?? _defaultCacheDuration);
      
      return relatedProductsData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Xóa cache của sản phẩm cụ thể
  void clearProductCache(int productId) {
    clearCachePattern('product_detail:{"id":$productId');
    clearCachePattern('same_shop_products:{"productId":$productId');
    clearCachePattern('related_products:{"productId":$productId');
  }

  /// Xóa tất cả cache của products
  void clearAllProductCache() {
    clearCachePattern(CacheKeys.productDetail);
    clearCachePattern(CacheKeys.sameShopProducts);
    clearCachePattern(CacheKeys.relatedProducts);
  }

  /// Force refresh tất cả cache của home
  /// Lấy banner products với cache
  Future<Map<String, BannerProducts?>?> getBannerProductsCached({
    String? viTriHienThi,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    // Cache key bao gồm vi_tri_hien_thi để phân biệt cache cho từng vị trí
    final cacheKey = MemoryCacheService.createKey(
      CacheKeys.homeBannerProducts,
      {
        if (viTriHienThi != null && viTriHienThi.isNotEmpty) 'position': viTriHienThi,
      },
    );
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        
        // Parse cached data back to Map<String, BannerProducts?>
        try {
          final result = <String, BannerProducts?>{};
          if (viTriHienThi != null && viTriHienThi.isNotEmpty) {
            // Single position
            if (cachedData.containsKey(viTriHienThi)) {
              final positionData = cachedData[viTriHienThi];
              if (positionData != null) {
                result[viTriHienThi] = BannerProducts.fromJson(positionData as Map<String, dynamic>);
              } else {
                result[viTriHienThi] = null;
              }
            }
          } else {
            // All positions
            for (final position in ['dau_trang', 'giua_trang', 'cuoi_trang']) {
              if (cachedData.containsKey(position)) {
                final positionData = cachedData[position];
                if (positionData != null) {
                  result[position] = BannerProducts.fromJson(positionData as Map<String, dynamic>);
                } else {
                  result[position] = null;
                }
              } else {
                result[position] = null;
              }
            }
          }
          return result;
        } catch (e) {
          // Fall through to fetch from API
        }
      }
    }

    try {
      final result = await _apiService.getBannerProducts(viTriHienThi: viTriHienThi);
      
      if (result != null) {
        // Convert BannerProducts to Map for caching
        final cacheData = <String, dynamic>{};
        result.forEach((position, bannerProduct) {
          if (bannerProduct != null) {
            cacheData[position] = bannerProduct.toJson();
          } else {
            cacheData[position] = null;
          }
        });
        
        // Lưu vào cache
        _cache.set(cacheKey, cacheData, duration: cacheDuration ?? _defaultCacheDuration);
        
      }
      
      return result;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        try {
          final result = <String, BannerProducts?>{};
          if (viTriHienThi != null && viTriHienThi.isNotEmpty) {
            if (cachedData.containsKey(viTriHienThi)) {
              final positionData = cachedData[viTriHienThi];
              if (positionData != null) {
                result[viTriHienThi] = BannerProducts.fromJson(positionData as Map<String, dynamic>);
              } else {
                result[viTriHienThi] = null;
              }
            }
          } else {
            for (final position in ['dau_trang', 'giua_trang', 'cuoi_trang']) {
              if (cachedData.containsKey(position)) {
                final positionData = cachedData[position];
                if (positionData != null) {
                  result[position] = BannerProducts.fromJson(positionData as Map<String, dynamic>);
                } else {
                  result[position] = null;
                }
              } else {
                result[position] = null;
              }
            }
          }
          return result;
        } catch (parseError) {
        }
      }
      
      rethrow;
    }
  }

  Future<void> refreshHomeCache() async {
    
    try {
      await Future.wait([
        getHomeBanners(forceRefresh: true),
        getHomeFlashSale(forceRefresh: true),
        getHomePartnerBanners(forceRefresh: true),
        getHomeSuggestions(forceRefresh: true),
        getBannerProductsCached(forceRefresh: true),
      ]);
      
    } catch (e) {
    }
  }

  /// Lấy danh sách sản phẩm freeship với cache
  Future<List<Map<String, dynamic>>?> getFreeShipProductsCached({
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = CacheKeys.freeshipProducts;
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final products = await _apiService.getFreeShipProducts();
      
      // Convert FreeShipProduct list to Map list for caching
      final productsData = products?.map((product) => product.toJson()).toList();
      
      // Lưu vào cache với thời gian dài vì freeship products ít thay đổi
      _cache.set(cacheKey, productsData, duration: cacheDuration ?? _longCacheDuration);
      
      return productsData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Xóa cache của freeship products
  void clearFreeshipCache() {
    _cache.remove(CacheKeys.freeshipProducts);
  }

  /// Tìm kiếm sản phẩm với cache
  Future<Map<String, dynamic>?> searchProductsCached({
    required String keyword,
    int page = 1,
    int limit = 50,
    bool forceRefresh = false,
    Duration? cacheDuration,
    int? userId, // Thêm userId để lưu search behavior
  }) async {
    // Cache key không bao gồm userId vì search results giống nhau cho mọi user
    // Nhưng API sẽ lưu search behavior riêng cho từng user
    final cacheKey = MemoryCacheService.createKey(CacheKeys.searchProducts, {
      'keyword': keyword,
      'page': page,
      'limit': limit,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      if (userId != null) {
      }
      
      final result = await _apiService.searchProducts(
        keyword: keyword,
        page: page,
        limit: limit,
        userId: userId,
      );
      
      // Lưu vào cache với thời gian ngắn vì search results thay đổi thường xuyên
      _cache.set(cacheKey, result, duration: cacheDuration ?? _shortCacheDuration);
      
      return result;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Lấy gợi ý tìm kiếm với cache
  Future<List<String>?> getSearchSuggestionsCached({
    required String keyword,
    int limit = 5,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.searchSuggestions, {
      'keyword': keyword,
      'limit': limit,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<String>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final suggestions = await _apiService.getSearchSuggestions(
        keyword: keyword,
        limit: limit,
      );
      
      // Lưu vào cache với thời gian ngắn vì suggestions thay đổi thường xuyên
      _cache.set(cacheKey, suggestions, duration: cacheDuration ?? _shortCacheDuration);
      
      return suggestions;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<String>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Xóa cache của search cụ thể
  void clearSearchCache(String keyword) {
    clearCachePattern('search_products:{"keyword":"$keyword"');
    clearCachePattern('search_suggestions:{"keyword":"$keyword"');
  }

  /// Xóa tất cả cache của search
  void clearAllSearchCache() {
    clearCachePattern(CacheKeys.searchProducts);
    clearCachePattern(CacheKeys.searchSuggestions);
  }

  /// Lấy flash sale deals với cache
  Future<List<Map<String, dynamic>>?> getFlashSaleDealsCached({
    required String timeSlot,
    String status = 'active',
    int limit = 100,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.flashSaleDeals, {
      'timeSlot': timeSlot,
      'status': status,
      'limit': limit,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final deals = await _apiService.getFlashSaleDeals(
        timeSlot: timeSlot,
        status: status,
        limit: limit,
      );
      
       // Convert FlashSaleDeal list to Map list for caching
       final dealsData = deals?.map((deal) => deal.toJson()).toList();
      
      // Lưu vào cache với thời gian ngắn vì flash sale thay đổi thường xuyên
      _cache.set(cacheKey, dealsData, duration: cacheDuration ?? _shortCacheDuration);
      
      return dealsData;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Xóa cache của flash sale cụ thể
  void clearFlashSaleCache(String timeSlot) {
    clearCachePattern('flash_sale_deals:{"timeSlot":"$timeSlot"');
  }

  /// Xóa tất cả cache của flash sale
  void clearAllFlashSaleCache() {
    clearCachePattern(CacheKeys.flashSaleDeals);
  }

  /// Lấy platform vouchers với cache
  Future<List<Voucher>?> getPlatformVouchersCached({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.platformVouchers, {
      'page': page,
      'limit': limit,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedVouchers = _cache.get<List<Voucher>>(cacheKey);
      if (cachedVouchers != null) {
        return cachedVouchers;
      }
    }

    try {
      final vouchers = await _apiService.getVouchers(
        type: 'platform',
        page: page,
        limit: limit,
      );
      
      // Lưu vào cache với thời gian ngắn vì voucher thay đổi thường xuyên
      if (vouchers != null) {
        _cache.set(cacheKey, vouchers, duration: cacheDuration ?? _shortCacheDuration);
      }
      
      return vouchers;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedVouchers = _cache.get<List<Voucher>>(cacheKey);
      if (cachedVouchers != null) {
        return cachedVouchers;
      }
      
      rethrow;
    }
  }

  /// Lấy shop vouchers với cache
  Future<List<Voucher>?> getShopVouchersCached({
    String? shopId,
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey('shop_vouchers', {
      'shopId': shopId,
      'page': page,
      'limit': limit,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedVouchers = _cache.get<List<Voucher>>(cacheKey);
      if (cachedVouchers != null) {
        return cachedVouchers;
      }
    }

    try {
      final vouchers = await _apiService.getVouchers(
        type: 'shop',
        shopId: shopId != null ? int.tryParse(shopId) : null,
        page: page,
        limit: limit,
      );
      
      // Lưu vào cache với thời gian ngắn vì voucher thay đổi thường xuyên
      if (vouchers != null) {
        _cache.set(cacheKey, vouchers, duration: cacheDuration ?? _shortCacheDuration);
      }
      
      return vouchers;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedVouchers = _cache.get<List<Voucher>>(cacheKey);
      if (cachedVouchers != null) {
        return cachedVouchers;
      }
      
      rethrow;
    }
  }

  /// Lấy danh sách shops cho voucher với cache
  Future<List<Map<String, dynamic>>?> getVoucherShopsCached({
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = CacheKeys.voucherShops;
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedShops = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedShops != null) {
        return cachedShops;
      }
    }

    try {
      final shops = await _apiService.getShopsWithVouchers();
      
      // Lưu vào cache với thời gian dài vì danh sách shop ít thay đổi
      if (shops != null) {
        _cache.set(cacheKey, shops, duration: cacheDuration ?? _longCacheDuration);
      }
      
      return shops;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedShops = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedShops != null) {
        return cachedShops;
      }
      
      rethrow;
    }
  }

  /// Xóa cache của platform vouchers cụ thể
  void clearPlatformVoucherCache(int page) {
    clearCachePattern('platform_vouchers:{"page":$page"');
  }

  /// Xóa tất cả cache của platform vouchers
  void clearAllPlatformVoucherCache() {
    clearCachePattern(CacheKeys.platformVouchers);
  }

  /// Xóa cache của shop vouchers cụ thể
  void clearShopVoucherCache(String? shopId, int page) {
    clearCachePattern('shop_vouchers:{"shopId":"$shopId","page":$page"');
  }

  /// Xóa tất cả cache của shop vouchers
  void clearAllShopVoucherCache() {
    clearCachePattern('shop_vouchers');
  }

  /// Xóa cache của voucher shops
  void clearVoucherShopsCache() {
    _cache.remove(CacheKeys.voucherShops);
  }

  /// Xóa tất cả cache của voucher
  void clearAllVoucherCache() {
    clearCachePattern(CacheKeys.platformVouchers);
    clearCachePattern('shop_vouchers');
    _cache.remove(CacheKeys.voucherShops);
  }

  // =============== FAVORITE PRODUCTS ===============
  
  /// Lấy danh sách sản phẩm yêu thích với cache
  Future<Map<String, dynamic>?> getFavoriteProductsCached({
    required int userId,
    int page = 1,
    int limit = 50,
    bool getAll = false,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey(CacheKeys.favoriteProducts, {
      'userId': userId,
      'page': page,
      'limit': limit,
      'getAll': getAll,
    });
    
    // Kiểm tra cache trước
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final result = await _apiService.getFavoriteProducts(
        userId: userId,
        page: page,
        limit: limit,
        getAll: getAll,
      );
      
      if (result != null) {
        // Lưu vào cache với thời gian ngắn vì favorite có thể thay đổi thường xuyên
        _cache.set(cacheKey, result, duration: cacheDuration ?? _shortCacheDuration);
      }
      
      return result;
    } catch (e) {
      
      // Fallback về cache cũ nếu có
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      rethrow;
    }
  }

  /// Thêm sản phẩm vào yêu thích và xóa cache
  Future<Map<String, dynamic>?> addFavoriteProductCached({
    required int userId,
    required int productId,
  }) async {
    try {
      final result = await _apiService.addFavoriteProduct(
        userId: userId,
        productId: productId,
      );
      
      if (result != null && result['success'] == true) {
        // Xóa cache của favorite products để refresh
        clearFavoriteProductsCache(userId);
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Xóa sản phẩm khỏi yêu thích và xóa cache
  Future<Map<String, dynamic>?> removeFavoriteProductCached({
    required int userId,
    required int productId,
  }) async {
    try {
      final result = await _apiService.removeFavoriteProduct(
        userId: userId,
        productId: productId,
      );
      
      if (result != null && result['success'] == true) {
        // Xóa cache của favorite products để refresh
        clearFavoriteProductsCache(userId);
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle favorite và xóa cache
  Future<Map<String, dynamic>?> toggleFavoriteProductCached({
    required int userId,
    required int productId,
  }) async {
    try {
      final result = await _apiService.toggleFavoriteProduct(
        userId: userId,
        productId: productId,
      );
      
      if (result != null && result['success'] == true) {
        // Xóa cache của favorite products để refresh
        clearFavoriteProductsCache(userId);
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Xóa cache của favorite products cho user cụ thể
  void clearFavoriteProductsCache(int userId) {
    clearCachePattern('favorite_products:{"userId":$userId');
  }

  /// Xóa tất cả cache của favorite products
  void clearAllFavoriteProductsCache() {
    clearCachePattern(CacheKeys.favoriteProducts);
  }

  /// Lấy sản phẩm shop với pagination và cache
  Future<Map<String, dynamic>?> getShopProductsPaginatedCached({
    required int shopId,
    int page = 1,
    int limit = 50,
    String? sortBy,
    String? categoryId,
    String? searchQuery,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey('shop_products_paginated', {
      'shopId': shopId,
      'page': page,
      'limit': limit,
      'sortBy': sortBy ?? '',
      'categoryId': categoryId ?? '',
      'searchQuery': searchQuery ?? '',
    });
    
    
    // Kiểm tra cache trước - nhưng không dùng cache khi có search query để đảm bảo kết quả mới nhất
    if (!forceRefresh && (searchQuery == null || searchQuery.isEmpty) && _cache.has(cacheKey)) {
      final cachedData = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
    }

    try {
      final result = await _apiService.getShopProductsPaginated(
        shopId: shopId,
        page: page,
        limit: limit,
        sortBy: sortBy,
        categoryId: categoryId,
        searchQuery: searchQuery,
      );
      
      if (result != null) {
        final products = result['products'] as List? ?? [];
      }
      
      if (result != null) {
        // Cache kết quả
        _cache.set(
          cacheKey,
          result,
        );
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Xóa cache của shop products
  void clearShopProductsCache(int shopId) {
    clearCachePattern('shop_products_paginated:{"shopId":$shopId');
  }

  /// Lấy flash sales của shop với cache riêng
  Future<List<Map<String, dynamic>>> getShopFlashSalesCached({
    required int shopId,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey('shop_flash_sales', {
      'shopId': shopId,
    });
    
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final result = await _apiService.getShopDetail(
        shopId: shopId,
        includeProducts: 0,
        includeFlashSale: 1,
        includeVouchers: 0,
        includeWarehouses: 0,
        includeCategories: 0,
        productsLimit: 0,
      );
      
      if (result != null) {
        final flashSales = result.flashSales.map((fs) => {
          'id': fs.id,
          'title': fs.title,
          'start_time': fs.startTime,
          'end_time': fs.endTime,
          'timeline': fs.timeline,
          'created_at': fs.createdAt,
          'main_products': fs.mainProducts,
          'sub_products': fs.subProducts,
        }).toList();
        _cache.set(
          cacheKey,
          flashSales,
        );
        return flashSales;
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Lấy vouchers của shop với cache riêng
  Future<List<Map<String, dynamic>>> getShopVouchersDataCached({
    required int shopId,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey('shop_vouchers', {
      'shopId': shopId,
    });
    
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final result = await _apiService.getShopDetail(
        shopId: shopId,
        includeProducts: 0,
        includeFlashSale: 0,
        includeVouchers: 1,
        includeWarehouses: 0,
        includeCategories: 0,
        productsLimit: 0,
      );
      
      if (result != null) {
        final vouchers = result.vouchers.map((v) => {
          'id': v.id,
          'code': v.code,
          'discount_value': v.discountValue,
          'max_discount': v.maxDiscount,
          'discount_type': v.discountType,
          'apply_type': v.applyType,
          'product_ids': v.productIds,
          'min_order_value': v.minOrderValue,
          'start_time': v.startTime,
          'end_time': v.endTime,
          'description': v.description,
          'image_url': v.imageUrl,
          'min_price': v.minPrice,
          'max_price': v.maxPrice,
          'allow_combination': v.allowCombination,
          'max_uses_per_user': v.maxUsesPerUser,
          'max_global_uses': v.maxGlobalUses,
          'current_uses': v.currentUses,
          'created_at': v.createdAt,
        }).toList();
        _cache.set(
          cacheKey,
          vouchers,
        );
        return vouchers;
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Lấy warehouses của shop với cache riêng
  Future<List<Map<String, dynamic>>> getShopWarehousesCached({
    required int shopId,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey('shop_warehouses', {
      'shopId': shopId,
    });
    
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final result = await _apiService.getShopDetail(
        shopId: shopId,
        includeProducts: 0,
        includeFlashSale: 0,
        includeVouchers: 0,
        includeWarehouses: 1,
        includeCategories: 0,
        productsLimit: 0,
      );
      
      if (result != null) {
        final warehouses = result.warehouses.map((w) => {
          'id': w.id,
          'warehouse_code': w.warehouseCode,
          'warehouse_name': w.warehouseName,
          'contact_name': w.contactName,
          'contact_phone': w.contactPhone,
          'is_default': w.isDefault,
          'is_pickup': w.isPickup,
          'is_return': w.isReturn,
          'latitude': w.latitude,
          'longitude': w.longitude,
          'address_detail': w.addressDetail,
          'province_id': w.provinceId,
          'district_id': w.districtId,
          'ward_id': w.wardId,
          'province_name': w.provinceName,
          'district_name': w.districtName,
          'ward_name': w.wardName,
          'full_address': w.fullAddress,
          'free_ship_mode': w.freeShipMode,
          'free_ship_min_order': w.freeShipMinOrder,
          'free_ship_discount': w.freeShipDiscount,
          'freeship_description': w.freeshipDescription,
        }).toList();
        _cache.set(
          cacheKey,
          warehouses,
        );
        return warehouses;
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Lấy categories của shop với cache riêng
  Future<List<Map<String, dynamic>>> getShopCategoriesCached({
    required int shopId,
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    final cacheKey = MemoryCacheService.createKey('shop_categories', {
      'shopId': shopId,
    });
    
    if (!forceRefresh && _cache.has(cacheKey)) {
      final cachedData = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final result = await _apiService.getShopDetail(
        shopId: shopId,
        includeProducts: 0,
        includeFlashSale: 0,
        includeVouchers: 0,
        includeWarehouses: 0,
        includeCategories: 1,
        productsLimit: 0,
      );
      
      if (result != null) {
        final categories = result.categories.map((c) => {
          'id': c.id,
          'icon': c.icon,
          'title': c.title,
          'description': c.description,
          'parent_id': c.parentId,
          'is_index': c.isIndex,
          'link': c.link,
          'image': c.image,
          'banner_image': c.bannerImage,
          'left_image': c.leftImage,
          'seo_title': c.seoTitle,
          'seo_description': c.seoDescription,
          'order': c.order,
          'socdo_category_ids': c.socdoCategoryIds,
          'socdo_category_name': c.socdoCategoryName,
          'category_url': c.categoryUrl,
        }).toList();
        _cache.set(
          cacheKey,
          categories,
        );
        return categories;
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Xóa tất cả cache của shop
  void clearAllShopCache(int shopId) {
    clearShopProductsCache(shopId);
    clearCachePattern('shop_flash_sales:{"shopId":$shopId');
    clearCachePattern('shop_vouchers:{"shopId":$shopId');
    clearCachePattern('shop_warehouses:{"shopId":$shopId');
    clearCachePattern('shop_categories:{"shopId":$shopId');
    clearCachePattern('shop_detail:{"shopId":$shopId');
  }
}
