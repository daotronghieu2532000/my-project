import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets/time_slots_tab_bar.dart';
import 'widgets/countdown_banner.dart';
import 'widgets/flash_sale_product_card.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/models/flash_sale_deal.dart';
import '../../core/models/flash_sale_product.dart';
import '../cart/cart_screen.dart';
import '../root_shell.dart';
import '../checkout/checkout_screen.dart';
import '../product/product_detail_screen.dart';
import '../product/widgets/variant_selection_dialog.dart';
import '../product/widgets/simple_purchase_dialog.dart';
import '../../core/models/product_detail.dart';
import '../../core/services/cart_service.dart';
import '../../core/utils/format_utils.dart';

class FlashSaleScreen extends StatefulWidget {
  const FlashSaleScreen({super.key});

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> with TickerProviderStateMixin {
  Duration _timeLeft = const Duration(hours: 1, minutes: 59, seconds: 28);
  late Timer _timer;
  late TabController _tabController;
  int _selectedTab = 0;
  final Map<int, bool> _expandedDeals = {}; // Track which deals are expanded
  final ApiService _apiService = ApiService();
  final CachedApiService _cachedApiService = CachedApiService();
  final CartService _cartService = CartService();
  
  final List<String> _timeSlots = ['00:00', '09:00', '16:00'];
  final List<String> _statusTexts = ['Sáng sớm', 'Buổi sáng', 'Buổi chiều tối'];
  
  final List<List<FlashSaleDeal>> _dealsBySlot = [[], [], []];
  final List<bool> _isLoadingSlots = [true, true, true];
  final List<String?> _errors = [null, null, null];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });
    
    _loadAllTimeSlots();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final slotEnd = _slotEndTime(_timeSlots[_selectedTab]);
      final now = DateTime.now();
      final remaining = slotEnd.difference(now).inSeconds;
      setState(() {
        _timeLeft = Duration(seconds: remaining > 0 ? remaining : 0);
      });
    });
  }

  Future<void> _loadAllTimeSlots() async {
    for (int i = 0; i < _timeSlots.length; i++) {
      await _loadTimeSlot(i);
    }
  }

  Future<void> _loadTimeSlot(int slotIndex) async {
    try {
      setState(() {
        _isLoadingSlots[slotIndex] = true;
        _errors[slotIndex] = null;
      });

      // Sử dụng cached API service cho flash sale deals
      final dealsData = await _cachedApiService.getFlashSaleDealsCached(
        timeSlot: _timeSlots[slotIndex],
        status: 'active',
        limit: 100,
      );
      
      // Nếu cache không có data, fallback về ApiService
      List<FlashSaleDeal>? deals;
      if (dealsData == null || dealsData.isEmpty) {
        
        deals = await _apiService.getFlashSaleDeals(
          timeSlot: _timeSlots[slotIndex],
          status: 'active',
          limit: 100,
        );
      } else {
      
        // Convert cached data to FlashSaleDeal list
        deals = dealsData.map((data) => FlashSaleDeal.fromJson(data)).toList();
      }
      
      if (mounted) {
        setState(() {
          _isLoadingSlots[slotIndex] = false;
          if (deals != null && deals.isNotEmpty) {
            _dealsBySlot[slotIndex] = deals;
            // Cập nhật countdown từ slot đầu tiên có deal
            if (slotIndex == 0 && deals.isNotEmpty) {
              final firstDeal = deals.first;
              _timeLeft = Duration(seconds: firstDeal.timeRemaining);
            }
          } else {
            _errors[slotIndex] = 'Không có deal flash sale';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSlots[slotIndex] = false;
          _errors[slotIndex] = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  DateTime _slotEndTime(String slot) {
    final now = DateTime.now();
    if (slot == '00:00') {
      return DateTime(now.year, now.month, now.day, 9, 0, 0);
    } else if (slot == '09:00') {
      return DateTime(now.year, now.month, now.day, 16, 0, 0);
    } else {
      return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  String _getShopName(int shopId) {
    // TODO: Implement shop name lookup from API
    // For now, return a friendly name based on shop ID
    switch (shopId) {
      case 8185:
        return 'Elmich Store';
      case 23933:
        return 'Julyhouse Store';
      case 20755:
        return 'Trường Store';
      default:
        return 'Shop $shopId';
    }
  }

  void _navigateToProductDetail(int productId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          productId: productId,
        ),
      ),
    );
  }

  void _addToCart(FlashSaleProduct product) async {
    try {
            // Lấy thông tin biến thể sản phẩm (nhẹ, chỉ cho dialog)
            final productDetail = await ApiService().getProductVariants(product.id);
      
      if (productDetail != null && productDetail.variants.isNotEmpty) {
        // Show variant selection dialog
        _showVariantDialog(productDetail, isAddToCart: true);
      } else {
        // Show simple quantity dialog for products without variants
        _showSimpleQuantityDialog(product, isAddToCart: true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void _showVariantDialog(ProductDetail product, {required bool isAddToCart}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Nếu có biến thể, hiển thị dialog chọn biến thể
        if (product.variants.isNotEmpty) {
          return VariantSelectionDialog(
          product: product,
          selectedVariant: product.variants.isNotEmpty ? product.variants.first : null,
          onBuyNow: (variant, quantity) {
            _handleBuyNow(product, variant, quantity);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) Navigator.of(context).pop();
            });
          },
          onAddToCart: (variant, quantity) {
            _handleAddToCart(product, variant, quantity);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) Navigator.of(context).pop();
            });
          },
          );
        } else {
          // Nếu không có biến thể, hiển thị dialog đơn giản
          return SimplePurchaseDialog(
            product: product,
            onBuyNow: (product, quantity) {
              Navigator.pop(context);
              _handleBuyNowSimple(product, quantity);
            },
            onAddToCart: (product, quantity) {
              Navigator.pop(context);
              _handleAddToCartSimple(product, quantity);
            },
          );
        }
      },
    );
  }




  // Xử lý MUA NGAY cho sản phẩm có biến thể
  void _handleBuyNow(ProductDetail product, ProductVariant variant, int quantity) {
 
    
    final cartItem = CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );

    _cartService.addItem(cartItem);
    
    // Hiển thị thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${variant.name} vào giỏ hàng'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Chuyển đến trang thanh toán
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  // Xử lý THÊM VÀO GIỎ cho sản phẩm có biến thể
  void _handleAddToCart(ProductDetail product, ProductVariant variant, int quantity) {
   
    
    final cartItem = CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );
    

    _cartService.addItem(cartItem);
    
    // Hiển thị thông báo và chuyển đến giỏ hàng
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${product.name} (${variant.name}) x$quantity vào giỏ hàng'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Xem giỏ hàng',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
        ),
      ),
    );
  }

  // Xử lý MUA NGAY cho sản phẩm không có biến thể
  void _handleBuyNowSimple(ProductDetail product, int quantity) {
  
    
    final cartItem = CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );
    _cartService.addItem(cartItem);
    
    // Hiển thị thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${product.name} vào giỏ hàng'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Chuyển đến trang thanh toán
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  // Xử lý THÊM VÀO GIỎ cho sản phẩm không có biến thể
  void _handleAddToCartSimple(ProductDetail product, int quantity) {
   
    
    final cartItem = CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );
    _cartService.addItem(cartItem);
    
    // Hiển thị thông báo và chuyển đến giỏ hàng
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${product.name} x$quantity vào giỏ hàng'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Xem giỏ hàng',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
        ),
      ),
    );
  }

  void _showSimpleQuantityDialog(FlashSaleProduct product, {required bool isAddToCart}) {
    int quantity = 1;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Product info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Product image
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(product.image ?? ''),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Product details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FormatUtils.formatCurrency(product.price),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          if (product.oldPrice != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              FormatUtils.formatCurrency(product.oldPrice!),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Còn lại: ${product.stock ?? 99} sản phẩm',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Quantity selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Số lượng:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Quantity controls
                    Row(
                      children: [
                        GestureDetector(
                          onTap: quantity > 1 ? () => setState(() => quantity--) : null,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: quantity > 1 ? Colors.grey[200] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.remove,
                              color: quantity > 1 ? Colors.black : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => quantity++),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          
                          // Add to cart service
                          final cartItem = CartItem(
                            id: product.id,
                            name: product.name,
                            image: product.image ?? '',
                            price: product.price,
                            oldPrice: product.oldPrice,
                            quantity: quantity,
                            shopId: 8185, // Default shop ID for flash sale
                            shopName: 'Elmich Store',
                            addedAt: DateTime.now(),
                          );
                          
                          _cartService.addItem(cartItem);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thêm ${product.name} x$quantity vào giỏ hàng'),
                              backgroundColor: Colors.green,
                              action: SnackBarAction(
                                label: 'Xem giỏ hàng',
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CartScreen()),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('THÊM VÀO GIỎ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          
                          // Add to cart and go to checkout
                          final cartItem = CartItem(
                            id: product.id,
                            name: product.name,
                            image: product.image ?? '',
                            price: product.price,
                            oldPrice: product.oldPrice,
                            quantity: quantity,
                            shopId: 8185, // Default shop ID for flash sale
                            shopName: 'Elmich Store',
                            addedAt: DateTime.now(),
                          );
                          
                          _cartService.addItem(cartItem);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thêm ${product.name} x$quantity vào giỏ hàng'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                          
                          // Navigate to checkout
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CheckoutScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('MUA NGAY'),
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


  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildProductsList() {
    final currentDeals = _dealsBySlot[_selectedTab];
    final isLoading = _isLoadingSlots[_selectedTab];
    final error = _errors[_selectedTab];

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.pink),
            SizedBox(height: 16),
            Text(
              'Đang tải flash sale...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadTimeSlot(_selectedTab),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (currentDeals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flash_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Không có flash sale trong khung giờ này',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTimeSlot(_selectedTab),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: currentDeals.length,
        itemBuilder: (context, index) {
          final deal = currentDeals[index];
          return _buildDealCard(deal, index);
        },
      ),
    );
  }

  Widget _buildDealCard(FlashSaleDeal deal, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Deal header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.pink.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deal.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   'Timeline: ${deal.timeline ?? 'N/A'}',
                      //   style: TextStyle(
                      //     fontSize: 12,
                      //     color: Colors.grey[600],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Products list
          if (deal.allProducts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sản phẩm (${deal.allProducts.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Hiển thị sản phẩm theo trạng thái expand/collapse
            ...(_expandedDeals[deal.id] == true 
              ? deal.allProducts 
              : deal.allProducts.take(3)
            ).map((product) => FlashSaleProductCard(
              product: product,
              index: deal.allProducts.indexOf(product),
              onTap: () => _navigateToProductDetail(product.id),
              onAddToCart: () => _addToCart(product),
            )),
            if (deal.allProducts.length > 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '... và ${deal.allProducts.length - 3} sản phẩm khác',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _expandedDeals[deal.id] = !(_expandedDeals[deal.id] ?? false);
                        });
                      },
                      child: Text(
                        _expandedDeals[deal.id] == true ? 'Ẩn bớt' : 'Xem thêm',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.pink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          
          // Deal footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Shop: ${_getShopName(deal.shop)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          'Flash Sale',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CartScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
            ),
        ],
      ),
      body: Column(
        children: [
          // Time slots tabs
          TimeSlotsTabBar(
            tabController: _tabController,
            selectedTab: _selectedTab,
            timeSlots: _timeSlots,
            statusTexts: _statusTexts,
          ),
          
          // Countdown banner
          CountdownBanner(timeLeft: _timeLeft),
          
          // Product list
          Expanded(
            child: _buildProductsList(),
          ),
        ],
      ),
      bottomNavigationBar: const RootShellBottomBar(),
    );
  }
}

