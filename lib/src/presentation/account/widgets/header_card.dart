import 'package:flutter/material.dart';
import 'status_item.dart';
import 'dart:async';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/user.dart';
import '../../orders/orders_screen.dart';

class HeaderCard extends StatefulWidget {
  const HeaderCard({super.key});

  @override
  State<HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends State<HeaderCard> {
  final _authService = AuthService();
  final _apiService = ApiService();
  User? _currentUser;
  bool _isLoading = true;
  Map<String, int> _counts = const {
    'cho_xac_nhan': 0,
    'cho_lay_hang': 0,
    'cho_giao_hang': 0,
    'danh_gia': 0,
    'da_huy_don': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    
    // Thêm listener để cập nhật khi trạng thái đăng nhập thay đổi
    _authService.addAuthStateListener(_loadUserInfo);
    // Poll counts every 30s similar to Orders badges
    _startPolling();
  }

  @override
  void dispose() {
    // Xóa listener khi dispose
    _authService.removeAuthStateListener(_loadUserInfo);
    _pollTimer?.cancel();
    super.dispose();
  }

  Timer? _pollTimer;
  void _startPolling(){
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadCounts());
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        // Thử lấy thông tin mới nhất từ API user_profile
        try {
          final profile = await _apiService.getUserProfile(userId: user.userId);
          if (profile != null && profile['user'] != null) {
            final u = profile['user'] as Map<String, dynamic>;
            int parseInt(dynamic v) {
              if (v == null) return 0;
              if (v is int) return v;
              if (v is String) return int.tryParse(v) ?? 0;
              if (v is num) return v.toInt();
              return 0;
            }
            final updated = user.copyWith(
              name: (u['name']?.toString() ?? user.name),
              username: (u['username']?.toString() ?? user.username),
              email: (u['email']?.toString() ?? user.email),
              mobile: (u['mobile']?.toString() ?? user.mobile),
              avatar: (u['avatar']?.toString().isNotEmpty == true ? u['avatar'].toString() : user.avatar),
              userMoney: parseInt(u['user_money']),
              userMoney2: parseInt(u['user_money2']),
            );
            // CRITICAL: Chỉ update UI, KHÔNG lưu vào SharedPreferences để tránh restore sau logout
            if (mounted) {
              setState(() {
                _currentUser = updated;
                _isLoading = false;
              });
            }
            // Sau khi có user -> tải badge
            _loadCounts();
            _startPolling();
            return;
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
      _loadCounts();
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCounts() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.userId;
    // Use grouped logic to mirror Orders tabs
    final all = await _apiService.getOrdersList(userId: uid, page: 1, limit: 100, status: null);
    final list = (all?['data']?['orders'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    int toInt(dynamic v){ if(v is int) return v; if(v is String) return int.tryParse(v)??0; if(v is num) return v.toInt(); return 0; }
    int c0=0,c1=0,c2=0,c3=0,c4=0;
    for(final o in list){
      final s = toInt(o['status'] ?? o['trangthai']);
      if ([0].contains(s)) {
        c0++; // Chờ xác nhận
      } else if ([1, 11, 10, 12].contains(s)) c1++; // Chờ lấy hàng
      else if ([2, 8, 9, 7, 14].contains(s)) c2++; // Chờ giao hàng
      else if ([5].contains(s)) c3++; // Đánh giá (chỉ status 5 - Giao thành công)
      else if ([3, 4, 6].contains(s)) c4++; // Đã hủy (bao gồm status 3 - Yêu cầu hủy đơn, 4 - Đã hủy đơn, 6 - Đã hoàn đơn)
    }
    if (!mounted) return;
    setState(() {
      _counts = {
        'cho_xac_nhan': c0,
        'cho_lay_hang': c1,
        'cho_giao_hang': c2,
        'danh_gia': c3, // Đổi key từ 'da_huy_tra' thành 'danh_gia'
        'da_huy_don': c4,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFD9E3F0),
                    backgroundImage: _currentUser?.avatar != null && _currentUser!.avatar!.isNotEmpty
                        ? NetworkImage(_authService.getAvatarUrl(_currentUser!.avatar))
                        : const AssetImage('lib/src/core/assets/images/user_default.png') as ImageProvider,
                    onBackgroundImageError: (exception, stackTrace) {
                      // Fallback to default image if network image fails
                    },
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: () async {
                        // Điều hướng tới màn hình sửa avatar (sẽ thêm sau)
                        Navigator.of(context).pushNamed('/profile/edit');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.edit, size: 16, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      Container(
                        height: 20,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    else if (_currentUser != null)
                      Text(
                        _authService.getDisplayName(_currentUser!),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      )
                    else
                      const Text(
                        'Chưa đăng nhập',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey),
                      ),
                    const SizedBox(height: 4),
                    if (_isLoading)
                      Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    else if (_currentUser != null)
                      Text(
                        'Số dư: ${_authService.getFormattedBalance(_currentUser!)}',
                        style: const TextStyle(color: Colors.grey),
                      )
                    else
                      const Text(
                        'Đăng nhập để xem thông tin',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Container(
          //   decoration: BoxDecoration(
          //     color: const Color(0xFFF6F7FB),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   padding: const EdgeInsets.all(12),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     children: const [
          //       Text('Điểm tích luỹ của bạn là:'),
          //       Text('0', style: TextStyle(fontWeight: FontWeight.w700)),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // Kiểm tra chiều rộng màn hình
              final screenWidth = MediaQuery.of(context).size.width;
              final canFitAll = screenWidth >= 380; // Ngưỡng để hiển thị đầy đủ 4 mục
              
              if (canFitAll) {
                // Hiển thị đầy đủ 4 mục như ban đầu
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    StatusItem(
                      iconPath: 'assets/images/icons/pending-order.png',
                      label: 'Chờ xác nhận',
                      count: _counts['cho_xac_nhan'] ?? 0,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersShortcut(index: 0))),
                    ),
                    StatusItem(
                      iconPath: 'assets/images/icons/pickup1.png',
                      label: 'Chờ lấy hàng',
                      count: _counts['cho_lay_hang'] ?? 0,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersShortcut(index: 1))),
                    ),
                    StatusItem(
                      iconPath: 'assets/images/icons/shipping1.png',
                      label: 'Chờ giao hàng',
                      count: _counts['cho_giao_hang'] ?? 0,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersShortcut(index: 2))),
                    ),
                    StatusItem(
                      iconPath: 'assets/images/icons/rating.png',
                      label: 'Đánh giá',
                      count: _counts['danh_gia'] ?? 0,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersShortcut(index: 3))),
                    ),
                  ],
                );
              } else {
                // Cuộn ngang cho màn hình nhỏ
                return Stack(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          StatusItem(
                            iconPath: 'assets/images/icons/pending-order.png',
                            label: 'Chờ xác nhận',
                            count: _counts['cho_xac_nhan'] ?? 0,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersShortcut(index: 0))),
                          ),
                          const SizedBox(width: 12),
                          StatusItem(
                            iconPath: 'assets/images/icons/pickup1.png',
                            label: 'Chờ lấy hàng',
                            count: _counts['cho_lay_hang'] ?? 0,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersShortcut(index: 1))),
                          ),
                          const SizedBox(width: 12),
                          StatusItem(
                            iconPath: 'assets/images/icons/shipping1.png',
                            label: 'Chờ giao hàng',
                            count: _counts['cho_giao_hang'] ?? 0,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersShortcut(index: 2))),
                          ),
                          const SizedBox(width: 12),
                          StatusItem(
                            iconPath: 'assets/images/icons/rating.png',
                            label: 'Đánh giá',
                            count: _counts['danh_gia'] ?? 0,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersShortcut(index: 3))),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                    // Gradient fade effect để chỉ ra có thể cuộn
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          )
        ],
      ),
    );
  }
}

class _OrdersShortcut extends StatelessWidget {
  final int index;
  const _OrdersShortcut({required this.index});

  @override
  Widget build(BuildContext context) {
    return OrdersScreen(initialIndex: index);
  }
}

