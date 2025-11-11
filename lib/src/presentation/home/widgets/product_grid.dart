import 'package:flutter/material.dart';
import 'product_card_horizontal.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/product_suggest.dart';

class ProductGrid extends StatefulWidget {
  final String title;
  const ProductGrid({super.key, required this.title});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  final CachedApiService _cachedApiService = CachedApiService();
  final AuthService _authService = AuthService();
  List<ProductSuggest> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load từ cache ngay lập tức
    _loadProductSuggestsFromCache();
  }

  Future<void> _loadProductSuggestsFromCache() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Lấy userId từ AuthService (user đã đăng nhập) để sử dụng personalized suggestions
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      if (userId != null) {
        print('👤 Đang tải gợi ý cá nhân hóa cho user_id: $userId');
      } else {
        print('👤 User chưa đăng nhập - sử dụng gợi ý chung');
      }
      
      // Sử dụng cached API service với userId (nếu có)
      // Nếu có userId, sẽ gọi API với type='user_based' để lấy gợi ý dựa trên hành vi
      final suggestionsData = await _cachedApiService.getHomeSuggestions(
        limit: 100,
        userId: userId,
      );
      
      if (userId != null) {
        print('📦 Đã nhận ${suggestionsData.length} sản phẩm gợi ý cá nhân hóa');
      }
      
      if (mounted && suggestionsData.isNotEmpty) {
        // Convert Map to ProductSuggest
        final products = suggestionsData.map((data) => ProductSuggest.fromJson(data)).toList();
        
        setState(() {
          _isLoading = false;
          _products = products;
        });
        
        print('✅ Product suggestions loaded successfully (${products.length} products)');
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Không có sản phẩm gợi ý';
        });
        print('⚠️ No product suggestions found');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Lỗi kết nối: $e';
        });
      }
      print('❌ Error loading product suggestions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _buildProductsList(),
      ],
    );
  }

  Widget _buildProductsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    if (_error != null) {
      return Padding(
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
      );
    }

    if (_products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.recommend_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Không có sản phẩm gợi ý',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Hiển thị dạng Wrap 2 cột - mỗi card tự co giãn theo nội dung
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding left/right - spacing giữa 2 cột) / 2
    // Padding: 4px mỗi bên = 8px, spacing: 8px giữa 2 cột
    final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: Wrap(
        alignment: WrapAlignment.start, // Căn trái khi chỉ có 1 sản phẩm
        spacing: 8, // Khoảng cách ngang giữa các card
        runSpacing: 8, // Khoảng cách dọc giữa các hàng
        children: _products.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          return SizedBox(
            width: cardWidth, // Width cố định cho 2 cột, height tự co giãn
            child: ProductCardHorizontal(
              product: product,
              index: index,
            ),
          );
        }).toList(),
          ),
    );
  }
}
