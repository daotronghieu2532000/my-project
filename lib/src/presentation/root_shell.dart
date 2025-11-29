import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'category/category_screen.dart';
import 'cart/cart_screen.dart';
import '../core/services/cart_service.dart' as cart_service;
import '../core/services/app_lifecycle_manager.dart';
import '../core/services/cart_animation_service.dart';
import '../core/utils/format_utils.dart';
// import 'notifications/notifications_screen.dart';
import 'affiliate/affiliate_screen.dart';

class RootShell extends StatefulWidget {
  final int initialIndex;
  const RootShell({super.key, this.initialIndex = 0});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late int _currentIndex = widget.initialIndex;
  final cart_service.CartService _cart = cart_service.CartService();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager();
  final CartAnimationService _cartAnimationService = CartAnimationService();
  bool _isInitialized = false;
  
  // GlobalKey cho icon giỏ hàng để animation bay vào
  final GlobalKey _cartIconKey = GlobalKey();
  
  // Animation controller cho bounce effect của icon giỏ hàng
  late AnimationController _cartBounceController;
  late Animation<double> _cartBounceAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cart.addListener(_onCartChanged);
    _initializeAppState();
    
    // Setup animation cho icon giỏ hàng
    _cartBounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _cartBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _cartBounceController,
      curve: Curves.easeInOut,
    ));
    
    // Set GlobalKey vào CartAnimationService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cartAnimationService.cartIconKey = _cartIconKey;
    });
    
    // Listen to cart changes để trigger bounce animation
    _cart.addListener(_onCartItemAdded);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cart.removeListener(_onCartChanged);
    _cart.removeListener(_onCartItemAdded);
    _cartBounceController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // Lưu state khi app bị pause
      _lifecycleManager.saveCurrentTab(_currentIndex);
    } else if (state == AppLifecycleState.resumed) {
      // Không restore state ngay - để Flutter tự xử lý navigation stack
      // Chỉ restore nếu app bị kill và restart
      _restoreStateOnResume();
    }
  }

  /// Restore state khi app resume
  Future<void> _restoreStateOnResume() async {
    try {
      // Chỉ restore nếu state hợp lệ và app có thể đã bị kill
      if (_lifecycleManager.isStateValid()) {
        final savedTab = await _lifecycleManager.getSavedTab();
        
        if (savedTab != null && savedTab != _currentIndex) {
          // Chỉ restore nếu tab khác - tránh rebuild không cần thiết
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentIndex = savedTab;
              });
            }
          });
        }
      }
    } catch (e) {
      // Error restoring state
    }
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }
  
  void _onCartItemAdded() {
    // Trigger bounce animation khi có sản phẩm mới thêm vào giỏ
    if (mounted && _cartBounceController.status != AnimationStatus.forward) {
      _cartBounceController.forward(from: 0);
    }
  }

  /// Khởi tạo và khôi phục state của app
  Future<void> _initializeAppState() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      // Khởi tạo AppLifecycleManager
      _lifecycleManager.initialize();
      
      // Đợi một chút để đảm bảo pause time đã được load từ storage
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Thử khôi phục tab đã lưu
      final savedTab = await _lifecycleManager.getSavedTab();
      
      if (savedTab != null && savedTab != widget.initialIndex) {
        setState(() {
          _currentIndex = savedTab;
        });
      }
      
      _isInitialized = true;
    } catch (e) {
      // Error initializing app state
    }
  }

  // Tabs: Trang chủ, Danh mục, Affiliate
  // Sử dụng keys để giữ state khi switch tabs
  final List<Widget> _tabs = [
    HomeScreen(key: const PageStorageKey('home')),
    CategoryScreen(key: const PageStorageKey('category')),
    AffiliateScreen(key: const PageStorageKey('affiliate')),
  ];

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    final bool selected = _currentIndex == index;
    final Color iconColor = selected ? Colors.red : Colors.black;
    final Color textColor = selected ? Colors.red : Colors.black;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Breakpoints: width >= 380: 11px, width >= 320: 10px, width < 320: ẩn text
    final bool showText = screenWidth >= 320;
    final double fontSize = screenWidth >= 380 ? 11 : (screenWidth >= 320 ? 10 : 11);
    
    return Expanded(
      child: InkWell(
        onTap: () => _onTabChanged(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor.withOpacity(0.7), size: 24),
              if (showText) ...[
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: textColor, 
                    fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Xử lý khi tab thay đổi
  void _onTabChanged(int newIndex) {
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
      
      // Lưu tab hiện tại
      _lifecycleManager.saveCurrentTab(newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(color: Colors.white),
          padding: const EdgeInsets.only(left: 12, right: 0),
          child: Row(
            children: [
              // Các tab điều hướng
              Expanded(
                child: Row(
                  children: [
                    _buildNavItem(index: 0, icon: Icons.home_outlined, label: 'Trang chủ', context: context),
                    _buildNavItem(index: 1, icon: Icons.grid_view_rounded, label: 'Danh mục', context: context),
                    _buildNavItem(index: 2, icon: Icons.people_outline, label: 'Affiliate', context: context),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Container cho phần giỏ hàng và nút đặt mua với nền riêng
              Expanded(
                child: ListenableBuilder(
                  listenable: _cart,
                  builder: (context, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9ECEF), // Màu đậm hơn cho phần giỏ hàng
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          // Icon + nhãn Giỏ hàng hiển thị badge động
                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CartScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _cartBounceAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _cartBounceAnimation.value,
                                      child: Stack(
                                        key: _cartIconKey, // GlobalKey cho animation
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Icon(
                                            Icons.shopping_cart_outlined,
                                            color: Colors.red,
                                            size: 24,
                                          ),
                                          if (_cart.itemCount > 0)
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
                                                  _cart.itemCount.toString(),
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
                                    );
                                  },
                                ),
                                Builder(
                                  builder: (context) {
                                    final screenWidth = MediaQuery.of(context).size.width;
                                    final bool showText = screenWidth >= 320;
                                    final double fontSize = screenWidth >= 380 ? 11 : (screenWidth >= 320 ? 10 : 11);
                                    
                                    return showText ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                const SizedBox(height: 2),
                                        Text(
                                  'Giỏ hàng',
                                  style: TextStyle(
                                    color: Colors.black,
                                            fontSize: fontSize,
                                    height: 1.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                        ),
                                      ],
                                    ) : const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Nút đặt mua chiếm phần còn lại, sát lề phải
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const CartScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0, // Bỏ shadow để hòa hợp với container
                              ),
                              child: Text(
                                'Đặt mua (${_cart.selectedItemCount})\n${FormatUtils.formatCurrency(_cart.selectedTotalPrice)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// Bottom bar có thể tái sử dụng ở các màn con
class RootShellBottomBar extends StatefulWidget {
  const RootShellBottomBar({super.key});

  @override
  State<RootShellBottomBar> createState() => _RootShellBottomBarState();
}

class _RootShellBottomBarState extends State<RootShellBottomBar> with TickerProviderStateMixin {
  final cart_service.CartService _cart = cart_service.CartService();
  final CartAnimationService _cartAnimationService = CartAnimationService();
  
  // GlobalKey cho icon giỏ hàng để animation bay vào
  final GlobalKey _cartIconKey = GlobalKey();
  
  // Animation controller cho bounce effect của icon giỏ hàng
  late AnimationController _cartBounceController;
  late Animation<double> _cartBounceAnimation;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    
    // Setup animation cho icon giỏ hàng
    _cartBounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _cartBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _cartBounceController,
      curve: Curves.easeInOut,
    ));
    
    // Set GlobalKey vào CartAnimationService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cartAnimationService.cartIconKey = _cartIconKey;
    });
    
    // Listen to cart changes để trigger bounce animation
    _cart.addListener(_onCartItemAdded);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _cart.removeListener(_onCartItemAdded);
    _cartBounceController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }
  
  void _onCartItemAdded() {
    // Trigger bounce animation khi có sản phẩm mới thêm vào giỏ
    if (mounted && _cartBounceController.status != AnimationStatus.forward) {
      _cartBounceController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white),
        padding: const EdgeInsets.only(left: 12, right: 0),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _navItem(context, icon: Icons.home_outlined, label: 'Trang chủ', onTap: () => _openHome(context)),
                  _navItem(context, icon: Icons.grid_view_rounded, label: 'Danh mục', onTap: () => _openCategory(context)),
                  _navItem(context, icon: Icons.people_outline, label: 'Affiliate', onTap: () => _openAffiliate(context)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE9ECEF), borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
                      borderRadius: BorderRadius.circular(6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _cartBounceAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _cartBounceAnimation.value,
                                child: Stack(
                                  key: _cartIconKey, // GlobalKey cho animation
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.shopping_cart_outlined, color: Colors.red, size: 24),
                                    if (_cart.itemCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -6,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: Center(
                                            child: Text(
                                              _cart.itemCount.toString(),
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
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              final screenWidth = MediaQuery.of(context).size.width;
                              final bool showText = screenWidth >= 320;
                              final double fontSize = screenWidth >= 380 ? 11 : (screenWidth >= 320 ? 10 : 11);
                              
                              return showText ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                          const SizedBox(height: 2),
                                  Text('Giỏ hàng', style: TextStyle(color: Colors.black, fontSize: fontSize, height: 1.0, fontWeight: FontWeight.w500)),
                                ],
                              ) : const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                        child: Text('Đặt mua (${_cart.selectedItemCount})\n${FormatUtils.formatCurrency(_cart.selectedTotalPrice)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Breakpoints: width >= 380: 11px, width >= 320: 10px, width < 320: ẩn text
    final bool showText = screenWidth >= 320;
    final double fontSize = screenWidth >= 380 ? 11 : (screenWidth >= 320 ? 10 : 11);
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.black.withOpacity(0.7), size: 24),
              if (showText) ...[
              const SizedBox(height: 3),
                Text(label, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: FontWeight.w500, height: 1.0)),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  void _openHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell(initialIndex: 0)),
      (route) => false,
    );
  }
  
  void _openCategory(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell(initialIndex: 1)),
      (route) => false,
    );
  }
  
  void _openAffiliate(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell(initialIndex: 2)),
      (route) => false,
    );
  }
}

// removed unused placeholder screen


