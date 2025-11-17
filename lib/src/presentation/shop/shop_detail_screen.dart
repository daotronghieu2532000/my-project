import 'package:flutter/material.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/models/shop_detail.dart';
import '../product/product_detail_screen.dart';
import '../cart/cart_screen.dart';
import '../chat/chat_screen.dart';
import 'widgets/shop_banner_header.dart';
import 'widgets/shop_tab_content.dart';
import 'widgets/shop_products_section.dart';
import 'widgets/shop_warehouses_section.dart';

class ShopDetailScreen extends StatefulWidget {
  final int? shopId;
  final String? shopUsername;
  final String? shopName;
  final String? shopAvatar;

  const ShopDetailScreen({
    super.key,
    this.shopId,
    this.shopUsername,
    this.shopName,
    this.shopAvatar,
  });

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen>
    with SingleTickerProviderStateMixin {
  final CachedApiService _cachedApiService = CachedApiService();
  ShopDetail? _shopDetail;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadShopDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShopDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final shopDetail = await _cachedApiService.getShopDetailCached(
        shopId: widget.shopId,
        username: widget.shopUsername,
        includeProducts: 1,
        includeFlashSale: 1,
        includeVouchers: 1,
        includeWarehouses: 1,
        includeCategories: 1,
        productsLimit: 50, // Tăng từ 20 lên 50
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _shopDetail = shopDetail;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  void _navigateToProduct(ShopProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          productId: product.id,
          title: product.name,
          image: product.image,
          price: product.price,
          initialShopId: widget.shopId,
          initialShopName: widget.shopName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.shopName ?? 'Đang tải...'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.shopName ?? 'Lỗi'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadShopDetail,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_shopDetail == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.shopName ?? 'Không tìm thấy'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Không tìm thấy thông tin shop'),
        ),
      );
    }

    final shopInfo = _shopDetail!.shopInfo;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Shop Banner Header với thông tin đè lên - dính lên đỉnh trang
          ShopBannerHeader(
            shopInfo: shopInfo,
            onBack: () => Navigator.pop(context),
            onChat: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    shopId: widget.shopId ?? shopInfo.shopId,
                    shopName: widget.shopName ?? shopInfo.name,
                    shopAvatar: widget.shopAvatar ?? shopInfo.avatarUrl,
                  ),
                ),
              );
            },
            onCart: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
            onSearch: (keyword) {
            
              setState(() {
                _searchKeyword = keyword;
              });
            },
          ),
          
          // Tab Bar - full width, không scrollable
          Container(
            color: Colors.white,
            child: SizedBox(
              height: 48,
              child: TabBar(
                controller: _tabController,
                isScrollable: false, // Không scrollable để full width
                labelColor: Colors.red,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.red,
                tabs: const [
                  Tab(text: 'Shop'),
                  Tab(text: 'Sản phẩm'),
                  Tab(text: 'Kho hàng'),
                ],
              ),
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              key: ValueKey('tab_view_${widget.shopId ?? shopInfo.shopId}_$_searchKeyword'),
              controller: _tabController,
              children: [
                // Shop tab - chứa Voucher, Flash Sale, Danh mục
                ShopTabContent(
                  shopId: widget.shopId ?? shopInfo.shopId,
                ),
                
                // Sản phẩm
                ShopProductsSection(
                  key: ValueKey('shop_products_${widget.shopId ?? shopInfo.shopId}_$_searchKeyword'),
                  shopId: widget.shopId ?? shopInfo.shopId,
                  onProductTap: _navigateToProduct,
                  searchKeyword: _searchKeyword,
                ),
                
                // Kho hàng
                ShopWarehousesSection(
                  shopId: widget.shopId ?? shopInfo.shopId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
