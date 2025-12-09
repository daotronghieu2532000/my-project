/// Model cho cấu hình bonus linh hoạt
class BonusConfig {
  final bool status;
  final int bonusAmount;
  final double discountPercent;
  final int maxDiscountAmount;
  final String dialogTitle;
  final String dialogMessage;
  final String dialogButtonText;
  final List<BonusShop> eligibleShops;

  BonusConfig({
    required this.status,
    required this.bonusAmount,
    required this.discountPercent,
    required this.maxDiscountAmount,
    required this.dialogTitle,
    required this.dialogMessage,
    required this.dialogButtonText,
    required this.eligibleShops,
  });

  factory BonusConfig.fromJson(Map<String, dynamic> json) {
    return BonusConfig(
      status: json['status'] == 1,
      bonusAmount: json['bonus_amount'] as int,
      discountPercent: (json['discount_percent'] as num).toDouble(),
      maxDiscountAmount: json['max_discount_amount'] as int,
      dialogTitle: json['dialog_title'] as String,
      dialogMessage: json['dialog_message'] as String,
      dialogButtonText: json['dialog_button_text'] as String,
      eligibleShops: (json['eligible_shops'] as List?)
              ?.map((e) => BonusShop.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// Config mặc định (fallback khi API fail)
  factory BonusConfig.defaultConfig() {
    return BonusConfig(
      status: true,
      bonusAmount: 200000,
      discountPercent: 10.0,
      maxDiscountAmount: 200000,
      dialogTitle: 'Cảm ơn bạn đã tin tưởng!',
      dialogMessage:
          'Chúc mừng bạn đã tải ứng dụng và đăng nhập thành công! Chúng tôi xin gửi tặng bạn',
      dialogButtonText: 'Bắt đầu mua sắm',
      eligibleShops: [
        BonusShop(shopId: 32373, shopName: 'Công ty Cổ phần Sóc Đỏ', displayOrder: 1),
        BonusShop(shopId: 23933, shopName: 'Socdo Choice', displayOrder: 2),
        BonusShop(shopId: 36893, shopName: 'JUDYDOOL', displayOrder: 3),
        BonusShop(shopId: 35683, shopName: 'Công ty cổ phần Sóc Đỏ', displayOrder: 4),
        BonusShop(shopId: 35681, shopName: 'Công ty Cổ phần Sóc Đỏ', displayOrder: 5),
      ],
    );
  }
}

/// Model cho shop được áp dụng bonus
class BonusShop {
  final int shopId;
  final String shopName;
  final int displayOrder;

  BonusShop({
    required this.shopId,
    required this.shopName,
    required this.displayOrder,
  });

  factory BonusShop.fromJson(Map<String, dynamic> json) {
    return BonusShop(
      shopId: json['shop_id'] as int,
      shopName: json['shop_name'] as String,
      displayOrder: json['display_order'] as int,
    );
  }
}

