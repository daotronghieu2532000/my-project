class Brand {
  final int id;
  final int shopId;
  final String name;
  final int order;
  final int idThuongHieuSocdo;
  final String logo;
  final String logoOriginal;
  final String link;
  final String url;
  final int productCount;
  final int status;
  final int approvalStatus;
  final Map<String, dynamic>? shopInfo;

  Brand({
    required this.id,
    required this.shopId,
    required this.name,
    required this.order,
    required this.idThuongHieuSocdo,
    required this.logo,
    required this.logoOriginal,
    required this.link,
    required this.url,
    required this.productCount,
    required this.status,
    required this.approvalStatus,
    this.shopInfo,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] ?? 0,
      shopId: json['shop_id'] ?? 0,
      name: json['name'] ?? '',
      order: json['order'] ?? 0,
      idThuongHieuSocdo: json['id_thuonghieu_socdo'] ?? 0,
      logo: json['logo'] ?? '',
      logoOriginal: json['logo_original'] ?? '',
      link: json['link'] ?? '',
      url: json['url'] ?? '',
      productCount: json['product_count'] ?? 0,
      status: json['status'] ?? 0,
      approvalStatus: json['approval_status'] ?? 0,
      shopInfo: json['shop_info'] != null 
          ? Map<String, dynamic>.from(json['shop_info'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'order': order,
      'id_thuonghieu_socdo': idThuongHieuSocdo,
      'logo': logo,
      'logo_original': logoOriginal,
      'link': link,
      'url': url,
      'product_count': productCount,
      'status': status,
      'approval_status': approvalStatus,
      if (shopInfo != null) 'shop_info': shopInfo,
    };
  }
}

