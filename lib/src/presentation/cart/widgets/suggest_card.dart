import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/utils/format_utils.dart';
import '../../../core/models/product_suggest.dart';
import '../../product/product_detail_screen.dart';

class SuggestCard extends StatelessWidget {
  final ProductSuggest product;
  final VoidCallback? onTap;
  
  const SuggestCard({
    super.key, 
    required this.product,
    this.onTap,
  });

  // Helper function to generate fake rating and sold data (giống flash sale)
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
    return GestureDetector(
      onTap: onTap ?? () => _navigateToProductDetail(context),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: const Color(0xFFF4F6FB),
                    child: product.imageUrl != null
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (c, e, s) => const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
                          )
                        : const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
                  ),
                  if (product.discount != null && product.discount! > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '-${product.discount!.toInt()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        FormatUtils.formatCurrency(product.price),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      if (product.oldPrice != null && product.oldPrice! > product.price) ...[
                        const SizedBox(width: 4),
                        Text(
                          FormatUtils.formatCurrency(product.oldPrice!),
                          style: const TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Rating and sold with fake data (giống flash sale)
                  Builder(
                    builder: (context) {
                      final fakeData = _generateFakeData(product.price);
                      return Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '${fakeData['rating']} (${fakeData['reviews']}) | Đã bán ${fakeData['sold']}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
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

  void _navigateToProductDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          productId: product.id,
          title: product.name,
          image: product.imageUrl,
          price: product.price,
        ),
      ),
    );
  }
}
