// Image URL normalizer
// Hỗ trợ CDN: https://socdo.cdn.vccloud.vn/
// Fallback về https://socdo.vn/ nếu CDN lỗi (được xử lý ở Image widget)
String? _fixImageUrl(String? rawUrl) {
  if (rawUrl == null) return null;
  String url = rawUrl.trim();
  if (url.isEmpty) return null;
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

class ProductSuggest {
  final int id;
  final String name;
  final String? image;
  final String? thumbnail;
  final int price;
  final int? oldPrice;
  final double? discount;
  final int? stock;
  final String? description;
  final String? brand;
  final String? category;
  final double? rating;
  final int? sold;
  final int? totalReviews;
  final String? shopId;
  final String? shopName;
  final bool isFreeship;
  final bool isRecommended;
  final int? weight;
  final String? unit;
  final List<String>? badges;
  final String? locationText;
  final String? warehouseName;
  final String? provinceName;
  final String? voucherIcon;
  final String? freeshipIcon;
  final String? chinhhangIcon;
  final String? starHtml;
  final String? priceThanhvien;

  const ProductSuggest({
    required this.id,
    required this.name,
    this.image,
    this.thumbnail,
    required this.price,
    this.oldPrice,
    this.discount,
    this.stock,
    this.description,
    this.brand,
    this.category,
    this.rating,
    this.sold,
    this.totalReviews,
    this.shopId,
    this.shopName,
    this.isFreeship = false,
    this.isRecommended = false,
    this.weight,
    this.unit,
    this.badges,
    this.locationText,
    this.warehouseName,
    this.provinceName,
    this.voucherIcon,
    this.freeshipIcon,
    this.chinhhangIcon,
    this.starHtml,
    this.priceThanhvien,
  });

  factory ProductSuggest.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int from String or int
    int? safeParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
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

    return ProductSuggest(
      id: safeParseInt(json['id']) ?? safeParseInt(json['product_id']) ?? 0,
      name: json['name'] as String? ?? json['tieu_de'] as String? ?? json['title'] as String? ?? json['product_name'] as String? ?? 'Sản phẩm',
      image: json['image'] as String? ?? json['minh_hoa'] as String? ?? json['image_url'] as String?,
      thumbnail: json['thumbnail'] as String? ?? json['thumb'] as String?,
      price: safeParseInt(json['price']) ?? safeParseInt(json['gia_moi']) ?? safeParseInt(json['sale_price']) ?? safeParseInt(json['current_price']) ?? 0,
      oldPrice: safeParseInt(json['old_price']) ?? safeParseInt(json['gia_cu']) ?? safeParseInt(json['original_price']) ?? safeParseInt(json['list_price']),
      discount: safeParseDouble(json['discount']) ?? safeParseDouble(json['discount_percent']),
      stock: safeParseInt(json['stock']) ?? safeParseInt(json['quantity']) ?? safeParseInt(json['available_stock']) ?? safeParseInt(json['kho']),
      description: json['description'] as String? ?? json['noi_bat'] as String? ?? json['desc'] as String?,
      brand: json['brand'] as String? ?? json['brand_name'] as String? ?? json['thuong_hieu'] as String?,
      category: json['category'] as String? ?? json['cat']?.toString() ?? json['category_name'] as String?,
      rating: safeParseDouble(json['rating']) ?? safeParseDouble(json['average_rating']) ?? safeParseDouble(json['avg_rating']),
      sold: safeParseInt(json['sold']) ?? safeParseInt(json['sold_count']) ?? safeParseInt(json['quantity_sold']) ?? safeParseInt(json['ban']),
      totalReviews: safeParseInt(json['total_reviews']) ?? safeParseInt(json['reviews_count']),
      shopId: json['shop_id']?.toString() ?? json['shop']?.toString(),
      shopName: json['shop_name'] as String?,
      isFreeship: json['is_freeship'] as bool? ?? json['free_shipping'] as bool? ?? false,
      isRecommended: json['is_recommended'] as bool? ?? json['recommended'] as bool? ?? false,
      weight: safeParseInt(json['weight']),
      unit: json['unit'] as String?,
      badges: json['badges'] != null ? List<String>.from(json['badges']) : null,
      locationText: json['location_text'] as String?,
      warehouseName: json['warehouse_name'] as String?,
      provinceName: json['province_name'] as String?,
      voucherIcon: json['voucher_icon'] as String?,
      freeshipIcon: json['freeship_icon'] as String?,
      chinhhangIcon: json['chinhhang_icon'] as String?,
      starHtml: json['star_html'] as String?,
      priceThanhvien: json['price_thanhvien'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'thumbnail': thumbnail,
      'price': price,
      'old_price': oldPrice,
      'discount': discount,
      'stock': stock,
      'description': description,
      'brand': brand,
      'category': category,
      'rating': rating,
      'sold': sold,
      'total_reviews': totalReviews,
      'shop_id': shopId,
      'shop_name': shopName,
      'is_freeship': isFreeship,
      'is_recommended': isRecommended,
      'weight': weight,
      'unit': unit,
      'badges': badges,
      'location_text': locationText,
      'warehouse_name': warehouseName,
      'province_name': provinceName,
      'voucher_icon': voucherIcon,
      'freeship_icon': freeshipIcon,
      'chinhhang_icon': chinhhangIcon,
      'star_html': starHtml,
      'price_thanhvien': priceThanhvien,
    };
  }

  ProductSuggest copyWith({
    int? id,
    String? name,
    String? image,
    String? thumbnail,
    int? price,
    int? oldPrice,
    double? discount,
    int? stock,
    String? description,
    String? brand,
    String? category,
    double? rating,
    int? sold,
    int? totalReviews,
    String? shopId,
    String? shopName,
    bool? isFreeship,
    bool? isRecommended,
    int? weight,
    String? unit,
    List<String>? badges,
    String? locationText,
    String? warehouseName,
    String? provinceName,
    String? voucherIcon,
    String? freeshipIcon,
    String? chinhhangIcon,
    String? starHtml,
    String? priceThanhvien,
  }) {
    return ProductSuggest(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      thumbnail: thumbnail ?? this.thumbnail,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      discount: discount ?? this.discount,
      stock: stock ?? this.stock,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      sold: sold ?? this.sold,
      totalReviews: totalReviews ?? this.totalReviews,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      isFreeship: isFreeship ?? this.isFreeship,
      isRecommended: isRecommended ?? this.isRecommended,
      weight: weight ?? this.weight,
      unit: unit ?? this.unit,
      badges: badges ?? this.badges,
      locationText: locationText ?? this.locationText,
      warehouseName: warehouseName ?? this.warehouseName,
      provinceName: provinceName ?? this.provinceName,
      voucherIcon: voucherIcon ?? this.voucherIcon,
      freeshipIcon: freeshipIcon ?? this.freeshipIcon,
      chinhhangIcon: chinhhangIcon ?? this.chinhhangIcon,
      starHtml: starHtml ?? this.starHtml,
      priceThanhvien: priceThanhvien ?? this.priceThanhvien,
    );
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

  /// Lấy URL hình ảnh ưu tiên với domain đúng
  String? get imageUrl {
    final imgUrl = image ?? thumbnail;
    return _fixImageUrl(imgUrl);
  }

  /// Format đánh giá
  String get formattedRating {
    if (rating == null) return '';
    return rating!.toStringAsFixed(1);
  }

  /// Format tổng đánh giá
  String get formattedTotalReviews {
    if (totalReviews == null) return '';
    if (totalReviews! >= 1000) {
      final double inK = totalReviews! / 1000.0;
      String s = inK.toStringAsFixed(inK.truncateToDouble() == inK ? 0 : 1);
      return '${s}k+';
    }
    return totalReviews.toString();
  }

  @override
  String toString() {
    return 'ProductSuggest(id: $id, name: $name, price: $price, shopName: $shopName)';
  }
}
