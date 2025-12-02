import 'package:flutter/material.dart';
import 'widgets/delivery_info_section.dart';
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
import '../../core/services/affiliate_tracking_service.dart';
import '../../core/services/shipping_quote_store.dart';
import '../../core/services/voucher_service.dart';
import '../../core/services/shipping_events.dart';
import '../../core/services/shipping_quote_service.dart';
import '../../core/services/first_time_bonus_service.dart';

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
  final AffiliateTrackingService _affiliateTracking = AffiliateTrackingService();
  final VoucherService _voucherService = VoucherService();
  final ShippingQuoteService _shippingQuoteService = ShippingQuoteService(); // ✅ Service chuyên nghiệp
  final ScrollController _scrollController = ScrollController();

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
    
    // ✅ Lắng nghe thay đổi cart để rebuild khi cart thay đổi
    _cartService.addListener(_onCartChanged);
    
    // ✅ Lắng nghe thay đổi auth state để reload sau khi đăng nhập
    _auth.addAuthStateListener(_onAuthStateChanged);
  }
  
  @override
  void dispose() {
    // ✅ Remove listeners
    _cartService.removeListener(_onCartChanged);
    _auth.removeAuthStateListener(_onAuthStateChanged);
    _scrollController.dispose(); // ✅ Dispose scroll controller
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
      // Trigger rebuild
      setState(() {});
      // Trigger refresh shipping
      ShippingEvents.refresh();
    }
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
    await _voucherService.autoApplyBestPlatformVoucher(
      totalGoods,
      cartProductIds,
      items: selectedItems.map((e) => {'id': e.id, 'price': e.price, 'quantity': e.quantity}).toList(),
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
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ✅ Sticky header cho DeliveryInfoSection
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyAddressHeaderDelegate(
              child: DeliveryInfoSection(
                scrollController: _scrollController,
              ),
            ),
          ),
          // ✅ Nội dung còn lại
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverToBoxAdapter(
              child: Column(
        children: [
          const SizedBox(height: 12),
          ProductSection(),
          const SizedBox(height: 12),
          const OrderSummarySection(),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              // ✅ Tính eligible_total (CHỈ từ 3 shop hợp lệ: 32373, 23933, 36893)
              // Bonus 10% CHỈ tính trên tiền hàng từ 3 shop này, KHÔNG tính toàn bộ giỏ
              final cart = _cartService;
              final items = cart.items.where((i) => i.isSelected).toList();
              
              // ✅ Chuyển items sang format cho calculateEligibleTotal
              final bonusService = FirstTimeBonusService();
              final eligibleItems = items.map((i) => {
                'shopId': i.shopId,
                'price': i.price,
                'quantity': i.quantity,
              }).toList();
              final eligibleTotal = bonusService.calculateEligibleTotal(eligibleItems);

              return FirstTimeBonusSection(
                orderTotal: eligibleTotal, // ✅ Truyền eligible_total, KHÔNG phải totalGoods
              );
            },
          ),
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
            final loginResult = await Navigator.pushNamed(
              context,
              '/login',
            );
            
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
    
    // ✅ DEBUG: Print địa chỉ được chọn

    final ship = ShippingQuoteStore();
    final voucherService = VoucherService();
    
    // ✅ Tính voucher discount theo từng shop để gửi chính xác
    final totalGoods = items.fold(0, (s, i) => s + (i['gia_moi'] as int) * (i['quantity'] as int));
    
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
      final shopItems = entry.value;
      final shopTotal = shopItems.fold(0, (s, i) => s + (i['gia_moi'] as int) * (i['quantity'] as int));
      final shopDiscount = voucherService.calculateShopDiscount(shopId, shopTotal);
      if (shopDiscount > 0) {
        shopDiscounts[shopId] = shopDiscount;
      }
    }
    
    // ✅ Tính platform discount cho từng shop (dựa trên sản phẩm áp dụng trong shop đó)
    final Map<int, int> platformDiscounts = {}; // shopId => discount
    final pv = voucherService.platformVoucher;
    if (pv != null && pv.discountValue != null) {
      // Lấy danh sách sản phẩm áp dụng
      final allowIds = <int>{};
      if (pv.applicableProductsDetail != null && pv.applicableProductsDetail!.isNotEmpty) {
        for (final m in pv.applicableProductsDetail!) {
          final id = int.tryParse(m['id'] ?? '');
          if (id != null) allowIds.add(id);
        }
      } else if (pv.applicableProducts != null && pv.applicableProducts!.isNotEmpty) {
        for (final s in pv.applicableProducts!) {
          final id = int.tryParse(s);
          if (id != null) allowIds.add(id);
        }
      }
      
      // Tính platform discount cho từng shop
      for (final entry in itemsByShop.entries) {
        final shopId = entry.key;
        final shopItems = entry.value;
        
        // Tính subtotal của sản phẩm áp dụng trong shop này
        int applicableSubtotal = 0;
        if (allowIds.isEmpty) {
          // Áp dụng cho tất cả sản phẩm
          applicableSubtotal = shopItems.fold(0, (s, i) => s + (i['gia_moi'] as int) * (i['quantity'] as int));
        } else {
          // Chỉ tính sản phẩm trong danh sách áp dụng
          for (final item in shopItems) {
            final productId = item['id'] as int? ?? 0;
            if (allowIds.contains(productId)) {
              applicableSubtotal += (item['gia_moi'] as int) * (item['quantity'] as int);
            }
          }
        }
        
        if (applicableSubtotal > 0 && totalGoods >= (pv.minOrderValue?.round() ?? 0)) {
          // Tính discount
          int discount = 0;
          if (pv.discountType == 'percentage') {
            discount = (applicableSubtotal * pv.discountValue! / 100).round();
            if (pv.maxDiscountValue != null && pv.maxDiscountValue! > 0) {
              discount = discount > pv.maxDiscountValue!.round() 
                  ? pv.maxDiscountValue!.round() 
                  : discount;
            }
          } else {
            discount = pv.discountValue!.round();
          }
          
          if (discount > 0) {
            platformDiscounts[shopId] = discount;
          }
        }
      }
    }
    
    // ✅ Tính tổng để gửi (backward compatibility)
    final shopDiscount = shopDiscounts.values.fold(0, (s, d) => s + d);
    final platformDiscount = platformDiscounts.values.fold(0, (s, d) => s + d);
    // final voucherDiscount = (shopDiscount + platformDiscount).clamp(0, totalGoods);
    
    // Lấy mã coupon từ platform voucher
    final platformVoucher = voucherService.platformVoucher;
    final couponCode = platformVoucher?.code ?? '';
    
    // ✅ Ưu tiên sử dụng shipSupport từ ShippingQuoteStore (giá trị đã được set từ OrderSummarySection)
    // Đảm bảo giá trị khớp với UI hiển thị
    int shipSupport = ship.shipSupport; // Lấy từ store (giá trị đúng, không bị clamp)
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
      final shippingItems = items.map((item) => {
        'product_id': item['id'],
        'quantity': item['quantity'],
        'price': item['gia_moi'], // ✅ Thêm giá để fallback tính chính xác
      }).toList();
      
    
      for (final item in shippingItems) {
        print('   - Product ID: ${item['product_id']}, Quantity: ${item['quantity']}, Price: ${item['price']}');
      }
      
      // ✅ Sử dụng ShippingQuoteService với retry, timeout, fallback, và cache
      final shippingQuote = await _shippingQuoteService.getShippingQuote(
        userId: user.userId,
        items: shippingItems.cast<Map<String, dynamic>>(),
        useCache: true,
        enableFallback: true, // ✅ Cho phép fallback nếu API fail
      );
      

      
      if (shippingQuote != null && shippingQuote['success'] == true) {
        // ✅ Lấy phí ship gốc từ API (nếu có) để đảm bảo chính xác
        final bestOverall = shippingQuote['data']?['best'] as Map<String, dynamic>?;
        if (bestOverall != null) {
          final apiFee = bestOverall['fee'] as int? ?? ship.lastFee;
        
          originalShipFee = apiFee; // Phí ship gốc từ API
          // ✅ Không override shipSupport từ store, vì store đã có giá trị đúng
          // shipSupport từ store đã được set từ OrderSummarySection với giá trị chính xác
        }
        
        //
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
        
        // ✅ Map shipping_fee và ship_support theo shop_id từ warehouse_details
        // Map provider cho từng shop
        // ✅ Đảm bảo mỗi shop chỉ có 1 provider duy nhất
        if (warehouseDetails != null && warehouseDetails.isNotEmpty) {
          for (final detail in warehouseDetails) {
            final detailMap = detail as Map<String, dynamic>?;
            if (detailMap != null) {
              final shopId = int.tryParse('${detailMap['shop_id'] ?? 0}') ?? 0;
              final provider = detailMap['provider']?.toString() ?? '';
              final shippingFee = (detailMap['shipping_fee'] as num?)?.toInt() ?? 0;
              
              // ✅ Xử lý cả shop_id = 0 (nếu có) và shop_id > 0
              if (provider.isNotEmpty) {
                // ✅ Nếu shop đã có provider, ghi đè (không nên xảy ra trong thực tế)
                shopShippingProviders[shopId] = provider;
              }
              
              // ✅ Lưu shipping_fee theo shop_id
              if (shopId > 0 && shippingFee > 0) {
                shopShippingFees[shopId] = shippingFee;
              }
            }
          }
          
          // ✅ Tính ship_support theo shop từ shop_freeship_details trong debug
          final debug = shippingQuote['data']?['debug'] as Map<String, dynamic>?;
          final shopFreeshipDetails = debug?['shop_freeship_details'] as Map<String, dynamic>?;
          
          if (shopFreeshipDetails != null) {
            // Tính ship_support cho từng shop từ shop_freeship_details
            for (final entry in shopFreeshipDetails.entries) {
              final shopId = int.tryParse(entry.key) ?? 0;
              final config = entry.value as Map<String, dynamic>?;
              
              if (shopId > 0 && config != null && (config['applied'] == true)) {
                final mode = (config['mode'] as num?)?.toInt() ?? 0;
                final subtotal = (config['subtotal'] as num?)?.toInt() ?? 0;
                final discount = (config['discount'] as num?)?.toDouble() ?? 0.0;
                
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
                  final products = config['products'] as Map<String, dynamic>?;
                  if (products != null) {
                    for (final prodEntry in products.entries) {
                      final prodConfig = prodEntry.value as Map<String, dynamic>?;
                      final prodType = prodConfig?['type']?.toString() ?? 'fixed';
                      final prodValue = (prodConfig?['value'] as num?)?.toDouble() ?? 0.0;
                      
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
      return {
        ...item,
        'shipping_provider': provider, // ✅ Thêm shipping_provider vào mỗi item
        if (itemShippingFee > 0) 'shipping_fee': itemShippingFee, // ✅ Thêm shipping_fee vào mỗi item
        if (itemShipSupport > 0) 'ship_support': itemShipSupport, // ✅ Thêm ship_support vào mỗi item
        'shop_discount_per_shop': itemShopDiscount, // ✅ Thêm shop_discount vào mỗi item (kể cả 0)
        'platform_discount_per_shop': itemPlatformDiscount, // ✅ Thêm platform_discount vào mỗi item (kể cả 0)
      };
    }).toList();
    
    // ✅ Validation: Kiểm tra tất cả items trong cùng shop có cùng provider
    final shopProviderMap = <int, String>{};
    for (final item in itemsWithProvider) {
      final shopId = item['shop'] as int? ?? 0;
      final provider = item['shipping_provider']?.toString() ?? '';
      if (shopProviderMap.containsKey(shopId)) {
        final existingProvider = shopProviderMap[shopId];
        if (existingProvider != provider) {
         
        }
      } else {
        shopProviderMap[shopId] = provider;
      }
    }
    


    
    // final grandTotal = totalGoods + finalShipFee - shopDiscount - platformDiscount;
    
    // ✅ Lấy affiliate_id nếu có (từ deep link)
    final affiliateId = await _affiliateTracking.getAffiliateId();
    
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
      utmSource: affiliateId,        // ✅ Gửi affiliate_id qua utm_source (backend sẽ xử lý riêng)
    );
    
    if (res?['success'] == true) {
      final data = res?['data'];
      final maDon = data?['ma_don'] ?? '';
      final orders = data?['orders'] as List<dynamic>?;
      final totalOrders = orders?.length ?? (maDon.isNotEmpty ? 1 : 0);
      
      // ✅ Clear affiliate tracking sau khi đặt hàng thành công
      if (affiliateId != null) {
        await _affiliateTracking.clearAffiliateTracking();
        print('✅ [Checkout] Đã clear affiliate tracking sau khi đặt hàng');
      }
      
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

// ✅ Delegate class cho sticky address header
class _StickyAddressHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyAddressHeaderDelegate({required this.child});

  @override
  double get minExtent => 52.0; // Chiều cao tối thiểu (compact mode)

  @override
  double get maxExtent => 60.0; // Chiều cao tối đa (full mode: đủ cho 1 dòng tên + 1 dòng địa chỉ)

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // ✅ Đảm bảo layoutExtent = paintExtent để tránh lỗi geometry
    final currentExtent = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    // ✅ Giảm padding đáng kể
    final progress = shrinkOffset / (maxExtent - minExtent);
    final verticalPadding = progress > 0.5 ? 4.0 : 6.0;
    
    return SizedBox(
      height: currentExtent,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
        color: Colors.white,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyAddressHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}