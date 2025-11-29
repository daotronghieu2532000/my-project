import 'package:flutter/material.dart';
import '../models/shop_cart.dart';
import 'cart_item_tile.dart';

class ShopSection extends StatelessWidget {
  final ShopCart shop;
  final VoidCallback onChanged;
  const ShopSection({super.key, required this.shop, required this.onChanged});

  void _showDeleteShopDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa shop'),
        content: Text('Bạn có chắc muốn xóa tất cả sản phẩm của ${shop.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete shop functionality
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Checkbox(
                  value: shop.items.every((e) => e.isSelected),
                  activeColor: Colors.red,
                  onChanged: (v) {
                    for (final i in shop.items) {
                      i.isSelected = v ?? false;
                    }
                    onChanged();
                  },
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shop.name, 
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _showDeleteShopDialog(context);
                  }, 
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Xóa'),
                ),
              ],
            ),
          ),
          for (final item in shop.items)
            CartItemTile(item: item, onChanged: onChanged),
          const Divider(height: 1),
          InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: const [
                  Icon(Icons.local_offer_outlined, color: Colors.teal),
                  SizedBox(width: 8),
                  Expanded(child: Text('Mã giảm giá của shop')),
                  Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
