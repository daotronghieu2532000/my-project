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
            content: Text('Đã đọc tất cả thông báo'),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        shadowColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
              ),
              indicatorColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              icon: const Icon(Icons.more_vert, color: Color(0xFF1A1A1A)),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              onSelected: (value) {
                if (value == 'mark_all_read' && _unread > 0) {
                  _markAllRead();
                } else if (value == 'delete_all') {
                  _showDeleteConfirmDialog(context);
                }
              },
              itemBuilder: (context) => [
                if (_unread > 0)
                  PopupMenuItem(
                    value: 'mark_all_read',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF6366F1),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Đánh dấu tất cả đã đọc',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Xóa tất cả thông báo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: _unread > 0
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF94A3B8),
                              const Color(0xFF64748B),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_unread > 0 ? const Color(0xFF6366F1) : const Color(0xFF94A3B8))
                            .withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _unread > 0
                                  ? 'Bạn có $_unread thông báo mới'
                                  : 'Không có thông báo mới',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cập nhật lần cuối: Hôm nay',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (notification['is_read'] as bool?) ?? false
                  ? Colors.grey[200]!
                  : const Color(0xFF6366F1).withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.handshake_outlined,
            color: Colors.white,
            size: 24,
          ),
        );
      case 'deposit':
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.trending_up_outlined,
            color: Colors.white,
            size: 24,
          ),
        );
      case 'withdrawal':
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.trending_down_outlined,
            color: Colors.white,
            size: 24,
          ),
        );
      case 'voucher_new':
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.card_giftcard_outlined,
            color: Colors.white,
            size: 24,
          ),
        );
      case 'voucher_expiring':
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFA855F7), Color(0xFF9333EA)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA855F7).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 24,
          ),
        );
      default:
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF64748B), Color(0xFF475569)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 24,
          ),
        );
    }
  }

  Widget _getOrderStatusIcon(String title) {
    // Phân tích title để xác định trạng thái đơn hàng
    if (title.contains('đã được xác nhận')) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_circle_outlined,
          color: Colors.white,
          size: 24,
        ),
      );
    } else if (title.contains('đang được giao')) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.local_shipping_outlined,
          color: Colors.white,
          size: 24,
        ),
      );
    } else if (title.contains('đã giao thành công')) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.done_all_outlined,
          color: Colors.white,
          size: 24,
        ),
      );
    } else if (title.contains('đã bị hủy')) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.cancel_outlined,
          color: Colors.white,
          size: 24,
        ),
      );
    } else if (title.contains('đã hoàn trả')) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA855F7), Color(0xFF9333EA)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA855F7).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.undo_outlined,
          color: Colors.white,
          size: 24,
        ),
      );
    } else {
      // Trạng thái mặc định
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF64748B), Color(0xFF475569)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64748B).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.shopping_bag_outlined,
          color: Colors.white,
          size: 24,
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
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isRead 
                ? Colors.white 
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: widget.priority == 'high' && !widget.isRead 
                ? Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon hoặc ảnh sản phẩm
              productImage != null && productImage.isNotEmpty
                  ? Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
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
              const SizedBox(width: 12),
              // Nội dung thông báo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề và badge priority
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontWeight: widget.isRead 
                                  ? FontWeight.w600 
                                  : FontWeight.w700,
                              fontSize: 15,
                              color: const Color(0xFF1A1A1A),
                              letterSpacing: -0.2,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.priority == 'high' && !widget.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.priority_high,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Nội dung thông báo
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: _isExpanded ? null : 2,
                      overflow: _isExpanded ? null : TextOverflow.ellipsis,
                    ),
                    // Nút Xem thêm / Thu gọn
                    if (isLongContent) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isExpanded ? 'Thu gọn' : 'Xem thêm',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF6366F1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _isExpanded 
                                    ? Icons.keyboard_arrow_up 
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: const Color(0xFF6366F1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Tên sản phẩm nếu có
                    if (productTitle != null && productTitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 14,
                              color: const Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                productTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF6366F1),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Thời gian và badge đọc/chưa đọc
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.time,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        if (!widget.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.priority == 'high'
                                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                    : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                              ),
                              shape: BoxShape.circle,
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
      ),
    );
  }

}

class _LoggedOutView extends StatelessWidget {
  final VoidCallback onLoginSuccess;
  
  const _LoggedOutView({required this.onLoginSuccess});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo/Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
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
    );
  }
}