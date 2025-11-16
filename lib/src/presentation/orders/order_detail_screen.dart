import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../product/product_detail_screen.dart';
import 'product_review_screen.dart';
import '../profile/address_book_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int userId;
  final String? maDon;
  final int? orderId;
  const OrderDetailScreen({super.key, required this.userId, this.maDon, this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  bool _loading = true;
  Map<String, dynamic>? _detail;

  // Helper function to format price from comma to dot
  String _formatPrice(String priceText) {
    return priceText.replaceAll(',', '.');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _api.getOrderDetail(
      userId: widget.userId,
      orderId: widget.orderId,
      maDon: widget.maDon,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _detail = data?['data']?['order'] as Map<String, dynamic>?;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chi tiết đơn hàng',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Show review button only for status 5 (Giao thành công)
          if ((_detail?['status'] as int? ?? 0) == 5)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildReviewButton(),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('Không tìm thấy đơn hàng'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Order Status Card with Icon
                      _buildStatusCard(),
                      const SizedBox(height: 12),
                      
                      // Shipping Info Card
                      _buildShippingCard(),
                      const SizedBox(height: 12),
                      
                      // Delivery Address Card
                      _buildAddressCard(),
                      const SizedBox(height: 12),
                      // Products Card
                      _buildProductsCard(),
                      const SizedBox(height: 12),
                      
                      // Payment Summary Card
                      _buildPaymentCard(),
                      const SizedBox(height: 16),
                      
                      // Action Buttons
                      if ((_detail!['status'] as int? ?? 0) <= 1)
                        _buildActionButtons(),
                    ],
                  ),
                ),
    );
  }

  // Modern Status Card with Icon and Color
  Widget _buildStatusCard() {
    final status = _detail!['status'] as int? ?? 0;
    final statusText = _detail!['status_text'] ?? '';
    final dateText = _detail!['date_post_formatted'] ?? '';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 0:
        statusColor = const Color(0xFFFF9500);
        statusIcon = Icons.schedule;
        break;
      case 1:
        statusColor = const Color(0xFF007AFF);
        statusIcon = Icons.check_circle_outline;
        break;
      case 2:
        statusColor = const Color(0xFF34C759);
        statusIcon = Icons.local_shipping;
        break;
      case 3:
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.cancel_outlined;
        break;
      case 4:
        statusColor = const Color(0xFF999999);
        statusIcon = Icons.cancel;
        break;
      case 5:
        statusColor = const Color(0xFF34C759);
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = const Color(0xFF8E8E93);
        statusIcon = Icons.info_outline;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trạng thái đơn hàng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ),
          Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Shipping Info Card
  Widget _buildShippingCard() {
    final provider = _detail!['shipping_provider'] ?? '—';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping, color: Color(0xFF007AFF), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn vị vận chuyển',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Address Card
  Widget _buildAddressCard() {
    final address = _detail!['customer_info']?['full_address'] ?? '';
    final status = _detail!['status'] as int? ?? 0;
    final canEdit = status == 0; // Chỉ cho phép sửa khi status = 0 (Chờ xử lý)
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on, color: Color(0xFF34C759), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Địa chỉ giao hàng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                    ),
                    if (canEdit)
                      GestureDetector(
                        onTap: _editOrderAddress,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Color(0xFF007AFF),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Thay đổi',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF007AFF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D1D1F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editOrderAddress() async {
    final user = await _auth.getCurrentUser();
    if (user == null) return;
    
    final selectedAddress = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddressBookScreen(
          onAddressSelected: (address) => address,
        ),
      ),
    );
    
    if (selectedAddress == null) return;
    
    // Parse tinh, huyen, xa to int
    final tinh = selectedAddress['tinh'] is int
        ? selectedAddress['tinh'] as int
        : (int.tryParse(selectedAddress['tinh']?.toString() ?? '0') ?? 0);
    final huyen = selectedAddress['huyen'] is int
        ? selectedAddress['huyen'] as int
        : (int.tryParse(selectedAddress['huyen']?.toString() ?? '0') ?? 0);
    final xa = selectedAddress['xa'] is int
        ? selectedAddress['xa'] as int
        : (int.tryParse(selectedAddress['xa']?.toString() ?? '0') ?? 0);
    
    if (tinh <= 0 || huyen <= 0 || xa <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Địa chỉ không hợp lệ. Vui lòng chọn lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final success = await _api.updateOrderAddress(
      userId: user.userId,
      orderId: _detail?['id'] as int?,
      maDon: _detail?['ma_don']?.toString(),
      hoTen: selectedAddress['ho_ten']?.toString() ?? '',
      email: selectedAddress['email']?.toString(),
      dienThoai: selectedAddress['dien_thoai']?.toString() ?? '',
      diaChi: selectedAddress['dia_chi']?.toString() ?? '',
      tinh: tinh,
      huyen: huyen,
      xa: xa,
    );
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật địa chỉ giao hàng'),
          backgroundColor: Colors.green,
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật địa chỉ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Products Card
  Widget _buildProductsCard() {
    final products = (_detail!['products'] ?? []) as List;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag, color: Color(0xFFFF9500), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sản phẩm đã đặt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...products.map((pp) {
            final p = (pp as Map).cast<String, dynamic>();
            final String img = (p['image'] ?? '').toString();
            final String fixed = img.startsWith('http') ? img : (img.isEmpty ? '' : 'https://socdo.vn$img');
            final String variant = [p['color'], p['size']].where((e) => (e?.toString().isNotEmpty ?? false)).join(' • ');
            final String priceText = p['price_formatted'] ?? '';
            
            return GestureDetector(
              onTap: () {
                // Navigate to product detail
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      productId: p['id'] ?? 0,
                      title: p['name'] ?? '',
                      image: fixed,
                      price: p['price'] ?? 0,
                      initialShopId: p['shop_id'] ?? 0,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Larger product image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        fixed,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: const Color(0xFFF5F5F5),
                          child: const Icon(Icons.image_not_supported, size: 30, color: Color(0xFF999999)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Color(0xFF1D1D1F),
                              height: 1.3,
                            ),
                          ),
                          if (variant.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              variant,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                _formatPrice(priceText),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF6B35),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'x${p['quantity']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Payment Summary Card
  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt, color: Color(0xFF34C759), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Tổng kết đơn hàng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPaymentRow('Tạm tính', _detail!['tamtinh_formatted'] ?? '', isTotal: false),
          _buildPaymentRow('Phí vận chuyển', _detail!['phi_ship_formatted'] ?? '', isTotal: false),
          if ((_detail!['ship_support'] ?? 0) > 0)
            _buildPaymentRow('Phí hỗ trợ giao hàng', _detail!['ship_support_formatted'] ?? '', isTotal: false),
          
          // Voucher và giảm giá
          if ((_detail!['voucher_tmdt'] ?? 0) > 0)
            _buildVoucherRow('Voucher giảm giá', _detail!['voucher_tmdt_formatted'] ?? '', _detail!['coupon_code'] ?? ''),
          if ((_detail!['giam'] ?? 0) > 0)
            _buildPaymentRow('Giảm giá khác', _detail!['giam_formatted'] ?? '', isTotal: false),
          
          const Divider(height: 24),
          _buildPaymentRow('Tổng thanh toán', _detail!['tongtien_formatted'] ?? '', isTotal: true),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? const Color(0xFF1D1D1F) : Colors.grey[700],
            ),
          ),
          Text(
            _formatPrice(value),
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isTotal ? const Color(0xFFFF6B35) : const Color(0xFF1D1D1F),
            ),
          ),
        ],
      ),
    );
  }

  // Voucher Row with Icon and Color
  Widget _buildVoucherRow(String label, String value, String couponCode) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1D5F7), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.local_offer,
              color: Color(0xFF9C27B0),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                if (couponCode.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Mã: $couponCode',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '-${_formatPrice(value)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9C27B0),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkAllProductsReviewed() async {
    final orderId = _detail?['id'] as int?;
    if (orderId == null) return false;
    
    final products = ((_detail?['products'] ?? []) as List).cast<Map<String, dynamic>>();
    if (products.isEmpty) return false;
    
    // Kiểm tra từng sản phẩm
    for (var product in products) {
      final productId = _toInt(product['id'] ?? product['product_id']);
      if (productId == null) continue;
      
      final reviewStatus = await _api.checkProductReviewStatus(
        userId: widget.userId,
        orderId: orderId,
        productId: productId,
        variantId: _toInt(product['variant_id']),
      );
      
      if (reviewStatus?['has_review'] != true) {
        return false;
      }
    }
    
    return true;
  }
  
  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  Widget _buildReviewButton() {
    final orderId = _detail?['id'] as int?;
    final products = ((_detail?['products'] ?? []) as List).cast<Map<String, dynamic>>();
    
    return FutureBuilder<bool>(
      future: _checkAllProductsReviewed(),
      builder: (context, snapshot) {
        final allReviewed = snapshot.data ?? false;
        
        if (allReviewed) {
          // Đã đánh giá hết
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Đã đánh giá',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        
        // Chưa đánh giá hết
    return GestureDetector(
      onTap: () {
        if (orderId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductReviewScreen(
              orderId: orderId,
              products: products,
              onReviewSubmitted: () {
                _load();
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Đánh giá',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }

  // Action Buttons
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _requestCancel,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Yêu cầu hủy đơn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
                side: const BorderSide(color: Color(0xFFFF3B30)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _requestCancel() async {
    final user = await _auth.getCurrentUser();
    if (user == null) return;
    
    String? selectedReason;
    
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
          backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final cancelReasons = [
              'Tôi muốn cập nhật địa chỉ/sđt nhận hàng.',
              'Tôi muốn thêm/thay đổi Mã giảm giá',
              'Tôi muốn thay đổi sản phẩm (kích thước, màu sắc, số lượng...)',
              'Thủ tục thanh toán rắc rối',
              'Tôi tìm thấy chỗ mua khác tốt hơn (Rẻ hơn, uy tín hơn, giao nhanh hơn...)',
            ];
            
            return Container(
              decoration: const BoxDecoration(
              color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  // Handle bar
                Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                const Text(
                          'Lý Do Hủy',
                  style: TextStyle(
                            fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D1D1F),
                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 24),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                ),
                      ],
                    ),
                  ),
                  // Info box
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE58F)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                          'Chúng tôi mong muốn được biết lý do hủy đơn của bạn.',
                  style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nếu bạn xác nhận hủy, toàn bộ đơn hàng sẽ được hủy. Chọn lý do hủy phù hợp nhất với bạn nhé!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                ),
                        ),
                      ],
                    ),
                  ),
                  // Checkbox list
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: cancelReasons.length,
                      itemBuilder: (context, index) {
                        final reason = cancelReasons[index];
                        final isSelected = selectedReason == reason;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedReason = reason;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                Container(
                                  width: 20,
                                  height: 20,
                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFFF3B30)
                                          : Colors.grey[400]!,
                                      width: 2,
                  ),
                                    color: isSelected
                                        ? const Color(0xFFFF3B30)
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                      ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                      fontSize: 14,
                                      color: Colors.grey[900],
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                    ),
                  ),
                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Submit button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey[200]!,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedReason != null
                            ? () => Navigator.pop(context, selectedReason!)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedReason != null
                              ? const Color(0xFFFF3B30)
                              : Colors.grey[300],
                          foregroundColor: selectedReason != null
                              ? Colors.white
                              : Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Xác nhận',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ),
              ],
          ),
        );
      },
    );
      },
    );
    
    if (result == null) return; // User cancelled
    
    final res = await _api.orderCancelRequest(
      userId: user.userId,
      maDon: _detail?['ma_don']?.toString(),
      reason: result,
    );
    if (mounted) {
      if (res?['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy đơn hàng')));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể hủy: ${res?['message'] ?? ''}')));
      }
    }
  }
}



