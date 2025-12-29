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
            
            // Nội dung (từ config) - Format đẹp hơn với RichText
            Builder(
              builder: (context) {
                final message = config.dialogMessage;
                // Parse text để format đẹp hơn: tách theo dấu " – " và "Thanh tiến trình:"
                final parts = message.split(' – ');
                final firstPart = parts.isNotEmpty ? parts[0] : message;
                final restOfText = parts.length > 1 ? parts.sublist(1).join(' – ') : '';
                
                // Tìm phần tiến trình
                String middleText = '';
                String progressText = '';
                
                if (restOfText.contains('Thanh tiến trình:')) {
                  final progressIndex = restOfText.indexOf('Thanh tiến trình:');
                  middleText = restOfText.substring(0, progressIndex).trim();
                  progressText = restOfText.substring(progressIndex + 'Thanh tiến trình:'.length).trim();
                } else if (restOfText.contains('Tiến trình:')) {
                  final progressIndex = restOfText.indexOf('Tiến trình:');
                  middleText = restOfText.substring(0, progressIndex).trim();
                  progressText = restOfText.substring(progressIndex + 'Tiến trình:'.length).trim();
                } else {
                  middleText = restOfText;
                }
                
                return RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(
                        text: '$firstPart\n',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (middleText.isNotEmpty) ...[
                        TextSpan(
                          text: '$middleText\n\n',
                        ),
                      ],
                      if (progressText.isNotEmpty) ...[
                        const TextSpan(
                          text: 'Tiến trình: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        TextSpan(
                          text: progressText,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            
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

