import 'package:flutter/material.dart';
import '../cart/cart_screen.dart';
import '../orders/orders_screen.dart'; // Giả định có OrdersScreen

class OrderSuccessScreen extends StatefulWidget {
  final String maDon;
  final List<dynamic>? orders;
  final Map<String, dynamic>? summary;
  
  const OrderSuccessScreen({
    super.key, 
    required this.maDon,
    this.orders,
    this.summary,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Hàm tiện ích để định dạng tiền tệ (giả định)
  String _formatCurrency(int amount) {
    // Thay thế bằng hàm format tiền tệ thực tế của bạn
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}₫';
  }

  // Widget hiển thị thông tin chi tiết đơn hàng (Mã đơn, Tổng tiền)
  Widget _buildSummaryCard() {
    final totalAmount = widget.summary?['tongtien'] as int? ?? 0;
    final maDon = widget.maDon;
    final isMultiOrder = widget.orders != null && widget.orders!.length > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề
          const Text(
            'Chi tiết đơn hàng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
          
          // Mã đơn hàng
          if (isMultiOrder)
            _buildMultiOrderCodes('Mã đơn hàng', widget.orders!)
          else
            _buildInfoRow(
              'Mã đơn hàng',
              maDon,
              isHighlight: true,
            ),
         
            const SizedBox(height: 8),
            _buildInfoRow(
              'Số lượng đơn',
              '${widget.orders!.length} đơn hàng',
              isHighlight: false,
            ),
          
          // const SizedBox(height: 16),
          
          // // Tổng tiền
          // _buildInfoRow(
          //   'Tổng thanh toán',
          //   _formatCurrency(totalAmount),
          //   isHighlight: true,
          //   valueColor: const Color(0xFFEF4444),
          //   valueWeight: FontWeight.w800,
          // ),
        ],
      ),
    );
  }

  // Widget hiển thị một dòng thông tin
  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, Color? valueColor, FontWeight? valueWeight}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isHighlight ? const Color(0xFF1A1A1A) : const Color(0xFF64748B),
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? const Color(0xFF1A1A1A),
              fontWeight: valueWeight ?? FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // Widget hiển thị danh sách mã đơn hàng (nhiều đơn)
  Widget _buildMultiOrderCodes(String label, List<dynamic> orders) {
    // Extract order codes from orders list
    final orderCodes = <String>[];
    for (var order in orders) {
      if (order is Map<String, dynamic>) {
        final maDon = order['ma_don']?.toString() ?? '';
        if (maDon.isNotEmpty) {
          orderCodes.add(maDon);
        }
      }
    }
    
    // If no order codes found in orders list, try to split maDon string
    if (orderCodes.isEmpty && widget.maDon.isNotEmpty) {
      // Try splitting by common separators (comma, space, underscore)
      final parts = widget.maDon.split(RegExp(r'[,;\s_]+')).where((s) => s.isNotEmpty).toList();
      orderCodes.addAll(parts);
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: orderCodes.map((code) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  // Widget hiển thị thông báo bổ sung
  Widget _buildAdditionalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Màu xanh nhạt
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFBFDBFE),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: const Color(0xFF2563EB),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Đơn hàng của bạn đã được tiếp nhận. Chúng tôi sẽ gửi thông báo cập nhật trạng thái đơn hàng sớm nhất.',
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF1E40AF),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Nền trắng xám nhẹ
      appBar: AppBar(
        title: const Text(
          'Đặt hàng thành công',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            // Đóng màn hình và về trang chủ (hoặc màn hình trước đó)
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            icon: Icon(
              Icons.shopping_cart_outlined,
              color: colorScheme.primary,
              size: 24,
            ),
            tooltip: 'Giỏ hàng',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    children: [
                      // 1. Success Icon & Message
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF10B981), // Màu xanh lá cây hiện đại
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Đặt hàng thành công!',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cảm ơn bạn đã tin tưởng và mua sắm tại Sóc Đỏ.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 32),
                    
                      // 2. Summary Card (Chi tiết đơn hàng)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildSummaryCard(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 3. Additional Info
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildAdditionalInfo(),
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            
            // 4. Action Buttons (Sticky Footer)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Nút 1: Xem đơn hàng
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Giả định OrdersScreen có thể nhận mã đơn hàng
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OrdersScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(color: colorScheme.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Xem đơn hàng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nút 2: Tiếp tục mua sắm (Về trang chủ)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Tiếp tục mua sắm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
