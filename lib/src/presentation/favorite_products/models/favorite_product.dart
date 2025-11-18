class FavoriteProduct {
  final int id;
  final String name;
  final String? brand;
  final String? store;
  final String imageUrl;
  final int price;
  final int? oldPrice;
  final double rating;
  final int reviewCount;
  final bool isInStock;
  final String? productCode;
  final int? shopId;
  final String? shopName;
  final int favoriteId;
  final List<String> badges;
  final String? voucherIcon;
  final String? freeshipIcon;
  final String? chinhhangIcon;
  final String? warehouseName;
  final String? provinceName;
  final String productUrl;
  final int discountPercent;
  final int soldCount;

  const FavoriteProduct({
    required this.id,
    required this.name,
    this.brand,
    this.store,
    required this.imageUrl,
    required this.price,
    this.oldPrice,
    required this.rating,
    required this.reviewCount,
    required this.isInStock,
    this.productCode,
    this.shopId,
    this.shopName,
    required this.favoriteId,
    required this.badges,
    this.voucherIcon,
    this.freeshipIcon,
    this.chinhhangIcon,
    this.warehouseName,
    this.provinceName,
    required this.productUrl,
    required this.discountPercent,
    required this.soldCount,
  });

  factory FavoriteProduct.fromJson(Map<String, dynamic> json) {
    return FavoriteProduct(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['tieu_de'] as String,
      brand: json['thuong_hieu'] as String?,
      store: json['shop_name'] as String?,
      imageUrl: json['minh_hoa'] as String? ?? json['image_url'] as String? ?? 'https://socdo.vn/images/no-images.jpg',
      price: int.tryParse(json['gia_moi']?.toString() ?? '0') ?? 0,
      oldPrice: int.tryParse(json['gia_cu']?.toString() ?? '0'),
      rating: _parseDouble(json['avg_rating']) ?? 0.0,
      reviewCount: _parseInt(json['total_reviews']) ?? 0,
      isInStock: (int.tryParse(json['kho']?.toString() ?? '0') ?? 0) > 0,
      productCode: json['ma_sanpham'] as String?,
      shopId: int.tryParse(json['shop']?.toString() ?? '0'),
      shopName: json['shop_name'] as String?,
      favoriteId: int.tryParse(json['favorite_id']?.toString() ?? '0') ?? 0,
      badges: (json['badges'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      voucherIcon: json['voucher_icon'] as String?,
      freeshipIcon: json['freeship_icon'] as String?,
      chinhhangIcon: json['chinhhang_icon'] as String?,
      warehouseName: json['warehouse_name'] as String?,
      provinceName: json['province_name'] as String?,
      productUrl: json['product_url'] as String? ?? '',
      discountPercent: int.tryParse(json['discount_percent']?.toString() ?? '0') ?? 0,
      soldCount: _parseInt(json['sold_count']) ?? _parseInt(json['ban']) ?? 0,
    );
  }

  // Helper methods để parse an toàn
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    if (value is num) return value.toDouble();
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) return value.toInt();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tieu_de': name,
      'thuong_hieu': brand,
      'shop_name': store,
      'image_url': imageUrl,
      'gia_moi': price,
      'gia_cu': oldPrice,
      'avg_rating': rating,
      'total_reviews': reviewCount,
      'kho': isInStock ? 1 : 0,
      'ma_sanpham': productCode,
      'shop': shopId,
      'favorite_id': favoriteId,
      'badges': badges,
      'voucher_icon': voucherIcon,
      'freeship_icon': freeshipIcon,
      'chinhhang_icon': chinhhangIcon,
      'warehouse_name': warehouseName,
      'province_name': provinceName,
      'product_url': productUrl,
      'discount_percent': discountPercent,
      'sold_count': soldCount,
    };
  }

  // Sample data để test (sẽ được thay thế bằng API thực tế)
  static List<FavoriteProduct> get sampleProducts => [
    FavoriteProduct(
      id: 1,
      name: 'Viên uống Collagen Youtheory Type 1 2 & 3 của Mỹ 126477',
      brand: 'Youtheory',
      store: 'Xuân Xuân Minh Pharma',
      imageUrl: 'lib/src/core/assets/images/product_1.png',
      price: 620000,
      oldPrice: 750000,
      rating: 4.8,
      reviewCount: 33,
      isInStock: true,
      productCode: '126477',
      shopId: 1,
      shopName: 'Xuân Xuân Minh Pharma',
      favoriteId: 1,
      badges: ['-17%', 'Voucher', 'Freeship'],
      voucherIcon: 'Voucher',
      freeshipIcon: 'Freeship',
      chinhhangIcon: 'Chính hãng',
      warehouseName: 'Kho Hà Nội',
      provinceName: 'Hà Nội',
      productUrl: 'https://socdo.vn/san-pham/1/collagen-youtheory.html',
      discountPercent: 17,
      soldCount: 150,
    ),
    FavoriteProduct(
      id: 2,
      name: 'Viên uống Collagen Youtheory Type 1 2 & 3 của Mỹ, 390 viên 278052',
      brand: 'Youtheory',
      store: 'Huệ Store',
      imageUrl: 'lib/src/core/assets/images/product_2.png',
      price: 570000,
      oldPrice: 650000,
      rating: 4.6,
      reviewCount: 9,
      isInStock: false,
      productCode: '278052',
      shopId: 2,
      shopName: 'Huệ Store',
      favoriteId: 2,
      badges: ['-12%', 'Voucher'],
      voucherIcon: 'Voucher',
      freeshipIcon: null,
      chinhhangIcon: 'Chính hãng',
      warehouseName: 'Kho TP.HCM',
      provinceName: 'TP.HCM',
      productUrl: 'https://socdo.vn/san-pham/2/collagen-youtheory-390.html',
      discountPercent: 12,
      soldCount: 89,
    ),
  ];
}
