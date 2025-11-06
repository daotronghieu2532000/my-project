import 'package:flutter/material.dart';

class TermsSection extends StatelessWidget {
  const TermsSection({
    super.key,
  });

  void _showTermsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            minHeight: 400,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header - Cố định
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Điều khoản dịch vụ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              
              // Content - Scroll được
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        '1. Giới thiệu',
                        'Chào mừng bạn đến với Sàn Thương Mại Điện Tử Socdo.vn. Trước khi sử dụng dịch vụ, vui lòng đọc kỹ các điều khoản dịch vụ để hiểu rõ quyền lợi và nghĩa vụ hợp pháp của mình.',
                      ),
                      _buildSection(
                        '2. Quyền riêng tư',
                        'Sóc Đỏ coi trọng việc bảo mật thông tin của bạn. Chúng tôi cam kết thu thập, sử dụng, công bố và xử lý thông tin cá nhân của bạn một cách an toàn và minh bạch.',
                      ),
                      _buildSection(
                        '3. Tài khoản và bảo mật',
                        '• Bạn có trách nhiệm bảo mật thông tin đăng nhập\n• Thông báo ngay khi phát hiện sử dụng trái phép\n• Chịu trách nhiệm với mọi hoạt động dưới tài khoản của mình',
                      ),
                      _buildSection(
                        '4. Đặt hàng và thanh toán',
                        '• Hỗ trợ thanh toán COD và chuyển khoản ngân hàng\n• Chỉ có thể thay đổi phương thức thanh toán trước khi thực hiện\n• Sóc Đỏ không chịu trách nhiệm với giao dịch bên ngoài sàn',
                      ),
                      _buildSection(
                        '5. Vận chuyển',
                        '• Người bán chịu trách nhiệm vận chuyển hàng hóa\n• Sóc Đỏ không chịu trách nhiệm với tổn thất trong quá trình vận chuyển\n• Hỗ trợ giải quyết tranh chấp khi có sự cố',
                      ),
                      _buildSection(
                        '6. Hủy đơn hàng, trả hàng và hoàn tiền',
                        '• Có thể hủy đơn hàng trong giai đoạn "Chờ Xác Nhận"\n• Được quyền trả hàng và hoàn tiền theo chính sách\n• Hoàn tiền bằng phương thức thanh toán ban đầu',
                      ),
                      _buildSection(
                        '7. Trách nhiệm của người bán',
                        '• Quản lý và đảm bảo độ chính xác thông tin sản phẩm\n• Cung cấp hóa đơn theo quy định pháp luật\n• Chịu trách nhiệm về thuế và các loại phí',
                      ),
                      _buildSection(
                        '8. Tranh chấp',
                        '• Ưu tiên giải quyết bằng thảo luận hai bên\n• Có thể khiếu nại lên cơ quan có thẩm quyền\n• Sóc Đỏ hỗ trợ giải quyết tranh chấp theo chính sách',
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Footer note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE9ECEF),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF6C757D),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Điều khoản này có hiệu lực từ ngày 06/06/2025 và có thể được cập nhật theo quy định pháp luật.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6C757D),
                                  fontWeight: FontWeight.w500,
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
            ],
          ),
        );
      },
    );
  }

  void _showPolicyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            minHeight: 400,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header - Cố định
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.security_outlined,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Chính sách bảo mật',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              
              // Content - Scroll được
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        '1. Giới thiệu',
                        'Sóc Đỏ nghiêm túc thực hiện trách nhiệm bảo mật thông tin theo quy định pháp luật Việt Nam và cam kết tôn trọng quyền riêng tư của người dùng.',
                      ),
                      _buildSection(
                        '2. Thu thập dữ liệu cá nhân',
                        'Chúng tôi thu thập dữ liệu khi:\n• Bạn đăng ký và sử dụng dịch vụ\n• Thực hiện giao dịch trên nền tảng\n• Tương tác với chúng tôi qua các kênh liên lạc\n• Sử dụng các tính năng của ứng dụng',
                      ),
                      _buildSection(
                        '3. Loại dữ liệu thu thập',
                        '• Thông tin cá nhân: họ tên, email, số điện thoại\n• Thông tin thanh toán và địa chỉ giao hàng\n• Thông tin thiết bị và vị trí\n• Dữ liệu sử dụng và giao dịch\n• Thông tin từ mạng xã hội (nếu liên kết)',
                      ),
                      _buildSection(
                        '4. Mục đích sử dụng',
                        '• Cung cấp và quản lý dịch vụ\n• Xử lý giao dịch và đơn hàng\n• Hỗ trợ khách hàng\n• Marketing và quảng cáo\n• Tuân thủ pháp luật và bảo vệ quyền lợi',
                      ),
                      _buildSection(
                        '5. Bảo vệ thông tin',
                        '• Sử dụng các biện pháp bảo mật tiên tiến\n• Mã hóa dữ liệu cá nhân\n• Giới hạn quyền truy cập\n• Tuân thủ quy định pháp luật về bảo vệ dữ liệu',
                      ),
                      _buildSection(
                        '6. Chia sẻ thông tin',
                        '• Với nhà cung cấp dịch vụ và đối tác\n• Khi có yêu cầu từ cơ quan nhà nước\n• Để bảo vệ quyền lợi hợp pháp\n• Với sự đồng ý của bạn',
                      ),
                      _buildSection(
                        '7. Quyền của bạn',
                        '• Truy cập và chỉnh sửa thông tin cá nhân\n• Rút lại sự đồng ý\n• Yêu cầu xóa dữ liệu\n• Phản đối việc xử lý dữ liệu\n• Yêu cầu cung cấp dữ liệu',
                      ),
                      _buildSection(
                        '8. Liên hệ',
                        'Nếu có thắc mắc về chính sách bảo mật:\n• Email: info@socdo.vn\n• Hotline: 0943.051.818\n• Địa chỉ: Số 22 Liền kề 25, HUD Vân Canh, Hoài Đức, Hà Nội',
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Footer note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE9ECEF),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.update,
                              color: Color(0xFF6C757D),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Chính sách này được cập nhật lần cuối vào ngày 06/06/2025.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6C757D),
                                  fontWeight: FontWeight.w500,
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 14),
                children: [
                  const TextSpan(text: 'Nhấn "Đặt hàng" đồng nghĩa bạn đồng ý với '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => _showTermsDialog(context),
                      child: const Text(
                        'điều khoản',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' và '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => _showPolicyDialog(context),
                      child: const Text(
                        'chính sách',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' của chúng tôi.'),
                ],
              ),
      ),
    );
  }
}
