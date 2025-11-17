import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cached_api_service.dart';
import '../../../core/models/voucher.dart';
import 'voucher_card.dart';
import '../../product/product_detail_screen.dart';

class ShopVouchersTab extends StatefulWidget {
  const ShopVouchersTab({super.key});

  @override
  State<ShopVouchersTab> createState() => _ShopVouchersTabState();
}

class _ShopVouchersTabState extends State<ShopVouchersTab> {
  final ApiService _apiService = ApiService();
  final CachedApiService _cachedApiService = CachedApiService();
  List<Voucher> _vouchers = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  final int _limit = 20; // Tăng từ 5 lên 20
  bool _hasMore = true;
  String? _selectedShopId;

  // Shops data sẽ được load động từ API
  List<Map<String, dynamic>> _shops = [];

  @override
  void initState() {
    super.initState();
    _loadShopsAndVouchers();
  }

  Future<void> _loadShopsAndVouchers() async {
    // Load shops và vouchers song song để tối ưu performance
    await Future.wait([
      _loadShops(),
      _loadVouchers(),
    ]);
  }

  Future<void> _loadShops() async {
    try {
      // Sử dụng cached API service cho shops
      final shops = await _cachedApiService.getVoucherShopsCached();
      
      if (mounted && shops != null) {
        setState(() {
          _shops = shops;
        });
      
      }
    } catch (e) {
    
    }
  }

  Future<void> _loadVouchers({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _vouchers.clear();
      });
    }

    try {
      setState(() {
        _isLoading = _currentPage == 1;
        _error = null;
      });
      List<Voucher>? vouchers = [];
      if (_selectedShopId != null) {
        vouchers = await _cachedApiService.getShopVouchersCached(
          shopId: _selectedShopId,
          page: _currentPage,
          limit: _limit,
          forceRefresh: isRefresh,
        );
      } else {

        vouchers = await _cachedApiService.getShopVouchersCached(
          page: _currentPage,
          limit: 100, // Tăng limit để lấy nhiều voucher hơn
          forceRefresh: isRefresh,
        );
  
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (vouchers != null && vouchers.isNotEmpty) {
            if (isRefresh) {
              _vouchers = vouchers;
            } else {
              _vouchers.addAll(vouchers);
            }
            _hasMore = vouchers.length == _limit;
          } else {
            _hasMore = false;
            if (_currentPage == 1) {
              _error = 'Không có voucher shop nào';
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_isLoading && _hasMore) {
      setState(() {
        _currentPage++;
      });
      await _loadVouchers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _loadVouchers(isRefresh: true),
      child: Column(
        children: [
          // Shop filter
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _shops.length + 1, // +1 for "Tất cả" option
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "Tất cả" option
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Tất cả'),
                      selected: _selectedShopId == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedShopId = null;
                        });
                        _loadVouchers(isRefresh: true);
                      },
                      selectedColor: Colors.blue.shade100,
                      checkmarkColor: Colors.blue,
                    ),
                  );
                }
                
                final shop = _shops[index - 1];
                final shopId = shop['id'].toString();
                final shopName = shop['name']?.toString() ?? 'Unknown Shop';
                final shopLogo = shop['logo']?.toString() ?? 'lib/src/core/assets/images/shop_1.png';
                final isSelected = _selectedShopId == shopId;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Image.asset(
                        shopLogo,
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.store,
                          size: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    label: Text(shopName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedShopId = selected ? shopId : null;
                      });
                      _loadVouchers(isRefresh: true);
                    },
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue,
                  ),
                );
              },
            ),
          ),
          
          // Content
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _vouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              _shops.isEmpty 
                ? 'Đang tải danh sách shop...' 
                : 'Đang tải voucher shop...',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (_shops.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tìm thấy ${_shops.length} shop',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      );
    }

    if (_error != null && _vouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shop,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadVouchers(isRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Color.fromARGB(255, 85, 157, 215)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shop,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Voucher từ các shop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_vouchers.length} voucher có sẵn',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Vouchers list
        Expanded(
          child: ListView.builder(
            itemCount: _vouchers.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _vouchers.length) {
                // Load more indicator
                if (_hasMore) {
                  _loadMore();
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
              
              final voucher = _vouchers[index];
              return VoucherCard(
                voucher: voucher,
                onTap: () => _showVoucherDetails(voucher),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showVoucherDetails(Voucher voucher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      voucher.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voucher.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (voucher.shopName != null)
                          Text(
                            voucher.shopName!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Discount info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              voucher.formattedDiscount,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Giảm giá ${voucher.discountType == 'percentage' ? 'phần trăm' : 'cố định'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (voucher.minOrderValue != null)
                                  Text(
                                    voucher.formattedMinOrder,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Description
                    if (voucher.description.isNotEmpty) ...[
                      const Text(
                        'Mô tả',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        voucher.description,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Terms
                    if (voucher.terms != null && voucher.terms!.isNotEmpty) ...[
                      const Text(
                        'Điều kiện sử dụng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        voucher.terms!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Usage info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                voucher.daysRemaining != null
                                    ? 'Còn ${voucher.daysRemaining} ngày'
                                    : 'Không giới hạn thời gian',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          if (voucher.usageLimit != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${voucher.usedCount ?? 0}/${voucher.usageLimit} người đã sử dụng',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
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
            
            // Applicable products (nếu có)
            if (voucher.applicableProductsDetail != null && voucher.applicableProductsDetail!.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sản phẩm áp dụng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final p = voucher.applicableProductsDetail![index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              productId: int.tryParse(p['id'] ?? ''),
                              title: p['title'],
                              image: p['image'],
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 90,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 90,
                                height: 90,
                                color: const Color(0xFFF4F6FB),
                                child: (p['image'] != null && p['image']!.isNotEmpty)
                                    ? Image.network(p['image']!, fit: BoxFit.cover)
                                    : const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Flexible(
                              child: Text(
                                p['title'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, height: 1.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: voucher.applicableProductsDetail!.length,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Bottom action
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: voucher.canUse ? () {
                    Navigator.pop(context);
                    _copyVoucherCode(voucher.code);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: voucher.canUse ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    voucher.canUse ? 'Sao chép mã voucher' : 'Voucher đã hết hạn',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyVoucherCode(String code) {
    // TODO: Implement copy to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép mã voucher: $code'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
