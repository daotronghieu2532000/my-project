import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/search_result.dart';
import '../../core/utils/format_utils.dart';
import 'widgets/search_product_card_horizontal.dart';
import '../common/widgets/go_top_button.dart';
import '../shop/shop_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final CachedApiService _cachedApiService = CachedApiService();
  final AuthService _authService = AuthService();

  SearchResult? _searchResult;
  bool _isSearching = false;
  String _currentKeyword = '';
  int _currentPage = 1;
  final int _itemsPerPage = 500; // Tăng từ 10 lên 50

  // Lọc & sắp xếp
  String _sort = 'relevance'; // relevance | price-asc | price-desc | rating-desc | sold-desc
  bool _onlyFreeship = false;
  bool _onlyInStock = false;
  bool _onlyHasVoucher = false;
  RangeValues _priceRange = const RangeValues(0, 20000000);
  bool _showFilters = false;

  // Gợi ý từ khóa
  List<String> _searchSuggestions = [];
  bool _isLoadingSuggestions = false;
  
  // Gợi ý shop
  List<ShopSuggestion> _shopSuggestions = [];
  bool _isLoadingShopSuggestions = false;
  
  // Danh mục nổi bật (có ảnh)
  List<Map<String, dynamic>> _randomCategories = [];
  bool _isLoadingCategories = false;
  
  // Lịch sử tìm kiếm
  List<String> _searchHistory = [];
  
  // Focus node cho search field
  final FocusNode _searchFocusNode = FocusNode();
  
  // Debounce timer cho search suggestions
  Timer? _debounceTimer;

  @override
  void initState() { 
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    // ✅ Load tất cả data sau khi UI đã render để không block navigation
    // Giúp màn hình hiển thị ngay lập tức, data sẽ load sau
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSearchHistory();
      _loadRandomCategoriesFromSuggestions();
      // ✅ Delay autofocus một chút để UI render trước, tránh delay khi mở keyboard
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _searchFocusNode.canRequestFocus) {
          _searchFocusNode.requestFocus();
        }
      });
    });
  }


  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Hủy timer cũ nếu có
    _debounceTimer?.cancel();
    
    final keyword = _searchController.text.trim();
    
    // Nếu keyword rỗng hoặc quá ngắn, clear suggestions ngay lập tức
    if (keyword.isEmpty || keyword.length < 2) {
      setState(() {
        _searchSuggestions = [];
        _shopSuggestions = [];
      });
      return;
    }
    
    // Debounce: chỉ gọi API sau 300ms khi user ngừng gõ
    // Giảm từ 3-5 giây xuống còn < 500ms với cache
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _searchController.text.trim() == keyword) {
        _loadSearchSuggestions(keyword);
      }
    });
  }

  void _onScroll() {
    // Infinite scroll logic
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _performSearch(String keyword, {bool isLoadMore = false}) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResult = null;
        _currentKeyword = '';
        _currentPage = 1;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      if (!isLoadMore) {
        _currentKeyword = keyword;
        _currentPage = 1;
        // Reset scroll position khi search mới
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });

    try {
      final page = isLoadMore ? _currentPage + 1 : 1;
      
      // Lấy userId để lưu search behavior
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      // Sử dụng cached API service cho search products
      final result = await _cachedApiService.searchProductsCached(
        keyword: keyword,
        page: page,
        limit: _itemsPerPage,
        userId: userId,
      );
      
      // Nếu cache không có data, fallback về ApiService
      Map<String, dynamic>? searchResult;
      if (result == null || result.isEmpty) {
        searchResult = await _apiService.searchProducts(
          keyword: keyword,
          page: page,
          limit: _itemsPerPage,
          userId: userId,
        );
      } else {
        searchResult = result;
      }

      if (searchResult != null && mounted) {
        final searchResultObj = SearchResult.fromJson(searchResult);
        
        // Nếu user đã đăng nhập và search thành công, clear cache của personalized suggestions
        // để khi quay về trang chủ, sẽ thấy gợi ý mới dựa trên search keywords
        if (userId != null && !isLoadMore) {
          _cachedApiService.clearCachePattern('home_suggestions');
        }

        setState(() {
          if (isLoadMore && _searchResult != null) {
            // Thêm sản phẩm mới vào danh sách hiện tại
            final existingProducts = List<SearchProduct>.from(
              _searchResult!.products,
            );
            existingProducts.addAll(searchResultObj.products);

            _searchResult = SearchResult(
              success: searchResultObj.success,
              products: existingProducts,
              pagination: searchResultObj.pagination,
              keyword: searchResultObj.keyword,
              searchTime: searchResultObj.searchTime,
            );
            _currentPage = page;
          } else {
            _searchResult = searchResultObj;
            _currentPage = page;
          }
          _isSearching = false;
        });

        // Thêm vào lịch sử tìm kiếm nếu có kết quả
        if (searchResultObj.products.isNotEmpty) {
          await _addToSearchHistory(keyword);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tìm kiếm: $e')));
      }
    }
  }

  void _onSearchSubmitted(String keyword) {
    // Ẩn bàn phím sau khi submit tìm kiếm
    FocusScope.of(context).unfocus();
    _performSearch(keyword);
  }

  void _onKeywordTapped(String keyword) {
    // Ẩn bàn phím khi tap vào từ khóa
    FocusScope.of(context).unfocus();
    _searchController.text = keyword;
    _performSearch(keyword);
  }

  void _loadMore() {
    if (_searchResult != null &&
        _searchResult!.pagination.hasNext &&
        !_isSearching &&
        _currentKeyword.isNotEmpty) {
      _performSearch(_currentKeyword, isLoadMore: true);
    }
  }

  // Load lịch sử tìm kiếm từ SharedPreferences
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      // Error loading search history
    }
  }

  // Save lịch sử tìm kiếm vào SharedPreferences
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (e) {
      // Error saving search history
    }
  }

  // Thêm từ khóa vào lịch sử
  Future<void> _addToSearchHistory(String keyword) async {
    if (keyword.trim().isEmpty) return;
    
    setState(() {
      // Xóa từ khóa cũ nếu có
      _searchHistory.remove(keyword);
      // Thêm vào đầu danh sách
      _searchHistory.insert(0, keyword);
      // Giới hạn tối đa 10 từ khóa
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.take(10).toList();
      }
    });
    
    // Lưu vào SharedPreferences
    await _saveSearchHistory();
  }

  // Clear lịch sử tìm kiếm
  Future<void> _clearSearchHistory() async {
    setState(() {
      _searchHistory.clear();
    });
    await _saveSearchHistory();
  }

  // Load danh mục nổi bật với ảnh từ product_suggest API (dựa trên hành vi người dùng)
  Future<void> _loadRandomCategoriesFromSuggestions() async {
    if (_isLoadingCategories) return;
    
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      // Lấy userId từ auth service
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      // Gọi API để lấy danh mục dựa trên hành vi người dùng
      // Nếu không có hành vi, API sẽ fallback về random categories
      final categories = await _apiService.getUserCategoriesSuggestions(
        userId: userId,
        limit: 4,
      );
      
      if (mounted && categories != null && categories.isNotEmpty) {
        setState(() {
          _randomCategories = categories;
          _isLoadingCategories = false;
        });
      } else {
        setState(() {
          _randomCategories = [];
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _randomCategories = [];
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadSearchSuggestions(String keyword) async {
    if (_isLoadingSuggestions) return;
    
    setState(() {
      _isLoadingSuggestions = true;
      _isLoadingShopSuggestions = true;
    });

    try {
      // Sử dụng cached API service cho search suggestions
      final suggestions = await _cachedApiService.getSearchSuggestionsCached(
        keyword: keyword,
        limit: 5,
      );
      
      // Nếu cache không có data, fallback về ApiService
      List<String>? suggestionsList;
      if (suggestions == null || suggestions.isEmpty) {
        suggestionsList = await _apiService.getSearchSuggestions(
          keyword: keyword,
          limit: 5,
        );
      } else {
        suggestionsList = suggestions;
      }
      
      // Load shop suggestions từ search products API
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      final searchResult = await _apiService.searchProducts(
        keyword: keyword,
        page: 1,
        limit: 10,
        userId: userId,
      );
      
      List<ShopSuggestion> shopSuggestionsList = [];
      if (searchResult != null && searchResult['success'] == true) {
        final data = searchResult['data'] as Map<String, dynamic>?;
        
        if (data != null && data['shops'] != null) {
          final shopsJson = data['shops'] as List<dynamic>?;
          
          if (shopsJson != null && shopsJson.isNotEmpty) {
            for (var shopJson in shopsJson) {
              try {
                final shop = ShopSuggestion.fromJson(shopJson as Map<String, dynamic>);
                shopSuggestionsList.add(shop);
              } catch (e) {
                // Error parsing shop
              }
            }
            
            // Sort shops: ưu tiên name match chính xác, sau đó có avatar
            final keywordLower = keyword.toLowerCase().trim();
            shopSuggestionsList.sort((a, b) {
              // 1. Ưu tiên name match chính xác
              final aNameLower = a.name.toLowerCase().trim();
              final bNameLower = b.name.toLowerCase().trim();
              
              final aExactMatch = aNameLower == keywordLower;
              final bExactMatch = bNameLower == keywordLower;
              if (aExactMatch != bExactMatch) {
                return aExactMatch ? -1 : 1;
              }
              
              final aStartsWith = aNameLower.startsWith(keywordLower);
              final bStartsWith = bNameLower.startsWith(keywordLower);
              if (aStartsWith != bStartsWith) {
                return aStartsWith ? -1 : 1;
              }
              
              // 2. Ưu tiên có avatar
              final aHasAvatar = a.avatar.isNotEmpty;
              final bHasAvatar = b.avatar.isNotEmpty;
              if (aHasAvatar != bHasAvatar) {
                return aHasAvatar ? -1 : 1;
              }
              
              // 3. Cuối cùng sort theo name
              return a.name.compareTo(b.name);
            });
            
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _searchSuggestions = suggestionsList ?? [];
          _shopSuggestions = shopSuggestionsList;
          _isLoadingSuggestions = false;
          _isLoadingShopSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchSuggestions = [];
          _shopSuggestions = [];
          _isLoadingSuggestions = false;
          _isLoadingShopSuggestions = false;
        });
      }
    }
  }

  void _navigateToShopDetail(ShopSuggestion shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDetailScreen(
          shopId: shop.shopId > 0 ? shop.shopId : null,
          shopUsername: shop.username.isNotEmpty ? shop.username : null,
          shopName: shop.name,
          shopAvatar: shop.avatar.isNotEmpty ? shop.avatar : null,
        ),
      ),
    );
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
                // Search field
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(
                            Icons.search,
                            size: 20,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: const InputDecoration(
                              hintText: 'Tìm kiếm sản phẩm...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 14,
                                height: 1.3,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: _onSearchSubmitted,
                            autofocus: false, // ✅ Tắt autofocus, sẽ request focus sau khi UI render
                            textInputAction: TextInputAction.search,
                            keyboardType: TextInputType.text,
                            textAlignVertical: TextAlignVertical.center,
                            maxLines: 1,
                            strutStyle: StrutStyle(height: 1.3, forceStrutHeight: true),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchResult = null;
                                _currentKeyword = '';
                                _currentPage = 1;
                                _showFilters = false;
                                _searchSuggestions = [];
                              });
                              if (_scrollController.hasClients) {
                                _scrollController.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.clear,
                                size: 18,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // TODO: Camera button - Tạm thời comment, sẽ dùng sau
                // const SizedBox(width: 12),
                // // Camera button
                // GestureDetector(
                //   onTap: () {
                //     // TODO: Implement camera search
                //   },
                //   child: Container(
                //     width: 40,
                //     height: 40,
                //     decoration: BoxDecoration(
                //       color: Colors.grey[100],
                //       borderRadius: BorderRadius.circular(12),
                //     ),
                //     child: Icon(
                //       Icons.camera_alt_outlined,
                //       size: 18,
                //       color: Colors.grey[700],
                //     ),
                //   ),
                // ),
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
    if (_searchResult != null) {
      return _buildSearchResults();
    } else {
      return _buildSearchSuggestions();
    }
  }

  Widget _buildSearchResults() {
    // Kiểm tra nếu không có sản phẩm nào
    final hasNoResults =
        _searchResult!.products.isEmpty ||
        (_searchResult!.products.length == 1 &&
            _searchResult!.products.first.name.isEmpty);

    if (hasNoResults) {
      return _buildNoResults();
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
                 'Tìm thấy ${_searchResult!.pagination.total > 0 ? _searchResult!.pagination.total : _searchResult!.products.length} kết quả cho "$_currentKeyword"',
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
            onRefresh: () => _performSearch(_currentKeyword),
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                // Khi user scroll, ẩn bàn phím và unfocus search field
                if (notification is ScrollUpdateNotification) {
                  FocusScope.of(context).unfocus();
                }
                return false;
              },
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
                const SizedBox(width: 8),
                _buildActionChip('Khoảng giá', Icons.price_check, _showPriceFilter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final bool selected = _sort == value;
    return GestureDetector(
      onTap: () => setState(() => _sort = value),
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

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lấy danh sách sau khi áp dụng lọc/sắp xếp
  List<SearchProduct> _getDisplayedProducts() {
    List<SearchProduct> items = List<SearchProduct>.from(
      _searchResult!.products,
    );
    
    // Lọc theo freeship - kiểm tra cả isFreeship và freeshipIcon
    if (_onlyFreeship) {
      items = items.where((p) => p.isFreeship || (p.freeshipIcon != null && p.freeshipIcon!.isNotEmpty)).toList();
    }
    
    // Lọc theo còn hàng
    if (_onlyInStock) {
      items = items.where((p) => p.inStock).toList();
    }
    
    // Lọc theo có voucher - kiểm tra cả hasVoucher và voucherIcon
    if (_onlyHasVoucher) {
      items = items.where((p) => p.hasVoucher || (p.voucherIcon != null && p.voucherIcon!.isNotEmpty)).toList();
    }
    
    // Lọc theo khoảng giá
    items = items
        .where(
          (p) =>
              p.price >= _priceRange.start.round() &&
              p.price <= _priceRange.end.round(),
        )
        .toList();
    
    // Sắp xếp
    switch (_sort) {
      case 'price-asc':
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price-desc':
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating-desc':
        items.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'sold-desc':
        items.sort((a, b) => b.sold.compareTo(a.sold));
        break;
      default:
        break;
    }
    return items;
  }

  Widget _buildProductsGrid() {
    final displayedProducts = _getDisplayedProducts();
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
          children: displayedProducts.map((product) {
            return SizedBox(
              width: cardWidth, // Width cố định cho 2 cột, height tự co giãn
              child: SearchProductCardHorizontal(product: product),
            );
          }).toList(),
        ),
        // Loading indicator khi đang search
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  void _showPriceFilter() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        RangeValues temp = _priceRange;
        return StatefulBuilder(
          builder: (ctx, setM) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khoảng giá',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    min: 0,
                    max: 20000000,
                    divisions: 200,
                    labels: RangeLabels(
                      FormatUtils.formatCurrency(temp.start.round()),
                      FormatUtils.formatCurrency(temp.end.round()),
                    ),
                    values: temp,
                    onChanged: (v) => setM(() => temp = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(FormatUtils.formatCurrency(temp.start.round())),
                      Text(FormatUtils.formatCurrency(temp.end.round())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _priceRange = const RangeValues(0, 20000000);
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Đặt lại'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _priceRange = temp;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Áp dụng'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }




  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.search_off,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
          Text(
            'Không tìm thấy kết quả',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
                color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thử tìm kiếm với từ khóa khác',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
          ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchResult = null;
                _currentKeyword = '';
                _currentPage = 1;
                _showFilters = false;
                _searchSuggestions = [];
              });
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Tìm kiếm lại',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Khi user scroll, ẩn bàn phím và unfocus search field
        if (notification is ScrollUpdateNotification) {
          FocusScope.of(context).unfocus();
        }
        return false;
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
        // Hiển thị gợi ý từ khóa nếu đang nhập
        if (_searchController.text.isNotEmpty && _searchSuggestions.isNotEmpty) ...[
          _SectionTitle(icon: Icons.lightbulb_outline, title: 'Gợi ý từ khóa'),
          const SizedBox(height: 12),
          _SearchSuggestionsList(
            suggestions: _searchSuggestions, 
            onTap: _onKeywordTapped,
            isLoading: _isLoadingSuggestions,
          ),
          const SizedBox(height: 24),
        ],
        // Hiển thị gợi ý shop nếu đang nhập
        Builder(
          builder: (context) {
            if (_searchController.text.isNotEmpty) {
              if (_isLoadingShopSuggestions) {
                return Column(
                  children: [
                    _SectionTitle(icon: Icons.store, title: 'Shops'),
                    const SizedBox(height: 12),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              } else if (_shopSuggestions.isNotEmpty) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SectionTitle(icon: Icons.store, title: 'Shops'),
                        ),
                        if (_shopSuggestions.length > 4)
                          GestureDetector(
                            onTap: () {
                              // TODO: Navigate to shop search results page
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                'Xem tất cả >',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ShopSuggestionsList(
                      shops: _shopSuggestions,
                      isLoading: _isLoadingShopSuggestions,
                      onTap: (shop) {
                        _navigateToShopDetail(shop);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
        // Hiển thị lịch sử tìm kiếm nếu có
        if (_searchHistory.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: _SectionTitle(icon: Icons.history, title: 'Lịch sử tìm kiếm'),
              ),
              GestureDetector(
                onTap: _clearSearchHistory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.clear_all,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Xóa',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SearchHistoryList(history: _searchHistory, onTap: _onKeywordTapped),
          const SizedBox(height: 24),
        ],
        // Hiển thị 4 danh mục nổi bật
        if (_randomCategories.isNotEmpty) ...[
          _SectionTitle(icon: Icons.category_outlined, title: 'Danh mục nổi bật'),
          const SizedBox(height: 12),
          _RandomCategoriesGrid(
            categories: _randomCategories,
            isLoading: _isLoadingCategories,
            onTap: (category) => _onKeywordTapped(category['name'] ?? ''),
          ),
          const SizedBox(height: 24),
        ],
        // Hiển thị từ khóa phổ biến
        _SectionTitle(icon: Icons.trending_up, title: 'Từ khóa phổ biến'),
        const SizedBox(height: 12),
        _KeywordGrid(onTap: _onKeywordTapped),
        const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }
}

class _SearchSuggestionsList extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onTap;
  final bool isLoading;

  const _SearchSuggestionsList({
    required this.suggestions, 
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: suggestions.map((suggestion) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              suggestion,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
            ),
            onTap: () => onTap(suggestion),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        );
      }).toList(),
    );
  }
}

class _SearchHistoryList extends StatelessWidget {
  final List<String> history;
  final Function(String) onTap;

  const _SearchHistoryList({required this.history, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Chỉ hiển thị 4 item đầu tiên
    final limitedHistory = history.take(4).toList();

    return Column(
      children: limitedHistory.map((keyword) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.history,
                size: 18,
                color: Colors.grey[600],
              ),
            ),
            title: Text(
              keyword,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
            ),
            onTap: () => onTap(keyword),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        );
      }).toList(),
    );
  }
}

class _RandomCategoriesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final bool isLoading;
  final Function(Map<String, dynamic>) onTap;

  const _RandomCategoriesGrid({
    required this.categories,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 100,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemBuilder: (context, i) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 100,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, i) => _RandomCategoryItem(
        category: categories[i],
        onTap: () => onTap(categories[i]),
      ),
    );
  }
}

class _RandomCategoryItem extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onTap;

  const _RandomCategoryItem({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = category['name']?.toString() ?? category['cat_tieude']?.toString() ?? '';
    
    // Lấy ảnh từ các nguồn: thumb_url > image_url > cat_minhhoa
    String? imageUrl;
    if (category['thumb_url'] != null && category['thumb_url'].toString().isNotEmpty) {
      imageUrl = category['thumb_url'].toString();
    } else if (category['image_url'] != null && category['image_url'].toString().isNotEmpty) {
      imageUrl = category['image_url'].toString();
    } else if (category['cat_minhhoa'] != null && category['cat_minhhoa'].toString().isNotEmpty) {
      final minhhoa = category['cat_minhhoa'].toString();
      // Nếu không có https:// thì thêm domain
      imageUrl = minhhoa.startsWith('http') ? minhhoa : 'https://socdo.vn/$minhhoa';
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hiển thị ảnh nếu có, nếu không thì hiển thị icon mặc định
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) {
                    // Fallback về icon nếu load ảnh lỗi
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                  placeholder: (context, url) {
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.category,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeywordGrid extends StatelessWidget {
  final Function(String) onTap;

  const _KeywordGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = ['dầu gội', 'nước giặt', 'chảo', 'điện gia dụng'];

    // Chỉ hiển thị 4 item đầu tiên
    final limitedItems = items.take(4).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: limitedItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 80,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, i) =>
          _KeywordItem(limitedItems[i], onTap: () => onTap(limitedItems[i])),
    );
  }
}

class _KeywordItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _KeywordItem(this.title, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.search,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopSuggestionsList extends StatelessWidget {
  final List<ShopSuggestion> shops;
  final bool isLoading;
  final Function(ShopSuggestion) onTap;

  const _ShopSuggestionsList({
    required this.shops,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (shops.isEmpty) {
      return const SizedBox.shrink();
    }

    // Chỉ hiển thị tối đa 4 shop đầu tiên
    final displayShops = shops.take(4).toList();

    return Column(
      children: displayShops.map((shop) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ClipOval(
              child: shop.avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: shop.avatar,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) {
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorWidget: (context, url, error) {
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.store,
                            size: 24,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.store,
                        size: 24,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
            title: Text(
              shop.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
            ),
            onTap: () {
              onTap(shop);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      }).toList(),
    );
  }
}

