import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../orders/order_detail_screen.dart';
import '../../orders/product_review_screen.dart';

class AllOrdersSection extends StatefulWidget {
  final int userId;
  const AllOrdersSection({super.key, required this.userId});

  @override
  State<AllOrdersSection> createState() => _AllOrdersSectionState();
}

class _AllOrdersSectionState extends State<AllOrdersSection> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  Map<String, bool> _reviewStatusCache = {}; // Cache trạng thái đánh giá: "orderId_productId" -> hasReview

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    
    // Lấy tất cả đơn hàng với all=1
    final data = await _api.getOrdersList(
      userId: widget.userId,
      page: 1,
      limit: 999999,
      status: null,
    );
    
    if (!mounted) return;
    
    final fetched = (data?['data']?['orders'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    // Sắp xếp theo thứ tự: 0,1,2 -> 5 -> 3,4 và các trạng thái khác
    final sorted = _sortOrders(fetched);
    
    setState(() {
      _orders = sorted;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> orders) {
    // Nhóm đơn hàng theo thứ tự ưu tiên
    final List<Map<String, dynamic>> priority1 = []; // 0, 1, 2
    final List<Map<String, dynamic>> priority2 = []; // 5
    final List<Map<String, dynamic>> priority3 = []; // 3, 4 và các trạng thái khác
    
    for (final order in orders) {
      final status = _toInt(order['status']);
      if (status == 0 || status == 1 || status == 2) {
        priority1.add(order);
      } else if (status == 5) {
        priority2.add(order);
      } else {
        priority3.add(order);
      }
    }
    
    // Sắp xếp mỗi nhóm theo date_post DESC (mới nhất trước)
    void sortByDate(List<Map<String, dynamic>> list) {
      list.sort((a, b) {
        final dateA = _toInt(a['date_post']) ?? 0;
        final dateB = _toInt(b['date_post']) ?? 0;
        return dateB.compareTo(dateA);
      });
    }
    
    sortByDate(priority1);
    sortByDate(priority2);
    sortByDate(priority3);
    
    // Kết hợp: priority1 -> priority2 -> priority3
    return [...priority1, ...priority2, ...priority3];
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_orders.isEmpty) {
      return const Center(
        child: Text(
          'Bạn chưa có đơn hàng nào',
          style: TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final List products = (o['products'] as List?) ?? [];
    final Map<String, dynamic>? first = products.isNotEmpty 
        ? (products.first as Map).cast<String, dynamic>() 
        : null;
    final int count = _toInt(o['product_count']) ?? products.length;
    final Color statusColor = _statusColor(_toInt(o['status']));
    final String shopName = first?['shop_name']?.toString() ?? '';
    final String etaText = o['delivery_eta_text']?.toString() ?? '';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(
              userId: widget.userId,
              maDon: o['ma_don'],
              orderId: _toInt(o['id']),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEAEAEA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: shop + status chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (shopName.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Shop',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFF5222D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              shopName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          Expanded(
                            child: Text(
                              o['ma_don'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      o['status_text'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Product summary row (image + info)
              _buildProductSummary(first, count),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Tổng số tiền: ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                  ),
                  Text(
                    _formatPrice(o['tongtien_formatted'] ?? ''),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0)),
                ],
              ),
              // Show shipping fee if available
              if ((o['phi_ship'] ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Phí vận chuyển: ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                    ),
                    Text(
                      _formatPrice(o['phi_ship_formatted'] ?? ''),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
              // Show voucher info if available
              if ((o['voucher_tmdt'] ?? 0) > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE1D5F7), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_offer, size: 14, color: Color(0xFF9C27B0)),
                      const SizedBox(width: 4),
                      Text(
                        'Đã áp voucher: -${_formatPrice(o['voucher_tmdt_formatted'] ?? '')}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Show delivery ETA if available
              if (etaText.isNotEmpty || (o['date_update_formatted'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBAE7FF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping, size: 16, color: Color(0xFF1890FF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          etaText.isNotEmpty
                              ? 'Thời gian giao dự kiến: $etaText'
                              : 'Cập nhật: ${o['date_update_formatted']?.toString() ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1890FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Show review button for status 5 (Giao thành công)
              if ((o['status'] as int? ?? 0) == 5) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    _buildReviewButton(o),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSummary(Map<String, dynamic>? first, int count) {
    if (first == null) {
      return const SizedBox.shrink();
    }
    final String img = (first['image'] ?? '').toString();
    final String fixed = img.startsWith('http')
        ? img
        : (img.isEmpty ? '' : 'https://socdo.vn$img');
    final String title = (first['name'] ?? '').toString();
    final String variant = [
      first['color'],
      first['size']
    ].where((e) => (e?.toString().isNotEmpty ?? false)).join(' • ');
    final int price = (first['price'] as int?) ?? 0;
    final int total = (first['total'] as int?) ?? price;
    final int oldPrice = (first['old_price'] as int?) ?? 0;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            fixed,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 64,
              height: 64,
              color: const Color(0xFFF5F5F5),
              child: const Icon(
                Icons.image_not_supported,
                size: 20,
                color: Color(0xFF999999),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF333333),
                ),
              ),
              if (variant.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  variant,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  if (oldPrice > 0 && oldPrice > price) ...[
                    Text(
                      _formatCurrency(oldPrice),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _formatCurrency(price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'x$count',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                  ),
                  const Spacer(),
                  Text(
                    _formatCurrency(total),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCurrency(int v) {
    return '${_group(v)}đ';
  }

  String _group(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatPrice(String priceText) {
    return priceText.replaceAll(',', '.');
  }

  Color _statusColor(int? status) {
    switch (status) {
      case 0:
      case 1:
        return const Color(0xFFFA8C16); // pending
      case 11:
      case 10:
      case 12:
        return const Color(0xFF1890FF); // pickup
      case 2:
      case 8:
      case 9:
      case 7:
      case 14:
        return const Color(0xFF722ED1); // shipping
      case 5:
        return const Color(0xFF52C41A); // delivered/rating
      case 3:
        return const Color(0xFFFF9800); // cancel-request (orange)
      case 6:
        return const Color(0xFFF5222D); // returned
      case 4:
        return const Color(0xFF999999); // cancelled
      default:
        return const Color(0xFF6C757D);
    }
  }

  Future<bool> _checkAllProductsReviewed(Map<String, dynamic> order) async {
    final orderId = _toInt(order['id']);
    if (orderId == null) return false;
    
    final products = (order['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (products.isEmpty) return false;
    
    // Kiểm tra từng sản phẩm
    for (var product in products) {
      final productId = _toInt(product['id'] ?? product['product_id']);
      if (productId == null) continue;
      
      final cacheKey = '${orderId}_$productId';
      if (_reviewStatusCache.containsKey(cacheKey)) {
        if (!_reviewStatusCache[cacheKey]!) return false;
        continue;
      }
      
      // Gọi API để check
      final reviewStatus = await _api.checkProductReviewStatus(
        userId: widget.userId,
        orderId: orderId,
        productId: productId,
        variantId: _toInt(product['variant_id']),
      );
      
      final hasReview = reviewStatus?['has_review'] == true;
      _reviewStatusCache[cacheKey] = hasReview;
      
      if (!hasReview) return false;
    }
    
    return true;
  }

  Widget _buildReviewButton(Map<String, dynamic> order) {
    final orderId = _toInt(order['id']);
    final products = (order['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    return FutureBuilder<bool>(
      future: _checkAllProductsReviewed(order),
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
                Icon(Icons.check_circle, size: 14, color: Colors.grey),
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
                    // Clear cache để refresh
                    _reviewStatusCache.clear();
                    _loadOrders();
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
                Icon(Icons.star, size: 14, color: Colors.white),
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
}

