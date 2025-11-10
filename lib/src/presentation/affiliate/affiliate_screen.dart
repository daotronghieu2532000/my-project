import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../core/models/affiliate_dashboard.dart';
import '../../core/models/affiliate_product.dart';
import '../../core/services/affiliate_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/scroll_preservation_wrapper.dart';
import '../auth/login_screen.dart';
import '../product/product_detail_screen.dart';
import '../common/widgets/go_top_button.dart';
import 'affiliate_links_screen.dart';
import 'affiliate_orders_screen.dart';
import 'affiliate_withdraw_screen.dart';
import 'commission_history_screen.dart';
import 'withdrawal_history_screen.dart';

class AffiliateScreen extends StatefulWidget {
  const AffiliateScreen({super.key});

  @override
  State<AffiliateScreen> createState() => _AffiliateScreenState();
}

class _AffiliateScreenState extends State<AffiliateScreen> {
  final AffiliateService _affiliateService = AffiliateService();
  final AuthService _authService = AuthService();
  final CachedApiService _cachedApiService = CachedApiService();
  AffiliateDashboard? _dashboard;
  bool _isLoading = true;
  String? _error;
  int _currentTabIndex = 0;
  int? _currentUserId;
  bool? _isAffiliateRegistered;
  bool _agreeToTerms = false;

  // Products state
  final ScrollController _productsScrollController = ScrollController();
  List<AffiliateProduct> _products = [];
  List<AffiliateProduct> _filteredProducts = [];
  bool _isProductsLoading = true;
  bool _isLoadingMore = false; // Separate loading state for load more
  String? _productsError;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final Map<int, bool> _followBusy = {};
  static const int _itemsPerPage = 20; // Load 20 items per page (like Shopee)
  
  // Filters & search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyFollowed = false;
  bool _onlyHasLink = false;
  String _sortBy = 'newest';
  bool _isFilterVisible = false;
  Timer? _searchDebounceTimer;
  Timer? _scrollDebounceTimer; // Debounce for scroll events

  @override
  void initState() {
    super.initState();
    _initUser();
    _productsScrollController.addListener(_onProductsScroll);
  }

  @override
  void dispose() {
    _productsScrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }

  void _onProductsScroll() {
    // Only load more if we're near the bottom and not already loading
    if (!_productsScrollController.hasClients) return;
    
    final maxScroll = _productsScrollController.position.maxScrollExtent;
    final currentScroll = _productsScrollController.position.pixels;
    final threshold = maxScroll * 0.8; // Load more when 80% scrolled (like Shopee)
    
    // Debounce scroll events to avoid too many API calls
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (currentScroll >= threshold && _hasMoreData && !_isProductsLoading && !_isLoadingMore) {
        _loadProducts();
      }
    });
  }

  Future<void> _initUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUserId = user?.userId;
    });
    
    if (_currentUserId != null) {
      await _checkAffiliateStatus();
      _loadProducts(refresh: true); // Load products on first init
    }
    
    _loadDashboard();
  }

  Future<void> _checkAffiliateStatus() async {
    if (_currentUserId == null) return;
    
    try {
      final isRegistered = await _affiliateService.getUserAffiliateStatus(userId: _currentUserId!);
      if (mounted) {
        setState(() {
          _isAffiliateRegistered = isRegistered;
        });
      }
    } catch (e) {
      print('❌ Lỗi check affiliate status: $e');
    }
  }

  void _showAffiliateTermsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            minHeight: 400,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header - Cố định
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF667eea),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Điều khoản chương trình Affiliate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              
              // Content - Scroll được
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAffiliateTermsSection(
                        '1. ĐỊNH NGHĨA',
                        '1.1 "Số Dư Tài Khoản" có nghĩa là Phí Hoa Hồng cộng dồn chưa thanh toán đã đến hạn và có thể thanh toán cho Đối Tác Tiếp Thị Liên Kết.\n\n1.2 "Phương Tiện Tiếp Thị Liên Kết" có nghĩa là tất cả các phương tiện truyền thông, bao gồm nhưng không giới hạn ở các website, ứng dụng di động, cũng như các thư thông (newsletters), Đối Tác tiếp thị liên kết thứ cấp trong hệ thống của Đối Tác Tiếp Thị Liên Kết.\n\n1.3 "Đường Link Tiếp Thị Liên Kết" có nghĩa là các tài liệu truyền thông/quảng cáo được Đối Tác Tiếp Thị Liên Kết cung cấp cho Socdo.vn thông qua Chương Trình.',
                      ),
                      _buildAffiliateTermsSection(
                        '2. CÁC YÊU CẦU KHI THAM GIA CHƯƠNG TRÌNH',
                        '2.1 Thông tin đăng ký: Để phục vụ cho việc đăng ký tham gia Chương Trình, Đối Tác Tiếp Thị Liên Kết sẽ cung cấp bất kỳ thông tin nào được Socdo.vn yêu cầu và sẽ đảm bảo các thông tin đó là đúng, chính xác, và đầy đủ.\n\n2.2 Giấy Phép Hạn Chế: Socdo.vn cấp cho Đối Tác Tiếp Thị Liên Kết quyền thể hiện Đường Link Tiếp Thị Liên Kết trên Phương Tiện Tiếp Thị Liên Kết bằng chi phí của mình.\n\n2.3 Điều kiện tham gia: Phương Tiện Tiếp Thị Liên Kết phải được đăng tải công khai và truy cập được thông qua thông tin được cung cấp ở đơn đăng ký tham gia Chương Trình.',
                      ),
                      _buildAffiliateTermsSection(
                        '3. PHÍ HOA HỒNG VÀ ĐIỀU KHOẢN THANH TOÁN',
                        '3.1 Phí Hoa Hồng: Các loại phí mà Socdo.vn sẽ chi trả cho Đối Tác Tiếp Thị Liên Kết trong một tháng bất kỳ sẽ được tính theo mức được thể hiện ở website của Chương Trình.\n\n3.2 Cách Tính Phí Hoa Hồng: Phí Hoa Hồng cho một tháng bất kỳ sẽ được tính dựa trên Giá Trị Giao Dịch Thành Công Thuần nhân với Mức Phí Hoa Hồng.\n\n3.3 Chi Trả Tối Thiểu: Socdo.vn sẽ chi trả Số Dư Tài Khoản cho Đối Tác Tiếp Thị Liên Kết theo định kỳ hàng tháng, với điều kiện là Số Dư Tài Khoản vào ngày thanh toán đạt mức chi trả tối thiểu 200.000 VNĐ.',
                      ),
                      _buildAffiliateTermsSection(
                        '4. TRÁCH NHIỆM CỦA ĐỐI TÁC TIẾP THỊ LIÊN KẾT',
                        '4.1 Hành Xử Trong Kinh Doanh: Đối Tác Tiếp Thị Liên Kết sẽ không giao kết hợp đồng ràng buộc Socdo.vn hoặc đưa ra các tuyên bố hoặc bảo đảm thay mặt Socdo.vn.\n\n4.2 Tuân Thủ Quy Định Pháp Luật: Đối Tác Tiếp Thị Liên Kết sẽ đảm bảo Phương Tiện Tiếp Thị Liên Kết và việc đặt Đường Link Tiếp Thị Liên Kết tuân thủ tất cả các quy định pháp luật.\n\n4.3 Các Hành Động Bị Cấm: Không được sử dụng email quảng cáo, robot, các công cụ thao tác tự động, hoặc các phương pháp không trung thực.',
                      ),
                      _buildAffiliateTermsSection(
                        '5. QUYỀN VÀ NGHĨA VỤ CỦA SOCDO.VN',
                        '5.1 Nền Tảng: Socdo.vn sẽ vận hành và đảm bảo hoạt động của Nền Tảng.\n\n5.2 Quyền Hủy, Từ Chối, Gỡ Bỏ: Socdo.vn bảo lưu quyền xem xét bất kỳ Phương Tiện Tiếp Thị Liên Kết nào cũng như bất kỳ tài liệu liên quan nào do Đối Tác Tiếp Thị Liên Kết đệ trình.\n\n5.3 Thay Đổi Điều Khoản: Socdo.vn có thể cập nhật, sửa đổi, hoặc thay đổi các Điều Khoản và Điều Kiện này.',
                      ),
                      _buildAffiliateTermsSection(
                        '6. THÔNG TIN MẬT',
                        '6.1 Định nghĩa: "Thông Tin Mật" có nghĩa là tất cả các thông tin về bản chất là thông tin không công khai của một bên trong Thỏa Thuận này.\n\n6.2 Không Sử Dụng và Không Tiết Lộ: Mỗi bên sẽ bảo mật tất cả Thông Tin Mật của bên còn lại và không tiết lộ cho bất kỳ bên thứ ba nào.',
                      ),
                      _buildAffiliateTermsSection(
                        '7. THỜI HẠN VÀ CHẤM DỨT',
                        '7.1 Thời Hạn: Thỏa Thuận này có hiệu lực vào ngày mà Socdo.vn duyệt đăng ký tham gia Chương Trình Tiếp Thị Liên Kết.\n\n7.2 Chấm Dứt Bởi Socdo.vn: Socdo.vn có toàn quyền quyết định đơn phương chấm dứt Thỏa Thuận này bằng bất kỳ lý do gì mà Socdo.vn cho là hợp lý.\n\n7.3 Các Trường Hợp Chấm Dứt: Thỏa Thuận này sẽ chấm dứt ngay lập tức khi một bên thực hiện phá sản hoặc ngừng hoạt động kinh doanh.',
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Footer note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE9ECEF),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF6C757D),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Phiên bản này có hiệu lực kể từ ngày: 18/08/2025',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6C757D),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAffiliateTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerAffiliate() async {
    if (_currentUserId == null) return;
    
    // Check if user agreed to terms
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với điều khoản chương trình Affiliate'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _affiliateService.registerAffiliate(userId: _currentUserId!);
      
      if (mounted) {
        if (result != null && result['success'] == true) {
          // Đăng ký thành công
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Đăng ký affiliate thành công'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Cập nhật trạng thái và reload dashboard
          await _checkAffiliateStatus();
          await _loadDashboard();
        } else {
          // Đăng ký thất bại
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?['message'] ?? 'Đăng ký affiliate thất bại'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi đăng ký affiliate: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Sử dụng cached API service cho dashboard
      final dashboardData = await _cachedApiService.getAffiliateDashboard(
        userId: _currentUserId,
      );
      
      // Xử lý dữ liệu từ cache hoặc API
      AffiliateDashboard? dashboard;
      
      if (dashboardData != null && dashboardData.isNotEmpty) {
        // Sử dụng dữ liệu từ cache
        print('💰 Using cached dashboard data');
        if (dashboardData['data'] != null) {
          dashboard = AffiliateDashboard.fromJson(dashboardData['data']);
        }
      } else {
        // Cache miss, gọi API trực tiếp
        print('🔄 Cache miss, fetching from AffiliateService...');
        dashboard = await _affiliateService.getDashboard(userId: _currentUserId);
        print('📊 Dashboard loaded: $dashboard');
      }
      
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi khi tải dữ liệu: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (_currentUserId == null) {
      print('❌ [AFFILIATE] Cannot load products: no user ID');
      return;
    }
    
    // If products list is empty, treat as refresh
    final isFirstLoad = _products.isEmpty;
    final shouldRefresh = refresh || isFirstLoad;
    
    print('🔄 [AFFILIATE] Loading products - refresh: $refresh, isFirstLoad: $isFirstLoad, shouldRefresh: $shouldRefresh');
    print('🔄 [AFFILIATE] Current state - page: $_currentPage, products: ${_products.length}, loading: $_isProductsLoading, loadingMore: $_isLoadingMore');
    
    // Prevent multiple simultaneous loads
    if (!shouldRefresh && (_isProductsLoading || _isLoadingMore)) {
      print('⏸️ [AFFILIATE] Already loading, skipping...');
      return;
    }
    
    if (shouldRefresh) {
      setState(() {
        _currentPage = 1;
        _products = [];
        _filteredProducts = [];
        _hasMoreData = true;
        _isProductsLoading = true;
        _productsError = null;
      });
    } else {
      // Loading more
      if (!_hasMoreData) return; // No more data to load
      if (_isLoadingMore) return; // Already loading more
      setState(() {
        _isLoadingMore = true;
      });
    }
    try {
      print('🌐 [AFFILIATE] Calling API - page: $_currentPage, limit: $_itemsPerPage, search: "$_searchQuery", sortBy: $_sortBy, onlyFollowing: $_onlyFollowed');
      
      final result = await _affiliateService.getProducts(
        userId: _currentUserId,
        page: _currentPage,
        limit: _itemsPerPage, // Load only 20 items per page (like Shopee)
        search: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        onlyFollowing: _onlyFollowed,
      );
      
      print('📦 [AFFILIATE] API Response received - result: ${result != null ? "not null" : "null"}');
      
      if (mounted) {
        if (result != null && result['products'] != null) {
          final newProducts = result['products'] as List<AffiliateProduct>;
          print('✅ [AFFILIATE] Received ${newProducts.length} products');
          
          setState(() {
            if (shouldRefresh) {
              _products = newProducts;
            } else {
              _products.addAll(newProducts);
            }
            
            // Apply filters after adding products
            _applyFilters();
            
            // Update pagination - check before incrementing page
            final pagination = result['pagination'];
            if (pagination != null) {
              // Check if there are more pages after current page
              _hasMoreData = _currentPage < pagination['total_pages'];
            } else {
              // If no pagination info, assume no more data if we got less than requested
              _hasMoreData = newProducts.length >= _itemsPerPage;
            }
            
            // Increment page for next load
            _currentPage++;
            _isProductsLoading = false;
            _isLoadingMore = false;
          });
          
          print('✅ [AFFILIATE] Products updated - total: ${_products.length}, filtered: ${_filteredProducts.length}, hasMore: $_hasMoreData, nextPage: $_currentPage');
        } else {
          // No products returned
          print('⚠️ [AFFILIATE] No products in response');
          setState(() {
            _hasMoreData = false;
            _isProductsLoading = false;
            _isLoadingMore = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ [AFFILIATE] Error loading products: $e');
      print('❌ [AFFILIATE] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _productsError = 'Lỗi khi tải sản phẩm: $e';
          _isProductsLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<AffiliateProduct> list = List.of(_products);

    if (_onlyFollowed) {
      list = list.where((p) => p.isFollowing).toList();
    }
    if (_onlyHasLink) {
      list = list.where((p) => p.hasLink).toList();
    }

    setState(() {
      _filteredProducts = list;
    });
  }

  String _buildAffiliateUrl(AffiliateProduct product) {
    final userId = _currentUserId ?? 0;
    final base = product.productUrl;
    final separator = base.contains('?') ? '&' : '?';
    return '$base${separator}utm_source_shop=$userId';
  }

  @override
  Widget build(BuildContext context) {
    return ScrollPreservationWrapper(
      tabIndex: 2, // Affiliate tab
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'TIẾP THỊ LIÊN KẾT',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_currentUserId != null && _currentTabIndex == 0)
              IconButton(
                onPressed: () {
                  setState(() {
                    _isFilterVisible = !_isFilterVisible;
                  });
                },
                icon: Icon(
                  _isFilterVisible ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                  color: _hasActiveFilters() ? const Color(0xFFFF6B35) : Colors.black,
                ),
                tooltip: _isFilterVisible ? 'Ẩn bộ lọc' : 'Hiện bộ lọc',
              ),
            if (_currentUserId != null)
              IconButton(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh, color: Colors.black),
              ),
          ],
        ),
        body: _currentUserId == null
            ? _buildLoginPrompt()
            : _isAffiliateRegistered == false
                ? _buildAffiliateRegistrationPrompt()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadDashboard,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          )
                        : _dashboard == null
                        ? const Center(child: Text('Không có dữ liệu'))
                        : Column(
                        children: [
                          // Custom Tab Bar
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildCustomTab('Tiếp thị liên kết', 0),
                                ),
                                Expanded(
                                  child: _buildCustomTab('Các tiện ích khác', 1),
                                ),
                              ],
                            ),
                          ),

                          // Tab Content
                          Expanded(
                            child: IndexedStack(
                              index: _currentTabIndex,
                              children: [
                                _buildAffiliateMarketingTab(),
                                _buildUtilitiesTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE3F2FD),
            Color(0xFFF3E5F5),
            Color(0xFFFFF3E0),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Affiliate Banner - Full width at top
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Background Image
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/affiliate-marketing-15725072874221438636530.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF667eea),
                                    Color(0xFF764ba2),
                                    Color(0xFFf093fb),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.campaign,
                                  color: Colors.white,
                                  size: 80,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Overlay với content
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '💰 TIẾP THỊ LIÊN KẾT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Kiếm tiền từ việc chia sẻ sản phẩm',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.3),
                                              ),
                                            ),
                                            child: const Text(
                                              'hoa hồng lên đến 30%',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.trending_up,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Login Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.login,
                      size: 48,
                      color: Color(0xFF667eea),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Đăng nhập để bắt đầu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Truy cập vào chương trình affiliate và kiếm tiền từ việc chia sẻ sản phẩm',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          ).then((result) {
                            // Reload user info after login
                            if (result == true) {
                              _initUser();
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Đăng nhập ngay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Features
                    Row(
                      children: [
                        Expanded(
                          child: _buildFeatureItem(
                            Icons.share,
                            'Chia sẻ dễ dàng',
                            'Tạo link affiliate',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFeatureItem(
                            Icons.account_balance_wallet,
                            'Rút tiền nhanh',
                            'Hoa hồng cao',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF667eea),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliateMarketingTab() {
    return Stack(
      children: [
        Column(
          children: [
            // Filter Panel - Fixed at top
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isFilterVisible ? null : 0,
              child: _isFilterVisible ? _buildFilterPanel() : const SizedBox.shrink(),
            ),
            
            // Main Content - Scrollable
            Expanded(
              child: SingleChildScrollView(
                controller: _productsScrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildSimpleCard(
                  'Có thể rút',
                  FormatUtils.formatCurrency(_dashboard!.withdrawableBalance.toInt()),
                  Colors.green,
                  Icons.account_balance_wallet,
                            null,
                ),
              ),
                        const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleCard(
                  'Lượt click',
                  _dashboard!.totalClicks.toString(),
                  Colors.blue,
                  Icons.mouse,
                  null,
                ),
              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
              Expanded(
                child: _buildSimpleCard(
                  'Đơn hàng',
                  _dashboard!.totalOrders.toString(),
                  Colors.purple,
                  Icons.shopping_bag,
                            null,
                ),
              ),
                        const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleCard(
                  'Tỷ lệ chuyển đổi',
                  '${_dashboard!.conversionRate.toStringAsFixed(1)}%',
                  _dashboard!.conversionRate >= 3
                      ? Colors.green
                      : _dashboard!.conversionRate >= 1
                          ? Colors.orange
                          : Colors.red,
                  Icons.trending_up,
                  null,
                ),
              ),
            ],
          ),

                    const SizedBox(height: 16),

                    // Affiliate Marketing Banner
                    Container(
                      width: double.infinity,
                      height: 170, // Giảm từ 200 xuống 170 (giảm 30px)
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/affiliate-marketing-15725072874221438636530.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple[600]!,
                                          Colors.pink[500]!,
                                          Colors.orange[400]!,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.white,
                                        size: 48,
                                      ),
      ),
    );
                                },
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.6),
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Spacer(),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  '💰 TIẾP THỊ LIÊN KẾT',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Text(
                                                  'Kiếm tiền từ việc chia sẻ',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Hoa đồng: ${FormatUtils.formatCurrency(_dashboard!.totalCommission.toInt())}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.trending_up,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Products Section
                    const Text(
                      'Sản phẩm Affiliate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Products List
                    _isProductsLoading && _products.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _productsError != null && _products.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_productsError!),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => _loadProducts(refresh: true),
                                      child: const Text('Thử lại'),
                                    ),
                                  ],
                                ),
                              )
                            : _filteredProducts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Không có sản phẩm affiliate',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _buildProductsGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Go Top Button
        GoTopButton(
          scrollController: _productsScrollController,
          showAfterScrollDistance: 1000.0,
        ),
      ],
    );
  }

  Widget _buildUtilitiesTab() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMenuCard(
            Icons.link,
            'Đang theo dõi',
            'Quản lý các sản phẩm đang theo dõi',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AffiliateLinksScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            Icons.receipt_long,
            'Đơn hàng',
            'Theo dõi đơn hàng & hoa hồng',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AffiliateOrdersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            Icons.account_balance_wallet,
            'Rút tiền',
            'Tạo yêu cầu rút hoa hồng',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AffiliateWithdrawScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            Icons.history,
            'Lịch sử hoa hồng',
            'Xem chi tiết hoa hồng đã nhận',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CommissionHistoryScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            Icons.account_balance,
            'Lịch sử rút tiền',
            'Theo dõi yêu cầu rút tiền',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WithdrawalHistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCard(String title, String value, Color color, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.purple[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTab(String text, int index) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[600] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty || 
           _onlyFollowed || 
           _onlyHasLink ||
           _sortBy != 'newest';
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _loadProducts(refresh: true);
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF6B35),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                  if (value.trim().isNotEmpty) {
                    _loadProducts(refresh: true);
                  }
                });
              },
              onSubmitted: (_) {
                FocusScope.of(context).unfocus();
                _loadProducts(refresh: true);
              },
            ),
          ),
          
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    icon: Icons.favorite_rounded,
                    label: 'Đang theo dõi',
                    isSelected: _onlyFollowed,
                    onTap: () {
                      setState(() {
                        _onlyFollowed = !_onlyFollowed;
                      });
                      _loadProducts(refresh: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    icon: Icons.link_rounded,
                    label: 'Có link rút gọn',
                    isSelected: _onlyHasLink,
                    onTap: () {
                      setState(() {
                        _onlyHasLink = !_onlyHasLink;
                      });
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildSortChip(),
                  if (_hasActiveFilters()) ...[
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      icon: Icons.clear_all_rounded,
                      label: 'Xóa bộ lọc',
                      isSelected: false,
                      backgroundColor: Colors.red[50],
                      textColor: Colors.red[600],
                      iconColor: Colors.red[600],
                      onTap: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          _onlyFollowed = false;
                          _onlyHasLink = false;
                          _sortBy = 'newest';
                        });
                        _loadProducts(refresh: true);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? textColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFFF6B35) 
              : backgroundColor ?? const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFFF6B35) 
                : const Color(0xFFE9ECEF),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected 
                  ? Colors.white 
                  : iconColor ?? Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected 
                    ? Colors.white 
                    : textColor ?? Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip() {
    return GestureDetector(
      onTap: _showSortBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE9ECEF),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              _getSortLabel(_sortBy),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(String sortBy) {
    final options = {
      'newest': 'Mới nhất',
      'price_asc': 'Giá tăng dần',
      'price_desc': 'Giá giảm dần',
      'commission_asc': 'Hoa hồng tăng dần',
      'commission_desc': 'Hoa hồng giảm dần',
    };
    return options[sortBy] ?? 'Mới nhất';
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.sort_rounded,
                    color: const Color(0xFFFF6B35),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sắp xếp theo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            ..._getSortOptions().map((option) {
              final isSelected = option['value'] == _sortBy;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFFF6B35).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    option['icon'] as IconData,
                    color: isSelected 
                        ? const Color(0xFFFF6B35)
                        : Colors.grey[600],
                    size: 20,
                  ),
                ),
                title: Text(
                  option['label'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected 
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF333333),
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFFFF6B35),
                        size: 24,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _sortBy = option['value'] as String;
                  });
                  _loadProducts(refresh: true);
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSortOptions() {
    return [
      {
        'value': 'newest',
        'label': 'Mới nhất',
        'icon': Icons.new_releases_rounded,
      },
      {
        'value': 'price_asc',
        'label': 'Giá tăng dần',
        'icon': Icons.trending_up_rounded,
      },
      {
        'value': 'price_desc',
        'label': 'Giá giảm dần',
        'icon': Icons.trending_down_rounded,
      },
      {
        'value': 'commission_asc',
        'label': 'Hoa hồng tăng dần',
        'icon': Icons.monetization_on_rounded,
      },
      {
        'value': 'commission_desc',
        'label': 'Hoa hồng giảm dần',
        'icon': Icons.money_off_rounded,
      },
    ];
  }

  Widget _buildProductsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Tính toán width: (screenWidth - padding SingleChildScrollView - padding Wrap - spacing giữa 2 cột) / 2
    // SingleChildScrollView padding: 16px mỗi bên = 32px
    // Wrap padding: 4px mỗi bên = 8px
    // Spacing giữa 2 cột: 8px
    // Tổng: 32 + 8 + 8 = 48
    final cardWidth = (screenWidth - 48) / 2;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            spacing: 8, // Khoảng cách ngang giữa các card
            runSpacing: 8, // Khoảng cách dọc giữa các hàng
            children: _filteredProducts.map((product) {
              return SizedBox(
                width: cardWidth, // Width cố định cho 2 cột, height tự co giãn
                child: _buildProductCard(product),
              );
            }).toList(),
          ),
        ),
        // Show loading indicator at bottom when loading more
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        // Show "No more products" message if no more data
        if (!_hasMoreData && _filteredProducts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Đã hiển thị tất cả sản phẩm',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(AffiliateProduct product) {
    final commissionRange = _calculateCommissionRange(product);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: product.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Tự co giãn theo nội dung
        children: [
            // Box trên: Ảnh sản phẩm + Badges
            LayoutBuilder(
              builder: (context, constraints) {
                final imageWidth = constraints.maxWidth;
                return Container(
                  width: double.infinity,
                  height: imageWidth * 1.0, // Ảnh vuông
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Stack(
              children: [
                ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                  child: Image.network(
                    product.image,
                          width: double.infinity,
                          height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                              width: double.infinity,
                              height: double.infinity,
                        color: const Color(0xFFF5F5F5),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 32,
                            color: Color(0xFF999999),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                      // Follow checkbox badge ở góc trên phải
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: _followBusy[product.id] == true
                                ? const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Checkbox(
                                    activeColor: const Color(0xFFFF6B35),
                                    value: product.isFollowing,
                                    onChanged: (v) async {
                                      setState(() { _followBusy[product.id] = true; });
                                      final result = await _affiliateService.toggleFollow(
                                        userId: _currentUserId ?? 0,
                                        spId: product.id,
                                        shopId: product.shopId,
                                        follow: v ?? false,
                                      );
                                      if (!mounted) return;
                                      setState(() { _followBusy[product.id] = false; });
                                      
                                      if (result != null && result['success'] == true) {
                                        final index = _products.indexWhere((p) => p.id == product.id);
                                        if (index != -1) {
                                          final updatedProduct = AffiliateProduct(
                                            id: product.id,
                                            name: product.name,
                                            slug: product.slug,
                                            image: product.image,
                                            price: product.price,
                                            oldPrice: product.oldPrice,
                                            discountPercent: product.discountPercent,
                                            shopId: product.shopId,
                                            categoryIds: product.categoryIds,
                                            brandId: product.brandId,
                                            brandName: product.brandName,
                                            productUrl: product.productUrl,
                                            commissionInfo: product.commissionInfo,
                                            shortLink: product.shortLink,
                                            campaignName: product.campaignName,
                                            priceFormatted: product.priceFormatted,
                                            oldPriceFormatted: product.oldPriceFormatted,
                                            isFeatured: product.isFeatured,
                                            isFlashSale: product.isFlashSale,
                                            createdAt: product.createdAt,
                                            updatedAt: product.updatedAt,
                                            isFollowing: v ?? false,
                                          );
                                          setState(() {
                                            _products[index] = updatedProduct;
                                            final fIndex = _filteredProducts.indexWhere((p) => p.id == updatedProduct.id);
                                            if (fIndex != -1) {
                                              _filteredProducts[fIndex] = updatedProduct;
                                            } else {
                                              _applyFilters();
                                            }
                                          });
                                        }
                                      }
                                    },
                                  ),
                          ),
                        ),
                      ),
                      // Discount badge ở góc trên trái
                      if (product.oldPrice > product.price)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              'GIẢM ${((product.oldPrice - product.price) / product.oldPrice * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      // Nút Chia sẻ ở góc phải bên dưới
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: product.hasLink
                                ? () => _shareToOther(product)
                                : () => _createAffiliateLink(product),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: (product.hasLink ? const Color(0xFF1976D2) : const Color(0xFFFF6B35)).withOpacity(0.95),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.share,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    product.hasLink ? 'Chia sẻ' : 'Rút gọn',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Box dưới: Thông tin sản phẩm
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tên sản phẩm
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF333333),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Giá
                      Row(
                        children: [
                          Text(
                            FormatUtils.formatCurrency(product.price.toInt()),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                          if (product.oldPrice > product.price) ...[
                        const SizedBox(width: 6),
                            Text(
                              FormatUtils.formatCurrency(product.oldPrice.toInt()),
                              style: const TextStyle(
                            fontSize: 11,
                                color: Color(0xFF999999),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                        const SizedBox(height: 4),
                  
                  // Hoa hồng
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE1F5FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                product.mainCommission,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                              commissionRange.replaceAll('↓', '→'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w500,
                              ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                  const SizedBox(height: 4),
                  
                  // Link rows
                _buildLinkRow(_buildAffiliateUrl(product)),
                if (product.hasLink) ...[
                    const SizedBox(height: 4),
                  _buildLinkRow(product.shortLink!),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _calculateCommissionRange(AffiliateProduct product) {
    if (product.commissionInfo.isEmpty) {
      return 'Hoa hồng: ${product.mainCommission}';
    }
    
    final commissions = <double>[];
    
    for (final commission in product.commissionInfo) {
      if (commission.type == 'phantram') {
        final minPrice = product.price;
        final maxPrice = product.oldPrice > product.price ? product.oldPrice : product.price * 1.2;
        
        final minCommission = (minPrice * commission.value / 100).round();
        final maxCommission = (maxPrice * commission.value / 100).round();
        
        commissions.addAll([minCommission.toDouble(), maxCommission.toDouble()]);
      } else {
        commissions.add(commission.value);
      }
    }
    
    if (commissions.isEmpty) {
      return 'Hoa hồng: ${product.mainCommission}';
    }
    
    commissions.sort();
    final minCommission = commissions.first;
    final maxCommission = commissions.last;
    
    if (minCommission == maxCommission) {
      return 'Hoa hồng: ${FormatUtils.formatCurrency(minCommission.round())}';
    } else {
      return '${FormatUtils.formatCurrency(minCommission.round())} ↓ ${FormatUtils.formatCurrency(maxCommission.round())}';
    }
  }

  Widget _buildLinkRow(String url) {
    return GestureDetector(
      onTap: () {}, // Prevent tap event from bubbling to parent InkWell
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, size: 11, color: Color(0xFF6C757D)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                url,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF495057),
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã copy link!'),
                    backgroundColor: const Color(0xFF28A745),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque, // Prevent event bubbling
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.copy, size: 11, color: Color(0xFF6C757D)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAffiliateLink(AffiliateProduct product) async {
    try {
      final longAffiliate = _buildAffiliateUrl(product);
      final result = await _affiliateService.createLink(
        userId: _currentUserId ?? 0,
        spId: product.id,
        fullLink: longAffiliate,
      );

      if (mounted) {
        if (result != null && result['short_link'] != null) {
          final short = result['short_link'] as String;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo link: $short'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: short));
                },
              ),
            ),
          );
          final index = _products.indexWhere((p) => p.id == product.id);
          if (index != -1) {
            final updated = _cloneWithShortLink(_products[index], short);
            setState(() {
              _products[index] = updated;
              final fIndex = _filteredProducts.indexWhere((p) => p.id == updated.id);
              if (fIndex != -1) {
                _filteredProducts[fIndex] = updated;
              } else {
                _applyFilters();
              }
            });
            // Gọi trực tiếp _shareToOther sau khi tạo link thành công
            _shareToOther(updated);
          } else {
            // Nếu không tìm thấy product trong list, vẫn gọi với product gốc
            _shareToOther(product);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tạo link thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  AffiliateProduct _cloneWithShortLink(AffiliateProduct src, String shortLink) {
    return AffiliateProduct(
      id: src.id,
      name: src.name,
      slug: src.slug,
      image: src.image,
      price: src.price,
      oldPrice: src.oldPrice,
      discountPercent: src.discountPercent,
      shopId: src.shopId,
      categoryIds: src.categoryIds,
      brandId: src.brandId,
      brandName: src.brandName,
      productUrl: src.productUrl,
      commissionInfo: src.commissionInfo,
      shortLink: shortLink,
      campaignName: src.campaignName,
      priceFormatted: src.priceFormatted,
      oldPriceFormatted: src.oldPriceFormatted,
      isFeatured: src.isFeatured,
      isFlashSale: src.isFlashSale,
      createdAt: src.createdAt,
      updatedAt: src.updatedAt,
      isFollowing: src.isFollowing,
    );
  }

  void _shareToOther(AffiliateProduct product) async {
    final shareText = _buildShareText(product);
    final shareUrl = _buildAffiliateUrl(product);
    
    try {
      if (product.image.isNotEmpty) {
        final imageFile = await _downloadImageToTemp(product.image);
        if (imageFile != null) {
          try {
            await Share.shareXFiles(
              [XFile(imageFile.path)],
              text: '$shareText\n\n$shareUrl',
              subject: product.title,
            );
            return;
          } catch (e) {
            // Fallback to text-only
          }
        }
      }
      Share.share(
        '$shareText\n\n$shareUrl',
        subject: product.title,
      );
    } catch (e) {
      Share.share(
        '$shareText\n\n$shareUrl',
        subject: product.title,
      );
    }
  }

  Future<File?> _downloadImageToTemp(String imageUrl) async {
    try {
      if (!imageUrl.startsWith('http')) {
        return null;
      }
      
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        
        final fileSize = await file.length();
        if (fileSize < 100) {
          return null;
        }
        
        return file;
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  String _buildShareText(AffiliateProduct product) {
    final discountPercent = product.oldPrice > product.price 
        ? ' (Giảm ${((product.oldPrice - product.price) / product.oldPrice * 100).round()}%)'
        : '';
    
    final oldPriceText = product.oldPrice > product.price 
        ? '\n💸 Giá gốc: ${FormatUtils.formatCurrency(product.oldPrice.toInt())}'
        : '';
    
    return '🔥 ${product.title}$discountPercent\n💰 Giá: ${FormatUtils.formatCurrency(product.price.toInt())}$oldPriceText\n💎 Hoa hồng: ${product.mainCommission}\n🏪 Thương hiệu: ${product.brandName}\n\n👉 Mua ngay để nhận ưu đãi tốt nhất!\n\n📱 Tải app Socdo để mua hàng với giá tốt nhất!';
  }

  Widget _buildAffiliateRegistrationPrompt() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
            Color(0xFFf093fb),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Affiliate Banner - Full width at top
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Background Image
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/affiliate-marketing-15725072874221438636530.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF667eea),
                                    Color(0xFF764ba2),
                                    Color(0xFFf093fb),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.campaign,
                                  color: Colors.white,
                                  size: 80,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.2),
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '💰 Affiliate Marketing',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Kiếm tiền từ việc chia sẻ sản phẩm',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                          ),
                                          child: const Text(
                                            'hoa hồng lên đến 30%',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ],
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

              // Registration Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [               
                    const SizedBox(height: 12),
                    _buildBenefitItem(
                      Icons.monetization_on,
                      'Hoa hồng cao',
                      'Nhận hoa hồng lên đến 30% từ mỗi đơn hàng',
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitItem(
                      Icons.share,
                      'Dễ dàng chia sẻ',
                      'Tạo link affiliate chỉ với một cú click',
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitItem(
                      Icons.trending_up,
                      'Theo dõi hiệu quả',
                      'Xem thống kê chi tiết về doanh thu',
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitItem(
                      Icons.account_balance_wallet,
                      'Rút tiền nhanh',
                      'Rút tiền về tài khoản ngân hàng dễ dàng',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Terms Checkbox
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            onChanged: (value) {
                              setState(() {
                                _agreeToTerms = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF667eea),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black, fontSize: 14),
                                children: [
                                  const TextSpan(text: 'Tôi đồng ý với '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () => _showAffiliateTermsDialog(context),
                                      child: const Text(
                                        'điều khoản chương trình Affiliate',
                                        style: TextStyle(
                                          color: Color(0xFF667eea),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Color(0xFF667eea),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' của Socdo.vn'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _registerAffiliate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Đăng ký Affiliate ngay',
                                    style: TextStyle(
                                      fontSize: 16,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF667eea),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


}
