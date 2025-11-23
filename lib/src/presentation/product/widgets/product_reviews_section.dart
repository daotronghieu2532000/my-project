import 'dart:convert';
import 'package:flutter/material.dart';
import '../product_reviews_screen.dart';
import 'review_image_viewer.dart';

class ProductReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>>? reviews;
  final int productId;
  final int? totalReviews;
  final double? rating;
  final bool isLoading; // Thêm parameter để biết đang load

  const ProductReviewsSection({
    super.key,
    required this.reviews,
    required this.productId,
    this.totalReviews,
    this.rating,
    this.isLoading = false, // Default false
  });

  @override
  Widget build(BuildContext context) {
    // LUÔN HIỂN THỊ section, ngay cả khi chưa có reviews
    final hasReviews = reviews != null && reviews!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề "Đánh giá sản phẩm" với rating, total reviews và nút "Xem tất cả" ở bên phải
        Padding(
          padding: const EdgeInsets.only(top: 0, left: 12, right: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Đánh giá sản phẩm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (rating != null && rating! > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    if (totalReviews != null && totalReviews! > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '($totalReviews)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Luôn hiển thị nút "Xem tất cả" nếu có reviews hoặc có totalReviews
              if (totalReviews != null && totalReviews! > 0)
                TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductReviewsScreen(productId: productId),
                            ),
                          );
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Tất cả',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_right_outlined,
                        size: 16,
                        color: Color(0xFFFF6B35),
                    ),
                ],
              ),
            ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // List đánh giá - hiển thị reviews nếu có, hoặc loading/empty state
        if (isLoading)
          // Đang load reviews
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasReviews)
          // Có reviews, hiển thị
          ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: reviews!.length > 2 ? 2 : reviews!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final review = reviews![index];
                  return _buildReviewItem(review);
                },
          )
        else if (totalReviews != null && totalReviews! > 0)
          // Có reviews nhưng chưa load được (có thể đang load hoặc lỗi)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'Đang tải đánh giá...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Chưa có reviews, hiển thị empty state
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Chưa có đánh giá nào',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      margin: EdgeInsets.zero,
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color.fromARGB(255, 0, 139, 253)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 12, color: Color.fromARGB(255, 0, 139, 253)),
                                SizedBox(width: 2),
                                Text(
                                  'Đã mua',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color.fromARGB(255, 0, 139, 253),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (variantName != null && variantName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Phân loại: ${variantName.replaceAll(RegExp(r'[-+]'), '').trim()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
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
                if (shopRating != null)
                  _buildShopRatingChip(shopRating),
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
                      final imageUrls = images.map((img) => img.toString()).toList();
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
                                  child: const Icon(Icons.image_not_supported, size: 24),
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported, size: 24),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
}

