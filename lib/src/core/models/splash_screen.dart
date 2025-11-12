class SplashScreenModel {
  final int id;
  final String title;
  final String imageUrl;
  final int priority;
  final int? startAt;
  final int? endAt;
  final int createdAt;
  final int updatedAt;

  SplashScreenModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.priority,
    this.startAt,
    this.endAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SplashScreenModel.fromJson(Map<String, dynamic> json) {
    return SplashScreenModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? '',
      priority: json['priority'] ?? 0,
      startAt: json['start_at'] != null ? int.tryParse(json['start_at'].toString()) : null,
      endAt: json['end_at'] != null ? int.tryParse(json['end_at'].toString()) : null,
      createdAt: json['created_at'] != null ? int.tryParse(json['created_at'].toString()) ?? 0 : 0,
      updatedAt: json['updated_at'] != null ? int.tryParse(json['updated_at'].toString()) ?? 0 : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'priority': priority,
      'start_at': startAt,
      'end_at': endAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

