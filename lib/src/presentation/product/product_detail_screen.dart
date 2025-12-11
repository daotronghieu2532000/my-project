import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'product_description_screen.dart';
import 'widgets/bottom_actions.dart';
import 'widgets/variant_selection_dialog.dart';
import 'widgets/simple_purchase_dialog.dart';
import 'widgets/row_tile.dart';
import 'widgets/voucher_row.dart';
import 'widgets/product_reviews_section.dart';
import 'widgets/shop_bar.dart';
import 'widgets/section_header.dart';
import 'widgets/specs_table.dart';
import 'widgets/description_text.dart';
// import 'widgets/flash_sale_timer.dart'; // Đã không dùng - thay bằng badge inline
// import 'widgets/viewed_product_card.dart'; // Đã ẩn để dùng lại sau
// import 'widgets/similar_product_card.dart'; // Đã thay thế bằng RelatedProductCard
import 'widgets/related_product_card_horizontal.dart';
import 'widgets/same_shop_product_card_horizontal.dart';
import 'widgets/product_carousel.dart';
import '../../core/utils/format_utils.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/models/product_detail.dart';
import '../../core/models/same_shop_product.dart';
import '../../core/models/related_product.dart';
import '../search/search_screen.dart';
import '../cart/cart_screen.dart';
import '../checkout/checkout_screen.dart';
import '../shop/shop_detail_screen.dart';
import '../chat/chat_screen.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/affiliate_tracking_service.dart';
import '../common/widgets/go_top_button.dart';
import '../account/support_center_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int? productId;
  final String? title;
  final String? image;
  final int? price;
  final int? initialShopId;
  final String? initialShopName;
  
  const ProductDetailScreen({
    super.key, 
    this.productId,
    this.title, 
    this.image, 
    this.price,
    this.initialShopId,
    this.initialShopName,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _apiService = ApiService();
  final CachedApiService _cachedApiService = CachedApiService();
  ProductDetail? _productDetail;
  List<SameShopProduct> _sameShopProducts = [];
  bool _isLoading = true;
  bool _isLoadingSameShop = false;
  String? _error;
  
  // Related products
  List<RelatedProduct> _relatedProducts = [];
  bool _isLoadingRelatedProducts = false;
  ProductVariant? _selectedVariant;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final AffiliateTrackingService _affiliateTracking = AffiliateTrackingService();
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;
  int? _cachedUserId; // Cache userId để tránh gọi getCurrentUser nhiều lần
  
  // Rating và reviews từ API product_reviews (dữ liệu thật)
  double? _realRating;
  int? _realReviewsCount;
  List<Map<String, dynamic>> _reviews = []; // Lưu reviews để hiển thị
  bool _isLoadingReviews = false;
  
  // Progressive loading flags
  bool _relatedLoaded = false;
  bool _sameShopLoaded = false;
  bool _ratingStatsLoaded = false;
  bool _reviewsLoaded = false;
  
  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite || widget.productId == null) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      // Sử dụng cached userId nếu có, nếu không thì lấy lại
      if (_cachedUserId == null) {
        await _cacheUserId();
      }
      
      if (_cachedUserId == null) {
        if (mounted) {
          setState(() {
            _isTogglingFavorite = false;
          });
        _showSnack('Vui lòng đăng nhập để thực hiện thao tác này', background: Colors.red);
        }
        return;
      }

      final result = await _apiService.toggleFavoriteProduct(
        userId: _cachedUserId!,
        productId: widget.productId!,
      );

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>?;
        final isFavorite = data?['is_favorite'] as bool? ?? false;
        
        setState(() {
          _isFavorite = isFavorite;
        });

        final message = isFavorite ? 'Đã thêm vào danh sách yêu thích' : 'Đã xóa khỏi danh sách yêu thích';
        _showSnack(message, background: Colors.green);
      } else {
        _showSnack('Không thể thực hiện thao tác này', background: Colors.red);
      }
    } catch (e) {
      _showSnack('Lỗi khi thực hiện thao tác: $e', background: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
    }
  }

  void _showSnack(String message, {SnackBarAction? action, Color? background}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          duration: const Duration(seconds: 1),
          action: action,
        ),
      );
    });
  }

  void _navigateToShop() {
    if (_productDetail == null) return;
    
    final shopId = int.tryParse(_productDetail!.shopId ?? '0');
    final shopUsername = _productDetail!.shopNameFromInfo.isNotEmpty 
        ? _productDetail!.shopNameFromInfo 
        : null;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDetailScreen(
          shopId: shopId,
          shopUsername: shopUsername,
          shopName: _productDetail!.shopNameFromInfo.isNotEmpty 
              ? _productDetail!.shopNameFromInfo 
              : widget.initialShopName,
          shopAvatar: _productDetail!.shopAvatar,
        ),
      ),
    );
  }

  void _navigateToChat() {
    if (_productDetail == null) return;
    
    final shopId = int.tryParse(_productDetail!.shopId ?? '0');
  
    
    if (shopId == null || shopId == 0) {
     
      _showSnack('Không thể xác định shop để chat', background: Colors.red);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          shopId: shopId,
          shopName: _productDetail!.shopNameFromInfo.isNotEmpty 
              ? _productDetail!.shopNameFromInfo 
              : widget.initialShopName ?? 'Shop',
          shopAvatar: _productDetail!.shopAvatar,
        ),
      ),
    );
  }

  void _showReturnPolicyDialog() {
    if (_productDetail == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
            const SizedBox(height: 16),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Đổi trả hàng trong vòng 15 ngày',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Policy information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPolicyItem(
                    icon: Icons.verified_user_outlined,
                    text: 'Bạn có thể hoàn toàn được đồng kiểm sản phẩm khi nhân đơn hàng.',
                  ),
                  const SizedBox(height: 12),
                  _buildPolicyItem(
                    icon: Icons.camera_alt_outlined,
                    text: 'Khi yêu cầu đổi trả vui lòng cung cấp video, hình ảnh sản phẩm, lý do đổi trả.',
                  ),
                  const SizedBox(height: 12),
                  _buildPolicyItem(
                    icon: Icons.local_shipping_outlined,
                    text: 'Miễn phí trả hàng trong 15 ngày, bạn hoàn toàn yên tâm khi mua hàng.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Shop info (giống ShopBar nhưng thay nút xem shop bằng nút chat)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: _productDetail!.shopAvatar.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.network(
                                _productDetail!.shopAvatar,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _productDetail!.shopNameFromInfo.isNotEmpty
                                ? _productDetail!.shopNameFromInfo
                                : 'Shop',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_productDetail!.shopInfo?['total_products'] != null &&
                              (_productDetail!.shopInfo!['total_products'] as int) > 0) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_productDetail!.shopInfo!['total_products']} sản phẩm',
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
                            _productDetail!.shopAddress.isNotEmpty
                                ? _productDetail!.shopAddress
                                : '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Chat button thay vì "Xem Shop"
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Đóng dialog
                        _navigateToChat(); // Mở chat
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE53E3E), Color(0xFFC53030)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Chat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Contact Socdo section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    'Nếu không thể liên hệ với Nhà bán, hãy liên lạc chúng tôi',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Đóng dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SupportCenterScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 255, 2, 2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.headset_mic, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Liên hệ ngay với Socdo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showVoucherDialog() {
    if (_productDetail == null || !_productDetail!.hasCoupon) return;
    
    final couponInfo = _productDetail!.couponInfo;
    final couponCode = _productDetail!.couponCode;
    final couponType = couponInfo?['coupon_type'] as String? ?? '';
    final couponDiscount = (couponInfo?['coupon_discount'] as num?)?.toInt() ?? 0;
    final couponDescription = couponInfo?['coupon_description'] as String? ?? '';
    final couponMinOrder = (couponInfo?['coupon_min_order'] as num?)?.toInt() ?? 0;
    final currentPrice = _selectedVariant?.price ?? _productDetail!.price;
    final isEligible = currentPrice >= couponMinOrder;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
            const SizedBox(height: 16),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Mã giảm giá',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Voucher code
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFFF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEligible ? Colors.green : Colors.orange,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer,
                          color: isEligible ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                couponCode,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isEligible ? Colors.green : Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                couponType == 'tru' 
                                    ? 'Giảm ${couponDiscount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}đ'
                                    : 'Giảm $couponDiscount%',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isEligible ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isEligible ? 'Đủ điều kiện' : 'Chưa đủ điều kiện',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Conditions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Điều kiện sử dụng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (couponMinOrder > 0)
                    _buildPolicyItem(
                      icon: Icons.shopping_cart_outlined,
                      text: 'Đơn hàng tối thiểu: ${couponMinOrder.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}đ',
                      isEligible: currentPrice >= couponMinOrder,
                    ),
                  if (couponDescription.isNotEmpty) ...[
                    if (couponMinOrder > 0) const SizedBox(height: 12),
                    _buildPolicyItem(
                      icon: Icons.info_outline,
                      text: couponDescription,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildPolicyItem(
                    icon: Icons.attach_money,
                    text: 'Giá trị đơn hàng hiện tại: ${currentPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}đ',
                    isEligible: isEligible,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Copy button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Copy coupon code to clipboard
                    // TODO: Implement clipboard copy
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEligible ? Colors.green : Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sao chép mã',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyItem({required IconData icon, required String text, bool? isEligible}) {
    final iconColor = isEligible == null 
        ? const Color(0xFF4CAF50) 
        : (isEligible ? Colors.green : Colors.orange);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: iconColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isEligible == null ? Colors.black87 : (isEligible ? Colors.green : Colors.orange),
              height: 1.5,
              fontWeight: isEligible != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Cache userId một lần để tránh gọi getCurrentUser nhiều lần
    _cacheUserId();
    if (widget.productId != null) {
      _loadProductDetail();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Cache userId một lần để tránh gọi getCurrentUser nhiều lần
  Future<void> _cacheUserId() async {
    try {
      final user = await _authService.getCurrentUser();
      _cachedUserId = user?.userId;
    } catch (e) {
      _cachedUserId = null;
    }
  }
  
  void _onScroll() {
    // Scroll detection không cần thiết nữa vì đã load ngay sau basic info
    // Giữ lại để có thể dùng cho các tính năng khác sau này
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load product basic info (Priority 1 - Immediate)
  /// Sử dụng API mới product_detail_basic để load nhanh hơn
  Future<void> _loadProductDetail() async {
    try {
      // Hiển thị UI ngay với loading state (không block)
      if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentImageIndex = 0; // Reset image index
        _reviews = []; // Reset reviews khi load lại
        _isLoadingReviews = false; // Reset loading state
        _reviewsLoaded = false; // Reset flag để có thể load lại
      });
      }

      // Sử dụng cached userId để tránh gọi getCurrentUser nhiều lần
      if (_cachedUserId == null) {
        await _cacheUserId();
      }
      
      // Kiểm tra cache trước (nhanh hơn)
      final cachedProduct = await _cachedApiService.getProductDetailBasicCached(
        widget.productId!,
        userId: _cachedUserId,
        forceRefresh: false, // Ưu tiên cache
      );
      
      // Nếu có cache, hiển thị ngay
      if (cachedProduct != null && mounted) {
        setState(() {
          _isLoading = false;
          _productDetail = cachedProduct;
          _isFavorite = cachedProduct.isFavorited;
          if (cachedProduct.variants.isNotEmpty) {
            _selectedVariant = cachedProduct.variants.first;
          }
        });
        
        // Track affiliate view if has valid affiliate tracking
        if (widget.productId != null) {
          _affiliateTracking.trackAffiliateView(productId: widget.productId);
        }
        
        // Load fresh data trong background
        _loadProductDetailFresh();
        return;
      }
      
      // Nếu không có cache, load từ API
      final productDetail = await _cachedApiService.getProductDetailBasicCached(
        widget.productId!,
        userId: _cachedUserId,
        forceRefresh: true, // Force refresh nếu không có cache
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _productDetail = productDetail;
          // Cập nhật trạng thái yêu thích từ API
          _isFavorite = productDetail?.isFavorited ?? false;
          // Khởi tạo biến thể đầu tiên nếu có
          if (productDetail?.variants.isNotEmpty == true) {
            _selectedVariant = productDetail!.variants.first;
          }
        });
        
        // Load các phần khác với delay để ưu tiên hiển thị basic info trước
        if (productDetail != null) {
          // Track affiliate view if has valid affiliate tracking
          if (widget.productId != null) {
            _affiliateTracking.trackAffiliateView(productId: widget.productId);
          }
          
          // Sử dụng rating từ product_detail_basic API trước (đã có sẵn)
          setState(() {
            _realRating = productDetail.rating;
            _realReviewsCount = productDetail.reviewsCount;
          });
          
          // Priority 2: Load rating stats và reviews cùng lúc (gộp thành 1 API call)
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _loadRatingAndReviews();
          });
          
          // Priority 4-5: Load các phần khác sau 200ms (lazy load)
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
          _loadRelatedProducts();
          _loadSameShopProducts();
            }
          });
        }
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
  
  /// Load fresh data trong background (sau khi đã hiển thị cache)
  Future<void> _loadProductDetailFresh() async {
    try {
      final productDetail = await _cachedApiService.getProductDetailBasicCached(
        widget.productId!,
        userId: _cachedUserId,
        forceRefresh: true, // Force refresh để lấy data mới nhất
      );
      
      if (mounted && productDetail != null) {
        setState(() {
          _productDetail = productDetail;
          _isFavorite = productDetail.isFavorited;
          if (productDetail.variants.isNotEmpty && _selectedVariant == null) {
            _selectedVariant = productDetail.variants.first;
          }
        });
        
        // Sử dụng rating từ product_detail_basic API trước (đã có sẵn)
        if (mounted) {
          setState(() {
            _realRating = productDetail.rating;
            _realReviewsCount = productDetail.reviewsCount;
          });
          
          // Load rating và reviews cùng lúc (gộp thành 1 API call)
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _loadRatingAndReviews();
          });
          
          // Load các phần khác
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _loadRelatedProducts();
              _loadSameShopProducts();
            }
          });
        }
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

  /// Load same shop products (Priority 5 - Progressive, ngay sau basic info)
  Future<void> _loadSameShopProducts() async {
    if (widget.productId == null || _sameShopLoaded) return;
    _sameShopLoaded = true;
    
    try {
      setState(() {
        _isLoadingSameShop = true;
      });

      // Sử dụng cached API service cho same shop products
      final responseData = await _cachedApiService.getSameShopProductsCached(
        widget.productId!,
        limit: 10,
      );
      
      // Nếu cache không có data, fallback về ApiService
      Map<String, dynamic>? response;
      if (responseData == null || responseData.isEmpty) {
       
        response = await _apiService.getProductsSameShop(
          productId: widget.productId!,
          limit: 10,
        );
      } else {
      
        response = responseData;
      }
      
      if (mounted && response != null) {
        final data = response['data'] as Map<String, dynamic>?;
        final products = data?['products'] as List?;
        
        if (products != null) {
          final sameShopProducts = products
              .map((product) => SameShopProduct.fromJson(product as Map<String, dynamic>))
              .toList();
          
          setState(() {
            _sameShopProducts = sameShopProducts;
            _isLoadingSameShop = false;
          });
        } else {
          setState(() {
            _isLoadingSameShop = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSameShop = false;
        });
      }
     
    }
  }

  /// Reload reviews sau khi block user (không reset flags)
  Future<void> _reloadReviewsAfterBlock() async {
    if (widget.productId == null) return;
    
    try {
      setState(() {
        _isLoadingReviews = true;
      });
      
      // Reload reviews với cùng limit
      final reviewsData = await _apiService.getProductReviews(
        productId: widget.productId!,
        page: 1,
        limit: 2,
      );
      
      if (mounted && reviewsData != null && reviewsData['success'] == true) {
        final data = reviewsData['data'] as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            final reviewsList = data['reviews'] as List?;
            if (reviewsList != null) {
              _reviews = reviewsList.cast<Map<String, dynamic>>();
            }
            _isLoadingReviews = false;
          });
        } else {
          setState(() {
            _isLoadingReviews = false;
          });
        }
      } else {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  /// Load rating stats và reviews cùng lúc (gộp thành 1 API call để tối ưu)
  /// Priority 2 - Load ngay sau basic info
  Future<void> _loadRatingAndReviews() async {
    if (widget.productId == null || (_ratingStatsLoaded && _reviewsLoaded)) return;
    
    // Đánh dấu đã load để tránh gọi lại
    _ratingStatsLoaded = true;
    _reviewsLoaded = true;
    
    try {
      setState(() {
        _isLoadingReviews = true;
      });
      
      // Gộp 2 API calls thành 1: Lấy cả rating stats và reviews cùng lúc
      final reviewsData = await _apiService.getProductReviews(
        productId: widget.productId!,
        page: 1,
        limit: 2, // Lấy 2 reviews đầu tiên, API sẽ trả về cả stats
      );
      
      if (mounted && reviewsData != null && reviewsData['success'] == true) {
        final data = reviewsData['data'] as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            // Cập nhật rating stats (dữ liệu thật từ API)
            _realRating = (data['average_rating'] as num?)?.toDouble();
            _realReviewsCount = data['total_reviews'] as int?;
            
            // Cập nhật reviews
          final reviewsList = data['reviews'] as List?;
          if (reviewsList != null) {
              _reviews = reviewsList.cast<Map<String, dynamic>>();
            }
              _isLoadingReviews = false;
            });
        } else {
          setState(() {
            _isLoadingReviews = false;
          });
        }
      } else {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  /// Load related products (Priority 4 - Progressive, ngay sau basic info)
  Future<void> _loadRelatedProducts() async {
    if (widget.productId == null || _relatedLoaded) return;
    _relatedLoaded = true;
    
    try {
      setState(() {
        _isLoadingRelatedProducts = true;
      });

      // Sử dụng cached API service cho related products
      final relatedProductsData = await _cachedApiService.getRelatedProductsCached(
        widget.productId!,
        limit: 8,
        type: 'auto',
      );
      
      // Nếu cache không có data, fallback về ApiService
      List<RelatedProduct>? relatedProducts;
      if (relatedProductsData == null || relatedProductsData.isEmpty) {
      
        relatedProducts = await _apiService.getRelatedProducts(
          productId: widget.productId!,
          limit: 8,
          type: 'auto',
        );
      } else {
      
        // Convert cached data to RelatedProduct list
        relatedProducts = relatedProductsData
            .map((data) => RelatedProduct.fromJson(data))
            .toList();
      }
      
      if (mounted && relatedProducts != null) {
        setState(() {
          _relatedProducts = relatedProducts!;
          _isLoadingRelatedProducts = false;
        });
      } else {
        setState(() {
          _isLoadingRelatedProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRelatedProducts = false;
        });
      }
     
    }
  }


  void _showPurchaseDialog({String? actionType}) {
    if (_productDetail == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Nếu có biến thể, hiển thị dialog chọn biến thể
        if (_productDetail!.variants.isNotEmpty) {
          return VariantSelectionDialog(
            product: _productDetail!,
            selectedVariant: _selectedVariant,
            onBuyNow: _handleBuyNow,
            onAddToCart: _handleAddToCart,
            actionType: actionType,
          );
        } else {
          // Nếu không có biến thể, hiển thị dialog đơn giản
          return SimplePurchaseDialog(
            product: _productDetail!,
            onBuyNow: _handleBuyNowSimple,
            onAddToCart: _handleAddToCartSimple,
            actionType: actionType,
          );
        }
      },
    );
  }

  // Xử lý MUA NGAY cho sản phẩm có biến thể
  void _handleBuyNow(ProductVariant variant, int quantity) {
   
    
    final product = _productDetail!;
    
    // Thêm sản phẩm vào giỏ hàng
    final cartItem = CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: int.tryParse(product.shopId ?? (widget.initialShopId?.toString() ?? '0')) ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : (widget.initialShopName ?? 'Unknown Shop'),
      addedAt: DateTime.now(),
    );
    _cartService.addItem(cartItem);
    
    // Hiển thị thông báo an toàn sau frame
    _showSnack('Đã thêm ${variant.name} vào giỏ hàng', background: Colors.green);
    
    // Chuyển đến trang thanh toán
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  // Xử lý THÊM VÀO GIỎ cho sản phẩm có biến thể
  void _handleAddToCart(ProductVariant variant, int quantity) {
    final product = _productDetail!;
    
    // Thêm sản phẩm vào giỏ hàng
    final cartItem = CartItem(
      id: product.id,
      name: '${product.name} - ${variant.name}',
      image: product.imageUrl,
      price: variant.price,
      oldPrice: variant.oldPrice,
      quantity: quantity,
      variant: variant.name,
      shopId: int.tryParse(product.shopId ?? '0') ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : 'Unknown Shop',
      addedAt: DateTime.now(),
    );
    _cartService.addItem(cartItem);
    
    // Hiển thị thông báo và nút xem giỏ hàng
    _showSnack(
      'Đã thêm ${variant.name} vào giỏ hàng',
      background: Colors.green, // Thêm màu xanh cho thông báo thành công
      action: SnackBarAction(
        label: 'Xem giỏ hàng',
        textColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          );
        },
      ),
    );
  }


  // Xử lý MUA NGAY cho sản phẩm không có biến thể
  void _handleBuyNowSimple(ProductDetail product, int quantity) {
   
    // Thêm sản phẩm vào giỏ hàng
    final cartItem = CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: int.tryParse(product.shopId ?? (widget.initialShopId?.toString() ?? '0')) ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : (widget.initialShopName ?? 'Unknown Shop'),
      addedAt: DateTime.now(),
    );

    _cartService.addItem(cartItem);
    
    _showSnack('Đã thêm ${product.name} vào giỏ hàng', background: Colors.green);
    
    // Chuyển đến trang thanh toán
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  // Xử lý THÊM VÀO GIỎ cho sản phẩm không có biến thể
  void _handleAddToCartSimple(ProductDetail product, int quantity) {
    // Thêm sản phẩm vào giỏ hàng
    final cartItem = CartItem(
      id: product.id,
      name: product.name,
      image: product.imageUrl,
      price: product.price,
      oldPrice: product.oldPrice,
      quantity: quantity,
      shopId: int.tryParse(product.shopId ?? (widget.initialShopId?.toString() ?? '0')) ?? 0,
      shopName: product.shopNameFromInfo.isNotEmpty ? product.shopNameFromInfo : (widget.initialShopName ?? 'Unknown Shop'),
      addedAt: DateTime.now(),
    );
    _cartService.addItem(cartItem);
    
    _showSnack(
      'Đã thêm ${product.name} vào giỏ hàng',
      background: Colors.green, // Thêm màu xanh cho thông báo thành công
      action: SnackBarAction(
        label: 'Xem giỏ hàng',
        textColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          );
        },
      ),
    );
  }



  Widget _buildImageCarousel(ProductDetail? product, String fallbackImage) {
    // Nếu có nhiều ảnh từ API, sử dụng PageView
    if (product?.images.isNotEmpty == true) {
      final productImages = product!.images; // Safe to use ! here because of the null check above
      return GestureDetector(
        onTap: () {
          // Mở gallery xem ảnh phóng to
          _showImageGallery(productImages, _currentImageIndex);
        },
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemCount: productImages.length,
          itemBuilder: (context, index) {
            return _buildSingleImage(productImages[index]);
          },
        ),
      );
    } else {
      // Fallback về ảnh đơn lẻ
      final singleImage = _productDetail?.mainImageUrl ?? fallbackImage;
      return GestureDetector(
        onTap: () {
          // Mở gallery xem ảnh phóng to
          _showImageGallery([singleImage], 0);
        },
        child: _buildSingleImage(singleImage),
      );
    }
  }

  // Hiển thị gallery ảnh phóng to (giống Shopee)
  void _showImageGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return _ImageGalleryViewer(
          images: images,
          initialIndex: initialIndex,
      );
      },
    );
  }

  Widget _buildSingleImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
         
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('NO IMAGE AVAILABLE', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('URL: ${imageUrl.length > 50 ? '${imageUrl.substring(0, 50)}...' : imageUrl}', 
                       style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
         
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('NO IMAGE AVAILABLE', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void _nextImage() {
    if (_productDetail?.images.isNotEmpty == true && 
        _currentImageIndex < _productDetail!.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousImage() {
    if (_currentImageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Các method _handleMoreOptions, _shareProduct, _toggleFavorite, _reportProduct đã được xóa
  // vì nút ... đã bị ẩn theo yêu cầu

  /// Skeleton loading widget (hiển thị khi đang load basic info)
  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          Container(
            height: 400,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          const SizedBox(height: 16),
          // Title skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 24,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 24,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                // Price skeleton
                Container(
                  height: 32,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Skeleton loading khi đang load basic info
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sản phẩm'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: _buildSkeletonLoading(),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProductDetail,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final product = _productDetail;
    final title = product?.name ?? widget.title ?? 'Sản phẩm';
    final image = product?.imageUrl ?? widget.image ?? 'lib/src/core/assets/images/product_1.png';
    final price = _selectedVariant?.price ?? product?.price ?? widget.price ?? 0;
    final oldPrice = _selectedVariant?.oldPrice ?? product?.oldPrice;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomActions(
        price: price,
        shopId: int.tryParse(_productDetail?.shopId ?? '0'),
        onChat: _navigateToChat,
        onBuyNow: () => _showPurchaseDialog(actionType: 'buyNow'),
        onAddToCart: () => _showPurchaseDialog(actionType: 'addToCart'),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 340,
            title: Text(
              title, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Thêm padding để tránh bị cắt ảnh
            toolbarHeight: 56,
            collapsedHeight: 56,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            actions: [
              // Search button - Navigate to search screen
              IconButton(
                onPressed: () {
                  // ✅ Sử dụng PageRouteBuilder với animation nhanh hơn để tăng tốc độ navigation
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        // ✅ Slide animation nhanh hơn (200ms thay vì 300ms mặc định)
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeOut;
                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);
                        return SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 200), // ✅ Nhanh hơn 100ms
                    ),
                  );
                },
                icon: const Icon(Icons.search),
                tooltip: 'Tìm kiếm',
              ),
              // Cart button - Navigate to cart screen with badge
              ListenableBuilder(
                listenable: _cartService,
                builder: (context, child) {
                  return GestureDetector(
                    onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CartScreen(),
                    ),
                  );
                },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 24,
                          ),
                          if (_cartService.itemCount > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _cartService.itemCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // More options menu - Đã ẩn theo yêu cầu
              // PopupMenuButton<String>(
              //   onSelected: (value) {
              //     _handleMoreOptions(value);
              //   },
              //   itemBuilder: (BuildContext context) => [
              //     const PopupMenuItem<String>(
              //       value: 'share',
              //       child: Row(
              //         children: [
              //           Icon(Icons.share, size: 20),
              //           SizedBox(width: 8),
              //           Text('Chia sẻ sản phẩm'),
              //         ],
              //       ),
              //     ),
              //     const PopupMenuItem<String>(
              //       value: 'favorite',
              //       child: Row(
              //         children: [
              //           Icon(Icons.favorite_border, size: 20),
              //           SizedBox(width: 8),
              //           Text('Thêm vào yêu thích'),
              //         ],
              //       ),
              //     ),
              //     const PopupMenuItem<String>(
              //       value: 'report',
              //       child: Row(
              //         children: [
              //           Icon(Icons.report_outlined, size: 20),
              //           SizedBox(width: 8),
              //           Text('Báo cáo sản phẩm'),
              //         ],
              //       ),
              //     ),
              //   ],
              //   icon: const Icon(Icons.more_horiz),
              //   tooltip: 'Thêm tùy chọn',
              // ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hiển thị carousel hình ảnh
                  _buildImageCarousel(product, image),
                  // Hiển thị số lượng hình ảnh nếu có gallery
                  if (product?.images.isNotEmpty == true)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          '${_currentImageIndex + 1}/${product!.images.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  // Navigation arrows
                  if (product?.images.isNotEmpty == true && product!.images.length > 1) ...[
                    // Previous arrow
                    if (_currentImageIndex > 0)
                      Positioned(
                        left: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _previousImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Next arrow
                    if (_currentImageIndex < product.images.length - 1)
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _nextImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(FormatUtils.formatCurrency(price),
                                style: const TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w800)),
                            if (oldPrice != null) ...[
                              const SizedBox(width: 8),
                              Text(FormatUtils.formatCurrency(oldPrice),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  )),
                            ],
                          ],
                        ),
                      ),
                      // Flash Sale Badge (nếu có flash sale)
                      if (product?.isFlashSale == true)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade700, Colors.red.shade700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SALE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Icon trái tim có thể tương tác
                      GestureDetector(
                        onTap: _toggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: _isTogglingFavorite
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: _isFavorite ? Colors.red : Colors.grey,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title, 
                      style: const TextStyle(fontSize: 16)),
                  // TODO: Hiển thị chọn biến thể với thiết kế minimalist hiện đại (nếu có) - ĐÃ COMMENT TẠM THỜI
                  // if (product?.variants.isNotEmpty == true) ...[
                  //   Container(
                  //     padding: const EdgeInsets.all(16),
                  //     decoration: BoxDecoration(
                  //       color: Colors.white,
                  //       borderRadius: BorderRadius.circular(12),
                  //       border: Border.all(color: Colors.grey[100]!, width: 1),
                  //     ),
                  //     child: Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       children: [
                  //         // Header với giá
                  //         Row(
                  //           children: [
                  //             Text(
                  //               'Chọn biến thể',
                  //               style: TextStyle(
                  //                 fontSize: 15,
                  //                 fontWeight: FontWeight.w600,
                  //                 color: Colors.grey[800],
                  //               ),
                  //             ),
                  //             const Spacer(),
                  //             Container(
                  //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  //               decoration: BoxDecoration(
                  //                 color: Colors.red[50],
                  //                 borderRadius: BorderRadius.circular(6),
                  //               ),
                  //               child: Text(
                  //                 '${_selectedVariant?.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫',
                  //                 style: TextStyle(
                  //                   fontSize: 14,
                  //                   fontWeight: FontWeight.bold,
                  //                   color: Colors.red[700],
                  //                 ),
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //         const SizedBox(height: 12),
                  //         // Selection buttons minimalist
                  //         ...product!.variants.map((ProductVariant variant) {
                  //           final isSelected = _selectedVariant?.id == variant.id;
                  //           return Container(
                  //             margin: const EdgeInsets.only(bottom: 8),
                  //             child: InkWell(
                  //               onTap: () {
                  //                 setState(() {
                  //                   _selectedVariant = variant;
                  //                 });
                  //               },
                  //               borderRadius: BorderRadius.circular(8),
                  //               child: Container(
                  //                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  //                 decoration: BoxDecoration(
                  //                   color: isSelected ? Colors.red[50] : Colors.transparent,
                  //                   borderRadius: BorderRadius.circular(8),
                  //                   border: Border.all(
                  //                     color: isSelected ? Colors.red : Colors.grey[200]!,
                  //                     width: isSelected ? 1.5 : 1,
                  //                   ),
                  //                 ),
                  //                 child: Row(
                  //                   children: [
                  //                     // Radio button custom
                  //                     Container(
                  //                       width: 20,
                  //                       height: 20,
                  //                       decoration: BoxDecoration(
                  //                         shape: BoxShape.circle,
                  //                         border: Border.all(
                  //                           color: isSelected ? Colors.red : Colors.grey[400]!,
                  //                           width: 2,
                  //                         ),
                  //                       ),
                  //                       child: isSelected
                  //                           ? Center(
                  //                               child: Container(
                  //                                 width: 8,
                  //                                 height: 8,
                  //                                 decoration: const BoxDecoration(
                  //                                   color: Colors.red,
                  //                                   shape: BoxShape.circle,
                  //                                 ),
                  //                               ),
                  //                             )
                  //                           : null,
                  //                     ),
                  //                     const SizedBox(width: 12),
                  //                     Expanded(
                  //                       child: Text(
                  //                         variant.name,
                  //                         style: TextStyle(
                  //                           fontSize: 14,
                  //                           fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  //                           color: isSelected ? Colors.red[700] : Colors.grey[700],
                  //                         ),
                  //                       ),
                  //                     ),
                  //                     Text(
                  //                       '${variant.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫',
                  //                       style: TextStyle(
                  //                         fontSize: 13,
                  //                         fontWeight: FontWeight.w600,
                  //                         color: Colors.red[600],
                  //                       ),
                  //                     ),
                  //                   ],
                  //                 ),
                  //               ),
                  //             ),
                  //           );
                  //         }).toList(),
                  //       ],
                  //     ),
                  //   ),
                  //   const SizedBox(height: 16),
                  // ],
                  const SizedBox(height: 12),
                  RowTile(
                    icon: Icons.autorenew,
                    title: 'Đổi trả hàng trong vòng 15 ngày',
                    onTap: () => _showReturnPolicyDialog(),
                  ),
                  const SizedBox(height: 8),
                  // Hiển thị mã giảm giá nếu có
                  if (product?.hasCoupon == true)
                    VoucherRow(
                      couponCode: product!.couponCode,
                      couponDetails: product.couponDetails,
                      onTap: () => _showVoucherDialog(),
                    ),
                ],
              ),
            ),
          ),
          // Hiển thị đánh giá - LUÔN HIỂN THỊ (với loading state nếu chưa có data)
          SliverToBoxAdapter(
            child: ProductReviewsSection(
              reviews: _reviews.isNotEmpty 
                  ? _reviews 
                  : (product?.reviews != null && (product!.reviews as List).isNotEmpty) 
                      ? product.reviews as List<Map<String, dynamic>> 
                      : [], // Empty list nếu chưa có reviews
              productId: product?.id ?? widget.productId ?? 0,
              totalReviews: _realReviewsCount ?? product?.reviewsCount ?? 0, // Ưu tiên dữ liệu thật từ product_reviews API
              rating: _realRating ?? product?.rating ?? 0.0, // Ưu tiên dữ liệu thật từ product_reviews API
              isLoading: _isLoadingReviews, // Truyền loading state
              onBlockUser: () {
                // Reload reviews sau khi block user
                _reloadReviewsAfterBlock();
              },
            ),
          ),
          ShopBar(
            shopName: product?.shopNameFromInfo,
            shopAvatar: product?.shopAvatar,
            shopAddress: product?.shopAddress,
            shopUrl: product?.shopUrl,
            rating: () {
              // shop_rating có thể là int (khi shop không có đánh giá) hoặc double (khi shop có đánh giá)
              final shopRatingValue = product?.shopInfo?['shop_rating'];
              if (shopRatingValue == null) return 0.0;
              // Xử lý cả int và double
              if (shopRatingValue is double) return shopRatingValue;
              if (shopRatingValue is int) return shopRatingValue.toDouble();
              // Fallback: thử parse nếu là String hoặc num
              if (shopRatingValue is num) return shopRatingValue.toDouble();
              return 0.0;
            }(),
            reviewCount: () {
              final shopReviews = product?.shopInfo?['shop_reviews'] as int?;
              return shopReviews ?? 0;
            }(),
            totalProducts: () {
              final totalProducts = product?.shopInfo?['total_products'] as int?;
              return totalProducts;
            }(),
            onViewShop: _navigateToShop,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2), // Giảm từ 8 xuống 2
                  // Sản phẩm cùng gian hàng - LUÔN HIỂN THỊ
                  if (_isLoadingSameShop)
                    Column(
                      children: [
                        const SectionHeader('Sản phẩm cùng gian hàng'),
                        const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    )
                  else if (_sameShopProducts.isNotEmpty) ...[
                    ProductCarousel(
                      title: 'Sản phẩm cùng gian hàng',
                      height: 300, // Tăng height để phù hợp với layout dọc 2 cột
                      itemWidth: 0, // Không dùng itemWidth nữa, tính động trong ProductCarousel
                      children: _sameShopProducts.map((product) {
                        return SameShopProductCardHorizontal(product: product);
                      }).toList(),
                    ),
                  ] else
                    Column(
                      children: [
                        const SectionHeader('Sản phẩm cùng gian hàng'),
                        const SizedBox(
                          height: 100,
                          child: Center(
                            child: Text(
                              'Không có sản phẩm cùng gian hàng',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8), // Giảm từ 16 xuống 8
                  // Hiển thị đặc điểm nổi bật nếu có
                  if (product?.highlights?.isNotEmpty == true) ...[
                    const SectionHeader('Đặc điểm nổi bật'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Html(
                        data: product!.highlights!,
                        style: {
                          "body": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(14),
                            lineHeight: const LineHeight(1.5),
                          ),
                          "ul": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            listStyleType: ListStyleType.none,
                          ),
                          "li": Style(
                            margin: Margins.only(bottom: 8),
                            padding: HtmlPaddings.zero,
                          ),
                          "p": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                          ),
                          "img": Style(
                            width: Width(300),
                            height: Height.auto(),
                            margin: Margins.symmetric(vertical: 8),
                          ),
                        },
                        extensions: [
                          TagExtension(
                            tagsToExtend: {"img"},
                            builder: (context) {
                              final src = context.attributes['src'] ?? '';
                              final fullUrl = src.startsWith('http') 
                                  ? src 
                                  : 'https://socdo.vn$src';
                              return Image.network(
                                fullUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Hiển thị chi tiết sản phẩm nếu có
                  if (product?.description?.isNotEmpty == true) ...[
                    const SectionHeader('Chi tiết sản phẩm'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Html(
                        data: product!.description!,
                        style: {
                          "body": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(14),
                            lineHeight: const LineHeight(1.5),
                          ),
                          "h1, h2, h3, h4, h5, h6": Style(
                            margin: Margins.only(bottom: 8),
                            padding: HtmlPaddings.zero,
                            fontWeight: FontWeight.bold,
                          ),
                          "p": Style(
                            margin: Margins.only(bottom: 8),
                            padding: HtmlPaddings.zero,
                          ),
                          "img": Style(
                            width: Width(300),
                            height: Height.auto(),
                            margin: Margins.symmetric(vertical: 8),
                          ),
                        },
                        extensions: [
                          TagExtension(
                            tagsToExtend: {"img"},
                            builder: (context) {
                              final src = context.attributes['src'] ?? '';
                              final fullUrl = src.startsWith('http') 
                                  ? src 
                                  : 'https://socdo.vn$src';
                              return Image.network(
                                fullUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ],
                  // Fallback nếu không có dữ liệu
                  if ((product?.highlights?.isEmpty ?? true) && (product?.description?.isEmpty ?? true)) ...[
                  const SectionHeader('Chi tiết sản phẩm'),
                  SpecsTable(),
                  const SizedBox(height: 12),
                  DescriptionText(
                    onViewMore: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDescriptionScreen(
                              productName: product?.name ?? 'Sản phẩm',
                              productImage: product?.imageUrl ?? 'lib/src/core/assets/images/product_1.png',
                          ),
                        ),
                      );
                    },
                  ),
                  ],
                  // Mục "Sản phẩm đã xem" đã được ẩn để dùng lại sau
                  // const SizedBox(height: 24),
                  // ProductCarousel(
                  //   title: 'Sản phẩm đã xem',
                  //   itemsPerPage: 2,
                  //   children: List.generate(6, (index) => ViewedProductCard(index: index)),
                  // ),
                  const SizedBox(height: 12), // Giảm từ 24 xuống 12
                  // Sản phẩm liên quan - LUÔN HIỂN THỊ
                  if (_isLoadingRelatedProducts)
                    Column(
                      children: [
                        const SectionHeader('Sản phẩm liên quan'),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ],
                    )
                  else if (_relatedProducts.isNotEmpty) ...[
                    ProductCarousel(
                      title: 'Sản phẩm liên quan',
                      height: 300, // Tăng height để phù hợp với layout dọc 2 cột
                      itemWidth: 0, // Không dùng itemWidth nữa, tính động trong ProductCarousel
                      children: _relatedProducts.map((product) {
                        return RelatedProductCardHorizontal(product: product);
                      }).toList(),
                    ),
                  ] else
                    Column(
                      children: [
                        const SectionHeader('Sản phẩm liên quan'),
                        const SizedBox(
                          height: 100,
                          child: Center(
                            child: Text(
                              'Không có sản phẩm liên quan',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8), // Giảm từ 20 xuống 8
                ],
              ),
            ),
          ),
        ],
      ),
          // Go Top Button
          GoTopButton(
            scrollController: _scrollController,
            showAfterScrollDistance: 1000.0, // Khoảng 2.5 màn hình
          ),
        ],
      ),
    );
  }
}

// Widget hiển thị gallery ảnh phóng to (giống Shopee)
class _ImageGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageGalleryViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<_ImageGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // PageView để swipe giữa các ảnh
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final imageUrl = widget.images[index];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                child: Center(
                  child: imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              padding: const EdgeInsets.all(40),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Không thể tải ảnh',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              padding: const EdgeInsets.all(40),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Không thể tải ảnh',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              );
            },
          ),
          // Nút đóng ở góc trên bên phải
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          // Indicator số ảnh ở dưới (nếu có nhiều ảnh)
          if (widget.images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
















