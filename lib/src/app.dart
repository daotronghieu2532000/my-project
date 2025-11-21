import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/services/notification_handler.dart';
import 'presentation/splash/splash_screen.dart';
import 'presentation/profile/profile_edit_screen.dart';
import 'presentation/profile/address_book_screen.dart';
import 'presentation/orders/orders_screen.dart';
import 'presentation/notifications/notifications_screen.dart';
import 'presentation/orders/order_success_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/chat/chat_list_screen.dart';

class SocdoApp extends StatelessWidget {
  const SocdoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cấu hình status bar để hiển thị đúng trên iOS
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Trong suốt để hiển thị nền app
        statusBarIconBrightness: Brightness.dark, // Icon màu đen (cho nền sáng)
        statusBarBrightness: Brightness.light, // iOS
      ),
    );
    
    return MaterialApp(
      navigatorKey: NotificationHandler.navigatorKey,
      title: 'Socdo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/profile/edit': (context) => const ProfileEditScreen(),
        '/profile/address': (context) => const AddressBookScreen(),
        '/orders': (context) => const OrdersScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/chat': (context) => const ChatListScreen(),
        // order success requires argument maDon
        '/order/success': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final maDon = args?['ma_don']?.toString() ?? '';
          final orders = args?['orders'] as List<dynamic>?;
          final summary = args?['summary'] as Map<String, dynamic>?;
          return OrderSuccessScreen(
            maDon: maDon,
            orders: orders,
            summary: summary,
          );
        },
      },
    );
  }
}




