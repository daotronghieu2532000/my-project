import 'package:flutter/material.dart';
import 'widgets/all_orders_section.dart';
import '../../core/services/auth_service.dart';
import '../root_shell.dart';

class AllOrdersAccountScreen extends StatefulWidget {
  const AllOrdersAccountScreen({super.key});

  @override
  State<AllOrdersAccountScreen> createState() => _AllOrdersAccountScreenState();
}

class _AllOrdersAccountScreenState extends State<AllOrdersAccountScreen> {
  final AuthService _auth = AuthService();
  int? _userId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final loggedIn = await _auth.isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      final user = await _auth.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _userId = user?.userId;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Tất cả đơn hàng',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _userId == null
              ? const Center(
                  child: Text(
                    'Vui lòng đăng nhập để xem đơn hàng',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
                  ),
                )
              : AllOrdersSection(userId: _userId!),
      bottomNavigationBar: const RootShellBottomBar(),
    );
  }
}

