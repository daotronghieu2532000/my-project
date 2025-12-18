import 'package:flutter/material.dart';
import '../../../core/models/bonus_config.dart';
import '../../../core/utils/format_utils.dart';

/// Dialog cảm ơn khi người dùng tải app và đăng nhập thành công lần đầu
/// Hiển thị 1 lần duy nhất khi nhận được bonus
class WelcomeBonusDialog extends StatelessWidget {
  final VoidCallback onClose;
  final BonusConfig config;
  
  const WelcomeBonusDialog({
    super.key,
    required this.onClose,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon cảm ơn
            // Container(
            //   width: 80,
            //   height: 80,
            //   decoration: BoxDecoration(
            //     color: Colors.orange.shade100,
            //     shape: BoxShape.circle,
            //   ),
            //   child: Icon(
            //     Icons.celebration,
            //     size: 50,
            //     color: Colors.orange.shade700,
            //   ),
            // ),
            const SizedBox(height: 20),
            
            // Tiêu đề (từ config)
            Text(
              config.dialogTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Nội dung (từ config)
            Text(
              config.dialogMessage,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Số tiền bonus (từ config)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.orange.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    FormatUtils.formatCurrency(config.bonusAmount),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            
            Builder(
              builder: (context) {
                // Format danh sách shop (lấy tất cả shop, join bằng dấu phẩy)
                final shopNames = config.eligibleShops
                    .map((s) => s.shopName)
                    .toList();
                final shopNamesText = shopNames.join(', ');
                final discountPercentText = config.discountPercent.toStringAsFixed(0);
                
                return Text(
                  // 'Số tiền này sẽ tự động được áp dụng: $discountPercentText% trên tổng đơn hàng thuộc các Nhà bán: " $shopNamesText ". Xin trân trọng cảm ơn! 💝',
                   '🎁 Chúc mừng! Bạn đã nhận Voucher thưởng của Socdo – Dùng ngay trong 30 ngày Thanh tiến trình: "Hoàn tất đơn đầu tiên – Mở khóa ưu đãi tiếp theo"',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 24),
            // Nút đóng (từ config)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  config.dialogButtonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

