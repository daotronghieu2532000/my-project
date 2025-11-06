import 'package:flutter/material.dart';

class ProductBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;
  final EdgeInsets padding;

  const ProductBadge({
    super.key,
    required this.text,
    this.icon,
    this.backgroundColor = Colors.red,
    this.iconColor = Colors.white,
    this.iconSize = 9,
    this.padding = const EdgeInsets.all(3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon ?? Icons.info,
        size: iconSize,
        color: iconColor,
      ),
    );
  }
}

class ProductBadgesRow extends StatelessWidget {
  final List<String> badges;
  final double spacing;
  final double iconSize;
  final EdgeInsets padding;

  const ProductBadgesRow({
    super.key,
    required this.badges,
    this.spacing = 4,
    this.iconSize = 9,
    this.padding = const EdgeInsets.all(3),
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: badges.map((badge) {
        Color backgroundColor;
        IconData icon;

        // Xác định màu sắc và icon dựa trên loại badge
        if (badge.contains('%') || badge.contains('Giảm')) {
          backgroundColor = Colors.red;
          icon = Icons.local_offer;
        } else if (badge == 'Voucher') {
          backgroundColor = Colors.orange;
          icon = Icons.local_offer;
        } else if (badge.contains('Freeship') || badge.contains('ship')) {
          backgroundColor = Colors.green;
          icon = Icons.local_shipping;
        } else if (badge == 'Flash Sale' || badge == 'FLASH SALE') {
          backgroundColor = Colors.purple;
          icon = Icons.flash_on;
        } else if (badge == 'Bán chạy' || badge == 'BÁN CHẠY') {
          backgroundColor = Colors.blue;
          icon = Icons.trending_up;
        } else if (badge == 'Nổi bật' || badge == 'NỔI BẬT') {
          backgroundColor = Colors.indigo;
          icon = Icons.star;
        } else if (badge == 'Chính hãng') {
          backgroundColor = const Color.fromARGB(255, 0, 140, 255);
          icon = Icons.verified;
        } else {
          backgroundColor = Colors.grey;
          icon = Icons.info;
        }

        return ProductBadge(
          text: badge,
          icon: icon,
          backgroundColor: backgroundColor,
          iconColor: Colors.white,
          iconSize: iconSize,
          padding: padding,
        );
      }).toList(),
    );
  }
}

class ProductLocationInfo extends StatelessWidget {
  final String? locationText;
  final String? warehouseName;
  final String? provinceName;
  final double fontSize;
  final Color textColor;

  const ProductLocationInfo({
    super.key,
    this.locationText,
    this.warehouseName,
    this.provinceName,
    this.fontSize = 11,
    this.textColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    String displayText = '';
    
    if (locationText != null && locationText!.isNotEmpty) {
      displayText = locationText!;
    } else if (warehouseName != null && warehouseName!.isNotEmpty) {
      displayText = warehouseName!;
    } else if (provinceName != null && provinceName!.isNotEmpty) {
      displayText = provinceName!;
    }

    if (displayText.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: fontSize,
          color: textColor,
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class ProductBadgeWithIcon extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;
  final EdgeInsets padding;

  const ProductBadgeWithIcon({
    super.key,
    required this.text,
    this.icon,
    this.backgroundColor = Colors.red,
    this.iconColor = Colors.white,
    this.iconSize = 9,
    this.padding = const EdgeInsets.all(3),
  });

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();
    
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
              icon,
        size: iconSize,
              color: iconColor,
      ),
    );
  }
}

class ProductBadgesRowNoDiscount extends StatelessWidget {
  final List<String> badges;
  final double spacing;
  final double iconSize;
  final EdgeInsets padding;

  const ProductBadgesRowNoDiscount({
    super.key,
    required this.badges,
    this.spacing = 4,
    this.iconSize = 9,
    this.padding = const EdgeInsets.all(3),
  });

  @override
  Widget build(BuildContext context) {
    // Lọc bỏ badges giảm giá
    final filteredBadges = badges.where((badge) => 
      !badge.contains('%') && !badge.contains('Giảm')
    ).toList();
    
    if (filteredBadges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.start,
      children: filteredBadges.take(4).map((badge) { // Giới hạn tối đa 4 badges để tránh overflow
        Color backgroundColor;
        IconData? icon;

        // Xác định màu sắc và icon dựa trên loại badge
        if (badge == 'Voucher') {
          backgroundColor = Colors.orange;
          icon = Icons.local_offer;
        } else if (badge.contains('Giảm') && badge.contains('đ')) {
          // Freeship giảm cố định (VD: Giảm 30,000đ)
          backgroundColor = Colors.green;
          icon = Icons.local_shipping;
        } else if (badge.contains('Ưu đãi ship')) {
          // Freeship theo sản phẩm cụ thể
          backgroundColor = Colors.green;
          icon = Icons.local_shipping;
        } else if (badge.contains('Freeship 100%')) {
          // Freeship hoàn toàn
          backgroundColor = Colors.green;
          icon = Icons.local_shipping;
        } else if (badge.contains('Giảm') && badge.contains('%')) {
          // Freeship giảm theo % (VD: Giảm 50% ship)
          backgroundColor = Colors.green;
          icon = Icons.local_shipping;
        } else if (badge.contains('Freeship từ')) {
          // Freeship có điều kiện (VD: Freeship từ 500,000đ)
          backgroundColor = Colors.green;
          icon = Icons.local_shipping;
        } else if (badge == 'Flash Sale' || badge == 'FLASH SALE') {
          backgroundColor = Colors.purple;
          icon = Icons.flash_on;
        } else if (badge == 'Bán chạy' || badge == 'BÁN CHẠY') {
          backgroundColor = Colors.blue;
          icon = Icons.trending_up;
        } else if (badge == 'Nổi bật' || badge == 'NỔI BẬT') {
          backgroundColor = Colors.indigo;
          icon = Icons.star;
        } else if (badge == 'Chính hãng') {
          backgroundColor = const Color.fromARGB(255, 0, 140, 255);
          icon = Icons.verified;
        } else {
          backgroundColor = Colors.grey;
          icon = Icons.info;
        }

        return ProductBadgeWithIcon(
          text: badge,
          icon: icon,
          backgroundColor: backgroundColor,
          iconColor: Colors.white,
          iconSize: iconSize,
          padding: padding,
        );
      }).toList(),
    );
  }
}

class ProductLocationBadge extends StatelessWidget {
  final String? locationText;
  final String? warehouseName;
  final String? provinceName;
  final double fontSize;
  final Color iconColor;
  final Color textColor;

  const ProductLocationBadge({
    super.key,
    this.locationText,
    this.warehouseName,
    this.provinceName,
    this.fontSize = 9,
    this.iconColor = Colors.black,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    String displayText = '';
    
    if (locationText != null && locationText!.isNotEmpty) {
      displayText = locationText!;
    } else if (warehouseName != null && warehouseName!.isNotEmpty) {
      displayText = warehouseName!;
    } else if (provinceName != null && provinceName!.isNotEmpty) {
      displayText = provinceName!;
    }

    if (displayText.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.location_on,
          size: fontSize,
          color: iconColor,
        ),
        const SizedBox(width: 2),
        Text(
          displayText,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// Widget hiển thị badges từ các icon riêng lẻ từ API
class ProductIconsRow extends StatelessWidget {
  final String? voucherIcon;
  final String? freeshipIcon;
  final String? chinhhangIcon;
  final double spacing;
  final double iconSize;
  final EdgeInsets padding;

  const ProductIconsRow({
    super.key,
    this.voucherIcon,
    this.freeshipIcon,
    this.chinhhangIcon,
    this.spacing = 4,
    this.iconSize = 9,
    this.padding = const EdgeInsets.all(3),
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> badges = [];

    // Thêm voucher icon nếu có
    if (voucherIcon != null && voucherIcon!.isNotEmpty) {
      badges.add(_buildBadge(
        text: voucherIcon!,
        backgroundColor: Colors.orange,
        icon: Icons.local_offer,
      ));
    }

    // Thêm freeship icon nếu có
    if (freeshipIcon != null && freeshipIcon!.isNotEmpty) {
      badges.add(_buildBadge(
        text: freeshipIcon!,
        backgroundColor: Colors.green,
        icon: Icons.local_shipping,
      ));
    }

    // Thêm chính hãng icon nếu có
    if (chinhhangIcon != null && chinhhangIcon!.isNotEmpty) {
      badges.add(_buildBadge(
        text: chinhhangIcon!,
        backgroundColor: const Color.fromARGB(255, 0, 140, 255),
        icon: Icons.verified,
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: badges,
    );
  }

  Widget _buildBadge({
    required String text,
    required Color backgroundColor,
    required IconData icon,
  }) {
    return ProductBadgeWithIcon(
      text: text,
      icon: icon,
      backgroundColor: backgroundColor,
      iconColor: Colors.white,
      iconSize: iconSize,
      padding: padding,
    );
  }
}
