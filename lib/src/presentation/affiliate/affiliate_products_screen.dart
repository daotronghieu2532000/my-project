import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../core/models/affiliate_product.dart';
import '../../core/services/affiliate_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/format_utils.dart';
import '../product/product_detail_screen.dart';
import '../common/widgets/go_top_button.dart';


class AffiliateProductsScreen extends StatefulWidget {
  const AffiliateProductsScreen({super.key});

  @override
  State<AffiliateProductsScreen> createState() => _AffiliateProductsScreenState();
}

class _AffiliateProductsScreenState extends State<AffiliateProductsScreen> {
  final AffiliateService _affiliateService = AffiliateService();
  final AuthService _authService = AuthService();

  final ScrollController _scrollController = ScrollController();
  List<AffiliateProduct> _products = [];
  List<AffiliateProduct> _filteredProducts = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final Map<int, bool> _followBusy = {}; // spId -> loading
  int? _currentUserId; // User ID của người đang đăng nhập

  // Filters & search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyFollowed = false;
  bool _onlyHasLink = false;
  String _sortBy = 'newest';
  bool _isFilterVisible = false;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  // Lấy thông tin user đang đăng nhập
  Future<void> _initUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUserId = user?.userId;
    });
    _loadProducts();
  }

  // Build affiliate URL with utm_source_shop for current user
  String _buildAffiliateUrl(AffiliateProduct product) {
    final userId = _currentUserId ?? 0;
    final base = product.productUrl;
    final separator = base.contains('?') ? '&' : '?';
    return '$base${separator}utm_source_shop=$userId';
  }

  // Reusable link row widget (copy to clipboard)
  Widget _buildLinkRow(String url) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 12, color: Color(0xFF6C757D)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              url,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF495057),
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Đã copy link!'),
                  backgroundColor: const Color(0xFF28A745),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
            child: const Icon(Icons.copy, size: 12, color: Color(0xFF6C757D)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _products = [];
        _hasMoreData = true;
      });
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Sử dụng cached API service cho products
      print('🔍 Starting _loadProducts: refresh=$refresh, page=$_currentPage');
      print('🔍 User ID: $_currentUserId');
      print('🔍 Search query: "$_searchQuery"');
      print('🔍 Sort by: $_sortBy');
      print('🔍 Only following: $_onlyFollowed');
      
      // Không dùng cache, gọi API trực tiếp để đảm bảo data luôn mới nhất
      print('🔄 Fetching from AffiliateService (no cache)...');
      final result = await _affiliateService.getProducts(
        userId: _currentUserId,
        page: _currentPage,
        limit: 300,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        onlyFollowing: _onlyFollowed,
      );
     
      
      // print('🔍 Final result: $result');
      // print('🔍 Final result products: ${result?['products']?.length ?? 0}');
      
      if (mounted) {
        setState(() {
          if (result != null && result['products'] != null) {
            final newProducts = result['products'] as List<AffiliateProduct>;
            print('📦 Loaded ${newProducts.length} products from API');
            if (refresh) {
              _products = newProducts;
            } else {
              _products.addAll(newProducts);
            }
            _applyFilters();
            
            final pagination = result['pagination'];
            _hasMoreData = _currentPage < pagination['total_pages'];
            _currentPage++;
            
            // Debug: Check if products have links
            // for (final product in newProducts) {
            //   print('📦 Product ${product.id}: hasLink=${product.hasLink}, shortLink=${product.shortLink}');
            // }
          } else {
            print('❌ No products found in result: $result');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi khi tải dữ liệu: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    // Server-side filtering: chỉ áp dụng client-side cho follow/link filters
    List<AffiliateProduct> list = List.of(_products);

    if (_onlyFollowed) {
      list = list.where((p) => p.isFollowing).toList();
    }
    if (_onlyHasLink) {
      list = list.where((p) => p.hasLink).toList();
    }

    setState(() {
      _filteredProducts = list;
    });
  }


  Future<void> _createAffiliateLink(AffiliateProduct product) async {
    try {
      print('🟠 [UI] Rút gọn link cho sp_id=${product.id}');
      print('🧩 [UI] productUrl: ${product.productUrl}');
      print('🧩 [UI] affiliateUrl: ${_buildAffiliateUrl(product)}');
      final longAffiliate = _buildAffiliateUrl(product);
      final result = await _affiliateService.createLink(
        userId: _currentUserId ?? 0,
        spId: product.id,
        fullLink: longAffiliate, // gửi luôn link có utm_source_shop cho server
      );

      if (mounted) {
        print('🔗 [UI] Create Link Result: $result');
        if (result != null && result['short_link'] != null) {
          final short = result['short_link'] as String;
          final longUrl = _buildAffiliateUrl(product);
          print('✅ [UI] short_link=$short');
          print('✅ [UI] expected_redirect=$longUrl');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo link: $short'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: short));
                },
              ),
            ),
          );
          // Cập nhật ngay sản phẩm hiện tại, không reload trang
          final index = _products.indexWhere((p) => p.id == product.id);
          if (index != -1) {
            final updated = _cloneWithShortLink(_products[index], short);
            setState(() {
              _products[index] = updated;
              final fIndex = _filteredProducts.indexWhere((p) => p.id == updated.id);
              if (fIndex != -1) {
                _filteredProducts[fIndex] = updated;
              } else {
                _applyFilters();
              }
            });
          }
          // Mở dialog chia sẻ luôn để trải nghiệm nhanh
          _showShareDialog(product);
        } else {
          print('❌ [UI] Create link fail or missing short_link');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tạo link thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        print('❌ [UI] Exception when creating link: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Tạo bản sao AffiliateProduct với shortLink mới (tránh reload danh sách)
  AffiliateProduct _cloneWithShortLink(AffiliateProduct src, String shortLink) {
    return AffiliateProduct(
      id: src.id,
      name: src.name,
      slug: src.slug,
      image: src.image,
      price: src.price,
      oldPrice: src.oldPrice,
      discountPercent: src.discountPercent,
      shopId: src.shopId,
      categoryIds: src.categoryIds,
      brandId: src.brandId,
      brandName: src.brandName,
      productUrl: src.productUrl,
      commissionInfo: src.commissionInfo,
      shortLink: shortLink,
      campaignName: src.campaignName,
      priceFormatted: src.priceFormatted,
      oldPriceFormatted: src.oldPriceFormatted,
      isFeatured: src.isFeatured,
      isFlashSale: src.isFlashSale,
      createdAt: src.createdAt,
      updatedAt: src.updatedAt,
      isFollowing: src.isFollowing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản phẩm Affiliate'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _loadProducts(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
              });
            },
            icon: Icon(
              _isFilterVisible ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
              color: _hasActiveFilters() ? const Color(0xFFFF6B35) : null,
            ),
            tooltip: _isFilterVisible ? 'Ẩn bộ lọc' : 'Hiện bộ lọc',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter Panel
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _isFilterVisible ? null : 0,
                child: _isFilterVisible ? _buildModernFilterPanel() : const SizedBox.shrink(),
              ),
              
              // Main Content
              Expanded(
                child: _isLoading && _products.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _loadProducts(refresh: true),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          )
                        : _filteredProducts.isEmpty
                            ? Center(
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
                                      'Không có sản phẩm affiliate',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Hiện tại chưa có sản phẩm nào trong chương trình affiliate',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => _loadProducts(refresh: true),
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(bottom: 12),
                                  itemCount: _filteredProducts.length + (_hasMoreData ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _filteredProducts.length) {
                                      // Load more indicator
                                      if (_hasMoreData && !_isLoading) {
                                        _loadProducts();
                                      }
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(child: CircularProgressIndicator()),
                                      );
                                    }

                                    final product = _filteredProducts[index];
                                    return _buildProductCard(product);
                                  },
                                ),
                              ),
              ),
            ],
          ),
          // Go Top Button
          GoTopButton(
            scrollController: _scrollController,
            showAfterScrollDistance: 1000.0, // Khoảng 2.5 màn hình
          ),
        ],
      ),
    );
  }



  Widget _buildProductCard(AffiliateProduct product) {
    // Calculate commission range based on price variants
    final commissionRange = _calculateCommissionRange(product);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal layout: image left, info right
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image only (badge removed by request)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        product.image,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 110,
                            height: 110,
                            color: const Color(0xFFF5F5F5),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 32,
                                color: Color(0xFF999999),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info right
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF333333),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Follow checkbox
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: _followBusy[product.id] == true
                                ? const CircularProgressIndicator(strokeWidth: 2)
                                : Checkbox(
                                    activeColor: const Color(0xFFFF6B35),
                                    value: product.isFollowing, // Sử dụng trạng thái từ API
                                    onChanged: (v) async {
                                      setState(() { _followBusy[product.id] = true; });
                                      final result = await _affiliateService.toggleFollow(
                                        userId: _currentUserId ?? 0,
                                        spId: product.id,
                                        shopId: product.shopId,
                                        follow: v ?? false,
                                      );
                                      if (!mounted) return;
                                      setState(() { _followBusy[product.id] = false; });
                                      
                                      // Cập nhật trạng thái follow trong danh sách
                                      if (result != null && result['success'] == true) {
                                        final index = _products.indexWhere((p) => p.id == product.id);
                                        if (index != -1) {
                                          final updatedProduct = AffiliateProduct(
                                            id: product.id,
                                            name: product.name,
                                            slug: product.slug,
                                            image: product.image,
                                            price: product.price,
                                            oldPrice: product.oldPrice,
                                            discountPercent: product.discountPercent,
                                            shopId: product.shopId,
                                            categoryIds: product.categoryIds,
                                            brandId: product.brandId,
                                            brandName: product.brandName,
                                            productUrl: product.productUrl,
                                            commissionInfo: product.commissionInfo,
                                            shortLink: product.shortLink,
                                            campaignName: product.campaignName,
                                            priceFormatted: product.priceFormatted,
                                            oldPriceFormatted: product.oldPriceFormatted,
                                            isFeatured: product.isFeatured,
                                            isFlashSale: product.isFlashSale,
                                            createdAt: product.createdAt,
                                            updatedAt: product.updatedAt,
                                            isFollowing: v ?? false, // Cập nhật trạng thái follow
                                          );
                                          setState(() {
                                            _products[index] = updatedProduct;
                                            final fIndex = _filteredProducts.indexWhere((p) => p.id == updatedProduct.id);
                                            if (fIndex != -1) {
                                              _filteredProducts[fIndex] = updatedProduct;
                                            } else {
                                              _applyFilters();
                                            }
                                          });
                                        }
                                      }
                                      
                                      // Hiển thị thông báo
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(v == true ? 'Đã theo dõi sản phẩm' : 'Đã bỏ theo dõi'),
                                          backgroundColor: v == true ? Colors.green : Colors.orange,
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            FormatUtils.formatCurrency(product.price.toInt()),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                          if (product.oldPrice > product.price) ...[
                            const SizedBox(width: 8),
                            Text(
                              FormatUtils.formatCurrency(product.oldPrice.toInt()),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF999999),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product.oldPrice > product.price) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            'GIẢM ${((product.oldPrice - product.price) / product.oldPrice * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE1F5FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Commission percent tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                product.mainCommission, // e.g. 9%
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Money range with right arrow to higher value
                            Text(
                              commissionRange.replaceAll('↓', '→'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons + link block wrapped to avoid bracket mismatches
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(productId: product.id),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            'Xem chi tiết',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: product.hasLink ? const Color(0xFF1976D2) : const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: TextButton(
                          onPressed: product.hasLink
                              ? () => _showShareDialog(product)
                              : () => _createAffiliateLink(product),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            product.hasLink ? 'Chia sẻ' : 'Rút gọn link & Chia sẻ',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Always show long affiliate URL (with utm_source_shop)
                const SizedBox(height: 8),
                _buildLinkRow(_buildAffiliateUrl(product)),

                // Show short link if available
                if (product.hasLink) ...[
                  const SizedBox(height: 6),
                  _buildLinkRow(product.shortLink!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateCommissionRange(AffiliateProduct product) {
    if (product.commissionInfo.isEmpty) {
      return 'Hoa hồng: ${product.mainCommission}';
    }
    
    // Calculate commission range based on actual commission info
    final commissions = <double>[];
    
    for (final commission in product.commissionInfo) {
      if (commission.type == 'phantram') {
        // Percentage commission - calculate based on price range
        final minPrice = product.price;
        final maxPrice = product.oldPrice > product.price ? product.oldPrice : product.price * 1.2;
        
        final minCommission = (minPrice * commission.value / 100).round();
        final maxCommission = (maxPrice * commission.value / 100).round();
        
        commissions.addAll([minCommission.toDouble(), maxCommission.toDouble()]);
      } else {
        // Fixed amount commission
        commissions.add(commission.value);
      }
    }
    
    if (commissions.isEmpty) {
      return 'Hoa hồng: ${product.mainCommission}';
    }
    
    commissions.sort();
    final minCommission = commissions.first;
    final maxCommission = commissions.last;
    
    if (minCommission == maxCommission) {
      return 'Hoa hồng: ${FormatUtils.formatCurrency(minCommission.round())}';
    } else {
      return '${FormatUtils.formatCurrency(minCommission.round())} ↓ ${FormatUtils.formatCurrency(maxCommission.round())}';
    }
  }

  void _showShareDialog(AffiliateProduct product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  const Text(
                    'Chia sẻ sản phẩm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Share options
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Center(
                child: _buildShareOption(
                  icon: Icons.share,
                  label: 'Chia sẻ',
                  color: const Color(0xFF1976D2),
                  onTap: () => _shareToOther(product),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _shareToOther(AffiliateProduct product) async {
    final shareText = _buildShareText(product);
    final shareUrl = _buildAffiliateUrl(product);
    
    print('🚀 [SHARE] Starting share for product: ${product.title}');
    print('🖼️ [SHARE] Image URL: ${product.image}');
    print('📝 [SHARE] Share text length: ${shareText.length}');
    print('🔗 [SHARE] Share URL: $shareUrl');
    
    try {
      // Try to share with image if available
      if (product.image.isNotEmpty) {
        print('🖼️ [SHARE] Attempting to share with image: ${product.image}');
        
        // Download image to temporary file
        final imageFile = await _downloadImageToTemp(product.image);
        if (imageFile != null) {
          print('✅ [SHARE] Image downloaded successfully: ${imageFile.path}');
          print('📊 [SHARE] Image file size: ${await imageFile.length()} bytes');
          
          // Method 1: Try sharing both together (preferred)
          try {
            print('📤 [SHARE] Method 1: Sharing both together...');
            await Share.shareXFiles(
              [XFile(imageFile.path)],
              text: '$shareText\n\n$shareUrl',
              subject: product.title,
            );
            print('✅ [SHARE] Combined sharing completed');
            return;
          } catch (e) {
            print('❌ [SHARE] Combined sharing failed: $e');
            print('🔄 [SHARE] Trying sequential method...');
          }
          
          // Method 2: Try sharing text first, then image (fallback)
          try {
            print('📤 [SHARE] Method 2: Sharing text first...');
            // Share text first
            await Share.share(
              '$shareText\n\n$shareUrl',
              subject: product.title,
            );
            print('✅ [SHARE] Text shared successfully');
            
            // Small delay then share image
            print('⏳ [SHARE] Waiting 2 seconds before sharing image...');
            await Future.delayed(const Duration(milliseconds: 2000));
            
            // Share image separately
            print('📤 [SHARE] Method 2: Sharing image separately...');
            await Share.shareXFiles(
              [XFile(imageFile.path)],
              text: '',
            );
            print('✅ [SHARE] Image shared successfully');
            print('✅ [SHARE] Sequential sharing completed');
            return;
          } catch (e) {
            print('❌ [SHARE] Sequential sharing failed: $e');
            print('🔄 [SHARE] Falling back to text-only...');
          }
        } else {
          print('❌ [SHARE] Failed to download image, falling back to text-only');
        }
      } else {
        print('⚠️ [SHARE] No image available, using text-only sharing');
      }
      
      // Fallback to text-only sharing
      print('📤 [SHARE] Fallback: Text-only sharing...');
      Share.share(
        '$shareText\n\n$shareUrl',
        subject: product.title,
      );
      print('✅ [SHARE] Text-only sharing completed');
    } catch (e) {
      print('❌ [SHARE] Error sharing: $e');
      print('🔄 [SHARE] Final fallback: Text-only sharing...');
      // If image sharing fails, fallback to text-only
      Share.share(
        '$shareText\n\n$shareUrl',
        subject: product.title,
      );
      print('✅ [SHARE] Final fallback completed');
    }
  }


  Future<File?> _downloadImageToTemp(String imageUrl) async {
    try {
      print('📥 [DOWNLOAD] Starting download: $imageUrl');
      
      // Validate URL
      if (!imageUrl.startsWith('http')) {
        print('❌ [DOWNLOAD] Invalid URL format: $imageUrl');
        return null;
      }
      
      // Add timeout and headers
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('📊 [DOWNLOAD] HTTP Status: ${response.statusCode}');
      print('📊 [DOWNLOAD] Content-Type: ${response.headers['content-type']}');
      print('📊 [DOWNLOAD] Content-Length: ${response.headers['content-length']}');
      
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        
        final fileSize = await file.length();
        print('✅ [DOWNLOAD] Image saved to: ${file.path}');
        print('📊 [DOWNLOAD] File size: $fileSize bytes');
        
        // Validate file size
        if (fileSize < 100) {
          print('⚠️ [DOWNLOAD] File size too small, might be corrupted');
          return null;
        }
        
        return file;
      } else {
        print('❌ [DOWNLOAD] HTTP error: ${response.statusCode}');
        print('❌ [DOWNLOAD] Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      }
    } catch (e) {
      print('❌ [DOWNLOAD] Error downloading image: $e');
      print('❌ [DOWNLOAD] Error type: ${e.runtimeType}');
    }
    return null;
  }

  String _buildShareText(AffiliateProduct product) {
    final discountPercent = product.oldPrice > product.price 
        ? ' (Giảm ${((product.oldPrice - product.price) / product.oldPrice * 100).round()}%)'
        : '';
    
    final oldPriceText = product.oldPrice > product.price 
        ? '\n💸 Giá gốc: ${FormatUtils.formatCurrency(product.oldPrice.toInt())}'
        : '';
    
    return '🔥 ${product.title}$discountPercent\n💰 Giá: ${FormatUtils.formatCurrency(product.price.toInt())}$oldPriceText\n💎 Hoa hồng: ${product.mainCommission}\n🏪 Thương hiệu: ${product.brandName}\n\n👉 Mua ngay để nhận ưu đãi tốt nhất!\n\n📱 Tải app Socdo để mua hàng với giá tốt nhất!';
  }


  Widget _buildModernFilterPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _loadProducts(refresh: true);
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF6B35),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                
                // Debounce search để tránh gọi API quá nhiều
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                  if (value.trim().isNotEmpty) {
                    print('🔍 [SEARCH] Debounced search triggered for: "$value"');
                    _loadProducts(refresh: true);
                  }
                });
              },
              onSubmitted: (_) {
                // Ẩn bàn phím sau khi submit tìm kiếm
                FocusScope.of(context).unfocus();
                print('🔍 [SEARCH] Manual search submitted for: "$_searchQuery"');
                _loadProducts(refresh: true);
              },
            ),
          ),
          
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Following Filter
                  _buildFilterChip(
                    icon: Icons.favorite_rounded,
                    label: 'Đang theo dõi',
                    isSelected: _onlyFollowed,
                    onTap: () {
                      setState(() {
                        _onlyFollowed = !_onlyFollowed;
                      });
                      _loadProducts(refresh: true);
                    },
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Has Link Filter
                  _buildFilterChip(
                    icon: Icons.link_rounded,
                    label: 'Có link rút gọn',
                    isSelected: _onlyHasLink,
                    onTap: () {
                      setState(() {
                        _onlyHasLink = !_onlyHasLink;
                      });
                      _applyFilters();
                    },
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Sort Dropdown
                  _buildSortChip(),
                  
                  // Clear Filters
                  if (_hasActiveFilters()) ...[
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      icon: Icons.clear_all_rounded,
                      label: 'Xóa bộ lọc',
                      isSelected: false,
                      backgroundColor: Colors.red[50],
                      textColor: Colors.red[600],
                      iconColor: Colors.red[600],
                      onTap: _clearAllFilters,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? textColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFFF6B35) 
              : backgroundColor ?? const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFFF6B35) 
                : const Color(0xFFE9ECEF),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected 
                  ? Colors.white 
                  : iconColor ?? Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected 
                    ? Colors.white 
                    : textColor ?? Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip() {
    return GestureDetector(
      onTap: _showSortBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE9ECEF),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              _getSortLabel(_sortBy),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.sort_rounded,
                    color: const Color(0xFFFF6B35),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sắp xếp theo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            
            // Sort options
            ..._getSortOptions().map((option) {
              final isSelected = option['value'] == _sortBy;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFFF6B35).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    option['icon'] as IconData,
                    color: isSelected 
                        ? const Color(0xFFFF6B35)
                        : Colors.grey[600],
                    size: 20,
                  ),
                ),
                title: Text(
                  option['label'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected 
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF333333),
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFFFF6B35),
                        size: 24,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _sortBy = option['value'] as String;
                  });
                  _loadProducts(refresh: true);
                },
              );
            }),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSortOptions() {
    return [
      {
        'value': 'newest',
        'label': 'Mới nhất',
        'icon': Icons.new_releases_rounded,
      },
      {
        'value': 'price_asc',
        'label': 'Giá tăng dần',
        'icon': Icons.trending_up_rounded,
      },
      {
        'value': 'price_desc',
        'label': 'Giá giảm dần',
        'icon': Icons.trending_down_rounded,
      },
      {
        'value': 'commission_asc',
        'label': 'Hoa hồng tăng dần',
        'icon': Icons.monetization_on_rounded,
      },
      {
        'value': 'commission_desc',
        'label': 'Hoa hồng giảm dần',
        'icon': Icons.money_off_rounded,
      },
    ];
  }

  String _getSortLabel(String sortBy) {
    final option = _getSortOptions().firstWhere(
      (opt) => opt['value'] == sortBy,
      orElse: () => _getSortOptions().first,
    );
    return option['label'] as String;
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty || 
           _onlyFollowed || 
           _onlyHasLink ||
           _sortBy != 'newest';
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _onlyFollowed = false;
      _onlyHasLink = false;
      _sortBy = 'newest';
    });
    _loadProducts(refresh: true);
  }
}
