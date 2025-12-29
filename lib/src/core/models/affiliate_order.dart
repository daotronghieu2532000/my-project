class AffiliateOrderProduct {
  final int spId;
  final String title;
  final int quantity;
  final double price;
  final double commission;
  final String size;
  final String color;

  AffiliateOrderProduct({
    required this.spId,
    required this.title,
    required this.quantity,
    required this.price,
    required this.commission,
    required this.size,
    required this.color,
  });

  factory AffiliateOrderProduct.fromJson(Map<String, dynamic> json) {
    return AffiliateOrderProduct(
      spId: json['sp_id'] ?? 0,
      title: json['name'] ?? json['title'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      commission: (json['commission'] ?? 0).toDouble(),
      size: json['size'] ?? '',
      color: json['color'] ?? '',
    );
  }

  String get variant {
    final parts = <String>[];
    if (size.isNotEmpty) parts.add(size);
    if (color.isNotEmpty) parts.add(color);
    return parts.isEmpty ? '' : parts.join(', ');
  }
}

class OrderStatus {
  final int code;
  final String text;
  final String color;

  OrderStatus({
    required this.code,
    required this.text,
    required this.color,
  });

  factory OrderStatus.fromJson(Map<String, dynamic> json) {
    return OrderStatus(
      code: json['code'] ?? 0,
      text: json['text'] ?? '',
      color: json['color'] ?? '#808080',
    );
  }
}

class AffiliateOrder {
  final int orderId;
  final String maDon;
  final List<AffiliateOrderProduct> products;
  final double totalAmount;
  final double totalCommission;
  final OrderStatus status;
  final String createdAt;
  final bool commissionPaid;

  AffiliateOrder({
    required this.orderId,
    required this.maDon,
    required this.products,
    required this.totalAmount,
    required this.totalCommission,
    required this.status,
    required this.createdAt,
    required this.commissionPaid,
  });

  factory AffiliateOrder.fromJson(Map<String, dynamic> json) {
    final productsList = json['products'] as List? ?? [];
    
    return AffiliateOrder(
      orderId: json['order_id'] ?? 0,
      maDon: json['ma_don'] ?? '',
      products: productsList
          .map((item) => AffiliateOrderProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      totalCommission: (json['commission'] ?? json['total_commission'] ?? 0).toDouble(),
      status: OrderStatus.fromJson(json['status'] ?? {}),
      createdAt: json['date_post_formatted'] ?? json['created_at'] ?? '',
      commissionPaid: json['commission_status'] == 'completed' || (json['commission_paid'] ?? false),
    );
  }
}

