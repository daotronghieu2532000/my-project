import 'package:flutter/material.dart';
import 'widgets/header_card.dart';
import 'widgets/section_header.dart';
import 'widgets/action_list.dart';
import 'models/action_item.dart';
import '../root_shell.dart';
import 'settings_screen.dart';
import '../home/widgets/product_grid.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Tài khoản của tôi',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          HeaderCard(),
          const SizedBox(height: 12),
          const SectionHeader(title: 'Danh mục '),
          ActionList(
            items: const [
            ActionItem.withImage('assets/images/icons/all_order.png', 'Lịch sử mua hàng'),
            ActionItem.withImage('assets/images/icons/rebuy.png', 'Mua lại'),
            ActionItem.withImage('assets/images/icons/heart.png', 'Sản phẩm yêu thích'),
            ActionItem.withImage('assets/images/icons/voucher2.png', 'Mã giảm giá'),
            ActionItem.withImage('assets/images/icons/rating.png', 'Lịch sử đánh giá'),
            // ActionItem(Icons.cancel_outlined, 'Đã huỷ & Trả lại'),
            ],
          ),
          // const SizedBox(height: 12),
          // const SectionHeader(title: 'Cá nhân'),
          // ActionList(items: const [
           
          // ]),
          const SizedBox(height: 24),
          // Gợi ý tới bạn section
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: Colors.grey.withOpacity(0.3),
                    ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Text(
                          'Sản phẩm dành cho bạn',
                    style: TextStyle(
                      fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
              ),
            ),
          ),
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: Colors.grey.withOpacity(0.3),
                  ),
                ),
                    ],
                  ),
                ),
                ProductGrid(title: ''),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: const RootShellBottomBar(),
    );
  }
}



