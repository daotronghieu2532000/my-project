import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cached_api_service.dart';
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
  final CachedApiService _cachedApiService = CachedApiService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _displayedProducts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  int _totalProducts = 0;
  List<int> _loadedCategories = [];
  String _currentSort = 'newest';
  bool _onlyFreeship = false;
  bool _onlyInStock = false;
  bool _onlyHasVoucher = false;
  bool _showFilters = false;
  static const int _initialDisplayCount = 10;
  static const int _loadMoreCount = 10;
  static const int _apiLoadLimit = 50;
  bool _hasMore = true;
  bool _isAutoLoading = false;

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
    final pixels = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final threshold = maxScroll - 200;

    if (pixels >= threshold) {
      _loadMore();
    }
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  bool _safeParseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    if (value is int) return value == 1;
    return false;
  }

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (!loadMore) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _currentPage = 1;
          _hasMore = true;
          _isAutoLoading = false;
        });
      }
    }

    try {
      if (!loadMore) {
        final cachedResponse = await _cachedApiService.getProductsByParentCategoryCached(
          parentCategoryId: widget.parentCategoryId,
          page: 1,
          limit: _apiLoadLimit,
          sort: _currentSort,
          forceRefresh: false,
        );

        if (cachedResponse != null && mounted) {
          _processResponse(cachedResponse, loadMore: false);
          _loadProductsFresh();
          return;
        }
      }

      final response = await _cachedApiService.getProductsByParentCategoryCached(
        parentCategoryId: widget.parentCategoryId,
        page: loadMore ? _currentPage + 1 : 1,
        limit: _apiLoadLimit,
        sort: _currentSort,
        forceRefresh: loadMore,
      );

      if (response != null && mounted) {
        _processResponse(response, loadMore: loadMore);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Không thể tải dữ liệu';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Có lỗi xảy ra khi tải dữ liệu';
        });
      }
    }
  }

  void _processResponse(Map<String, dynamic> response, {required bool loadMore}) {
    if (!mounted) return;

    final data = response['data'];
    final rawProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
    final pagination = data['pagination'] ?? {};

    final products = rawProducts.map((product) {
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
    }).toList();

    final includedCategories = List<int>.from(data['filters']['included_categories'] ?? []);

    setState(() {
      if (loadMore) {
        final existingIds = _allProducts.map((p) => p['id']).toSet();
        final newProducts = products.where((p) => !existingIds.contains(p['id'])).toList();
        _allProducts.addAll(newProducts);
        _currentPage++;
        _loadedCategories.addAll(includedCategories);
      } else {
        _allProducts = products;
        _currentPage = 1;
        _loadedCategories = includedCategories;
        _displayedProducts = products.take(_initialDisplayCount).toList();
      }

      _hasNextPage = _safeParseBool(pagination['has_next']) != false ? _safeParseBool(pagination['has_next']) : false;
      _totalProducts = _safeParseInt(pagination['total_products']) != 0
          ? _safeParseInt(pagination['total_products'])
          : (_safeParseInt(pagination['total']) != 0 ? _safeParseInt(pagination['total']) : 0);
      _isLoading = false;
      _isLoadingMore = false;
      _hasError = false;
      _hasMore = _allProducts.length > _displayedProducts.length || _hasNextPage;
      _isAutoLoading = false;
    });

    if (mounted && !loadMore && _hasMore && _allProducts.length > _displayedProducts.length && !_isAutoLoading) {
      _isAutoLoading = true;
      Future.microtask(() {
        if (mounted && _allProducts.length > _displayedProducts.length) {
          _loadAllFromCache();
        }
      });
    }
  }

  Future<void> _loadProductsFresh() async {
    try {
      final response = await _cachedApiService.getProductsByParentCategoryCached(
        parentCategoryId: widget.parentCategoryId,
        page: 1,
        limit: _apiLoadLimit,
        sort: _currentSort,
        forceRefresh: true,
      );

      if (mounted && response != null) {
        _processResponse(response, loadMore: false);
      }
    } catch (e) {
      // Ignore
    }
  }

  void _onSortChanged(String sort) {
    if (sort != _currentSort) {
      setState(() => _currentSort = sort);
      _loadProducts();
    }
  }

  Future<void> _onRefresh() async => await _loadProducts();

  void _loadMore() {
    if (_isLoadingMore || _isLoading || !_hasMore) return;

    if (_allProducts.length > _displayedProducts.length) {
      _loadMoreProducts();
    } else if (_hasNextPage) {
      _loadMoreProductsFromApi();
    }
  }

  Future<void> _loadAllFromCache() async {
    if (_isLoadingMore || _isLoading || _allProducts.length <= _displayedProducts.length) {
      _isAutoLoading = false;
      return;
    }

    if (_isAutoLoading) return;
    _isAutoLoading = true;

    final remainingProducts = _allProducts.skip(_displayedProducts.length).toList();

    if (mounted && remainingProducts.isNotEmpty) {
      setState(() {
        _displayedProducts.addAll(remainingProducts);
        _hasMore = _hasNextPage;
        _isAutoLoading = false;
      });
    } else {
      _isAutoLoading = false;
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    if (_allProducts.length <= _displayedProducts.length) {
      if (_hasNextPage) _loadMoreProductsFromApi();
      return;
    }

    setState(() => _isLoadingMore = true);

    final additionalProducts = _allProducts.skip(_displayedProducts.length).take(_loadMoreCount).toList();

    if (mounted && additionalProducts.isNotEmpty) {
      setState(() {
        _displayedProducts.addAll(additionalProducts);
        _hasMore = _allProducts.length > _displayedProducts.length || _hasNextPage;
        _isLoadingMore = false;
      });

      if (_hasNextPage && _displayedProducts.length >= _allProducts.length - 10) {
        _loadMoreProductsFromApi();
      }
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreProductsFromApi() async {
    if (_isLoadingMore || _isLoading) return;
    setState(() => _isLoadingMore = true);

    try {
      final response = await _apiService.loadMoreProductsFromParentCategory(
        parentCategoryId: widget.parentCategoryId,
        alreadyLoadedCategories: _loadedCategories,
        page: _currentPage + 1,
        limit: _apiLoadLimit,
        sort: _currentSort,
      );

      if (response != null && mounted) {
        final data = response['data'];
        final rawProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
        final pagination = data['pagination'] ?? {};
        final includedCategories = List<int>.from(data['filters']['included_categories'] ?? []);

        final products = rawProducts.map((product) {
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
        }).toList();

        final existingIds = _allProducts.map((p) => p['id']).toSet();
        final newProducts = products.where((p) => !existingIds.contains(p['id'])).toList();

        setState(() {
          _allProducts.addAll(newProducts);
          _currentPage++;
          _loadedCategories.addAll(includedCategories);
          _hasNextPage = _safeParseBool(pagination['has_next']) != false ? _safeParseBool(pagination['has_next']) : false;
          _isLoadingMore = false;
          _hasMore = _allProducts.length > _displayedProducts.length || _hasNextPage;
        });

        if (mounted && _hasMore && _allProducts.length > _displayedProducts.length && !_isAutoLoading) {
          _isAutoLoading = true;
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _allProducts.length > _displayedProducts.length) {
              _loadAllFromCache();
            }
          });
        }
      } else {
        setState(() {
          _isLoadingMore = false;
          _hasNextPage = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoading && !_isLoadingMore && !_isAutoLoading && _hasMore && _displayedProducts.isNotEmpty && _allProducts.length > _displayedProducts.length) {
        _isAutoLoading = true;
        Future.microtask(() {
          if (mounted && _allProducts.length > _displayedProducts.length) {
            _loadAllFromCache();
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          bottom: false,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.grey[700]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.parentCategoryName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _showFilters = !_showFilters),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _showFilters ? Theme.of(context).colorScheme.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tune, size: 18, color: _showFilters ? Colors.white : Colors.grey[700]),
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
          GoTopButton(scrollController: _scrollController, showAfterScrollDistance: 1000.0),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage, style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _onRefresh, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_displayedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Không có sản phẩm nào', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tìm thấy ${_totalProducts > 0 ? _totalProducts : _allProducts.length} sản phẩm',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF666666)),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showFilters = !_showFilters),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showFilters ? Theme.of(context).colorScheme.primary : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 16, color: _showFilters ? Colors.white : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('Lọc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _showFilters ? Colors.white : Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showFilters) _buildFilterPanel(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Align(alignment: Alignment.topLeft, child: _buildProductsGrid()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Sắp xếp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Lọc nhanh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Freeship', _onlyFreeship, Icons.local_shipping, () => setState(() => _onlyFreeship = !_onlyFreeship)),
                const SizedBox(width: 8),
                _buildFilterChip('Còn hàng', _onlyInStock, Icons.check_circle, () => setState(() => _onlyInStock = !_onlyInStock)),
                const SizedBox(width: 8),
                _buildFilterChip('Có voucher', _onlyHasVoucher, Icons.local_offer, () => setState(() => _onlyHasVoucher = !_onlyHasVoucher)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final selected = _currentSort == value;
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
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : Colors.grey[700])),
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
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    final filteredProducts = _filteredSorted(_displayedProducts);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 16) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: filteredProducts.map((product) {
            return SizedBox(width: cardWidth, child: CategoryProductCardHorizontal(product: product));
          }).toList(),
        ),
        if (_isLoadingMore) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredSorted(List<Map<String, dynamic>> products) {
    var items = List<Map<String, dynamic>>.from(products);

    if (_onlyFreeship) {
      items = items.where((p) =>
          (p['is_freeship'] == true) ||
          (p['freeship_icon']?.toString().isNotEmpty == true)).toList();
    }

    if (_onlyInStock) {
      items = items.where((p) {
        final stock = p['kho'] ?? 0;
        return stock is int ? stock > 0 : (int.tryParse('$stock') ?? 0) > 0;
      }).toList();
    }

    if (_onlyHasVoucher) {
      items = items.where((p) =>
          (p['hasVoucher'] == true) ||
          (p['voucher_icon']?.toString().isNotEmpty == true)).toList();
    }

    switch (_currentSort) {
      case 'price_asc':
        items.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
        break;
      case 'price_desc':
        items.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
        break;
      case 'popular':
        items.sort((a, b) => (b['sold'] ?? 0).compareTo(a['sold'] ?? 0));
        break;
    }
    return items;
  }
}