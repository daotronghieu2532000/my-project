import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'product_card_horizontal.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/product_suggest.dart';

/// ProductGridSliver: Sử dụng SliverMasonryGrid để hỗ trợ 500+ items
/// 
/// Ưu điểm:
/// - TRUE lazy loading (không cần shrinkWrap)
/// - Hỗ trợ 500-1000+ items smooth
/// - Dynamic height (tự co giãn)
/// - Giống Shopee/Amazon chính xác
class ProductGridSliver extends StatefulWidget {
  const ProductGridSliver({super.key});

  @override
  State<ProductGridSliver> createState() => _ProductGridSliverState();
}

class _ProductGridSliverState extends State<ProductGridSliver> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  final CachedApiService _cachedApiService = CachedApiService();
  final AuthService _authService = AuthService();
  
  List<ProductSuggest> _allProducts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasLoadedOnce = false;
  static const int _apiLoadLimit = 50; // 50 items/lần
  static const int _maxProductsLimit = 500; // Tối đa 500 items - OK với Sliver!
  bool _hasMore = true;
  int? _cachedUserId;
  bool _isLoadingFromApi = false;
  int _lastLoadTriggerIndex = -1;
  Timer? _loadMoreDebounceTimer;

  @override
  void initState() {
    super.initState();
    _cacheUserId();
    _loadProductSuggestsFromCache();
    _authService.addAuthStateListener(_onAuthStateChanged);
  }

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
    _loadMoreDebounceTimer?.cancel();
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      _cacheUserId();
      setState(() {
        _hasLoadedOnce = false;
        _allProducts = [];
        _isLoading = true;
        _hasMore = true;
        _lastLoadTriggerIndex = -1;
      });
      _loadProductSuggestsWithRefresh();
    }
  }

  Future<void> _loadProductSuggestsFromCache() async {
    try {
      if (_hasLoadedOnce && _allProducts.isNotEmpty) return;
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (_cachedUserId == null) {
        await _cacheUserId();
      }
      
      final suggestionsData = await _cachedApiService.getHomeSuggestions(
        limit: _apiLoadLimit,
        userId: _cachedUserId,
        forceRefresh: false,
      );

      if (mounted && suggestionsData.isNotEmpty) {
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

  Future<void> _loadProductSuggestsWithRefresh() async {
    try {
      if (!mounted) return;
      
      await _cacheUserId();
      
      final suggestionsData = await _cachedApiService.getHomeSuggestions(
        limit: _apiLoadLimit,
        userId: _cachedUserId,
        forceRefresh: true,
      );

      if (mounted && suggestionsData.isNotEmpty) {
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

  Future<void> _loadMoreFromApi() async {
    if (_isLoadingFromApi || _isLoading) return;
    if (_allProducts.length >= _maxProductsLimit) {
      setState(() {
        _hasMore = false;
      });
      return;
    }
    
    try {
      _isLoadingFromApi = true;
      
      if (_cachedUserId == null) {
        await _cacheUserId();
      }
      
      final currentCount = _allProducts.length;
      final targetCount = (currentCount ~/ 50 + 1) * 50;
      final newLimit = targetCount > _maxProductsLimit ? _maxProductsLimit : targetCount;
      
      final suggestionsData = await _cachedApiService.getHomeSuggestions(
        limit: newLimit,
        userId: _cachedUserId,
        forceRefresh: false,
      );
      
      if (mounted && suggestionsData.isNotEmpty) {
        final newProducts = suggestionsData.map((data) => ProductSuggest.fromJson(data)).toList();
        
        final existingIds = _allProducts.map((p) => p.id).toSet();
        final additionalProducts = newProducts.where((p) => !existingIds.contains(p.id)).toList();
        
        if (mounted && additionalProducts.isNotEmpty) {
          final productsToAdd = additionalProducts.take(_maxProductsLimit - _allProducts.length).toList();
          
          setState(() {
            _allProducts.addAll(productsToAdd);
            _hasMore = _allProducts.length < _maxProductsLimit && productsToAdd.length >= _apiLoadLimit;
          });
        } else {
          setState(() {
            _hasMore = false;
          });
        }
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e) {
      // Silent fail
    } finally {
      _isLoadingFromApi = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(color: Colors.red),
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: Padding(
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
        ),
      );
    }

    if (_allProducts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Chưa có sản phẩm gợi ý',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // SliverMasonryGrid: TRUE lazy loading, hỗ trợ 500+ items smooth!
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8, // Khoảng cách giữa 2 cột = 8px (vừa phải)
        childCount: _allProducts.length + (_isLoadingMore || _isLoadingFromApi ? 1 : 0),
        itemBuilder: (context, index) {
        // Auto load more
        if (index >= _allProducts.length - 20 &&
            index > _lastLoadTriggerIndex &&
            !_isLoadingFromApi &&
            !_isLoading &&
            _hasMore &&
            _allProducts.length < _maxProductsLimit) {
          _lastLoadTriggerIndex = index;
          _loadMoreDebounceTimer?.cancel();
          _loadMoreDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && !_isLoadingFromApi && _hasMore) {
              _loadMoreFromApi();
            }
          });
        }
        
        // Loading indicator
        if (index == _allProducts.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.red),
            ),
          );
        }
        
        final product = _allProducts[index];
        return RepaintBoundary(
          child: ProductCardHorizontal(
            product: product,
            index: index,
          ),
        );
      },
    ),
    );
  }
}

