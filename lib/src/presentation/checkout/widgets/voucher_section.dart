import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../product/product_detail_screen.dart';
import '../../../core/services/voucher_service.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../../core/utils/format_utils.dart';

class VoucherSection extends StatefulWidget {
  const VoucherSection({super.key});

  @override
  State<VoucherSection> createState() => _VoucherSectionState();
}

class _VoucherSectionState extends State<VoucherSection> {
  final VoucherService _voucherService = VoucherService();

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
    final pv = _voucherService.platformVoucher;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number, color: Colors.red),
          const SizedBox(width: 8),
          const Text('Voucher sàn'),
          const Spacer(),
          InkWell(
            onTap: () async {
              await _showPlatformVoucherDialog(context);
              // ✅ setState() không cần thiết vì listener sẽ tự động rebuild
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pv == null
                        ? 'Chọn hoặc nhập mã'
                        : '${pv.code} · ${_discountText(pv)}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlatformVoucherDialog(BuildContext context) async {
    final api = ApiService();
    final cart = cart_service.CartService();
    final items = cart.items;
    if (items.isEmpty) return;

    // Lấy toàn bộ voucher sàn (không lọc product_id để tránh bỏ sót),
    // sau đó kiểm tra điều kiện áp dụng theo giỏ hàng ở client
    final vouchers = await api.getVouchers(type: 'platform');

    if (vouchers == null || vouchers.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiện chưa có Voucher sàn khả dụng')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Voucher>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Chọn Voucher sàn',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, i) {
                    final v = vouchers[i];
                    final eligibility = _eligibilityForPlatformVoucher(
                      v,
                      items,
                    );
                    final canUse = eligibility.$1;
                    final minTxt = v.minOrderValue != null
                        ? 'Đơn tối thiểu ${FormatUtils.formatCurrency(v.minOrderValue!.round())}'
                        : '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(
                        Icons.local_activity,
                        color: canUse ? Colors.red : Colors.grey,
                      ),
                      title: Text(
                        '${v.code} · ${_discountText(v)}',
                        style: TextStyle(
                          color: canUse ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        minTxt,
                        style: TextStyle(
                          color: canUse ? Colors.grey[700] : Colors.grey,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!canUse)
                            IconButton(
                              tooltip: 'Điều kiện áp dụng',
                              icon: const Icon(
                                Icons.priority_high,
                                color: Colors.orange,
                              ),
                              onPressed: () => _showIneligibleReason(
                                context,
                                v,
                                eligibility.$2,
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: canUse ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              canUse ? 'Sử dụng' : 'Chưa đủ điều kiện',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: canUse
                          ? () => Navigator.pop(context, v)
                          : () => _showIneligibleReason(
                              context,
                              v,
                              eligibility.$2,
                            ),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: vouchers.length,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      _voucherService.setPlatformVoucher(selected);
      // ✅ setState() không cần thiết vì listener sẽ tự động rebuild
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã áp dụng voucher sàn ${selected.code}'),
          backgroundColor: Colors.green, // Thêm màu nền xanh lá cây
        ),
      );
    }
  }

  String _discountText(Voucher v) {
    if (v.discountType == 'percentage') {
      return '${v.discountValue?.toInt()}%';
    }
    return FormatUtils.formatCurrency(v.discountValue?.round() ?? 0);
  }

  // Deprecated: thay bằng _eligibilityForPlatformVoucher

  // Trả về (canUse, reason)
  (bool, String) _eligibilityForPlatformVoucher(
    Voucher v,
    List<cart_service.CartItem> items,
  ) {
    // 1) HSD / trạng thái
    if (!v.canUse) return (false, 'Voucher đã hết hạn hoặc tạm dừng.');

    // 2) Min order
    final subtotal = items.fold<int>(0, (s, i) => s + i.price * i.quantity);
    if (v.minOrderValue != null && subtotal < v.minOrderValue!.round()) {
      return (
        false,
        'Đơn tối thiểu ${FormatUtils.formatCurrency(v.minOrderValue!.round())}.',
      );
    }

    // 3) Applicable products (nếu có)
    final allowIds = <int>{};
    if (v.applicableProductsDetail != null &&
        v.applicableProductsDetail!.isNotEmpty) {
      for (final m in v.applicableProductsDetail!) {
        final id = int.tryParse(m['id'] ?? '');
        if (id != null) allowIds.add(id);
      }
    } else if (v.applicableProducts != null &&
        v.applicableProducts!.isNotEmpty) {
      for (final s in v.applicableProducts!) {
        final id = int.tryParse(s);
        if (id != null) allowIds.add(id);
      }
    }
    if (allowIds.isNotEmpty) {
      final cartIds = items.map((e) => e.id).toSet();
      if (allowIds.intersection(cartIds).isEmpty) {
        return (false, 'Voucher áp dụng cho sản phẩm khác.');
      }
    }

    return (true, '');
  }

  void _showIneligibleReason(BuildContext context, Voucher v, String reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${v.code} · ${_discountText(v)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (v.minOrderValue != null)
                    Text(
                      '• Đơn tối thiểu: ${FormatUtils.formatCurrency(v.minOrderValue!.round())}',
                    ),
                  if ((v.applicableProductsDetail?.isNotEmpty ?? false) ||
                      (v.applicableProducts?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    const Text('• Áp dụng cho sản phẩm:'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 124,
                      width: double.infinity,
                      child: ListView.separated(
                        shrinkWrap: true,
                        primary: false,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final item = _mapApplicableItem(v, index);
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    productId: item.$1,
                                    title: item.$2,
                                    image: item.$3,
                                  ),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 120,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 80,
                                      width: 120,
                                      color: Colors.grey[100],
                                      child: item.$3.isNotEmpty
                                          ? Image.network(
                                              item.$3,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.$2,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _applicableCount(v),
                      ),
                    ),
                  ],
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Lý do hiện tại: $reason',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helpers để dựng danh sách sản phẩm áp dụng trong dialog
  int _applicableCount(Voucher v) {
    if (v.applicableProductsDetail != null &&
        v.applicableProductsDetail!.isNotEmpty) {
      return v.applicableProductsDetail!.length;
    }
    return v.applicableProducts?.length ?? 0;
  }

  // Trả về (id, title, image)
  (int?, String, String) _mapApplicableItem(Voucher v, int index) {
    if (v.applicableProductsDetail != null &&
        v.applicableProductsDetail!.isNotEmpty) {
      final m = v.applicableProductsDetail![index];
      final id = int.tryParse(m['id'] ?? '');
      final title = (m['title'] ?? '').toString();
      final image = (m['image'] ?? '').toString();
      return (id, title, image);
    }
    final id = int.tryParse(v.applicableProducts![index]);
    return (id, 'Sản phẩm #${v.applicableProducts![index]}', '');
  }
}
