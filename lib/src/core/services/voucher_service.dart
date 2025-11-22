import 'package:flutter/foundation.dart';
import '../models/voucher.dart';
import 'api_service.dart';

class VoucherService extends ChangeNotifier {
  static final VoucherService _instance = VoucherService._internal();
  factory VoucherService() => _instance;
  VoucherService._internal();

  // Voucher đã chọn cho từng shop
  final Map<int, Voucher> _selectedVouchers = {};
  
  // Voucher đã áp dụng (đã confirm)
  final Map<int, Voucher> _appliedVouchers = {};

  // Voucher sàn hiện tại
  Voucher? _platformVoucher;

  Map<int, Voucher> get selectedVouchers => Map.unmodifiable(_selectedVouchers);
  Map<int, Voucher> get appliedVouchers => Map.unmodifiable(_appliedVouchers);
  Voucher? get platformVoucher => _platformVoucher;

  /// Chọn voucher cho shop
  void selectVoucher(int shopId, Voucher voucher) {
    _selectedVouchers[shopId] = voucher;
    notifyListeners();
  }

  /// Bỏ chọn voucher cho shop
  void removeVoucher(int shopId) {
    _selectedVouchers.remove(shopId);
    notifyListeners();
  }

  /// Áp dụng voucher (confirm)
  void applyVoucher(int shopId, Voucher voucher) {
    _appliedVouchers[shopId] = voucher;
    _selectedVouchers.remove(shopId); // Xóa khỏi selected sau khi apply
    notifyListeners();
  }

  /// Hủy áp dụng voucher
  void cancelVoucher(int shopId) {
    _appliedVouchers.remove(shopId);
    notifyListeners();
  }

  /// Chọn/áp dụng voucher sàn
  void setPlatformVoucher(Voucher? voucher) {
    _platformVoucher = voucher;
    notifyListeners();
  }

  /// Lấy voucher đã áp dụng cho shop
  Voucher? getAppliedVoucher(int shopId) {
    return _appliedVouchers[shopId];
  }

  /// Lấy voucher đã chọn cho shop
  Voucher? getSelectedVoucher(int shopId) {
    return _selectedVouchers[shopId];
  }

  /// Kiểm tra shop có voucher đã áp dụng không
  bool hasAppliedVoucher(int shopId) {
    return _appliedVouchers.containsKey(shopId);
  }

  /// Kiểm tra shop có voucher đã chọn không
  bool hasSelectedVoucher(int shopId) {
    return _selectedVouchers.containsKey(shopId);
  }

  /// Tính tổng tiền giảm giá từ các voucher shop đã áp dụng (không gồm voucher sàn)
  /// - totalPrice: tổng tiền hàng tất cả shop (để backward compatibility)
  /// - items: danh sách items với shopId và giá (để tính subtotal theo shop) - format: [{'shopId': int, 'price': int, 'quantity': int}]
  int calculateTotalDiscount(int totalPrice, {List<Map<String, dynamic>>? items}) {
    // 🔍 DEBUG: In ra thông tin để kiểm tra
    print('🔍 [VOUCHER_DEBUG] ==========================================');
    print('🔍 [VOUCHER_DEBUG] calculateTotalDiscount - totalPrice: $totalPrice');
    print('🔍 [VOUCHER_DEBUG] items: $items');
    print('🔍 [VOUCHER_DEBUG] Số lượng voucher shop đã áp dụng: ${_appliedVouchers.length}');
    print('🔍 [VOUCHER_DEBUG] _appliedVouchers map: ${_appliedVouchers.map((k, v) => MapEntry(k.toString(), '${v.code} (${v.discountType}, ${v.discountValue})'))}');
    
    int totalDiscount = 0;
    
    // ✅ Tính subtotal theo từng shop từ items (nếu có)
    final shopSubtotals = <int, int>{};
    if (items != null && items.isNotEmpty) {
      for (final item in items) {
        final shopId = (item['shopId'] as int?) ?? 0;
        final price = (item['price'] as int?) ?? 0;
        final quantity = (item['quantity'] as int?) ?? 1;
        
        if (shopId > 0) {
          shopSubtotals[shopId] = (shopSubtotals[shopId] ?? 0) + (price * quantity);
        }
      }
      print('🔍 [VOUCHER_DEBUG] shopSubtotals map: $shopSubtotals');
    }
    
    for (final entry in _appliedVouchers.entries) {
      final shopId = entry.key;
      final voucher = entry.value;
      
      print('🔍 [VOUCHER_DEBUG]   → Xử lý voucher shop $shopId:');
      print('🔍 [VOUCHER_DEBUG]     Code: ${voucher.code}');
      print('🔍 [VOUCHER_DEBUG]     Type: ${voucher.discountType}');
      print('🔍 [VOUCHER_DEBUG]     Value: ${voucher.discountValue}');
      print('🔍 [VOUCHER_DEBUG]     MaxDiscount: ${voucher.maxDiscountValue}');
      
      // ✅ Tính subtotal của shop này (nếu có trong shopSubtotals)
      final shopSubtotal = shopSubtotals[shopId] ?? totalPrice;
      if (shopSubtotals.containsKey(shopId)) {
        print('🔍 [VOUCHER_DEBUG]     Shop subtotal: $shopSubtotal (chỉ của shop $shopId)');
      } else {
        print('🔍 [VOUCHER_DEBUG]     ⚠️ Không tìm thấy shop $shopId trong items, dùng totalPrice: $totalPrice (TỔNG TẤT CẢ SHOP)');
      }
      
      // ✅ Tính discount trên shopSubtotal (subtotal của shop đó), không phải totalPrice tổng
      final discount = calculateShopDiscount(shopId, shopSubtotal);
      
      if (discount > 0) {
        print('🔍 [VOUCHER_DEBUG]     Discount tính được: $discount (trên shopSubtotal: $shopSubtotal)');
        print('🔍 [VOUCHER_DEBUG]     ⚠️ QUAN TRỌNG: Tính trên shopSubtotal ($shopSubtotal), KHÔNG phải totalPrice tổng ($totalPrice)');
        totalDiscount += discount;
        print('🔍 [VOUCHER_DEBUG]     ✅ Thêm discount vào tổng: $totalDiscount');
      }
    }
    
    print('🔍 [VOUCHER_DEBUG] Tổng shopDiscount: $totalDiscount');
    print('🔍 [VOUCHER_DEBUG] ==========================================');
    return totalDiscount;
  }

  /// Tính giảm giá của voucher sàn dựa trên danh sách sản phẩm trong giỏ
  /// - subtotal: tổng tiền hàng của các item đang thanh toán (tổng tất cả, để check min order)
  /// - cartProductIds: danh sách product id trong giỏ (để kiểm tra applicable_products)
  /// - items: danh sách items với giá (để tính subtotal chỉ của sản phẩm áp dụng) - format: [{'id': int, 'price': int, 'quantity': int}]
  int calculatePlatformDiscountWithItems(int subtotal, List<int> cartProductIds, {List<Map<String, dynamic>>? items}) {
    // 🔍 DEBUG: In ra thông tin để kiểm tra
    print('🔍 [VOUCHER_DEBUG] ==========================================');
    print('🔍 [VOUCHER_DEBUG] calculatePlatformDiscountWithItems - subtotal: $subtotal');
    print('🔍 [VOUCHER_DEBUG] cartProductIds: $cartProductIds');
    print('🔍 [VOUCHER_DEBUG] items: $items');
    
    final pv = _platformVoucher;
    if (pv == null || pv.discountValue == null) {
      print('🔍 [VOUCHER_DEBUG] Không có platform voucher hoặc discountValue = null');
      print('🔍 [VOUCHER_DEBUG] ==========================================');
      return 0;
    }

    print('🔍 [VOUCHER_DEBUG] Platform voucher:');
    print('🔍 [VOUCHER_DEBUG]   Code: ${pv.code}');
    print('🔍 [VOUCHER_DEBUG]   Type: ${pv.discountType}');
    print('🔍 [VOUCHER_DEBUG]   Value: ${pv.discountValue}');
    print('🔍 [VOUCHER_DEBUG]   MaxDiscount: ${pv.maxDiscountValue}');
    print('🔍 [VOUCHER_DEBUG]   MinOrder: ${pv.minOrderValue}');

    // Kiểm tra min order (dùng subtotal tổng để check)
    if (pv.minOrderValue != null && subtotal < pv.minOrderValue!.round()) {
      print('🔍 [VOUCHER_DEBUG]   ⚠️ Không đủ min order: subtotal ($subtotal) < minOrder (${pv.minOrderValue})');
      print('🔍 [VOUCHER_DEBUG] ==========================================');
      return 0;
    }

    print('🔍 [VOUCHER_DEBUG]   ✅ Đủ min order');

    // Kiểm tra danh sách sản phẩm áp dụng (nếu có)
    final allowIds = <int>{};
    if (pv.applicableProductsDetail != null && pv.applicableProductsDetail!.isNotEmpty) {
      for (final m in pv.applicableProductsDetail!) {
        final id = int.tryParse(m['id'] ?? '');
        if (id != null) allowIds.add(id);
      }
      print('🔍 [VOUCHER_DEBUG]   applicableProductsDetail: $allowIds');
    } else if (pv.applicableProducts != null && pv.applicableProducts!.isNotEmpty) {
      for (final s in pv.applicableProducts!) {
        final id = int.tryParse(s);
        if (id != null) allowIds.add(id);
      }
      print('🔍 [VOUCHER_DEBUG]   applicableProducts: $allowIds');
    } else {
      print('🔍 [VOUCHER_DEBUG]   Không có giới hạn sản phẩm (áp dụng cho tất cả)');
    }
    
    // ✅ Tính subtotal chỉ của các sản phẩm trong danh sách áp dụng (nếu có giới hạn)
    int applicableSubtotal = subtotal; // Mặc định = subtotal tổng (nếu không có giới hạn)
    
    if (allowIds.isNotEmpty) {
      final hasApplicable = cartProductIds.toSet().intersection(allowIds).isNotEmpty;
      print('🔍 [VOUCHER_DEBUG]   Kiểm tra sản phẩm áp dụng:');
      print('🔍 [VOUCHER_DEBUG]     allowIds: $allowIds');
      print('🔍 [VOUCHER_DEBUG]     cartProductIds: ${cartProductIds.toSet()}');
      print('🔍 [VOUCHER_DEBUG]     Giao nhau: ${cartProductIds.toSet().intersection(allowIds)}');
      
      if (!hasApplicable) {
        print('🔍 [VOUCHER_DEBUG]   ⚠️ Không có sản phẩm nào trong danh sách áp dụng');
        print('🔍 [VOUCHER_DEBUG] ==========================================');
        return 0;
      }
      
      print('🔍 [VOUCHER_DEBUG]   ✅ Có sản phẩm trong danh sách áp dụng');
      
      // ✅ Tính subtotal chỉ của các sản phẩm trong danh sách áp dụng
      if (items != null && items.isNotEmpty) {
        applicableSubtotal = 0;
        for (final item in items) {
          final productId = (item['id'] as int?) ?? 0;
          final price = (item['price'] as int?) ?? 0;
          final quantity = (item['quantity'] as int?) ?? 1;
          
          if (allowIds.contains(productId)) {
            final itemTotal = price * quantity;
            applicableSubtotal += itemTotal;
            print('🔍 [VOUCHER_DEBUG]     Sản phẩm $productId (giá $price x $quantity = $itemTotal) → Thêm vào applicableSubtotal');
          }
        }
        print('🔍 [VOUCHER_DEBUG]   Tổng subtotal các sản phẩm áp dụng: $applicableSubtotal');
      } else {
        print('🔍 [VOUCHER_DEBUG]   ⚠️ Không có items để tính subtotal, dùng subtotal tổng: $applicableSubtotal');
      }
    } else {
      print('🔍 [VOUCHER_DEBUG]   Không có giới hạn sản phẩm → áp dụng cho tất cả (dùng subtotal tổng: $applicableSubtotal)');
    }

    // Tính tiền giảm theo kiểu (trên applicableSubtotal, không phải subtotal tổng)
    int finalDiscount = 0;
    if (pv.discountType == 'percentage') {
      final discount = (applicableSubtotal * pv.discountValue! / 100).round();
      print('🔍 [VOUCHER_DEBUG]   Discount tính được (percentage): $applicableSubtotal * ${pv.discountValue}% = $discount');
      print('🔍 [VOUCHER_DEBUG]   ⚠️ QUAN TRỌNG: Tính trên applicableSubtotal ($applicableSubtotal), KHÔNG phải subtotal tổng ($subtotal)');
      
      if (pv.maxDiscountValue != null && pv.maxDiscountValue! > 0) {
        finalDiscount = discount > pv.maxDiscountValue!.round() ? pv.maxDiscountValue!.round() : discount;
        print('🔍 [VOUCHER_DEBUG]   So sánh với maxDiscount (${pv.maxDiscountValue}): $finalDiscount');
      } else {
        finalDiscount = discount;
      }
    } else {
      finalDiscount = pv.discountValue!.round();
      print('🔍 [VOUCHER_DEBUG]   Discount (fixed): $finalDiscount');
    }
    
    print('🔍 [VOUCHER_DEBUG] Platform discount cuối cùng: $finalDiscount');
    print('🔍 [VOUCHER_DEBUG] ==========================================');
    return finalDiscount;
  }

  /// Tính tiền giảm cho shop cụ thể
  int calculateShopDiscount(int shopId, int shopTotal) {
    final voucher = _appliedVouchers[shopId];
    if (voucher == null || voucher.discountValue == null) return 0;
    
    if (voucher.discountType == 'percentage') {
      final discount = (shopTotal * voucher.discountValue! / 100).round();
      if (voucher.maxDiscountValue != null) {
        return discount > voucher.maxDiscountValue! 
            ? voucher.maxDiscountValue!.round() 
            : discount;
      }
      return discount;
    } else {
      return voucher.discountValue!.round();
    }
  }

  /// Kiểm tra voucher có thể áp dụng cho đơn hàng không
  bool canApplyVoucher(Voucher voucher, int orderTotal, {List<int>? productIds}) {
    // Kiểm tra giá tối thiểu
    if (voucher.minOrderValue != null && orderTotal < voucher.minOrderValue!) {
      return false;
    }
    
    // Kiểm tra thời gian
    final now = DateTime.now();
    if (voucher.startDate != null && now.isBefore(voucher.startDate!)) {
      return false;
    }
    if (voucher.endDate != null && now.isAfter(voucher.endDate!)) {
      return false;
    }
    
    // Kiểm tra trạng thái
    if (!voucher.isActive) {
      return false;
    }
    
    // Kiểm tra sản phẩm áp dụng (nếu có productIds)
    if (productIds != null && productIds.isNotEmpty) {
      if (!voucher.appliesToProducts(productIds)) {
        return false;
      }
    }
    
    return true;
  }

  /// Xóa tất cả voucher (khi logout hoặc clear cart)
  void clearAllVouchers() {
    _selectedVouchers.clear();
    _appliedVouchers.clear();
    _platformVoucher = null;
    notifyListeners();
  }

  /// Lấy tất cả voucher đã áp dụng
  List<Voucher> getAllAppliedVouchers() {
    return _appliedVouchers.values.toList();
  }

  /// Lấy tất cả voucher đã chọn
  List<Voucher> getAllSelectedVouchers() {
    return _selectedVouchers.values.toList();
  }

  /// Tính giá trị giảm giá thực tế của voucher cho một đơn hàng
  int _calculateDiscountValue(Voucher voucher, int orderTotal) {
    if (voucher.discountValue == null) return 0;
    
    if (voucher.discountType == 'percentage') {
      final discount = (orderTotal * voucher.discountValue! / 100).round();
      if (voucher.maxDiscountValue != null) {
        return discount > voucher.maxDiscountValue! 
            ? voucher.maxDiscountValue!.round() 
            : discount;
      }
      return discount;
    } else {
      return voucher.discountValue!.round();
    }
  }

  /// Tự động áp dụng voucher tốt nhất cho shop nếu đủ điều kiện
  /// - shopId: ID của shop
  /// - shopTotal: Tổng tiền đơn hàng của shop
  /// - cartProductIds: Danh sách product ID trong giỏ hàng của shop
  Future<void> autoApplyBestVoucher(int shopId, int shopTotal, List<int> cartProductIds) async {
    // Nếu đã có voucher được áp dụng, không tự động áp dụng
    if (_appliedVouchers.containsKey(shopId)) {
      return;
    }

    try {
      final apiService = ApiService();
      
      // Lấy danh sách voucher của shop
      final vouchers = await apiService.getVouchers(
        type: 'shop',
        shopId: shopId,
        limit: 50, // Lấy nhiều voucher để tìm voucher tốt nhất
      );

      if (vouchers == null || vouchers.isEmpty) {
        return;
      }

      // Lọc voucher khả dụng (đủ điều kiện)
      final eligibleVouchers = vouchers.where((voucher) {
        // Kiểm tra điều kiện cơ bản
        if (!canApplyVoucher(voucher, shopTotal, productIds: cartProductIds)) {
          return false;
        }
        
        // Kiểm tra áp dụng cho sản phẩm trong giỏ hàng
        if (cartProductIds.isNotEmpty && !voucher.appliesToProducts(cartProductIds)) {
          return false;
        }
        
        return true;
      }).toList();

      if (eligibleVouchers.isEmpty) {
        return;
      }

      // Tìm voucher có giá trị giảm giá cao nhất
      Voucher? bestVoucher;
      int maxDiscount = 0;

      for (final voucher in eligibleVouchers) {
        final discount = _calculateDiscountValue(voucher, shopTotal);
        if (discount > maxDiscount) {
          maxDiscount = discount;
          bestVoucher = voucher;
        }
      }

      // Tự động áp dụng voucher tốt nhất
      if (bestVoucher != null) {
        applyVoucher(shopId, bestVoucher);
        if (kDebugMode) {
        }
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  /// Tự động áp dụng voucher sàn tốt nhất nếu đủ điều kiện
  /// - totalGoods: Tổng tiền hàng
  /// - cartProductIds: Danh sách product ID trong giỏ hàng
  /// - items: Danh sách items với giá (để tính subtotal chỉ của sản phẩm áp dụng) - format: [{'id': int, 'price': int, 'quantity': int}]
  Future<void> autoApplyBestPlatformVoucher(int totalGoods, List<int> cartProductIds, {List<Map<String, dynamic>>? items}) async {
    // Nếu đã có voucher sàn được áp dụng, không tự động áp dụng
    if (_platformVoucher != null) {
      return;
    }

    try {
      final apiService = ApiService();
      
      // Lấy danh sách voucher sàn
      final vouchers = await apiService.getVouchers(
        type: 'platform',
        limit: 50, // Lấy nhiều voucher để tìm voucher tốt nhất
      );

      if (vouchers == null || vouchers.isEmpty) {
        return;
      }

      // Lọc voucher khả dụng (đủ điều kiện)
      final eligibleVouchers = vouchers.where((voucher) {
        // Kiểm tra điều kiện cơ bản
        if (!canApplyVoucher(voucher, totalGoods, productIds: cartProductIds)) {
          return false;
        }
        
        // Kiểm tra áp dụng cho sản phẩm trong giỏ hàng
        if (cartProductIds.isNotEmpty && !voucher.appliesToProducts(cartProductIds)) {
          return false;
        }
        
        return true;
      }).toList();

      if (eligibleVouchers.isEmpty) {
        return;
      }

      // Tìm voucher có giá trị giảm giá cao nhất
      Voucher? bestVoucher;
      int maxDiscount = 0;

      for (final voucher in eligibleVouchers) {
        // Tính discount cho voucher này (tạm thời set để tính)
        final tempPlatformVoucher = _platformVoucher;
        _platformVoucher = voucher;
        final discount = calculatePlatformDiscountWithItems(totalGoods, cartProductIds, items: items);
        _platformVoucher = tempPlatformVoucher; // Restore
        
        if (discount > maxDiscount) {
          maxDiscount = discount;
          bestVoucher = voucher;
        }
      }

      // Tự động áp dụng voucher tốt nhất
      if (bestVoucher != null && maxDiscount > 0) {
        setPlatformVoucher(bestVoucher);
        if (kDebugMode) {
        }
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }
}
