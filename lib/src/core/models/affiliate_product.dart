class CommissionInfo {
  final String variantId;
  final String type; // 'phantram' or 'tru'
  final double value;

  CommissionInfo({
    required this.variantId,
    required this.type,
    required this.value,
  });

  factory CommissionInfo.fromJson(Map<String, dynamic> json) {
    return CommissionInfo(
      variantId: json['variant_id']?.toString() ?? 'main',
      type: json['type'] ?? 'tru',
      value: (json['value'] ?? 0).toDouble(),
    );
  }

  String get displayCommission {
    if (type == 'phantram') {
      return '${value.toStringAsFixed(0)}%';
    } else {
      return '${value.toStringAsFixed(0)}đ';
    }
  }
}

class AffiliateProduct {
  final int id;
  final String name;
  final String slug;
  final String image;
  final double price;
  final double oldPrice;
  final int discountPercent;
  final int shopId;
  final List<int> categoryIds;
  final int brandId;
  final String brandName;
  final String productUrl;
  final List<CommissionInfo> commissionInfo;
  final String? shortLink;
  final String campaignName;
  final String priceFormatted;
  final String oldPriceFormatted;
  final int isFeatured;
  final int isFlashSale;
  final int createdAt;
  final int updatedAt;
  final bool _isFollowing;

  AffiliateProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.price,
    required this.oldPrice,
    required this.discountPercent,
    required this.shopId,
    required this.categoryIds,
    required this.brandId,
    required this.brandName,
    required this.productUrl,
    required this.commissionInfo,
    this.shortLink,
    required this.campaignName,
    required this.priceFormatted,
    required this.oldPriceFormatted,
    required this.isFeatured,
    required this.isFlashSale,
    required this.createdAt,
    required this.updatedAt,
    required bool isFollowing,
  }) : _isFollowing = isFollowing;
  
  bool get isFollowing => _isFollowing;

  factory AffiliateProduct.fromJson(Map<String, dynamic> json) {
    final commissionList = json['commission_info'] as List? ?? [];
    final categoryList = json['category_ids'] as List? ?? [];
    
    // Fix image URL - hỗ trợ CDN và sửa api.socdo.vn
    String imageUrl = json['image'] ?? '';
    if (imageUrl.isNotEmpty) {
      // Nếu chứa api.socdo.vn, thay bằng CDN domain
      if (imageUrl.contains('api.socdo.vn')) {
        imageUrl = imageUrl.replaceAll('api.socdo.vn', 'socdo.cdn.vccloud.vn');
      }
      // Nếu là relative path và chưa có domain, thêm CDN domain
      else if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        final cleanUrl = imageUrl.replaceFirst(RegExp(r'^/'), '');
        imageUrl = 'https://socdo.cdn.vccloud.vn/$cleanUrl';
      }
      // Nếu chứa socdo.vn nhưng không phải CDN, thay bằng CDN
      else if (imageUrl.contains('socdo.vn') && !imageUrl.contains('cdn.vccloud.vn')) {
        imageUrl = imageUrl.replaceAll('socdo.vn', 'socdo.cdn.vccloud.vn');
      }
    }
    
    // Fix product URL - replace api.socdo.vn with socdo.vn
    String productUrl = json['product_url'] ?? '';
    if (productUrl.contains('api.socdo.vn')) {
      productUrl = productUrl.replaceAll('api.socdo.vn', 'socdo.vn');
    }
    
    return AffiliateProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      image: imageUrl,
      price: (json['price'] ?? 0).toDouble(),
      oldPrice: (json['old_price'] ?? 0).toDouble(),
      discountPercent: json['discount_percent'] ?? 0,
      shopId: json['shop_id'] ?? 0,
      categoryIds: categoryList.map((e) => e as int).toList(),
      brandId: json['brand_id'] ?? 0,
      brandName: json['brand_name'] ?? '',
      productUrl: productUrl,
      commissionInfo: commissionList
          .map((item) => CommissionInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      shortLink: json['short_link'],
      campaignName: json['campaign_name'] ?? '',
      priceFormatted: json['price_formatted'] ?? '',
      oldPriceFormatted: json['old_price_formatted'] ?? '',
      isFeatured: json['is_featured'] ?? 0,
      isFlashSale: json['is_flash_sale'] ?? 0,
      createdAt: json['created_at'] ?? 0,
      updatedAt: json['updated_at'] ?? 0,
      isFollowing: json['is_following'] ?? false,
    );
  }

  String get title => name;
  String get link => productUrl;
  
  double? get discount => discountPercent > 0 ? discountPercent.toDouble() : null;

  String get mainCommission {
    if (commissionInfo.isEmpty) return 'Chưa có hoa hồng';
    return commissionInfo.first.displayCommission;
  }

  bool get hasLink => shortLink != null && shortLink!.isNotEmpty;
}

