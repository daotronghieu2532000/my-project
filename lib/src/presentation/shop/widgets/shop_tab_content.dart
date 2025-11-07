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
          _buildSectionTitle('Mã giảm giá'),
          const SizedBox(height: 8),
          ShopVouchersHorizontal(shopId: shopId),
          
          // Flash Sale section - tabs nếu có nhiều flash sale
          const SizedBox(height: 16),
          _buildSectionTitle('Flash sale'),
          const SizedBox(height: 8),
          ShopFlashSalesTabs(shopId: shopId),
          
          // Categories section - cuộn ngang
          const SizedBox(height: 16),
          _buildSectionTitle('Danh mục'),
          const SizedBox(height: 8),
          ShopCategoriesHorizontal(shopId: shopId),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

