import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/models/related_product.dart';
import '../product_detail_screen.dart';

class RelatedProductCard extends StatelessWidget {
  final RelatedProduct product;

  const RelatedProductCard({
    super.key,
    required this.product,
  });

  // Helper function to generate fake rating and sold data
  Map<String, dynamic> _generateFakeData(int price) {
    // Sử dụng product ID làm seed để đảm bảo dữ liệu cố định
    final random = Random(product.id);
    
    // Check if it's expensive (>= 1,000,000)
    final isExpensive = price >= 1000000;
    
    // Generate fake data based on price with fixed seed
    final reviews = isExpensive 
        ? (random.nextInt(21) + 5) // 5-25 for expensive products
        : (random.nextInt(95) + 10); // 10-104 for normal products
    
    final sold = isExpensive
        ? (random.nextInt(21) + 5) // 5-25 for expensive products
        : (random.nextInt(90) + 15); // 15-104 for normal products
    
    return {
      'rating': '5.0',
      'reviews': reviews,
      'sold': sold,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 290, // Tăng thêm từ 280 lên 320 (+40px)
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToProductDetail(context),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hình ảnh sản phẩm
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Container(
                    height: 200, // Tăng thêm từ 150 lên 180 (+30px)
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: product.image.isNotEmpty
                        ? Image.network(
                            product.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                          )
                        : _buildPlaceholderImage(),
                  ),
                ),
                // Badge giảm giá
                if (product.discountPercent > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.discountPercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Badge Flash Sale
                if (product.isFlashSale)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Flash',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Badge Freeship
                if (product.hasFreeShipping)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Freeship',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Thông tin sản phẩm
            Padding(
              padding: const EdgeInsets.all(6), // Giảm từ 8 xuống 6
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên sản phẩm
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12, // Giảm từ 13 xuống 12
                      height: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 3), // Giảm từ 4 xuống 3
                  
                  // Giá sản phẩm
                  Row(
                    children: [
                      Text(
                        product.priceFormatted,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (product.oldPrice > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          product.oldPriceFormatted,
                          style: const TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 3), // Giảm từ 4 xuống 3
                  
                  // Rating, đánh giá và đã bán cùng hàng với fake data
                  Builder(
                    builder: (context) {
                      final fakeData = _generateFakeData(product.price);
                      return Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${fakeData['rating']} (${fakeData['reviews']}) | Đã bán ${fakeData['sold']}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 180, // Tăng chiều cao để đồng bộ với container chính
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          size: 24,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _navigateToProductDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: product.id,
          title: product.name,
          image: product.image,
          price: product.price,
        ),
      ),
    );
  }
}
