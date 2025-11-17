import 'package:flutter/material.dart';
// import removed (not used while actions hidden)
import '../../core/services/affiliate_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/format_utils.dart';

class AffiliateOrdersScreen extends StatefulWidget {
  const AffiliateOrdersScreen({super.key});

  @override
  State<AffiliateOrdersScreen> createState() => _AffiliateOrdersScreenState();
}

class _AffiliateOrdersScreenState extends State<AffiliateOrdersScreen> {
  final AffiliateService _affiliateService = AffiliateService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _orders = [];
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUserId = user?.userId;
    });
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _affiliateService.getOrders(userId: _currentUserId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result != null && result['data'] != null && result['data']['orders'] != null) {
            _orders = result['data']['orders'] ?? [];
          } else {
            _orders = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi khi tải dữ liệu: $e';
          _isLoading = false;
          _orders = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng Affiliate'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrders,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Chưa có đơn hàng nào',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Khi có đơn hàng qua link affiliate sẽ hiển thị ở đây',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return _buildOrderCard(order);
                        },
                      ),
                    ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final products = (order['products'] ?? []) as List<dynamic>;
    final firstProduct = products.isNotEmpty ? products.first : null;
    final status = (order['status'] ?? {}) as Map<String, dynamic>;
    final statusText = status['text'] ?? 'Chờ xử lý';
    final statusColor = _parseColor(status['color'] ?? '#FFA500');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Order ID and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mã: ${order['ma_don'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Product Info
            if (firstProduct != null) ...[
              Row(
                children: [
                  // Product image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: (firstProduct != null &&
                            firstProduct['image'] != null &&
                            firstProduct['image'].toString().isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              firstProduct['image'].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.shopping_bag,
                                  color: Color(0xFF999999),
                                  size: 24,
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.shopping_bag,
                            color: Color(0xFF999999),
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstProduct['name'] ?? firstProduct['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if ((firstProduct['size'] ?? '').toString().isNotEmpty) ...[
                              Text(
                                'Size: ${firstProduct['size']}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if ((firstProduct['color'] ?? '').toString().isNotEmpty)
                              Text(
                                'Màu: ${firstProduct['color']}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                              ),
                          ],
                        ),
                        if (products.length > 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+${products.length - 1} sản phẩm khác',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Order Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tạm tính:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                      Text(
                        FormatUtils.formatCurrency((order['subtotal'] ?? 0).toInt()),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                  // Hidden: shipping fee & discount (tạm ẩn theo yêu cầu)
                  const SizedBox(height: 8),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng đơn hàng:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                      Text(
                        FormatUtils.formatCurrency((order['total_amount'] ?? 0).toInt()),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hoa hồng:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                      Text(
                        FormatUtils.formatCurrency(((order['commission'] ?? order['total_commission'] ?? 0)).toInt()),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tỉ lệ hoa hồng:',
                        style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (order['commission_rate_formatted'] ?? '${order['commission_rate'] ?? 0}%').toString(),
                          style: const TextStyle(fontSize: 11, color: Color(0xFFFF6B35)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Payment, shipping, dates and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping, size: 14, color: Color(0xFF999999)),
                          const SizedBox(width: 4),
                          Text(
                            (order['shipping_provider'] ?? '').toString(),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.payment, size: 14, color: Color(0xFF999999)),
                          const SizedBox(width: 4),
                          Text(
                            (order['payment_method'] ?? '').toString().toUpperCase(),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ngày: ${order['date_post_formatted'] ?? order['created_at'] ?? ''}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (order['commission_status'] == 'completed' || order['commission_paid'] == true)
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    (order['commission_status_text'] ?? ((order['commission_paid'] == true) ? 'Đã thanh toán' : 'Chờ thanh toán')).toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: (order['commission_status'] == 'completed' || order['commission_paid'] == true)
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            // Actions removed (tạm ẩn theo yêu cầu)
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFFFA500); // Default orange
    }
  }
}

