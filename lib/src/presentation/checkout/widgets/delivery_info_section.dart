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
    final name = _user?.name ?? '';
    final phone = _user?.mobile ?? '';
    final address = _defaultAddress != null
        ? (_defaultAddress!['dia_chi']?.toString() ?? '') + ([_defaultAddress!['ten_xa'], _defaultAddress!['ten_huyen'], _defaultAddress!['ten_tinh']].where((e) => e != null && e.toString().isNotEmpty).map((e) => e.toString()).isNotEmpty ? '' : '')
        : '';

    return InkWell(
      onTap: _openAddressBook,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name.isNotEmpty && phone.isNotEmpty ? '$name (+84) ${phone.startsWith('0') ? phone.substring(1) : phone}' : 'Chọn địa chỉ nhận hàng',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
              ],
            ),
            const SizedBox(height: 2),
            if (address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  address,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}