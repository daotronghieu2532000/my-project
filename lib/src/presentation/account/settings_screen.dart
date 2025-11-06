import 'package:flutter/material.dart';
import 'widgets/section_header.dart';
import 'widgets/action_list.dart';
import 'widgets/logout_confirmation_dialog.dart';
import 'models/action_item.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_initialization_service.dart';
import '../root_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            ActionItem(Icons.manage_accounts_outlined, 'Thông tin cá nhân'),
            ActionItem(Icons.location_on_outlined, 'Sổ địa chỉ'),
          ]),
        
          const SizedBox(height: 12),
          const SectionHeader(title: 'Hỗ trợ'),
          ActionList(items: const [
            ActionItem(Icons.headset_mic_outlined, 'Trung tâm trợ giúp'),
            ActionItem(Icons.bug_report_outlined, 'Báo lỗi cho chúng tôi'),
            ActionItem(Icons.star_outline, 'Đánh giá ứng dụng'),
          ]),
          const SizedBox(height: 24),
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
                  'App version V3.4.34',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last updated 10.08.2025',
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

