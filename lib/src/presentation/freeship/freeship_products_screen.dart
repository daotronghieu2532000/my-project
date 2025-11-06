import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/models/freeship_product.dart';
import '../root_shell.dart';
import 'widgets/freeship_product_card_horizontal.dart';

class FreeShipProductsScreen extends StatefulWidget {
  const FreeShipProductsScreen({super.key});

  @override
  State<FreeShipProductsScreen> createState() => _FreeShipProductsScreenState();
}

class _FreeShipProductsScreenState extends State<FreeShipProductsScreen> {
  final ApiService _apiService = ApiService();
  final CachedApiService _cachedApiService = CachedApiService();
  List<FreeShipProduct> _products = [];
  bool _isLoading = true;
  String? _error;

  // Lọc & sắp xếp
  String _currentSort = 'relevance'; // relevance | price-asc | price-desc | rating-desc | sold-desc
  bool _onlyHasVoucher = false;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Clear cache để force refresh với dữ liệu mới
      _cachedApiService.clearFreeshipCache();
      print('🧹 Cleared freeship cache to force refresh');
      
      // Sử dụng cached API service cho freeship products
      final productsData = await _cachedApiService.getFreeShipProductsCached();
      
      // Debug: In ra cached data
      print('🔍 Cached productsData: ${productsData?.length} items');
      if (productsData != null && productsData.isNotEmpty) {
        print('🔍 First cached product: ${productsData.first}');
      }
      
      // Nếu cache không có data, fallback về ApiService
      List<FreeShipProduct>? products;
      if (productsData == null || productsData.isEmpty) {
        print('🔄 Cache miss, fetching from ApiService...');
        products = await _apiService.getFreeShipProducts();
      } else {
        print('🚚 Using cached freeship products data');
        // Convert cached data to FreeShipProduct list
        products = productsData.map((data) {
          print('🔍 Converting cached data: ${data['id']}');
          print('  - voucherIcon: ${data['voucher_icon']}');
          print('  - freeshipIcon: ${data['freeship_icon']}');
          print('  - chinhhangIcon: ${data['chinhhang_icon']}');
          print('  - warehouseName: ${data['warehouse_name']}');
          print('  - provinceName: ${data['province_name']}');
          return FreeShipProduct.fromJson(data);
        }).toList();
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (products != null) {
            _products = products;
          } else {
            _error = 'Không thể tải danh sách sản phẩm';
          }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Miễn phí ship',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF333333)),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const RootShellBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
            SizedBox(height: 16),
            Text(
              'Đang tải sản phẩm miễn phí ship...',
              style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFF666666),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping,
              size: 64,
              color: Color(0xFF666666),
            ),
            SizedBox(height: 16),
            Text(
              'Hiện tại không có sản phẩm miễn phí ship nào',
              style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final displayedProducts = _getDisplayedProducts();

    return Column(
      children: [
        // Header với số kết quả và nút lọc
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Tìm thấy ${displayedProducts.length} sản phẩm',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showFilters ? const Color(0xFF4CAF50) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 16,
                        color: _showFilters ? Colors.white : const Color(0xFF666666),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lọc',
                        style: TextStyle(
                          fontSize: 12,
                          color: _showFilters ? Colors.white : const Color(0xFF666666),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Panel lọc
        if (_showFilters) _buildFilterPanel(),

        // Danh sách sản phẩm - Wrap 2 cột
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: _buildProductsGrid(displayedProducts),
          ),
        ),
      ],
    );
  }

  // Lấy danh sách sản phẩm đã lọc và sắp xếp
  List<FreeShipProduct> _getDisplayedProducts() {
    List<FreeShipProduct> filtered = List.from(_products);

    // Lọc theo điều kiện
    if (_onlyHasVoucher) {
      filtered = filtered.where((product) {
        // Kiểm tra cả boolean và icon voucher
        return product.voucherIcon != null && product.voucherIcon!.isNotEmpty;
      }).toList();
    }

    // Sắp xếp
    switch (_currentSort) {
      case 'price-asc':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price-desc':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating-desc':
        filtered.sort((a, b) {
          final ratingA = a.rating ?? 0.0;
          final ratingB = b.rating ?? 0.0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case 'sold-desc':
        filtered.sort((a, b) {
          final soldA = a.sold ?? 0;
          final soldB = b.sold ?? 0;
          return soldB.compareTo(soldA);
        });
        break;
      case 'relevance':
      default:
        // Giữ nguyên thứ tự từ API
        break;
    }

    return filtered;
  }

  Widget _buildProductsGrid(List<FreeShipProduct> products) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding left/right - spacing giữa 2 cột) / 2
    // Padding: 4px mỗi bên = 8px, spacing: 8px giữa 2 cột
    final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)

    return Wrap(
      spacing: 8, // Khoảng cách ngang giữa các card
      runSpacing: 8, // Khoảng cách dọc giữa các hàng
      children: products.map((product) {
        return SizedBox(
          width: cardWidth, // Width cố định cho 2 cột, height tự co giãn
          child: FreeShipProductCardHorizontal(product: product),
        );
      }).toList(),
    );
  }

  // Panel lọc
  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSortChip('relevance', 'Phù hợp', Icons.sort),
            const SizedBox(width: 8),
            _buildSortChip('price-asc', 'Giá tăng', Icons.keyboard_arrow_up),
            const SizedBox(width: 8),
            _buildSortChip('price-desc', 'Giá giảm', Icons.keyboard_arrow_down),
            const SizedBox(width: 8),
            _buildSortChip('rating-desc', 'Đánh giá', Icons.star),
            const SizedBox(width: 8),
            _buildSortChip('sold-desc', 'Bán chạy', Icons.trending_up),
            const SizedBox(width: 8),
            _buildFilterChip('hasVoucher', 'Có voucher', Icons.local_offer, _onlyHasVoucher),
          ],
        ),
      ),
    );
  }

  // Chip sắp xếp
  Widget _buildSortChip(String value, String label, IconData icon) {
    final isSelected = _currentSort == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentSort = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF666666),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : const Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Chip lọc
  Widget _buildFilterChip(String type, String label, IconData icon, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (type == 'hasVoucher') {
            _onlyHasVoucher = !_onlyHasVoucher;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4CAF50) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF666666),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.white : const Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
