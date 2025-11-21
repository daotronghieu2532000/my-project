import 'package:flutter/material.dart';
import 'shop_vouchers_horizontal.dart';
import 'shop_flash_sales_tabs.dart';
import 'shop_categories_horizontal.dart';
import 'shop_suggested_products_section.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/shop_detail.dart';

class ShopTabContent extends StatelessWidget {
  final int shopId;

  const ShopTabContent({
    super.key,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Clear cache và reload các section
        final cachedApiService = CachedApiService();
        cachedApiService.clearAllShopCache(shopId);
        // Trigger rebuild bằng cách không làm gì cả, các widget con sẽ tự reload
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Voucher section - cuộn ngang
            _VoucherSectionWithTitle(shopId: shopId),
            
            // Flash Sale section - tabs nếu có nhiều flash sale
            _FlashSaleSectionWithTitle(shopId: shopId),
            
            // Suggested Products section - cuộn ngang
            _SuggestedProductsSectionWithTitle(shopId: shopId),
            
            // Categories section - cuộn ngang
            _CategorySectionWithTitle(shopId: shopId),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Widget wrapper cho Voucher section
class _VoucherSectionWithTitle extends StatefulWidget {
  final int shopId;

  const _VoucherSectionWithTitle({required this.shopId});

  @override
  State<_VoucherSectionWithTitle> createState() => _VoucherSectionWithTitleState();
}

class _VoucherSectionWithTitleState extends State<_VoucherSectionWithTitle> {
  final CachedApiService _cachedApiService = CachedApiService();
  bool _hasVouchers = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkVouchers();
  }

  Future<void> _checkVouchers() async {
    try {
      final vouchersData = await _cachedApiService.getShopVouchersDataCached(
        shopId: widget.shopId,
      );
      
      if (mounted) {
        setState(() {
          _hasVouchers = vouchersData.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasVouchers = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        if (_hasVouchers) ...[
          _buildSectionTitle('Mã giảm giá'),
          const SizedBox(height: 8),
        ],
        ShopVouchersHorizontal(shopId: widget.shopId),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// Widget wrapper cho Flash Sale section
class _FlashSaleSectionWithTitle extends StatefulWidget {
  final int shopId;

  const _FlashSaleSectionWithTitle({required this.shopId});

  @override
  State<_FlashSaleSectionWithTitle> createState() => _FlashSaleSectionWithTitleState();
}

class _FlashSaleSectionWithTitleState extends State<_FlashSaleSectionWithTitle> {
  final CachedApiService _cachedApiService = CachedApiService();
  bool _hasFlashSales = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFlashSales();
  }

  Future<void> _checkFlashSales() async {
    try {
      final flashSalesData = await _cachedApiService.getShopFlashSalesCached(
        shopId: widget.shopId,
      );
      
      if (mounted) {
        setState(() {
          _hasFlashSales = flashSalesData.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasFlashSales = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        if (_hasFlashSales) ...[
          // Tiêu đề Flash sale cũ - đã ẩn vì có tiêu đề FLASH SALE mới
          // _buildSectionTitle('Flash sale'),
          // const SizedBox(height: 8),
        ],
        ShopFlashSalesTabs(shopId: widget.shopId),
      ],
    );
  }
}

// Widget wrapper cho Category section
class _CategorySectionWithTitle extends StatefulWidget {
  final int shopId;

  const _CategorySectionWithTitle({required this.shopId});

  @override
  State<_CategorySectionWithTitle> createState() => _CategorySectionWithTitleState();
}

class _CategorySectionWithTitleState extends State<_CategorySectionWithTitle> {
  final CachedApiService _cachedApiService = CachedApiService();
  bool _hasCategories = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkCategories();
  }

  Future<void> _checkCategories() async {
    try {
      final shopDetail = await _cachedApiService.getShopDetailCached(
        shopId: widget.shopId,
      );
      
      if (mounted) {
        setState(() {
          _hasCategories = shopDetail?.categories.isNotEmpty ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasCategories = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        if (_hasCategories) ...[
          _buildSectionTitle('Danh mục'),
          const SizedBox(height: 8),
        ],
        ShopCategoriesHorizontal(shopId: widget.shopId),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// Widget wrapper cho Suggested Products section
class _SuggestedProductsSectionWithTitle extends StatefulWidget {
  final int shopId;

  const _SuggestedProductsSectionWithTitle({required this.shopId});

  @override
  State<_SuggestedProductsSectionWithTitle> createState() => _SuggestedProductsSectionWithTitleState();
}

class _SuggestedProductsSectionWithTitleState extends State<_SuggestedProductsSectionWithTitle> {
  final CachedApiService _cachedApiService = CachedApiService();
  final AuthService _authService = AuthService();
  List<ShopProduct> _suggestedProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestedProducts();
    // Lắng nghe sự kiện đăng nhập để refresh
    _authService.addAuthStateListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _authService.removeAuthStateListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    // Khi đăng nhập/logout, refresh lại suggested products
    if (mounted) {
      _loadSuggestedProducts(forceRefresh: true);
    }
  }

  Future<void> _loadSuggestedProducts({bool forceRefresh = false}) async {
    try {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });
      
      final shopDetail = await _cachedApiService.getShopDetailCached(
        shopId: widget.shopId,
        includeSuggestedProducts: 1,
        forceRefresh: forceRefresh, // Force refresh khi đăng nhập
      );
      
      if (mounted) {
        setState(() {
          _suggestedProducts = shopDetail?.suggestedProducts ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestedProducts = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_suggestedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        ShopSuggestedProductsSection(
          shopId: widget.shopId,
          suggestedProducts: _suggestedProducts,
        ),
      ],
    );
  }
}

