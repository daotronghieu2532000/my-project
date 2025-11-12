import 'package:flutter/material.dart';
import 'dart:math';

class ViewedProductCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic>? product;
  final VoidCallback? onTap;

  const ViewedProductCard({
    super.key,
    required this.index,
    this.product,
    this.onTap,
  });

  // Helper function to generate fake rating and sold data
  Map<String, dynamic> _generateFakeData(String currentPrice) {
    final random = Random();
    
    // Parse price to check if it's expensive (>= 1,000,000)
    final priceStr = currentPrice.replaceAll(RegExp(r'[^\d]'), '');
    final price = int.tryParse(priceStr) ?? 0;
    final isExpensive = price >= 1000000;
    
    // Generate fake data based on price
    final reviews = isExpensive 
        ? random.nextInt(21) // 0-20 for expensive products
        : random.nextInt(100); // 0-99 for normal products
    
    final sold = isExpensive
        ? random.nextInt(21) // 0-20 for expensive products
        : random.nextInt(99) + 2; // 2-100 for normal products
    
    return {
      'rating': '5.0',
      'reviews': reviews,
      'sold': sold,
    };
  }

  @override
  Widget build(BuildContext context) {
    final products = [
      {
        'name': 'Okinawa Fucoidan của Nhật - Fucoidan xanh 180 viên',
        'currentPrice': '1.799.000₫',
        'originalPrice': '2.100.000₫',
        'discount': '-14%',
        'rating': '4.8',
        'sold': '2.1k+',
        'image': 'lib/src/core/assets/images/product_4.png',
        'badge': 'BÁN CHẠY',
      },
      {
        'name': 'Viên uống Transino White C Clear hỗ trợ trắng da, cải thiện nám',
        'currentPrice': '530.000₫',
        'originalPrice': '590.000₫',
        'discount': '',
        'rating': '4.9',
        'sold': '1.5k+',
        'image': 'lib/src/core/assets/images/product_5.png',
        'badge': '',
      },
      {
        'name': '[Mẫu mới] Viên Uống Collagen + Biotin',
        'currentPrice': '750.000₫',
        'originalPrice': '800.000₫',
        'discount': '',
        'rating': '5.0',
        'sold': '217',
        'image': 'lib/src/core/assets/images/product_6.png',
        'badge': '',
      },
    ];

    final productData = product ?? products[index % products.length];
    
    // Generate fake rating and sold data
    final fakeData = _generateFakeData(productData['currentPrice']!);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      productData['image']!,
                      fit: BoxFit.contain, // Đổi từ cover sang contain để không cắt ảnh
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.image, color: Colors.grey, size: 40),
                        );
                      },
                    ),
                  ),
                  if (productData['discount']!.isNotEmpty)
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
                          productData['discount']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (productData['badge']!.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          productData['badge']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              productData['name']!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  productData['currentPrice']!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (productData['originalPrice']!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    productData['originalPrice']!,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '${fakeData['rating']} (${fakeData['reviews']}) | Đã bán ${fakeData['sold']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
