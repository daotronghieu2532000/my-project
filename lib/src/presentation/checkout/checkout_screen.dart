import 'dart:math';
import 'package:flutter/material.dart';
import 'widgets/delivery_info_section.dart';
import 'widgets/product_section.dart';
import 'widgets/order_summary_section.dart';
import 'widgets/voucher_section.dart';
import 'widgets/payment_methods_section.dart';
import 'widgets/payment_details_section.dart';
import 'widgets/terms_section.dart';
import 'widgets/bottom_order_bar.dart';
import '../../core/services/cart_service.dart' as cart_service;
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/shipping_quote_store.dart';
import '../../core/services/voucher_service.dart';
import '../../core/services/shipping_events.dart';
import '../../core/services/shipping_quote_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String selectedPaymentMethod = 'cod'; // Chỉ hỗ trợ COD
  bool _isProcessingOrder = false; // Flag để prevent double submission
  final cart_service.CartService _cartService = cart_service.CartService();
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final VoucherService _voucherService = VoucherService();
  final ShippingQuoteService _shippingQuoteService = ShippingQuoteService(); // ✅ Service chuyên nghiệp

  int get totalPrice => _cartService.items
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + (item.price * item.quantity));

  int get selectedCount => _cartService.items
      .where((item) => item.isSelected)
      .length;

  @override
  void initState() {
    super.initState();
    // Tự động áp dụng voucher tốt nhất khi mở checkout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoApplyBestVouchers();
    });
  }

  /// Tự động áp dụng voucher tốt nhất cho từng shop và voucher sàn
  Future<void> _autoApplyBestVouchers() async {
    final itemsByShop = _cartService.itemsByShop;
    final selectedItems = _cartService.items.where((item) => item.isSelected).toList();
    
    if (selectedItems.isEmpty) return;
    
    // Tính tổng tiền hàng
    final totalGoods = selectedItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
    
    // Lấy danh sách product ID trong giỏ hàng
    final cartProductIds = selectedItems.map((item) => item.id).toList();
    
    // Tự động áp dụng voucher tốt nhất cho từng shop
    for (final entry in itemsByShop.entries) {
      final shopId = entry.key;
      final items = entry.value;
      
      // Chỉ tính cho các item đã chọn
      final shopSelectedItems = items.where((item) => item.isSelected).toList();
      if (shopSelectedItems.isEmpty) continue;
      
      // Tính tổng tiền của shop
      final shopTotal = shopSelectedItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
      
      // Lấy danh sách product ID trong giỏ hàng của shop
      final shopProductIds = shopSelectedItems.map((item) => item.id).toList();
      
      // Tự động áp dụng voucher tốt nhất cho shop
      await _voucherService.autoApplyBestVoucher(shopId, shopTotal, shopProductIds);
    }
    
    // Tự động áp dụng voucher sàn tốt nhất (sau khi đã áp dụng voucher shop)
    await _voucherService.autoApplyBestPlatformVoucher(totalGoods, cartProductIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thanh toán',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const DeliveryInfoSection(),
          const SizedBox(height: 12),
          ProductSection(),
          const SizedBox(height: 12),
          const OrderSummarySection(),
          const SizedBox(height: 12),
          const VoucherSection(),
          const SizedBox(height: 12),
          PaymentMethodsSection(
            selectedPaymentMethod: selectedPaymentMethod,
            onPaymentMethodChanged: (value) {
              // Không cần thay đổi vì chỉ có COD
            },
          ),
          const SizedBox(height: 12),
          const PaymentDetailsSection(),
          const SizedBox(height: 12),
          const TermsSection(),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: BottomOrderBar(
        totalPrice: totalPrice,
        isProcessing: _isProcessingOrder,
        onOrder: () async {
          // Prevent double submission
          if (_isProcessingOrder) {
            return;
          }
          
          // Kiểm tra đăng nhập trước
          var user = await _auth.getCurrentUser();
          if (user == null) {
            // Nếu chưa đăng nhập, navigate đến login screen
            final loginResult = await Navigator.pushNamed(
              context,
              '/login',
            );
            
            // Nếu login thành công, chỉ quay lại trang checkout
            // Người dùng cần bấm nút đặt hàng lại sau khi đăng nhập
            if (loginResult == true) {
              // Trigger reload shipping fee sau khi đăng nhập
              ShippingEvents.refresh();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đăng nhập thành công! Vui lòng bấm nút đặt hàng lại.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            return;
          }
          
          // Nếu đã đăng nhập, tiếp tục xử lý đặt hàng
          _processOrder(user);
        },
      ),
    );
  }
  
  // Tách logic đặt hàng ra hàm riêng để tái sử dụng
  Future<void> _processOrder(user) async {
    // Set flag để prevent double submission
    if (!mounted) return;
    setState(() {
      _isProcessingOrder = true;
    });
    
    try {
      // Chuẩn bị payload theo API create_order
    final items = _cartService.items
        .where((i) => i.isSelected)
        .map((i) => {
              'id': i.id,
              'tieu_de': i.name,
              'anh_chinh': i.image,
              'quantity': i.quantity,
              'gia_moi': i.price,
              'thanh_tien': i.price * i.quantity,
              'shop': i.shopId,
            })
        .toList();
    // Lấy địa chỉ mặc định từ user_profile để điền
    final profile = await _api.getUserProfile(userId: user.userId);
    final addr = (profile?['addresses'] as List?)?.cast<Map<String, dynamic>?>().firstWhere(
            (a) => (a?['active'] == 1 || a?['active'] == '1'),
            orElse: () => null) ??
        (profile?['addresses'] as List?)?.cast<Map<String, dynamic>?>().firstOrNull;
    if (addr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm địa chỉ nhận hàng')),
      );
      return;
    }
    final ship = ShippingQuoteStore();
    final voucherService = VoucherService();
    
    // Tính voucher discount như trong PaymentDetailsSection
    final totalGoods = items.fold(0, (s, i) => s + (i['gia_moi'] as int) * (i['quantity'] as int));
    final shopDiscount = voucherService.calculateTotalDiscount(totalGoods);
    final platformDiscount = voucherService.calculatePlatformDiscountWithItems(
      totalGoods,
      items.map((e) => e['id'] as int).toList(),
    );
    // final voucherDiscount = (shopDiscount + platformDiscount).clamp(0, totalGoods);
    
    // Lấy mã coupon từ platform voucher
    final platformVoucher = voucherService.platformVoucher;
    final couponCode = platformVoucher?.code ?? '';
    
    // Tính ship support từ freeship logic
    // API shipping_quote.php trả về phí ship gốc và hỗ trợ ship riêng biệt
    int shipSupport = 0;
    int originalShipFee = ship.lastFee; // Phí ship gốc
    int finalShipFee = ship.lastFee; // Phí ship cuối (sẽ được tính lại)
    
    // Map để lưu shipping_provider cho từng shop
    Map<int, String> shopShippingProviders = {};
    
    // Gọi API shipping_quote để lấy thông tin freeship cho tất cả items
    try {
      // ✅ Thêm giá vào items để fallback tính chính xác hơn
      final shippingItems = items.map((item) => {
        'product_id': item['id'],
        'quantity': item['quantity'],
        'price': item['gia_moi'], // ✅ Thêm giá để fallback tính chính xác
      }).toList();
      
      // ✅ Sử dụng ShippingQuoteService với retry, timeout, fallback, và cache
      final shippingQuote = await _shippingQuoteService.getShippingQuote(
        userId: user.userId,
        items: shippingItems.cast<Map<String, dynamic>>(),
        useCache: true,
        enableFallback: true, // ✅ Cho phép fallback nếu API fail
      );
      
      if (shippingQuote != null && shippingQuote['success'] == true) {
        // Sử dụng phí ship gốc và hỗ trợ ship từ API response
        final bestOverall = shippingQuote['data']?['best'] as Map<String, dynamic>?;
        if (bestOverall != null) {
          originalShipFee = bestOverall['fee'] as int? ?? ship.lastFee; // Phí ship gốc từ API
          shipSupport = bestOverall['ship_support'] as int? ?? 0; // Hỗ trợ ship từ API
          finalShipFee = max(0, originalShipFee - shipSupport); // Phí ship cuối
        } else {
          // Fallback: sử dụng logic cũ nếu không có best_overall
          final debug = shippingQuote['data']?['debug'];
          if (debug != null) {
            final freeshipExcluded = debug['freeship_excluded'] as Map<String, dynamic>?;
            if (freeshipExcluded != null) {
              // Lấy ship support từ API response
              final shipFixedSupport = freeshipExcluded['ship_fixed_support'] as int? ?? 0;
              final shipPercentSupport = freeshipExcluded['ship_percent_support'] as double? ?? 0.0;
              
              // Tính tổng ship support
              shipSupport = shipFixedSupport;
              if (shipPercentSupport > 0) {
                // Lấy fee_before_support từ debug để tính percent support chính xác
                final finalFeeCalculation = debug['final_fee_calculation'] as Map<String, dynamic>?;
                int percentSupportAmount = 0;
                if (finalFeeCalculation != null) {
                  final feeBeforeSupport = finalFeeCalculation['fee_before_support'] as int? ?? 0;
                  percentSupportAmount = (feeBeforeSupport * shipPercentSupport / 100).round();
                } else {
                  // Fallback: sử dụng ship.lastFee nếu không có debug info
                  percentSupportAmount = (ship.lastFee * shipPercentSupport / 100).round();
                }
                shipSupport += percentSupportAmount;
              }
              
              // Tính final ship fee
              finalShipFee = max(0, ship.lastFee - shipSupport);
            }
          }
        }
        
        // ✅ Lấy warehouse_shipping_details để map provider cho từng shop
        // Ưu tiên lấy từ best['warehouse_details'], sau đó từ warehouse_shipping
        List<dynamic>? warehouseDetails;
        
        // Thử lấy từ best['warehouse_details'] trước (chính xác hơn)
        final best = shippingQuote['best'] as Map<String, dynamic>?;
        if (best != null) {
          warehouseDetails = best['warehouse_details'] as List<dynamic>?;
        }
        
        // Nếu không có, thử lấy từ warehouse_shipping
        if (warehouseDetails == null || warehouseDetails.isEmpty) {
          final warehouseShipping = shippingQuote['data']?['warehouse_shipping'] as Map<String, dynamic>?;
          if (warehouseShipping != null) {
            warehouseDetails = warehouseShipping['warehouse_details'] as List<dynamic>?;
          }
        }
        
        // Nếu vẫn không có, thử lấy từ quotes[0]
        if (warehouseDetails == null || warehouseDetails.isEmpty) {
          final quotes = shippingQuote['quotes'] as List<dynamic>?;
          if (quotes != null && quotes.isNotEmpty) {
            final firstQuote = quotes[0] as Map<String, dynamic>?;
            if (firstQuote != null) {
              warehouseDetails = firstQuote['warehouse_details'] as List<dynamic>?;
            }
          }
        }
        
        // Map provider cho từng shop
        if (warehouseDetails != null && warehouseDetails.isNotEmpty) {
          print('🔍 [Checkout] Found ${warehouseDetails.length} warehouse details');
          for (final detail in warehouseDetails) {
            final detailMap = detail as Map<String, dynamic>?;
            if (detailMap != null) {
              final shopId = int.tryParse('${detailMap['shop_id'] ?? 0}') ?? 0;
              final provider = detailMap['provider']?.toString() ?? '';
              if (shopId > 0 && provider.isNotEmpty) {
                shopShippingProviders[shopId] = provider;
                print('🔍 [Checkout] Mapped shop $shopId -> provider: $provider');
              }
            }
          }
          print('🔍 [Checkout] Total shops mapped: ${shopShippingProviders.length}');
        } else {
          print('⚠️ [Checkout] No warehouse_details found in response');
        }
      }
    } catch (e) {
      // Nếu có lỗi khi gọi shipping_quote, sử dụng ship fee gốc
      print('Error getting shipping quote: $e');
    }
    
    // Đảm bảo ship support không vượt quá ship fee gốc
    shipSupport = shipSupport.clamp(0, ship.lastFee);
    finalShipFee = finalShipFee.clamp(0, ship.lastFee);
    
    // ✅ Thêm shipping_provider vào mỗi item dựa trên shop_id
    final itemsWithProvider = items.map((item) {
      final shopId = item['shop'] as int? ?? 0;
      final provider = shopShippingProviders[shopId] ?? ship.provider ?? '';
      print('🔍 [Checkout] Item ${item['id']} (shop $shopId) -> provider: $provider');
      return {
        ...item,
        'shipping_provider': provider, // ✅ Thêm shipping_provider vào mỗi item
      };
    }).toList();
    
    // ✅ Log tổng hợp để debug
    print('🔍 [Checkout] Items with provider:');
    for (final item in itemsWithProvider) {
      print('  - Product ${item['id']}: shop=${item['shop']}, provider=${item['shipping_provider']}');
    }
    
    // final grandTotal = totalGoods + finalShipFee - shopDiscount - platformDiscount;
    
    final res = await _api.createOrder(
      userId: user.userId,
      hoTen: addr['ho_ten']?.toString() ?? user.name,
      dienThoai: addr['dien_thoai']?.toString() ?? user.mobile,
      email: user.email,
      diaChi: addr['dia_chi']?.toString() ?? '',
      tinh: int.tryParse('${addr['tinh'] ?? 0}') ?? 0,
      huyen: int.tryParse('${addr['huyen'] ?? 0}') ?? 0,
      xa: int.tryParse('${addr['xa'] ?? 0}'),
      sanpham: itemsWithProvider.cast<Map<String, dynamic>>(), // ✅ Sử dụng itemsWithProvider
      thanhtoan: selectedPaymentMethod.toUpperCase(),
      ghiChu: '',
      coupon: couponCode,
      giam: shopDiscount,           // ✅ Shop discount
      voucherTmdt: platformDiscount, // ✅ Platform discount
      phiShip: originalShipFee,     // ✅ Phí ship gốc (giống website)
      shipSupport: shipSupport,      // ✅ Hỗ trợ ship từ freeship
      shippingProvider: ship.provider, // ✅ Vẫn giữ để tương thích, nhưng sẽ bị override bởi provider trong items
    );
    
    if (res?['success'] == true) {
      final data = res?['data'];
      final maDon = data?['ma_don'] ?? '';
      final orders = data?['orders'] as List<dynamic>?;
      final totalOrders = orders?.length ?? (maDon.isNotEmpty ? 1 : 0);
      
      // Clear cart sau khi đặt hàng thành công
      _cartService.clearCart();
      
      // Tạo message phù hợp
      String message;
      if (totalOrders > 1) {
        message = 'Đặt hàng thành công: $totalOrders đơn hàng';
      } else {
        message = 'Đặt hàng thành công: ${maDon.isNotEmpty ? maDon : ''}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white), // chữ trắng cho dễ đọc
          ),
          backgroundColor: Colors.green, // ✅ nền xanh lá cây
          behavior: SnackBarBehavior.floating, // tùy chọn: nổi lên đẹp hơn
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // bo góc nhẹ
          ),
        ),
      );

      if (!mounted) return;
      // Dùng pushNamedAndRemoveUntil để không thể quay lại checkout và cart
      // Xóa tất cả route trước đó (trừ route đầu tiên - home)
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/order/success',
        (route) => route.isFirst, // Chỉ giữ lại route đầu tiên (home)
        arguments: {
          'ma_don': maDon,
          'orders': orders,
          'summary': data?['summary'],
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đặt hàng thất bại: ${res?['message'] ?? 'Lỗi không xác định'}')),
      );
    }
    } finally {
      // Reset flag sau khi xử lý xong (dù thành công hay thất bại)
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
  }
}

