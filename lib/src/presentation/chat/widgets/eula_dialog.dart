import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EulaDialog extends StatefulWidget {
  final VoidCallback onAgree;

  const EulaDialog({
    super.key,
    required this.onAgree,
  });

  @override
  State<EulaDialog> createState() => _EulaDialogState();
}

class _EulaDialogState extends State<EulaDialog> {
  bool _isAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Điều khoản sử dụng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Điều khoản sử dụng nội dung do người dùng tạo ra',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Khi sử dụng dịch vụ của chúng tôi, bạn đồng ý tuân thủ các điều khoản sau:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTermItem(
                    '1. Nghiêm cấm đăng tải nội dung phản cảm, thô tục, khiêu dâm, bạo lực hoặc vi phạm pháp luật.',
                  ),
                  const SizedBox(height: 12),
                  _buildTermItem(
                    '2. Nghiêm cấm đăng tải thông tin cá nhân của người khác mà không có sự đồng ý.',
                  ),
                  const SizedBox(height: 12),
                  _buildTermItem(
                    '3. Nghiêm cấm spam, quảng cáo trái phép hoặc lừa đảo.',
                  ),
                  const SizedBox(height: 12),
                  _buildTermItem(
                    '4. Nghiêm cấm đăng tải nội dung vi phạm bản quyền hoặc quyền sở hữu trí tuệ.',
                  ),
                  const SizedBox(height: 12),
                  _buildTermItem(
                    '5. Chúng tôi có quyền xóa hoặc chặn nội dung vi phạm mà không cần thông báo trước.',
                  ),
                  const SizedBox(height: 12),
                  _buildTermItem(
                    '6. Người dùng có trách nhiệm báo cáo nội dung vi phạm thông qua tính năng báo cáo.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vi phạm điều khoản có thể dẫn đến việc khóa tài khoản vĩnh viễn.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Checkbox đồng ý
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isAgreed = !_isAgreed;
                      });
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _isAgreed ? Colors.grey[700]! : Colors.grey[400]!,
                              width: 2,
                            ),
                            color: _isAgreed ? Colors.grey[700]! : Colors.transparent,
                          ),
                          child: _isAgreed
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tôi đã đọc và đồng ý với các điều khoản sử dụng trên',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: _isAgreed ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAgreed ? _handleAgree : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAgreed ? Colors.grey[800] : Colors.grey[300],
                  foregroundColor: _isAgreed ? Colors.white : Colors.grey[600],
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Đồng ý',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAgree() async {
    // Lưu trạng thái đã đồng ý
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('eula_agreed', true);
    } catch (e) {
      // Ignore error
    }

    Navigator.pop(context);
    
    // Hiển thị thông báo thành công
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cảm ơn bạn đã đồng ý với điều khoản sử dụng!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Gọi callback để hiển thị list chat
    widget.onAgree();
  }
}

// Helper function để kiểm tra đã đồng ý chưa
Future<bool> hasAgreedToEula() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('eula_agreed') ?? false;
  } catch (e) {
    return false;
  }
}

// Helper function để hiển thị dialog từ dưới lên
void showEulaDialog(BuildContext context, VoidCallback onAgree) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false, // Không cho phép đóng bằng cách tap ra ngoài
    enableDrag: false, // Không cho phép kéo xuống
    builder: (context) => EulaDialog(onAgree: onAgree),
  );
}

