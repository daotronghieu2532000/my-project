import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../../core/services/shipping_events.dart';
import '../../../core/services/shipping_quote_store.dart';
import '../../../core/services/shipping_quote_service.dart';
import '../../../core/services/voucher_service.dart';
import '../../../core/utils/format_utils.dart';

class OrderSummarySection extends StatefulWidget {
  const OrderSummarySection({super.key});

  @override
  State<OrderSummarySection> createState() => _OrderSummarySectionState();
}

class _OrderSummarySectionState extends State<OrderSummarySection> {
  final _auth = AuthService();
  final _api = ApiService();
  final _shippingQuoteService = ShippingQuoteService(); // ✅ Sử dụng service chuyên nghiệp
  bool _isLoading = false; // ✅ Trạng thái đang load phí ship
  int? _shipFee;
  int? _originalShipFee; // Phí ship gốc
  int? _shipSupport; // Hỗ trợ ship
  String? _etaText;
  String? _provider;
  bool _hasFreeshipAvailable = false;
  bool _isFallback = false; // ✅ Đánh dấu đang dùng fallback
  List<Map<String, dynamic>>? _warehouseDetails; // Chi tiết phí ship từng kho
  Map<String, dynamic>? _shopFreeshipDetails; // Chi tiết freeship theo shop
  Map<int, int> _shopShipSupportMap = {}; // Map shop_id => ship_support (để lưu vào store)
  StreamSubscription<void>? _shipSub;
  final VoucherService _voucherService = VoucherService();

  @override
  void initState() {
    super.initState();
    _load();
    // ✅ Lắng nghe sự kiện cần tính lại phí ship khi đổi địa chỉ
    _shipSub = ShippingEvents.stream.listen((_) {
      if (!mounted) return;
      _load();
    });
    // ✅ Lắng nghe thay đổi voucher để cập nhật UI
    _voucherService.addListener(_onVoucherChanged);
  }

  @override
  void dispose() {
    _shipSub?.cancel();
    _loadDebounceTimer?.cancel(); // ✅ Hủy timer khi dispose
    _voucherService.removeListener(_onVoucherChanged); // ✅ Remove listener
    super.dispose();
  }
  
  // ✅ Callback khi voucher thay đổi
  void _onVoucherChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild để cập nhật UI
      });
    }
  }

  Timer? _loadDebounceTimer; // ✅ Debounce để tránh gọi API quá nhiều lần

  Future<void> _load() async {
    // ✅ Debounce: Hủy timer cũ nếu có, tạo timer mới
    _loadDebounceTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    _loadDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _loadShippingQuote();
    });
  }

  Future<void> _loadShippingQuote() async {
  
    final u = await _auth.getCurrentUser();
    
    // ✅ DEBUG: Lấy và print địa chỉ mặc định
    if (u != null) {
      try {
        final profile = await _api.getUserProfile(userId: u.userId);
        final addr = (profile?['addresses'] as List?)?.cast<Map<String, dynamic>?>().firstWhere(
                (a) => (a?['active'] == 1 || a?['active'] == '1'),
                orElse: () => null) ??
            (profile?['addresses'] as List?)?.cast<Map<String, dynamic>?>().firstOrNull;
     
      } catch (e) {
        // print('❌ [OrderSummarySection._loadShippingQuote] Lỗi khi lấy địa chỉ: $e');
      }
    }
    
    // Chuẩn bị danh sách items trong giỏ với giá thực tế
    final cart = cart_service.CartService();
    final items = cart.items
        .where((i) => i.isSelected) // ✅ Chỉ lấy items đã chọn
        .map((i) => {
              'product_id': i.id,
              'quantity': i.quantity,
              'price': i.originalPrice ?? i.price, // ✅ Dùng originalPrice (giá gốc) để tính toán đúng
            })
        .toList();
    
    
    // ✅ Nếu chưa đăng nhập, hiển thị thông báo yêu cầu đăng nhập
    if (u == null) {
      if (!mounted) return;
      setState(() {
        _shipFee = null;
        _originalShipFee = null;
        _shipSupport = null;
        _etaText = null;
        _provider = null;
        _warehouseDetails = null;
        _isLoading = false;
      });
      return;
    }
    
    // ✅ Nếu không có items được chọn, không tính ship
    if (items.isEmpty) {
      if (!mounted) return;
      setState(() {
        _shipFee = 0;
        _originalShipFee = 0;
        _shipSupport = 0;
        _etaText = null;
        _provider = null;
        _warehouseDetails = null;
        _shopShipSupportMap = {}; // Reset shop ship support map
        _isLoading = false;
      });
      return;
    }

    // ✅ Kiểm tra xem có phải chỉ có shop 0 không (dựa trên cart items)
    final cartItems = cart.items.where((i) => i.isSelected).toList();
    final hasOnlyShop0 = cartItems.isNotEmpty && 
      cartItems.every((item) => item.shopId == 0);
  
    // ✅ Sử dụng ShippingQuoteService với retry, timeout, fallback, và cache
    //  - Ở checkout: tăng timeout lên 15s cho shop 0, retry 2 lần
    Map<String, dynamic>? rawQuote;
    try {
      // print('🚀 [OrderSummarySection] Requesting shipping quote: items=${items.length}, hasOnlyShop0=$hasOnlyShop0');
      rawQuote = await _shippingQuoteService.getShippingQuote(
      userId: u.userId,
      items: items,
        useCache: !hasOnlyShop0, // ✅ Không dùng cache cho shop 0 để tránh cache cũ
      enableFallback: true,
        maxRetries: 1, // ✅ Giảm retry xuống 1 để nhanh hơn
        timeout: const Duration(seconds: 6), // ✅ Giảm timeout xuống 6s để fallback sớm hơn
      );
    } catch (e) {
      // print('❌ [OrderSummarySection] Lỗi khi lấy shipping quote: $e');
      // ✅ Nếu có lỗi, dùng fallback hoặc giá trị mặc định
      rawQuote = null;
    }

    if (!mounted) return;
    
    // ✅ Xử lý khi rawQuote là null (timeout hoặc lỗi)
    if (rawQuote == null) {
      // print('⚠️ [OrderSummarySection] rawQuote is null - using fallback values');
    if (!mounted) return;
    setState(() {
        _isLoading = false;
        _isFallback = true;
        _shipFee = 0;
        _originalShipFee = 0;
        _shipSupport = 0;
        _etaText = 'dự kiến: Đang tính...';
        _provider = null;
        _warehouseDetails = null;
        _shopFreeshipDetails = null;
      });
      return;
    }
    
    // ✅ Debug: Log response để kiểm tra
    // print('✅ [OrderSummarySection] Received shipping quote: success=${rawQuote['success']}, fee=${rawQuote['fee']}, provider=${rawQuote['provider']}');
    // print('   - best: ${rawQuote['best']}');
    // print('   - data: ${rawQuote['data']}');
    
    setState(() {
      try {
        // ✅ Đảm bảo _isLoading luôn được set về false
        _isLoading = false;
      // ✅ Kiểm tra xem có phải fallback không
      _isFallback = rawQuote?['is_fallback'] == true;
      // Robust parse of dynamic 'fee' (can be int/num/string)
      final dynamic feeDyn = rawQuote?['fee'];
      int? parsedFee;
      if (feeDyn is int) {
        parsedFee = feeDyn;
      } else if (feeDyn is num) {
        parsedFee = feeDyn.toInt();
      } else if (feeDyn is String) {
        // Remove non-digits just in case server returns formatted string
        final onlyDigits = feeDyn.replaceAll(RegExp(r'[^0-9]'), '');
        parsedFee = int.tryParse(onlyDigits);
      }
      _shipFee = parsedFee ?? 0;
      _etaText = rawQuote?['eta_text']?.toString();
      _provider = rawQuote?['provider']?.toString();
      
      // Lấy phí ship gốc và hỗ trợ ship từ API response
        // ✅ Parse an toàn để tránh lỗi type cast
        final originalFeeDyn = rawQuote?['fee'];
        if (originalFeeDyn is int) {
          _originalShipFee = originalFeeDyn;
        } else if (originalFeeDyn is num) {
          _originalShipFee = originalFeeDyn.toInt();
        } else if (originalFeeDyn is String) {
          final onlyDigits = originalFeeDyn.replaceAll(RegExp(r'[^0-9]'), '');
          _originalShipFee = int.tryParse(onlyDigits) ?? parsedFee ?? 0;
        } else {
          _originalShipFee = parsedFee ?? 0;
        }
        
        // ✅ Đảm bảo _originalShipFee và _shipFee luôn có giá trị
        if (_originalShipFee == null || _originalShipFee! <= 0) {
          _originalShipFee = parsedFee ?? 0;
        }
        if (_shipFee == null || _shipFee! <= 0) {
          _shipFee = _originalShipFee ?? 0;
        }
        
        // ✅ Lấy chi tiết phí ship từng kho (ưu tiên từ best, sau đó warehouse_shipping)
        List<dynamic>? warehouseDetailsList;
        
        // Thử lấy từ best['warehouse_details'] trước
        final best = rawQuote?['best'];
        if (best is Map<String, dynamic>) {
          final warehouseDetails = best['warehouse_details'];
          if (warehouseDetails is List) {
            warehouseDetailsList = warehouseDetails;
          }
        }
        
        // Nếu không có, thử lấy từ warehouse_shipping
        if (warehouseDetailsList == null || warehouseDetailsList.isEmpty) {
          final data = rawQuote?['data'];
          if (data is Map<String, dynamic>) {
            final warehouseShipping = data['warehouse_shipping'];
            if (warehouseShipping is Map<String, dynamic>) {
              final warehouseDetails = warehouseShipping['warehouse_details'];
              if (warehouseDetails is List) {
                warehouseDetailsList = warehouseDetails;
              }
            }
          }
        }
        
        // Nếu vẫn không có, thử lấy từ quotes[0]
        if (warehouseDetailsList == null || warehouseDetailsList.isEmpty) {
          final quotes = rawQuote?['quotes'];
          if (quotes is List && quotes.isNotEmpty) {
            final firstQuote = quotes[0];
            if (firstQuote is Map<String, dynamic>) {
              final warehouseDetails = firstQuote['warehouse_details'];
              if (warehouseDetails is List) {
                warehouseDetailsList = warehouseDetails;
              }
            }
          }
        }
        
        if (warehouseDetailsList != null && warehouseDetailsList.isNotEmpty) {
          _warehouseDetails = List<Map<String, dynamic>>.from(
            warehouseDetailsList.map((e) => e as Map<String, dynamic>)
          );
        } else {
          _warehouseDetails = null;
        }
        
        // ✅ Tính ship_support đúng: theo shop (mỗi shop chỉ tính một lần)
        // Tránh lỗi tính ship_support theo sản phẩm (20.000 x 3 = 60.000)
        // Đúng: ship_support = 20.000/tổng đơn hàng shop (không nhân với số lượng sản phẩm)
        int calculatedShipSupport = 0;
        int bestShipSupport = 0;
        final bestObj = rawQuote?['best'];
        if (bestObj is Map<String, dynamic>) {
          final shipSupport = bestObj['ship_support'];
          if (shipSupport is num) {
            bestShipSupport = shipSupport.toInt();
          }
        }
        
        // ✅ Tính ship_support từ shop_freeship_details (nếu có)
        // shop_freeship_details chứa thông tin ship_support theo shop
        Map<String, dynamic>? shopFreeshipDetails;
        final debug = rawQuote?['debug'];
        if (debug is Map<String, dynamic>) {
          final shopFreeship = debug['shop_freeship_details'];
          if (shopFreeship is Map<String, dynamic>) {
            shopFreeshipDetails = shopFreeship;
          }
        }
        
        // ✅ Lưu shop_freeship_details để hiển thị
        _shopFreeshipDetails = shopFreeshipDetails;
        
        // ✅ Tạo map shop_id -> shipping_fee từ warehouse_details (cần cho mode 1, 2)
        final Map<int, int> shopShippingFees = {};
        if (_warehouseDetails != null && _warehouseDetails!.isNotEmpty) {
          for (final detailMap in _warehouseDetails!) {
            final shopId = int.tryParse('${detailMap['shop_id'] ?? 0}') ?? 0;
            final shippingFee = (detailMap['shipping_fee'] as num?)?.toInt() ?? 0;
            if (shippingFee > 0) {
              // Lấy shipping_fee lớn nhất cho mỗi shop (nếu có nhiều warehouse)
              if (!shopShippingFees.containsKey(shopId) || shippingFee > shopShippingFees[shopId]!) {
                shopShippingFees[shopId] = shippingFee;
              }
            }
          }
        }
        
        if (shopFreeshipDetails != null && shopFreeshipDetails.isNotEmpty) {
          final Map<int, int> shopShipSupport = {};
          
          for (final entry in shopFreeshipDetails.entries) {
            final shopIdStr = entry.key;
            final shopId = int.tryParse(shopIdStr) ?? 0;
            final config = entry.value;
            
            if (config is Map<String, dynamic>) {
              final mode = config['mode'] as int? ?? 0;
              final applied = config['applied'] as bool? ?? false;
              
              // Mode 3: Per-product freeship - ship_support theo sản phẩm
              // Nhưng cần tính theo shop (không nhân với số lượng)
              if (mode == 3 && applied == true) {
                final products = config['products'];
                int shopSupport = 0;
                
                if (products is Map<String, dynamic> && products.isNotEmpty) {
                  // Lấy ship_support lớn nhất từ các sản phẩm (vì ship_support là theo shop, không phải theo sản phẩm)
                  for (final productEntry in products.entries) {
                    if (productEntry.value is Map<String, dynamic>) {
                      final productConfig = productEntry.value as Map<String, dynamic>;
                      final supportAmount = (productConfig['value'] as num?)?.toInt() ?? 0;
                      if (supportAmount > shopSupport) {
                        shopSupport = supportAmount;
                      }
                    }
                  }
                } else if (products is List && products.isNotEmpty) {
                  for (final productItem in products) {
                    if (productItem is Map<String, dynamic>) {
                      final supportAmount = (productItem['value'] as num?)?.toInt() ?? 0;
                      if (supportAmount > shopSupport) {
                        shopSupport = supportAmount;
                      }
                    }
                  }
                }
                
                if (shopSupport > 0) {
                  shopShipSupport[shopId] = shopSupport;
                }
              } else if ((mode == 0 || mode == 1 || mode == 2) && applied == true) {
                // Mode 0, 1, 2: ship_support theo shop (không phải theo sản phẩm)
                final discount = (config['discount'] as num?)?.toDouble() ?? 0.0;
                if (mode == 0 && discount > 0) {
                  // Mode 0: Fixed discount
                  shopShipSupport[shopId] = discount.toInt();
                } else if (mode == 1) {
                  // Mode 1: 100% freeship - ship_support = toàn bộ shipping_fee
                  final shippingFee = shopShippingFees[shopId] ?? 0;
                  if (shippingFee > 0) {
                    shopShipSupport[shopId] = shippingFee;
                  }
                } else if (mode == 2 && discount > 0) {
                  // Mode 2: Percentage discount - ship_support = discount% của giá trị đơn hàng shop (subtotal)
                  final subtotal = (config['subtotal'] as num?)?.toInt() ?? 0;
                  if (subtotal > 0) {
                    // ✅ Tính ship_support = discount% của subtotal (giá trị đơn hàng shop)
                    final support = (subtotal * discount / 100).round();
                    shopShipSupport[shopId] = support;
                  }
                }
              }
            }
          }
          
          // ✅ Tổng hợp ship_support từ tất cả các shop
          calculatedShipSupport = shopShipSupport.values.fold(0, (sum, support) => sum + support);
          // ✅ Lưu shop ship support map vào biến instance để truyền vào store
          _shopShipSupportMap = shopShipSupport;
        }
        
        // ✅ Fallback: Thử tính từ warehouse_details nếu shop_freeship_details không có
        if (calculatedShipSupport == 0 && _warehouseDetails != null && _warehouseDetails!.isNotEmpty) {
          final Map<int, int> shopShipSupport = {};
          
          for (final detailMap in _warehouseDetails!) {
            final shopId = int.tryParse('${detailMap['shop_id'] ?? 0}') ?? 0;
            final shipSupport = (detailMap['ship_support'] as num?)?.toInt() ?? 0;
            
            if (shipSupport > 0) {
              if (!shopShipSupport.containsKey(shopId) || shipSupport > shopShipSupport[shopId]!) {
                shopShipSupport[shopId] = shipSupport;
              }
            }
          }
          
          calculatedShipSupport = shopShipSupport.values.fold(0, (sum, support) => sum + support);
          // ✅ Lưu shop ship support map vào biến instance để truyền vào store
          _shopShipSupportMap = shopShipSupport;
        }
        
        // ✅ Ưu tiên dùng ship_support tính từ shop_freeship_details hoặc warehouse_details (đúng)
        // Fallback về best['ship_support'] nếu không có
        // ⚠️ Nếu best['ship_support'] khác với calculated, có thể API đang tính sai
        if (calculatedShipSupport > 0 && calculatedShipSupport != bestShipSupport) {
          _shipSupport = calculatedShipSupport;
        } else {
          _shipSupport = calculatedShipSupport > 0 ? calculatedShipSupport : bestShipSupport;
        }
      
      // Check if there's freeship available using raw API response
      _checkFreeshipAvailability(rawQuote);
      
        // ✅ Đảm bảo các giá trị không null trước khi lưu vào store
        final finalShipFee = _shipFee ?? _originalShipFee ?? 0;
        final finalOriginalShipFee = _originalShipFee ?? finalShipFee;
        
        // ✅ Debug log để kiểm tra giá trị
        // print('💰 [OrderSummarySection] Final values: shipFee=$finalShipFee, originalShipFee=$finalOriginalShipFee, shipSupport=${_shipSupport ?? 0}');
    
      // Lưu vào store dùng chung cho các section khác (PaymentDetails, Bottom bar)
      ShippingQuoteStore().setQuote(
          fee: finalShipFee,
        etaText: _etaText,
        provider: _provider,
        shipSupport: _shipSupport ?? 0,
        shopShipSupport: _shopShipSupportMap,
      );
        
        // ✅ Đảm bảo _originalShipFee được set đúng
        _originalShipFee = finalOriginalShipFee;
        _shipFee = finalShipFee;
      } catch (e) {
        // ✅ Nếu có lỗi trong quá trình parse, dùng giá trị mặc định
        // print('❌ [OrderSummarySection] Lỗi khi parse shipping quote: $e');
        _shipFee = _shipFee ?? 0;
        _originalShipFee = _originalShipFee ?? 0;
        _shipSupport = _shipSupport ?? 0;
        _etaText = _etaText ?? 'dự kiến: Đang tính...';
        _provider = _provider;
      } finally {
        // ✅ Đảm bảo _isLoading luôn được set về false
        _isLoading = false;
      }
    });
  }

  void _checkFreeshipAvailability(Map<String, dynamic>? quote) {
    try {
      _hasFreeshipAvailable = false;
      
      if (quote != null) {
        // Debug info is directly in quote['debug'] (not in quote['data']['debug'])
        final debug = quote['debug'];
        
        if (debug != null) {
          final shopFreeshipDetails = debug['shop_freeship_details'] as Map<String, dynamic>?;
          if (shopFreeshipDetails != null && shopFreeshipDetails.isNotEmpty) {
            // Check if any shop has freeship config (regardless of applied status)
            for (final entry in shopFreeshipDetails.entries) {
              // ✅ Xử lý an toàn: entry.value có thể là Map hoặc List
              final value = entry.value;
              if (value is! Map<String, dynamic>) {
                continue;
              }
              
              final config = value;
              final mode = config['mode'] as int? ?? 0;
              final discount = (config['discount'] as num?)?.toDouble() ?? 0.0;
              
              // Check freeship config based on mode
              bool hasValidFreeship = false;
              
              if (mode == 0 && discount > 0) {
                // Mode 0: Fixed discount
                hasValidFreeship = true;
              } else if (mode == 1) {
                // Mode 1: 100% freeship
                hasValidFreeship = true;
              } else if (mode == 2 && discount > 0) {
                // Mode 2: Percentage discount
                hasValidFreeship = true;
              } else if (mode == 3) {
                // Mode 3: Per-product freeship - check if any products have ship support
                final products = config['products'];
                if (products != null) {
                  // ✅ Xử lý cả trường hợp products là Map hoặc List
                  if (products is Map<String, dynamic> && products.isNotEmpty) {
                  for (final productEntry in products.entries) {
                      if (productEntry.value is Map<String, dynamic>) {
                    final productConfig = productEntry.value as Map<String, dynamic>;
                    final supportAmount = productConfig['value'] as int? ?? 0;
                    if (supportAmount > 0) {
                      hasValidFreeship = true;
                      break;
                        }
                      }
                    }
                  } else if (products is List && products.isNotEmpty) {
                    // Nếu products là List, kiểm tra từng item
                    for (final productItem in products) {
                      if (productItem is Map<String, dynamic>) {
                        final supportAmount = productItem['value'] as int? ?? 0;
                        if (supportAmount > 0) {
                          hasValidFreeship = true;
                          break;
                        }
                      }
                    }
                  }
                }
              }
              
              if (hasValidFreeship) {
                _hasFreeshipAvailable = true;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      _hasFreeshipAvailable = false;
    }
  }

  void _showFreeshipDialog(BuildContext context) async {
    // ✅ Sử dụng dữ liệu đã có từ _shopFreeshipDetails
    final cart = cart_service.CartService();
    final voucherService = VoucherService();
    final items = cart.items.where((i) => i.isSelected).toList();
    
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn sản phẩm để xem ưu đãi')),
      );
      return;
    }
    
    final itemsByShop = cart.itemsByShop;
    
    final platformVoucher = voucherService.platformVoucher;
    final hasShopVoucher = voucherService.appliedVouchers.isNotEmpty;
    final hasPlatformVoucher = platformVoucher != null;
    final hasFreeship = _shopFreeshipDetails != null && _shopFreeshipDetails!.isNotEmpty;
    
    // ✅ Chỉ hiển thị nếu có ít nhất một loại ưu đãi
    if (!hasShopVoucher && !hasPlatformVoucher && !hasFreeship) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiện tại chưa có ưu đãi nào được áp dụng')),
      );
      return;
    }
    
    final shopFreeshipDetails = _shopFreeshipDetails;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              // Header
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
                        Icons.local_shipping,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Chi tiết ưu đãi',
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
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      
                      // ✅ Hiển thị voucher shop theo từng shop - chỉ hiển thị shop có ưu đãi
                      for (final entry in itemsByShop.entries) ...[
                        Builder(
                          builder: (context) {
                            final shopId = entry.key;
                            
                            // ✅ Bỏ qua shop 0 (Sàn TMĐT) - không có voucher shop
                            if (shopId <= 0) {
                              return const SizedBox.shrink();
                            }
                            
                            final shopItems = entry.value.where((i) => i.isSelected).toList();
                            if (shopItems.isEmpty) return const SizedBox.shrink();
                            
                            final appliedVoucher = voucherService.getAppliedVoucher(shopId);
                            
                            // ✅ Kiểm tra hỗ trợ ship có giá trị không
                            bool hasValidShipSupport = false;
                            if (shopFreeshipDetails != null && shopFreeshipDetails.containsKey(shopId.toString())) {
                              final freeshipConfig = shopFreeshipDetails[shopId.toString()] as Map<String, dynamic>?;
                              if (freeshipConfig != null) {
                                final mode = freeshipConfig['mode'] as int? ?? 0;
                                final applied = freeshipConfig['applied'] as bool? ?? false;
                                final discount = (freeshipConfig['discount'] as num?)?.toDouble() ?? 0.0;
                                hasValidShipSupport = applied || (discount > 0 && mode >= 0 && mode <= 3);
                              }
                            }
                            
                            // ✅ Chỉ hiển thị shop nếu có voucher hoặc hỗ trợ ship hợp lệ
                            if (appliedVoucher != null || hasValidShipSupport) {
                              return Column(
                                children: [
                                  _buildShopPromotionSection(context, shopId, entry.value, voucherService, shopFreeshipDetails),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }
                            
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                      
                      // ✅ Hiển thị voucher sàn (nếu có)
                      if (platformVoucher != null) ...[
                        const Divider(height: 24),
                        _buildPlatformVoucherSection(context, platformVoucher, items, voucherService),
                        const SizedBox(height: 16),
                      ],
                      
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
                              Icons.tips_and_updates,
                              color: Color(0xFF28A745),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Thêm sản phẩm vào giỏ hàng để được hưởng ưu đãi vận chuyển tốt nhất.',
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

  // ✅ Widget hiển thị section ưu đãi của một shop trong dialog
  Widget _buildShopPromotionSection(
    BuildContext context,
    int shopId,
    List<cart_service.CartItem> shopItems,
    VoucherService voucherService,
    Map<String, dynamic>? shopFreeshipDetails,
  ) {
    // ✅ Bỏ qua shop 0 (Sàn TMĐT) - không có voucher shop
    if (shopId <= 0) {
      return const SizedBox.shrink();
    }
    
    final selectedShopItems = shopItems.where((i) => i.isSelected).toList();
    if (selectedShopItems.isEmpty) return const SizedBox.shrink();
    
    final shopName = selectedShopItems.first.shopName;
    // ✅ Tính tổng dựa trên originalPrice (giá gốc) để tính toán đúng trong checkout
    final shopTotal = selectedShopItems.fold(0, (sum, item) => sum + ((item.originalPrice ?? item.price) * item.quantity));
    final appliedVoucher = voucherService.getAppliedVoucher(shopId);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shop header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.store, color: Colors.blue, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                shopName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ),
            Text(
              FormatUtils.formatCurrency(shopTotal),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // ✅ Voucher shop (chỉ shop > 0)
        if (appliedVoucher != null) ...[
          _buildVoucherShopCardDialog(shopName, appliedVoucher, shopTotal),
          const SizedBox(height: 12),
        ],
        
        // ✅ Hỗ trợ ship - chỉ hiển thị khi có giá trị thực sự
        if (shopFreeshipDetails != null && shopFreeshipDetails.containsKey(shopId.toString())) ...[
          Builder(
            builder: (context) {
              final freeshipConfig = shopFreeshipDetails[shopId.toString()] as Map<String, dynamic>?;
              if (freeshipConfig != null) {
                // ✅ Kiểm tra xem có nên hiển thị không
                final mode = freeshipConfig['mode'] as int? ?? 0;
                final applied = freeshipConfig['applied'] as bool? ?? false;
                final discount = (freeshipConfig['discount'] as num?)?.toDouble() ?? 0.0;
                
                // ✅ Chỉ hiển thị nếu: applied = true HOẶC (discount > 0 và mode hợp lệ)
                final shouldShow = applied || (discount > 0 && mode >= 0 && mode <= 3);
                
                if (shouldShow) {
                  return Column(
                    children: [
                      _buildShipSupportCardDialog(shopName, shopId, freeshipConfig, shopTotal),
                      const SizedBox(height: 12),
                    ],
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ],
    );
  }
  
  // ✅ Widget hiển thị voucher sàn trong dialog
  Widget _buildPlatformVoucherSection(
    BuildContext context,
    dynamic platformVoucher,
    List<cart_service.CartItem> items,
    VoucherService voucherService,
  ) {
    // ✅ Tính tổng dựa trên originalPrice (giá gốc) để tính toán đúng trong checkout
    final totalGoods = items.fold(0, (s, i) => s + ((i.originalPrice ?? i.price) * i.quantity));
    return _buildPlatformVoucherCardDialog(platformVoucher, items, totalGoods);
  }
  
  // ✅ Widget hiển thị voucher shop trong dialog (chi tiết hơn)
  Widget _buildVoucherShopCardDialog(String shopName, dynamic voucher, int shopTotal) {
    final discountValue = voucher.discountValue ?? 0.0;
    final discountType = voucher.discountType ?? 'fixed';
    final maxDiscount = voucher.maxDiscountValue;
    final minOrder = voucher.minOrderValue?.round() ?? 0;
    
    String discountText = '';
    int calculatedDiscount = 0;
    
    if (discountType == 'percentage') {
      calculatedDiscount = (shopTotal * discountValue / 100).round();
      if (maxDiscount != null && calculatedDiscount > maxDiscount.round()) {
        calculatedDiscount = maxDiscount.round();
      }
      discountText = 'Giảm ${discountValue.toInt()}% (tối đa ${FormatUtils.formatCurrency(maxDiscount?.round() ?? calculatedDiscount)})';
    } else {
      calculatedDiscount = discountValue.round();
      discountText = 'Giảm ${FormatUtils.formatCurrency(calculatedDiscount)}';
    }
    
    final canApply = shopTotal >= minOrder;
    final statusColor = canApply ? Colors.green : Colors.orange;
    final statusText = canApply ? 'Đã áp dụng' : 'Chưa đủ điều kiện';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canApply ? Icons.check_circle : Icons.info_outline,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mã giảm giá shop',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã: ${voucher.code}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  discountText,
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Giá trị đơn hàng shop: ${FormatUtils.formatCurrency(shopTotal)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C757D),
                  ),
                ),
                if (canApply) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bạn đã tiết kiệm ${FormatUtils.formatCurrency(calculatedDiscount)}! 🎉',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    'Cần thêm ${FormatUtils.formatCurrency(minOrder - shopTotal)} để nhận ưu đãi 💝',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ Widget hiển thị hỗ trợ ship trong dialog (chi tiết hơn)
  Widget _buildShipSupportCardDialog(String shopName, int shopId, Map<String, dynamic> config, int shopTotal) {
    final mode = config['mode'] as int? ?? 0;
    final applied = config['applied'] as bool? ?? false;
    final subtotal = config['subtotal'] as int? ?? 0;
    final minOrder = config['min_order'] as int? ?? 0;
    final discount = (config['discount'] as num?)?.toDouble() ?? 0.0;
    
    String title = '';
    String description = '';
    int supportAmount = 0;
    final statusColor = applied ? Colors.green : Colors.orange;
    final statusText = applied ? 'Đã áp dụng' : 'Chưa đủ điều kiện';
    
    switch (mode) {
      case 0:
        title = 'Hỗ trợ ship cố định';
        description = 'Shop hỗ trợ ${FormatUtils.formatCurrency(discount.toInt())} phí ship';
        supportAmount = discount.toInt();
        break;
      case 1:
        title = 'Miễn phí ship 100%';
        description = 'Shop miễn phí toàn bộ phí ship';
        final shippingFee = _warehouseDetails?.firstWhere(
          (w) => (w['shop_id'] as int?) == shopId,
          orElse: () => {},
        )['shipping_fee'] as int? ?? 0;
        supportAmount = shippingFee;
        break;
      case 2:
        title = 'Hỗ trợ ship theo %';
        description = 'Shop hỗ trợ ${discount.toInt()}% giá trị đơn hàng';
        supportAmount = subtotal > 0 ? (subtotal * discount / 100).round() : 0;
        break;
      case 3:
        title = 'Hỗ trợ ship theo sản phẩm';
        final products = config['products'] as Map<String, dynamic>?;
        if (products != null && products.isNotEmpty) {
          int maxSupport = 0;
          for (final productEntry in products.entries) {
            final productConfig = productEntry.value as Map<String, dynamic>?;
            final value = (productConfig?['value'] as num?)?.toInt() ?? 0;
            if (value > maxSupport) maxSupport = value;
          }
          supportAmount = maxSupport;
          description = 'Shop hỗ trợ ${FormatUtils.formatCurrency(maxSupport)} ship cho sản phẩm này';
        } else {
          description = 'Shop có hỗ trợ ship cho sản phẩm đặc biệt';
        }
        break;
      default:
        title = 'Ưu đãi vận chuyển';
        description = 'Shop có ưu đãi vận chuyển đặc biệt';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                applied ? Icons.local_shipping : Icons.local_shipping_outlined,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Giá trị đơn hàng shop: ${FormatUtils.formatCurrency(subtotal)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C757D),
                  ),
                ),
                if (applied && supportAmount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bạn được hỗ trợ ${FormatUtils.formatCurrency(supportAmount)}! 🚚',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else if (!applied) ...[
                  if (minOrder > 0 && shopTotal < minOrder) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Thêm ${FormatUtils.formatCurrency(minOrder - shopTotal)} để nhận ưu đãi ship! 💝',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ Widget hiển thị voucher sàn trong dialog (chi tiết hơn)
  Widget _buildPlatformVoucherCardDialog(dynamic voucher, List<cart_service.CartItem> items, int totalGoods) {
    final discountValue = voucher.discountValue ?? 0.0;
    final discountType = voucher.discountType ?? 'fixed';
    final maxDiscount = voucher.maxDiscountValue;
    final minOrder = voucher.minOrderValue?.round() ?? 0;
    
    // ✅ Kiểm tra sản phẩm áp dụng
    final allowIds = <int>{};
    if (voucher.applicableProductsDetail != null && voucher.applicableProductsDetail!.isNotEmpty) {
      for (final m in voucher.applicableProductsDetail!) {
        final id = int.tryParse(m['id'] ?? '');
        if (id != null) allowIds.add(id);
      }
    } else if (voucher.applicableProducts != null && voucher.applicableProducts!.isNotEmpty) {
      for (final s in voucher.applicableProducts!) {
        final id = int.tryParse(s);
        if (id != null) allowIds.add(id);
      }
    }
    
    // ✅ Tính subtotal của sản phẩm áp dụng
    int applicableSubtotal = 0;
    if (allowIds.isNotEmpty) {
      for (final item in items) {
        if (allowIds.contains(item.id)) {
          // ✅ Dùng originalPrice (giá gốc) để tính toán đúng trong checkout
          applicableSubtotal += (item.originalPrice ?? item.price) * item.quantity;
        }
      }
    } else {
      applicableSubtotal = totalGoods;
    }
    
    String discountText = '';
    int calculatedDiscount = 0;
    
    if (discountType == 'percentage') {
      calculatedDiscount = (applicableSubtotal * discountValue / 100).round();
      if (maxDiscount != null && maxDiscount! > 0 && calculatedDiscount > maxDiscount!.round()) {
        calculatedDiscount = maxDiscount!.round();
      }
      // ✅ Chỉ hiển thị "tối đa" khi maxDiscount > 0
      final maxDiscountText = (maxDiscount != null && maxDiscount! > 0) 
          ? ' (tối đa ${FormatUtils.formatCurrency(maxDiscount!.round())})' 
          : '';
      if (allowIds.isNotEmpty) {
        discountText = 'Giảm ${discountValue.toInt()}% cho sản phẩm áp dụng$maxDiscountText';
      } else {
        discountText = 'Giảm ${discountValue.toInt()}% cho toàn bộ đơn hàng$maxDiscountText';
      }
    } else {
      calculatedDiscount = discountValue.round();
      discountText = 'Giảm ${FormatUtils.formatCurrency(calculatedDiscount)}';
    }
    
    final canApply = totalGoods >= minOrder && (allowIds.isEmpty || applicableSubtotal > 0);
    final statusColor = canApply ? Colors.green : Colors.orange;
    final statusText = canApply ? 'Đã áp dụng' : 'Chưa đủ điều kiện';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canApply ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mã giảm giá sàn TMĐT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã: ${voucher.code}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  discountText,
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
               
                if (allowIds.isNotEmpty && applicableSubtotal > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Áp dụng cho sản phẩm: ${FormatUtils.formatCurrency(applicableSubtotal)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C757D),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (canApply) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bạn đã tiết kiệm ${FormatUtils.formatCurrency(calculatedDiscount)}! 🎊',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  if (totalGoods < minOrder) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Thêm ${FormatUtils.formatCurrency(minOrder - totalGoods)} để nhận ưu đãi sàn! 💎',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else if (allowIds.isNotEmpty && applicableSubtotal == 0) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Voucher chỉ áp dụng cho sản phẩm đặc biệt. Hãy thêm sản phẩm phù hợp! 🛍️',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeshipInfo(String shopId, Map<String, dynamic> config) {
    final mode = config['mode'] as int? ?? 0;
    final subtotal = config['subtotal'] as int? ?? 0;
    final minOrder = config['min_order'] as int? ?? 0;
    final discount = (config['discount'] as num?)?.toDouble() ?? 0.0;
    final applied = config['applied'] as bool? ?? false;
    
    String title = '';
    String description = '';
    Color statusColor = Colors.grey;
    
    switch (mode) {
      case 0:
        title = 'Giảm phí ship cố định';
        description = 'Giảm ${_formatCurrency(discount.toInt())} phí ship';
        statusColor = applied ? Colors.green : Colors.orange;
        break;
      case 1:
        title = 'Miễn phí ship 100%';
        description = 'Miễn phí ship toàn bộ đơn hàng';
        statusColor = applied ? Colors.green : Colors.orange;
        break;
      case 2:
        title = 'Giảm phí ship theo %';
        description = 'Giảm ${discount.toInt()}% phí ship';
        statusColor = applied ? Colors.green : Colors.orange;
        break;
      case 3:
        title = 'Hỗ trợ ship theo sản phẩm';
        // Lấy thông tin ship support cụ thể từ config
        final products = config['products'] as Map<String, dynamic>?;
        if (products != null && products.isNotEmpty) {
          // Tính tổng ship support từ các sản phẩm
          int totalShipSupport = 0;
          for (final productEntry in products.entries) {
            final productConfig = productEntry.value as Map<String, dynamic>;
            final supportAmount = productConfig['value'] as int? ?? 0;
            totalShipSupport += supportAmount;
          }
          if (totalShipSupport > 0) {
            description = 'Hỗ trợ ship ${_formatCurrency(totalShipSupport)}';
          } else {
            description = 'Hỗ trợ ship cho sản phẩm cụ thể';
          }
        } else {
          description = 'Hỗ trợ ship cho sản phẩm cụ thể';
        }
        statusColor = applied ? Colors.green : Colors.orange;
        break;
      default:
        title = 'Ưu đãi vận chuyển';
        description = 'Có ưu đãi vận chuyển đặc biệt';
        statusColor = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                applied ? Icons.check_circle : Icons.info_outline,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  applied ? 'Đã áp dụng' : 'Chưa áp dụng',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6C757D),
            ),
          ),
          if (minOrder > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Đơn hàng tối thiểu: ${_formatCurrency(minOrder)}',
              style: TextStyle(
                fontSize: 13,
                color: subtotal >= minOrder ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          Text(
            'Giá trị đơn hàng hiện tại: ${_formatCurrency(subtotal)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }

  void _showInspectionDialog(BuildContext context) {
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
                        color: const Color(0xFF4A90E2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Color(0xFF4A90E2),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Quy định đồng kiểm hàng hóa',
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
                        '1. Quyền lợi của khách hàng',
                        '• Kiểm tra hàng hóa trước khi thanh toán\n• Được đổi/trả hàng nếu không đúng mô tả\n• Được hỗ trợ giải quyết tranh chấp\n• Đảm bảo chất lượng sản phẩm như cam kết',
                      ),
                      _buildSection(
                        '2. Quy trình đồng kiểm',
                        '• Nhận hàng từ nhân viên giao hàng\n• Kiểm tra bao bì, tem niêm phong\n• Mở hàng để kiểm tra sản phẩm\n• Xác nhận chất lượng và số lượng\n• Thanh toán hoặc từ chối nhận hàng',
                      ),
                      _buildSection(
                        '3. Lưu ý quan trọng',
                        '• Thời gian kiểm tra: tối đa 15 phút\n• Không được sử dụng sản phẩm\n• Giữ nguyên tem niêm phong khi kiểm tra\n• Thông báo ngay nếu phát hiện lỗi\n• Không làm hỏng bao bì sản phẩm',
                      ),
                      _buildSection(
                        '4. Trường hợp từ chối nhận hàng',
                        '• Sản phẩm không đúng mô tả\n• Bao bì bị hỏng, rách\n• Thiếu phụ kiện đi kèm\n• Sản phẩm bị lỗi, hỏng\n• Không đúng số lượng đặt hàng',
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
                              Icons.security,
                              color: Color(0xFF28A745),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Chúng tôi cam kết bảo vệ quyền lợi khách hàng và đảm bảo chất lượng dịch vụ tốt nhất.',
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
      child: Column(
        children: [
          // Hàng voucher shop đã ẩn vì hiển thị ngay trên header của từng shop
          const SizedBox(height: 12),
          Row(
            children: [
              Image.asset(
                'assets/images/icons/shipping_fee.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.where_to_vote_outlined, color: Color.fromARGB(255, 19, 129, 255), size: 24);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Hiển thị thông báo phù hợp khi chưa đăng nhập
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoading)
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Đang tính ...',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ],
                          )
                        else
                        Text(
                          _originalShipFee != null 
                            ? 'Phí vận chuyển: ${_formatCurrency(_originalShipFee!)}'
                            : 'Phí vận chuyển: Vui lòng đăng nhập!',
                          style: TextStyle(
                            color: _originalShipFee == null ? Colors.orange : null,
                          ),
                        ),
                        // ✅ Hiển thị cảnh báo khi đang dùng fallback
                        if (_isFallback)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Ước tính phí ship',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    
                    // ✅ Tạm thời comment lại - Hiển thị chi tiết phí ship từng kho với provider
                    // if (_warehouseDetails != null && _warehouseDetails!.isNotEmpty)
                    //   ...(_warehouseDetails!.map((warehouse) => Padding(
                    //     padding: const EdgeInsets.only(left: 8, top: 2),
                    //     child: Text(
                    //       '• ${warehouse['warehouse_location']}: ${_formatCurrency(warehouse['shipping_fee'])} (${warehouse['provider']})',
                    //       style: const TextStyle(
                    //         fontSize: 11,
                    //         color: Colors.grey,
                    //       ),
                    //     ),
                    //   )).toList()),
                    
                    if (_shipSupport != null && _shipSupport! > 0)
                      Text(
                        'Hỗ trợ vận chuyển: -${_formatCurrency(_shipSupport!)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (_shipFee != null && _shipFee! > 0 && _hasFreeshipAvailable)
                GestureDetector(
                  onTap: () => _showFreeshipDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      ' Ưu đãi! Xem ngay',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Image.asset(
                'assets/images/icons/du_kien.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.access_time, color: Color.fromARGB(255, 128, 128, 128), size: 24);
                },
              ),
              const SizedBox(width: 8),
              Text(
                _etaText != null 
                  ? 'Nhận hàng $_etaText'
                  : 'Dự kiến: Đang tính...',
                style: TextStyle(
                  color: _etaText == null ? Colors.orange : null,
                ),
              ),
            ],
          ),
          if (_provider != null) const SizedBox(height: 6),
          if (_provider != null)
            Row(
              children: [
                Image.asset(
                  'assets/images/icons/warehouse.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.local_shipping_outlined, color: Color.fromARGB(255, 112, 112, 112), size: 24);
                  },
                ),
                const SizedBox(width: 8),
                Text(_provider!),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF4A90E2)),
              const SizedBox(width: 8),
              const Text('Được đồng kiểm'),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showInspectionDialog(context),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4A90E2).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: Color(0xFF4A90E2),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // ✅ Đã chuyển hiển thị ưu đãi vào dialog "Ưu đãi! Xem ngay"
          // if (_shouldShowPromotionDetails())
          //   ..._buildPromotionDetails(),
        ],
      ),
    );
  }

  String _formatCurrency(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final p = s.length - i;
      b.write(s[i]);
      if (p > 1 && p % 3 == 1) b.write('.');
    }
    return '${b.toString()}₫';
  }
  
  // ✅ Kiểm tra xem có cần hiển thị chi tiết ưu đãi không
  bool _shouldShowPromotionDetails() {
    final cart = cart_service.CartService();
    final voucherService = VoucherService();
    final items = cart.items.where((i) => i.isSelected).toList();
    
    // Kiểm tra có voucher shop hoặc platform voucher
    final hasShopVoucher = voucherService.appliedVouchers.isNotEmpty;
    final hasPlatformVoucher = voucherService.platformVoucher != null;
    final hasFreeship = _shopFreeshipDetails != null && _shopFreeshipDetails!.isNotEmpty;
    
    return items.isNotEmpty && (hasShopVoucher || hasPlatformVoucher || hasFreeship);
  }
  
  // ✅ Hiển thị chi tiết ưu đãi theo shop
  List<Widget> _buildPromotionDetails() {
    final cart = cart_service.CartService();
    final voucherService = VoucherService();
    final items = cart.items.where((i) => i.isSelected).toList();
    final itemsByShop = cart.itemsByShop;
    
    if (items.isEmpty) return [];
    
    final List<Widget> widgets = [];
    
    widgets.add(const SizedBox(height: 16));
    widgets.add(const Divider(height: 1));
    widgets.add(const SizedBox(height: 16));
    
    // Header
    widgets.add(Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.local_offer, color: Colors.red, size: 18),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Ưu đãi đang áp dụng',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D1D1F),
            ),
          ),
        ),
      ],
    ));
    
    widgets.add(const SizedBox(height: 12));
    
    // ✅ Hiển thị voucher shop theo từng shop
    for (final entry in itemsByShop.entries) {
      final shopId = entry.key;
      
      // ✅ Bỏ qua shop 0 (Sàn TMĐT) - không có voucher shop
      if (shopId <= 0) {
        continue;
      }
      
      final shopItems = entry.value.where((i) => i.isSelected).toList();
      if (shopItems.isEmpty) continue;
      
      final shopName = shopItems.first.shopName;
      // ✅ Tính tổng dựa trên originalPrice (giá gốc) để tính toán đúng trong checkout
      final shopTotal = shopItems.fold(0, (sum, item) => sum + ((item.originalPrice ?? item.price) * item.quantity));
      final appliedVoucher = voucherService.getAppliedVoucher(shopId);
      
      if (appliedVoucher != null) {
        // ✅ Voucher shop đã áp dụng
        widgets.add(_buildVoucherShopCard(shopName, appliedVoucher, shopTotal, true));
        widgets.add(const SizedBox(height: 8));
      } else {
        // ✅ Không có voucher shop - có thể hiển thị thông báo mời chọn voucher
      }
      
      // ✅ Hỗ trợ ship của shop
      if (_shopFreeshipDetails != null && _shopFreeshipDetails!.containsKey(shopId.toString())) {
        final freeshipConfig = _shopFreeshipDetails![shopId.toString()] as Map<String, dynamic>?;
        if (freeshipConfig != null) {
          widgets.add(_buildShipSupportCard(shopName, shopId, freeshipConfig, shopTotal));
          widgets.add(const SizedBox(height: 8));
        }
      }
    }
    
    // ✅ Hiển thị voucher sàn (nếu có)
    final platformVoucher = voucherService.platformVoucher;
    if (platformVoucher != null) {
      final items = cart.items.where((i) => i.isSelected).toList();
      // ✅ Tính tổng dựa trên originalPrice (giá gốc) để tính toán đúng trong checkout
    final totalGoods = items.fold(0, (s, i) => s + ((i.originalPrice ?? i.price) * i.quantity));
      widgets.add(_buildPlatformVoucherCard(platformVoucher, items, totalGoods));
      widgets.add(const SizedBox(height: 8));
    }
    
    return widgets;
  }
  
  // ✅ Widget hiển thị voucher shop
  Widget _buildVoucherShopCard(String shopName, dynamic voucher, int shopTotal, bool isApplied) {
    final discountValue = voucher.discountValue ?? 0.0;
    final discountType = voucher.discountType ?? 'fixed';
    final maxDiscount = voucher.maxDiscountValue;
    
    String discountText = '';
    int calculatedDiscount = 0;
    
    if (discountType == 'percentage') {
      calculatedDiscount = (shopTotal * discountValue / 100).round();
      if (maxDiscount != null && calculatedDiscount > maxDiscount.round()) {
        calculatedDiscount = maxDiscount.round();
      }
      discountText = 'Giảm ${discountValue.toInt()}% (tối đa ${FormatUtils.formatCurrency(maxDiscount?.round() ?? calculatedDiscount)})';
    } else {
      calculatedDiscount = discountValue.round();
      discountText = 'Giảm ${FormatUtils.formatCurrency(calculatedDiscount)}';
    }
    
    final canApply = shopTotal >= (voucher.minOrderValue?.round() ?? 0);
    final statusColor = canApply ? Colors.green : Colors.orange;
    final statusText = canApply ? 'Đã áp dụng' : 'Chưa đủ điều kiện';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canApply ? Icons.check_circle : Icons.info_outline,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mã giảm giá $shopName',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã: ${voucher.code}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  discountText,
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (canApply) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bạn đã tiết kiệm ${FormatUtils.formatCurrency(calculatedDiscount)}! 🎉',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cần thêm ${FormatUtils.formatCurrency((voucher.minOrderValue?.round() ?? 0) - shopTotal)} để nhận ưu đãi 💝',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ Widget hiển thị hỗ trợ ship
  Widget _buildShipSupportCard(String shopName, int shopId, Map<String, dynamic> config, int shopTotal) {
    final mode = config['mode'] as int? ?? 0;
    final applied = config['applied'] as bool? ?? false;
    final subtotal = config['subtotal'] as int? ?? 0;
    final minOrder = config['min_order'] as int? ?? 0;
    final discount = (config['discount'] as num?)?.toDouble() ?? 0.0;
    
    String title = '';
    String description = '';
    int supportAmount = 0;
    final statusColor = applied ? Colors.green : Colors.orange;
    final statusText = applied ? 'Đã áp dụng' : 'Chưa đủ điều kiện';
    
    switch (mode) {
      case 0:
        title = 'Hỗ trợ ship cố định';
        description = 'Shop hỗ trợ ${FormatUtils.formatCurrency(discount.toInt())} phí ship cho đơn hàng';
        supportAmount = discount.toInt();
        break;
      case 1:
        title = 'Miễn phí ship 100%';
        description = 'Shop miễn phí toàn bộ phí ship cho đơn hàng của bạn';
        final shippingFee = _warehouseDetails?.firstWhere(
          (w) => (w['shop_id'] as int?) == shopId,
          orElse: () => {},
        )['shipping_fee'] as int? ?? 0;
        supportAmount = shippingFee;
        break;
      case 2:
        title = 'Hỗ trợ ship theo %';
        description = 'Shop hỗ trợ ${discount.toInt()}% giá trị đơn hàng làm phí ship';
        supportAmount = subtotal > 0 ? (subtotal * discount / 100).round() : 0;
        break;
      case 3:
        title = 'Hỗ trợ ship theo sản phẩm';
        final products = config['products'] as Map<String, dynamic>?;
        if (products != null && products.isNotEmpty) {
          // Lấy ship support lớn nhất (theo shop, không nhân số lượng)
          int maxSupport = 0;
          for (final productEntry in products.entries) {
            final productConfig = productEntry.value as Map<String, dynamic>?;
            final value = (productConfig?['value'] as num?)?.toInt() ?? 0;
            if (value > maxSupport) maxSupport = value;
          }
          supportAmount = maxSupport;
          description = 'Shop hỗ trợ ${FormatUtils.formatCurrency(maxSupport)} ship cho sản phẩm này';
        } else {
          description = 'Shop có hỗ trợ ship cho sản phẩm đặc biệt';
        }
        break;
      default:
        title = 'Ưu đãi vận chuyển';
        description = 'Shop có ưu đãi vận chuyển đặc biệt';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                applied ? Icons.local_shipping : Icons.local_shipping_outlined,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title - $shopName',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                  ),
                ),
                if (applied && supportAmount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bạn được hỗ trợ ${FormatUtils.formatCurrency(supportAmount)}! 🚚',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else if (!applied) ...[
                  if (minOrder > 0 && shopTotal < minOrder) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Thêm ${FormatUtils.formatCurrency(minOrder - shopTotal)} để nhận ưu đãi ship! 💝',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Đang kiểm tra điều kiện...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ Widget hiển thị voucher sàn
  Widget _buildPlatformVoucherCard(dynamic voucher, List<cart_service.CartItem> items, int totalGoods) {
    final discountValue = voucher.discountValue ?? 0.0;
    final discountType = voucher.discountType ?? 'fixed';
    final maxDiscount = voucher.maxDiscountValue;
    final minOrder = voucher.minOrderValue?.round() ?? 0;
    
    // ✅ Kiểm tra sản phẩm áp dụng
    final allowIds = <int>{};
    if (voucher.applicableProductsDetail != null && voucher.applicableProductsDetail!.isNotEmpty) {
      for (final m in voucher.applicableProductsDetail!) {
        final id = int.tryParse(m['id'] ?? '');
        if (id != null) allowIds.add(id);
      }
    } else if (voucher.applicableProducts != null && voucher.applicableProducts!.isNotEmpty) {
      for (final s in voucher.applicableProducts!) {
        final id = int.tryParse(s);
        if (id != null) allowIds.add(id);
      }
    }
    
    // ✅ Tính subtotal của sản phẩm áp dụng
    int applicableSubtotal = 0;
    if (allowIds.isNotEmpty) {
      for (final item in items) {
        if (allowIds.contains(item.id)) {
          // ✅ Dùng originalPrice (giá gốc) để tính toán đúng trong checkout
          applicableSubtotal += (item.originalPrice ?? item.price) * item.quantity;
        }
      }
    } else {
      applicableSubtotal = totalGoods; // Áp dụng cho tất cả
    }
    
    String discountText = '';
    int calculatedDiscount = 0;
    
    if (discountType == 'percentage') {
      calculatedDiscount = (applicableSubtotal * discountValue / 100).round();
      if (maxDiscount != null && maxDiscount! > 0 && calculatedDiscount > maxDiscount!.round()) {
        calculatedDiscount = maxDiscount!.round();
      }
      // ✅ Chỉ hiển thị "tối đa" khi maxDiscount > 0
      final maxDiscountText = (maxDiscount != null && maxDiscount! > 0) 
          ? ' (tối đa ${FormatUtils.formatCurrency(maxDiscount!.round())})' 
          : '';
      if (allowIds.isNotEmpty) {
        discountText = 'Giảm ${discountValue.toInt()}% cho sản phẩm áp dụng$maxDiscountText';
      } else {
        discountText = 'Giảm ${discountValue.toInt()}% cho toàn bộ đơn hàng$maxDiscountText';
      }
    } else {
      calculatedDiscount = discountValue.round();
      discountText = 'Giảm ${FormatUtils.formatCurrency(calculatedDiscount)}';
    }
    
    final canApply = totalGoods >= minOrder && (allowIds.isEmpty || applicableSubtotal > 0);
    final statusColor = canApply ? Colors.green : Colors.orange;
    final statusText = canApply ? 'Đã áp dụng' : 'Chưa đủ điều kiện';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canApply ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mã giảm giá sàn TMĐT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã: ${voucher.code}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  discountText,
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (allowIds.isNotEmpty && applicableSubtotal > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Áp dụng cho sản phẩm: ${FormatUtils.formatCurrency(applicableSubtotal)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C757D),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (canApply) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bạn đã tiết kiệm ${FormatUtils.formatCurrency(calculatedDiscount)}! 🎊',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  if (totalGoods < minOrder) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Thêm ${FormatUtils.formatCurrency(minOrder - totalGoods)} để nhận ưu đãi sàn! 💎',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else if (allowIds.isNotEmpty && applicableSubtotal == 0) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Voucher chỉ áp dụng cho sản phẩm đặc biệt. Hãy thêm sản phẩm phù hợp! 🛍️',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}