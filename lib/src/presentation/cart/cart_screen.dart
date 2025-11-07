import 'package:flutter/material.dart';
import 'widgets/suggest_section.dart';
import 'widgets/bottom_checkout_bar.dart';
import 'widgets/counter_bubble.dart';
import 'widgets/cart_service_shop_section.dart';
import 'models/shop_cart.dart';
import 'models/cart_item.dart';
import '../../core/services/cart_service.dart' as cart_service;

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final cart_service.CartService _cartService = cart_service.CartService();
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

  int get totalPrice => _cartService.items
      .where((i) => i.isSelected)
      .fold(0, (sum, i) => sum + i.price * i.quantity);

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
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    setState(() {});
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã xóa ${selectedItems.length} sản phẩm'),
                                  backgroundColor: Colors.red[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
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
    return Center(
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
    );
  }
}



