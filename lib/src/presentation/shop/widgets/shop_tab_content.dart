import 'package:flutter/material.dart';
import 'shop_vouchers_horizontal.dart';
import 'shop_flash_sales_tabs.dart';
import 'shop_categories_horizontal.dart';
import '../../../core/services/cached_api_service.dart';

class ShopTabContent extends StatelessWidget {
  final int shopId;

  const ShopTabContent({
    super.key,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voucher section - cuộn ngang
          _VoucherSectionWithTitle(shopId: shopId),
          
          // Flash Sale section - tabs nếu có nhiều flash sale
          _FlashSaleSectionWithTitle(shopId: shopId),
          
          // Categories section - cuộn ngang
          _CategorySectionWithTitle(shopId: shopId),
          const SizedBox(height: 16),
        ],
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
          _buildSectionTitle('Flash sale'),
          const SizedBox(height: 8),
        ],
        ShopFlashSalesTabs(shopId: widget.shopId),
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

