import 'package:flutter/material.dart';
import '../../../core/models/user.dart';

/// Widget sticky header hiển thị thông tin địa chỉ ngắn khi cuộn
class DeliveryInfoStickyHeader extends StatelessWidget {
  final User? user;
  final Map<String, dynamic>? defaultAddress;
  final VoidCallback? onTap;

  const DeliveryInfoStickyHeader({ 
    super.key,
    required this.user,
    required this.defaultAddress,
    this.onTap,
  });

  String _formatPhone(String phone) {
    if (phone.isEmpty) return phone;
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.startsWith('84')) {
      cleaned = cleaned.substring(2);
    }
    return '+84 $cleaned';
  }

  String _buildShortAddress(Map<String, dynamic>? address) {
    if (address == null || address.isEmpty) return '';
    final parts = <String>[];
    final tenXa = address['ten_xa']?.toString().trim();
    final tenHuyen = address['ten_huyen']?.toString().trim();
    final tenTinh = address['ten_tinh']?.toString().trim();
    
    if (tenXa != null && tenXa.isNotEmpty) parts.add(tenXa);
    if (tenHuyen != null && tenHuyen.isNotEmpty) parts.add(tenHuyen);
    if (tenTinh != null && tenTinh.isNotEmpty) parts.add(tenTinh);
    
    if (parts.isEmpty) {
      // Fallback: lấy phần đầu của địa chỉ
      final diaChi = address['dia_chi']?.toString().trim() ?? '';
      if (diaChi.length > 30) {
        return '${diaChi.substring(0, 30)}...';
      }
      return diaChi;
    }
    
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    String displayName = '';
    String displayPhone = '';
    String shortAddress = '';
    
    if (defaultAddress != null && defaultAddress!.isNotEmpty) {
      displayName = defaultAddress!['ho_ten']?.toString().trim() ?? user?.name ?? '';
      displayPhone = defaultAddress!['dien_thoai']?.toString().trim() ?? user?.mobile ?? '';
      shortAddress = _buildShortAddress(defaultAddress);
    } else {
      displayName = user?.name ?? '';
      displayPhone = user?.mobile ?? '';
    }

    final hasInfo = displayName.isNotEmpty || displayPhone.isNotEmpty || shortAddress.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Colors.red,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: hasInfo
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Tên và số điện thoại trên 1 dòng
                          Text(
                            displayName.isNotEmpty && displayPhone.isNotEmpty
                                ? '$displayName | ${_formatPhone(displayPhone)}'
                                : displayName.isNotEmpty
                                    ? displayName
                                    : _formatPhone(displayPhone),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Địa chỉ ngắn
                          if (shortAddress.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              shortAddress,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      )
                    : const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Chọn địa chỉ nhận hàng',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

