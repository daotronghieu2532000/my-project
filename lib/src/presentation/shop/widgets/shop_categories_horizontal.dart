import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';
import '../../../core/services/cached_api_service.dart';

class ShopCategoriesHorizontal extends StatefulWidget {
  final int shopId;

  const ShopCategoriesHorizontal({
    super.key,
    required this.shopId,
  });

  @override
  State<ShopCategoriesHorizontal> createState() => _ShopCategoriesHorizontalState();
}

class _ShopCategoriesHorizontalState extends State<ShopCategoriesHorizontal> {
  final CachedApiService _cachedApiService = CachedApiService();
  
  List<ShopCategory> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final categoriesData = await _cachedApiService.getShopCategoriesCached(
        shopId: widget.shopId,
      );

      if (mounted) {
        final categories = categoriesData.map((data) => ShopCategory.fromJson(data)).toList();
        
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 96, // Giảm từ 100 xuống 96 để tránh overflow
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            child: _buildCategoryCard(category),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(ShopCategory category) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Giảm chiều cao để tránh overflow
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: category.image.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    category.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.category,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                )
              : const Icon(
                  Icons.category,
                  size: 30,
                  color: Colors.grey,
                ),
        ),
        const SizedBox(height: 2), // Giảm từ 4 xuống 2
        Flexible( // Wrap Text trong Flexible để tránh overflow
          child: Text(
            category.title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

