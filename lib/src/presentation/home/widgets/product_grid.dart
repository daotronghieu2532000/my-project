import 'dart:async';
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
  final ScrollController _scrollController = ScrollController();
  
  List<ProductSuggest> _allProducts = []; // Tất cả sản phẩm đã load từ API
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasLoadedOnce = false; // Flag để tránh load lại khi rebuild
  static const int _apiLoadLimit = 50; // Số sản phẩm load từ API một lần
  static const int _maxProductsLimit = 500; // Tối đa 1000 sản phẩm
  bool _hasMore = true; // Còn sản phẩm để hiển thị không
  int? _cachedUserId; // Cache userId để tránh gọi getCurrentUser nhiều lần
  bool _isLoadingFromApi = false; // Flag để tránh gọi API nhiều lần cùng lúc
  int _lastLoadTriggerIndex = -1; // Track index cuối cùng đã trigger load để tránh load nhiều lần
  Timer? _loadMoreDebounceTimer; // Debounce timer để tránh gọi API quá nhiều
  double? _cachedScreenWidth; // Cache screenWidth để tránh tính toán lại
  double? _cachedCardWidth; // Cache cardWidth để tránh tính toán lại
  double? _cachedItemHeight; // Cache itemHeight để tránh tính toán lại

  @override
  void initState() {
    super.initState();
    // Cache userId một lần để tránh gọi getCurrentUser nhiều lần
    _cacheUserId();
    // Load từ cache ngay lập tức
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
    _scrollController.dispose();
    _loadMoreDebounceTimer?.cancel();
    // Cleanup: Clear products để giải phóng memory
    _allProducts.clear();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _onAuthStateChanged() {
    // Khi đăng nhập/logout, reset flag và refresh lại
    // QUAN TRỌNG: Giữ nguyên logic user_id/hành vi - refresh để lấy sản phẩm mới theo user mới
    if (mounted) {
      // Update cached userId
      _cacheUserId();
      setState(() {
        _hasLoadedOnce = false;
        _allProducts = [];
        _isLoading = true;
        _hasMore = true;
        _lastLoadTriggerIndex = -1;
        _cachedScreenWidth = null; // Reset cache khi refresh
        _cachedCardWidth = null;
        _cachedItemHeight = null;
      });
      // Force refresh để lấy sản phẩm mới theo user_id mới (hoặc mặc định nếu logout)
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
      // Logic: Nếu có userId → dùng user_based API, nếu không → dùng home_suggest mặc định
      final suggestionsData = await _cachedApiService.getHomeSuggestions(
        limit: _apiLoadLimit,
        userId: _cachedUserId, // QUAN TRỌNG: Giữ nguyên logic này - null = default, có giá trị = personalized
        forceRefresh: false, // Chỉ load từ cache
      );

      if (mounted && suggestionsData.isNotEmpty) {
        // Convert Map to ProductSuggest
        final allProducts = suggestionsData.map((data) => ProductSuggest.fromJson(data)).toList();
        
        setState(() {
          _isLoading = false;
          _allProducts = allProducts;
          _hasLoadedOnce = true; // Đánh dấu đã load
          // Còn sản phẩm để hiển thị nếu chưa đạt max limit
          _hasMore = allProducts.length >= _apiLoadLimit && allProducts.length < _maxProductsLimit;
        });
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
        
        setState(() {
          _isLoading = false;
          _allProducts = allProducts;
          _hasLoadedOnce = true;
          _hasMore = allProducts.length >= _apiLoadLimit && allProducts.length < _maxProductsLimit;
        });
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
  
  /// Load thêm sản phẩm từ API trong background
  Future<void> _loadMoreFromApi() async {
    // Tránh gọi API nhiều lần cùng lúc
    if (_isLoadingFromApi || _isLoading) {
      return;
    }
    
    // GIỚI HẠN: Không load thêm nếu đã đạt max limit
    if (_allProducts.length >= _maxProductsLimit) {
      setState(() {
        _hasMore = false; // Không còn sản phẩm để load
      });
      return;
    }
    
    try {
      _isLoadingFromApi = true;
      
      // Sử dụng cached userId
      if (_cachedUserId == null) {
        await _cacheUserId();
      }
      
      // Tối ưu: Chỉ load thêm 50 sản phẩm mỗi lần, không tăng limit vô hạn
      final currentCount = _allProducts.length;
      final targetCount = (currentCount ~/ 50 + 1) * 50; // Làm tròn lên bội số của 50
      final newLimit = targetCount > _maxProductsLimit ? _maxProductsLimit : targetCount;
      
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
          // GIỚI HẠN: Chỉ thêm đến max limit
          final productsToAdd = additionalProducts.take(_maxProductsLimit - _allProducts.length).toList();
          
          setState(() {
            _allProducts.addAll(productsToAdd);
            _hasMore = _allProducts.length < _maxProductsLimit && productsToAdd.length >= _apiLoadLimit;
          });
        } else {
          // Không có sản phẩm mới, đánh dấu không còn sản phẩm
          setState(() {
            _hasMore = false;
          });
        }
      } else {
        // Không có dữ liệu mới, đánh dấu không còn sản phẩm
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e) {
      // Silent fail - không làm gián đoạn UI
    } finally {
      _isLoadingFromApi = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Bắt buộc cho AutomaticKeepAliveClientMixin
    
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

    if (_allProducts.isEmpty) {
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

    // Sử dụng GridView.builder với lazy loading - chỉ render items visible
    // Đây là cách Shopee và các app lớn làm - mượt mà ngay cả với hàng nghìn sản phẩm
    
    // Cache screenWidth và các giá trị tính toán để tránh tính toán lại mỗi lần build
    final screenWidth = MediaQuery.of(context).size.width;
    if (_cachedScreenWidth != screenWidth) {
      _cachedScreenWidth = screenWidth;
      _cachedCardWidth = (screenWidth - 16) / 2; // 2 cột với spacing
      _cachedItemHeight = _cachedCardWidth! + 120; // Chiều cao ước tính của mỗi card (ảnh + text)
    }
    
    final cardWidth = _cachedCardWidth!;
    final itemHeight = _cachedItemHeight!;
    
    return GridView.builder(
      controller: _scrollController,
      shrinkWrap: true, // Quan trọng: Cho phép GridView fit trong parent ListView
      physics: const NeverScrollableScrollPhysics(), // Disable scroll riêng - để parent ListView scroll
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cột
        childAspectRatio: cardWidth / itemHeight, // Tỷ lệ width/height
        crossAxisSpacing: 8, // Khoảng cách ngang
        mainAxisSpacing: 8, // Khoảng cách dọc
      ),
      itemCount: _allProducts.length + (_isLoadingMore || _isLoadingFromApi ? 1 : 0),
      cacheExtent: 250, // Cache một số items để scroll mượt hơn (250px)
      itemBuilder: (context, index) {
        // Tự động load thêm khi render item gần cuối (còn <= 20 items)
        // Chỉ trigger một lần cho mỗi index để tránh gọi API nhiều lần
        if (index >= _allProducts.length - 20 &&
            index > _lastLoadTriggerIndex &&
            !_isLoadingFromApi &&
            !_isLoading &&
            _hasMore &&
            _allProducts.length < _maxProductsLimit) {
          _lastLoadTriggerIndex = index;
          // Debounce: Hủy timer cũ nếu có và tạo timer mới
          _loadMoreDebounceTimer?.cancel();
          _loadMoreDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && !_isLoadingFromApi && _hasMore) {
              _loadMoreFromApi();
            }
          });
        }
        
        // Hiển thị loading indicator ở cuối danh sách
        if (index == _allProducts.length) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }
        
        final product = _allProducts[index];
        // Sử dụng RepaintBoundary để tối ưu repaint - mỗi card chỉ repaint khi cần
        return RepaintBoundary(
          child: ProductCardHorizontal(
            product: product,
            index: index,
          ),
        );
      },
    );
  }
}
