import 'package:flutter/material.dart';
import '../../favorite_products/favorite_products_screen.dart';
import '../../orders/orders_screen.dart';
import '../../profile/address_book_screen.dart';
import '../../voucher/voucher_screen.dart';
import '../../purchased_products/purchased_products_screen.dart';
import '../app_rating_screen.dart';
import '../app_report_screen.dart';
import '../support_center_screen.dart';
import '../all_orders_account_screen.dart';
import '../review_history_screen.dart';
import '../change_password_screen.dart';

class ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  const ActionRow({super.key, required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Lấy màu icon dựa trên title nếu không có màu được chỉ định
    final iconColor = _getIconColor(title);
    
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap ?? () => _handleNavigation(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }

  // Hàm lấy màu icon dựa trên title
  Color _getIconColor(String title) {
    switch (title) {
      case 'Thông tin cá nhân':
        return Colors.blue;
      case 'Tất cả đơn hàng':
        return Colors.orange;
      case 'Sản phẩm yêu thích':
        return Colors.red;
      case 'Mua lại':
        return Colors.blue;
      case 'Sổ địa chỉ':
        return Colors.green;
      case 'Đổi mật khẩu':
        return Colors.teal;
      case 'Mã giảm giá':
        return Colors.purple;
      case 'Lịch sử đánh giá':
        return Colors.amber;
      case 'Đã huỷ & Trả lại':
        return const Color.fromARGB(255, 255, 0, 0);
      case 'Trung tâm trợ giúp':
        return Colors.blue;
      case 'Báo lỗi cho chúng tôi':
        return Colors.red;
      case 'Đánh giá ứng dụng':
        return Colors.amber;
      case 'Xóa tài khoản':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _handleNavigation(BuildContext context) {
    switch (title) {
      case 'Lịch sử mua hàng':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AllOrdersAccountScreen(),
          ),
        );
        break;
      case 'Thông tin cá nhân':
        Navigator.pushNamed(context, '/profile/edit');
        break;
      case 'Đổi mật khẩu':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChangePasswordScreen(),
          ),
        );
        break;
      case 'Sản phẩm yêu thích':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FavoriteProductsScreen(),
          ),
        );
        break;
      case 'Mua lại':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PurchasedProductsScreen(),
          ),
        );
        break;
      case 'Sổ địa chỉ':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddressBookScreen(),
          ),
        );
        break;
      case 'Mã giảm giá':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VoucherScreen(),
          ),
        );
        break;
      case 'Lịch sử đánh giá':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ReviewHistoryScreen(),
          ),
        );
        break;
      case 'Thông báo':
        Navigator.pushNamed(context, '/notifications');
        break;
      case 'Đã huỷ & Trả lại':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OrdersScreen(initialIndex: 4),
          ),
        );
        break;
      case 'Báo lỗi cho chúng tôi':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AppReportScreen(),
          ),
        );
        break;
      case 'Đánh giá ứng dụng':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AppRatingScreen(),
          ),
        );
        break;
      case 'Trung tâm trợ giúp':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SupportCenterScreen(),
          ),
        );
        break;
      default:
        // Handle other navigation cases
        break;
    }
  }
}
