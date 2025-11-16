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

class FlashSaleProduct {
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
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isActive;
  final String? timeSlot; // 06:00, 12:00, 18:00, 00:00
  final String? status; // 'active', 'upcoming', 'ended'
  final double? rating;
  final int? sold;

  const FlashSaleProduct({
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
    this.startTime,
    this.endTime,
    required this.isActive,
    this.timeSlot,
    this.status,
    this.rating,
    this.sold,
  });

  factory FlashSaleProduct.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int from String or int
    int? safeParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
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

    // Helper function to parse DateTime from timestamp or string
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        // Handle both seconds and milliseconds timestamp
        if (value > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    // Calculate discount percentage if not provided
    double? calculateDiscount(int? price, int? oldPrice) {
      if (price == null || oldPrice == null || oldPrice <= 0) return null;
      return ((oldPrice - price) / oldPrice * 100).roundToDouble();
    }

    final price = safeParseInt(json['price']) ?? safeParseInt(json['gia']) ?? safeParseInt(json['gia_moi']) ?? safeParseInt(json['sale_price']) ?? safeParseInt(json['current_price']) ?? 0;
    final oldPrice = safeParseInt(json['old_price']) ?? safeParseInt(json['gia_cu']) ?? safeParseInt(json['original_price']) ?? safeParseInt(json['list_price']);
    final discount = safeParseDouble(json['discount']) ?? safeParseDouble(json['discount_percent']) ?? calculateDiscount(price, oldPrice);

    return FlashSaleProduct(
      id: safeParseInt(json['id']) ?? safeParseInt(json['product_id']) ?? 0,
      name: json['name'] as String? ?? json['tieu_de'] as String? ?? json['title'] as String? ?? json['product_name'] as String? ?? 'Sản phẩm',
      image: json['image'] as String? ?? json['image_url'] as String? ?? json['minh_hoa'] as String?,
      thumbnail: json['thumbnail'] as String? ?? json['thumb'] as String?,
      price: price,
      oldPrice: oldPrice,
      discount: discount,
      stock: safeParseInt(json['stock']) ?? safeParseInt(json['so_luong']) ?? safeParseInt(json['quantity']) ?? safeParseInt(json['available_stock']),
      description: json['description'] as String? ?? json['desc'] as String?,
      brand: json['brand'] as String? ?? json['brand_name'] as String?,
      category: json['category'] as String? ?? json['category_name'] as String?,
      startTime: parseDateTime(json['start_time']) ?? parseDateTime(json['date_start']),
      endTime: parseDateTime(json['end_time']) ?? parseDateTime(json['date_end']),
      isActive: json['is_active'] as bool? ?? json['active'] as bool? ?? (json['deal_status'] == 'active'),
      timeSlot: json['time_slot'] as String? ?? json['slot'] as String? ?? json['timeline'] as String?,
      status: json['status'] as String? ?? json['flash_status'] as String? ?? json['deal_status'] as String?,
      rating: safeParseDouble(json['rating']) ?? safeParseDouble(json['average_rating']),
      sold: safeParseInt(json['sold']) ?? safeParseInt(json['sold_count']) ?? safeParseInt(json['quantity_sold']),
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
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'is_active': isActive,
      'time_slot': timeSlot,
      'status': status,
      'rating': rating,
      'sold': sold,
    };
  }

  FlashSaleProduct copyWith({
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
    DateTime? startTime,
    DateTime? endTime,
    bool? isActive,
    String? timeSlot,
    String? status,
    double? rating,
    int? sold,
  }) {
    return FlashSaleProduct(
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
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      sold: sold ?? this.sold,
    );
  }

  /// Kiểm tra flash sale có đang diễn ra không
  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startTime != null && now.isBefore(startTime!)) return false;
    if (endTime != null && now.isAfter(endTime!)) return false;
    return true;
  }

  /// Tính thời gian còn lại (seconds)
  int? get timeRemaining {
    if (endTime == null) return null;
    final now = DateTime.now();
    final difference = endTime!.difference(now).inSeconds;
    return difference > 0 ? difference : 0;
  }

  /// Format thời gian còn lại
  String get formattedTimeRemaining {
    final remaining = timeRemaining;
    if (remaining == null || remaining <= 0) return 'Đã kết thúc';
    
    final hours = remaining ~/ 3600;
    final minutes = (remaining % 3600) ~/ 60;
    final seconds = remaining % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
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

  /// Lấy URL hình ảnh ưu tiên với domain đúng
  String? get imageUrl {
    final imgUrl = image ?? thumbnail;
    return _fixImageUrl(imgUrl);
  }

  @override
  String toString() {
    return 'FlashSaleProduct(id: $id, name: $name, price: $price, status: $status, timeSlot: $timeSlot)';
  }
}
