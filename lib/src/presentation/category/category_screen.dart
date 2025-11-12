import 'package:flutter/material.dart';
import 'widgets/left_menu_item.dart';
import 'widgets/right_content.dart';
import '../../core/services/cached_api_service.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  final CachedApiService _cachedApiService = CachedApiService();
  
  List<Map<String, dynamic>> _parentCategories = [];
  List<Map<String, dynamic>> _childCategories = [];
  bool _isLoading = true;
  int _selectedParentIndex = 0;

  @override
  void initState() {
    super.initState();
    print('🚀 [CategoryScreen] initState - wantKeepAlive: $wantKeepAlive');
    _loadParentCategories();
  }
  
  @override
  void dispose() {
    print('🗑️ [CategoryScreen] dispose called!');
    print('   ⚠️ This should NOT happen with IndexedStack + AutomaticKeepAliveClientMixin');
    print('   💡 If you see this, IndexedStack is not working correctly');
    super.dispose();
  }

  Future<void> _loadParentCategories() async {
    try {
      setState(() => _isLoading = true);
      
      // Sử dụng cached API service
      final categoriesData = await _cachedApiService.getCategoriesList(
        type: 'parents',
        includeChildren: true,
        includeProductsCount: true,
      );
      
      if (categoriesData.isNotEmpty && mounted) {
        setState(() {
          _parentCategories = categoriesData;
          _isLoading = false;
          // Load children of first category
          if (categoriesData.isNotEmpty) {
            _loadChildrenFromParent(categoriesData.first);
          }
        });
      }
    } catch (e) {
      print('❌ Lỗi khi tải danh mục cha: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadChildrenFromParent(Map<String, dynamic> parentCategory) {
    try {
      // Kiểm tra xem parent category có children không
      final children = parentCategory['children'] as List?;
      if (children != null && children.isNotEmpty) {
        print('🔍 Loaded ${children.length} child categories from parent: ${parentCategory['name'] ?? parentCategory['cat_tieude']}');
        
        // Kiểm tra xem children có đủ thông tin không (có image field)
        final firstChild = children.first as Map<String, dynamic>;
        final hasImageInfo = firstChild.containsKey('image') || 
                            firstChild.containsKey('cat_minhhoa') || 
                            firstChild.containsKey('cat_img');
        
        if (hasImageInfo) {
          // Sử dụng children từ parent data
          for (var child in children) {
            print('  - ${child['name'] ?? child['cat_tieude']} (ID: ${child['id'] ?? child['cat_id']})');
            print('    Image: image=${child['image']}, cat_minhhoa=${child['cat_minhhoa']}, cat_img=${child['cat_img']}');
          }
          setState(() {
            _childCategories = List<Map<String, dynamic>>.from(children);
          });
        } else {
          // Children không có đủ thông tin, gọi API riêng
          print('⚠️ Children không có đủ thông tin, gọi API riêng');
          final parentId = parentCategory['id'] ?? parentCategory['cat_id'];
          _loadChildCategories(parentId);
        }
      } else {
        // Nếu không có children trong parent data, gọi API riêng
        final parentId = parentCategory['id'] ?? parentCategory['cat_id'];
        _loadChildCategories(parentId);
      }
    } catch (e) {
      print('❌ Lỗi khi load children from parent: $e');
      // Fallback to API call
      final parentId = parentCategory['id'] ?? parentCategory['cat_id'];
      _loadChildCategories(parentId);
    }
  }

  Future<void> _loadChildCategories(int parentId) async {
    try {
      // Sử dụng cached API service
      final childrenData = await _cachedApiService.getCategoriesList(
        type: 'children',
        parentId: parentId,
        includeProductsCount: true,
      );
      
      if (childrenData.isNotEmpty && mounted) {
        print('🔍 Loaded ${childrenData.length} child categories for parent ID: $parentId');
        for (var child in childrenData) {
          print('  - ${child['name'] ?? child['cat_tieude']} (ID: ${child['id'] ?? child['cat_id']})');
        }
        setState(() {
          _childCategories = childrenData;
        });
      }
    } catch (e) {
      print('❌ Lỗi khi tải danh mục con: $e');
    }
  }

  void _onParentCategorySelected(int index) {
    if (index != _selectedParentIndex) {
      setState(() {
        _selectedParentIndex = index;
      });
      
      if (_parentCategories.isNotEmpty && index < _parentCategories.length) {
        _loadChildrenFromParent(_parentCategories[index]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    print('🏗️ [CategoryScreen] build');
    print('   ✅ wantKeepAlive: $wantKeepAlive (widget will be kept alive)');
    print('   📦 PageStorageKeys: category_left_menu, category_right_content');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Danh mục sản phẩm',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        // Ẩn icon giỏ hàng góc phải theo yêu cầu
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              SizedBox(
                width: 110,
                child: ListView.builder(
                  key: const PageStorageKey('category_left_menu'), // Flutter tự động lưu scroll position
                  itemCount: _parentCategories.length,
                  itemBuilder: (context, index) => LeftMenuItem(
                    label: _parentCategories[index]['name'] ?? _parentCategories[index]['cat_tieude'] ?? 'Danh mục',
                    imageUrl: _parentCategories[index]['image'] ?? _parentCategories[index]['cat_minhhoa'] ?? _parentCategories[index]['cat_img'],
                    selected: index == _selectedParentIndex,
                    onTap: () => _onParentCategorySelected(index),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: RightContent(
                  key: const PageStorageKey('category_right_content'), // Flutter tự động lưu scroll position
                  title: _parentCategories.isNotEmpty 
                    ? _parentCategories[_selectedParentIndex]['name'] ?? _parentCategories[_selectedParentIndex]['cat_tieude'] ?? 'Danh mục'
                    : 'Danh mục',
                  parentCategoryId: _parentCategories.isNotEmpty 
                    ? _parentCategories[_selectedParentIndex]['id'] ?? _parentCategories[_selectedParentIndex]['cat_id'] ?? 0
                    : 0,
                  childCategories: _childCategories,
                ),
              ),
            ],
          ),
    );
  }
}



