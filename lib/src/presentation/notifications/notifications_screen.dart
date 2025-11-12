import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../root_shell.dart';
import '../auth/login_screen.dart';
import '../voucher/voucher_screen.dart';
import '../orders/orders_screen.dart';
import '../orders/order_detail_screen.dart';
import '../affiliate/affiliate_screen.dart';
import '../product/product_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  bool _loading = true;
  int _unread = 0;
  List<dynamic> _items = [];
  int? _userId;
  
  // Phân loại thông báo theo category
  Map<String, List<dynamic>> _groupedNotifications = {};
  
  // TabController cho tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _init();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final logged = await _auth.isLoggedIn();
    if (!mounted) return;
    if (!logged) {
      setState(() {
        _userId = null;
        _loading = false;
      });
      return;
    }
    final user = await _auth.getCurrentUser();
    _userId = user?.userId;
    await _load();
  }

  Future<void> _load() async {
    if (_userId == null) return;
    setState(() => _loading = true);
    final data = await _api.getNotifications(userId: _userId!, page: 1, limit: 100);
    if (!mounted) return;
    
    final items = (data?['data']?['notifications'] as List?) ?? [];
    
    // Nhóm thông báo theo category
    final grouped = <String, List<dynamic>>{
      'orders': [],
      'vouchers': [],
      'transactions': [],
      'affiliate': [],
      'other': [],
    };
    
    for (var item in items) {
      final type = item['type']?.toString() ?? '';
      if (type == 'order') {
        grouped['orders']!.add(item);
      } else if (type == 'voucher_new' || type == 'voucher_expiring') {
        grouped['vouchers']!.add(item);
      } else if (type == 'deposit' || type == 'withdrawal') {
        grouped['transactions']!.add(item);
      } else if (type == 'affiliate_order' || type == 'affiliate_product') {
        grouped['affiliate']!.add(item);
      } else {
        grouped['other']!.add(item);
      }
    }
    
    setState(() {
      _loading = false;
      _items = items;
      _unread = (data?['data']?['unread_count'] as int?) ?? 0;
      _groupedNotifications = grouped;
    });
  }

  Future<void> _markAllRead() async {
    if (_userId == null) return;
    final ok = await _api.markAllNotificationsRead(userId: _userId!);
    if (ok) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Future<void> _deleteAllNotifications() async {
    if (_userId == null) return;
    final ok = await _api.deleteAllNotifications(userId: _userId!);
    if (ok) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa tất cả thông báo'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _markRead(int id) async {
    if (_userId == null) return;
    final ok = await _api.markNotificationRead(userId: _userId!, notificationId: id);
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF2196F3).withOpacity(0.1),
              ),
              indicatorColor: const Color(0xFF2196F3),
              labelColor: const Color(0xFF2196F3),
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                _buildTab(
                  'Tất cả',
                  _items.length,
                  Icons.notifications_outlined,
                ),
                _buildTab(
                  'Đơn hàng',
                  _groupedNotifications['orders']?.length ?? 0,
                  Icons.shopping_bag_outlined,
                ),
                _buildTab(
                  'Voucher',
                  _groupedNotifications['vouchers']?.length ?? 0,
                  Icons.card_giftcard_outlined,
                ),
                _buildTab(
                  'Giao dịch',
                  _groupedNotifications['transactions']?.length ?? 0,
                  Icons.account_balance_wallet_outlined,
                ),
                _buildTab(
                  'Affiliate',
                  _groupedNotifications['affiliate']?.length ?? 0,
                  Icons.handshake_outlined,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: Colors.white,
              onSelected: (value) {
                if (value == 'mark_all_read' && _unread > 0) {
                  _markAllRead();
                } else if (value == 'delete_all') {
                  _showDeleteConfirmDialog(context);
                }
              },
              itemBuilder: (context) => [
                if (_unread > 0)
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Đánh dấu tất cả đã đọc'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Xóa tất cả thông báo'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_userId == null) {
            return _LoggedOutView(onLoginSuccess: _init);
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: Column(
              children: [
                // Header với số lượng thông báo
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _unread > 0 
                                ? [const Color(0xFF4CAF50), const Color(0xFF45A049)]
                                : [const Color(0xFF9E9E9E), const Color(0xFF757575)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _unread > 0
                                  ? 'Bạn có $_unread thông báo mới'
                                  : 'Không có thông báo mới',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cập nhật lần cuối: Hôm nay',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // TabBarView với nội dung từng tab
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab: Tất cả
                      _buildTabContent(_items),
                      // Tab: Đơn hàng
                      _buildTabContent(_groupedNotifications['orders'] ?? []),
                      // Tab: Voucher
                      _buildTabContent(_groupedNotifications['vouchers'] ?? []),
                      // Tab: Giao dịch
                      _buildTabContent(_groupedNotifications['transactions'] ?? []),
                      // Tab: Affiliate
                      _buildTabContent(_groupedNotifications['affiliate'] ?? []),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const RootShellBottomBar(),
    );
  }

  // Widget tạo tab với badge số lượng
  Widget _buildTab(String label, int count, IconData icon) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Widget tạo nội dung cho từng tab
  Widget _buildTabContent(List<dynamic> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có thông báo',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Khi có thông báo mới, chúng sẽ xuất hiện ở đây',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _NotificationItemWidget(
            id: notification['id'] ?? 0,
            iconWidget: _getNotificationIcon(
              notification['type']?.toString(),
              notification['title']?.toString(),
            ),
            title: notification['title']?.toString() ?? 'Thông báo',
            subtitle: notification['content']?.toString() ?? '',
            time: notification['time_ago']?.toString() ?? '',
            isRead: (notification['is_read'] as bool?) ?? false,
            priority: notification['priority']?.toString() ?? 'medium',
            data: notification['data'] as Map<String, dynamic>?,
            onMarkRead: _markRead,
            onTap: () => _handleNotificationTap(notification),
          ),
        );
      },
    );
  }

  // Xử lý khi click vào thông báo
  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type']?.toString() ?? '';
    final relatedId = notification['related_id'];
    final data = notification['data'] as Map<String, dynamic>?;
    
    if (_userId == null) return;
    
    switch (type) {
      case 'order':
        // Nếu có order_id hoặc order_code, đi đến chi tiết đơn hàng
        if (relatedId != null && relatedId > 0) {
          final orderCode = data?['order_code']?.toString();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                userId: _userId!,
                orderId: relatedId is int ? relatedId : int.tryParse(relatedId.toString()),
                maDon: orderCode,
              ),
            ),
          );
        } else {
          // Nếu không có, đi đến danh sách đơn hàng
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrdersScreen()),
          );
        }
        break;
        
      case 'voucher_new':
      case 'voucher_expiring':
        // Đi đến màn hình voucher
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoucherScreen()),
        );
        break;
        
      case 'deposit':
      case 'withdrawal':
        // Đi đến màn hình affiliate (có phần giao dịch)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AffiliateScreen()),
        );
        break;
        
      case 'affiliate_order':
      case 'affiliate_product':
      case 'affiliate_daily':
        // Đi đến màn hình affiliate
        // Nếu có product_id trong data, có thể navigate đến product detail
        final productId = data?['product_id'];
        if (productId != null) {
          final productIdInt = productId is int 
              ? productId 
              : (productId is String ? int.tryParse(productId) : null);
          
          if (productIdInt != null && productIdInt > 0) {
            // Navigate đến product detail
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(productId: productIdInt),
              ),
            );
            break;
          }
        }
        
        // Fallback: Navigate đến affiliate screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AffiliateScreen()),
        );
        break;
        
      default:
        // Không làm gì cho các loại khác
        break;
    }
  }

  Widget _getNotificationIcon(String? type, String? title) {
    // Nếu là đơn hàng, phân tích title để lấy icon/màu phù hợp
    if (type == 'order' && title != null) {
      return _getOrderStatusIcon(title);
    }
    
    // Các loại thông báo khác
    switch (type) {
      case 'affiliate_order':
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.handshake_outlined,
            color: Colors.white,
            size: 22,
          ),
        );
      case 'deposit':
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00BCD4).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.trending_up_outlined,
            color: Colors.white,
            size: 22,
          ),
        );
      case 'withdrawal':
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF9800).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.trending_down_outlined,
            color: Colors.white,
            size: 22,
          ),
        );
      case 'voucher_new':
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE91E63).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.card_giftcard_outlined,
            color: Colors.white,
            size: 22,
          ),
        );
      case 'voucher_expiring':
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF9C27B0).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 22,
          ),
        );
      default:
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF607D8B), Color(0xFF455A64)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF607D8B).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 22,
          ),
        );
    }
  }

  Widget _getOrderStatusIcon(String title) {
    // Phân tích title để xác định trạng thái đơn hàng
    if (title.contains('đã được xác nhận')) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)], // Xanh dương
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2196F3).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.check_circle_outlined,
          color: Colors.white,
          size: 22,
        ),
      );
    } else if (title.contains('đang được giao')) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFF57C00)], // Cam
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF9800).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.local_shipping_outlined,
          color: Colors.white,
          size: 22,
        ),
      );
    } else if (title.contains('đã giao thành công')) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF388E3C)], // Xanh lá
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.done_all_outlined,
          color: Colors.white,
          size: 22,
        ),
      );
    } else if (title.contains('đã bị hủy')) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF44336), Color(0xFFD32F2F)], // Đỏ
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF44336).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.cancel_outlined,
          color: Colors.white,
          size: 22,
        ),
      );
    } else if (title.contains('đã hoàn trả')) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)], // Tím
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF9C27B0).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.undo_outlined,
          color: Colors.white,
          size: 22,
        ),
      );
    } else {
      // Trạng thái mặc định
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF607D8B), Color(0xFF455A64)], // Xám
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF607D8B).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.shopping_bag_outlined,
          color: Colors.white,
          size: 22,
        ),
      );
    }
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Xóa tất cả thông báo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: const Text(
            'Bạn có chắc chắn muốn xóa tất cả thông báo? Hành động này không thể hoàn tác.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Hủy',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAllNotifications();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Xóa',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationItemWidget extends StatefulWidget {
  final int id;
  final Widget iconWidget;
  final String title;
  final String subtitle;
  final String time;
  final bool isRead;
  final String priority;
  final Map<String, dynamic>? data;
  final Function(int) onMarkRead;
  final VoidCallback? onTap;

  const _NotificationItemWidget({
    required this.id,
    required this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isRead,
    required this.priority,
    this.data,
    required this.onMarkRead,
    this.onTap,
  });

  @override
  State<_NotificationItemWidget> createState() => _NotificationItemWidgetState();
}

class _NotificationItemWidgetState extends State<_NotificationItemWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin sản phẩm từ data
    String? productImage;
    String? productTitle;
    if (widget.data != null) {
      productImage = widget.data!['product_image']?.toString();
      // Sửa URL ảnh nếu bắt đầu bằng /uploads/
      if (productImage != null && productImage.isNotEmpty) {
        if (productImage.startsWith('/uploads/')) {
          productImage = 'https://socdo.vn$productImage';
        } else if (!productImage.startsWith('http')) {
          productImage = 'https://socdo.vn/uploads/$productImage';
        }
      }
      productTitle = widget.data!['product_title']?.toString();
    }

    // Kiểm tra nội dung có dài không
    bool isLongContent = widget.subtitle.length > 100;
    
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: widget.priority == 'high' && !widget.isRead 
              ? const Border(left: BorderSide(color: Color(0xFFEF4444), width: 3))
              : null,
        ),
        child: ListTile(
        leading: productImage != null && productImage.isNotEmpty
            ? Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    productImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey[400],
                          size: 24,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            : widget.iconWidget,
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontWeight: widget.isRead ? FontWeight.w500 : FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.priority == 'high' && !widget.isRead)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.priority_high,
                  color: Colors.white,
                  size: 12,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Nội dung thông báo với tính năng rút gọn
            Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: _isExpanded ? null : 2,
              overflow: _isExpanded ? null : TextOverflow.ellipsis,
            ),
            if (isLongContent) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(
                  _isExpanded ? 'Thu gọn' : 'Xem thêm',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (productTitle != null && productTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 12,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      productTitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.access_time_outlined,
                  size: 11,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  widget.time,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
                const Spacer(),
                if (!widget.isRead)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.priority == 'high' 
                          ? const Color(0xFFEF4444) 
                          : const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      ),
    );
  }

}

class _LoggedOutView extends StatelessWidget {
  final VoidCallback onLoginSuccess;
  
  const _LoggedOutView({required this.onLoginSuccess});
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image with opacity
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('lib/src/core/assets/images/logo_socdo.png'),
              fit: BoxFit.cover,
              opacity: 0.15, // Mờ mờ cho đẹp
            ),
          ),
        ),
        // Subtle overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.8),
                Colors.white.withOpacity(0.9),
              ],
            ),
          ),
        ),
        // Content
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo/Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  size: 40,
                  color: Color(0xFFDC3545),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Bạn chưa đăng nhập',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đăng nhập để xem thông báo của bạn',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFDC3545),
                      Color(0xFFC82333),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC3545).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                    
                    // Nếu đăng nhập thành công, refresh trạng thái
                    if (result == true) {
                      onLoginSuccess();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}