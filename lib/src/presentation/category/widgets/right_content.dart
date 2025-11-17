import 'package:flutter/material.dart';
import 'group_card.dart';

class RightContent extends StatelessWidget {
  final String title;
  final int parentCategoryId;
  final List<Map<String, dynamic>> childCategories;
  const RightContent({
    super.key, 
    required this.title,
    required this.parentCategoryId,
    required this.childCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: childCategories.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Không có danh mục con',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              GroupCard(
                title: title,
                parentCategoryId: parentCategoryId,
                childCategories: childCategories,
                onCategoryTap: (categoryId, categoryName) {
                  // TODO: Navigate to category products
                
                },
              ),
            ],
          ),
    );
  }
}
