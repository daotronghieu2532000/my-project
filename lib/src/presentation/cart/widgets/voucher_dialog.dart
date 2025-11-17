import 'package:flutter/material.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/voucher_service.dart';
import '../../../core/utils/format_utils.dart';

class VoucherDialog extends StatefulWidget {
  final int shopId;
  final String shopName;
  final int shopTotal;
  final Voucher? currentVoucher;
  final List<int>? cartProductIds; // Danh sách product IDs trong giỏ hàng của shop này

  const VoucherDialog({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.shopTotal,
    this.currentVoucher,
    this.cartProductIds,
  });

  @override
  State<VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<VoucherDialog> {
  final ApiService _apiService = ApiService();
  final VoucherService _voucherService = VoucherService();
  List<Voucher> _vouchers = [];
  bool _isLoading = true;
  Voucher? _selectedVoucher;

  @override
  void initState() {
    super.initState();
    _selectedVoucher = widget.currentVoucher;
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final vouchers = await _apiService.getVouchers(
        type: 'shop',
        shopId: widget.shopId,
        limit: 20,
      );

      if (mounted) {
        // Filter vouchers based on cart product IDs
        List<Voucher>? filteredVouchers = vouchers;
        if (filteredVouchers != null && widget.cartProductIds != null && widget.cartProductIds!.isNotEmpty) {
          filteredVouchers = filteredVouchers.where((voucher) {
            // Check if voucher applies to the products in cart
            return voucher.appliesToProducts(widget.cartProductIds!);
          }).toList();
        }
        
        setState(() {
          _vouchers = filteredVouchers ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header - đơn giản
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    color: Colors.grey[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mã giảm giá - ${widget.shopName}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _vouchers.isEmpty
                      ? _buildEmptyState()
                      : _buildVoucherList(),
            ),
            
            // Footer buttons - đơn giản
            if (!_isLoading && _vouchers.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(8),
                            child: const Center(
                              child: Text(
                                'Hủy',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _selectedVoucher != null ? Colors.red[600] : Colors.grey[400],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _selectedVoucher != null ? _applyVoucher : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Center(
                              child: Text(
                                _selectedVoucher != null ? 'Áp dụng' : 'Chọn mã',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Đang tải...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Không có mã giảm giá',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shop này hiện tại không có mã giảm giá nào',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vouchers.length,
      itemBuilder: (context, index) {
        final voucher = _vouchers[index];
        final isSelected = _selectedVoucher?.id == voucher.id;
        final canApply = _voucherService.canApplyVoucher(
          voucher, 
          widget.shopTotal,
          productIds: widget.cartProductIds,
        );
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canApply ? () => _selectVoucher(voucher) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red[50] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.red[400]! : Colors.grey[200]!,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Voucher icon - đơn giản
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red[600] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.local_offer_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Voucher info - responsive
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Code và discount trên cùng 1 dòng
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  voucher.code,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                voucher.discountType == 'percentage'
                                    ? 'Giảm ${voucher.discountValue?.toInt()}%'
                                    : 'Giảm ${FormatUtils.formatCurrency(voucher.discountValue?.round() ?? 0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Title
                          Text(
                            voucher.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Min order - chỉ hiện khi cần
                          if (voucher.minOrderValue != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Đơn tối thiểu ${FormatUtils.formatCurrency(voucher.minOrderValue!.round())}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Selection indicator - đơn giản
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Colors.red[600],
                        size: 20,
                      )
                    else if (!canApply)
                      Icon(
                        Icons.cancel_outlined,
                        color: Colors.grey[400],
                        size: 18,
                      )
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!, width: 1.5),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectVoucher(Voucher voucher) {
    setState(() {
      _selectedVoucher = voucher;
    });
  }

  void _applyVoucher() {
    if (_selectedVoucher != null) {
      _voucherService.applyVoucher(widget.shopId, _selectedVoucher!);
      Navigator.pop(context, _selectedVoucher);
    }
  }
}
