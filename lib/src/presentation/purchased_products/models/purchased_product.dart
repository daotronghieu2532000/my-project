class PurchasedProduct {
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
  final List<String> badges;
  final String? voucherIcon;
  final String? freeshipIcon;
  final String? chinhhangIcon;
  final String? warehouseName;
  final String? provinceName;
  final String productUrl;
  final int discountPercent;
  final int soldCount;
  final int quantity; // Số lượng đã mua
  final String? size;
  final String? color;
  final int variantId;
  final String orderId; // Mã đơn hàng
  final int orderDate; // Timestamp ngày mua

  const PurchasedProduct({
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
    required this.badges,
    this.voucherIcon,
    this.freeshipIcon,
    this.chinhhangIcon,
    this.warehouseName,
    this.provinceName,
    required this.productUrl,
    required this.discountPercent,
    required this.soldCount,
    required this.quantity,
    this.size,
    this.color,
    required this.variantId,
    required this.orderId,
    required this.orderDate,
  });

  factory PurchasedProduct.fromOrderProduct(Map<String, dynamic> productJson, Map<String, dynamic> orderJson) {
    // Tính discount percent
    final price = productJson['price'] as int? ?? 0;
    final oldPrice = productJson['old_price'] as int? ?? 0;
    final discountPercent = oldPrice > 0 && oldPrice > price
        ? ((oldPrice - price) / oldPrice * 100).round()
        : 0;

    // Fake rating và review count (giống favorite_product_card)
    final random = productJson['id'] as int? ?? 0;
    final isExpensive = price >= 1000000;
    final reviews = isExpensive 
        ? ((random % 21) + 5) // 5-25 for expensive products
        : ((random % 95) + 10); // 10-104 for normal products
    
    final sold = isExpensive
        ? ((random % 21) + 5) // 5-25 for expensive products
        : ((random % 90) + 15); // 15-104 for normal products

    // Parse badges từ product data hoặc tạo mặc định
    final badges = <String>[];
    if (discountPercent > 0) {
      badges.add('-$discountPercent%');
    }

    return PurchasedProduct(
      id: productJson['id'] as int? ?? 0,
      name: productJson['name'] as String? ?? '',
      brand: null,
      store: productJson['shop_name'] as String?,
      imageUrl: productJson['image'] as String? ?? 'https://socdo.vn/images/no-images.jpg',
      price: price,
      oldPrice: oldPrice > 0 ? oldPrice : null,
      rating: 5.0,
      reviewCount: reviews,
      isInStock: true, // Sản phẩm đã mua nên giả sử còn hàng
      productCode: null,
      shopId: int.tryParse(productJson['shop_name']?.toString() ?? '0'),
      shopName: productJson['shop_name'] as String?,
      badges: badges,
      voucherIcon: null,
      freeshipIcon: null,
      chinhhangIcon: null,
      warehouseName: null,
      provinceName: null, // Có thể lấy từ order nếu có
      productUrl: productJson['product_url'] as String? ?? '',
      discountPercent: discountPercent,
      soldCount: sold,
      quantity: productJson['quantity'] as int? ?? 1,
      size: productJson['size'] as String?,
      color: productJson['color'] as String?,
      variantId: productJson['variant_id'] as int? ?? 0,
      orderId: orderJson['ma_don'] as String? ?? '',
      orderDate: orderJson['date_post'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'shop_name': store,
      'image': imageUrl,
      'price': price,
      'old_price': oldPrice,
      'rating': rating,
      'review_count': reviewCount,
      'is_in_stock': isInStock,
      'shop': shopId,
      'badges': badges,
      'product_url': productUrl,
      'discount_percent': discountPercent,
      'sold_count': soldCount,
      'quantity': quantity,
      'size': size,
      'color': color,
      'variant_id': variantId,
      'order_id': orderId,
      'order_date': orderDate,
    };
  }
}

