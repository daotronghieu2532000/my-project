import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cart_service.dart' as cart_service;
import '../../../core/services/shipping_events.dart';
import '../../../core/services/shipping_quote_store.dart';
import '../../../core/services/shipping_quote_service.dart';

class OrderSummarySection extends StatefulWidget {
  const OrderSummarySection({super.key});

  @override
  State<OrderSummarySection> createState() => _OrderSummarySectionState();
}

class _OrderSummarySectionState extends State<OrderSummarySection> {
  final _api = ApiService();
  final _auth = AuthService();
  final _shippingQuoteService = ShippingQuoteService(); // ✅ Sử dụng service chuyên nghiệp
  int? _shipFee;
  int? _originalShipFee; // Phí ship gốc
  int? _shipSupport; // Hỗ trợ ship
  String? _etaText;
  String? _provider;
  bool _hasFreeshipAvailable = false;
  bool _isFallback = false; // ✅ Đánh dấu đang dùng fallback
  List<Map<String, dynamic>>? _warehouseDetails; // Chi tiết phí ship từng kho
  StreamSubscription<void>? _shipSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Lắng nghe sự kiện cần tính lại phí ship khi đổi địa chỉ
    _shipSub = ShippingEvents.stream.listen((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _shipSub?.cancel();
    _loadDebounceTimer?.cancel(); // ✅ Hủy timer khi dispose
    super.dispose();
  }

  Timer? _loadDebounceTimer; // ✅ Debounce để tránh gọi API quá nhiều lần

  Future<void> _load() async {
    // ✅ Debounce: Hủy timer cũ nếu có, tạo timer mới
    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _loadShippingQuote();
    });
  }

  Future<void> _loadShippingQuote() async {
    final u = await _auth.getCurrentUser();
    
    // Chuẩn bị danh sách items trong giỏ với giá thực tế
    final cart = cart_service.CartService();
    final items = cart.items
        .where((i) => i.isSelected) // ✅ Chỉ lấy items đã chọn
        .map((i) => {
              'product_id': i.id,
              'quantity': i.quantity,
              'price': i.price, // ✅ Thêm giá để fallback tính chính xác hơn
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
      });
      return;
    }
  
    // ✅ Sử dụng ShippingQuoteService với retry, timeout, fallback, và cache
    final rawQuote = await _shippingQuoteService.getShippingQuote(
      userId: u.userId,
      items: items,
      useCache: true,
      enableFallback: true,
    );
    if (!mounted) return;
    setState(() {
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
        _originalShipFee = rawQuote?['fee'] as int? ?? 0; // Phí ship gốc
        
        // ✅ Lấy chi tiết phí ship từng kho (ưu tiên từ best, sau đó warehouse_shipping)
        List<dynamic>? warehouseDetailsList;
        
        // Thử lấy từ best['warehouse_details'] trước
        final best = rawQuote?['best'] as Map<String, dynamic>?;
        if (best != null) {
          warehouseDetailsList = best['warehouse_details'] as List<dynamic>?;
        }
        
        // Nếu không có, thử lấy từ warehouse_shipping
        if (warehouseDetailsList == null || warehouseDetailsList.isEmpty) {
          final warehouseShipping = rawQuote?['data']?['warehouse_shipping'] as Map<String, dynamic>?;
        if (warehouseShipping != null) {
            warehouseDetailsList = warehouseShipping['warehouse_details'] as List<dynamic>?;
          }
        }
        
        // Nếu vẫn không có, thử lấy từ quotes[0]
        if (warehouseDetailsList == null || warehouseDetailsList.isEmpty) {
          final quotes = rawQuote?['quotes'] as List<dynamic>?;
          if (quotes != null && quotes.isNotEmpty) {
            final firstQuote = quotes[0] as Map<String, dynamic>?;
            if (firstQuote != null) {
              warehouseDetailsList = firstQuote['warehouse_details'] as List<dynamic>?;
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
        final bestShipSupport = (rawQuote?['best']?['ship_support'] as num?)?.toInt() ?? 0;
        
        // 🔍 DEBUG: In ra thông tin để kiểm tra
        print('🔍 [SHIP_SUPPORT_DEBUG] ==========================================');
        print('🔍 [SHIP_SUPPORT_DEBUG] best[\'ship_support\'] từ API: $bestShipSupport');
        print('🔍 [SHIP_SUPPORT_DEBUG] Số lượng items trong giỏ: ${items.length}');
        print('🔍 [SHIP_SUPPORT_DEBUG] Items: ${items.map((i) => 'product_id=${i['product_id']}, qty=${i['quantity']}').join('; ')}');
        
        // ✅ Tính ship_support từ shop_freeship_details (nếu có)
        // shop_freeship_details chứa thông tin ship_support theo shop
        final debug = rawQuote?['debug'] as Map<String, dynamic>?;
        final shopFreeshipDetails = debug?['shop_freeship_details'] as Map<String, dynamic>?;
        
        print('🔍 [SHIP_SUPPORT_DEBUG] shop_freeship_details: $shopFreeshipDetails');
        print('🔍 [SHIP_SUPPORT_DEBUG] Số lượng shop trong shop_freeship_details: ${shopFreeshipDetails?.length ?? 0}');
        
        // ✅ Tạo map shop_id -> shipping_fee từ warehouse_details (cần cho mode 1, 2)
        final Map<int, int> shopShippingFees = {};
        if (_warehouseDetails != null && _warehouseDetails!.isNotEmpty) {
          print('🔍 [SHIP_SUPPORT_DEBUG] Tạo map shopShippingFees từ warehouse_details:');
          for (final detailMap in _warehouseDetails!) {
            final shopId = int.tryParse('${detailMap['shop_id'] ?? 0}') ?? 0;
            final shippingFee = (detailMap['shipping_fee'] as num?)?.toInt() ?? 0;
            if (shippingFee > 0) {
              // Lấy shipping_fee lớn nhất cho mỗi shop (nếu có nhiều warehouse)
              if (!shopShippingFees.containsKey(shopId) || shippingFee > shopShippingFees[shopId]!) {
                shopShippingFees[shopId] = shippingFee;
              }
              print('🔍 [SHIP_SUPPORT_DEBUG]   Shop $shopId: shipping_fee = $shippingFee');
            }
          }
          print('🔍 [SHIP_SUPPORT_DEBUG] shopShippingFees map: $shopShippingFees');
        }
        
        if (shopFreeshipDetails != null && shopFreeshipDetails.isNotEmpty) {
          final Map<int, int> shopShipSupport = {};
          
          print('🔍 [SHIP_SUPPORT_DEBUG] Bắt đầu tính ship_support từ shop_freeship_details:');
          
          for (final entry in shopFreeshipDetails.entries) {
            final shopIdStr = entry.key;
            final shopId = int.tryParse(shopIdStr) ?? 0;
            final config = entry.value;
            
            print('🔍 [SHIP_SUPPORT_DEBUG]   → Xử lý Shop ID: $shopId');
            print('🔍 [SHIP_SUPPORT_DEBUG]     Config: $config');
            
            if (config is Map<String, dynamic>) {
              final mode = config['mode'] as int? ?? 0;
              final applied = config['applied'] as bool? ?? false;
              
              print('🔍 [SHIP_SUPPORT_DEBUG]     Mode: $mode, Applied: $applied');
              
              // Mode 3: Per-product freeship - ship_support theo sản phẩm
              // Nhưng cần tính theo shop (không nhân với số lượng)
              if (mode == 3 && applied == true) {
                final products = config['products'];
                int shopSupport = 0;
                
                print('🔍 [SHIP_SUPPORT_DEBUG]     Mode 3: Xử lý products: $products');
                
                if (products is Map<String, dynamic> && products.isNotEmpty) {
                  // Lấy ship_support lớn nhất từ các sản phẩm (vì ship_support là theo shop, không phải theo sản phẩm)
                  for (final productEntry in products.entries) {
                    if (productEntry.value is Map<String, dynamic>) {
                      final productConfig = productEntry.value as Map<String, dynamic>;
                      final supportAmount = (productConfig['value'] as num?)?.toInt() ?? 0;
                      print('🔍 [SHIP_SUPPORT_DEBUG]       Product ${productEntry.key}: supportAmount = $supportAmount');
                      if (supportAmount > shopSupport) {
                        shopSupport = supportAmount;
                      }
                    }
                  }
                } else if (products is List && products.isNotEmpty) {
                  for (final productItem in products) {
                    if (productItem is Map<String, dynamic>) {
                      final supportAmount = (productItem['value'] as num?)?.toInt() ?? 0;
                      print('🔍 [SHIP_SUPPORT_DEBUG]       Product trong List: supportAmount = $supportAmount');
                      if (supportAmount > shopSupport) {
                        shopSupport = supportAmount;
                      }
                    }
                  }
                }
                
                print('🔍 [SHIP_SUPPORT_DEBUG]     Shop $shopId (mode 3): shopSupport = $shopSupport');
                
                if (shopSupport > 0) {
                  shopShipSupport[shopId] = shopSupport;
                  print('🔍 [SHIP_SUPPORT_DEBUG]     ✅ Đã thêm shopSupport = $shopSupport cho shop $shopId');
                }
              } else if ((mode == 0 || mode == 1 || mode == 2) && applied == true) {
                // Mode 0, 1, 2: ship_support theo shop (không phải theo sản phẩm)
                final discount = (config['discount'] as num?)?.toDouble() ?? 0.0;
                if (mode == 0 && discount > 0) {
                  // Mode 0: Fixed discount
                  shopShipSupport[shopId] = discount.toInt();
                  print('🔍 [SHIP_SUPPORT_DEBUG]     Shop $shopId (mode 0): shopSupport = ${discount.toInt()}');
                  print('🔍 [SHIP_SUPPORT_DEBUG]     ✅ Đã thêm shopSupport = ${discount.toInt()} cho shop $shopId');
                } else if (mode == 1) {
                  // Mode 1: 100% freeship - ship_support = toàn bộ shipping_fee
                  final shippingFee = shopShippingFees[shopId] ?? 0;
                  if (shippingFee > 0) {
                    shopShipSupport[shopId] = shippingFee;
                    print('🔍 [SHIP_SUPPORT_DEBUG]     Shop $shopId (mode 1): shipping_fee = $shippingFee, shopSupport = $shippingFee');
                    print('🔍 [SHIP_SUPPORT_DEBUG]     ✅ Đã thêm shopSupport = $shippingFee cho shop $shopId');
                  } else {
                    print('🔍 [SHIP_SUPPORT_DEBUG]     ⚠️ Shop $shopId (mode 1): Không có shipping_fee trong warehouse_details');
                  }
                } else if (mode == 2 && discount > 0) {
                  // Mode 2: Percentage discount - ship_support = discount% của giá trị đơn hàng shop (subtotal)
                  final subtotal = (config['subtotal'] as num?)?.toInt() ?? 0;
                  if (subtotal > 0) {
                    // ✅ Tính ship_support = discount% của subtotal (giá trị đơn hàng shop)
                    final support = (subtotal * discount / 100).round();
                    shopShipSupport[shopId] = support;
                    print('🔍 [SHIP_SUPPORT_DEBUG]     Shop $shopId (mode 2): subtotal = $subtotal, discount = ${discount.toInt()}%, shopSupport = $support');
                    print('🔍 [SHIP_SUPPORT_DEBUG]     ✅ Đã thêm shopSupport = $support cho shop $shopId');
                  } else {
                    print('🔍 [SHIP_SUPPORT_DEBUG]     ⚠️ Shop $shopId (mode 2): Không có subtotal trong config');
                  }
                }
              } else {
                print('🔍 [SHIP_SUPPORT_DEBUG]     ⚠️ Shop $shopId: Mode $mode, Applied: $applied - KHÔNG ÁP DỤNG');
              }
            }
          }
          
          print('🔍 [SHIP_SUPPORT_DEBUG] Kết quả shopShipSupport map: $shopShipSupport');
          print('🔍 [SHIP_SUPPORT_DEBUG] Số lượng shop có ship_support: ${shopShipSupport.length}');
          
          // ✅ Tổng hợp ship_support từ tất cả các shop
          calculatedShipSupport = shopShipSupport.values.fold(0, (sum, support) => sum + support);
          print('🔍 [SHIP_SUPPORT_DEBUG] Tổng ship_support tính từ shop_freeship_details: $calculatedShipSupport');
          
          // In chi tiết từng shop
          for (final entry in shopShipSupport.entries) {
            print('🔍 [SHIP_SUPPORT_DEBUG]   - Shop ${entry.key}: ${entry.value}');
          }
        } else {
          print('🔍 [SHIP_SUPPORT_DEBUG] Không có shop_freeship_details hoặc rỗng');
        }
        
        // ✅ Fallback: Thử tính từ warehouse_details nếu shop_freeship_details không có
        if (calculatedShipSupport == 0 && _warehouseDetails != null && _warehouseDetails!.isNotEmpty) {
          print('🔍 [SHIP_SUPPORT_DEBUG] Fallback: Tính từ warehouse_details');
          final Map<int, int> shopShipSupport = {};
          
          for (final detailMap in _warehouseDetails!) {
            final shopId = int.tryParse('${detailMap['shop_id'] ?? 0}') ?? 0;
            final shipSupport = (detailMap['ship_support'] as num?)?.toInt() ?? 0;
            
            print('🔍 [SHIP_SUPPORT_DEBUG]   warehouse_detail: shop_id=$shopId, ship_support=$shipSupport');
            
            if (shipSupport > 0) {
              if (!shopShipSupport.containsKey(shopId) || shipSupport > shopShipSupport[shopId]!) {
                shopShipSupport[shopId] = shipSupport;
              }
            }
          }
          
          print('🔍 [SHIP_SUPPORT_DEBUG] Kết quả shopShipSupport từ warehouse_details: $shopShipSupport');
          calculatedShipSupport = shopShipSupport.values.fold(0, (sum, support) => sum + support);
          print('🔍 [SHIP_SUPPORT_DEBUG] Tổng ship_support tính từ warehouse_details: $calculatedShipSupport');
        }
        
        // ✅ Ưu tiên dùng ship_support tính từ shop_freeship_details hoặc warehouse_details (đúng)
        // Fallback về best['ship_support'] nếu không có
        // ⚠️ Nếu best['ship_support'] khác với calculated, có thể API đang tính sai
        if (calculatedShipSupport > 0 && calculatedShipSupport != bestShipSupport) {
          print('🔍 [SHIP_SUPPORT_DEBUG] ⚠️ PHÁT HIỆN: best[\'ship_support\'] ($bestShipSupport) khác với calculated ($calculatedShipSupport)');
          print('🔍 [SHIP_SUPPORT_DEBUG] ⚠️ → Sử dụng calculated ($calculatedShipSupport) để tránh tính sai');
          _shipSupport = calculatedShipSupport;
        } else {
          _shipSupport = calculatedShipSupport > 0 ? calculatedShipSupport : bestShipSupport;
        }
        
        // 🔍 DEBUG: In ra kết quả cuối cùng
        print('🔍 [SHIP_SUPPORT_DEBUG] Kết quả cuối cùng:');
        print('🔍 [SHIP_SUPPORT_DEBUG]   - best[\'ship_support\']: $bestShipSupport');
        print('🔍 [SHIP_SUPPORT_DEBUG]   - calculatedShipSupport: $calculatedShipSupport');
        print('🔍 [SHIP_SUPPORT_DEBUG]   - _shipSupport (đã chọn): $_shipSupport');
        print('🔍 [SHIP_SUPPORT_DEBUG] ==========================================');
      
      // Check if there's freeship available using raw API response
      _checkFreeshipAvailability(rawQuote);
      
      // Sử dụng ship_support từ API (đã tính toán chính xác)
      // API trả về ship_support = 250.000₫ (2% của giá trị đơn hàng)
    
      // Lưu vào store dùng chung cho các section khác (PaymentDetails, Bottom bar)
      ShippingQuoteStore().setQuote(
        fee: _shipFee!,
        etaText: _etaText,
        provider: _provider,
        shipSupport: _shipSupport ?? 0,
      );
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
    // Sử dụng dữ liệu đã có từ _checkFreeshipAvailability thay vì gọi API lại
    if (!_hasFreeshipAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sản phẩm này không có ưu đãi vận chuyển')),
      );
      return;
    }
    
    // Lấy thông tin freeship từ shipping quote
    final u = await _auth.getCurrentUser();
    if (u == null) return;
    
    final cart = cart_service.CartService();
    final items = cart.items
        .map((i) => {
              'product_id': i.id,
              'quantity': i.quantity,
            })
        .toList();
    
    if (items.isEmpty) return;
    
    Map<String, dynamic>? shopFreeshipDetails;
    
    try {
      final quote = await _api.getShippingQuote(userId: u.userId, items: items);
      
      if (quote != null) {
        final debug = quote['debug'];
        
        if (debug != null) {
          shopFreeshipDetails = debug['shop_freeship_details'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      // Error getting quote
    }
    
    // Only show dialog if there's actual freeship data
    if (shopFreeshipDetails == null || shopFreeshipDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sản phẩm này không có ưu đãi vận chuyển')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            minHeight: 300,
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
                        'Ưu đãi vận chuyển',
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
                      // Debug info
                    
                      const SizedBox(height: 16),
                      
                      if (shopFreeshipDetails != null && shopFreeshipDetails.isNotEmpty) ...[
                    
                        for (final entry in shopFreeshipDetails.entries) ...[
                          _buildFreeshipInfo(entry.key, entry.value),
                          const SizedBox(height: 16),
                        ],
                      ] else ...[
                        Text('❌ No freeship details found', 
                             style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 16),
                        const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Hiện tại chưa có ưu đãi vận chuyển nào',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
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
              const Icon(Icons.mobile_friendly_rounded, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Hiển thị thông báo phù hợp khi chưa đăng nhập
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _originalShipFee != null 
                            ? 'Phí vận chuyển: ${_formatCurrency(_originalShipFee!)}'
                            : 'Phí vận chuyển: Vui lòng đăng nhập để tính phí ship',
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
                                  'Đang sử dụng phí ship ước tính',
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
                        'Hỗ trợ ship: -${_formatCurrency(_shipSupport!)}',
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
              const Icon(Icons.access_time, color: Color.fromARGB(255, 255, 47, 47)),
              const SizedBox(width: 8),
              Text(
                _etaText != null 
                  ? 'Nhận hàng $_etaText'
                  : 'Dự kiến: Vui lòng đăng nhập để tính thời gian',
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
                const Icon(Icons.local_shipping_outlined, color: Color.fromARGB(255, 5, 87, 2)),
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
}