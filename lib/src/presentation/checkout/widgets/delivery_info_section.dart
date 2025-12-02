import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/shipping_events.dart';

class DeliveryInfoSection extends StatefulWidget {
  final ScrollController? scrollController;
  const DeliveryInfoSection({super.key, this.scrollController});

  @override
  State<DeliveryInfoSection> createState() => _DeliveryInfoSectionState();
}

class _DeliveryInfoSectionState extends State<DeliveryInfoSection> {
  final _api = ApiService();
  final _auth = AuthService();
  Map<String, dynamic>? _defaultAddress;
  bool _isCompact = false; // ✅ Flag để xác định compact mode

  @override
  void initState() {
    super.initState();
    _load();
    // ✅ Lắng nghe scroll để chuyển đổi giữa full và compact mode
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController == null) return;
    final scrollOffset = widget.scrollController!.offset;
    // ✅ Khi scroll > 20px, chuyển sang compact mode
    final shouldBeCompact = scrollOffset > 20;
    if (shouldBeCompact != _isCompact && mounted) {
      setState(() {
        _isCompact = shouldBeCompact;
      });
    }
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
    setState(() { _defaultAddress = def; });
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
    // ✅ Lấy tên và số điện thoại TỪ ĐỊA CHỈ (không phải từ user profile)
    final name = _defaultAddress?['ho_ten']?.toString() ?? '';
    final phone = _defaultAddress?['dien_thoai']?.toString() ?? '';
    
    // ✅ Tạo địa chỉ text đúng cách
    String addressText = '';
    if (_defaultAddress != null) {
      final diaChi = _defaultAddress!['dia_chi']?.toString() ?? '';
      final parts = [
        _defaultAddress!['ten_xa'],
        _defaultAddress!['ten_huyen'],
        _defaultAddress!['ten_tinh']
      ].where((e) => e != null && e.toString().isNotEmpty).map((e) => e.toString()).toList();
      final locationParts = parts.join(', ');
      addressText = diaChi + (locationParts.isNotEmpty ? ', $locationParts' : '');
    }
    
    final hasAddress = addressText.isNotEmpty;
    final hasNameAndPhone = name.isNotEmpty && phone.isNotEmpty;

    return InkWell(
      onTap: _openAddressBook,
      child: Container(
        padding: EdgeInsets.zero, // ✅ Padding đã được handle ở delegate
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: _isCompact ? BorderRadius.zero : BorderRadius.circular(12),
          border: _isCompact ? Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ) : null,
        ),
        child: _isCompact
            ? _buildCompactView(addressText, hasAddress)
            : _buildFullView(name, phone, addressText, hasNameAndPhone, hasAddress),
      ),
    );
  }

  // ✅ Compact mode: chỉ icon + địa chỉ
  Widget _buildCompactView(String addressText, bool hasAddress) {
    return SizedBox(
      height: 44, // ✅ Chiều cao cố định cho compact mode
      child: Row(
          children: [
          const Icon(Icons.location_on, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
              hasAddress ? addressText : 'Chưa có địa chỉ',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: hasAddress ? Colors.black87 : Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
                  ),
                ),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 14),
              ],
            ),
    );
  }

  // ✅ Full mode: đầy đủ thông tin
  // Dòng 1: Tên + Số điện thoại (từ địa chỉ)
  // Dòng 2: Địa chỉ
  Widget _buildFullView(String name, String phone, String addressText, bool hasNameAndPhone, bool hasAddress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // ✅ Tránh overflow
      children: [
        // ✅ Dòng 1: Icon + Tên và số điện thoại (từ địa chỉ)
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 18),
            const SizedBox(width: 4),
            Expanded(
                child: Text(
                hasNameAndPhone 
                    ? '$name (+84) ${phone.startsWith('0') ? phone.substring(1) : phone}' 
                    : 'Chọn địa chỉ nhận hàng',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 14),
          ],
        ),
        // ✅ Dòng 2: Địa chỉ (nếu có) - nằm ngay dưới tên/số điện thoại
        if (hasAddress) ...[
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 0),
            child: Text(
              addressText,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ),
        ],
      ],
    );
  }
}