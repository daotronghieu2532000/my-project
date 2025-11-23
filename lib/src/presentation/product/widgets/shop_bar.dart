import 'package:flutter/material.dart';

class ShopBar extends StatelessWidget {
  final String? shopName;
  final String? shopLogo;
  final String? shopAvatar;
  final String? shopAddress;
  final String? shopUrl;
  final double rating;
  final int reviewCount;
  final int? totalProducts; // Thêm field cho số sản phẩm
  final VoidCallback? onViewShop;

  const ShopBar({
    super.key,
    this.shopName,
    this.shopLogo,
    this.shopAvatar,
    this.shopAddress,
    this.shopUrl,
    this.rating = 4.46,
    this.reviewCount = 24,
    this.totalProducts, // Thêm parameter
    this.onViewShop,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: onViewShop,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12), // Giảm padding từ 20 xuống 12
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA), // Màu nền nhẹ nhàng, đơn giản hơn
          ),
          child: Row(
            children: [
              Container(
                width: 70, // Tăng kích thước để hiển thị full ảnh
                height: 70,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(60), // Bo góc nhiều hơn cho đẹp
                ),
                child: shopAvatar?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(60), // Bo góc nhiều hơn cho đẹp
                        child: Image.network(
                          shopAvatar!,
                          width: 70, // Đảm bảo width đầy đủ
                          height: 70, // Đảm bảo height đầy đủ
                          fit: BoxFit.cover, // Thay đổi thành cover để full box
                          errorBuilder: (context, error, stackTrace) => ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.asset(
                              'assets/images/shop.jpg',
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: Image.asset(
                          'assets/images/shop.jpg',
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(width: 16), // Tăng khoảng cách
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      shopName ?? 'Shop',
                      style: const TextStyle(
                        fontSize: 15, // Tăng kích thước tên shop
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6), // Tăng khoảng cách
                    // Hiển thị số sản phẩm nếu có dữ liệu thật từ API
                    if (totalProducts != null && totalProducts! > 0) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$totalProducts sản phẩm',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      shopAddress?.isNotEmpty == true 
                          ? shopAddress!
                          : (rating > 0 && reviewCount > 0 
                              ? '$rating ⭐ | $reviewCount đánh giá'
                              : shopAddress ?? ''),
                      style: const TextStyle(
                        fontSize: 13, // Giảm kích thước địa chỉ một chút
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Padding cân đối
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53E3E), Color(0xFFC53030)], // Gradient đỏ sang trọng
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20), // Bo góc tròn hơn
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Xem Shop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13, // Font size vừa phải
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5, // Tăng khoảng cách chữ cho sang trọng
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
