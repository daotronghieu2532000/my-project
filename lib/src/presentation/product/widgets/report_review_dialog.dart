import 'package:flutter/material.dart';

class ReportReviewDialog extends StatefulWidget {
  const ReportReviewDialog({super.key});

  @override
  State<ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends State<ReportReviewDialog> {
  final Set<int> _selectedReasons = {};

  final List<Map<String, String>> _reportReasons = [
    {
      'id': '1',
      'title': 'Đánh giá thô tục phản cảm',
    },
    {
      'id': '2',
      'title': 'Chứa hình ảnh phản cảm, khỏa thân, khiêu dâm',
    },
    {
      'id': '3',
      'title': 'Đánh giá trùng lặp (thông tin rác)',
    },
    {
      'id': '4',
      'title': 'Chứa thông tin cá nhân',
    },
    {
      'id': '5',
      'title': 'Quảng cáo trái phép',
    },
    {
      'id': '6',
      'title': 'Đánh giá không chính xác / gây hiểu lầm (ví dụ như: đánh giá và sản phẩm không khớp, ...)',
    },
    {
      'id': '7',
      'title': 'Vi phạm khác',
    },
  ];

  void _toggleReason(int index) {
    setState(() {
      if (_selectedReasons.contains(index)) {
        _selectedReasons.remove(index);
      } else {
        _selectedReasons.add(index);
      }
    });
  }

  void _submitReport() {
    if (_selectedReasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một lý do báo cáo'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.pop(context);
    
    // Hiển thị thông báo thành công
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Báo cáo đã được gửi thành công. Cảm ơn bạn đã phản hồi!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
                  'Báo cáo đánh giá này',
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
                    'Vui lòng chọn lý do báo cáo',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_reportReasons.length, (index) {
                    final reason = _reportReasons[index];
                    final isSelected = _selectedReasons.contains(index);
                    
                    return InkWell(
                      onTap: () => _toggleReason(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.grey[100] : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[200]!,
                              width: index < _reportReasons.length - 1 ? 1 : 0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.grey[700]!
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                                color: isSelected
                                    ? Colors.grey[700]!
                                    : Colors.transparent,
                              ),
                              child: isSelected
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
                                reason['title']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReasons.isNotEmpty ? _submitReport : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedReasons.isNotEmpty
                      ? Colors.grey[800]
                      : Colors.grey[300],
                  foregroundColor: _selectedReasons.isNotEmpty
                      ? Colors.white
                      : Colors.grey[600],
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Gửi',
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
}

// Helper function để hiển thị dialog từ dưới lên
void showReportReviewDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const ReportReviewDialog(),
  );
}

