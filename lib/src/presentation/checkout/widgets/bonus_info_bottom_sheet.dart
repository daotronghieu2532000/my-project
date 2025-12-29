import 'package:flutter/material.dart';
import '../../../core/models/bonus_config.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/models/shop_detail.dart';
import '../../shop/shop_detail_screen.dart';

class BonusInfoBottomSheet extends StatefulWidget {
  final BonusConfig bonusConfig;
  final int remainingAmount;
  final int bonusAmount;
  final double discountPercent;

  const BonusInfoBottomSheet({
    super.key,
    required this.bonusConfig,
    required this.remainingAmount,
    required this.bonusAmount,
    required this.discountPercent,
  });

  @override
  State<BonusInfoBottomSheet> createState() => _BonusInfoBottomSheetState();
}

class _BonusInfoBottomSheetState extends State<BonusInfoBottomSheet> {
  final CachedApiService _cachedApiService = CachedApiService();
  final Map<int, ShopInfo?> _shopInfoCache = {};
  final Map<int, bool> _loadingShops = {};

  @override
  void initState() {
    super.initState();
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    for (final shop in widget.bonusConfig.eligibleShops) {
      if (!_shopInfoCache.containsKey(shop.shopId) && !(_loadingShops[shop.shopId] ?? false)) {
        _loadingShops[shop.shopId] = true;
        try {
          final shopDetail = await _cachedApiService.getShopDetailCached(
            shopId: shop.shopId,
            includeProducts: 0,
            includeFlashSale: 0,
            includeVouchers: 0,
            includeWarehouses: 0,
            includeCategories: 0,
            includeSuggestedProducts: 0,
          );
          if (mounted) {
            setState(() {
              _shopInfoCache[shop.shopId] = shopDetail?.shopInfo;
              _loadingShops[shop.shopId] = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _loadingShops[shop.shopId] = false;
            });
          }
        }
      }
    }
  }

  void _navigateToShop(int shopId, String shopName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDetailScreen(
          shopId: shopId,
          shopName: shopName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  color: Colors.green.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎁 Voucher giảm giá',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Giảm ${widget.discountPercent.toStringAsFixed(0)}% cho đơn hàng của bạn',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Bonus info card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thông tin chi tiết',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Số dư', '${_formatPrice(widget.remainingAmount)}'),
                const SizedBox(height: 8),
                _buildInfoRow('Giảm', '${_formatPrice(widget.bonusAmount)} (${widget.discountPercent.toStringAsFixed(0)}%)'),
                 const SizedBox(height: 8),
                _buildInfoRow('Điều kiện', 'Đơn hàng tối thiểu >= 100.000 đ'),
                const SizedBox(height: 8),
                _buildInfoRow('', 'Chỉ áp dụng cho sản phẩm từ các Nhà bán thuộc chương trình khuyến mại'),
                
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Eligible shops info (mô tả chung, không liệt kê từng shop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.store,
                  color: Colors.green.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voucher áp dụng cho các sản phẩm của Sóc Đỏ Choice và một số nhãn hàng liên kết.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShopItem({
    required BonusShop shop,
    ShopInfo? shopInfo,
    required bool isLoading,
  }) {
    final avatarUrl = shopInfo?.avatarUrl ?? '';
    final shopName = shopInfo?.name ?? shop.shopName;

    return InkWell(
      onTap: () => _navigateToShop(shop.shopId, shopName),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[200],
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.store,
                              size: 24,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : Icon(
                          Icons.store,
                          size: 24,
                          color: Colors.grey[600],
                        ),
            ),
            const SizedBox(width: 12),
            // Shop name
            Expanded(
              child: Text(
                shopName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            // Arrow icon
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    // Hiển thị dạng tiền Việt đầy đủ, ví dụ: 200.000 đ, 22.400 đ
    final priceStr = price.toString();
    final buffer = StringBuffer();
    int count = 0;

    // Duyệt từ phải sang trái và chèn dấu chấm mỗi 3 chữ số
    for (int i = priceStr.length - 1; i >= 0; i--) {
      buffer.write(priceStr[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    final formatted = buffer.toString().split('').reversed.join();
    return '$formatted đ';
  }
}

