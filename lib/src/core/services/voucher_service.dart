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
    }
    
    for (final entry in _appliedVouchers.entries) {
      final shopId = entry.key;
      
      // ✅ Tính subtotal của shop này (nếu có trong shopSubtotals)
      final shopSubtotal = shopSubtotals[shopId] ?? totalPrice;
      
      // ✅ Tính discount trên shopSubtotal (subtotal của shop đó), không phải totalPrice tổng
      final discount = calculateShopDiscount(shopId, shopSubtotal);
      
      if (discount > 0) {
        totalDiscount += discount;
      }
    }
    
    return totalDiscount;
  }

  /// Tính giảm giá của voucher sàn dựa trên danh sách sản phẩm trong giỏ
  /// - subtotal: tổng tiền hàng của các item đang thanh toán (tổng tất cả, để check min order)
  /// - cartProductIds: danh sách product id trong giỏ (để kiểm tra applicable_products)
  /// - items: danh sách items với giá (để tính subtotal chỉ của sản phẩm áp dụng) - format: [{'id': int, 'price': int, 'quantity': int}]
  int calculatePlatformDiscountWithItems(int subtotal, List<int> cartProductIds, {List<Map<String, dynamic>>? items}) {
    final pv = _platformVoucher;
    if (pv == null || pv.discountValue == null) {
      return 0;
    }

    // Kiểm tra min order (dùng subtotal tổng để check)
    if (pv.minOrderValue != null && subtotal < pv.minOrderValue!.round()) {
      return 0;
    }

    // Kiểm tra danh sách sản phẩm áp dụng (nếu có)
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
    
    // ✅ Tính subtotal chỉ của các sản phẩm trong danh sách áp dụng (nếu có giới hạn)
    int applicableSubtotal = subtotal; // Mặc định = subtotal tổng (nếu không có giới hạn)
    
    if (allowIds.isNotEmpty) {
      final hasApplicable = cartProductIds.toSet().intersection(allowIds).isNotEmpty;
      
      if (!hasApplicable) {
        return 0;
      }
      
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
          }
        }
      }
    }

    // Tính tiền giảm theo kiểu (trên applicableSubtotal, không phải subtotal tổng)
    int finalDiscount = 0;
    if (pv.discountType == 'percentage') {
      final discount = (applicableSubtotal * pv.discountValue! / 100).round();
      
      if (pv.maxDiscountValue != null && pv.maxDiscountValue! > 0) {
        finalDiscount = discount > pv.maxDiscountValue!.round() ? pv.maxDiscountValue!.round() : discount;
      } else {
        finalDiscount = discount;
      }
    } else {
      finalDiscount = pv.discountValue!.round();
    }
    
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
