
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
  import 'widgets/home_app_bar.dart';
import 'widgets/quick_actions.dart';
import 'widgets/flash_sale_section.dart';
import 'widgets/product_grid.dart';
import 'widgets/partner_banner_slider.dart';
import 'widgets/featured_brands_slider.dart';
import 'widgets/popup_banner_widget.dart';
import 'widgets/service_guarantees.dart';
import 'widgets/banner_products_widget.dart';
// import 'widgets/dedication_section.dart'; // Tận tâm - Tận tình - Tận tụy
import '../common/widgets/go_top_button.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_lifecycle_manager.dart';
import '../../core/models/popup_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;
  
  final ScrollController _scrollController = ScrollController();
  final CachedApiService _cachedApiService = CachedApiService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager();
  bool _isPreloading = true;
  int _refreshKey = 0; // Key để trigger reload các widget con
  PopupBanner? _popupBanner;
  bool _showPopup = false;
  bool _hasRestoredScroll = false;
  Timer? _scrollSaveTimer; // Timer để debounce việc lưu scroll position

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Lưu scroll position khi scroll
    _scrollController.addListener(_onScroll);
    
    _preloadData();
    _loadPopupBanner();
    
    // Restore scroll position sau khi data đã load (đợi ListView build xong)
    _restoreScrollPositionAfterLoad();
  }
  
  /// Restore scroll position sau khi data đã load và ListView đã build
  Future<void> _restoreScrollPositionAfterLoad() async {
    // Đợi preload xong (đợi _isPreloading = false)
    while (_isPreloading && mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    if (!mounted) return;
    
    // Đợi thêm để ListView build xong (sau khi setState _isPreloading = false)
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Đợi ListView render xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Đợi thêm vài frame để đảm bảo ListView đã render hoàn toàn
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _restoreScrollPosition();
        }
      });
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollSaveTimer?.cancel();
    _saveScrollPosition();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Lưu scroll position khi app bị pause
      _saveScrollPosition();
    } else if (state == AppLifecycleState.resumed) {
      // Reset flag để có thể restore lại khi resume
      _hasRestoredScroll = false;
      // Restore scroll position khi app resume (nếu trong 3 phút)
      _restoreScrollPosition();
    }
  }
  
  /// Lưu scroll position vào AppLifecycleManager
  void _saveScrollPosition() {
    if (_scrollController.hasClients) {
      final position = _scrollController.offset;
      if (position > 0) {
        _lifecycleManager.saveScrollPosition(0, position); // Tab 0 = Home
      }
    }
  }
  
  /// Restore scroll position từ AppLifecycleManager
  Future<void> _restoreScrollPosition() async {
    if (_hasRestoredScroll) return;
    
    try {
      final savedPosition = await _lifecycleManager.getSavedScrollPosition(0); // Tab 0 = Home
      if (savedPosition != null && savedPosition > 0) {
        // Retry với delay tăng dần và max retries lớn hơn
        int retryCount = 0;
        const maxRetries = 20;
        
        void tryRestore() {
          if (!mounted) return;
          
          if (_scrollController.hasClients) {
            try {
              final position = _scrollController.position;
              final maxScroll = position.maxScrollExtent;
              
              // Chỉ restore nếu maxScrollExtent > 0 (ListView đã render content)
              if (maxScroll > 0) {
                final targetPosition = savedPosition > maxScroll ? maxScroll : savedPosition;
                _scrollController.jumpTo(targetPosition);
                _hasRestoredScroll = true;
              } else if (retryCount < maxRetries) {
                // maxScrollExtent = 0 nghĩa là ListView chưa render xong
                retryCount++;
                final delay = retryCount * 50; // Delay tăng dần: 50ms, 100ms, 150ms...
                Future.delayed(Duration(milliseconds: delay), tryRestore);
              }
            } catch (e) {
              // Ignore error
            }
          } else if (retryCount < maxRetries) {
            retryCount++;
            final delay = retryCount * 50;
            Future.delayed(Duration(milliseconds: delay), tryRestore);
          }
        }
        
        // Thử restore ngay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          tryRestore();
        });
      }
    } catch (e) {
      // Ignore error
    }
  }
  
  /// Lưu scroll position khi user scroll (với debounce)
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final position = _scrollController.offset;
    if (position <= 0) return;
    
    // Debounce: chỉ lưu sau 500ms khi user ngừng scroll
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _lifecycleManager.saveScrollPosition(0, position);
    });
  }
  
  Future<void> _loadPopupBanner() async {
    try {
      // Lấy danh sách banner ID đã hiển thị từ SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final displayedBannerIdsString = prefs.getString('displayed_popup_banner_ids');
      List<int> displayedBannerIds = [];
      
      if (displayedBannerIdsString != null && displayedBannerIdsString.isNotEmpty) {
        displayedBannerIds = displayedBannerIdsString
            .split(',')
            .map((id) => int.tryParse(id.trim()))
            .where((id) => id != null)
            .cast<int>()
            .toList();
      }
      
      // Gọi API với danh sách banner đã hiển thị để loại trừ tất cả
      PopupBanner? popupBanner = await _apiService.getPopupBanner(
        excludeIds: displayedBannerIds.isNotEmpty ? displayedBannerIds : null,
      );
      
      // Nếu không có banner mới (đã hiển thị hết), reset danh sách và lấy banner đầu tiên
      if (popupBanner == null || displayedBannerIds.contains(popupBanner.id)) {
        displayedBannerIds.clear();
        popupBanner = await _apiService.getPopupBanner(excludeIds: null);
      }
      
      if (mounted && popupBanner != null) {
        // Preload ảnh trước khi hiển thị popup
        final imageLoaded = await _preloadPopupImage(popupBanner.imageUrl);
        
        if (mounted && imageLoaded) {
          // Chỉ hiển thị popup khi ảnh đã load xong
          setState(() {
            _popupBanner = popupBanner;
            _showPopup = true;
          });
          
          // Thêm banner ID mới vào danh sách đã hiển thị
          if (!displayedBannerIds.contains(popupBanner.id)) {
            displayedBannerIds.add(popupBanner.id);
          }
          
          // Lưu danh sách banner ID đã hiển thị vào SharedPreferences
          await prefs.setString(
            'displayed_popup_banner_ids',
            displayedBannerIds.join(','),
          );
        }
      }
    } catch (e) {
      // Ignore error
    }
  }
  
  /// Preload ảnh popup banner vào cache trước khi hiển thị
  /// Trả về true nếu ảnh load thành công, false nếu thất bại hoặc timeout
  Future<bool> _preloadPopupImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) {
        return false;
      }
      
      // Sử dụng CachedNetworkImageProvider để preload ảnh
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      
      // Preload ảnh với timeout 10 giây
      await precacheImage(
        imageProvider,
        context,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Image preload timeout');
        },
      );
      
      return true;
    } on TimeoutException {
      return false;
    } catch (e) {
      return false;
    }
  }
  
  void _closePopup() {
    setState(() {
      _showPopup = false;
    });
  }

  Future<void> _preloadData() async {
    try {
      // Preload tất cả dữ liệu cần thiết cho trang chủ
      // Lấy userId từ AuthService (user đã đăng nhập) để preload personalized suggestions
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      await Future.wait([
        _cachedApiService.getHomeBanners(),
        _cachedApiService.getHomeFlashSale(),
        _cachedApiService.getHomePartnerBanners(),
        _cachedApiService.getHomeFeaturedBrands(),
        _cachedApiService.getHomeSuggestions(limit: 100, userId: userId),
      ]);
      
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      // Clear cache và load lại dữ liệu
      _cachedApiService.clearCachePattern('home_');
      
      // Lấy userId từ AuthService (user đã đăng nhập) để refresh personalized suggestions
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      await Future.wait([
        _cachedApiService.getHomeBanners(forceRefresh: true),
        _cachedApiService.getHomeFlashSale(forceRefresh: true),
        _cachedApiService.getHomePartnerBanners(forceRefresh: true),
        _cachedApiService.getHomeFeaturedBrands(forceRefresh: true),
        _cachedApiService.getHomeSuggestions(limit: 100, forceRefresh: true, userId: userId),
      ]);
      
      // Reload popup banner khi refresh
      _loadPopupBanner();
      
      // Trigger reload các widget con bằng cách thay đổi refreshKey
      if (mounted) {
        setState(() {
          _refreshKey++;
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Hiển thị loading screen trong khi preload
    if (_isPreloading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              const HomeAppBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      // Khi ListView đã scroll được (tức là đã ready), thử restore nếu chưa restore
                      if (notification is ScrollUpdateNotification && !_hasRestoredScroll) {
                        // Đợi một chút rồi restore (đảm bảo ListView đã render xong)
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted && !_hasRestoredScroll) {
                            _restoreScrollPosition();
                          }
                        });
                      }
                      return false;
                    },
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        // Partner Banner - Full width, 160px height (thay thế banner mobile)
                        PartnerBannerSlider(key: ValueKey('partner_banner_$_refreshKey')),
                        
                        // Service Guarantees - Trả hàng 15 ngày, Chính hãng 100%, Giao miễn phí
                        const ServiceGuarantees(),
                        const SizedBox(height: 8),
                        
                        // Quick actions
                        Container(
                          color: Colors.white,
                          child: const QuickActions(),
                        ),
                        // const SizedBox(height: 8),
                        
                        // Dedication Section - Tận tâm - Tận tình - Tận tụy
                        // "Tận tâm" (icon: fire.png)
                        // "Tận tình" (icon: handshake.png)
                        // "Tận tụy" (icon: heart.png)
                        // const DedicationSection(),
                        
                        // Banner Products - Đầu trang (sau QuickActions, trước FlashSale)
                        BannerProductsWidget(position: 'dau_trang'),
                        
                        // Flash Sale section
                        FlashSaleSection(key: ValueKey('flash_sale_$_refreshKey')),
                        const SizedBox(height: 4),
                        
                        // Banner Products - Giữa trang (sau FlashSale, trước FeaturedBrands)
                        BannerProductsWidget(position: 'giua_trang'),
                        
                        // Featured Brands slider - Tách riêng với border
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!, width: 1),
                              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                            ),
                          ),
                          child: FeaturedBrandsSlider(key: ValueKey('featured_brands_$_refreshKey')),
                        ),
                        
                        // Banner Products - Cuối trang (sau FeaturedBrands, trước ProductGrid) - Tách riêng với border
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!, width: 1),
                              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                            ),
                          ),
                          child: BannerProductsWidget(position: 'cuoi_trang'),
                        ),
                        
                        // Suggested products grid - Tách riêng với border
                        Container(
                          decoration: BoxDecoration(
                          color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!, width: 1),
                              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                            ),
                          ),
                          child: ProductGrid(key: ValueKey('product_grid_$_refreshKey'), title: 'GỢI Ý TỚI BẠN '),
                        ),
                      ],
                    ),
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
            // Popup Banner
            if (_showPopup && _popupBanner != null)
              PopupBannerWidget(
                popupBanner: _popupBanner!,
                onClose: _closePopup,
            ),
          ],
        ),
    );
  }
}