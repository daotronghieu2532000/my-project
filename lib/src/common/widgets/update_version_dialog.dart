import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'dart:math';

class UpdateVersionDialog extends StatelessWidget {
  final String updateUrl;

  const UpdateVersionDialog({
    super.key,
    required this.updateUrl,
  });

  // Danh sách các mẫu giao diện (4 mẫu)
  static final List<_UpdateTemplate> _templates = [
    _UpdateTemplate(
      title: 'Phiên bản mới đã có!',
      content: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15.5, height: 1.5, color: Colors.grey),
          children: [
            const TextSpan(text: 'Để đảm bảo tính bảo mật và quyền lợi của bạn, '),
            const TextSpan(
              text: 'Sóc Đỏ ',
              style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: 'yêu cầu nâng cấp lên phiên bản mới nhất.'),
          ],
        ),
      ),
      subContent: 'Mong bạn thông cảm vì sự bất tiện!',
      icon: Icons.cloud_download_rounded,
      accentColor: const Color(0xFF3478F6),
      headerGradientColors: [const Color(0xFF3478F6).withOpacity(0.18), const Color(0xFF3478F6).withOpacity(0.05)],
    ),
    _UpdateTemplate(
      title: 'Cập nhật quan trọng',
      content: const Text(
        'Chúng tôi vừa bổ sung nhiều tính năng mới và vá lỗi bảo mật. Hãy cập nhật ngay để trải nghiệm mượt mà hơn!',
        style: TextStyle(fontSize: 15.5, height: 1.5, color: Colors.grey),
      ),
      subContent: 'Cảm ơn bạn luôn đồng hành cùng ',
      icon: Icons.new_releases_rounded,
      accentColor: const Color(0xFF6200EE),
      headerGradientColors: [const Color(0xFF6200EE).withOpacity(0.2), const Color(0xFF6200EE).withOpacity(0.06)],
    ),
    _UpdateTemplate(
      title: 'Sẵn sàng nâng cấp',
      content: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15.5, height: 1.5, color: Colors.grey),
          children: [
            const TextSpan(text: 'Phiên bản mới của '),
            const TextSpan(
              text: 'Sóc Đỏ ',
              style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: 'đã được cải tiến để mang lại trải nghiệm tốt nhất cho bạn.'),
          ],
        ),
      ),
      subContent: 'Trân trọng cảm ơn sự ủng hộ của bạn ',
      icon: Icons.update_rounded,
      accentColor: const Color(0xFF00C853),
      headerGradientColors: [const Color(0xFF00C853).withOpacity(0.18), const Color(0xFF00C853).withOpacity(0.05)],
    ),
    _UpdateTemplate(
      title: 'Thông báo cập nhật',
      content: const Text(
        'Để tiếp tục sử dụng ứng dụng một cách an toàn và đầy đủ tính năng, vui lòng cập nhật phiên bản mới nhất ngay bây giờ.',
        style: TextStyle(fontSize: 15.5, height: 1.5, color: Colors.grey),
      ),
      subContent: 'Chúng tôi luôn nỗ lực vì bạn ',
      icon: Icons.security_rounded,
      accentColor: const Color(0xFFFF5722),
      headerGradientColors: [const Color(0xFFFF5722).withOpacity(0.18), const Color(0xFFFF5722).withOpacity(0.05)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final random = Random();
    final template = _templates[random.nextInt(_templates.length)];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF121212).withOpacity(0.92) : Colors.white.withOpacity(0.95);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F0F0F);
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[700]!;

    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: const ColorFilter.mode(Colors.black26, BlendMode.darken),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header với gradient thay đổi theo mẫu
                  Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: template.headerGradientColors,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          template.icon,
                          size: 64,
                          color: template.accentColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          template.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nội dung chính
                        template.content,

                        const SizedBox(height: 16),

                        // Dòng cảm ơn + icon tim
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              template.subContent,
                              style: TextStyle(
                                fontSize: 15.5,
                                height: 1.5,
                                color: textSecondary,
                              ),
                            ),
                            Icon(
                              Icons.favorite_rounded,
                              size: 18,
                              color: const Color(0xFFE53935),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Nút cập nhật dùng màu của template
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                final uri = Uri.parse(updateUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else {
                                  final storeUrl = Platform.isIOS
                                      ? 'https://apps.apple.com/vn/app/sóc-đỏ/id6756269687'
                                      : 'https://play.google.com/store/apps/details?id=com.socdo.mobile';
                                  await launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication);
                                }
                              } catch (_) {}
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: template.accentColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text(
                              'Cập nhật ngay',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.2),
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
        ),
      ),
    );
  }
}

// Class chứa thông tin mỗi mẫu
class _UpdateTemplate {
  final String title;
  final Widget content;
  final String subContent;
  final IconData icon;
  final Color accentColor;
  final List<Color> headerGradientColors;

  _UpdateTemplate({
    required this.title,
    required this.content,
    required this.subContent,
    required this.icon,
    required this.accentColor,
    required this.headerGradientColors,
  });
}