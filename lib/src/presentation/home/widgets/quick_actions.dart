import 'package:flutter/material.dart';
import '../../flash_sale/flash_sale_screen.dart';
import '../../freeship/freeship_products_screen.dart';
import '../../voucher/voucher_screen.dart';
import '../../orders/orders_screen.dart';

class QuickActions extends StatelessWidget {
  final List<QAItem> items = const [
     QAItem('assets/images/icons/flash-sale1.png', Color.fromARGB(255, 182, 182, 182), 'FLASH SALE'),
     QAItem('assets/images/icons/freeship8.png', Color.fromARGB(255, 182, 182, 182), 'FREESHIP'),
     QAItem('assets/images/icons/coupon.png', Color.fromARGB(255, 182, 182, 182), 'VOUCHER'),
     QAItem('assets/images/icons/package.png', Color.fromARGB(255, 182, 182, 182), 'ĐƠN HÀNG'),
  ];

  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < items.length; i++)
            GestureDetector(
              onTap: () {
                if (i == 0) {
                  // Flash Sale item
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FlashSaleScreen()),
                  );
                } else if (i == 1) {
                  // Ship 0 đồng item
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FreeShipProductsScreen(),
                    ),
                  );
                } else if (i == 2) {
                  // Voucher item
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VoucherScreen()),
                  );
                } else if (i == 3) {
                  // Đơn hàng
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                }
                // Add other navigation logic for other items if needed
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: items[i].iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: items[i].iconColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        items[i].imagePath,
                        fit: BoxFit.contain,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Error loading image: ${items[i].imagePath}');
                          print('Error: $error');
                          return Icon(
                            Icons.error_outline,
                            color: items[i].iconColor,
                            size: 24,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    items[i].label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class QAItem {
  final String imagePath;
  final Color iconColor;
  final String label;
  const QAItem(this.imagePath, this.iconColor, this.label);
}
