import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/models/flash_sale_product.dart';

class FlashSaleProductCard extends StatelessWidget {
  final FlashSaleProduct product;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const FlashSaleProductCard({
    super.key,
    required this.product,
    required this.index,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {

    // String formatSold(int sold) {
    //   if (sold >= 1000) {
    //     final double inK = sold / 1000.0;
    //     String s = inK.toStringAsFixed(inK.truncateToDouble() == inK ? 0 : 1);
    //     return '$s+';
    //   }
    //   return '$sold';
    // }

    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Product image
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: product.imageUrl != null
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => _buildPlaceholderImage(),
                          )
                        : _buildPlaceholderImage(),
                  ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.favorite_border,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.formattedDiscount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand
                if (product.brand != null)
                  Text(
                    product.brand!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 4),
                
                // Product name
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Price section (new price first, then old price)
                Row(
                  children: [
                    Text(
                      FormatUtils.formatCurrency(product.price),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.oldPrice != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        FormatUtils.formatCurrency(product.oldPrice!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Rating and sold row under price
                Row(
                  children: [
                    if (product.rating != null) ...[
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        product.formattedRating,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (product.sold != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Đã bán ${product.formattedSold}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                
                // Hot deal badge and action buttons
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department, size: 12, color: Colors.white),
                          const SizedBox(width: 2),
                          const Text(
                            'BÁN CHẠY',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                      GestureDetector(
                        onTap: onAddToCart,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.red, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.shopping_cart,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
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
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          size: 32,
          color: Colors.grey,
        ),
      ),
    );
  }
}
