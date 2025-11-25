import 'dart:async';
import 'shipping_quote_service.dart';

/// Event bus đơn giản để thông báo các phần trên checkout
/// cần tính lại phí ship khi địa chỉ giao hàng thay đổi.
class ShippingEvents {
  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  static Stream<void> get stream => _controller.stream;

  static void refresh() {
    try {
      final shippingQuoteService = ShippingQuoteService();
      shippingQuoteService.clearCache();

    } catch (e) {
      print('❌ [ShippingEvents.refresh] Lỗi khi clear cache: $e');
    }
    if (!_controller.isClosed) _controller.add(null);
  }

  static Future<void> dispose() async {
    await _controller.close();
  }
}


