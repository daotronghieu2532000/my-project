import 'package:flutter/material.dart';
import 'widgets/platform_vouchers_tab.dart';
import 'widgets/shop_vouchers_tab.dart';
import '../root_shell.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mã giảm giá',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF5222D),
          indicatorWeight: 3,
          labelColor: const Color(0xFFF5222D),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.store, size: 20),
              text: 'Voucher sàn',
            ),
            Tab(
              icon: Icon(Icons.shop, size: 20),
              text: 'Voucher shop',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PlatformVouchersTab(),
          ShopVouchersTab(),
        ],
      ),
      bottomNavigationBar: const RootShellBottomBar(),
    );
  }
}
