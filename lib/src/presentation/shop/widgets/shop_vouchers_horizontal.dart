import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/utils/format_utils.dart';

class ShopVouchersHorizontal extends StatefulWidget {
  final int shopId;

  const ShopVouchersHorizontal({
    super.key,
    required this.shopId,
  });

  @override
  State<ShopVouchersHorizontal> createState() => _ShopVouchersHorizontalState();
}

class _ShopVouchersHorizontalState extends State<ShopVouchersHorizontal> {
  final CachedApiService _cachedApiService = CachedApiService();
  
  List<ShopVoucher> _vouchers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final vouchersData = await _cachedApiService.getShopVouchersDataCached(
        shopId: widget.shopId,
      );

      if (mounted) {
        final vouchers = vouchersData.map((data) => ShopVoucher.fromJson(data)).toList();
        
        setState(() {
          _vouchers = vouchers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _vouchers.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _vouchers.length,
        itemBuilder: (context, index) {
          final voucher = _vouchers[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: _buildVoucherCard(voucher),
          );
        },
      ),
    );
  }

  Widget _buildVoucherCard(ShopVoucher voucher) {
    final discountText = voucher.discountType == 'phantram'
        ? 'Giảm ${voucher.discountValue}%'
        : 'Giảm ${FormatUtils.formatCurrency(voucher.discountValue)}';
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeLeft = voucher.endTime - now;
    final daysLeft = timeLeft > 0 ? (timeLeft / 86400).ceil() : 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 1.5),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.red[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discountText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đơn tối thiểu ${FormatUtils.formatCurrency(voucher.minOrderValue)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã lưu voucher ${voucher.code}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Lưu',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (daysLeft > 0)
              Text(
                daysLeft == 1 ? 'Còn 1 ngày' : 'Còn $daysLeft ngày',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

