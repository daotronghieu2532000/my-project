import 'dart:convert';

// Image URL normalizer
String? _fixImageUrl(String? rawUrl) {
  if (rawUrl == null) return null;
  String url = rawUrl.trim();
  if (url.isEmpty) return null;
  if (url.startsWith('@')) url = url.substring(1);
  if (url.startsWith('/uploads/') || url.startsWith('uploads/')) {
    url = url.replaceFirst(RegExp(r'^/'), '');
    return 'https://socdo.vn/$url';
  }
  if (url.startsWith('http://') || url.startsWith('https://')) {
    url = url.replaceFirst('://api.socdo.vn', '://socdo.vn');
    url = url.replaceFirst('://www.api.socdo.vn', '://socdo.vn');
    url = url.replaceFirst('://www.socdo.vn', '://socdo.vn');
    if (url.startsWith('http://')) url = url.replaceFirst('http://', 'https://');
    return url;
  }
  url = url.replaceFirst(RegExp(r'^/'), '');
  return 'https://socdo.vn/$url';
}

class Voucher {
  final int id;
  final String code;
  final String title;
  final String description;
  final String type; // 'platform' hoặc 'shop'
  final String? shopId;
  final String? shopName;
  final String? shopLogo;
  final String? userId;
  final String? image;
  final String? thumbnail;
  final double? discountValue;
  final double? minOrderValue;
  final double? maxDiscountValue;
  final String discountType; // 'percentage' hoặc 'fixed'
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final int? usageLimit;
  final int? usedCount;
  final String? terms;
  final List<String>? applicableProducts;
  final List<String>? applicableCategories;
  // Chi tiết sản phẩm áp dụng (id, title, image)
  final List<Map<String, String>>? applicableProductsDetail;
  // Loại voucher: 'all' (áp dụng tất cả sản phẩm) hoặc 'sanpham' (áp dụng sản phẩm cụ thể)
  final String? voucherType;
  // Cho biết voucher áp dụng cho tất cả sản phẩm hay không
  final bool isAllProducts;
  // Danh sách shop được phép sử dụng voucher platform (socdo_choice_shops)
  // Format: {"main_shop": 23933, "shops": [23933, 39046]}
  final Map<String, dynamic>? socdoChoiceShops;

  const Voucher({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    this.shopId,
    this.shopName,
    this.shopLogo,
    this.userId,
    this.image,
    this.thumbnail,
    this.discountValue,
    this.minOrderValue,
    this.maxDiscountValue,
    required this.discountType,
    this.startDate,
    this.endDate,
    required this.isActive,
    this.usageLimit,
    this.usedCount,
    this.terms,
    this.applicableProducts,
    this.applicableCategories,
    this.applicableProductsDetail,
    this.voucherType,
    this.isAllProducts = false,
    this.socdoChoiceShops,
  });

  /// Helper method để parse int an toàn từ String hoặc int
  static int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  /// Helper method để parse double an toàn từ String, int hoặc double
  static double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Helper method để parse string list an toàn
  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) {
        if (e is Map && e.containsKey('id')) {
          return e['id'].toString();
        }
        return e.toString();
      }).toList();
    }
    if (value is String) {
      return [value];
    }
    return null;
  }

  // Parse list chi tiết sản phẩm từ API (id, tieu_de, minh_hoa)
  static List<Map<String, String>>? _parseProductDetailList(dynamic value) {
    if (value == null || value is! List) return null;
    final List<Map<String, String>> result = [];
    for (final item in value) {
      if (item is Map) {
        final id = item['id']?.toString();
        final title = (item['tieu_de'] ?? item['name'] ?? item['title'])?.toString();
        final image = item['minh_hoa']?.toString();
        if (id != null) {
          result.add({
            'id': id,
            'title': title ?? '',
            'image': _fixImageUrl(image) ?? '',
          });
        }
      }
    }
    return result.isEmpty ? null : result;
  }

  /// Helper method để parse discount type từ API
  static String _parseDiscountType(dynamic value) {
    if (value == null) return 'percentage';
    final str = value.toString().toLowerCase();
    
    // API trả về 'phantram', 'percentage' hoặc 'tru' (giảm trực tiếp)
    if (str == 'phantram' || str == 'percentage') {
      return 'percentage';
    } else if (str == 'giatien' || str == 'fixed' || str == 'amount' || str == 'tru') {
      return 'fixed';
    }
    
    // Mặc định là percentage
    return 'percentage';
  }

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: _safeParseInt(json['id'] ?? json['voucher_id']) ?? 0,
      code: json['code'] as String? ?? json['voucher_code'] as String? ?? json['ma'] as String? ?? '',
      title: json['title'] as String? ?? json['name'] as String? ?? json['voucher_name'] as String? ?? json['tieu_de'] as String? ?? json['ma'] as String? ?? '',
      description: json['description'] as String? ?? json['desc'] as String? ?? json['mo_ta'] as String? ?? '',
      type: json['type'] as String? ?? json['voucher_type'] as String? ?? json['loai'] as String? ?? 'platform',
      shopId: json['shop_id']?.toString() ?? json['shop']?.toString(),
      shopName: json['shop_name'] as String? ?? json['ten_shop'] as String? ?? 
                (json['shop_info'] != null ? (json['shop_info'] as Map<String, dynamic>)['name'] as String? : null),
      shopLogo: json['shop_logo'] as String? ?? json['shop_logo_url'] as String? ?? json['logo_shop'] as String? ??
                (json['shop_info'] != null ? (json['shop_info'] as Map<String, dynamic>)['avatar'] as String? : null),
      userId: json['user_id']?.toString(),
      image: json['image'] as String? ?? json['image_url'] as String? ?? json['minh_hoa'] as String?,
      thumbnail: json['thumbnail'] as String? ?? json['thumb'] as String?,
      discountValue: _safeParseDouble(json['discount_value'] ?? json['discount_amount'] ?? json['giam']),
      minOrderValue: _safeParseDouble(json['min_order_value'] ?? json['minimum_amount'] ?? json['min_price']),
      maxDiscountValue: _safeParseDouble(json['max_discount_value'] ?? json['max_discount_amount'] ?? json['giam_toi_da']),
      discountType: _parseDiscountType(json['discount_type'] ?? json['loai']),
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : 
                 json['start'] != null ? DateTime.fromMillisecondsSinceEpoch(_safeParseInt(json['start'])! * 1000) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : 
               json['expired'] != null ? DateTime.fromMillisecondsSinceEpoch(_safeParseInt(json['expired'])! * 1000) : null,
      isActive: json['is_active'] as bool? ?? json['active'] as bool? ?? json['can_apply'] as bool? ?? true,
      usageLimit: _safeParseInt(json['usage_limit'] ?? json['limit'] ?? json['max_global_uses']),
      usedCount: _safeParseInt(json['used_count'] ?? json['used'] ?? json['current_uses']),
      terms: json['terms'] as String? ?? json['conditions'] as String? ?? json['dieu_kien'] as String?,
      applicableProducts: _parseStringList(json['applicable_products']),
      applicableCategories: _parseStringList(json['applicable_categories']),
      applicableProductsDetail: _parseProductDetailList(json['applicable_products']),
      voucherType: json['voucher_type'] as String? ?? json['kieu'] as String?,
      isAllProducts: json['is_all_products'] as bool? ?? (json['kieu'] as String?) == 'all',
      socdoChoiceShops: _parseSocdoChoiceShops(json['socdo_choice_shops']),
    );
  }
  
  /// Parse socdo_choice_shops từ JSON (có thể là String hoặc Map)
  static Map<String, dynamic>? _parseSocdoChoiceShops(dynamic value) {
    if (value == null) return null;
    
    if (value is Map) {
      return value as Map<String, dynamic>;
    }
    
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded as Map<String, dynamic>;
        }
      } catch (e) {
        // Bỏ qua nếu parse lỗi
      }
    }
    
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'description': description,
      'type': type,
      'shop_id': shopId,
      'shop_name': shopName,
      'shop_logo': shopLogo,
      'user_id': userId,
      'image': image,
      'thumbnail': thumbnail,
      'discount_value': discountValue,
      'min_order_value': minOrderValue,
      'max_discount_value': maxDiscountValue,
      'discount_type': discountType,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'terms': terms,
      'applicable_products': applicableProducts,
      'applicable_categories': applicableCategories,
      'applicable_products_detail': applicableProductsDetail,
      'voucher_type': voucherType,
      'is_all_products': isAllProducts,
      'socdo_choice_shops': socdoChoiceShops,
    };
  }

  Voucher copyWith({
    int? id,
    String? code,
    String? title,
    String? description,
    String? type,
    String? shopId,
    String? shopName,
    String? shopLogo,
    String? userId,
    String? image,
    String? thumbnail,
    double? discountValue,
    double? minOrderValue,
    double? maxDiscountValue,
    String? discountType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    int? usageLimit,
    int? usedCount,
    String? terms,
    List<String>? applicableProducts,
    List<String>? applicableCategories,
    List<Map<String, String>>? applicableProductsDetail,
    String? voucherType,
    bool? isAllProducts,
    Map<String, dynamic>? socdoChoiceShops,
  }) {
    return Voucher(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      shopLogo: shopLogo ?? this.shopLogo,
      userId: userId ?? this.userId,
      image: image ?? this.image,
      thumbnail: thumbnail ?? this.thumbnail,
      discountValue: discountValue ?? this.discountValue,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      maxDiscountValue: maxDiscountValue ?? this.maxDiscountValue,
      discountType: discountType ?? this.discountType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      usageLimit: usageLimit ?? this.usageLimit,
      usedCount: usedCount ?? this.usedCount,
      terms: terms ?? this.terms,
      applicableProducts: applicableProducts ?? this.applicableProducts,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      applicableProductsDetail: applicableProductsDetail ?? this.applicableProductsDetail,
      voucherType: voucherType ?? this.voucherType,
      isAllProducts: isAllProducts ?? this.isAllProducts,
      socdoChoiceShops: socdoChoiceShops ?? this.socdoChoiceShops,
    );
  }

  /// Lấy URL hình ảnh ưu tiên với domain đúng
  String? get imageUrl {
    final imgUrl = image ?? thumbnail;
    return _fixImageUrl(imgUrl);
  }

  /// Kiểm tra voucher có hết hạn không
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// Kiểm tra voucher có thể sử dụng không
  bool get canUse {
    return isActive && !isExpired && (usageLimit == null || (usedCount ?? 0) < usageLimit!);
  }

  /// Kiểm tra voucher có áp dụng được cho danh sách sản phẩm không
  bool appliesToProducts(List<int> productIds) {
    // Nếu voucher áp dụng cho tất cả sản phẩm
    if (isAllProducts || voucherType == 'all') {
      return true;
    }
    
    // Nếu voucher áp dụng cho sản phẩm cụ thể
    if (voucherType == 'sanpham' && applicableProducts != null && applicableProducts!.isNotEmpty) {
      final applicableIds = applicableProducts!.map((id) => int.tryParse(id) ?? 0).toList();
      // Kiểm tra xem có ít nhất một sản phẩm trong giỏ hàng nằm trong danh sách sản phẩm được áp dụng
      return productIds.any((productId) => applicableIds.contains(productId));
    }
    
    return false;
  }

  /// Tính số ngày còn lại
  int? get daysRemaining {
    if (endDate == null) return null;
    final now = DateTime.now();
    final difference = endDate!.difference(now).inDays;
    return difference > 0 ? difference : 0;
  }

  /// Format giá trị giảm giá
  String get formattedDiscount {
    if (discountValue == null) return '';
    
    if (discountType == 'percentage') {
      return '${discountValue!.toInt()}%';
    } else {
      return '${discountValue!.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
        (Match m) => '${m[1]},'
      )}₫';
    }
  }

  /// Format giá trị đơn hàng tối thiểu
  String get formattedMinOrder {
    if (minOrderValue == null) return '';
    return 'Đơn tối thiểu ${minOrderValue!.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},'
    )}₫';
  }

  @override
  String toString() {
    return 'Voucher(id: $id, code: $code, title: $title, type: $type, shopName: $shopName)';
  }
}

