import 'product_suggest.dart';

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

class BannerProducts {
  final int id;
  final int shopId;
  final String shopName;
  final String position; // dau_trang, giua_trang, cuoi_trang
  final String positionName;
  final String bannerUrl;
  final String? bannerLink;
  final String bannerType; // banner_doc hoặc banner_ngang
  final int bannerWidth;
  final int bannerHeight;
  final int displayStart;
  final int displayEnd;
  final int displayDays;
  final List<ProductSuggest> products;
  final int productCount;

  const BannerProducts({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.position,
    required this.positionName,
    required this.bannerUrl,
    this.bannerLink,
    required this.bannerType,
    required this.bannerWidth,
    required this.bannerHeight,
    required this.displayStart,
    required this.displayEnd,
    required this.displayDays,
    required this.products,
    required this.productCount,
  });

  factory BannerProducts.fromJson(Map<String, dynamic> json) {
    // Parse products list
    final productsList = json['products'] as List<dynamic>? ?? [];
    final products = productsList
        .map((p) => ProductSuggest.fromJson(p as Map<String, dynamic>))
        .toList();

    return BannerProducts(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      shopId: int.tryParse(json['shop_id']?.toString() ?? '0') ?? 0,
      shopName: json['shop_name'] as String? ?? '',
      position: json['position'] as String? ?? '',
      positionName: json['position_name'] as String? ?? '',
      bannerUrl: _fixImageUrl(json['banner_url'] as String?) ?? '',
      bannerLink: json['banner_link'] as String?,
      bannerType: json['banner_type'] as String? ?? 'banner_ngang',
      bannerWidth: int.tryParse(json['banner_width']?.toString() ?? '0') ?? 0,
      bannerHeight: int.tryParse(json['banner_height']?.toString() ?? '0') ?? 0,
      displayStart: int.tryParse(json['display_start']?.toString() ?? '0') ?? 0,
      displayEnd: int.tryParse(json['display_end']?.toString() ?? '0') ?? 0,
      displayDays: int.tryParse(json['display_days']?.toString() ?? '0') ?? 0,
      products: products,
      productCount: int.tryParse(json['product_count']?.toString() ?? '0') ?? products.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'shop_name': shopName,
      'position': position,
      'position_name': positionName,
      'banner_url': bannerUrl,
      'banner_link': bannerLink,
      'banner_type': bannerType,
      'banner_width': bannerWidth,
      'banner_height': bannerHeight,
      'display_start': displayStart,
      'display_end': displayEnd,
      'display_days': displayDays,
      'products': products.map((p) => p.toJson()).toList(),
      'product_count': productCount,
    };
  }

  /// Kiểm tra banner có còn hiệu lực không
  bool get isValid {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return displayEnd > now;
  }

  /// Kiểm tra có phải banner dọc không
  bool get isVerticalBanner => bannerType == 'banner_doc';

  /// Kiểm tra có phải banner ngang không
  bool get isHorizontalBanner => bannerType == 'banner_ngang';
}

