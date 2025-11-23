import 'package:flutter/material.dart';
import '../../core/services/cached_api_service.dart';
import 'widgets/category_product_card_horizontal.dart';
import '../common/widgets/go_top_button.dart';

class CategoryProductsScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final CachedApiService _cachedApiService = CachedApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _allProducts = []; // Tất cả sản phẩm đã load từ API
  List<Map<String, dynamic>> _displayedProducts = []; // Sản phẩm đang hiển thị
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  int _totalProducts = 0;
  String _currentSort = 'relevance'; // relevance | price-asc | price-desc | rating-desc | sold-desc
  bool _onlyFreeship = false;
  bool _onlyInStock = false;
  bool _onlyHasVoucher = false;
  bool _showFilters = false;
  static const int _initialDisplayCount = 10; // Số sản phẩm hiển thị ban đầu
  static const int _loadMoreCount = 10; // Số sản phẩm load thêm mỗi lần khi scroll
  static const int _apiLoadLimit = 50; // Số sản phẩm load từ API một lần
  bool _hasMore = true; // Còn sản phẩm để hiển thị không

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
    final pixels = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final threshold = maxScroll - 200;
    
    if (pixels >= threshold) {
      print('🛍️ CategoryProducts: Scroll trigger - pixels: $pixels, maxScroll: $maxScroll, threshold: $threshold');
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
    final startTime = DateTime.now();
    print('🛍️ CategoryProducts: Bắt đầu _loadProducts, loadMore: $loadMore, categoryId: ${widget.categoryId}');
    
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _currentPage = 1;
        _hasMore = true;
      });
      print('🛍️ CategoryProducts: Reset state cho lần load đầu');
    }

    try {
      // Sử dụng cached API service với pagination - load nhiều sản phẩm để cache
      print('🛍️ CategoryProducts: Gọi API với page: ${loadMore ? _currentPage + 1 : 1}, limit: $_apiLoadLimit');
      final response = await _cachedApiService.getCategoryProductsWithPagination(
        categoryId: widget.categoryId,
        page: loadMore ? _currentPage + 1 : 1,
        limit: _apiLoadLimit,
        sort: _currentSort,
      );
      final apiTime = DateTime.now().difference(startTime).inMilliseconds;
      print('🛍️ CategoryProducts: API trả về sau ${apiTime}ms');

      if (response != null && mounted) {
        final data = response['data'];
        final rawProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
        final pagination = data['pagination'] ?? {};
        
        // Lưu total products từ pagination
        _totalProducts = _safeParseInt(pagination['total_products']) != 0 ? _safeParseInt(pagination['total_products']) : (_safeParseInt(pagination['total']) != 0 ? _safeParseInt(pagination['total']) : 0);

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

        setState(() {
          if (loadMore) {
            // Thêm sản phẩm mới vào _allProducts (bỏ qua trùng lặp)
            final existingIds = _allProducts.map((p) => p['id']).toSet();
            final newProducts = products.where((p) => !existingIds.contains(p['id'])).toList();
            _allProducts.addAll(newProducts);
            _currentPage++;
            print('🛍️ CategoryProducts: LoadMore - Thêm ${newProducts.length} sản phẩm mới, tổng _allProducts: ${_allProducts.length}');
          } else {
            _allProducts = products;
            _currentPage = 1;
            // Chỉ hiển thị 10 sản phẩm đầu tiên
            _displayedProducts = products.take(_initialDisplayCount).toList();
            print('🛍️ CategoryProducts: Load đầu - _allProducts: ${_allProducts.length}, _displayedProducts: ${_displayedProducts.length}');
          }
          
          _hasNextPage = _safeParseBool(pagination['has_next']) != false ? _safeParseBool(pagination['has_next']) : false;
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
          _hasMore = _allProducts.length > _displayedProducts.length || _hasNextPage;
          print('🛍️ CategoryProducts: State updated - _hasNextPage: $_hasNextPage, _hasMore: $_hasMore');
        });
        
        // KHÔNG tự động load thêm - chỉ load khi user scroll
        // Để user có trải nghiệm tốt hơn, chỉ hiển thị 10 sản phẩm đầu và chờ user scroll
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = true;
          _errorMessage = 'Không thể tải dữ liệu';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = 'Có lỗi xảy ra: $e';
      });
    }
  }

  void _onSortChanged(String sort) {
    if (sort != _currentSort) {
      setState(() {
        _currentSort = sort;
      });
      
      // Clear cache cho category này khi sort thay đổi
      _cachedApiService.clearCategoryCache(widget.categoryId);
      
      _loadProducts();
    }
  }

  void _loadMore() {
    print('🛍️ CategoryProducts: _loadMore được gọi - _isLoadingMore: $_isLoadingMore, _isLoading: $_isLoading, _hasMore: $_hasMore');
    if (_isLoadingMore || _isLoading) {
      print('🛍️ CategoryProducts: ⚠️ Đang load, bỏ qua _loadMore');
      return;
    }
    
    if (!_hasMore) {
      print('🛍️ CategoryProducts: ⚠️ Không còn sản phẩm, bỏ qua _loadMore');
      return;
    }
    
    // Nếu còn sản phẩm trong cache, load từ cache trước
    if (_allProducts.length > _displayedProducts.length) {
      print('🛍️ CategoryProducts: Còn sản phẩm trong cache (${_allProducts.length - _displayedProducts.length}), load từ cache');
      _loadMoreProducts();
    } else if (_hasNextPage) {
      // Nếu hết cache, load từ API
      print('🛍️ CategoryProducts: Hết cache, load từ API');
      _loadProducts(loadMore: true);
    } else {
      print('🛍️ CategoryProducts: ⚠️ Không có gì để load');
    }
  }
  
  /// Load thêm sản phẩm từ cache (không gọi API)
  Future<void> _loadMoreProducts() async {
    print('🛍️ CategoryProducts: _loadMoreProducts được gọi - _allProducts: ${_allProducts.length}, _displayedProducts: ${_displayedProducts.length}');
    
    if (_isLoadingMore || _isLoading) {
      print('🛍️ CategoryProducts: ⚠️ Đang load, bỏ qua _loadMoreProducts');
      return;
    }
    
    if (!_hasMore) {
      print('🛍️ CategoryProducts: ⚠️ Không còn sản phẩm, bỏ qua _loadMoreProducts');
      return;
    }
    
    if (_allProducts.length <= _displayedProducts.length) {
      // Nếu hết cache, load từ API
      print('🛍️ CategoryProducts: Hết cache (_allProducts: ${_allProducts.length} <= _displayedProducts: ${_displayedProducts.length})');
      if (_hasNextPage) {
        print('🛍️ CategoryProducts: Có _hasNextPage, gọi API');
        _loadProducts(loadMore: true);
      } else {
        print('🛍️ CategoryProducts: ⚠️ Không có _hasNextPage');
      }
      return;
    }
    
    try {
      setState(() {
        _isLoadingMore = true;
      });
      
      // Simulate delay nhỏ để UI mượt hơn
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Lấy thêm sản phẩm từ danh sách đã load (không gọi API)
      final additionalProducts = _allProducts
          .skip(_displayedProducts.length)
          .take(_loadMoreCount)
          .toList();
      
      print('🛍️ CategoryProducts: Lấy ${additionalProducts.length} sản phẩm từ cache');
      
      if (mounted && additionalProducts.isNotEmpty) {
        setState(() {
          _displayedProducts.addAll(additionalProducts);
          _hasMore = _allProducts.length > _displayedProducts.length || _hasNextPage;
          _isLoadingMore = false;
        });
        
        print('🛍️ CategoryProducts: ✅ Đã thêm ${additionalProducts.length} sản phẩm, _displayedProducts: ${_displayedProducts.length}, _hasMore: $_hasMore');
        
        // KHÔNG tự động load thêm - chỉ load khi user scroll
        // Pre-load từ API trong background khi gần hết danh sách đã cache (còn <= 10 sản phẩm)
        if (mounted && _hasMore && _hasNextPage && _displayedProducts.length >= _allProducts.length - 10) {
          print('🛍️ CategoryProducts: Gần hết cache (còn ${_allProducts.length - _displayedProducts.length}), pre-load từ API');
          _loadProducts(loadMore: true);
        }
      } else {
        print('🛍️ CategoryProducts: ⚠️ Không có sản phẩm để thêm');
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
      }
    } catch (e) {
      print('🛍️ CategoryProducts: ❌ Lỗi _loadMoreProducts: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
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
                    widget.categoryName,
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
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadProducts(),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_displayedProducts.isEmpty && !_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Không có sản phẩm nào',
              style: TextStyle(color: Colors.grey),
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
                'Tìm thấy ${_totalProducts > 0 ? _totalProducts : _allProducts.length} sản phẩm',
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
            onRefresh: () => _loadProducts(),
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
                _buildSortChip('Phù hợp', 'relevance', Icons.trending_up),
                const SizedBox(width: 8),
                _buildSortChip('Giá tăng', 'price-asc', Icons.keyboard_arrow_up),
                const SizedBox(width: 8),
                _buildSortChip('Giá giảm', 'price-desc', Icons.keyboard_arrow_down),
                const SizedBox(width: 8),
                _buildSortChip('Đánh giá', 'rating-desc', Icons.star),
                const SizedBox(width: 8),
                _buildSortChip('Bán chạy', 'sold-desc', Icons.local_fire_department),
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
    // Áp dụng filter và sort cho displayed products
    final filteredProducts = _filteredSorted(_displayedProducts);
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

  List<Map<String, dynamic>> _filteredSorted(List<Map<String, dynamic>> products) {
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(products);
    
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
      case 'price-asc':
        items.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
        break;
      case 'price-desc':
        items.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
        break;
      case 'rating-desc':
        items.sort((a, b) => ((b['rating'] ?? 0) as num).compareTo((a['rating'] ?? 0) as num));
        break;
      case 'sold-desc':
        items.sort((a, b) => ((b['sold'] ?? 0) as num).compareTo((a['sold'] ?? 0) as num));
        break;
      default:
        break;
    }
    return items;
  }

}
