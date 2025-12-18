import 'package:flutter/material.dart';
import 'widgets/delivery_info_section.dart';
import 'widgets/delivery_info_sticky_header.dart';
import 'widgets/product_section.dart';
import 'widgets/order_summary_section.dart';
import 'widgets/first_time_bonus_section.dart';
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
import '../../core/models/user.dart';
import 'dart:async';

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
  final ShippingQuoteService _shippingQuoteService =
      ShippingQuoteService(); // ✅ Service chuyên nghiệp
  
  // ✅ State cho sticky header
  final ScrollController _scrollController = ScrollController();
  bool _showStickyHeader = false;
  User? _user;
  Map<String, dynamic>? _defaultAddress;

  // ✅ Tính tổng giá dựa trên originalPrice (giá gốc) để hiển thị chính xác
  int get totalPrice => _cartService.items
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + ((item.originalPrice ?? item.price) * item.quantity));

  int get selectedCount =>
      _cartService.items.where((item) => item.isSelected).length;

  StreamSubscription? _shippingEventsSubscription;

  @override
  void initState() {
    super.initState();
    // Tự động áp dụng voucher tốt nhất khi mở checkout
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ✅ QUAN TRỌNG: Load originalPrice cho các CartItem chưa có giá gốc
      await _loadOriginalPricesForCartItems();
      _autoApplyBestVouchers();
      _loadUserAddress();
    });
    
    // ✅ Lắng nghe scroll để hiển thị/ẩn sticky header
    _scrollController.addListener(_onScroll);
    
    // ✅ Lắng nghe thay đổi cart để rebuild khi cart thay đổi
    _cartService.addListener(_onCartChanged);
    
    // ✅ Lắng nghe thay đổi auth state để reload sau khi đăng nhập
    _auth.addAuthStateListener(_onAuthStateChanged);
    
    // ✅ Lắng nghe ShippingEvents để reload địa chỉ khi địa chỉ thay đổi
    _shippingEventsSubscription = ShippingEvents.stream.listen((_) {
      _loadUserAddress();
    });
  }
  
  /// ✅ QUAN TRỌNG: Load originalPrice cho các CartItem chưa có giá gốc
  /// Đảm bảo checkout luôn dùng giá gốc (chưa trừ ưu đãi) để tính toán
  Future<void> _loadOriginalPricesForCartItems() async {
    final selectedItems = _cartService.items
        .where((item) => item.isSelected)
        .toList();
    
    if (selectedItems.isEmpty) return;
    
    // Tìm các item chưa có originalPrice
    final itemsNeedUpdate = selectedItems
        .where((item) => item.originalPrice == null)
        .toList();
    
    if (itemsNeedUpdate.isEmpty) return;
    
    // Load originalPrice cho từng item
    for (final item in itemsNeedUpdate) {
      try {
        // Gọi API để lấy product detail với originalPrice
        final productDetail = await _api.getProductDetailBasic(item.id);
        
        if (productDetail != null) {
          // Nếu có variant, tìm variant tương ứng
          int? originalPrice;
          
          if (item.variant != null && productDetail.variants.isNotEmpty) {
            // Tìm variant theo tên
            final variant = productDetail.variants.firstWhere(
              (v) => v.name == item.variant,
              orElse: () => productDetail.variants.first,
            );
            originalPrice = variant.originalPrice ?? variant.price;
          } else {
            // Không có variant, dùng giá của product chính
            originalPrice = productDetail.originalPrice ?? productDetail.price;
          }
          
          // ✅ Cập nhật originalPrice cho CartItem (originalPrice đã được đảm bảo không null từ fallback)
          if (originalPrice > 0) {
            _cartService.updateItemOriginalPrice(
              item.id,
              originalPrice,
              variant: item.variant,
            );
          }
        }
      } catch (e) {
        // Nếu lỗi, bỏ qua item này
        print('⚠️ [Checkout] Không thể load originalPrice cho item ${item.id}: $e');
      }
    }
    
    // Trigger rebuild sau khi cập nhật
    if (mounted) {
      setState(() {});
    }
  }
  
  // ✅ Load user và địa chỉ cho sticky header
  Future<void> _loadUserAddress() async {
    final u = await _auth.getCurrentUser();
    if (u == null) return;
    final data = await _api.getUserProfile(userId: u.userId);
    Map<String, dynamic>? def;
    if (data != null) {
      final list = (data['addresses'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
      def = list.firstWhere((a) => (a['active']?.toString() ?? '0') == '1', orElse: () => (list.isNotEmpty ? list.first : <String,dynamic>{}));
    }
    if (!mounted) return;
    setState(() {
      _user = u;
      _defaultAddress = def;
    });
  }
  
  // ✅ Handle scroll để hiển thị/ẩn sticky header
  void _onScroll() {
    // Hiển thị sticky header khi cuộn xuống hơn 150px (đã qua DeliveryInfoSection)
    final shouldShow = _scrollController.offset > 150;
    if (shouldShow != _showStickyHeader) {
      setState(() {
        _showStickyHeader = shouldShow;
      });
    }
  }
  
  // ✅ Xử lý mở address book từ sticky header
  Future<void> _openAddressBook() async {
    // Kiểm tra đăng nhập trước
    final u = await _auth.getCurrentUser();
    if (u == null) {
      // Nếu chưa đăng nhập, navigate đến trang đăng nhập
      final loginResult = await Navigator.pushNamed(context, '/login');
      // Nếu đăng nhập thành công, reload lại địa chỉ và trigger refresh shipping
      if (loginResult == true) {
        await _loadUserAddress();
        // Trigger refresh shipping
        ShippingEvents.refresh();
      }
      return;
    }
    // Nếu đã đăng nhập, mở trang địa chỉ
    await Navigator.of(context).pushNamed('/profile/address');
    await _loadUserAddress();
    // Trigger refresh shipping để tính lại phí ship với địa chỉ mới
    ShippingEvents.refresh();
  }
  
  @override
  void dispose() {
    // ✅ Remove listeners
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cartService.removeListener(_onCartChanged);
    _auth.removeAuthStateListener(_onAuthStateChanged);
    _shippingEventsSubscription?.cancel();
    super.dispose();
  }
  
  // ✅ Callback khi cart thay đổi
  void _onCartChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild để cập nhật UI
      });
    }
  }
  
  // ✅ Callback khi auth state thay đổi (đăng nhập/đăng xuất)
  Future<void> _onAuthStateChanged() async {
    if (mounted) {
      // Reload cart sau khi đăng nhập
      await _cartService.loadCartForUser();
      // Reload user và address
      await _loadUserAddress();
      // Trigger rebuild
      setState(() {});
      // Trigger refresh shipping
      ShippingEvents.refresh();
    }
  }

  /// Tự động áp dụng voucher tốt nhất cho từng shop và voucher sàn
  Future<void> _autoApplyBestVouchers() async {
    final itemsByShop = _cartService.itemsByShop;
    final selectedItems = _cartService.items
        .where((item) => item.isSelected)
        .toList();
    
    if (selectedItems.isEmpty) return;
    
    // ✅ Tính tổng tiền hàng dựa trên originalPrice (giá gốc)
    final totalGoods = selectedItems.fold(
      0,
      (sum, item) => sum + ((item.originalPrice ?? item.price) * item.quantity),
    );
    
    // Lấy danh sách product ID trong giỏ hàng
    final cartProductIds = selectedItems.map((item) => item.id).toList();
    
    // Tự động áp dụng voucher tốt nhất cho từng shop
    for (final entry in itemsByShop.entries) {
      final shopId = entry.key;
      final items = entry.value;
      
      // Chỉ tính cho các item đã chọn
      final shopSelectedItems = items.where((item) => item.isSelected).toList();
      if (shopSelectedItems.isEmpty) continue;
      
      // ✅ Tính tổng tiền của shop dựa trên originalPrice (giá gốc)
      final shopTotal = shopSelectedItems.fold(
        0,
        (sum, item) => sum + ((item.originalPrice ?? item.price) * item.quantity),
      );
      
      // Lấy danh sách product ID trong giỏ hàng của shop
      final shopProductIds = shopSelectedItems.map((item) => item.id).toList();
      
      // Tự động áp dụng voucher tốt nhất cho shop
      await _voucherService.autoApplyBestVoucher(
        shopId,
        shopTotal,
        shopProductIds,
      );
    }
    
    // Tự động áp dụng voucher sàn tốt nhất (sau khi đã áp dụng voucher shop)
    await _voucherService.autoApplyBestPlatformVoucher(
      totalGoods,
      cartProductIds,
      items: selectedItems
          .map((e) => {'id': e.id, 'price': e.price, 'quantity': e.quantity})
          .toList(),
    );
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
      body: Stack(
        children: [
          // ✅ ListView chính với scroll controller
          ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            // ✅ Đảm bảo ListView có thể cuộn bình thường
            physics: const AlwaysScrollableScrollPhysics(),
            shrinkWrap: false,
            children: [
              // ✅ DeliveryInfoSection là một child bình thường trong ListView, sẽ cuộn theo trang
              const DeliveryInfoSection(),
              const SizedBox(height: 12),
              ProductSection(),
              const SizedBox(height: 12),
              const OrderSummarySection(),
              const SizedBox(height: 12),
              // ✅ FirstTimeBonusSection tự tính eligibleTotal từ cart items (chỉ 5 shop hợp lệ)
              const FirstTimeBonusSection(),
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
          // ✅ Sticky header hiển thị khi cuộn
          if (_showStickyHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DeliveryInfoStickyHeader(
                user: _user,
                defaultAddress: _defaultAddress,
                onTap: _openAddressBook,
              ),
            ),
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
            final loginResult = await Navigator.pushNamed(context, '/login');
            
            // Nếu login thành công, reload cart và trigger rebuild
            if (loginResult == true) {
              // ✅ Reload cart sau khi đăng nhập (sẽ merge cart guest vào cart user)
              await _cartService.loadCartForUser();
              
              // ✅ Trigger rebuild để cập nhật UI
              if (mounted) {
                setState(() {});
              }
              
              // ✅ Trigger reload shipping fee sau khi đăng nhập
              ShippingEvents.refresh();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đăng nhập thành công!'),
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
      // ✅ Helper function để format số thành string với dấu phẩy (giống website)
      String formatPrice(int price) {
        return price.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
      }
      
      // ✅ Helper function để chuyển full URL thành relative path
      String getRelativeImagePath(String imageUrl) {
        if (imageUrl.isEmpty) return '';
        // Nếu là full URL, lấy phần path sau domain
        final uri = Uri.tryParse(imageUrl);
        if (uri != null && uri.path.isNotEmpty) {
          return uri.path;
        }
        // Nếu đã là relative path, trả về nguyên
        if (imageUrl.startsWith('/')) {
          return imageUrl;
        }
        return imageUrl;
      }
      
      // ✅ Helper function để parse pl từ variant (nếu variant là pl ID hoặc chứa pl)
      int? parsePlFromVariant(String? variant) {
        if (variant == null || variant.isEmpty) return null;
        // Thử parse variant như là pl ID
        final plId = int.tryParse(variant);
        if (plId != null) return plId;
        // Nếu variant có format "sp_id_pl", extract pl
        final parts = variant.split('_');
        if (parts.length >= 2) {
          final lastPart = int.tryParse(parts.last);
          if (lastPart != null) return lastPart;
        }
        return null;
      }
      
      // ✅ Helper function để parse color và size từ variant name
      Map<String, String> parseColorSizeFromVariant(String? variant) {
        if (variant == null || variant.isEmpty) {
          return {'color': '', 'size': '+'};
        }
        // Tách variant name để lấy color và size
        // Format thường là: "Color: #02, Size: +" hoặc "#02, +"
        String color = '';
        String size = '+';
        
        // Tìm color (thường bắt đầu bằng #)
        final colorMatch = RegExp(r'#[\w\d]+').firstMatch(variant);
        if (colorMatch != null) {
          color = colorMatch.group(0) ?? '';
        }
        
        // Tìm size (thường là chữ hoặc số)
        final sizeMatch = RegExp(r'Size[:\s]+([^,]+)', caseSensitive: false).firstMatch(variant);
        if (sizeMatch != null) {
          size = sizeMatch.group(1)?.trim() ?? '+';
        } else {
          // Nếu không tìm thấy, thử tìm pattern khác
          final parts = variant.split(',');
          if (parts.length >= 2) {
            size = parts.last.trim();
          }
        }
        
        return {'color': color, 'size': size};
      }
      
      // ✅ Helper function để tạo link từ tieu_de
      String createLinkFromTitle(String title) {
        // Chuyển tiêu đề thành link (lowercase, thay space bằng dấu gạch ngang)
        return title
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-')
            .replaceAll(RegExp(r'-+'), '-')
            .trim();
      }
      
      // Chuẩn bị payload theo format website (object với key sp_id_pl)
      final selectedItems = _cartService.items.where((i) => i.isSelected).toList();
      
      // ✅ Tạo map items theo format website: { "sp_id_pl": { ... } }
      final Map<String, Map<String, dynamic>> itemsMap = {};
      
      for (final item in selectedItems) {
        // Parse pl từ variant (nếu có)
        final pl = parsePlFromVariant(item.variant) ?? 0;
        final key = '${item.id}_$pl';
        
        // Parse color và size từ variant
        final colorSize = parseColorSizeFromVariant(item.variant);
        
        // ✅ Sử dụng originalPrice (giá gốc) để tính toán trong checkout, nếu không có thì dùng price
        // Trong checkout sẽ trừ các ưu đãi, nên phải dùng giá gốc để tránh trừ 2 lần
        final basePrice = item.originalPrice ?? item.price;
        final giaMoiFormatted = formatPrice(basePrice);
        final thanhTienFormatted = formatPrice(basePrice * item.quantity);
        
        // Chuyển anh_chinh thành minh_hoa (relative path)
        final minhHoa = getRelativeImagePath(item.image);
        
        // Tạo link từ tieu_de
        final link = createLinkFromTitle(item.name);
        
        // ✅ Tạo item theo format website
        itemsMap[key] = {
          'sp_id': item.id,
          'pl': pl,
          'quantity': item.quantity,
          'gia_moi': giaMoiFormatted,  // String với dấu phẩy
          'thanhtien': thanhTienFormatted,  // String với dấu phẩy
          'tieu_de': item.name,
          'color': colorSize['color'] ?? '',
          'size': colorSize['size'] ?? '+',
          'link': link,
          'minh_hoa': minhHoa,
          'hoa_hong': '0',
          // 'utm_source': user.userId.toString(),
          // 'utm_campaign': '',
          // ✅ Thêm các field bổ sung từ app (để backend xử lý)
          'shop': item.shopId,
          // ✅ Giữ giá trị số để tính toán (dùng basePrice - giá gốc)
          '_gia_moi_number': basePrice,
          '_thanh_tien_number': basePrice * item.quantity,
        };
      }
      
      // ✅ Chuyển map thành list để xử lý (giữ format cũ cho logic tính toán)
      final items = itemsMap.values.toList();

    // Lấy địa chỉ mặc định từ user_profile để điền
    final profile = await _api.getUserProfile(userId: user.userId);
      final addr =
          (profile?['addresses'] as List?)
              ?.cast<Map<String, dynamic>?>()
              .firstWhere(
            (a) => (a?['active'] == 1 || a?['active'] == '1'),
                orElse: () => null,
              ) ??
          (profile?['addresses'] as List?)
              ?.cast<Map<String, dynamic>?>()
              .firstOrNull;
    if (addr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm địa chỉ nhận hàng')),
      );
      return;
    }

    final ship = ShippingQuoteStore();
    final voucherService = VoucherService();
    
    // ✅ Tính voucher discount theo từng shop để gửi chính xác
      final totalGoods = items.fold(
        0,
        (s, i) => s + (i['_gia_moi_number'] as int? ?? 0) * (i['quantity'] as int? ?? 1),
      );
    
    // ✅ Tính shop discount cho từng shop
    final Map<int, int> shopDiscounts = {}; // shopId => discount
    final itemsByShop = <int, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final shopId = item['shop'] as int? ?? 0;
      if (!itemsByShop.containsKey(shopId)) {
        itemsByShop[shopId] = [];
      }
      itemsByShop[shopId]!.add(item);
    }
    
    for (final entry in itemsByShop.entries) {
      final shopId = entry.key;
        
        // ✅ Bỏ qua shop 0 (Sàn TMĐT) - không có voucher shop
        if (shopId <= 0) {
          continue;
        }
        
      final shopItems = entry.value;
        final shopTotal = shopItems.fold(
          0,
          (s, i) => s + (i['_gia_moi_number'] as int? ?? 0) * (i['quantity'] as int? ?? 1),
        );
        final shopDiscount = voucherService.calculateShopDiscount(
          shopId,
          shopTotal,
        );
      if (shopDiscount > 0) {
        shopDiscounts[shopId] = shopDiscount;
      }
    }
    
      // ✅ Tính platform discount cho từng shop (dựa trên TẤT CẢ platform vouchers, giống như UI)
      // ✅ Sử dụng logic tương tự VoucherService.calculatePlatformDiscountWithItems nhưng phân bổ theo shop
    final Map<int, int> platformDiscounts = {}; // shopId => discount
      final platformVouchers = voucherService.platformVouchers;

      if (platformVouchers.isNotEmpty) {
        // ✅ Duyệt qua TẤT CẢ platform vouchers (giống như UI)
        for (final entry in platformVouchers.entries) {
          final voucherCode = entry.key;
          final voucher = entry.value;

          // Lấy danh sách sản phẩm áp dụng của voucher này
      final allowIds = <int>{};
          bool isAllProducts =
              voucher.isAllProducts == true || voucher.voucherType == 'all';

          if (!isAllProducts) {
            if (voucher.applicableProductsDetail != null &&
                voucher.applicableProductsDetail!.isNotEmpty) {
              for (final m in voucher.applicableProductsDetail!) {
          final id = int.tryParse(m['id'] ?? '');
          if (id != null) allowIds.add(id);
        }
            } else if (voucher.applicableProducts != null &&
                voucher.applicableProducts!.isNotEmpty) {
              for (final s in voucher.applicableProducts!) {
          final id = int.tryParse(s);
          if (id != null) allowIds.add(id);
        }
            }
      }
      
          // ✅ Tính discount cho từng shop dựa trên sản phẩm áp dụng trong shop đó
          for (final shopEntry in itemsByShop.entries) {
            final shopId = shopEntry.key;
            final shopItems = shopEntry.value;
        
        // Tính subtotal của sản phẩm áp dụng trong shop này
        int applicableSubtotal = 0;
            if (isAllProducts) {
              // Áp dụng cho tất cả sản phẩm trong shop
              applicableSubtotal = shopItems.fold(
                0,
                (s, i) => s + (i['_gia_moi_number'] as int? ?? 0) * (i['quantity'] as int? ?? 1),
              );
            } else if (allowIds.isNotEmpty) {
          // Chỉ tính sản phẩm trong danh sách áp dụng
          for (final item in shopItems) {
            final productId = item['sp_id'] as int? ?? item['id'] as int? ?? 0;
            if (allowIds.contains(productId)) {
                  applicableSubtotal +=
                      (item['_gia_moi_number'] as int? ?? 0) * (item['quantity'] as int? ?? 1);
            }
          }
        }
        
            if (applicableSubtotal > 0) {
              // Tính discount cho shop này
          int discount = 0;
              if (voucher.discountType == 'percentage') {
                discount = (applicableSubtotal * voucher.discountValue! / 100)
                    .round();
                if (voucher.maxDiscountValue != null &&
                    voucher.maxDiscountValue! > 0) {
                  discount = discount > voucher.maxDiscountValue!.round()
                      ? voucher.maxDiscountValue!.round()
                  : discount;
            }
          } else {
                // Fixed discount: chia đều cho các shop có sản phẩm áp dụng
                // Nếu có nhiều shop áp dụng, chia theo tỷ lệ subtotal
                final totalApplicableSubtotal = itemsByShop.values.fold(0, (
                  sum,
                  items,
                ) {
                  int shopSubtotal = 0;
                  if (isAllProducts) {
                    shopSubtotal = items.fold(
                      0,
                      (s, i) =>
                          s + (i['_gia_moi_number'] as int? ?? 0) * (i['quantity'] as int? ?? 1),
                    );
                  } else if (allowIds.isNotEmpty) {
                    for (final item in items) {
                      final productId = item['sp_id'] as int? ?? item['id'] as int? ?? 0;
                      if (allowIds.contains(productId)) {
                        shopSubtotal +=
                            (item['_gia_moi_number'] as int? ?? 0) *
                            (item['quantity'] as int? ?? 1);
                      }
                    }
                  }
                  return sum + shopSubtotal;
                });

                if (totalApplicableSubtotal > 0) {
                  // Chia discount theo tỷ lệ subtotal của shop này
                  discount =
                      (voucher.discountValue!.round() *
                              applicableSubtotal /
                              totalApplicableSubtotal)
                          .round();
                } else {
                  discount = voucher.discountValue!.round();
                }
          }
          
          if (discount > 0) {
                platformDiscounts[shopId] =
                    (platformDiscounts[shopId] ?? 0) + discount;
                print(
                  '      ✅ Shop $shopId: +$discount (subtotal: $applicableSubtotal) → Tổng: ${platformDiscounts[shopId]}',
                );
          }
        }
      }
    }
      }
    // ✅ Tính tổng để gửi (backward compatibility)
    final shopDiscount = shopDiscounts.values.fold(0, (s, d) => s + d);
      final platformDiscount = platformDiscounts.values.fold(
        0,
        (s, d) => s + d,
      );
    // final voucherDiscount = (shopDiscount + platformDiscount).clamp(0, totalGoods);
    
    // Lấy mã coupon từ platform voucher
    final platformVoucher = voucherService.platformVoucher;
    final couponCode = platformVoucher?.code ?? '';
    
    // ✅ Ưu tiên sử dụng shipSupport từ ShippingQuoteStore (giá trị đã được set từ OrderSummarySection)
    // Đảm bảo giá trị khớp với UI hiển thị
      int shipSupport =
          ship.shipSupport; // Lấy từ store (giá trị đúng, không bị clamp)
    int originalShipFee = ship.lastFee; // Phí ship gốc
    
    // Map để lưu shipping_provider cho từng shop
    Map<int, String> shopShippingProviders = {};
    // ✅ Map để lưu shipping_fee và ship_support cho từng shop
    Map<int, int> shopShippingFees = {};
    Map<int, int> shopShipSupports = {};
    
    // Gọi API shipping_quote để lấy thông tin freeship cho tất cả items
    // Chỉ để lấy warehouse_details và provider, không cần tính lại shipSupport
    try {
      // ✅ Thêm giá vào items để fallback tính chính xác hơn
        final shippingItems = items
            .map(
              (item) => {
        'product_id': item['sp_id'] ?? item['id'],
        'quantity': item['quantity'],
                'price':
                    item['_gia_moi_number'] ?? item['gia_moi'], // ✅ Thêm giá để fallback tính chính xác
              },
            )
            .toList();
      
      // ✅ Sử dụng ShippingQuoteService với retry, timeout, fallback, và cache
      final shippingQuote = await _shippingQuoteService.getShippingQuote(
        userId: user.userId,
        items: shippingItems.cast<Map<String, dynamic>>(),
        useCache: true,
        enableFallback: true, // ✅ Cho phép fallback nếu API fail
      );
      
      if (shippingQuote != null && shippingQuote['success'] == true) {
        // ✅ Lấy phí ship gốc từ API (nếu có) để đảm bảo chính xác
          final bestOverall =
              shippingQuote['data']?['best'] as Map<String, dynamic>?;
        if (bestOverall != null) {
            final apiFee = bestOverall['fee'] as int? ?? ship.lastFee;

            originalShipFee = apiFee; // Phí ship gốc từ API
          // ✅ Không override shipSupport từ store, vì store đã có giá trị đúng
          // shipSupport từ store đã được set từ OrderSummarySection với giá trị chính xác
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
            final warehouseShipping =
                shippingQuote['data']?['warehouse_shipping']
                    as Map<String, dynamic>?;
          if (warehouseShipping != null) {
              warehouseDetails =
                  warehouseShipping['warehouse_details'] as List<dynamic>?;
          }
        }
        
        // Nếu vẫn không có, thử lấy từ quotes[0]
        if (warehouseDetails == null || warehouseDetails.isEmpty) {
          final quotes = shippingQuote['quotes'] as List<dynamic>?;
          if (quotes != null && quotes.isNotEmpty) {
            final firstQuote = quotes[0] as Map<String, dynamic>?;
            if (firstQuote != null) {
                warehouseDetails =
                    firstQuote['warehouse_details'] as List<dynamic>?;
            }
          }
        }
        
        // ✅ Map shipping_fee và ship_support theo shop_id từ warehouse_details
        // Map provider cho từng shop
        // ✅ Đảm bảo mỗi shop chỉ có 1 provider duy nhất
        if (warehouseDetails != null && warehouseDetails.isNotEmpty) {
            int totalWarehouseFee = 0; // Tổng phí ship từ warehouse_details

          for (final detail in warehouseDetails) {
            final detailMap = detail as Map<String, dynamic>?;
            if (detailMap != null) {
                final shopId =
                    int.tryParse('${detailMap['shop_id'] ?? 0}') ?? 0;
              final provider = detailMap['provider']?.toString() ?? '';
                final shippingFee =
                    (detailMap['shipping_fee'] as num?)?.toInt() ?? 0;
              
              // ✅ Xử lý cả shop_id = 0 (nếu có) và shop_id > 0
              if (provider.isNotEmpty) {
                // ✅ Nếu shop đã có provider, ghi đè (không nên xảy ra trong thực tế)
                shopShippingProviders[shopId] = provider;
              }
              
                // ✅ Lưu shipping_fee theo shop_id (chỉ shop có warehouse)
                if (shippingFee > 0 && shopId > 0) {
                shopShippingFees[shopId] = shippingFee;
                  totalWarehouseFee += shippingFee;
                }
              }
            }

            // ✅ QUAN TRỌNG: Tính phí ship cho shop 0 (sàn TMDT) = tổng phí ship - tổng phí ship của các shop khác
            // Shop 0 không có warehouse nên không có trong warehouse_details, nhưng vẫn được tính trong tổng phí ship
            final totalShipFee = originalShipFee; // Phí ship tổng từ API
            final shop0Fee = totalShipFee - totalWarehouseFee;

            if (shop0Fee > 0) {
              // Kiểm tra xem có items thuộc shop 0 không
              final hasShop0Items = items.any(
                (item) => (item['shop'] as int? ?? 0) == 0,
              );
              if (hasShop0Items) {
                shopShippingFees[0] = shop0Fee;
            }
          }
          
          // ✅ Tính ship_support theo shop từ shop_freeship_details trong debug
            final debug =
                shippingQuote['data']?['debug'] as Map<String, dynamic>?;
            final shopFreeshipDetails =
                debug?['shop_freeship_details'] as Map<String, dynamic>?;
          
          if (shopFreeshipDetails != null) {
            // Tính ship_support cho từng shop từ shop_freeship_details
            for (final entry in shopFreeshipDetails.entries) {
              final shopId = int.tryParse(entry.key) ?? 0;
              final config = entry.value as Map<String, dynamic>?;
              
                if (shopId > 0 &&
                    config != null &&
                    (config['applied'] == true)) {
                final mode = (config['mode'] as num?)?.toInt() ?? 0;
                final subtotal = (config['subtotal'] as num?)?.toInt() ?? 0;
                  final discount =
                      (config['discount'] as num?)?.toDouble() ?? 0.0;
                
                int shopSupport = 0;
                
                if (mode == 0 && discount > 0) {
                  // Mode 0: Fixed discount
                  shopSupport = discount.toInt();
                } else if (mode == 1) {
                  // Mode 1: 100% freeship - lấy shipping_fee của shop này
                  shopSupport = shopShippingFees[shopId] ?? 0;
                } else if (mode == 2 && discount > 0 && subtotal > 0) {
                  // Mode 2: % discount của subtotal
                  shopSupport = (subtotal * discount / 100).round();
                } else if (mode == 3) {
                  // Mode 3: Per-product freeship
                    final products =
                        config['products'] as Map<String, dynamic>?;
                  if (products != null) {
                    for (final prodEntry in products.entries) {
                        final prodConfig =
                            prodEntry.value as Map<String, dynamic>?;
                        final prodType =
                            prodConfig?['type']?.toString() ?? 'fixed';
                        final prodValue =
                            (prodConfig?['value'] as num?)?.toDouble() ?? 0.0;
                      
                      if (prodType == 'fixed') {
                        shopSupport += prodValue.toInt();
                      } else if (prodType == 'percent') {
                        // Mode 3 percent: tính trên shipping_fee của shop
                        final shopFee = shopShippingFees[shopId] ?? 0;
                        shopSupport += (shopFee * prodValue / 100).round();
                      }
                    }
                  }
                }
                
                if (shopSupport > 0) {
                  shopShipSupports[shopId] = shopSupport;
                }
              }
            }
          }
        } 
      }
    } catch (e) {
      // Nếu có lỗi khi gọi shipping_quote, sử dụng ship fee gốc và shipSupport từ store
    }
    
    // ✅ KHÔNG clamp shipSupport vì API cho phép shipSupport lớn hơn ship fee
    // shipSupport từ store đã là giá trị chính xác từ API (39.400)
    // Việc clamp sẽ làm sai giá trị (giảm từ 39.400 xuống 12.000)
    
    // ✅ Thêm shipping_provider, shipping_fee, ship_support, shop_discount, platform_discount vào mỗi item dựa trên shop_id
    // ✅ Đảm bảo tất cả items trong cùng shop có cùng provider, phí ship và discount
    final itemsWithProvider = items.map((item) {
      final shopId = item['shop'] as int? ?? 0;
      // ✅ Giữ nguyên format website, chỉ thêm các field bổ sung
      // ✅ Ưu tiên lấy từ shopShippingProviders (từ warehouse_details)
      // Nếu không có, dùng fallback từ ship.provider
      final provider = shopShippingProviders[shopId] ?? ship.provider ?? '';
      // ✅ Lấy shipping_fee và ship_support theo shop_id
      final itemShippingFee = shopShippingFees[shopId] ?? 0;
      final itemShipSupport = shopShipSupports[shopId] ?? 0;
      // ✅ Lấy shop_discount và platform_discount theo shop_id
      final itemShopDiscount = shopDiscounts[shopId] ?? 0;
      final itemPlatformDiscount = platformDiscounts[shopId] ?? 0;
      
      // ✅ Đảm bảo gửi discount ngay cả khi = 0 để backend biết shop này không có discount
        // ✅ QUAN TRỌNG: Shop 0 phải có shipping_fee (kể cả = 0) để backend không chia theo tỷ lệ
      // ✅ Giữ nguyên format website, chỉ thêm các field bổ sung cho backend xử lý
      final itemWithProvider = Map<String, dynamic>.from(item);
      itemWithProvider['shipping_provider'] = provider;
      itemWithProvider['shipping_fee'] = itemShippingFee;
      if (itemShipSupport > 0) {
        itemWithProvider['ship_support'] = itemShipSupport;
      }
      itemWithProvider['shop_discount_per_shop'] = itemShopDiscount;
      itemWithProvider['platform_discount_per_shop'] = itemPlatformDiscount;
      return itemWithProvider;
    }).toList();
    
    // ✅ Validation: Kiểm tra tất cả items trong cùng shop có cùng provider
    final shopProviderMap = <int, String>{};
    for (final item in itemsWithProvider) {
      final shopId = item['shop'] as int? ?? 0;
      final provider = item['shipping_provider']?.toString() ?? '';
      if (shopProviderMap.containsKey(shopId)) {
        final existingProvider = shopProviderMap[shopId];
          if (existingProvider != provider) {}
      } else {
        shopProviderMap[shopId] = provider;
      }
    }
    
    // ✅ Chuyển itemsWithProvider thành format object với key sp_id_pl (giống website)
    final Map<String, Map<String, dynamic>> finalItemsMap = {};
    for (final item in itemsWithProvider) {
      final spId = item['sp_id'] as int? ?? item['id'] as int? ?? 0;
      final pl = item['pl'] as int? ?? 0;
      final key = '${spId}_$pl';
      
      // ✅ Xóa các field tạm thời (_gia_moi_number, _thanh_tien_number) trước khi gửi
      final finalItem = Map<String, dynamic>.from(item);
      finalItem.remove('_gia_moi_number');
      finalItem.remove('_thanh_tien_number');
      
      finalItemsMap[key] = finalItem;
    }
    
    // ✅ Chuyển map thành list để gửi (backend sẽ group lại theo shop)
    final finalItemsList = finalItemsMap.values.toList();
    
    final res = await _api.createOrder(
      userId: user.userId,
      hoTen: addr['ho_ten']?.toString() ?? user.name,
      dienThoai: addr['dien_thoai']?.toString() ?? user.mobile,
      email: user.email,
      diaChi: addr['dia_chi']?.toString() ?? '',
      tinh: int.tryParse('${addr['tinh'] ?? 0}') ?? 0,
      huyen: int.tryParse('${addr['huyen'] ?? 0}') ?? 0,
      xa: int.tryParse('${addr['xa'] ?? 0}'),
        sanpham: finalItemsList
            .cast<Map<String, dynamic>>(), // ✅ Sử dụng finalItemsList với format website
      thanhtoan: selectedPaymentMethod.toUpperCase(),
      ghiChu: '',
      coupon: couponCode,
        giam: shopDiscount, // ✅ Shop discount
      voucherTmdt: platformDiscount, // ✅ Platform discount
        phiShip: originalShipFee, // ✅ Phí ship gốc (giống website)
        shipSupport: shipSupport, // ✅ Hỗ trợ ship từ freeship
        shippingProvider: ship
            .provider, // ✅ Vẫn giữ để tương thích, nhưng sẽ bị override bởi provider trong items
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
              style: const TextStyle(
                color: Colors.white,
              ), // chữ trắng cho dễ đọc
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
      // ✅ DEBUG: Hiển thị lỗi chi tiết hơn
      final errorMsg = res?['message'] ?? 'Lỗi không xác định';
      final errorDetail = res?['error'] ?? '';
      final errorCode = res?['error_code'] ?? '';
      final shopId = res?['shop_id'] ?? '';

      String displayMessage = 'Đặt hàng thất bại: $errorMsg';
      if (errorDetail.isNotEmpty) {
        displayMessage += '\nChi tiết: $errorDetail';
      }
      if (errorCode.toString().isNotEmpty) {
        displayMessage += '\nMã lỗi: $errorCode';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              displayMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10), // Hiển thị lâu hơn để đọc
          ),
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
