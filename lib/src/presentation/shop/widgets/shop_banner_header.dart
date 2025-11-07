import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';

class ShopBannerHeader extends StatelessWidget {
  final ShopInfo shopInfo;
  final VoidCallback? onBack;
  final VoidCallback? onCart;

  const ShopBannerHeader({
    super.key,
    required this.shopInfo,
    this.onBack,
    this.onCart,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Banner image - dính lên đỉnh trang
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/banner-shop.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Gradient overlay để text dễ đọc
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
        ),
        // Nút back và icon giỏ hàng màu trắng ở trên cùng
        Positioned(
          top: MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onBack ?? () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  iconSize: 24,
                ),
                IconButton(
                  onPressed: onCart,
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  iconSize: 24,
                ),
              ],
            ),
          ),
        ),
        // Shop info overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: shopInfo.avatarUrl.isNotEmpty
                        ? NetworkImage(shopInfo.avatarUrl)
                        : null,
                    child: shopInfo.avatarUrl.isEmpty
                        ? const Icon(Icons.store, size: 30, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Shop Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shopInfo.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '4.9',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${shopInfo.totalProducts} Sản phẩm',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (shopInfo.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                shopInfo.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

