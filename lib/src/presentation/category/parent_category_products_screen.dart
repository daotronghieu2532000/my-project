import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'widgets/category_product_card_horizontal.dart';
import '../common/widgets/go_top_button.dart';

class ParentCategoryProductsScreen extends StatefulWidget {
  final int parentCategoryId;
  final String parentCategoryName;

  const ParentCategoryProductsScreen({
    super.key,
    required this.parentCategoryId,
    required this.parentCategoryName,
  });

  @override
  State<ParentCategoryProductsScreen> createState() => _ParentCategoryProductsScreenState();
}

class _ParentCategoryProductsScreenState extends State<ParentCategoryProductsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  int _totalProducts = 0;
  List<int> _loadedCategories = []; // Track which categories we've loaded
  String _currentSort = 'newest'; // newest | price_asc | price_desc | popular
  bool _onlyFreeship = false;
  bool _onlyInStock = false;
  bool _onlyHasVoucher = false;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll logic
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // Helper method để parse int an toàn từ String hoặc int
  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  // Helper method để parse double an toàn
  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper method để parse bool an toàn
  bool _safeParseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) return value == 1;
    return false;
  }

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _currentPage = 1;
      });
    }

    try {
      final response = await _apiService.getProductsByParentCategory(
        parentCategoryId: widget.parentCategoryId,
        page: loadMore ? _currentPage + 1 : 1,
        limit: 150, // Tăng từ 10 lên 50
        sort: _currentSort,
      );

      if (response != null && mounted) {
        final data = response['data'];
        final rawProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
        final pagination = data['pagination'] ?? {};
        
       

        // Map API fields to UI expected fields
        final products = rawProducts.map((product) {
          try {
            final mappedProduct = {
              'id': _safeParseInt(product['id']),
              'name': product['tieu_de']?.toString() ?? 'Sản phẩm',
              'image': product['minh_hoa']?.toString() ?? '',
              'price': _safeParseInt(product['gia_moi']),
              'old_price': _safeParseInt(product['gia_cu']),
              'discount_percent': _safeParseInt(product['discount_percent']),
              'rating': _safeParseDouble(product['rating'] ?? product['average_rating'] ?? product['avg_rating']),
              'reviews_count': _safeParseInt(product['reviews_count'] ?? product['total_reviews']),
              'total_reviews': _safeParseInt(product['reviews_count'] ?? product['total_reviews']),
              'sold': _safeParseInt(product['ban'] ?? product['sold_count']),
              'sold_count': _safeParseInt(product['ban'] ?? product['sold_count']),
              'view': _safeParseInt(product['view']),
              'shop_id': product['shop']?.toString() ?? '',
              'shop_name': product['shop_name']?.toString() ?? 'Shop',
              'is_freeship': _safeParseBool(product['isFreeship']),
              'hasVoucher': _safeParseBool(product['hasVoucher']),
              'badges': product['badges'] ?? [],
              'voucher_icon': product['voucher_icon']?.toString(),
              'freeship_icon': product['freeship_icon']?.toString(),
              'chinhhang_icon': product['chinhhang_icon']?.toString(),
              'warehouse_name': product['warehouse_name']?.toString(),
              'province_name': product['province_name']?.toString(),
              'link': product['link']?.toString() ?? '',
              'date_post': product['date_post']?.toString() ?? '',
              'kho': _safeParseInt(product['kho']),
              'thuong_hieu': product['thuong_hieu']?.toString() ?? '',
              'noi_ban': product['noi_ban']?.toString() ?? '',
              'cat': product['cat']?.toString() ?? '',
              'status': product['status'] != null ? _safeParseInt(product['status']) : 1,
            };
            return mappedProduct;
          } catch (e) {
         
            rethrow;
          }
        }).toList();

        // Get included categories for tracking
        final includedCategories = List<int>.from(data['filters']['included_categories'] ?? []);
        
        setState(() {
          if (loadMore) {
            _products.addAll(products);
            _currentPage++;
            _loadedCategories.addAll(includedCategories);
          } else {
            _products = products;
            _currentPage = 1;
            _loadedCategories = includedCategories;
          }
          
          _hasNextPage = _safeParseBool(pagination['has_next']) != false ? _safeParseBool(pagination['has_next']) : false;
          _totalProducts = _safeParseInt(pagination['total_products']) != 0 ? _safeParseInt(pagination['total_products']) : (_safeParseInt(pagination['total']) != 0 ? _safeParseInt(pagination['total']) : 0);
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Không thể tải dữ liệu';
        });
      }
    } catch (e) {
    
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Có lỗi xảy ra khi tải dữ liệu';
      });
    }
  }

  void _onSortChanged(String sort) {
    if (sort != _currentSort) {
      setState(() {
        _currentSort = sort;
      });
      _loadProducts();
    }
  }

  Future<void> _onRefresh() async {
    await _loadProducts();
  }

  void _loadMore() {
    if (!_isLoadingMore && _hasNextPage) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadMoreProducts() async {
    setState(() {
      _isLoadingMore = true;
    });
      
    try {
      // Use the new smart loading method
      final response = await _apiService.loadMoreProductsFromParentCategory(
        parentCategoryId: widget.parentCategoryId,
        alreadyLoadedCategories: _loadedCategories,
        page: _currentPage + 1,
        limit: 150, // Tăng từ 10 lên 50
        sort: _currentSort,
      );
      
      if (response != null && mounted) {
        final data = response['data'];
        final rawProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
        final pagination = data['pagination'] ?? {};
        final includedCategories = List<int>.from(data['filters']['included_categories'] ?? []);
        
        // Map API fields to UI expected fields
        final products = rawProducts.map((product) {
          try {
            return {
              'id': _safeParseInt(product['id']),
              'name': product['tieu_de']?.toString() ?? 'Sản phẩm',
              'image': product['minh_hoa']?.toString() ?? '',
              'price': _safeParseInt(product['gia_moi']),
              'old_price': _safeParseInt(product['gia_cu']),
              'discount_percent': _safeParseInt(product['discount_percent']),
              'rating': _safeParseDouble(product['rating'] ?? product['average_rating'] ?? product['avg_rating']),
              'reviews_count': _safeParseInt(product['reviews_count'] ?? product['total_reviews']),
              'total_reviews': _safeParseInt(product['reviews_count'] ?? product['total_reviews']),
              'sold': _safeParseInt(product['ban'] ?? product['sold_count']),
              'sold_count': _safeParseInt(product['ban'] ?? product['sold_count']),
              'view': _safeParseInt(product['view']),
              'shop_id': product['shop']?.toString() ?? '',
              'shop_name': product['shop_name']?.toString() ?? 'Shop',
              'is_freeship': _safeParseBool(product['isFreeship']),
              'hasVoucher': _safeParseBool(product['hasVoucher']),
              'badges': product['badges'] ?? [],
              'voucher_icon': product['voucher_icon']?.toString(),
              'freeship_icon': product['freeship_icon']?.toString(),
              'chinhhang_icon': product['chinhhang_icon']?.toString(),
              'warehouse_name': product['warehouse_name']?.toString(),
              'province_name': product['province_name']?.toString(),
              'link': product['link']?.toString() ?? '',
              'date_post': product['date_post']?.toString() ?? '',
              'kho': _safeParseInt(product['kho']),
              'thuong_hieu': product['thuong_hieu']?.toString() ?? '',
              'noi_ban': product['noi_ban']?.toString() ?? '',
              'cat': product['cat']?.toString() ?? '',
              'status': product['status'] != null ? _safeParseInt(product['status']) : 1,
            };
          } catch (e) {
          
            rethrow;
          }
        }).toList();
        
        setState(() {
          _products.addAll(products);
          _currentPage++;
          _loadedCategories.addAll(includedCategories);
          _hasNextPage = _safeParseBool(pagination['has_next']) != false ? _safeParseBool(pagination['has_next']) : false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
          _hasNextPage = false;
        });
      }
    } catch (e) {
     
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          bottom: false,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    widget.parentCategoryName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Filter button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _showFilters ? Theme.of(context).colorScheme.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune,
                      size: 18,
                      color: _showFilters ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          // Go Top Button
          GoTopButton(
            scrollController: _scrollController,
            showAfterScrollDistance: 1000.0, // Khoảng 2.5 màn hình
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _onRefresh,
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
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Không có sản phẩm nào',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
      );
    }

    return Column(
      children: [
        // Header với số kết quả và icon lọc
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tìm thấy ${_totalProducts > 0 ? _totalProducts : _products.length} sản phẩm',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showFilters ? Theme.of(context).colorScheme.primary : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 16,
                        color: _showFilters ? Colors.white : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lọc',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _showFilters ? Colors.white : Colors.grey[600],
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
          child: RefreshIndicator(
            onRefresh: _onRefresh,
          child: SingleChildScrollView(
                                controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Align(
              alignment: Alignment.topLeft,
              child: _buildProductsGrid(),
            ),
            ),
          ),
        ),
      ],
    );
  }

  // Build panel lọc mới
  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sắp xếp
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Sắp xếp',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildSortChip('Mới nhất', 'newest', Icons.new_releases),
                const SizedBox(width: 8),
                _buildSortChip('Giá tăng', 'price_asc', Icons.keyboard_arrow_up),
                const SizedBox(width: 8),
                _buildSortChip('Giá giảm', 'price_desc', Icons.keyboard_arrow_down),
                const SizedBox(width: 8),
                _buildSortChip('Phổ biến', 'popular', Icons.local_fire_department),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Lọc nhanh
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Lọc nhanh',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Freeship', _onlyFreeship, Icons.local_shipping, () {
                  setState(() => _onlyFreeship = !_onlyFreeship);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Còn hàng', _onlyInStock, Icons.check_circle, () {
                  setState(() => _onlyInStock = !_onlyInStock);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Có voucher', _onlyHasVoucher, Icons.local_offer, () {
                  setState(() => _onlyHasVoucher = !_onlyHasVoucher);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final bool selected = _currentSort == value;
    return GestureDetector(
      onTap: () => _onSortChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.grey[700],
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProductsGrid() {
    final filteredProducts = _filteredSorted();
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding left/right - spacing giữa 2 cột) / 2
    // Padding: 4px mỗi bên = 8px, spacing: 8px giữa 2 cột
    final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Căn trái toàn bộ nội dung
      children: [
        Wrap(
          alignment: WrapAlignment.start, // Căn trái khi chỉ có 1 sản phẩm
          spacing: 8, // Khoảng cách ngang giữa các card
          runSpacing: 8, // Khoảng cách dọc giữa các hàng
          children: filteredProducts.map((product) {
            return SizedBox(
              width: cardWidth, // Width cố định cho 2 cột, height tự co giãn
              child: CategoryProductCardHorizontal(product: product),
            );
          }).toList(),
        ),
        // Loading indicator khi đang load more
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredSorted() {
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(_products);
    
    // Lọc theo freeship - kiểm tra cả is_freeship và freeship_icon
    if (_onlyFreeship) {
      items = items.where((p) => 
        (p['is_freeship'] == true) || 
        (p['free_shipping'] == true) ||
        (p['freeship_icon'] != null && p['freeship_icon'].toString().isNotEmpty)
      ).toList();
    }
    
    // Lọc theo còn hàng
    if (_onlyInStock) {
      items = items.where((p) {
        final s = p['kho'] ?? p['stock'] ?? p['so_luong'];
        if (s is int) return s > 0;
        final si = int.tryParse('$s');
        return si == null ? true : si > 0;
      }).toList();
    }
    
    // Lọc theo có voucher - kiểm tra cả hasVoucher và voucher_icon
    if (_onlyHasVoucher) {
      items = items.where((p) => 
        (p['hasVoucher'] == true) ||
        (p['has_coupon'] == true) || 
        (p['coupon'] != null) || 
        (p['coupon_info'] != null) ||
        (p['voucher_icon'] != null && p['voucher_icon'].toString().isNotEmpty)
      ).toList();
    }
    
    // Sắp xếp
    switch (_currentSort) {
      case 'price_asc':
        items.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
        break;
      case 'price_desc':
        items.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
        break;
      case 'popular':
        items.sort((a, b) => ((b['sold'] ?? 0) as num).compareTo((a['sold'] ?? 0) as num));
        break;
      default: // newest
        // Giữ nguyên thứ tự từ API (mới nhất)
        break;
    }
    return items;
  }
}