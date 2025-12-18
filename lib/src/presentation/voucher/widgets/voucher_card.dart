import 'package:flutter/material.dart';
import '../../../core/models/voucher.dart';
import '../../../core/utils/format_utils.dart';

class VoucherCard extends StatelessWidget {
  final Voucher voucher;
  final VoidCallback? onTap;

  const VoucherCard({
    super.key,
    required this.voucher,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isShopVoucher = voucher.type == 'shop';
    // Màu sắc nhẹ nhàng
    final Color primaryColor = isShopVoucher ? const Color(0xFFEEF5FF) : const Color(0xFFFFF3F0);
    final Color accentColor = isShopVoucher ? const Color(0xFF3B82F6) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: voucher.canUse ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Discount badge (left side)
              Container(
                width: 85,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    voucher.formattedDiscount,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Main content (center)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voucher code/title
                    Text(
                      voucher.code.isNotEmpty ? voucher.code : voucher.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Shop name (for shop vouchers) or description
                    if (isShopVoucher && voucher.shopName != null) ...[
                      Text(
                        voucher.shopName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ] else if (!isShopVoucher && voucher.description.isNotEmpty) ...[
                      Text(
                        voucher.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    
                    // Minimum order requirement
                    Row(
                      children: [
                        Icon(Icons.local_offer_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Đơn tối thiểu ${FormatUtils.formatCurrency(voucher.minOrderValue?.toInt() ?? 50000)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Time remaining
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          voucher.daysRemaining != null 
                              ? 'Còn ${voucher.daysRemaining} ngày'
                              : 'Đã hết hạn',
                          style: TextStyle(
                            fontSize: 12,
                            color: voucher.daysRemaining != null && voucher.daysRemaining! > 0 
                                ? Colors.grey[600] 
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Usage info
                    Text(
                      '${voucher.usedCount ?? 0}/${voucher.usageLimit ?? '∞'} đã dùng',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Status badge (right side)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: voucher.canUse ? accentColor.withOpacity(0.08) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: voucher.canUse ? accentColor : Colors.grey[300]!),
                ),
                child: Text(
                  voucher.canUse ? 'Sử dụng' : 'Không khả dụng',
                  style: TextStyle(
                    color: voucher.canUse ? accentColor : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}