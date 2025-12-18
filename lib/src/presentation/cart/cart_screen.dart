import 'package:flutter/material.dart';
import 'widgets/suggest_section.dart';
import 'widgets/bottom_checkout_bar.dart';
import 'widgets/counter_bubble.dart';
import 'widgets/cart_service_shop_section.dart';
import '../checkout/widgets/voucher_section.dart' as checkout_widgets;
import 'models/shop_cart.dart';
import 'models/cart_item.dart';
import '../../core/services/cart_service.dart' as cart_service;
import '../../core/services/voucher_service.dart';
import '../../core/utils/format_utils.dart';
import '../home/widgets/product_grid.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final cart_service.CartService _cartService = cart_service.CartService();
  final VoucherService _voucherService = VoucherService();
  bool _isEditMode = false;
  
  List<ShopCart> get shops {
    // Only use real cart data from CartService
    return _buildShopsFromCartService();
  }

  List<ShopCart> _buildShopsFromCartService() {
    final Map<int, List<cart_service.CartItem>> itemsByShop = _cartService.itemsByShop;
    final List<ShopCart> result = [];
    
    for (final entry in itemsByShop.entries) {
      final items = entry.value;
      
      // Convert CartItem to old CartItem model
      final convertedItems = items.map((item) {
        final cartItem = CartItem(
          title: item.name,
          price: item.price,
          oldPrice: item.oldPrice,
          image: item.image,
        );
        cartItem.quantity = item.quantity;
        cartItem.isSelected = item.isSelected;
        return cartItem;
      }).toList();
      
      result.add(ShopCart(
        name: items.first.shopName,
        items: convertedItems,
      ));
    }
    
    return result;
  }

  bool get selectAll => _cartService.items.every((i) => i.isSelected);

  int get selectedCount => _cartService.items
      .where((i) => i.isSelected)
      .length;

  // ✅ Tính tổng dựa trên originalPrice (giá gốc) để đồng bộ với checkout
  int get totalPrice => _cartService.items
      .where((i) => i.isSelected)
      .fold(0, (sum, i) => sum + ((i.originalPrice ?? i.price) * i.quantity));

  int get totalSavings => _cartService.items
      .where((i) => i.isSelected)
      .fold(0, (sum, i) {
        if (i.oldPrice != null && i.oldPrice! > i.price) {
          return sum + ((i.oldPrice! - i.price) * i.quantity);
        }
        return sum;
      });

  @override
  void initState() {
    super.initState();
    _cartService.addListener(_onCartChanged);
    _voucherService.addListener(_onVoucherChanged);
    // Tự động áp dụng voucher tốt nhất khi mở giỏ hàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoApplyBestVouchers();
    });
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    _voucherService.removeListener(_onVoucherChanged);
    super.dispose();
  }

  void _onCartChanged() {
    // ✅ DEBUG: Print thông tin cart khi thay đổi
    final selectedItems = _cartService.items.where((i) => i.isSelected).toList();
    final totalPrice = selectedItems.fold(0, (sum, i) => sum + i.price * i.quantity);
  
    
    setState(() {});
    // Tự động áp dụng voucher tốt nhất cho từng shop
    _autoApplyBestVouchers();
  }

  void _onVoucherChanged() {
    // Cập nhật UI khi voucher thay đổi
    if (mounted) {
      setState(() {});
    }
  }

  /// Tự động áp dụng voucher tốt nhất cho từng shop
  Future<void> _autoApplyBestVouchers() async {
    final itemsByShop = _cartService.itemsByShop;
    
    if (itemsByShop.isEmpty) {
      print('🛒 [CART - _autoApplyBestVouchers] Cart is empty, skipping');
      return;
    }
    
  
    
    for (final entry in itemsByShop.entries) {
      final shopId = entry.key;
      final items = entry.value;
      
      // Chỉ tính cho các item đã chọn
      final selectedItems = items.where((item) => item.isSelected).toList();
      if (selectedItems.isEmpty) {
        print('   ⏭️ Shop $shopId: No selected items, skipping');
        continue;
      }
      
      // Tính tổng tiền của shop
      final shopTotal = selectedItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
      
      // Lấy danh sách product ID trong giỏ hàng của shop
      final cartProductIds = selectedItems.map((item) => item.id).toList();
      
   
      
      // Tự động áp dụng voucher tốt nhất cho shop
      await _voucherService.autoApplyBestVoucher(shopId, shopTotal, cartProductIds);
      
      final appliedVoucher = _voucherService.getAppliedVoucher(shopId);
      if (appliedVoucher != null) {
        print('      ✅ Applied voucher: ${appliedVoucher.code} (${appliedVoucher.discountType == 'percentage' ? '${appliedVoucher.discountValue}%' : FormatUtils.formatCurrency(appliedVoucher.discountValue?.round() ?? 0)})');
      } else {
        print('      ❌ No voucher applied');
      }
    }
    
    // ✅ DEBUG: Print tổng hợp voucher sau khi auto apply
    final appliedVouchers = _voucherService.appliedVouchers;
    final platformVouchers = _voucherService.platformVouchers;
 
    
    // Cập nhật UI sau khi áp dụng voucher
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Giỏ hàng',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            CounterBubble(count: _cartService.itemCount),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
                if (!_isEditMode) {
                  // Reset all selections when exiting edit mode
                  _cartService.setAllItemsSelection(true);
                }
              });
            }, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_isEditMode ? 'Xong' : 'Sửa'),
          ),
        ],
      ),
      body: _cartService.items.isEmpty
          ? _buildEmptyCart()
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Hiển thị items từ CartService
                for (final entry in _cartService.itemsByShop.entries)
                  CartServiceShopSection(
                    shopName: entry.value.first.shopName,
                    items: entry.value,
                    onChanged: _onChanged,
                    isEditMode: _isEditMode,
                  ),
                const SizedBox(height: 12),
                
                // Thêm VoucherSection để hiển thị voucher sàn
                if (_cartService.items.any((item) => item.isSelected))
                  checkout_widgets.VoucherSection(key: const ValueKey('platform_voucher_section')),
                
                const SizedBox(height: 12),
                const SuggestSection(),
                const SizedBox(height: 100),
              ],
            ),
      bottomNavigationBar: _cartService.items.isEmpty
          ? null
          : BottomCheckoutBar(
              selectAll: selectAll,
              onToggleAll: (v) {
                _cartService.setAllItemsSelection(v);
                setState(() {});
              },
              totalPrice: totalPrice,
              selectedCount: selectedCount,
              totalSavings: totalSavings,
              isEditMode: _isEditMode,
              onDeleteSelected: _isEditMode ? () => _deleteSelectedItems() : null,
            ),
    );
  }

  void _onChanged() => setState(() {});

  void _deleteSelectedItems() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red[600],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xóa sản phẩm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bạn có chắc muốn xóa $selectedCount sản phẩm đã chọn?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(10),
                            child: const Center(
                              child: Text(
                                'Hủy',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              final selectedItems = _cartService.items.where((item) => item.isSelected).toList();
                              for (final item in selectedItems) {
                                _cartService.removeCartItem(item);
                              }
                              setState(() {
                                _isEditMode = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: const Center(
                              child: Text(
                                'Xóa',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildEmptyCart() {
    // Empty state chiếm 40% chiều cao màn hình, phần gợi ý ở dưới
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Giỏ hàng trống',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thêm sản phẩm vào giỏ hàng để tiếp tục mua sắm',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Tiếp tục mua sắm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: Colors.grey.withOpacity(0.4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Text(
                          'Sản phẩm dành cho bạn',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: Colors.grey.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                ProductGrid(title: ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



