import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

class ReviewHistoryScreen extends StatefulWidget {
  const ReviewHistoryScreen({super.key});

  @override
  State<ReviewHistoryScreen> createState() => _ReviewHistoryScreenState();
}

class _ReviewHistoryScreenState extends State<ReviewHistoryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  late TabController _tabController;
  
  int? _userId;
  bool _loading = true;
  Map<String, List<dynamic>> _reviews = {
    'all': [],
    'reviewed': [],
    'pending': [],
  };
  int _currentPage = 1;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadReviews(refresh: true);
  }

  Future<void> _init() async {
    final loggedIn = await _auth.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      setState(() => _userId = null);
      return;
    }
    final user = await _auth.getCurrentUser();
    if (!mounted) return;
    setState(() => _userId = user?.userId);
    if (_userId != null) {
      await _loadReviews(refresh: true);
    }
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (_userId == null) return;
    
    if (refresh) {
      setState(() {
        _loading = true;
        _currentPage = 1;
        _hasMore = true;
      });
    }

    final statusMap = ['all', 'reviewed', 'pending'];
    final status = statusMap[_tabController.index];
    
    final data = await _api.getReviewHistory(
      userId: _userId!,
      page: _currentPage,
      limit: _limit,
      status: status,
    );

    if (!mounted) return;

    final reviews = (data?['data']?['reviews'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pagination = data?['data']?['pagination'] as Map<String, dynamic>?;
    
    setState(() {
      if (refresh) {
        _reviews[status] = reviews;
      } else {
        _reviews[status] = [..._reviews[status]!, ...reviews];
      }
      _loading = false;
      _hasMore = pagination?['has_next'] == true;
      if (_hasMore) _currentPage += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lịch sử đánh giá',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Đã đánh giá'),
            Tab(text: 'Chưa đánh giá'),
          ],
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6B35),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: _userId == null
          ? const Center(child: Text('Vui lòng đăng nhập'))
          : _loading && _reviews[_getCurrentStatus()]!.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _loadReviews(refresh: true),
                  child: _buildReviewList(),
                ),
    );
  }

  String _getCurrentStatus() {
    final statusMap = ['all', 'reviewed', 'pending'];
    return statusMap[_tabController.index];
  }

  Widget _buildReviewList() {
    final status = _getCurrentStatus();
    final reviews = _reviews[status] ?? [];

    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_border,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có đánh giá nào',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == reviews.length) {
          // Load more
          _loadReviews();
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _buildReviewCard(reviews[index] as Map<String, dynamic>);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> order) {
    final products = (order['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final orderId = order['order_id'] as int?;
    final maDon = order['ma_don'] ?? '';
    final datePost = order['date_post_formatted'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đơn hàng: $maDon',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                datePost,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Products
          ...products.map((product) => _buildProductReviewItem(product, orderId)),
        ],
      ),
    );
  }

  Widget _buildProductReviewItem(Map<String, dynamic> product, int? orderId) {
    final productName = product['name'] ?? '';
    final productImage = product['image'] ?? '';
    final size = product['size'] ?? '';
    final color = product['color'] ?? '';
    final variant = [size, color].where((e) => e.toString().isNotEmpty).join(' • ');
    final hasReview = product['has_review'] == true;
    final review = product['review'] as Map<String, dynamic>?;
    
    final fixedImage = productImage.startsWith('http')
        ? productImage
        : (productImage.isEmpty ? '' : 'https://socdo.vn$productImage');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  fixedImage,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: const Color(0xFFF5F5F5),
                    child: const Icon(Icons.image_not_supported, size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (variant.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        variant,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Review content
          if (hasReview && review != null) ...[
            // Rating stars
            Row(
              children: List.generate(5, (index) {
                final starRating = index + 1;
                final isSelected = (review['rating'] as int? ?? 0) >= starRating;
                return Icon(
                  isSelected ? Icons.star : Icons.star_border,
                  color: isSelected ? Colors.amber : Colors.grey[300],
                  size: 20,
                );
              }),
            ),
            const SizedBox(height: 8),
            
            // Review text
            Text(
              review['content'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
              ),
            ),
            
            // Review images
            if ((review['images'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (review['images'] as List).map((img) {
                  final imageUrl = img.toString().startsWith('http')
                      ? img.toString()
                      : 'https://socdo.vn${img.toString()}';
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(Icons.image_not_supported, size: 20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            // Review date and verified badge
            const SizedBox(height: 8),
            Row(
              children: [
                if (review['is_verified_purchase'] == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF52C41A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF52C41A).withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Đã mua hàng',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF52C41A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  review['review_date_formatted'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Not reviewed yet
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_border,
                    color: Color(0xFFFF6B35),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chưa đánh giá',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFF6B35),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

