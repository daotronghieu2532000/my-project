class SearchResult {
  final bool success;
  final List<SearchProduct> products;
  final List<ShopSuggestion> shops;
  final SearchPagination pagination;
  final String keyword;
  final String searchTime;

  SearchResult({
    required this.success,
    required this.products,
    this.shops = const [],
    required this.pagination,
    required this.keyword,
    required this.searchTime,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final productsJson = data['products'] as List<dynamic>? ?? [];
    final shopsJson = data['shops'] as List<dynamic>? ?? [];
    final paginationJson = data['pagination'] as Map<String, dynamic>? ?? {};

    return SearchResult(
      success: json['success'] == true,
      products: productsJson
          .map((product) {
            try {
              final parsedProduct = SearchProduct.fromJson(product as Map<String, dynamic>);
              // Chỉ filter out sản phẩm có ID = 0 (không có ID)
              if (parsedProduct.id == 0) {
                print('⚠️ Filtering out product with ID = 0');
                return null;
              }
              print('✅ Parsed product: ${parsedProduct.name} (ID: ${parsedProduct.id})');
              return parsedProduct;
            } catch (e) {
              print('❌ Lỗi parse product: $e, product data: $product');
              return null;
            }
          })
          .where((product) => product != null)
          .cast<SearchProduct>()
          .toList(),
      shops: shopsJson
          .map((shop) {
            try {
              return ShopSuggestion.fromJson(shop as Map<String, dynamic>);
            } catch (e) {
              print('❌ Lỗi parse shop: $e, shop data: $shop');
              return null;
            }
          })
          .where((shop) => shop != null)
          .cast<ShopSuggestion>()
          .toList(),
      pagination: SearchPagination.fromJson(paginationJson),
      keyword: data['keyword']?.toString() ?? '',
      searchTime: data['search_time']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': {
        'products': products.map((product) => product.toJson()).toList(),
        'shops': shops.map((shop) => shop.toJson()).toList(),
        'pagination': pagination.toJson(),
        'keyword': keyword,
        'search_time': searchTime,
      },
    };
  }
}

class SearchProduct {
  final int id;
  final String name;
  final String image;
  final int price;
  final int? oldPrice;
  final int? discount;
  final double rating;
  final int sold;
  final String shopId;
  final String shopName;
  final bool isFreeship;
  final String category;
  final bool inStock;
  final bool hasVoucher;
  
  // Thông tin badges từ API (giống ProductSuggest)
  final String? voucherIcon;
  final String? freeshipIcon;
  final String? chinhhangIcon;
  final String? warehouseName;
  final String? provinceName;

  SearchProduct({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    this.oldPrice,
    this.discount,
    required this.rating,
    required this.sold,
    required this.shopId,
    required this.shopName,
    required this.isFreeship,
    required this.category,
    required this.inStock,
    required this.hasVoucher,
    this.voucherIcon,
    this.freeshipIcon,
    this.chinhhangIcon,
    this.warehouseName,
    this.provinceName,
  });

  factory SearchProduct.fromJson(Map<String, dynamic> json) {
    return SearchProduct(
      id: _safeParseInt(json['id']) ?? 0,
      name: json['tieu_de']?.toString() ?? json['name']?.toString() ?? '',
      image: _buildImageUrl(json),
      price: _safeParseInt(json['gia_moi']) ?? _safeParseInt(json['price']) ?? 0,
      oldPrice: _safeParseInt(json['gia_cu']) ?? _safeParseInt(json['old_price']),
      discount: _safeParseInt(json['discount_percent']) ?? _safeParseInt(json['discount']),
      rating: _safeParseDouble(json['avg_rating']) ?? _safeParseDouble(json['rating']) ?? 0.0,
      sold: _safeParseInt(json['total_sold']) ?? _safeParseInt(json['sold']) ?? 0,
      shopId: json['shop']?.toString() ?? json['shop_id']?.toString() ?? '',
      shopName: json['shop_name']?.toString() ?? 'Shop',
      isFreeship: _safeParseBool(json['is_freeship']) ?? false,
      category: json['category']?.toString() ?? 'Sản phẩm',
      inStock: (() {
        final s = _safeParseInt(json['kho']) ?? _safeParseInt(json['stock']) ?? _safeParseInt(json['so_luong']);
        if (s != null) return s > 0;
        // Fallback: nếu không có thông tin kho, coi như còn hàng
        return true;
      })(),
      hasVoucher: (() {
        if (json['has_coupon'] != null) return _safeParseBool(json['has_coupon']) ?? false;
        if (json['coupon'] != null) return true;
        if (json['coupon_info'] is Map) return true;
        return false;
      })(),
      // Parse badges từ API
      voucherIcon: json['voucher_icon'] as String?,
      freeshipIcon: json['freeship_icon'] as String?,
      chinhhangIcon: json['chinhhang_icon'] as String?,
      warehouseName: json['warehouse_name'] as String?,
      provinceName: json['province_name'] as String?,
    );
  }

  /// Helper method để parse int an toàn từ String hoặc int
  static int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  /// Helper method để parse double an toàn từ String hoặc num
  static double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Helper method để parse bool an toàn
  static bool? _safeParseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) return value == 1;
    return null;
  }

  /// Helper method để build URL hình ảnh
  static String _buildImageUrl(Map<String, dynamic> json) {
    // Ưu tiên image_url nếu có và không phải no-images.jpg
    final imageUrl = json['image_url']?.toString();
    if (imageUrl != null && !imageUrl.contains('no-images.jpg')) {
      return imageUrl;
    }
    
    // Nếu có minh_hoa, build URL đầy đủ
    final minhHoa = json['minh_hoa']?.toString();
    if (minhHoa != null && minhHoa.isNotEmpty) {
      // Nếu đã có https:// thì dùng luôn
      if (minhHoa.startsWith('http')) {
        return minhHoa;
      }
      // Nếu bắt đầu bằng / thì thêm domain
      if (minhHoa.startsWith('/')) {
        return 'https://socdo.vn$minhHoa';
      }
      // Nếu không có / ở đầu thì thêm /
      return 'https://socdo.vn/$minhHoa';
    }
    
    // Fallback về image_url hoặc no-images
    return imageUrl ?? 'https://socdo.vn/images/no-images.jpg';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'price': price,
      'old_price': oldPrice,
      'discount': discount,
      'rating': rating,
      'sold': sold,
      'shop_id': shopId,
      'shop_name': shopName,
      'is_freeship': isFreeship,
      'category': category,
      'in_stock': inStock,
      'has_voucher': hasVoucher,
    };
  }

  /// Tính phần trăm giảm giá
  double get discountPercentage {
    if (oldPrice == null || oldPrice! <= 0) return 0.0;
    return ((oldPrice! - price) / oldPrice!) * 100;
  }

  /// Format giá tiền
  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M ₫';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K ₫';
    } else {
      return '$price ₫';
    }
  }

  /// Format giá cũ
  String get formattedOldPrice {
    if (oldPrice == null) return '';
    if (oldPrice! >= 1000000) {
      return '${(oldPrice! / 1000000).toStringAsFixed(1)}M ₫';
    } else if (oldPrice! >= 1000) {
      return '${(oldPrice! / 1000).toStringAsFixed(0)}K ₫';
    } else {
      return '$oldPrice ₫';
    }
  }

  /// Format số lượng đã bán
  String get formattedSold {
    if (sold >= 1000000) {
      return '${(sold / 1000000).toStringAsFixed(1)}M';
    } else if (sold >= 1000) {
      return '${(sold / 1000).toStringAsFixed(0)}K';
    } else {
      return sold.toString();
    }
  }
}

class ShopSuggestion {
  final int shopId;
  final int userId;
  final String name;
  final String username;
  final String handle;
  final String avatar;

  ShopSuggestion({
    required this.shopId,
    required this.userId,
    required this.name,
    required this.username,
    required this.handle,
    required this.avatar,
  });

  factory ShopSuggestion.fromJson(Map<String, dynamic> json) {
    return ShopSuggestion(
      shopId: SearchProduct._safeParseInt(json['shop_id']) ?? 0,
      userId: SearchProduct._safeParseInt(json['user_id']) ?? 0,
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      handle: json['handle']?.toString() ?? json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? 'https://socdo.vn/images/no-images.jpg',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'user_id': userId,
      'name': name,
      'username': username,
      'handle': handle,
      'avatar': avatar,
    };
  }
}

class SearchPagination {
  final int currentPage;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  SearchPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory SearchPagination.fromJson(Map<String, dynamic> json) {
    return SearchPagination(
      currentPage: SearchProduct._safeParseInt(json['current_page']) ?? 1,
      perPage: SearchProduct._safeParseInt(json['per_page']) ?? 10,
      total: SearchProduct._safeParseInt(json['total']) ?? 
             SearchProduct._safeParseInt(json['total_products']) ?? 0,
      totalPages: SearchProduct._safeParseInt(json['total_pages']) ?? 1,
      hasNext: SearchProduct._safeParseBool(json['has_next']) ?? false,
      hasPrev: SearchProduct._safeParseBool(json['has_prev']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'per_page': perPage,
      'total': total,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_prev': hasPrev,
    };
  }
}
