import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'voucher_service.dart';
import 'auth_service.dart';
import 'api_service.dart';

class CartItem {
  final int id;
  final String name;
  final String image;
  final int price;
  final int? oldPrice;
  final int quantity;
  final String? variant;
  final int shopId;
  final String shopName;
  final DateTime addedAt;
  bool isSelected;

  CartItem({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    this.oldPrice,
    required this.quantity,
    this.variant,
    required this.shopId,
    required this.shopName,
    required this.addedAt,
    this.isSelected = true,
  });

  CartItem copyWith({
    int? id,
    String? name,
    String? image,
    int? price,
    int? oldPrice,
    int? quantity,
    String? variant,
    int? shopId,
    String? shopName,
    DateTime? addedAt,
    bool? isSelected,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      quantity: quantity ?? this.quantity,
      variant: variant ?? this.variant,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      addedAt: addedAt ?? this.addedAt,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'price': price,
      'oldPrice': oldPrice,
      'quantity': quantity,
      'variant': variant,
      'shopId': shopId,
      'shopName': shopName,
      'addedAt': addedAt.toIso8601String(),
      'isSelected': isSelected,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      image: json['image'],
      price: json['price'],
      oldPrice: json['oldPrice'],
      quantity: json['quantity'],
      variant: json['variant'],
      shopId: json['shopId'],
      shopName: json['shopName'],
      addedAt: DateTime.parse(json['addedAt']),
      isSelected: json['isSelected'] ?? true, // Default true nếu không có
    );
  }
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal() {
    // Khởi tạo giỏ hàng (async sẽ được gọi sau)
    _initializeCart();
  }

  final List<CartItem> _items = [];
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  static const String _cartKeyPrefix = 'cart_items_';
  bool _isLoading = false; // Flag để tránh lưu khi đang load
  int? _currentUserId; // User ID hiện tại để theo dõi thay đổi user
  bool _isInitialized = false; // Flag để đảm bảo chỉ init một lần
  
  // Khởi tạo giỏ hàng và load theo user hiện tại
  Future<void> _initializeCart() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    await _loadCart();
    // Lắng nghe thay đổi user để load giỏ hàng mới
    _authService.addAuthStateListener(_onAuthStateChanged);
  }
  
  // Xử lý khi user đăng nhập/đăng xuất
  Future<void> _onAuthStateChanged() async {
    final currentUser = await _authService.getCurrentUser();
    final newUserId = currentUser?.userId;
    
    // Nếu user thay đổi, lưu giỏ hàng cũ và load giỏ hàng mới
    if (_currentUserId != newUserId) {
      // Lưu giỏ hàng cũ trước khi chuyển user
      if (_currentUserId != null && _items.isNotEmpty) {
        await _saveCartForUser(_currentUserId!);
      }
      
      // Clear giỏ hàng hiện tại
      _items.clear();
      _currentUserId = newUserId;
      
      // Load giỏ hàng của user mới
      await _loadCart();
      notifyListeners();
    }
  }

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  int get totalPrice => _items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  int get totalSavings => _items.fold(0, (sum, item) {
    if (item.oldPrice != null) {
      return sum + ((item.oldPrice! - item.price) * item.quantity);
    }
    return sum;
  });

  List<CartItem> get selectedItems => _items.where((item) => item.quantity > 0).toList();

  int get selectedItemCount => selectedItems.fold(0, (sum, item) => sum + item.quantity);

  int get selectedTotalPrice => selectedItems.fold(0, (sum, item) => sum + (item.price * item.quantity));

  // Group items by shop
  Map<int, List<CartItem>> get itemsByShop {
    final Map<int, List<CartItem>> grouped = {};
    for (final item in _items) {
      if (!grouped.containsKey(item.shopId)) {
        grouped[item.shopId] = [];
      }
      grouped[item.shopId]!.add(item);
    }
    return grouped;
  }

  // Add item to cart
  void addItem(CartItem item) async {
    // Check if item already exists (same id and variant)
    final existingIndex = _items.indexWhere(
      (existing) => existing.id == item.id && existing.variant == item.variant,
    );
    
    final shopId = item.shopId;
    final hadItemsBefore = _items.any((existing) => existing.shopId == shopId);

    if (existingIndex != -1) {
      // Update quantity if item exists
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + item.quantity,
      );
    } else {
      // Add new item
      _items.add(item);
    }

    // Validate vouchers if adding to a shop that might have vouchers
    if (hadItemsBefore) {
      _validateAndClearVouchers(shopId);
    }
    
    // Lưu cart behavior vào database (chạy async, không ảnh hưởng UI)
    _saveCartBehavior(item);
    
    notifyListeners();
    _saveCart(); // Lưu giỏ hàng sau khi thay đổi
  }
  
  // Lưu cart behavior vào database
  Future<void> _saveCartBehavior(CartItem item) async {
    try {
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      if (userId != null) {
        // Gọi API để lưu cart behavior (chạy async, không chờ kết quả)
        _apiService.addToCart(
          userId: userId,
          productId: item.id,
          quantity: item.quantity,
          variant: item.variant,
        ).then((result) {
          if (result != null && result['success'] == true) {
            print('✅ Cart behavior saved successfully for product_id=${item.id}');
          } else {
            print('⚠️ Failed to save cart behavior for product_id=${item.id}');
          }
        }).catchError((error) {
          print('❌ Error saving cart behavior: $error');
        });
      } else {
        print('⚠️ User not logged in - cannot save cart behavior');
      }
    } catch (e) {
      print('❌ Error in _saveCartBehavior: $e');
    }
  }

  // Remove item from cart
  void removeItem(int itemId, {String? variant}) {
    final removedItem = _items.firstWhere(
      (item) => item.id == itemId && item.variant == variant,
      orElse: () => throw StateError('Item not found'),
    );
    final shopId = removedItem.shopId;
    
    _items.removeWhere(
      (item) => item.id == itemId && item.variant == variant,
    );
    
    // Validate and clear vouchers if products changed
    _validateAndClearVouchers(shopId);
    
    notifyListeners();
    _saveCart(); // Lưu giỏ hàng sau khi thay đổi
  }

  // Update item quantity
  void updateQuantity(int itemId, int quantity, {String? variant}) {
    if (quantity <= 0) {
      removeItem(itemId, variant: variant);
      return;
    }

    final index = _items.indexWhere(
      (item) => item.id == itemId && item.variant == variant,
    );

    if (index != -1) {
      _items[index] = _items[index].copyWith(quantity: quantity);
      notifyListeners();
      _saveCart(); // Lưu giỏ hàng sau khi thay đổi
    }
  }

  // Clear all items
  void clearCart() {
    // Clear all vouchers before clearing items
    final voucherService = VoucherService();
    final shopIds = _items.map((item) => item.shopId).toSet();
    for (final shopId in shopIds) {
      voucherService.cancelVoucher(shopId);
    }
    
    _items.clear();
    notifyListeners();
    _saveCart(); // Lưu giỏ hàng sau khi xóa (để xóa dữ liệu đã lưu)
  }

  // Clear items by shop
  void clearShopItems(int shopId) {
    _items.removeWhere((item) => item.shopId == shopId);
    // Clear voucher for this shop when all items are removed
    final voucherService = VoucherService();
    voucherService.cancelVoucher(shopId);
    notifyListeners();
    _saveCart(); // Lưu giỏ hàng sau khi thay đổi
  }

  // Remove specific item by CartItem object
  void removeCartItem(CartItem item) {
    final shopId = item.shopId;
    _items.removeWhere((existing) => 
        existing.id == item.id && 
        existing.variant == item.variant &&
        existing.shopId == item.shopId);
    
    // Validate and clear vouchers if products changed
    _validateAndClearVouchers(shopId);
    
    notifyListeners();
    _saveCart(); // Lưu giỏ hàng sau khi thay đổi
  }
  
  // Validate vouchers and clear if products no longer match
  void _validateAndClearVouchers(int shopId) {
    final voucherService = VoucherService();
    final appliedVoucher = voucherService.getAppliedVoucher(shopId);
    
    if (appliedVoucher == null) return;
    
    // Get current product IDs for this shop
    final currentProductIds = _items
        .where((item) => item.shopId == shopId)
        .map((item) => item.id)
        .toList();
    
    // If no products remain for this shop, clear the voucher
    if (currentProductIds.isEmpty) {
      voucherService.cancelVoucher(shopId);
      return;
    }
    
    // Check if voucher still applies to remaining products
    if (!appliedVoucher.appliesToProducts(currentProductIds)) {
      voucherService.cancelVoucher(shopId);
    }
  }

  // Update item variant with price
  void updateItemVariant(CartItem item, String? newVariant, {int? newPrice, int? newOldPrice}) {
    final currentIndex = _items.indexWhere((existing) => 
        existing.id == item.id && 
        existing.variant == item.variant &&
        existing.shopId == item.shopId);
    
    if (currentIndex == -1) return;
    
    // Check if there's already an item with the new variant
    final existingVariantIndex = _items.indexWhere((existing) => 
        existing.id == item.id && 
        existing.variant == newVariant &&
        existing.shopId == item.shopId);
    
    if (existingVariantIndex != -1) {
      // Merge quantities and remove the current item
      _items[existingVariantIndex] = _items[existingVariantIndex].copyWith(
        quantity: _items[existingVariantIndex].quantity + item.quantity
      );
      _items.removeAt(currentIndex);
    } else {
      // Update the variant with new price and oldPrice
      _items[currentIndex] = _items[currentIndex].copyWith(
        variant: newVariant,
        price: newPrice ?? item.price,  // Sử dụng giá mới nếu có
        oldPrice: newOldPrice ?? item.oldPrice,  // Sử dụng giá cũ mới nếu có
      );
    }
    
    notifyListeners();
    _saveCart(); // Lưu giỏ hàng sau khi thay đổi
  }

  // Update item price and oldPrice
  void updateItemPrice(int itemId, int newPrice, int newOldPrice, {String? variant, int? shopId}) {
    final index = _items.indexWhere(
      (item) => item.id == itemId && 
                item.variant == variant &&
                (shopId == null || item.shopId == shopId),
    );

    if (index != -1) {
      _items[index] = _items[index].copyWith(
        price: newPrice,
        oldPrice: newOldPrice,
      );
      notifyListeners();
      _saveCart(); // Lưu giỏ hàng sau khi thay đổi
    }
  }

  // Toggle item selection
  void toggleItemSelection(int itemId, {String? variant}) {
    final index = _items.indexWhere(
      (item) => item.id == itemId && item.variant == variant,
    );

    if (index != -1) {
      _items[index] = _items[index].copyWith(
        isSelected: !_items[index].isSelected,
      );
      notifyListeners();
      _saveCart(); // Lưu giỏ hàng sau khi thay đổi
    }
  }

  // Set all items selection
  void setAllItemsSelection(bool isSelected) {
    for (int i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isSelected: isSelected);
    }
    notifyListeners();
    _saveCart(); // Lưu giỏ hàng sau khi thay đổi
  }

  // Lưu giỏ hàng vào SharedPreferences
  Future<void> _saveCart() async {
    if (_isLoading) return; // Không lưu khi đang load
    
    // Lấy user hiện tại để lưu theo userId
    final currentUser = await _authService.getCurrentUser();
    final userId = currentUser?.userId;
    
    if (userId != null) {
      await _saveCartForUser(userId);
      _currentUserId = userId;
    } else {
      // Nếu chưa đăng nhập, lưu vào giỏ hàng guest
      await _saveCartForUser(null);
    }
  }
  
  // Lưu giỏ hàng cho user cụ thể
  Future<void> _saveCartForUser(int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartKey = userId != null ? '$_cartKeyPrefix$userId' : '${_cartKeyPrefix}guest';
      final cartJson = _items.map((item) => item.toJson()).toList();
      await prefs.setString(cartKey, jsonEncode(cartJson));
    } catch (e) {
      print('❌ Lỗi khi lưu giỏ hàng: $e');
    }
  }

  // Load giỏ hàng từ SharedPreferences
  Future<void> _loadCart() async {
    _isLoading = true; // Đánh dấu đang load để tránh lưu
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = await _authService.getCurrentUser();
      final userId = currentUser?.userId;
      
      // Xác định key để load
      final cartKey = userId != null ? '$_cartKeyPrefix$userId' : '${_cartKeyPrefix}guest';
      final cartJsonString = prefs.getString(cartKey);
      
      if (cartJsonString != null && cartJsonString.isNotEmpty) {
        final cartJson = jsonDecode(cartJsonString) as List<dynamic>;
        _items.clear();
        _items.addAll(
          cartJson.map((json) => CartItem.fromJson(json as Map<String, dynamic>)).toList(),
        );
        _currentUserId = userId;
        notifyListeners();
      } else {
        // Nếu không có giỏ hàng cho user này, clear items
        _items.clear();
        _currentUserId = userId;
      }
    } catch (e) {
      print('❌ Lỗi khi load giỏ hàng: $e');
    } finally {
      _isLoading = false; // Hoàn tất load
    }
  }
  
  // Load giỏ hàng khi user đăng nhập (gọi từ bên ngoài)
  Future<void> loadCartForUser() async {
    await _loadCart();
  }
  
  // Clear giỏ hàng khi user đăng xuất
  Future<void> clearCartOnLogout() async {
    // Lưu giỏ hàng hiện tại trước khi clear (nếu có user)
    if (_currentUserId != null && _items.isNotEmpty) {
      await _saveCartForUser(_currentUserId!);
    }
    
    _items.clear();
    _currentUserId = null;
    notifyListeners();
  }

  // Check if item is in cart
  bool isInCart(int itemId, {String? variant}) {
    return _items.any(
      (item) => item.id == itemId && item.variant == variant,
    );
  }

  // Get item quantity in cart
  int getItemQuantity(int itemId, {String? variant}) {
    final item = _items.firstWhere(
      (item) => item.id == itemId && item.variant == variant,
      orElse: () => CartItem(
        id: 0,
        name: '',
        image: '',
        price: 0,
        quantity: 0,
        shopId: 0,
        shopName: '',
        addedAt: DateTime.now(),
      ),
    );
    return item.quantity;
  }
}
