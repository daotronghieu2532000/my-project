import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';
import '../../../core/services/cached_api_service.dart';
import '../shop_category_products_screen.dart';

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
        
        // Debug: Kiểm tra xem có categories nào có cùng image URL không
        // (Có thể uncomment để debug nếu cần)
        // final imageUrlMap = <String, List<String>>{};
        // for (var cat in categories) {
        //   final imageUrl = cat.image.isNotEmpty ? cat.image : (cat.icon.isNotEmpty ? cat.icon : '');
        //   if (imageUrl.isNotEmpty) {
        //     imageUrlMap.putIfAbsent(imageUrl, () => []).add('${cat.id}:${cat.title}');
        //   }
        // }
        // final duplicates = imageUrlMap.entries.where((e) => e.value.length > 1).toList();
        // if (duplicates.isNotEmpty) {
        //   print('⚠️ [ShopCategories] Phát hiện ${duplicates.length} ảnh bị lặp lại:');
        //   for (var dup in duplicates) {
        //     print('  - URL: ${dup.key} -> Categories: ${dup.value.join(", ")}');
        //   }
        // }
        
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


       height: 120, // Tăng chiều cao để chứa ảnh + tên + số lượng sản phẩm
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

  /// Lấy URL ảnh cho category với logic fallback
  /// Ưu tiên: image > icon > bannerImage > leftImage
  String? _getCategoryImageUrl(ShopCategory category) {
    if (category.image.isNotEmpty) {
      return category.image;
    }
    if (category.icon.isNotEmpty) {
      return category.icon;
    }
    if (category.bannerImage.isNotEmpty) {
      return category.bannerImage;
    }
    if (category.leftImage.isNotEmpty) {
      return category.leftImage;
    }
    return null;
  }

  Widget _buildCategoryCard(ShopCategory category) {
    final imageUrl = _getCategoryImageUrl(category);
    
    return InkWell(
      onTap: () => _navigateToCategoryProducts(category),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ảnh category
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.category,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    )
                  : Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.category,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            // Tên category - wrap trong Flexible để tránh overflow
            Flexible(
              child: Text(
                category.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Số lượng sản phẩm
            if (category.productCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${category.productCount} sản phẩm',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToCategoryProducts(ShopCategory category) {
    // Navigate to shop products section with category filter
    // Tạm thời navigate đến tab "Sản phẩm" với category filter
    // TODO: Tạo màn hình riêng hoặc thêm categoryId vào ShopProductsSection
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopCategoryProductsScreen(
          shopId: widget.shopId,
          categoryId: category.id,
          categoryName: category.title,
        ),
      ),
    );
  }
}

