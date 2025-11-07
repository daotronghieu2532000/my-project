import 'package:flutter/material.dart';
import 'shop_vouchers_horizontal.dart';
import 'shop_flash_sales_tabs.dart';
import 'shop_categories_horizontal.dart';

class ShopTabContent extends StatelessWidget {
  final int shopId;

  const ShopTabContent({
    super.key,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voucher section - cuộn ngang
          const SizedBox(height: 8),
          ShopVouchersHorizontal(shopId: shopId),
          
          // Flash Sale section - tabs nếu có nhiều flash sale
          const SizedBox(height: 16),
          ShopFlashSalesTabs(shopId: shopId),
          
          // Categories section - cuộn ngang
          const SizedBox(height: 16),
          ShopCategoriesHorizontal(shopId: shopId),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

