import 'package:flutter/material.dart';
import 'chip_item.dart';
import '../category_products_screen.dart';
import '../parent_category_products_screen.dart';

class GroupCard extends StatefulWidget {
  final String title;
  final int parentCategoryId;
  final List<Map<String, dynamic>> childCategories;
  final Function(int categoryId, String categoryName) onCategoryTap;
  const GroupCard({
    super.key, 
    required this.title,
    required this.parentCategoryId,
    required this.childCategories,
    required this.onCategoryTap,
  });

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                  ? primaryColor.withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
                blurRadius: _isHovered ? 16 : 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: _isHovered 
                ? primaryColor.withOpacity(0.15)
                : Colors.transparent,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(0.1),
                              primaryColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: () {
                          // Navigate to all products in this parent category
                          _navigateToAllProducts();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: _isHovered 
                            ? primaryColor.withOpacity(0.1)
                            : Colors.grey[100],
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Xem thêm',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isHovered ? primaryColor : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: _isHovered ? primaryColor : Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTwoColumnGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAllProducts() {
    // Navigate to all products in parent category using the new API
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ParentCategoryProductsScreen(
          parentCategoryId: widget.parentCategoryId,
          parentCategoryName: widget.title,
        ),
      ),
    );
  }

  Widget _buildTwoColumnGrid() {
    // Chia danh mục con thành các cặp để hiển thị 2 cột
    final List<List<Map<String, dynamic>>> categoryPairs = [];
    for (int i = 0; i < widget.childCategories.length; i += 2) {
      if (i + 1 < widget.childCategories.length) {
        categoryPairs.add([widget.childCategories[i], widget.childCategories[i + 1]]);
      } else {
        categoryPairs.add([widget.childCategories[i]]);
      }
    }

    return Column(
      children: categoryPairs.map((pair) {
        // Ưu tiên 'image' field trước (API trả về field này), sau đó mới đến cat_minhhoa và cat_img
        final imageUrl1 = pair[0]['image'] ?? pair[0]['cat_minhhoa'] ?? pair[0]['cat_img'];
        
        return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: ChipItem(
                label: pair[0]['name'] ?? pair[0]['cat_tieude'] ?? 'Danh mục',
                imageUrl: imageUrl1,
                onTap: () {
                  final categoryId = pair[0]['id'] ?? pair[0]['cat_id'] ?? 0;
                  final categoryName = pair[0]['name'] ?? pair[0]['cat_tieude'] ?? 'Danh mục';
                  
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CategoryProductsScreen(
                        categoryId: categoryId,
                        categoryName: categoryName,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: pair.length > 1 
                ? Builder(
                    builder: (context) {
                      // Ưu tiên 'image' field trước (API trả về field này)
                      final imageUrl2 = pair[1]['image'] ?? pair[1]['cat_minhhoa'] ?? pair[1]['cat_img'];
                      return ChipItem(
                        label: pair[1]['name'] ?? pair[1]['cat_tieude'] ?? 'Danh mục',
                        imageUrl: imageUrl2,
                        onTap: () {
                      final categoryId = pair[1]['id'] ?? pair[1]['cat_id'] ?? 0;
                      final categoryName = pair[1]['name'] ?? pair[1]['cat_tieude'] ?? 'Danh mục';
                      
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CategoryProductsScreen(
                            categoryId: categoryId,
                            categoryName: categoryName,
                          ),
                        ),
                      );
                    },
                      );
                    },
                  )
                : const SizedBox(), // Empty space nếu chỉ có 1 item
            ),
          ],
        ),
      );
      }).toList(),
    );
  }
}
