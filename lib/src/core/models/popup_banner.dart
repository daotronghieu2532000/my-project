class PopupBanner {
  final int id;
  final String title;
  final String imageUrl;
  final String? targetUrl;
  final int? productId; // Thêm productId từ API (giống BannerModel)
  final DateTime? startAt;
  final DateTime? endAt;
  final int priority;
  final int displayLimitPerUser;
  final int clickCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PopupBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.targetUrl,
    this.productId,
    this.startAt,
    this.endAt,
    required this.priority,
    required this.displayLimitPerUser,
    required this.clickCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PopupBanner.fromJson(Map<String, dynamic> json) {
    return PopupBanner(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? '',
      targetUrl: json['target_url'],
      productId: json['product_id'] != null ? int.tryParse(json['product_id'].toString()) : null,
      startAt: json['start_at'] != null
          ? DateTime.tryParse(json['start_at'])
          : null,
      endAt: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'])
          : null,
      priority: json['priority'] ?? 0,
      displayLimitPerUser: json['display_limit_per_user'] ?? 1,
      clickCount: json['click_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'target_url': targetUrl,
      'product_id': productId,
      'start_at': startAt?.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'priority': priority,
      'display_limit_per_user': displayLimitPerUser,
      'click_count': clickCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

