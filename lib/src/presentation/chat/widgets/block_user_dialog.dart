import 'package:flutter/material.dart';

class BlockUserDialog extends StatelessWidget {
  final String userName;
  final VoidCallback onConfirm;

  const BlockUserDialog({
    super.key,
    required this.userName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Chặn người dùng',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn có chắc chắn muốn chặn $userName?',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Khi chặn, bạn sẽ không nhận được tin nhắn từ người này và nội dung của họ sẽ bị ẩn ngay lập tức.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Hủy',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
          ),
          child: const Text('Chặn'),
        ),
      ],
    );
  }
}

// Helper function để hiển thị dialog chặn
void showBlockUserDialog(
  BuildContext context,
  String userName,
  VoidCallback onConfirm,
) {
  showDialog(
    context: context,
    builder: (context) => BlockUserDialog(
      userName: userName,
      onConfirm: onConfirm,
    ),
  );
}

