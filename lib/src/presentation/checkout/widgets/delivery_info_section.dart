import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/shipping_events.dart';
import '../../../core/models/user.dart';

class DeliveryInfoSection extends StatefulWidget {
  const DeliveryInfoSection({super.key});

  @override
  State<DeliveryInfoSection> createState() => _DeliveryInfoSectionState();
}

class _DeliveryInfoSectionState extends State<DeliveryInfoSection> {
  final _api = ApiService();
  final _auth = AuthService();
  User? _user;
  Map<String, dynamic>? _defaultAddress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await _auth.getCurrentUser();
    if (u == null) return;
    final data = await _api.getUserProfile(userId: u.userId);
    Map<String, dynamic>? def;
    if (data != null) {
      final list = (data['addresses'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
      def = list.firstWhere((a) => (a['active']?.toString() ?? '0') == '1', orElse: () => (list.isNotEmpty ? list.first : <String,dynamic>{}));
    }
    if (!mounted) return;
    setState(() { _user = u; _defaultAddress = def; });
  }

  Future<void> _openAddressBook() async {
    // print('📖 [DeliveryInfoSection._openAddressBook] Mở address book...');
    // Kiểm tra đăng nhập trước
    final u = await _auth.getCurrentUser();
    if (u == null) {
      // Nếu chưa đăng nhập, navigate đến trang đăng nhập
      final loginResult = await Navigator.pushNamed(context, '/login');
      // Nếu đăng nhập thành công, reload lại địa chỉ và trigger refresh shipping
      if (loginResult == true) {
        await _load();
      
        // Trigger refresh shipping để OrderSummarySection tự động tính lại phí ship
        ShippingEvents.refresh();
      }
      return;
    }
    // Nếu đã đăng nhập, mở trang địa chỉ
    await Navigator.of(context).pushNamed('/profile/address');
    await _load();
  
    // ✅ Trigger refresh shipping để tính lại phí ship với địa chỉ mới
    ShippingEvents.refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin từ địa chỉ hoặc user
    String displayName = '';
    String displayPhone = '';
    String fullAddress = '';
    
    if (_defaultAddress != null && _defaultAddress!.isNotEmpty) {
      // Ưu tiên lấy từ địa chỉ
      displayName = _defaultAddress!['ho_ten']?.toString().trim() ?? _user?.name ?? '';
      displayPhone = _defaultAddress!['dien_thoai']?.toString().trim() ?? _user?.mobile ?? '';
      
      // Ghép địa chỉ đầy đủ
      final parts = <String>[];
      final diaChi = _defaultAddress!['dia_chi']?.toString().trim();
      if (diaChi != null && diaChi.isNotEmpty) {
        parts.add(diaChi);
      }
      final tenXa = _defaultAddress!['ten_xa']?.toString().trim();
      if (tenXa != null && tenXa.isNotEmpty) {
        parts.add(tenXa);
      }
      final tenHuyen = _defaultAddress!['ten_huyen']?.toString().trim();
      if (tenHuyen != null && tenHuyen.isNotEmpty) {
        parts.add(tenHuyen);
      }
      final tenTinh = _defaultAddress!['ten_tinh']?.toString().trim();
      if (tenTinh != null && tenTinh.isNotEmpty) {
        parts.add(tenTinh);
      }
      fullAddress = parts.join(', ');
    } else {
      // Nếu chưa có địa chỉ, lấy từ user
      displayName = _user?.name ?? '';
      displayPhone = _user?.mobile ?? '';
    }

    final hasInfo = displayName.isNotEmpty || displayPhone.isNotEmpty || fullAddress.isNotEmpty;

    // ✅ Thay đổi cấu trúc hoàn toàn: Sử dụng Material + InkWell với borderRadius
    // Đảm bảo widget có thể cuộn bình thường trong ListView
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAddressBook,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: hasInfo
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // ✅ Hàng 1: Icon + Tên và số điện thoại + Chevron
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(top: 2),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.red,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Tên và số điện thoại
                              Text(
                                _buildNamePhoneText(displayName, displayPhone),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Địa chỉ đầy đủ
                              if (fullAddress.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  fullAddress,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Colors.red,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Chọn địa chỉ nhận hàng',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey[400],
                      size: 22,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
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
  
  String _buildNamePhoneText(String name, String phone) {
    final nameText = name.isNotEmpty ? name : '';
    final phoneText = phone.isNotEmpty ? _formatPhone(phone) : '';
    
    if (nameText.isEmpty && phoneText.isEmpty) {
      return '';
    }
    if (nameText.isEmpty) {
      return phoneText;
    }
    if (phoneText.isEmpty) {
      return nameText;
    }
    return '$nameText | $phoneText';
  }
}