class SameShopProduct {
  final int id;
  final String name;
  final String slug;
  final int price;
  final int oldPrice;
  final int discountPercent;
  final int shopId;
  final List<int> categoryIds;
  final int brandId;
  final String brandName;
  final String brandLogo;
  final String image;
  final String thumb;
  final String productUrl;
  final Map<String, dynamic> voucherInfo;
  final Map<String, dynamic> shippingInfo;
  final List<String> badges;
  final int isAuthentic;
  final int isFeatured;
  final int isTrending;
  final int isFlashSale;
  final int createdAt;
  final int updatedAt;
  final String priceFormatted;
  final String oldPriceFormatted;
  
  // Rating và reviews từ database thật
  final int totalReviews;
  final double avgRating;
  final int soldCount;
  
  // Thông tin badges từ API (giống ProductSuggest)
  final String? voucherIcon;
  final String? freeshipIcon;
  final String? chinhhangIcon;
  final String? warehouseName;
  final String? provinceName;

  const SameShopProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    required this.oldPrice,
    required this.discountPercent,
    required this.shopId,
    required this.categoryIds,
    required this.brandId,
    required this.brandName,
    required this.brandLogo,
    required this.image,
    required this.thumb,
    required this.productUrl,
    required this.voucherInfo,
    required this.shippingInfo,
    required this.badges,
    required this.isAuthentic,
    required this.isFeatured,
    required this.isTrending,
    required this.isFlashSale,
    required this.createdAt,
    required this.updatedAt,
    required this.priceFormatted,
    required this.oldPriceFormatted,
    this.totalReviews = 0,
    this.avgRating = 0.0,
    this.soldCount = 0,
    this.voucherIcon,
    this.freeshipIcon,
    this.chinhhangIcon,
    this.warehouseName,
    this.provinceName,
  });

  factory SameShopProduct.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int from String or int
    int safeParseInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper function to safely parse list of ints
    List<int> safeParseIntList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => safeParseInt(e)).toList();
      }
      if (value is String) {
        return value.split(',').map((e) => safeParseInt(e.trim())).toList();
      }
      return [];
    }

    // Helper function to safely parse list of strings
    List<String> safeParseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      if (value is String) {
        return [value];
      }
      return [];
    }

    // Helper function to safely parse map
    Map<String, dynamic> safeParseMap(dynamic value) {
      if (value == null) return {};
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return {};
    }

    // Helper function to safely parse double
    double safeParseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return SameShopProduct(
      id: safeParseInt(json['id']),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      price: safeParseInt(json['price']),
      oldPrice: safeParseInt(json['old_price']),
      discountPercent: safeParseInt(json['discount_percent']),
      shopId: safeParseInt(json['shop_id']),
      categoryIds: safeParseIntList(json['category_ids']),
      brandId: safeParseInt(json['brand_id']),
      brandName: json['brand_name'] as String? ?? '',
      brandLogo: json['brand_logo'] as String? ?? '',
      image: json['image'] as String? ?? '',
      thumb: json['thumb'] as String? ?? '',
      productUrl: json['product_url'] as String? ?? '',
      voucherInfo: safeParseMap(json['voucher_info']),
      shippingInfo: safeParseMap(json['shipping_info']),
      badges: safeParseStringList(json['badges']),
      isAuthentic: safeParseInt(json['is_authentic']),
      isFeatured: safeParseInt(json['is_featured']),
      isTrending: safeParseInt(json['is_trending']),
      isFlashSale: safeParseInt(json['is_flash_sale']),
      createdAt: safeParseInt(json['created_at']),
      updatedAt: safeParseInt(json['updated_at']),
      priceFormatted: json['price_formatted'] as String? ?? '',
      oldPriceFormatted: json['old_price_formatted'] as String? ?? '',
      // Parse rating và reviews từ API (dữ liệu thật)
      totalReviews: safeParseInt(json['reviews_count'] ?? json['total_reviews']),
      avgRating: safeParseDouble(json['rating'] ?? json['average_rating'] ?? json['avg_rating']) ?? 0.0,
      soldCount: safeParseInt(json['sold_count'] ?? json['ban']),
      // Parse badges từ API
      voucherIcon: json['voucher_icon'] as String?,
      freeshipIcon: json['freeship_icon'] as String?,
      chinhhangIcon: json['chinhhang_icon'] as String?,
      warehouseName: json['warehouse_name'] as String?,
      provinceName: json['province_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'price': price,
      'old_price': oldPrice,
      'discount_percent': discountPercent,
      'shop_id': shopId,
      'category_ids': categoryIds,
      'brand_id': brandId,
      'brand_name': brandName,
      'brand_logo': brandLogo,
      'image': image,
      'thumb': thumb,
      'product_url': productUrl,
      'voucher_info': voucherInfo,
      'shipping_info': shippingInfo,
      'badges': badges,
      'is_authentic': isAuthentic,
      'is_featured': isFeatured,
      'is_trending': isTrending,
      'is_flash_sale': isFlashSale,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'price_formatted': priceFormatted,
      'old_price_formatted': oldPriceFormatted,
      'total_reviews': totalReviews,
      'avg_rating': avgRating,
      'sold_count': soldCount,
      'voucher_icon': voucherIcon,
      'freeship_icon': freeshipIcon,
      'chinhhang_icon': chinhhangIcon,
      'warehouse_name': warehouseName,
      'province_name': provinceName,
    };
  }

  /// Kiểm tra có voucher không
  bool get hasVoucher => voucherInfo['has_voucher'] == true;

  /// Kiểm tra có freeship không
  bool get hasFreeShipping => shippingInfo['has_free_shipping'] == true;

  /// Lấy thông tin voucher
  String get voucherDetails => voucherInfo['voucher_details'] as String? ?? '';

  /// Lấy thông tin freeship
  String get freeShipDetails => shippingInfo['free_ship_details'] as String? ?? '';

  @override
  String toString() {
    return 'SameShopProduct(id: $id, name: $name, price: $price, shopId: $shopId)';
  }
}
