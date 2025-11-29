import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../../../core/utils/format_utils.dart';
import 'qty_button.dart';

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onChanged;
  const CartItemTile({super.key, required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.isSelected,
            activeColor: Colors.red,
            onChanged: (v) {
              item.isSelected = v ?? false;
              onChanged();
            },
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 64,
              height: 64,
              color: const Color(0xFFF4F6FB),
              child: Image.asset(
                item.image,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      FormatUtils.formatCurrency(item.price),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.oldPrice != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        FormatUtils.formatCurrency(item.oldPrice!),
                        style: const TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    QtyButton(icon: Icons.remove, onTap: () {
                      if (item.quantity > 1) {
                        item.quantity -= 1;
                        onChanged();
                      }
                    }),
                    const SizedBox(width: 4),
                    Container(
                      width: 40,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    QtyButton(icon: Icons.add, onTap: () {
                      item.quantity += 1;
                      onChanged();
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            onPressed: () {
              _showDeleteItemDialog(context);
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showDeleteItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sản phẩm'),
        content: Text('Bạn có chắc muốn xóa "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete item functionality
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
