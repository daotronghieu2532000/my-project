import 'package:flutter/material.dart';
import 'product_card_horizontal.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/product_suggest.dart';

class ProductGrid extends StatefulWidget {
  final String title;
  final VoidCallback? onNearEnd; // Callback khi scroll gần đến cuối
  
  const ProductGrid({
    super.key, 
    required this.title,
    this.onNearEnd,
  });

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  final CachedApiService _cachedApiService = CachedApiService();
  final AuthService _authService = AuthService();
  List<ProductSuggest> _allProducts = []; // Tất cả sản phẩm đã load từ API
  List<ProductSuggest> _displayedProducts = []; // Sản phẩm đang hiển thị
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasLoadedOnce = false; // Flag để tránh load lại khi rebuild
  static const int _initialDisplayCount = 10; // Số sản phẩm hiển thị ban đầu
  static const int _loadMoreCount = 10; // Số sản phẩm load thêm mỗi lần khi scroll
  static const int _apiLoadLimit = 50; // Số sản phẩm load từ API một lần
  int _currentDisplayCount = 0; // Số sản phẩm đang hiển thị
  bool _hasMore = true; // Còn sản phẩm để hiển thị không
  int? _cachedUserId; // Cache userId để tránh gọi getCurrentUser nhiều lần

  @override
  void initState() {
    super.initState();
    // Cache userId một lần để tránh gọi getCurrentUser nhiều lần
    _cacheUserId();
    // Load từ cache ngay lập tức với 10 sản phẩm
    _loadProductSuggestsFromCache();
    // Lắng nghe sự kiện đăng nhập để refresh
    _authService.addAuthStateListener(_onAuthStateChanged);
  }
  
  /// Cache userId một lần để tránh gọi getCurrentUser nhiều lần
  Future<void> _cacheUserId() async {
    try {
      final user = await _authService.getCurrentUser();
      _cachedUserId = user?.userId;
    } catch (e) {
      _cachedUserId = null;
    }
  }

  @override
  void dispose() {
    _authService.removeAuthStateListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    // Khi đăng nhập/logout, reset flag và refresh lại
    if (mounted) {
      // Update cached userId
      _cacheUserId();
      setState(() {
        _hasLoadedOnce = false;
        _allProducts = [];
        _displayedProducts = [];
        _isLoading = true;
        _currentDisplayCount = 0;
        _hasMore = true;
      });
      _loadProductSuggestsWithRefresh();
    }
  }

  Future<void> _loadProductSuggestsFromCache() async {
    try {
      // Nếu đã load rồi và có dữ liệu, không load lại (tránh gọi API khi scroll)
      if (_hasLoadedOnce && _allProducts.isNotEmpty) {
        return;
      }
      
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Sử dụng cached userId để tránh gọi getCurrentUser nhiều lần
      if (_cachedUserId == null) {
        await _cacheUserId();
      }
      
      // Load nhiều sản phẩm từ API một lần (50 sản phẩm) để cache
      final suggestionsData = await _cachedApiService.getHomeSuggestions(
        limit: _apiLoadLimit,
        userId: _cachedUserId,
        forceRefresh: false, // Chỉ load từ cache
      );

      if (mounted && suggestionsData.isNotEmpty) {
        // Convert Map to ProductSuggest
        final allProducts = suggestionsData.map((data) => ProductSuggest.fromJson(data)).toList();
        
        // Chỉ hiển thị 10 sản phẩm đầu tiên
        final displayedProducts = allProducts.take(_initialDisplayCount).toList();
        
        setState(() {
          _isLoading = false;
          _allProducts = allProducts;
          _displayedProducts = displayedProducts;
          _currentDisplayCount = displayedProducts.length;
          _hasLoadedOnce = true; // Đánh dấu đã load
          // Còn sản phẩm để hiển thị nếu số sản phẩm đã load > số sản phẩm đang hiển thị
          _hasMore = allProducts.length > _currentDisplayCount;
        });
        
        // Tự động load thêm khi số sản phẩm hiển thị gần hết
        if (mounted && _hasMore && _allProducts.length > _currentDisplayCount) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _hasMore && _allProducts.length > _currentDisplayCount) {
              _loadMoreProducts();
            }
          });
        }
      
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Không có sản phẩm gợi ý';
        });
    
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
     
    }
  }

  Future<void> _loadProductSuggestsWithRefresh() async {
    try {
      if (!mounted) return;
      
      // Update cached userId
      await _cacheUserId();
      
      // Force refresh để lấy dữ liệu mới theo user_id
      final suggestionsData = await _cachedApiService.getHomeSuggestions(
        limit: _apiLoadLimit,
        userId: _cachedUserId,
        forceRefresh: true, // Force refresh khi đăng nhập
      );

      if (mounted && suggestionsData.isNotEmpty) {
        // Convert Map to ProductSuggest
        final allProducts = suggestionsData.map((data) => ProductSuggest.fromJson(data)).toList();
        
        // Chỉ hiển thị 10 sản phẩm đầu tiên
        final displayedProducts = allProducts.take(_initialDisplayCount).toList();
        
        setState(() {
          _isLoading = false;
          _allProducts = allProducts;
          _displayedProducts = displayedProducts;
          _currentDisplayCount = displayedProducts.length;
          _hasLoadedOnce = true;
          _hasMore = allProducts.length > _currentDisplayCount;
        });
        
        // Tự động load thêm khi số sản phẩm hiển thị gần hết
        if (mounted && _hasMore && _allProducts.length > _currentDisplayCount) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _hasMore && _allProducts.length > _currentDisplayCount) {
              _loadMoreProducts();
            }
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Không có sản phẩm gợi ý';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Bắt buộc cho AutomaticKeepAliveClientMixin
    
    // Tự động load thêm khi số sản phẩm hiển thị gần hết danh sách đã load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && 
          !_isLoading && 
          !_isLoadingMore && 
          _hasMore && 
          _displayedProducts.isNotEmpty &&
          _allProducts.length > _displayedProducts.length) {
        // Kiểm tra nếu còn sản phẩm để hiển thị và gần hết danh sách đã load (còn <= 10)
        final remainingInCache = _allProducts.length - _displayedProducts.length;
        if (remainingInCache > 0 && remainingInCache <= 10) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _hasMore && _allProducts.length > _displayedProducts.length) {
              _loadMoreProducts();
            }
          });
        }
      }
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _buildProductsList(),
      ],
    );
  }
  
  /// Load thêm sản phẩm khi user scroll gần đến cuối
  /// Lấy từ danh sách đã cache, không gọi API lại
  Future<void> _loadMoreProducts() async {
    // Không load nếu đang load hoặc không còn sản phẩm
    if (_isLoadingMore || _isLoading) {
      return;
    }
    
    if (!_hasMore) {
      return;
    }
    
    if (_allProducts.length <= _displayedProducts.length) {
      // Load thêm từ API nếu đã hết cache
      _loadMoreFromApi();
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
      
      if (mounted && additionalProducts.isNotEmpty) {
        setState(() {
          _displayedProducts.addAll(additionalProducts);
          _currentDisplayCount = _displayedProducts.length;
          // Còn sản phẩm để hiển thị nếu số sản phẩm đã load > số sản phẩm đang hiển thị
          _hasMore = _allProducts.length > _displayedProducts.length;
          _isLoadingMore = false;
        });
        
        // Tự động load thêm nếu còn sản phẩm trong _allProducts
        if (mounted && _hasMore && _allProducts.length > _displayedProducts.length) {
          // Tự động load thêm sau một khoảng thời gian ngắn
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _hasMore && _allProducts.length > _displayedProducts.length) {
              _loadMoreProducts();
            }
          });
        }
        
        // Load thêm từ API trong background khi gần hết danh sách đã cache (còn <= 10 sản phẩm)
        if (mounted && _hasMore && _displayedProducts.length >= _allProducts.length - 10) {
          _loadMoreFromApi();
        }
      } else {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }
  
  /// Load thêm sản phẩm từ API trong background
  Future<void> _loadMoreFromApi() async {
    try {
      // Sử dụng cached userId
      if (_cachedUserId == null) {
        await _cacheUserId();
      }
      
      // Load thêm từ API với limit lớn hơn
      final newLimit = _allProducts.length + 20; // Load thêm 20 sản phẩm
      
      final suggestionsData = await _cachedApiService.getHomeSuggestions(
        limit: newLimit,
        userId: _cachedUserId,
        forceRefresh: false,
      );
      
      if (mounted && suggestionsData.isNotEmpty) {
        final newProducts = suggestionsData.map((data) => ProductSuggest.fromJson(data)).toList();
        
        // Chỉ thêm sản phẩm mới (bỏ qua các sản phẩm đã có)
        final existingIds = _allProducts.map((p) => p.id).toSet();
        final additionalProducts = newProducts.where((p) => !existingIds.contains(p.id)).toList();
        
        if (mounted && additionalProducts.isNotEmpty) {
          setState(() {
            _allProducts.addAll(additionalProducts);
            _hasMore = _allProducts.length > _displayedProducts.length;
          });
          
          // Tự động load thêm sản phẩm mới vào danh sách hiển thị
          if (mounted && _hasMore && _allProducts.length > _displayedProducts.length) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && _hasMore && _allProducts.length > _displayedProducts.length) {
                _loadMoreProducts();
              }
            });
          }
        }
      }
    } catch (e) {
      // Ignore error, không ảnh hưởng đến UI
    }
  }

  Widget _buildProductsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadProductSuggestsFromCache,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_displayedProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.recommend_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Không có sản phẩm gợi ý',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Hiển thị dạng Wrap 2 cột - mỗi card tự co giãn theo nội dung
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding left/right - spacing giữa 2 cột) / 2
    // Padding: 4px mỗi bên = 8px, spacing: 8px giữa 2 cột
    final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          child: Wrap(
            alignment: WrapAlignment.start, // Căn trái khi chỉ có 1 sản phẩm
            spacing: 8, // Khoảng cách ngang giữa các card
            runSpacing: 8, // Khoảng cách dọc giữa các hàng
            children: [
              ..._displayedProducts.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return SizedBox(
                  width: cardWidth, // Width cố định cho 2 cột, height tự co giãn
                  child: ProductCardHorizontal(
                    product: product,
                    index: index,
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        // Hiển thị loading indicator khi đang load thêm
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
          ),
      ],
    );
  }
}
