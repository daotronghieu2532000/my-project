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
    // ✅ Listen vào CartService để tự động validate voucher khi giỏ hàng thay đổi
    cart_service.CartService().addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _voucherService.removeListener(_onVoucherChanged);
    cart_service.CartService().removeListener(_onCartChanged);
    super.dispose();
  }

  void _onVoucherChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onCartChanged() {
    // ✅ Tự động validate và xóa voucher sàn nếu không đủ điều kiện
    final pv = _voucherService.platformVoucher;
    if (pv != null) {
      final cart = cart_service.CartService();
      // ✅ QUAN TRỌNG: Chỉ tính trên items ĐÃ CHỌN để thanh toán, không phải tất cả items
      final items = cart.items.where((i) => i.isSelected).toList();
      final eligibility = _eligibilityForPlatformVoucher(pv, items);
      
     
      
      if (!eligibility.$1) {
     
        _voucherService.setPlatformVoucher(null);
        // ✅ setPlatformVoucher(null) sẽ gọi notifyListeners() tự động
        // Nhưng để đảm bảo UI cập nhật, ta vẫn gọi setState()
      } else {
        print('✅ [VOUCHER VALIDATE] Voucher ${pv.code} vẫn đủ điều kiện');
      }
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pv = _voucherService.platformVoucher;
    
    // ✅ DEBUG: Print để kiểm tra voucher hiện tại khi build
    print('🎨 [VOUCHER UI] Build VoucherSection - voucher: ${pv?.code ?? "null"}');
    
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
    
    // ✅ QUAN TRỌNG: Chỉ lấy items ĐÃ CHỌN để thanh toán
    final selectedItems = cart.items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn sản phẩm để thanh toán')),
      );
      return;
    }

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
        // ✅ QUAN TRỌNG: Dùng StatefulWidget riêng để có thể rebuild khi giỏ hàng thay đổi
        return _VoucherDialogContent(
          vouchers: vouchers,
          cart: cart,
          onShowIneligibleReason: _showIneligibleReason,
          discountText: _discountText,
          eligibilityCheck: _eligibilityForPlatformVoucher,
        );
      },
    );

    if (selected != null) {
      // ✅ Kiểm tra lại điều kiện TRƯỚC KHI set voucher (đảm bảo giỏ hàng không thay đổi)
      // ✅ QUAN TRỌNG: Chỉ tính trên items ĐÃ CHỌN để thanh toán
      final currentItems = cart.items.where((i) => i.isSelected).toList();
      final eligibility = _eligibilityForPlatformVoucher(selected, currentItems);
      
      if (!eligibility.$1) {
        // ❌ Không đủ điều kiện, hiển thị lý do
        print('⚠️ [VOUCHER SET] Không thể set voucher: ${eligibility.$2}');
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể áp dụng: ${eligibility.$2}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // ✅ Đủ điều kiện, set voucher
      print('✅ [VOUCHER SET] Set voucher sàn: ${selected.code}');
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
    if (!v.canUse) {
     
      return (false, 'Voucher đã hết hạn hoặc tạm dừng.');
    }

    // 2) Min order
    final subtotal = items.fold<int>(0, (s, i) => s + i.price * i.quantity);
    print('   - Tổng tiền hàng (subtotal): ${FormatUtils.formatCurrency(subtotal)}');
    print('   - Số lượng items: ${items.length}');
    for (var item in items) {
      print('     + Item ${item.id}: ${FormatUtils.formatCurrency(item.price)} x ${item.quantity} = ${FormatUtils.formatCurrency(item.price * item.quantity)}');
    }
    
    if (v.minOrderValue != null && subtotal < v.minOrderValue!.round()) {
      print('   - ❌ Không đủ điều kiện: subtotal (${FormatUtils.formatCurrency(subtotal)}) < minOrderValue (${FormatUtils.formatCurrency(v.minOrderValue!.round())})');
      return (
        false,
        'Đơn tối thiểu ${FormatUtils.formatCurrency(v.minOrderValue!.round())}.',
      );
    } else if (v.minOrderValue != null) {
      print('   - ✅ Đủ điều kiện minOrderValue: subtotal (${FormatUtils.formatCurrency(subtotal)}) >= minOrderValue (${FormatUtils.formatCurrency(v.minOrderValue!.round())})');
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

// ✅ Widget riêng để quản lý state cho dialog chọn voucher
class _VoucherDialogContent extends StatefulWidget {
  final List<Voucher> vouchers;
  final cart_service.CartService cart;
  final Function(BuildContext, Voucher, String) onShowIneligibleReason;
  final String Function(Voucher) discountText;
  final (bool, String) Function(Voucher, List<cart_service.CartItem>) eligibilityCheck;

  const _VoucherDialogContent({
    required this.vouchers,
    required this.cart,
    required this.onShowIneligibleReason,
    required this.discountText,
    required this.eligibilityCheck,
  });

  @override
  State<_VoucherDialogContent> createState() => _VoucherDialogContentState();
}

class _VoucherDialogContentState extends State<_VoucherDialogContent> {
  @override
  void initState() {
    super.initState();
    // ✅ Lắng nghe thay đổi giỏ hàng để rebuild
    widget.cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    widget.cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {}); // Rebuild khi giỏ hàng thay đổi
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ QUAN TRỌNG: Chỉ lấy items ĐÃ CHỌN để thanh toán, không phải tất cả items
    final currentItems = widget.cart.items.where((i) => i.isSelected).toList();
    
    if (currentItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text('Vui lòng chọn sản phẩm để thanh toán'),
      );
    }

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
                final v = widget.vouchers[i];
                // ✅ Dùng currentItems (lấy mới mỗi lần build) - QUAN TRỌNG!
                final eligibility = widget.eligibilityCheck(v, currentItems);
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
                    '${v.code} · ${widget.discountText(v)}',
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
                          onPressed: () => widget.onShowIneligibleReason(
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
                      : () => widget.onShowIneligibleReason(
                          context,
                          v,
                          eligibility.$2,
                        ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: widget.vouchers.length,
            ),
          ),
        ],
      ),
    );
  }
}
