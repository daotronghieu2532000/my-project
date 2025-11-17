import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/models/splash_screen.dart';
import '../root_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  late Future<SplashScreenModel?> _splashScreenFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Load API ngay từ đầu, không chờ
    _splashScreenFuture = _apiService.getSplashScreen();
    _navigateToHome();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload ảnh khi context sẵn sàng để hiển thị nhanh hơn
    _preloadImage();
  }

  Future<void> _preloadImage() async {
    try {
      final splashScreen = await _splashScreenFuture;
      if (mounted && splashScreen != null && splashScreen.imageUrl.isNotEmpty) {
        // Preload ảnh để cache và hiển thị nhanh hơn
        final imageProvider = NetworkImage(splashScreen.imageUrl);
        precacheImage(imageProvider, context);
      }
    } catch (e) {
      // Ignore preload errors
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  void _navigateToHome() {
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const RootShell(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  Widget _buildBackgroundImage() {
    return FutureBuilder<SplashScreenModel?>(
      future: _splashScreenFuture,
      builder: (context, snapshot) {
        // Đang load API → hiển thị màn hình trống (không có gì)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.white, // Màn hình trắng trong khi load
          );
        }
        
        // Đã load xong API
        final splashScreen = snapshot.data;
        
        // Nếu có splash screen từ API và có image_url → chỉ hiển thị ảnh từ DB
        if (splashScreen != null && splashScreen.imageUrl.isNotEmpty) {
          return Image.network(
            splashScreen.imageUrl,
            fit: BoxFit.cover, // Fill toàn màn hình, không có khoảng trắng
            alignment: Alignment.center, // Căn giữa - ảnh 300x658px phù hợp với tỉ lệ màn hình
            filterQuality: FilterQuality.high,
            // Không hiển thị gì trong khi load ảnh (màn hình trắng)
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              // Màn hình trắng trong khi load ảnh từ DB
              return Container(color: Colors.white);
            },
            errorBuilder: (context, error, stackTrace) {
            
              // Nếu lỗi load ảnh từ DB → fallback về ảnh mặc định
              return _buildDefaultImage();
            },
          );
        }
        
        // API không có ảnh → hiển thị ảnh mặc định từ app
        return _buildDefaultImage();
      },
    );
  }

  Widget _buildDefaultImage() {
    return Image.asset(
      'lib/src/core/assets/images/logo_socdo.png',
      fit: BoxFit.cover, // Fill toàn màn hình, không có khoảng trắng
      alignment: Alignment.center, // Căn giữa - ảnh 300x658px phù hợp với tỉ lệ màn hình
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        // Nếu không load được ảnh asset → màn hình trắng (bỏ gradient)
        return Container(color: Colors.white);
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image - Hiển thị ảnh từ API hoặc ảnh mặc định
          Positioned.fill(
            child: _buildBackgroundImage(),
          ),
          // Main Content - Loading indicator ở dưới cùng
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
