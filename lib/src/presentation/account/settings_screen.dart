import 'package:flutter/material.dart';
import 'widgets/section_header.dart';
import 'widgets/action_list.dart';
import 'widgets/logout_confirmation_dialog.dart';
import 'models/action_item.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_initialization_service.dart';
import '../../core/services/api_service.dart';
import '../root_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final authService = AuthService();
    final apiService = ApiService();
    
    // Kiểm tra đăng nhập
    final isLoggedIn = await authService.isLoggedIn();
    if (!isLoggedIn) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn chưa đăng nhập'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    final currentUser = await authService.getCurrentUser();
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xác định thông tin tài khoản'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Hiển thị dialog xác nhận
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Xóa tài khoản',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn có chắc chắn muốn xóa tài khoản của mình?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hành động này không thể hoàn tác. Tất cả dữ liệu của bạn sẽ bị xóa vĩnh viễn.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
    
    if (shouldDelete != true) return;
    
    // Hiển thị loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    try {
      // Gọi API xóa tài khoản
      final success = await apiService.deleteAccount(
        userId: currentUser.userId,
        reason: 'User requested account deletion',
      );
      
      if (context.mounted) {
        Navigator.pop(context); // Đóng loading dialog
      }
      
      if (success) {
        // Logout và xóa dữ liệu local
        await authService.logoutCompletely();
        AppInitializationService().resetInitialization();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tài khoản đã được xóa thành công'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Đẩy về trang đăng nhập
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể xóa tài khoản. Vui lòng thử lại sau.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Đóng loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Thiết lập tài khoản',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          const SectionHeader(title: 'Tài khoản'),
          ActionList(items: const [
            ActionItem.withImage('assets/images/icons/user-setting.png', 'Thông tin cá nhân'),
            ActionItem.withImage('assets/images/icons/change-pass.png', 'Đổi mật khẩu'),
            ActionItem.withImage('assets/images/icons/user-location.png', 'Sổ địa chỉ'),
          ]),
        
          const SizedBox(height: 12),
          const SectionHeader(title: 'Hỗ trợ'),
          ActionList(
            items: const [
              ActionItem.withImage('assets/images/icons/customer-service.png', 'Trung tâm trợ giúp'),
              ActionItem.withImage('assets/images/icons/error-message.png', 'Báo lỗi cho chúng tôi'),
              ActionItem.withImage('assets/images/icons/rating-stars.png', 'Đánh giá ứng dụng'),
              ActionItem.withImage('assets/images/icons/delete_user.png', 'Xóa tài khoản'),
            ],
            onTapCallbacks: {
              'Xóa tài khoản': () => _handleDeleteAccount(context),
            },
          ),
          const SizedBox(height: 12),
          // Logout Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () async {
                final authService = AuthService();
                final isLoggedIn = await authService.isLoggedIn();
                
                if (isLoggedIn) {
                  // Show confirmation dialog
                  final shouldLogout = await LogoutConfirmationDialog.show(context);
                  
                  if (shouldLogout == true) {
                    // CRITICAL: Sử dụng logoutCompletely để đảm bảo logout hoàn toàn
                    await authService.logoutCompletely();
                    
                    // Reset app initialization state
                    AppInitializationService().resetInitialization();
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã đăng xuất '),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // Quay về trang chủ và refresh toàn bộ navigation stack
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const RootShell(initialIndex: 0),
                        ),
                        (route) => false,
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bạn chưa đăng nhập'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Đăng xuất',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // App Version Info
          Center(
            child: Column(
              children: [
                Text(
                  'App version Socdo 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phát triển bởi Socdo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

