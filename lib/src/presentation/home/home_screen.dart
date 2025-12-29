
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/quick_actions.dart';
import 'widgets/flash_sale_section.dart';
import 'widgets/product_grid_sliver.dart';
import 'widgets/partner_banner_slider.dart';
import 'widgets/featured_brands_slider.dart';
import 'widgets/popup_banner_widget.dart';
import 'widgets/service_guarantees.dart';
import 'widgets/banner_products_widget.dart';
// import 'widgets/dedication_section.dart'; // Tận tâm - Tận tình - Tận tụy
import '../common/widgets/go_top_button.dart';
import '../common/widgets/welcome_bonus_dialog.dart';
import '../../common/widgets/update_version_dialog.dart';
import '../../core/services/cached_api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/first_time_bonus_service.dart';
import '../../core/models/popup_banner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

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
  final FirstTimeBonusService _bonusService = FirstTimeBonusService();
  bool _isPreloading = true;
  int _refreshKey = 0; // Key để trigger reload các widget con
  PopupBanner? _popupBanner;
  bool _showPopup = false;
  Timer? _scrollSaveTimer; // Timer để debounce việc lưu scroll position (không dùng nữa)
  bool _isShowingWelcomeDialog = false; // Flag để tránh hiển thị dialog nhiều lần đồng thời
  bool _hasCheckedVersion = false; // Flag để tránh check version nhiều lần
  bool _isShowingUpdateDialog = false; // Flag để tránh hiển thị update dialog nhiều lần đồng thời

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Lưu scroll position khi scroll
    _scrollController.addListener(_onScroll);
    
    // ✅ Lắng nghe sự thay đổi auth state để kiểm tra dialog bonus khi user đăng nhập
    _authService.addAuthStateListener(_onAuthStateChanged);
    
    _preloadData();
    // Load popup banner trong background, không block UI
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
    _loadPopupBanner();
      }
    });
    
    // ✅ Kiểm tra và hiển thị dialog cảm ơn nếu có bonus mới (sau khi vào home)
    // Kiểm tra ngay sau khi widget được build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Delay một chút để đảm bảo auth_service đã hoàn thành việc set flag
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            // print('🔍 [HomeScreen] initState: Calling _showWelcomeBonusDialogIfNeeded() after postFrameCallback');
            _showWelcomeBonusDialogIfNeeded();
          }
        });
      }
    });
    
    // ✅ Kiểm tra lại sau 2 giây để đảm bảo không bỏ sót (nếu có delay từ API)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        // print('🔍 [HomeScreen] initState: Calling _showWelcomeBonusDialogIfNeeded() after 2000ms (retry)');
        _showWelcomeBonusDialogIfNeeded();
      }
    });
    
    // ✅ Kiểm tra version update sau khi vào home
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _checkVersionUpdate();
      }
    });
    
    // KHÔNG restore scroll position - luôn bắt đầu từ đầu trang chủ
    // _restoreScrollPositionAfterLoad();
  }
  
  /// Callback khi auth state thay đổi (đăng nhập/đăng xuất)
  void _onAuthStateChanged() {
    // print('🔍 [HomeScreen] _onAuthStateChanged() called');
    // ✅ Khi user đăng nhập thành công, kiểm tra lại flag bonus dialog
    // Delay một chút để đảm bảo flag đã được set từ auth_service
    // Tăng delay lên 1000ms để đảm bảo bonus check API đã hoàn thành
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        // print('🔍 [HomeScreen] Calling _showWelcomeBonusDialogIfNeeded() after auth state changed');
        _showWelcomeBonusDialogIfNeeded();
        // ✅ Kiểm tra version update khi user đăng nhập
        _checkVersionUpdate();
      } else {
        // print('⚠️ [HomeScreen] Widget not mounted, skipping dialog check');
      }
    });
  }
  
  /// Kiểm tra version update
  Future<void> _checkVersionUpdate() async {
    try {
      // ✅ Tránh check nhiều lần
      if (_hasCheckedVersion || _isShowingUpdateDialog) {
        return;
      }
      
      // ✅ Lấy thông tin app version và platform
      String? appVersion;
      String platform = 'android';
      
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
        
        if (Platform.isIOS) {
          platform = 'ios';
        } else if (Platform.isAndroid) {
          platform = 'android';
        }
      } catch (e) {
        return;
      }
      
      if (appVersion == null || appVersion.isEmpty) {
        return;
      }
      
      // ✅ Lấy user_id nếu đã đăng nhập
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      // ✅ Gọi API check version
      final versionData = await _apiService.checkVersion(
        platform: platform,
        appVersion: appVersion,
        userId: userId,
      );
      
      if (!mounted) {
        return;
      }
      
      // ✅ Đánh dấu đã check
      _hasCheckedVersion = true;
      
      // ✅ Kiểm tra xem có cần update không
      if (versionData != null && 
          versionData['need_update'] == true && 
          versionData['update_url'] != null &&
          versionData['update_url'].toString().isNotEmpty) {
        
        // ✅ Delay một chút để tránh conflict với các dialog khác
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted || _isShowingUpdateDialog) {
          return;
        }
        
        // ✅ Hiển thị dialog update
        _isShowingUpdateDialog = true;
        
        showDialog(
          context: context,
          barrierDismissible: false, // Không cho đóng bằng cách tap outside
          builder: (context) => UpdateVersionDialog(
            updateUrl: versionData['update_url'].toString(),
          ),
        ).then((_) {
          // ✅ Reset flag khi dialog đóng (nếu có thể đóng)
          _isShowingUpdateDialog = false;
        });
      }
    } catch (e) {
      // Ignore error, không block UI
    }
  }
  
  // KHÔNG restore scroll position - luôn bắt đầu từ đầu
  // /// Restore scroll position sau khi data đã load và ListView đã build
  // Future<void> _restoreScrollPositionAfterLoad() async {
  //   // Đợi preload xong (đợi _isPreloading = false)
  //   while (_isPreloading && mounted) {
  //     await Future.delayed(const Duration(milliseconds: 50));
  //   }
  //   
  //   if (!mounted) return;
  //   
  //   // Đợi thêm để ListView build xong (sau khi setState _isPreloading = false)
  //   await Future.delayed(const Duration(milliseconds: 300));
  //   
  //   // Đợi ListView render xong
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     // Đợi thêm vài frame để đảm bảo ListView đã render hoàn toàn
  //     Future.delayed(const Duration(milliseconds: 500), () {
  //       if (mounted) {
  //         _restoreScrollPosition();
  //       }
  //     });
  //   });
  // }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authService.removeAuthStateListener(_onAuthStateChanged);
    _scrollController.removeListener(_onScroll);
    _scrollSaveTimer?.cancel();
    // KHÔNG lưu scroll position khi dispose
    // _saveScrollPosition();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // KHÔNG lưu scroll position - luôn bắt đầu từ đầu khi mở lại
      // _saveScrollPosition();
    } else if (state == AppLifecycleState.resumed) {
      // KHÔNG restore scroll position - luôn bắt đầu từ đầu
      // Reset scroll về đầu khi app resume
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }
  
  // KHÔNG lưu scroll position - luôn bắt đầu từ đầu
  // /// Lưu scroll position vào AppLifecycleManager
  // void _saveScrollPosition() {
  //   if (_scrollController.hasClients) {
  //     final position = _scrollController.offset;
  //     if (position > 0) {
  //       _lifecycleManager.saveScrollPosition(0, position); // Tab 0 = Home
  //     }
  //   }
  // }
  
  // KHÔNG restore scroll position - luôn bắt đầu từ đầu
  // /// Restore scroll position từ AppLifecycleManager
  // Future<void> _restoreScrollPosition() async {
  //   if (_hasRestoredScroll) return;
  //   
  //   try {
  //     final savedPosition = await _lifecycleManager.getSavedScrollPosition(0); // Tab 0 = Home
  //     if (savedPosition != null && savedPosition > 0) {
  //       // Retry với delay tăng dần và max retries lớn hơn
  //       int retryCount = 0;
  //       const maxRetries = 20;
  //       
  //       void tryRestore() {
  //         if (!mounted) return;
  //         
  //         if (_scrollController.hasClients) {
  //           try {
  //             final position = _scrollController.position;
  //             final maxScroll = position.maxScrollExtent;
  //             
  //             // Chỉ restore nếu maxScrollExtent > 0 (ListView đã render content)
  //             if (maxScroll > 0) {
  //               final targetPosition = savedPosition > maxScroll ? maxScroll : savedPosition;
  //               _scrollController.jumpTo(targetPosition);
  //               _hasRestoredScroll = true;
  //             } else if (retryCount < maxRetries) {
  //               // maxScrollExtent = 0 nghĩa là ListView chưa render xong
  //               retryCount++;
  //               final delay = retryCount * 50; // Delay tăng dần: 50ms, 100ms, 150ms...
  //               Future.delayed(Duration(milliseconds: delay), tryRestore);
  //             }
  //           } catch (e) {
  //             // Ignore error
  //           }
  //         } else if (retryCount < maxRetries) {
  //           retryCount++;
  //           final delay = retryCount * 50;
  //           Future.delayed(Duration(milliseconds: delay), tryRestore);
  //         }
  //       }
  //       
  //       // Thử restore ngay
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         tryRestore();
  //       });
  //     }
  //   } catch (e) {
  //     // Ignore error
  //   }
  // }
  
  /// Lưu scroll position khi user scroll (với debounce)
  void _onScroll() {
    // KHÔNG lưu scroll position - luôn bắt đầu từ đầu khi mở lại
    // if (!_scrollController.hasClients) return;
    // 
    // final position = _scrollController.offset;
    // if (position <= 0) return;
    // 
    // // Debounce: chỉ lưu sau 500ms khi user ngừng scroll
    // _scrollSaveTimer?.cancel();
    // _scrollSaveTimer = Timer(const Duration(milliseconds: 500), () {
    //   _lifecycleManager.saveScrollPosition(0, position);
    // });
  }
  
  Future<void> _loadPopupBanner() async {
    try {
      // Load SharedPreferences một lần và cache kết quả
      final prefs = await SharedPreferences.getInstance();
      
      // Đọc tất cả dữ liệu cần thiết một lần để giảm database operations
      final displayedBannerIdsString = prefs.getString('displayed_popup_banner_ids') ?? '';
      final lastResetTimeString = prefs.getString('popup_banner_last_reset_time');
      final lastPopupDisplayTimeString = prefs.getString('popup_banner_last_display_time');
      
      List<int> displayedBannerIds = [];
      if (displayedBannerIdsString.isNotEmpty) {
        displayedBannerIds = displayedBannerIdsString
            .split(',')
            .map((id) => int.tryParse(id.trim()))
            .where((id) => id != null)
            .cast<int>()
            .toList();
      }
      
      DateTime? lastResetTime;
      if (lastResetTimeString != null && lastResetTimeString.isNotEmpty) {
        lastResetTime = DateTime.tryParse(lastResetTimeString);
      }
      
      DateTime? lastPopupDisplayTime;
      if (lastPopupDisplayTimeString != null && lastPopupDisplayTimeString.isNotEmpty) {
        lastPopupDisplayTime = DateTime.tryParse(lastPopupDisplayTimeString);
      }
      
      // Kiểm tra xem đã qua 24h chưa (để reset danh sách banner đã hiển thị)
      final now = DateTime.now();
      final shouldReset = lastResetTime == null || 
          now.difference(lastResetTime).inHours >= 24;
      
      // Kiểm tra xem đã đủ 2 giờ kể từ lần hiển thị popup cuối cùng chưa
      final canShowPopup = lastPopupDisplayTime == null || 
          now.difference(lastPopupDisplayTime).inHours >= 2;
      
      // Nếu chưa đủ 2 giờ, không hiển thị popup
      if (!canShowPopup) {
        return;
      }
      
      // Gọi API với danh sách banner đã hiển thị để loại trừ tất cả
      PopupBanner? popupBanner = await _apiService.getPopupBanner(
        excludeIds: displayedBannerIds.isNotEmpty ? displayedBannerIds : null,
      );
      
      // Nếu không có banner mới (đã hiển thị hết), chỉ reset nếu đã qua 24h
      if (popupBanner == null || displayedBannerIds.contains(popupBanner.id)) {
        if (shouldReset) {
          // Reset danh sách và lấy banner đầu tiên
          displayedBannerIds.clear();
          popupBanner = await _apiService.getPopupBanner(excludeIds: null);
          
          // Lưu thời gian reset (chỉ lưu khi cần)
          if (popupBanner != null) {
          await prefs.setString(
            'popup_banner_last_reset_time',
            now.toIso8601String(),
          );
          }
        } else {
          // Chưa qua 24h, không hiển thị banner
          popupBanner = null;
        }
      }
      
      if (mounted && popupBanner != null) {
        final bannerId = popupBanner.id;
        // Preload ảnh trong background, không block UI
        _preloadPopupImage(popupBanner.imageUrl).then((imageLoaded) {
        if (mounted && imageLoaded) {
          // Chỉ hiển thị popup khi ảnh đã load xong
          setState(() {
            _popupBanner = popupBanner;
            _showPopup = true;
          });
          
          // Lưu thời gian hiển thị popup lần cuối
          prefs.setString(
            'popup_banner_last_display_time',
            now.toIso8601String(),
          );
          
          // Thêm banner ID mới vào danh sách đã hiển thị
            if (!displayedBannerIds.contains(bannerId)) {
              displayedBannerIds.add(bannerId);
          }
          
            // Lưu danh sách banner ID đã hiển thị vào SharedPreferences (async, không block)
            prefs.setString(
            'displayed_popup_banner_ids',
            displayedBannerIds.join(','),
          );
        }
        });
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
      
      // Preload ảnh với timeout ngắn hơn (5 giây) để không block quá lâu
      await precacheImage(
        imageProvider,
        context,
      ).timeout(
        const Duration(seconds: 5),
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
  
  /// Hiển thị dialog cảm ơn nếu user vừa nhận bonus mới
  Future<void> _showWelcomeBonusDialogIfNeeded() async {
    try {
      // print('🔍 [HomeScreen] _showWelcomeBonusDialogIfNeeded() called');
      
      // ✅ Tránh hiển thị dialog nhiều lần đồng thời
      if (_isShowingWelcomeDialog) {
        // print('⚠️ [HomeScreen] Dialog is already being shown, skipping');
        return;
      }
      
      // ✅ Chỉ hiển thị dialog nếu user đã đăng nhập
      final isLoggedIn = await _authService.isLoggedIn();
      // print('🔍 [HomeScreen] isLoggedIn: $isLoggedIn');
      if (!isLoggedIn) {
        // print('⚠️ [HomeScreen] User not logged in, skipping dialog');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // ✅ Retry kiểm tra flag với tối đa 5 lần (mỗi lần cách nhau 500ms)
      // Để đảm bảo flag đã được set từ auth_service (có thể mất thời gian do API call)
      bool shouldShow = false;
      for (int i = 0; i < 5; i++) {
        shouldShow = prefs.getBool('show_bonus_dialog') ?? false;
        // print('🔍 [HomeScreen] Check attempt ${i + 1}/5: show_bonus_dialog = $shouldShow');
        if (shouldShow) {
          break;
        }
        // Nếu chưa có flag, đợi một chút rồi thử lại
        if (i < 4) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (!shouldShow) {
        // ✅ Nếu flag = false, kiểm tra xem dialog đã được hiển thị chưa
        final alreadyShown = prefs.getBool('welcome_bonus_dialog_shown') ?? false;
        if (alreadyShown) {
          // print('⚠️ [HomeScreen] Dialog already shown before, skipping');
          return;
        }
        // print('⚠️ [HomeScreen] Flag is false after all retries, not showing dialog');
        // Debug: Kiểm tra xem có bonus info không
        final bonusInfoString = prefs.getString('first_time_bonus_info');
        if (bonusInfoString != null) {
          // print('🔍 [HomeScreen] Found first_time_bonus_info in SharedPreferences');
          try {
            final bonusInfo = jsonDecode(bonusInfoString);
            // print('🔍 [HomeScreen] Bonus info: is_new_bonus = ${bonusInfo['is_new_bonus']}');
          } catch (e) {
            // print('⚠️ [HomeScreen] Error parsing bonus info: $e');
          }
        } else {
          // print('⚠️ [HomeScreen] No first_time_bonus_info found in SharedPreferences');
        }
        return;
      }
      
      // ✅ Flag = true, tiến hành hiển thị dialog
      // print('✅ [HomeScreen] Flag is true, proceeding to show dialog');
      
      // Clear flag ngay để tránh hiển thị lại nhiều lần
      await prefs.setBool('show_bonus_dialog', false);
      // print('✅ [HomeScreen] Flag cleared, getting config...');
      
      // Lấy config từ API
      final config = await _bonusService.getBonusConfig();
      // print('🔍 [HomeScreen] Config received: ${config != null ? "not null" : "null"}');
      if (config != null) {
        // print('🔍 [HomeScreen] Config status: ${config.status}');
      }
      
      if (config == null || !config.status) {
        // print('⚠️ [HomeScreen] Config is null or status is false, not showing dialog');
        return; // Tính năng đã tắt, không hiển thị dialog
      }
      
      // Delay một chút để đảm bảo UI đã render xong
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) {
        // print('⚠️ [HomeScreen] Widget not mounted, cannot show dialog');
        // ✅ Nếu widget unmount, restore flag để thử lại lần sau
        await prefs.setBool('show_bonus_dialog', true);
        return;
      }
      
      // print('✅ [HomeScreen] Showing WelcomeBonusDialog');
      // ✅ Đánh dấu đang hiển thị dialog để tránh gọi lại
      _isShowingWelcomeDialog = true;
      
      // ✅ CHỈ set welcome_bonus_dialog_shown = true SAU KHI dialog đã được đóng
      // (để đảm bảo user đã thấy dialog)
      showDialog(
        context: context,
        barrierDismissible: false, // Không cho đóng bằng cách tap outside
        builder: (context) => WelcomeBonusDialog(
          onClose: () {
            // print('✅ [HomeScreen] WelcomeBonusDialog closed');
            Navigator.of(context).pop();
            // ✅ Đánh dấu đã hiển thị SAU KHI dialog đã được đóng (đảm bảo user đã thấy dialog)
            SharedPreferences.getInstance().then((prefs) {
              prefs.setBool('welcome_bonus_dialog_shown', true);
            });
            // ✅ Reset flag để có thể hiển thị lại nếu cần (mặc dù không nên xảy ra)
            _isShowingWelcomeDialog = false;
          },
          config: config,
        ),
      );
    } catch (e) {
      // print('❌ [HomeScreen] Error in _showWelcomeBonusDialogIfNeeded: $e');
    }
  }
  
  void _closePopup() async {
    setState(() {
      _showPopup = false;
    });
    
    // Lưu thời gian đóng popup (để đảm bảo tính chính xác của 2 giờ)
    // Nếu chưa lưu thời gian hiển thị ở _loadPopupBanner (do ảnh chưa load xong),
    // thì lưu ở đây để đảm bảo
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDisplayTimeString = prefs.getString('popup_banner_last_display_time');
      
      // Chỉ lưu nếu chưa có (trường hợp ảnh load nhanh và đã lưu ở _loadPopupBanner)
      // hoặc nếu đã có thì không cần lưu lại
      if (lastDisplayTimeString == null || lastDisplayTimeString.isEmpty) {
        await prefs.setString(
          'popup_banner_last_display_time',
          DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _preloadData() async {
    // Hiển thị UI ngay, không chờ preload
    if (mounted) {
      setState(() {
        _isPreloading = false;
      });
    }
    
    // Load các section quan trọng nhất trước (section trên cùng)
    try {
      // Cache userId một lần để tránh gọi getCurrentUser nhiều lần
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      // Load section trên cùng trước (Partner Banner, Flash Sale)
      // Không chờ, để chạy song song
      Future(() async {
        try {
          await Future.wait([
            _cachedApiService.getHomePartnerBanners(),
            _cachedApiService.getHomeFlashSale(),
          ]);
        } catch (e) {
          // Silent fail
        }
      });
      
      // Load các section còn lại trong background (không block UI)
      Future(() async {
        try {
          await Future.wait([
            _cachedApiService.getHomeBanners(),
            _cachedApiService.getHomeFeaturedBrands(),
            _cachedApiService.getHomeSuggestions(limit: 50, userId: userId), // Load 50 để cache
            // Banner products - load lazy khi scroll đến
          ]);
        } catch (e) {
          // Silent fail
        }
      });
    } catch (e) {
      // Ignore errors, UI đã hiển thị rồi
    }
  }

  Future<void> _refreshData() async {
    try {
      // Clear tất cả cache liên quan đến home trước khi refresh
      _cachedApiService.clearCachePattern('home_');
      // Clear cache flash sale cụ thể (vì flash sale dùng cache key với timeline)
      _cachedApiService.clearAllFlashSaleCache();
      // Clear cache banner products
      _cachedApiService.clearCachePattern('banner_products');
      
      // Trigger reload các widget con sớm để UI update nhanh
      if (mounted) {
        setState(() {
          _refreshKey++;
        });
      }
      
      // Lấy userId từ AuthService (user đã đăng nhập) để refresh personalized suggestions
      final user = await _authService.getCurrentUser();
      final userId = user?.userId;
      
      // Gọi tất cả API song song để tối ưu thời gian
      await Future.wait([
        // API chính
        _cachedApiService.getHomeBanners(forceRefresh: true),
        _cachedApiService.getHomeFlashSale(forceRefresh: true),
        _cachedApiService.getHomePartnerBanners(forceRefresh: true),
        _cachedApiService.getHomeFeaturedBrands(forceRefresh: true),
        _cachedApiService.getHomeSuggestions(limit: 10, forceRefresh: true, userId: userId),
        // Banner products - gọi song song với các API khác
        _cachedApiService.getBannerProductsCached(viTriHienThi: 'dau_trang', forceRefresh: true),
        _cachedApiService.getBannerProductsCached(viTriHienThi: 'giua_trang', forceRefresh: true),
        _cachedApiService.getBannerProductsCached(viTriHienThi: 'cuoi_trang', forceRefresh: true),
        // Popup banner - không chờ, load background
        _loadPopupBanner(),
      ]);
      
    } catch (e) {
      // Error refreshing data - đã trigger reload widget rồi nên UI không bị đơ
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
                        // KHÔNG restore scroll position - luôn bắt đầu từ đầu
                        return false;
                      },
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Partner Banner - Full width, 160px height (thay thế banner mobile)
                        SliverToBoxAdapter(
                          child: PartnerBannerSlider(key: ValueKey('partner_banner_$_refreshKey')),
                        ),
                        
                        // Service Guarantees - Trả hàng 15 ngày, Chính hãng 100%, Giao miễn phí
                        const SliverToBoxAdapter(
                          child: ServiceGuarantees(),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 8),
                        ),
                        
                        // Quick actions
                        SliverToBoxAdapter(
                          child: Container(
                            color: Colors.white,
                            child: const QuickActions(),
                          ),
                        ),
                        // const SizedBox(height: 8),
                        
                        // Banner Products - Đầu trang (sau QuickActions, trước FlashSale)
                        SliverToBoxAdapter(
                          child: BannerProductsWidget(
                            key: ValueKey('banner_products_dau_trang_$_refreshKey'),
                            position: 'dau_trang',
                          ),
                        ),
                        
                        // Flash Sale section
                        SliverToBoxAdapter(
                          child: FlashSaleSection(key: ValueKey('flash_sale_$_refreshKey')),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 4),
                        ),
                        
                        // Banner Products - Giữa trang (sau FlashSale, trước FeaturedBrands)
                        SliverToBoxAdapter(
                          child: BannerProductsWidget(
                            key: ValueKey('banner_products_giua_trang_$_refreshKey'),
                            position: 'giua_trang',
                          ),
                        ),
                        
                        // Featured Brands slider - Tách riêng với border
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey[200]!, width: 1),
                                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                              ),
                            ),
                            child: FeaturedBrandsSlider(key: ValueKey('featured_brands_$_refreshKey')),
                          ),
                        ),
                        
                        // Banner Products - Cuối trang (sau FeaturedBrands, trước ProductGrid) - Tách riêng với border
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey[200]!, width: 1),
                                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                              ),
                            ),
                            child: BannerProductsWidget(
                              key: ValueKey('banner_products_cuoi_trang_$_refreshKey'),
                              position: 'cuoi_trang',
                            ),
                          ),
                        ),
                        
                        // Header cho ProductGrid
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey[200]!, width: 1),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: const Text(
                              'GỢI Ý CHO BẠN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        
                        // Suggested products grid - SỬ DỤNG SLIVER!
                        const ProductGridSliver(),
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
