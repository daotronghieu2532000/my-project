import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'widgets/left_menu_item.dart';
import 'widgets/right_content.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/widgets/scroll_preservation_wrapper.dart';

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
  bool _isLoadingChildren = false; // Loading state cho child categories
  int _selectedParentIndex = 0;
  bool _hasLoadedOnce = false; // Flag để tránh load lại khi rebuild
  // Cache để lưu children của từng parent category
  final Map<int, List<Map<String, dynamic>>> _childrenCache = {};
  // Track current loading parent ID để cancel nếu cần
  int? _currentLoadingParentId;

  @override
  void initState() {
    super.initState();
    _loadParentCategories();
  }

  Future<void> _loadParentCategories() async {
    try {
      // Nếu đã load rồi và có dữ liệu, không load lại (tránh gọi API khi switch tabs)
      if (_hasLoadedOnce && _parentCategories.isNotEmpty) {
        return;
      }
      
      setState(() => _isLoading = true);
      
      // Sử dụng cached API service - forceRefresh false để dùng cache nếu có
      final categoriesData = await _cachedApiService.getCategoriesList(
        type: 'parents',
        includeChildren: true,
        includeProductsCount: true,
        forceRefresh: false,
      );
      
      if (categoriesData.isNotEmpty && mounted) {
        final cacheStartTime = DateTime.now();
        int cachedCount = 0;
        int missingChildrenCount = 0;
        
        // Pre-cache children của TẤT CẢ parent categories nếu có trong response
        for (var parent in categoriesData) {
          final parentId = parent['id'] ?? parent['cat_id'];
          if (parentId != null) {
            final children = parent['children'] as List?;
            if (children != null && children.isNotEmpty) {
              // Kiểm tra xem children có đủ image không (ưu tiên 'image' field vì API trả về field này)
              int childrenWithImage = 0;
              for (var child in children) {
                final childMap = child as Map<String, dynamic>?;
                if (childMap != null) {
                  // Ưu tiên 'image' field trước (API trả về field này), sau đó mới đến cat_minhhoa và cat_img
                  final imageUrl = childMap['image'] ?? childMap['cat_minhhoa'] ?? childMap['cat_img'];
                  if (imageUrl != null && imageUrl.toString().isNotEmpty) {
                    childrenWithImage++;
                  }
                }
              }
              
              if (childrenWithImage > 0) {
                // Chỉ cache nếu có ít nhất 1 child có image
                _childrenCache[parentId] = List<Map<String, dynamic>>.from(children);
                cachedCount++;
              } else {
                // KHÔNG cache nếu thiếu image - để pre-load có thể load từ API
                missingChildrenCount++;
              }
            } else {
              missingChildrenCount++;
            }
          }
        }
        
        setState(() {
          _parentCategories = categoriesData;
          _isLoading = false;
          _hasLoadedOnce = true;
          // Load children of first category ngay lập tức từ cache (đã có sẵn)
          if (categoriesData.isNotEmpty) {
            _loadChildrenFromParent(categoriesData.first, showLoading: false);
          }
        });
        
        // Pre-load children cho các parent categories còn lại trong background
        // Chỉ load những parent chưa có children trong cache
        if (missingChildrenCount > 0) {
          // Load children của parent đầu tiên ngay lập tức (nếu chưa có trong cache)
          if (categoriesData.isNotEmpty) {
            final firstParentId = categoriesData.first['id'] ?? categoriesData.first['cat_id'];
            if (firstParentId != null && !_childrenCache.containsKey(firstParentId)) {
              _loadChildCategories(firstParentId);
            }
          }
          
          // Pre-load các parent còn lại trong background (song song)
          _preloadAllChildren(categoriesData);
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadChildrenFromParent(Map<String, dynamic> parentCategory, {bool showLoading = true}) {
      final parentId = parentCategory['id'] ?? parentCategory['cat_id'];
      if (parentId == null) {
        return;
      }
      
      // Kiểm tra cache trước - đây là cách nhanh nhất (0ms)
      if (_childrenCache.containsKey(parentId)) {
        final cachedChildren = _childrenCache[parentId]!;
        
        setState(() {
        _childCategories = cachedChildren;
        _isLoadingChildren = false;
      });
      
      // Pre-load ảnh trong background để hiển thị nhanh hơn
      _preloadCategoryImages(cachedChildren);
      
      return;
    }
    
    // Nếu không có trong cache, kiểm tra parent data
    try {
      final children = parentCategory['children'] as List?;
      if (children != null && children.isNotEmpty) {
        // Sử dụng children từ parent data ngay lập tức (dù có thể thiếu image)
        // Để tốc độ nhanh, sau đó load từ API trong background nếu thiếu image
        final childrenList = List<Map<String, dynamic>>.from(children);
        
        // Kiểm tra xem có children nào có image không (ưu tiên 'image' field)
        int childrenWithImage = 0;
        for (var child in childrenList) {
          // Ưu tiên 'image' field trước (API trả về field này)
          final imageUrl = child['image'] ?? child['cat_minhhoa'] ?? child['cat_img'];
          if (imageUrl != null && imageUrl.toString().isNotEmpty) {
            childrenWithImage++;
          }
        }
        
          // Cache và hiển thị ngay
          _childrenCache[parentId] = childrenList;
          
          setState(() {
          _childCategories = childrenList;
          _isLoadingChildren = false;
        });
        
        // Pre-load ảnh trong background nếu có
        if (childrenWithImage > 0) {
          _preloadCategoryImages(childrenList);
        }
        
        // Nếu thiếu image, load từ API ngay (không background)
        if (childrenWithImage == 0) {
          if (showLoading) {
            setState(() => _isLoadingChildren = true);
          }
          _loadChildCategories(parentId);
          return;
        }
        
        return;
      }
      
      // Nếu không có children trong parent data, gọi API
      if (showLoading) {
        setState(() => _isLoadingChildren = true);
      }
      _loadChildCategories(parentId);
    } catch (e) {
      // Fallback to API call
      if (showLoading) {
        setState(() => _isLoadingChildren = true);
      }
      _loadChildCategories(parentId);
    }
  }

  Future<void> _loadChildCategories(int parentId) async {
    // Đánh dấu đang load parent này
    _currentLoadingParentId = parentId;
    
    try {
      // Sử dụng cached API service - sẽ tự động dùng cache nếu có
      final childrenData = await _cachedApiService.getCategoriesList(
        type: 'children',
        parentId: parentId,
        includeProductsCount: true,
        forceRefresh: false, // Ưu tiên dùng cache
      );
      
        // Kiểm tra xem user đã chuyển sang category khác chưa
        if (_currentLoadingParentId != parentId) {
          return;
        }
        
        if (mounted && _currentLoadingParentId == parentId) {
        if (childrenData.isNotEmpty) {
          // Kiểm tra xem children từ API có đủ image không (ưu tiên 'image' field)
          int childrenWithImage = 0;
          for (var child in childrenData) {
            // Ưu tiên 'image' field trước (API trả về field này)
            final imageUrl = child['image'] ?? child['cat_minhhoa'] ?? child['cat_img'];
            if (imageUrl != null && imageUrl.toString().isNotEmpty) {
              childrenWithImage++;
            }
          }
          
            // Cache lại để dùng lần sau
            _childrenCache[parentId] = childrenData;
            
            setState(() {
            _childCategories = childrenData;
            _isLoadingChildren = false;
          });
          
          // Pre-load ảnh trong background để hiển thị nhanh hơn
            _preloadCategoryImages(childrenData);
          } else {
            setState(() {
            _childCategories = [];
            _isLoadingChildren = false;
          });
        }
      }
    } catch (e) {
        // Chỉ xử lý lỗi nếu vẫn đang load category này
        if (_currentLoadingParentId == parentId) {
          if (mounted) {
          setState(() {
            _childCategories = [];
            _isLoadingChildren = false;
              });
            }
          }
    } finally {
      // Reset nếu vẫn là category hiện tại
      if (_currentLoadingParentId == parentId) {
        _currentLoadingParentId = null;
      }
    }
  }

  /// Pre-load children cho tất cả parent categories trong background (song song)
  void _preloadAllChildren(List<Map<String, dynamic>> parents) {
    // Load trong background, không block UI
    // Load SONG SONG thay vì tuần tự để nhanh hơn
    Future.microtask(() async {
      final futures = <Future<void>>[];
      
      for (var parent in parents) {
        final parentId = parent['id'] ?? parent['cat_id'];
        if (parentId != null && !_childrenCache.containsKey(parentId)) {
          // Chỉ load nếu chưa có trong cache
          futures.add(_loadSingleChildCategory(parentId));
        }
      }
      
        // Chờ tất cả load xong (song song)
        await Future.wait(futures, eagerError: false);
      });
  }
  
  /// Load children cho một parent category (dùng cho pre-load song song)
  Future<void> _loadSingleChildCategory(int parentId) async {
    try {
      final childrenData = await _cachedApiService.getCategoriesList(
        type: 'children',
        parentId: parentId,
        includeProductsCount: true,
        forceRefresh: false,
      );
      
      if (childrenData.isNotEmpty && mounted) {
        _childrenCache[parentId] = childrenData;
      }
    } catch (e) {
      // Ignore errors trong background loading
    }
  }

  /// Pre-load ảnh của categories trong background để hiển thị nhanh hơn
  void _preloadCategoryImages(List<Map<String, dynamic>> children) {
    if (!mounted) return;
    
    // Pre-load trong background, không block UI
    // Chỉ pre-load ảnh đầu tiên để không tốn quá nhiều bandwidth
    Future.microtask(() async {
      int preloadedCount = 0;
      const maxPreload = 6; // Chỉ pre-load 6 ảnh đầu tiên (3 hàng x 2 cột)
      
      for (var child in children) {
        if (!mounted || preloadedCount >= maxPreload) break;
        
        // Ưu tiên 'image' field trước (API trả về field này)
        final imageUrl = child['image'] ?? child['cat_minhhoa'] ?? child['cat_img'];
        if (imageUrl != null && imageUrl.toString().isNotEmpty) {
          try {
            String fullImageUrl = imageUrl.toString();
            if (!fullImageUrl.startsWith('http')) {
              if (fullImageUrl.startsWith('/')) {
                fullImageUrl = 'https://socdo.vn$fullImageUrl';
              } else {
                fullImageUrl = 'https://socdo.vn/$fullImageUrl';
              }
            }
            
            // Pre-load ảnh với timeout ngắn để không block quá lâu
            final imageProvider = CachedNetworkImageProvider(fullImageUrl);
            await precacheImage(imageProvider, context).timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                // Timeout không quan trọng, bỏ qua
              },
            );
            preloadedCount++;
          } catch (e) {
            // Ignore preload errors
          }
        }
      }
    });
  }

  void _onParentCategorySelected(int index) {
    if (index != _selectedParentIndex) {
      final parentId = _parentCategories.isNotEmpty && index < _parentCategories.length
            ? _parentCategories[index]['id'] ?? _parentCategories[index]['cat_id']
            : null;
        
        // Cancel previous loading nếu có
        if (_currentLoadingParentId != null && _currentLoadingParentId != parentId) {
          _currentLoadingParentId = null;
        }
      
      setState(() {
        _selectedParentIndex = index;
        // Giữ nguyên child categories cũ trong khi load mới (better UX)
      });
      
      if (_parentCategories.isNotEmpty && index < _parentCategories.length) {
        _loadChildrenFromParent(_parentCategories[index], showLoading: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Bắt buộc cho AutomaticKeepAliveClientMixin
    return ScrollPreservationWrapper(
      tabIndex: 1, // Category tab
      child: Scaffold(
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
                    title: _parentCategories.isNotEmpty 
                      ? _parentCategories[_selectedParentIndex]['name'] ?? _parentCategories[_selectedParentIndex]['cat_tieude'] ?? 'Danh mục'
                      : 'Danh mục',
                    parentCategoryId: _parentCategories.isNotEmpty 
                      ? _parentCategories[_selectedParentIndex]['id'] ?? _parentCategories[_selectedParentIndex]['cat_id'] ?? 0
                      : 0,
                    childCategories: _childCategories,
                    isLoading: _isLoadingChildren,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}



