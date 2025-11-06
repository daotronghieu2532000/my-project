import 'package:flutter/material.dart';
import 'widgets/purchased_product_card.dart';
import 'models/purchased_product.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cart_service.dart';
import '../cart/cart_screen.dart';
import '../home/widgets/product_grid.dart';

class PurchasedProductsScreen extends StatefulWidget {
  const PurchasedProductsScreen({super.key});

  @override
  State<PurchasedProductsScreen> createState() => _PurchasedProductsScreenState();
}

class _PurchasedProductsScreenState extends State<PurchasedProductsScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();
  
  List<PurchasedProduct> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalPurchased = 0;
  final int _limit = 50;

  @override
  void initState() {
    super.initState();
    _loadPurchasedProducts();
  }

  Future<void> _loadPurchasedProducts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _products.clear();
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = 'Vui lòng đăng nhập để xem sản phẩm đã mua';
        });
        return;
      }

      // Lấy tất cả đơn hàng có status = 5 (giao thành công)
      final response = await _apiService.getOrdersList(
        userId: currentUser.userId,
        page: _currentPage,
        limit: _limit,
        status: 5, // Chỉ lấy đơn hàng đã giao thành công
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final ordersData = data['orders'] as List<dynamic>?;
        final pagination = data['pagination'] as Map<String, dynamic>?;

        // Lấy tất cả sản phẩm từ các đơn hàng
        final List<PurchasedProduct> newProducts = [];
        
        if (ordersData != null) {
          for (final orderData in ordersData) {
            final order = orderData as Map<String, dynamic>;
            final products = order['products'] as List<dynamic>?;
            
            if (products != null) {
              for (final productData in products) {
                final product = productData as Map<String, dynamic>;
                // Tạo PurchasedProduct từ product và order data
                final purchasedProduct = PurchasedProduct.fromOrderProduct(product, order);
                newProducts.add(purchasedProduct);
              }
            }
          }
        }

        setState(() {
          if (refresh) {
            _products = newProducts;
          } else {
            _products.addAll(newProducts);
          }
          _isLoading = false;
          _isLoadingMore = false;
          
          if (pagination != null) {
            _totalPages = pagination['total_pages'] as int? ?? 1;
            _totalPurchased = newProducts.length;
          } else {
            _totalPurchased = _products.length;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = response?['message'] ?? 'Không thể tải danh sách sản phẩm đã mua';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = 'Lỗi kết nối: $e';
      });
    }
  }

  Future<void> _refresh() async {
    await _loadPurchasedProducts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          'Sản phẩm đã mua${_totalPurchased > 0 ? ' ($_totalPurchased)' : ''}',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        actions: [
          // Cart button with realtime badge
          ListenableBuilder(
            listenable: _cartService,
            builder: (context, child) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CartScreen(),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.black,
                        size: 24,
                      ),
                      // Cart count badge - realtime version
                      if (_cartService.itemCount > 0)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _cartService.itemCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có sản phẩm đã mua',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các sản phẩm bạn đã mua sẽ hiển thị ở đây',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Mua sắm ngay'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Danh sách sản phẩm đã mua
          ...List.generate(
            _products.length + (_isLoadingMore && _currentPage < _totalPages ? 1 : 0),
            (index) {
              if (index == _products.length) {
                // Loading more indicator
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final product = _products[index];
              return Column(
                children: [
                  PurchasedProductCard(
                    product: product,
                  ),
                  if (index < _products.length - 1) const Divider(height: 1),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Gợi ý tới bạn section
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Text(
                          'Có thể bạn sẽ thích',
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
                          color: Colors.black87,
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

