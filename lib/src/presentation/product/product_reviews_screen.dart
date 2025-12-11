import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/blocked_users_service.dart';
import 'widgets/review_image_viewer.dart';
import 'widgets/report_review_dialog.dart' show showReportReviewDialog;

class ProductReviewsScreen extends StatefulWidget {
  final int productId;

  const ProductReviewsScreen({super.key, required this.productId});

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  final ApiService _api = ApiService();
  final BlockedUsersService _blockedUsersService = BlockedUsersService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  int _page = 1;
  final int _limit = 400; // Tăng từ 20 lên 100 để hiển thị nhiều reviews hơn
  bool _hasMore = true;
  Set<int> _blockedUserIds = {};

  // Filters
  int? _selectedRating; // null = all, 1-5 = specific rating
  bool _hasImagesOnly = false;
  bool? _isSatisfied; // null = all, true = satisfied, false = not satisfied
  bool? _matchesDescription; // null = all, true = matches, false = not matches
  String _sort = 'latest'; // latest, oldest, highest, lowest
  
  // Rating stats
  int _totalReviews = 0;
  int _rating5Count = 0;
  int _rating4Count = 0;
  int _rating3Count = 0;
  int _rating2Count = 0;
  int _rating1Count = 0;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _loadReviews(); // Load reviews và stats ngay từ đầu
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadBlockedUsers() async {
    await _blockedUsersService.initialize();
    final blocked = await _blockedUsersService.getBlockedUsers();
    if (mounted) {
      setState(() {
        _blockedUserIds = blocked;
      });
      // Reload reviews để ẩn content từ blocked users
      _loadReviews(refresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_loading && _hasMore) {
        _loadMoreReviews();
      }
    }
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _reviews = [];
        _hasMore = true;
      });
    }

    setState(() => _loading = true);

    try {
      final result = await _api.getProductReviews(
        productId: widget.productId,
        page: _page,
        limit: _limit,
        rating: _selectedRating ?? 0,
        hasImages: _hasImagesOnly ? 1 : 0,
        isSatisfied: _isSatisfied == null ? '' : (_isSatisfied! ? '1' : '0'),
        matchesDescription: _matchesDescription == null
            ? ''
            : (_matchesDescription! ? '1' : '0'),
        sort: _sort,
      );

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>?;
        final reviews =
            (data?['reviews'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final total = data?['total'] as int? ?? 0;
        final ratingStats = data?['rating_stats'] as Map<String, dynamic>?;

        setState(() {
          if (refresh) {
            _reviews = reviews;
          } else {
            _reviews.addAll(reviews);
          }
          // Cập nhật rating stats (luôn cập nhật, không chỉ khi refresh)
          if (ratingStats != null) {
            _totalReviews = data?['total_reviews'] as int? ?? 0;
            _rating5Count = ratingStats['rating_5'] as int? ?? 0;
            _rating4Count = ratingStats['rating_4'] as int? ?? 0;
            _rating3Count = ratingStats['rating_3'] as int? ?? 0;
            _rating2Count = ratingStats['rating_2'] as int? ?? 0;
            _rating1Count = ratingStats['rating_1'] as int? ?? 0;
          }
          _hasMore = reviews.length == _limit && _reviews.length < total;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _hasMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _page++;
    });

    await _loadReviews();
  }

  void _applyFilters() {
    _loadReviews(refresh: true);
  }

  // Lọc reviews: ẩn reviews từ người bị chặn và lọc profanity
  List<Map<String, dynamic>> _getFilteredReviews() {
    return _reviews.where((review) {
      final userId = review['user_id'] as int? ?? review['sender_id'] as int? ?? 0;
      // Ẩn review từ người bị chặn
      if (userId > 0 && _blockedUserIds.contains(userId)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text(
        //   'Đánh giá sản phẩm',
        //   style: TextStyle(
        //     fontSize: 16,
        //     color: Colors.black,
        //     fontWeight: FontWeight.w600,
        //   ),
        // ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Compact Filter Bar - Horizontal scroll, gọn gàng
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Header row - Compact
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Đánh giá',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_totalReviews > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_totalReviews',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Sort button - Compact
                      GestureDetector(
                        onTap: () => _showSortDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                _getSortLabel(_sort),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Rating filters - Horizontal scroll
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildCompactFilterChip(
                        label: 'Tất cả',
                        isSelected: _selectedRating == null,
                        count: _totalReviews,
                        onTap: () {
                          setState(() => _selectedRating = null);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCompactRatingChip(5, _rating5Count),
                      const SizedBox(width: 6),
                      _buildCompactRatingChip(4, _rating4Count),
                      const SizedBox(width: 6),
                      _buildCompactRatingChip(3, _rating3Count),
                      const SizedBox(width: 6),
                      _buildCompactRatingChip(2, _rating2Count),
                      const SizedBox(width: 6),
                      _buildCompactRatingChip(1, _rating1Count),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Other filters - Horizontal scroll, compact
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildCompactFilterChip(
                        label: 'Có ảnh',
                        isSelected: _hasImagesOnly,
                        icon: Icons.image,
                        iconSize: 14,
                        onTap: () {
                          setState(() => _hasImagesOnly = !_hasImagesOnly);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCompactFilterChip(
                        label: 'Hài lòng',
                        isSelected: _isSatisfied == true,
                        icon: Icons.sentiment_satisfied,
                        iconSize: 14,
                        onTap: () {
                          setState(() => _isSatisfied = _isSatisfied == true ? null : true);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCompactFilterChip(
                        label: 'Đúng mô tả',
                        isSelected: _matchesDescription == true,
                        icon: Icons.check_circle_outline,
                        iconSize: 14,
                        onTap: () {
                          setState(() => _matchesDescription = _matchesDescription == true ? null : true);
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: Colors.grey[200]),
          // Reviews list
          Expanded(
            child: _loading && _reviews.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _reviews.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có đánh giá nào',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadReviews(refresh: true),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _getFilteredReviews().length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final filteredReviews = _getFilteredReviews();
                        if (index == filteredReviews.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return _buildReviewItem(filteredReviews[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(String sort) {
    switch (sort) {
      case 'latest':
        return 'Mới nhất';
      case 'oldest':
        return 'Cũ nhất';
      case 'highest':
        return 'Cao nhất';
      case 'lowest':
        return 'Thấp nhất';
      default:
        return 'Mới nhất';
    }
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sắp xếp theo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...['latest', 'oldest', 'highest', 'lowest'].map((sort) {
              final isSelected = _sort == sort;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? const Color(0xFFFF6B35) : Colors.grey,
                ),
                title: Text(_getSortLabel(sort)),
                onTap: () {
                  setState(() => _sort = sort);
                  _applyFilters();
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRatingChip(int rating, int count) {
    return _buildCompactFilterChip(
      label: '$rating',
      isSelected: _selectedRating == rating,
      count: count,
      icon: Icons.star,
      iconColor: Colors.amber,
      iconAfterText: true,
      onTap: () {
        setState(() => _selectedRating = _selectedRating == rating ? null : rating);
        _applyFilters();
      },
    );
  }

  Widget _buildCompactFilterChip({
    required String label,
    required bool isSelected,
    int? count,
    IconData? icon,
    Color? iconColor,
    double iconSize = 16,
    bool iconAfterText = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[50],
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null && !iconAfterText) ...[
              Icon(
                icon,
                size: iconSize,
                color: isSelected
                    ? Colors.white
                    : (iconColor ?? Colors.grey[600]),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (icon != null && iconAfterText) ...[
              const SizedBox(width: 4),
              Icon(
                icon,
                size: iconSize,
                color: isSelected
                    ? Colors.white
                    : (iconColor ?? Colors.grey[600]),
              ),
            ],
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final userName = review['user_name'] as String? ?? 'Người dùng';
    final userAvatar = review['user_avatar'] as String? ?? '';
    final content = review['content'] as String? ?? '';
    final rating = review['rating'] as int? ?? 5;
    final variant = review['variant'] as Map<String, dynamic>?;
    final variantName = variant?['name'] as String?;
    final images = review['images'] as List? ?? [];
    final shopRating = review['shop_rating'] as int?;
    final matchesDescription = review['matches_description'] as bool?;
    final isSatisfied = review['is_satisfied'] as bool?;
    final willBuyAgain = review['will_buy_again'] as String?;
    final isVerifiedPurchase = review['is_verified_purchase'] == true;
    final createdAt = review['created_at_formatted'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: userAvatar.isNotEmpty
                    ? NetworkImage(userAvatar)
                    : null,
                child: userAvatar.isEmpty
                    ? const Icon(Icons.person, size: 18, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (isVerifiedPurchase)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 255, 255, 255),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color.fromARGB(255, 0, 139, 253)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 12,
                                  color: Color.fromARGB(255, 0, 139, 253),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Đã mua',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color.fromARGB(255, 3, 113, 248),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Nút ba chấm để báo cáo
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: Colors.grey,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          color: Colors.white,
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'report',
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flag_outlined, size: 14, color: Colors.grey[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Báo cáo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'block',
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.block, size: 14, color: Colors.grey[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Chặn',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (String value) {
                            if (value == 'report') {
                              showReportReviewDialog(context);
                            } else if (value == 'block') {
                              _handleBlockUser(review);
                            }
                          },
                        ),
                      ],
                    ),
                    if (variantName != null && variantName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Phân loại: ${variantName.replaceAll(RegExp(r'[-+]'), '').trim()}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rating stars
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: index < rating ? Colors.amber : Colors.grey[300],
                );
              }),
              const SizedBox(width: 8),
              if (createdAt.isNotEmpty)
                Text(
                  createdAt,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Content
          if (content.isNotEmpty)
            Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 8),

          // Additional ratings and info chips - horizontal scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (shopRating != null) _buildShopRatingChip(shopRating),
                if (matchesDescription != null)
                  _buildInfoChip(
                    matchesDescription ? 'Đúng mô tả' : 'Không đúng mô tả',
                    '',
                    matchesDescription ? Colors.green : Colors.red,
                  ),
                if (isSatisfied != null)
                  _buildInfoChip(
                    isSatisfied ? 'Hài lòng' : 'Không hài lòng',
                    '',
                    isSatisfied ? Colors.green : Colors.orange,
                  ),
                if (willBuyAgain != null)
                  _buildInfoChip(
                    willBuyAgain == 'yes'
                        ? 'Sẽ quay lại'
                        : willBuyAgain == 'no'
                        ? 'Không quay lại'
                        : 'Sẽ cân nhắc',
                    '',
                    willBuyAgain == 'yes'
                        ? Colors.green
                        : willBuyAgain == 'no'
                        ? Colors.red
                        : Colors.orange,
                  ),
              ],
            ),
          ),

          // Images
          if (images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final imageUrl = images[index] as String;
                  return GestureDetector(
                    onTap: () {
                      // Chuyển đổi List<dynamic> thành List<String>
                      final imageUrls = images
                          .map((img) => img.toString())
                          .toList();
                      showDialog(
                        context: context,
                        builder: (context) => ReviewImageViewer(
                          images: imageUrls,
                          initialIndex: index,
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: imageUrl.startsWith('data:image/')
                            ? Image.memory(
                                base64Decode(imageUrl.split(',')[1]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 24,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          // Nút "Hữu ích" và ba chấm ở cuối review
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  // TODO: Implement helpful functionality if needed
                },
                icon: const Icon(Icons.thumb_up_outlined, size: 16, color: Colors.grey),
                label: const Text(
                  'Hữu ích',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopRatingChip(int rating) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Shop : $rating',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.star,
            size: 14,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleBlockUser(Map<String, dynamic> review) async {
    await _blockedUsersService.initialize();
    
    final userId = review['user_id'] as int? ?? review['sender_id'] as int? ?? 0;
    final userName = review['user_name'] as String? ?? 'Người dùng';
    
    if (userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xác định người dùng để chặn'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }
    
    // Hiển thị dialog xác nhận
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Chặn người dùng',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc chắn muốn chặn $userName?',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khi chặn, đánh giá và nội dung của người này sẽ bị ẩn ngay lập tức.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Gọi API để chặn user
              final success = await _blockedUsersService.blockUser(userId);
              
              if (success && mounted) {
                // Cập nhật danh sách chặn và reload reviews
                await _loadBlockedUsers();
                
                // Hiển thị thông báo
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã chặn người dùng. Nội dung của họ đã bị ẩn.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không thể chặn người dùng. Vui lòng thử lại.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
            ),
            child: const Text('Chặn'),
          ),
        ],
      ),
    );
  }
}
