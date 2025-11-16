// Image URL normalizer
// Hỗ trợ CDN: https://socdo.cdn.vccloud.vn/
// Fallback về https://socdo.vn/ nếu CDN lỗi (được xử lý ở Image widget)
String _fixImageUrl(String rawUrl) {
  String url = rawUrl.trim();
  if (url.isEmpty) return '';
  if (url.startsWith('@')) url = url.substring(1);
  
  // Nếu đã là URL đầy đủ (bao gồm CDN), giữ nguyên
  if (url.startsWith('http://') || url.startsWith('https://')) {
    // Sửa lỗi URL có 2 dấu // (ví dụ: https://socdo.vn//uploads/...)
    url = url.replaceAll(RegExp(r'([^:])//+'), r'$1/');
    url = url.replaceFirst('://api.socdo.vn', '://socdo.vn');
    url = url.replaceFirst('://www.api.socdo.vn', '://socdo.vn');
    url = url.replaceFirst('://www.socdo.vn', '://socdo.vn');
    if (url.startsWith('http://')) url = url.replaceFirst('http://', 'https://');
    return url;
  }
  
  // Nếu là relative path, chuyển sang CDN
  if (url.startsWith('/uploads/') || url.startsWith('uploads/')) {
    url = url.replaceFirst(RegExp(r'^/'), '');
    return 'https://socdo.cdn.vccloud.vn/$url';
  }
  
  url = url.replaceFirst(RegExp(r'^/'), '');
  return 'https://socdo.cdn.vccloud.vn/$url';
}

class ProductDetail {
  final int id;
  final String name;
  final String? description;
  final String? shortDescription;
  final String? highlights;
  final List<String> images;
  final String? thumbnail;
  final int price;
  final int? oldPrice;
  final double? discount;
  final int? stock;
  final String? brand;
  final String? category;
  final double? rating;
  final int? sold;
  final int? reviews;
  final String? shopId;
  final String? shopName;
  final String? shopLogo;
  final bool isFreeship;
  final bool isRecommended;
  final List<ProductVariant> variants;
  final List<String> tags;
  final String? specifications;
  final String? warranty;
  final String? returnPolicy;
  final Map<String, dynamic>? couponInfo;
  final Map<String, dynamic>? shopInfo;
  final bool isFavorited;
  final Map<String, dynamic>? flashSaleInfo;

  const ProductDetail({
    required this.id,
    required this.name,
    this.description,
    this.shortDescription,
    this.highlights,
    required this.images,
    this.thumbnail,
    required this.price,
    this.oldPrice,
    this.discount,
    this.stock,
    this.brand,
    this.category,
    this.rating,
    this.sold,
    this.reviews,
    this.shopId,
    this.shopName,
    this.shopLogo,
    this.isFreeship = false,
    this.isRecommended = false,
    required this.variants,
    required this.tags,
    this.specifications,
    this.warranty,
    this.returnPolicy,
    this.couponInfo,
    this.shopInfo,
    this.isFavorited = false,
    this.flashSaleInfo,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int from String or int
    int? safeParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Helper function to safely parse Map<String, dynamic> from dynamic
    Map<String, dynamic>? safeParseMap(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      if (value is List && value.isNotEmpty && value.first is Map) {
        final Map first = value.first as Map;
        return first.map((key, val) => MapEntry(key.toString(), val));
      }
      return null;
    }

    // Helper function to safely parse double from String, int, or double
    double? safeParseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // Helper function to safely parse bool from String, int, or bool
    bool safeParseBool(dynamic value, {bool defaultValue = false}) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) {
        final lowerValue = value.toLowerCase();
        return lowerValue == 'true' || lowerValue == '1' || lowerValue == 'yes';
      }
      return defaultValue;
    }

    // Parse images array
    List<String> parseImages(dynamic imagesData) {
      // print('🔍 parseImages input: $imagesData');
      // print('🔍 parseImages type: ${imagesData.runtimeType}');
      
      if (imagesData == null) {
        // print('🔍 parseImages: null data, returning empty list');
        return [];
      }
      if (imagesData is List) {
        final result = imagesData.map((e) => _fixImageUrl(e.toString())).toList();
        // print('🔍 parseImages: List result: $result');
        return result;
      }
      if (imagesData is String) {
        // Check if string contains comma-separated paths
        if (imagesData.contains(',')) {
          final result = imagesData.split(',').map((e) => _fixImageUrl(e.trim())).where((e) => e.isNotEmpty).toList();
          // print('🔍 parseImages: Comma-separated string result: $result');
          return result;
        } else {
          final result = [_fixImageUrl(imagesData)];
          // print('🔍 parseImages: Single string result: $result');
          return result;
        }
      }
      // print('🔍 parseImages: Unknown type, returning empty list');
      return [];
    }

    // Parse variants
    List<ProductVariant> parseVariants(dynamic variantsData) {
      if (variantsData == null) return [];
      if (variantsData is List) {
        return variantsData
            .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    // Parse tags
    List<String> parseTags(dynamic tagsData) {
      if (tagsData == null) return [];
      if (tagsData is List) {
        return tagsData.map((e) => e.toString()).toList();
      }
      if (tagsData is String) {
        return [tagsData];
      }
      return [];
    }

    final Map<String, dynamic>? shopInfoMap = safeParseMap(json['shop_info']);
    final String? parsedShopId = (json['shop_id']?.toString() ?? json['shop']?.toString() ?? shopInfoMap?['user_id']?.toString() ?? shopInfoMap?['id']?.toString());
    final String? parsedShopName = (json['shop_name'] as String?) ?? (json['ten_shop'] as String?) ?? (shopInfoMap?['name'] as String?);

    return ProductDetail(
      id: safeParseInt(json['id']) ?? safeParseInt(json['product_id']) ?? 0,
      name: json['name'] as String? ?? json['tieu_de'] as String? ?? json['title'] as String? ?? 'Sản phẩm',
      description: json['noi_dung'] as String? ?? json['description'] as String? ?? json['mo_ta'] as String?,
      shortDescription: json['short_description'] as String? ?? json['mo_ta_ngan'] as String?,
      highlights: json['noi_bat'] as String?,
      images: () {
        // print('🔍 API Response - images: ${json['images']}');
        // print('🔍 API Response - anh: ${json['anh']}');
        // print('🔍 API Response - minh_hoa: ${json['minh_hoa']}');
        // Ưu tiên lấy từ anh (gallery images), sau đó từ images.gallery, cuối cùng từ minh_hoa
        final galleryData = json['anh'] ?? json['images']?['gallery'] ?? json['minh_hoa'];
        // print('🔍 Gallery data to parse: $galleryData');
        return parseImages(galleryData);
      }(),
      thumbnail: () {
        // print('🔍 Thumbnail data: ${json['images']?['main']}');
        final thumbnailUrl = json['images']?['main'] as String? ?? json['images']?['thumb'] as String? ?? json['thumbnail'] as String? ?? json['hinh_dai_dien'] as String?;
        final fixedUrl = thumbnailUrl != null ? _fixImageUrl(thumbnailUrl) : null;
        // print('🔍 Fixed thumbnail URL: $fixedUrl');
        return fixedUrl;
      }(),
      price: safeParseInt(json['price']) ?? safeParseInt(json['gia_moi']) ?? safeParseInt(json['gia']) ?? 0,
      oldPrice: safeParseInt(json['old_price']) ?? safeParseInt(json['gia_cu']) ?? safeParseInt(json['gia_goc']),
      discount: safeParseDouble(json['discount']) ?? safeParseDouble(json['giam_gia']),
      stock: safeParseInt(json['stock']) ?? safeParseInt(json['so_luong']) ?? safeParseInt(json['ton_kho']),
      brand: json['brand'] as String? ?? json['thuong_hieu'] as String?,
      category: json['category'] as String? ?? json['danh_muc'] as String?,
      rating: safeParseDouble(json['rating']) ?? safeParseDouble(json['danh_gia']),
      sold: safeParseInt(json['sold']) ?? safeParseInt(json['da_ban']) ?? safeParseInt(json['luot_ban']),
      reviews: safeParseInt(json['reviews']) ?? safeParseInt(json['danh_gia_count']) ?? safeParseInt(json['luot_danh_gia']),
      shopId: parsedShopId,
      shopName: parsedShopName,
      shopLogo: json['shop_logo'] as String? ?? json['logo_shop'] as String? ?? shopInfoMap?['avatar'] as String?,
      isFreeship: safeParseBool(json['is_freeship'] ?? json['mien_phi_ship']),
      isRecommended: safeParseBool(json['is_recommended'] ?? json['khuyen_mai']),
      variants: parseVariants(json['variants'] ?? json['bien_the'] ?? json['sub_product']),
      tags: parseTags(json['tags'] ?? json['the'] ?? json['nhan']),
      specifications: json['specifications'] as String? ?? json['thong_so_ky_thuat'] as String?,
      warranty: json['warranty'] as String? ?? json['bao_hanh'] as String?,
      returnPolicy: json['return_policy'] as String? ?? json['chinh_sach_doi_tra'] as String?,
      couponInfo: safeParseMap(json['coupon_info']),
      shopInfo: safeParseMap(json['shop_info']),
      isFavorited: safeParseBool(json['is_favorited']),
      flashSaleInfo: safeParseMap(json['flash_sale_info']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'short_description': shortDescription,
      'highlights': highlights,
      'images': images,
      'thumbnail': thumbnail,
      'price': price,
      'old_price': oldPrice,
      'discount': discount,
      'stock': stock,
      'brand': brand,
      'category': category,
      'rating': rating,
      'sold': sold,
      'reviews': reviews,
      'shop_id': shopId,
      'shop_name': shopName,
      'shop_logo': shopLogo,
      'is_freeship': isFreeship,
      'is_recommended': isRecommended,
      'variants': variants.map((v) => v.toJson()).toList(),
      'tags': tags,
      'specifications': specifications,
      'warranty': warranty,
      'return_policy': returnPolicy,
      'coupon_info': couponInfo,
      'shop_info': shopInfo,
      'is_favorited': isFavorited,
      'flash_sale_info': flashSaleInfo,
    };
  }

  /// Format phần trăm giảm giá
  String get formattedDiscount {
    if (discount == null) return '';
    return '${discount!.toInt()}%';
  }

  /// Format số lượng đã bán
  String get formattedSold {
    if (sold == null) return '';
    if (sold! >= 1000) {
      final double inK = sold! / 1000.0;
      String s = inK.toStringAsFixed(inK.truncateToDouble() == inK ? 0 : 1);
      return '$s+';
    }
    return sold.toString();
  }

  /// Format đánh giá
  String get formattedRating {
    if (rating == null) return '';
    return rating!.toStringAsFixed(1);
  }

  /// Lấy URL hình ảnh chính
  String get mainImageUrl {
    // Ưu tiên lấy từ thumbnail (images.main từ API)
    if (thumbnail?.isNotEmpty == true) {
      return thumbnail!;
    }
    // Fallback về images array
    if (images.isNotEmpty) {
      return images.first;
    }
    return '';
  }

  /// Lấy URL hình ảnh ưu tiên với domain đúng
  String get imageUrl {
    return _fixImageUrl(mainImageUrl);
  }

  /// Kiểm tra có mã giảm giá không
  bool get hasCoupon => couponInfo?['has_coupon'] == true;

  /// Lấy mã giảm giá
  String get couponCode => couponInfo?['coupon_code'] as String? ?? '';

  /// Lấy chi tiết mã giảm giá
  String get couponDetails => couponInfo?['coupon_details'] as String? ?? '';

  /// Lấy mô tả mã giảm giá
  String get couponDescription => couponInfo?['coupon_description'] as String? ?? '';

  /// Lấy thông tin shop
  String get shopNameFromInfo => shopInfo?['shop_name'] as String? ?? shopName ?? '';

  /// Lấy địa chỉ shop
  String get shopAddress => shopInfo?['shop_address'] as String? ?? '';

  /// Lấy avatar shop
  String get shopAvatar => shopInfo?['shop_avatar'] as String? ?? shopLogo ?? '';

  /// Lấy URL shop
  String get shopUrl => shopInfo?['shop_url'] as String? ?? '';

  /// Kiểm tra có flash sale không
  bool get isFlashSale => flashSaleInfo?['is_flash_sale'] == true;

  /// Lấy thời gian còn lại (seconds)
  int get flashSaleTimeRemaining => flashSaleInfo?['time_remaining'] as int? ?? 0;

  /// Lấy thời gian còn lại formatted (HH:mm:ss)
  String get flashSaleTimeFormatted => flashSaleInfo?['time_remaining_formatted'] as String? ?? '00:00:00';

  @override
  String toString() {
    return 'ProductDetail(id: $id, name: $name, price: $price, shopName: $shopName)';
  }
}

class ProductVariant {
  final String id;
  final String name;
  final Map<String, String> attributes;
  final int price;
  final int? oldPrice;
  final int? stock;
  final String? imageUrl;
  final bool isDefault;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.attributes,
    required this.price,
    this.oldPrice,
    this.stock,
    this.imageUrl,
    this.isDefault = false,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int from String or int
    int? safeParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Helper function to safely parse bool from String, int, or bool
    bool safeParseBool(dynamic value, {bool defaultValue = false}) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) {
        final lowerValue = value.toLowerCase();
        return lowerValue == 'true' || lowerValue == '1' || lowerValue == 'yes';
      }
      return defaultValue;
    }

    // Parse attributes
    Map<String, String> parseAttributes(dynamic attrsData) {
      if (attrsData == null) return {};
      if (attrsData is Map) {
        return attrsData.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
      return {};
    }

    return ProductVariant(
      id: json['id']?.toString() ?? json['variant_id']?.toString() ?? '',
      name: json['variant_name'] as String? ?? json['name'] as String? ?? json['ten'] as String? ?? json['color'] as String? ?? 'Variant',
      attributes: parseAttributes(json['attributes'] ?? json['thuoc_tinh']),
      price: safeParseInt(json['gia_moi']) ?? safeParseInt(json['price']) ?? safeParseInt(json['gia']) ?? 0,
      oldPrice: safeParseInt(json['gia_cu']) ?? safeParseInt(json['old_price']),
      stock: safeParseInt(json['kho_sanpham_socdo']) ?? safeParseInt(json['stock']) ?? safeParseInt(json['so_luong']),
      imageUrl: json['image_url'] as String? ?? json['image_phanloai'] as String? ?? json['hinh_anh'] as String?,
      isDefault: safeParseBool(json['is_default'] ?? json['mac_dinh']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'attributes': attributes,
      'price': price,
      'old_price': oldPrice,
      'stock': stock,
      'image_url': imageUrl,
      'is_default': isDefault,
    };
  }
}
