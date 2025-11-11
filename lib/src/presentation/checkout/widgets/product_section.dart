import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../../core/services/voucher_service.dart';
import '../../../core/utils/format_utils.dart' as utils;
import '../../cart/widgets/voucher_dialog.dart';

class ProductSection extends StatefulWidget {
  const ProductSection({super.key});

  @override
  State<ProductSection> createState() => _ProductSectionState();
}

class _ProductSectionState extends State<ProductSection> {
  final cart_service.CartService _cartService = cart_service.CartService();
  final VoucherService _voucherService = VoucherService();

  List<cart_service.CartItem> get selectedItems =>
      _cartService.items.where((item) => item.isSelected).toList();

  @override
  void initState() {
    super.initState();
    // ✅ Listen vào VoucherService để tự động rebuild khi voucher thay đổi
    _voucherService.addListener(_onVoucherChanged);
  }

  @override
  void dispose() {
    _voucherService.removeListener(_onVoucherChanged);
    super.dispose();
  }

  void _onVoucherChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (selectedItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Không có sản phẩm nào được chọn',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Group items by shop
    final Map<String, List<cart_service.CartItem>> itemsByShop = {};
    for (final item in selectedItems) {
      if (!itemsByShop.containsKey(item.shopName)) {
        itemsByShop[item.shopName] = [];
      }
      itemsByShop[item.shopName]!.add(item);
    }

    final voucherService = VoucherService();
    return Column(
      children: itemsByShop.entries.map((entry) {
        final shopName = entry.key;
        final items = entry.value;
        final shopId = items.first.shopId;
        final appliedVoucher = voucherService.getAppliedVoucher(shopId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      shopName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final shopTotal = items.fold(
                        0,
                        (s, i) => s + i.price * i.quantity,
                      );
                      final selected = await showDialog(
                        context: context,
                        builder: (_) {
                          // Get product IDs from items
                          final cartProductIds = items.map((item) => item.id).toList();
                          return VoucherDialog(
                            shopId: shopId,
                            shopName: shopName,
                            shopTotal: shopTotal,
                            currentVoucher: appliedVoucher,
                            cartProductIds: cartProductIds,
                          );
                        },
                      );
                      if (selected != null && context.mounted) {
                        // ✅ setState() không cần thiết vì listener sẽ tự động rebuild
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã áp dụng voucher shop'),
                            backgroundColor:
                                Colors.green, // Màu nền xanh lá cây
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        appliedVoucher == null
                            ? 'Voucher shop'
                            : '${appliedVoucher.code} · ${_discountText(appliedVoucher)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: const Color(0xFFF4F6FB),
                        child: items[i].image.isNotEmpty
                            ? Image.network(
                                items[i].image,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) =>
                                    const Icon(Icons.image, color: Colors.grey),
                              )
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                FormatUtils.formatCurrency(items[i].price),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (items[i].oldPrice != null &&
                                  items[i].oldPrice! > items[i].price) ...[
                                const SizedBox(width: 8),
                                Text(
                                  FormatUtils.formatCurrency(
                                    items[i].oldPrice!,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'x${items[i].quantity}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

String _discountText(dynamic v) {
  if (v == null) return '';
  try {
    final type = v.discountType?.toString();
    final value = v.discountValue;
    if (type == 'percentage') {
      return '${value?.toInt()}%';
    }
    return utils.FormatUtils.formatCurrency(value?.round() ?? 0);
  } catch (_) {
    return '';
  }
}
