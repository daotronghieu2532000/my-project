import 'package:flutter/foundation.dart';
import '../models/voucher.dart';
import 'api_service.dart';
import '../utils/format_utils.dart';

class VoucherService extends ChangeNotifier {
  static final VoucherService _instance = VoucherService._internal();
  factory VoucherService() => _instance;
  VoucherService._internal();

  // Voucher đã chọn cho từng shop
  final Map<int, Voucher> _selectedVouchers = {};
  
  // Voucher đã áp dụng (đã confirm)
  final Map<int, Voucher> _appliedVouchers = {};

  // ✅ Thay đổi: Lưu nhiều voucher platform (key = voucher code)
  final Map<String, Voucher> _platformVouchers = {};

  Map<int, Voucher> get selectedVouchers => Map.unmodifiable(_selectedVouchers);
  Map<int, Voucher> get appliedVouchers => Map.unmodifiable(_appliedVouchers);
  
  // ✅ Thay đổi: Getter trả về Map thay vì single voucher
  Map<String, Voucher> get platformVouchers => Map.unmodifiable(_platformVouchers);
  
  // ✅ Backward compatibility: Trả về voucher platform đầu tiên (nếu có)
  Voucher? get platformVoucher => _platformVouchers.values.isNotEmpty ? _platformVouchers.values.first : null;

  /// Chọn voucher cho shop
  void selectVoucher(int shopId, Voucher voucher) {
    _selectedVouchers[shopId] = voucher;
    notifyListeners();
  }

  /// Bỏ chọn voucher cho shop
  void removeVoucher(int shopId) {
    if (_selectedVouchers.containsKey(shopId)) {
   
      _selectedVouchers.remove(shopId);
      notifyListeners();
    }
  }

  /// Áp dụng voucher (confirm)
  void applyVoucher(int shopId, Voucher voucher) {
    // Validate shopId
  
    
    _appliedVouchers[shopId] = voucher;
    _selectedVouchers.remove(shopId); // Xóa khỏi selected sau khi apply
    notifyListeners();
    
    // Debug log
    _logAppliedVouchers();
  }
  
  // Helper method để log các voucher đã áp dụng
  void _logAppliedVouchers() {
    if (_appliedVouchers.isEmpty) {
      return;
    }
    
    
    _appliedVouchers.forEach((shopId, voucher) {
    
    });
  }

  /// Hủy áp dụng voucher
  void cancelVoucher(int shopId) {
  
    
    if (_appliedVouchers.containsKey(shopId)) {
    
      _appliedVouchers.remove(shopId);
      notifyListeners();
      _logAppliedVouchers();
    }
  }

  /// ✅ Thêm voucher platform
  void addPlatformVoucher(Voucher voucher) {
    if (voucher.code != null && voucher.code!.isNotEmpty) {
      _platformVouchers[voucher.code!] = voucher;
      notifyListeners();
    }
  }

  /// ✅ Xóa voucher platform theo code
  void removePlatformVoucher(String code) {
    _platformVouchers.remove(code);
    notifyListeners();
  }

  /// ✅ Xóa tất cả voucher platform
  void clearPlatformVouchers() {
    _platformVouchers.clear();
    notifyListeners();
  }

  /// ✅ Chọn/áp dụng voucher sàn (backward compatibility - chỉ set 1 voucher)
  void setPlatformVoucher(Voucher? voucher) {
    _platformVouchers.clear();
    if (voucher != null && voucher.code != null && voucher.code!.isNotEmpty) {
      _platformVouchers[voucher.code!] = voucher;
    }
    notifyListeners();
  }

  /// ✅ Kiểm tra voucher platform đã được áp dụng chưa
  bool isPlatformVoucherApplied(String code) {
    return _platformVouchers.containsKey(code);
  }

  /// ✅ Lấy voucher platform theo code
  Voucher? getPlatformVoucher(String code) {
    return _platformVouchers[code];
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
        
        // ✅ Chỉ tính cho shop > 0 (bỏ qua shop 0 - Sàn TMĐT)
        if (shopId > 0) {
          shopSubtotals[shopId] = (shopSubtotals[shopId] ?? 0) + (price * quantity);
        }
      }
    }
    
 
    for (final entry in _appliedVouchers.entries) {
      print('      - Shop ${entry.key}: ${entry.value.code}');
    }
    
    for (final entry in _appliedVouchers.entries) {
      final shopId = entry.key;
      
      // ✅ Bỏ qua shop 0 (Sàn TMĐT) - không có voucher shop
      if (shopId <= 0) {
        print('      ⏭️ Shop $shopId: Skipping (shop 0)');
        continue;
      }
      
      // ✅ CHỈ tính discount cho shop có sản phẩm trong items
      // Nếu shop không có trong shopSubtotals, nghĩa là không còn sản phẩm, bỏ qua
      if (!shopSubtotals.containsKey(shopId)) {
        // Shop không còn sản phẩm trong items, bỏ qua voucher này
        print('      ❌ Shop $shopId: No products in items, skipping voucher ${entry.value.code}');
        continue;
      }
      
      // ✅ Tính subtotal của shop này (chắc chắn có trong shopSubtotals)
      final shopSubtotal = shopSubtotals[shopId]!;
      
      // ✅ Tính discount trên shopSubtotal (subtotal của shop đó), không phải totalPrice tổng
      final discount = calculateShopDiscount(shopId, shopSubtotal);
      
   
      
      if (discount > 0) {
        totalDiscount += discount;
      }
    }
    
    return totalDiscount;
  }

  /// ✅ Tính giảm giá của TẤT CẢ voucher sàn dựa trên danh sách sản phẩm trong giỏ
  /// - subtotal: tổng tiền hàng của các item đang thanh toán (tổng tất cả, để check min order)
  /// - cartProductIds: danh sách product id trong giỏ (để kiểm tra applicable_products)
  /// - items: danh sách items với giá (để tính subtotal chỉ của sản phẩm áp dụng) - format: [{'id': int, 'price': int, 'quantity': int}]
  int calculatePlatformDiscountWithItems(int subtotal, List<int> cartProductIds, {List<Map<String, dynamic>>? items}) {
    if (_platformVouchers.isEmpty) {
     
      return 0;
    }

    int totalDiscount = 0;
    
    // ✅ Map để theo dõi sản phẩm đã được áp dụng voucher nào (để tránh overlap)
    // Key: productId, Value: discount amount
    final Map<int, int> productDiscounts = {};
    
    // ✅ Duyệt qua từng voucher platform
    for (final entry in _platformVouchers.entries) {
      final voucherCode = entry.key;
      final voucher = entry.value;
      

      // Lấy danh sách sản phẩm áp dụng của voucher này
      final allowIds = <int>{};
      bool isAllProducts = voucher.isAllProducts == true || voucher.voucherType == 'all';
      
      if (!isAllProducts) {
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
      }

      // ✅ Tính subtotal chỉ của các sản phẩm trong danh sách áp dụng (và chưa được áp dụng voucher khác)
      int applicableSubtotal = 0;
      final List<int> applicableProductIds = [];
      
      if (items != null && items.isNotEmpty) {
        for (final item in items) {
          final productId = (item['id'] as int?) ?? 0;
          final price = (item['price'] as int?) ?? 0;
          final quantity = (item['quantity'] as int?) ?? 1;
          
          // Kiểm tra sản phẩm có áp dụng được voucher này không
          bool canApply = false;
          if (isAllProducts) {
            canApply = true;
          } else if (allowIds.contains(productId)) {
            canApply = true;
          }
          
          // ✅ Chỉ tính sản phẩm chưa được áp dụng voucher nào (hoặc voucher hiện tại tốt hơn)
          if (canApply) {
            final itemTotal = price * quantity;
            applicableSubtotal += itemTotal;
            applicableProductIds.add(productId);
          }
        }
      } else if (isAllProducts) {
        // Nếu không có items detail, dùng subtotal tổng
        applicableSubtotal = subtotal;
      }

      if (applicableSubtotal == 0) {
      
        continue;
      }

      // Tính tiền giảm theo kiểu (trên applicableSubtotal)
      int discount = 0;
      
      if (voucher.discountType == 'percentage') {
        discount = (applicableSubtotal * voucher.discountValue! / 100).round();
        
        if (voucher.maxDiscountValue != null && voucher.maxDiscountValue! > 0) {
          discount = discount > voucher.maxDiscountValue!.round() 
              ? voucher.maxDiscountValue!.round() 
              : discount;
        }
      } else {
        discount = voucher.discountValue!.round();
      }

     
      
      // ✅ Cộng discount vào tổng
      totalDiscount += discount;
      
      // ✅ Đánh dấu các sản phẩm đã được áp dụng voucher này
      for (final productId in applicableProductIds) {
        productDiscounts[productId] = (productDiscounts[productId] ?? 0) + discount;
      }
    }
    
  
    return totalDiscount;
  }

  /// Tính tiền giảm cho shop cụ thể
  int calculateShopDiscount(int shopId, int shopTotal) {
    final voucher = _appliedVouchers[shopId];
    if (voucher == null || voucher.discountValue == null) {
      return 0;
    }
    
    
    int discount = 0;
    if (voucher.discountType == 'percentage') {
      discount = (shopTotal * voucher.discountValue! / 100).round();
      if (voucher.maxDiscountValue != null) {
        discount = discount > voucher.maxDiscountValue!
            ? voucher.maxDiscountValue!.round()
            : discount;
      }
    } else {
      discount = voucher.discountValue!.round();
    }
    
    return discount;
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
    _platformVouchers.clear(); // ✅ Clear tất cả platform vouchers
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

  /// ✅ Lấy tất cả platform vouchers
  List<Voucher> getAllPlatformVouchers() {
    return _platformVouchers.values.toList();
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
    // ✅ Shop 0 (Sàn TMĐT) không có voucher shop, bỏ qua
    if (shopId <= 0) {
      return;
    }
    
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
      if (bestVoucher != null && maxDiscount > 0) {
        applyVoucher(shopId, bestVoucher);
      }
    } catch (e) {
      print('❌ [VoucherService] Lỗi khi tự động áp dụng voucher cho shop $shopId: $e');
    }
  }

  /// ✅ Tự động áp dụng NHIỀU voucher sàn tốt nhất nếu đủ điều kiện
  /// - totalGoods: Tổng tiền hàng
  /// - cartProductIds: Danh sách product ID trong giỏ hàng
  /// - items: Danh sách items với giá (để tính subtotal chỉ của sản phẩm áp dụng) - format: [{'id': int, 'price': int, 'quantity': int}]
  Future<void> autoApplyBestPlatformVoucher(int totalGoods, List<int> cartProductIds, {List<Map<String, dynamic>>? items}) async {
    // ✅ Cho phép tự động áp dụng nhiều voucher (không return nếu đã có voucher)
    
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

      // ✅ Map để theo dõi sản phẩm đã được áp dụng voucher
      final Set<int> coveredProducts = {};
      
      // ✅ Danh sách voucher đã chọn
      final List<Voucher> selectedVouchers = [];

      // ✅ Sắp xếp voucher theo discount value giảm dần
      final sortedVouchers = List<Voucher>.from(eligibleVouchers);
      sortedVouchers.sort((a, b) {
        // Tính discount tạm thời để so sánh
        final discountA = _calculateDiscountValue(a, totalGoods);
        final discountB = _calculateDiscountValue(b, totalGoods);
        return discountB.compareTo(discountA); // Giảm dần
      });

      // ✅ Duyệt qua từng voucher và áp dụng nếu có sản phẩm chưa được cover
      for (final voucher in sortedVouchers) {
        // Lấy danh sách sản phẩm áp dụng của voucher này
        final allowIds = <int>{};
        bool isAllProducts = voucher.isAllProducts == true || voucher.voucherType == 'all';
        
        if (!isAllProducts) {
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
        }

        // Kiểm tra xem voucher này có sản phẩm nào chưa được cover không
        bool hasUncoveredProducts = false;
        final Set<int> newCoveredProducts = {};
        
        if (isAllProducts) {
          // Nếu áp dụng cho tất cả, kiểm tra xem còn sản phẩm nào chưa cover không
          for (final productId in cartProductIds) {
            if (!coveredProducts.contains(productId)) {
              hasUncoveredProducts = true;
              newCoveredProducts.add(productId);
            }
          }
        } else {
          // Nếu áp dụng cho sản phẩm cụ thể
          for (final productId in allowIds) {
            if (cartProductIds.contains(productId) && !coveredProducts.contains(productId)) {
              hasUncoveredProducts = true;
              newCoveredProducts.add(productId);
            }
          }
        }

        // Nếu có sản phẩm chưa được cover, áp dụng voucher này
        if (hasUncoveredProducts) {
          selectedVouchers.add(voucher);
          coveredProducts.addAll(newCoveredProducts);
          
          // ✅ Nếu đã cover hết tất cả sản phẩm, dừng lại
          if (coveredProducts.length >= cartProductIds.length) {
            break;
          }
        }
      }

      // ✅ Áp dụng tất cả voucher đã chọn
      if (selectedVouchers.isNotEmpty) {
        _platformVouchers.clear();
        for (final voucher in selectedVouchers) {
          if (voucher.code != null && voucher.code!.isNotEmpty) {
            _platformVouchers[voucher.code!] = voucher;
          }
        }
        notifyListeners();
        
      
      }
    } catch (e) {
      print('❌ [VoucherService] Lỗi khi tự động áp dụng voucher platform: $e');
    }
  }
}
