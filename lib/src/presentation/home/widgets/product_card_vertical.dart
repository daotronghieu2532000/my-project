import 'package:flutter/material.dart';
import '../../product/product_detail_screen.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/models/product_detail.dart';
import '../../../core/assets/app_images.dart';
import 'simple_variant_selector.dart';
import '../../shared/widgets/product_badges.dart';

class ProductCardVertical extends StatefulWidget {
  final int index;
  final List<String>? badges;
  final String? locationText;
  final String? warehouseName;
  final String? provinceName;
  
  const ProductCardVertical({
    super.key, 
    required this.index,
    this.badges,
    this.locationText,
    this.warehouseName,
    this.provinceName,
  });

  @override
  State<ProductCardVertical> createState() => _ProductCardVerticalState();
}

class _ProductCardVerticalState extends State<ProductCardVertical> {
  bool _isExpanded = false;
  final Map<String, int> _quantities = {};
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int price = 1000; // Giá cố định 1.000₫ như trong hình
    final int oldPrice = (widget.index + 1) * 5000 + 1000; // Giá gốc khác nhau cho mỗi sản phẩm
    
    // Tên sản phẩm theo hình
    final List<String> productNames = [
      'Sữa tươi ít đường TH true MILK bịch 220ml',
      'Nước lon Hydrogen Quantum Nuwa Daily chai 500ml',
      'Quả quất túi 200gr',
      'Bột canh lot Hải Châu gói 190gr',
      'Sản phẩm #4',
      'Sản phẩm #5',
    ];
    
    final List<int> discountPercentages = [89, 88, 85, 82, 80, 75];
    
    final String productName = widget.index < productNames.length ? productNames[widget.index] : 'Sản phẩm #${widget.index}';
    final int discountPercentage = widget.index < discountPercentages.length ? discountPercentages[widget.index] : 80;

    String formatSold(int sold) {
      if (sold >= 1000) {
        final double inK = sold / 1000.0;
        String s = inK.toStringAsFixed(inK.truncateToDouble() == inK ? 0 : 1);
        return '$s+';
      }
      return '$sold';
    }

    final double rating = 4.8; // demo
    final int sold = 2100; // demo 2.1k+

    // Product variants data - với dependencies thông minh
    final List<ProductVariant> variants = _getProductVariants();

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              title: productName,
              image: FormatUtils.resolveProductImage(widget.index),
              price: price,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Hình ảnh sản phẩm với label giảm giá
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
                        child: Image.asset(
                          FormatUtils.resolveProductImage(widget.index),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const Center(
                            child: Icon(Icons.image_not_supported, size: 32, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    // Label giảm giá ở góc phải của ảnh
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-$discountPercentage%',
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
                const SizedBox(width: 12),
                
                // Thông tin sản phẩm
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên sản phẩm
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Giá sản phẩm chính - LUÔN giữ nguyên, không thay đổi khi chọn biến thể
                      Row(
                        children: [
                          Text(
                            FormatUtils.formatCurrency(price), // Luôn hiển thị giá sản phẩm chính
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            FormatUtils.formatCurrency(oldPrice),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Hàng rating | đã bán
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '$rating | Đã bán ${formatSold(sold)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Badges row
                      if (widget.badges != null && widget.badges!.isNotEmpty)
                        ProductBadgesRow(
                          badges: widget.badges!,
                          iconSize: 8,
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        ),
                      const SizedBox(height: 4),
                      // Location info
                      ProductLocationInfo(
                        locationText: widget.locationText,
                        warehouseName: widget.warehouseName,
                        provinceName: widget.provinceName,
                        fontSize: 10,
                      ),
                      const SizedBox(height: 8),
                      
                      // Nút thêm vào giỏ hàng (màu đỏ, nhỏ hơn, nằm dưới bên phải)
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            if (_isDisposed || !mounted) return;
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _isExpanded ? Icons.remove : Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Expandable variants section
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Wrap variant selector để ngăn event bubbling
              GestureDetector(
                onTap: () {
                  // Ngăn event bubbling - không làm gì cả
                },
                child: SimpleVariantSelector(
                  variants: variants,
                  defaultProductImage: AppImages.products[0], // Ảnh sản phẩm chính mặc định
                  onVariantChanged: (variant) {
                    // Không cần cập nhật state vì giá sản phẩm chính không thay đổi
                    // Chỉ để thông báo biến thể đã chọn cho các mục đích khác nếu cần
                  },
                  onQuantityChanged: (quantity, variant) {
                    if (_isDisposed || !mounted) return;
                    setState(() {
                      _quantities[variant.id] = quantity;
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<ProductVariant> _getProductVariants() {
    // iPhone với 4 nhóm thuộc tính: Dung lượng, Màu sắc, Kích cỡ, Chip
    return [
      // iPhone 15 Pro Max - 256GB - Đen - 6.7" - A17 Pro
      ProductVariant(
        id: 'iphone_256gb_black_67_a17',
        attributes: {
          'Dung lượng': '256GB', 
          'Màu sắc': 'Đen', 
          'Kích cỡ': '6.7"', 
          'Chip': 'A17 Pro'
        },
        price: 29990000,
        discount: 5,
        stock: 10,
        imageUrl: AppImages.products[0], // product_1.png
      ),
      
      // iPhone 15 Pro Max - 256GB - Trắng - 6.7" - A17 Pro
      ProductVariant(
        id: 'iphone_256gb_white_67_a17',
        attributes: {
          'Dung lượng': '256GB', 
          'Màu sắc': 'Trắng', 
          'Kích cỡ': '6.7"', 
          'Chip': 'A17 Pro'
        },
        price: 29990000,
        discount: 5,
        stock: 8,
        imageUrl: AppImages.products[1], // product_2.png
      ),
      
      // iPhone 15 Pro Max - 512GB - Đen - 6.7" - A17 Pro
      ProductVariant(
        id: 'iphone_512gb_black_67_a17',
        attributes: {
          'Dung lượng': '512GB', 
          'Màu sắc': 'Đen', 
          'Kích cỡ': '6.7"', 
          'Chip': 'A17 Pro'
        },
        price: 34990000,
        discount: 3,
        stock: 5,
        imageUrl: AppImages.products[2], // product_3.png
      ),
      
      // iPhone 15 Pro Max - 512GB - Trắng - 6.7" - A17 Pro
      ProductVariant(
        id: 'iphone_512gb_white_67_a17',
        attributes: {
          'Dung lượng': '512GB', 
          'Màu sắc': 'Trắng', 
          'Kích cỡ': '6.7"', 
          'Chip': 'A17 Pro'
        },
        price: 34990000,
        discount: 3,
        stock: 3,
        imageUrl: AppImages.products[3], // product_4.png
      ),
      
      // iPhone 15 Pro - 256GB - Đen - 6.1" - A17 Pro
      ProductVariant(
        id: 'iphone_256gb_black_61_a17',
        attributes: {
          'Dung lượng': '256GB', 
          'Màu sắc': 'Đen', 
          'Kích cỡ': '6.1"', 
          'Chip': 'A17 Pro'
        },
        price: 26990000,
        discount: 8,
        stock: 15,
        imageUrl: AppImages.products[4], // product_5.png
      ),
      
      // iPhone 15 Pro - 256GB - Trắng - 6.1" - A17 Pro
      ProductVariant(
        id: 'iphone_256gb_white_61_a17',
        attributes: {
          'Dung lượng': '256GB', 
          'Màu sắc': 'Trắng', 
          'Kích cỡ': '6.1"', 
          'Chip': 'A17 Pro'
        },
        price: 26990000,
        discount: 8,
        stock: 12,
        imageUrl: AppImages.products[5], // product_6.png
      ),
      
      // iPhone 15 - 128GB - Đen - 6.1" - A16 Bionic
      ProductVariant(
        id: 'iphone_128gb_black_61_a16',
        attributes: {
          'Dung lượng': '128GB', 
          'Màu sắc': 'Đen', 
          'Kích cỡ': '6.1"', 
          'Chip': 'A16 Bionic'
        },
        price: 19990000,
        discount: 10,
        stock: 20,
        imageUrl: AppImages.products[6], // product_7.png
      ),
      
      // iPhone 15 - 128GB - Trắng - 6.1" - A16 Bionic
      ProductVariant(
        id: 'iphone_128gb_white_61_a16',
        attributes: {
          'Dung lượng': '128GB', 
          'Màu sắc': 'Trắng', 
          'Kích cỡ': '6.1"', 
          'Chip': 'A16 Bionic'
        },
        price: 19990000,
        discount: 10,
        stock: 18,
        imageUrl: AppImages.products[7], // product_8.png
      ),
    ];
  }
}
