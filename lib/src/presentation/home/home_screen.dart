
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
  import 'widgets/home_app_bar.dart';
import 'widgets/quick_actions.dart';
import 'widgets/flash_sale_section.dart';
import 'widgets/product_grid.dart';
import 'widgets/partner_banner_slider.dart';
import 'widgets/featured_brands_slider.dart';
import 'widgets/popup_banner_widget.dart';
import 'widgets/service_guarantees.dart';
// import 'widgets/dedication_section.dart'; // Tận tâm - Tận tình - Tận tụy
import '../common/widgets/go_top_button.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/popup_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ScrollController _scrollController = ScrollController();
  final CachedApiService _cachedApiService = CachedApiService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  bool _isPreloading = true;
  int _refreshKey = 0; // Key để trigger reload các widget con
  PopupBanner? _popupBanner;
  bool _showPopup = false;

  @override
  void initState() {
    super.initState();
    _preloadData();
    _loadPopupBanner();
  }
  
  Future<void> _loadPopupBanner() async {
    try {
      print('🔍 Loading popup banner...');
      
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
      
      print('🔍 Displayed banner IDs: $displayedBannerIds');
      
      // Gọi API với danh sách banner đã hiển thị để loại trừ tất cả
      PopupBanner? popupBanner = await _apiService.getPopupBanner(
        excludeIds: displayedBannerIds.isNotEmpty ? displayedBannerIds : null,
      );
      
      // Nếu không có banner mới (đã hiển thị hết), reset danh sách và lấy banner đầu tiên
      if (popupBanner == null || displayedBannerIds.contains(popupBanner.id)) {
        print('ℹ️ All banners have been displayed, resetting...');
        displayedBannerIds.clear();
        popupBanner = await _apiService.getPopupBanner(excludeIds: null);
      }
      
      if (mounted && popupBanner != null) {
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
        
        print('✅ Popup banner loaded: ${popupBanner.title} (ID: ${popupBanner.id})');
        print('🔍 Updated displayed banner IDs: $displayedBannerIds');
      } else {
        print('ℹ️ No popup banner to display');
      }
    } catch (e) {
      print('❌ Error loading popup banner: $e');
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
      print('🚀 Preloading home data...');
      
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
      
      print('✅ Home data preloaded successfully');
      
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    } catch (e) {
      print('❌ Error preloading home data: $e');
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      print('🔄 Refreshing home data...');
      
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
      
      print('✅ Home data refreshed successfully');
      
      // Reload popup banner khi refresh
      _loadPopupBanner();
      
      // Trigger reload các widget con bằng cách thay đổi refreshKey
      if (mounted) {
        setState(() {
          _refreshKey++;
        });
      }
    } catch (e) {
      print('❌ Error refreshing home data: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                  child: ListView(
                    key: const PageStorageKey('home_list'), // Flutter tự động lưu/restore scroll position
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
                        
                        // Flash Sale section
                        FlashSaleSection(key: ValueKey('flash_sale_$_refreshKey')),
                        const SizedBox(height: 4),
                        
                        // Featured Brands slider
                        FeaturedBrandsSlider(key: ValueKey('featured_brands_$_refreshKey')),
                        
                        // Suggested products grid
                        Container(
                          color: Colors.white,
                          child: ProductGrid(key: ValueKey('product_grid_$_refreshKey'), title: 'GỢI Ý TỚI BẠN '),
                        ),
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


