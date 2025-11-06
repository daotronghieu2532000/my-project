import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã sao chép: $text'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở liên kết: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở ứng dụng gọi điện'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    try {
      final uri = Uri.parse('mailto:$email');
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có ứng dụng email'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _openZalo() async {
    try {
      // Thử mở Zalo bằng app trước (nếu có)
      final zaloAppUrl = Uri.parse('zalo://chat?phone=0943051818');
      try {
        await launchUrl(zaloAppUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        // Nếu không mở được app, mở web
        final webUrl = Uri.parse('https://zalo.me/0943051818');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở Zalo'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Trung tâm trợ giúp',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade50,
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 56,
                    color: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chúng tôi luôn sẵn sàng hỗ trợ bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Liên hệ với chúng tôi qua các kênh dưới đây',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Contact Methods
            _buildContactCard(
              icon: Icons.alternate_email,
              title: 'Facebook',
              subtitle: 'Theo dõi và tương tác với chúng tôi',
              value: 'SocDo',
              onTap: () => _openUrl('https://www.facebook.com/SocDoPage'),
              onLongPress: () => _copyToClipboard('https://www.facebook.com/SocDoPage'),
              color: const Color(0xFF1877F2),
            ),
            
            const SizedBox(height: 12),
            
            _buildContactCard(
              icon: Icons.phone,
              title: 'Hotline',
              subtitle: 'Hỗ trợ nhanh 24/7',
              value: '094 305 18 18',
              onTap: () => _makePhoneCall('0943051818'),
              onLongPress: () => _copyToClipboard('0943051818'),
              color: Colors.grey.shade700,
            ),
            
            const SizedBox(height: 12),
            
            _buildContactCard(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'Gửi email cho chúng tôi',
              value: 'info@socdo.vn',
              onTap: () => _sendEmail('info@socdo.vn'),
              onLongPress: () => _copyToClipboard('info@socdo.vn'),
              color: Colors.grey.shade700,
            ),
            
            const SizedBox(height: 12),
            
            _buildContactCard(
              icon: Icons.message,
              title: 'Zalo',
              subtitle: 'Nhắn tin trực tiếp',
              value: '094 305 18 18',
              onTap: () => _openZalo(),
              onLongPress: () => _copyToClipboard('0943051818'),
              color: const Color(0xFF0068FF),
            ),
            
            const SizedBox(height: 32),
            
            // Additional Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thời gian hoạt động: Tất cả các ngày trong tuần',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nhấn giữ để sao chép',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Copy icon
              if (onLongPress != null)
                Icon(
                  Icons.copy,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              
              const SizedBox(width: 4),
              
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

