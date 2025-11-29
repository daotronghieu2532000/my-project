import 'package:flutter/material.dart';

/// Service để xử lý animation bay vào giỏ hàng như Shopee
/// Có thể tái sử dụng ở bất kỳ đâu trong app
class CartAnimationService {
  static final CartAnimationService _instance = CartAnimationService._internal();
  factory CartAnimationService() => _instance;
  CartAnimationService._internal();

  /// GlobalKey cho icon giỏ hàng ở bottom navigation
  /// Được set từ RootShell
  GlobalKey? cartIconKey;

  /// Tạo animation bay vào giỏ hàng
  /// 
  /// [context]: BuildContext hiện tại
  /// [imageUrl]: URL ảnh sản phẩm
  /// [startKey]: GlobalKey của widget nguồn (nơi ảnh bắt đầu bay)
  /// [onComplete]: Callback khi animation hoàn thành
  Future<void> animateToCart({
    required BuildContext context,
    required String imageUrl,
    GlobalKey? startKey,
    Offset? startPosition,
    VoidCallback? onComplete,
  }) async {
    // Nếu không có cartIconKey, không làm gì cả
    if (cartIconKey == null) {
      onComplete?.call();
      return;
    }

    // Lấy vị trí đích (icon giỏ hàng)
    final cartRenderBox = cartIconKey!.currentContext?.findRenderObject() as RenderBox?;
    if (cartRenderBox == null) {
      onComplete?.call();
      return;
    }

    final cartPosition = cartRenderBox.localToGlobal(Offset.zero);
    final cartSize = cartRenderBox.size;

    // Lấy vị trí bắt đầu
    Offset start;
    Size startSize = const Size(60, 60); // Default size

    if (startKey != null) {
      final startRenderBox = startKey.currentContext?.findRenderObject() as RenderBox?;
      if (startRenderBox != null) {
        start = startRenderBox.localToGlobal(Offset.zero);
        startSize = startRenderBox.size;
      } else if (startPosition != null) {
        start = startPosition;
      } else {
        // Không có vị trí bắt đầu, không làm gì
        onComplete?.call();
        return;
      }
    } else if (startPosition != null) {
      start = startPosition;
    } else {
      // Không có vị trí bắt đầu, không làm gì
      onComplete?.call();
      return;
    }

    // Tính điểm đích (trung tâm icon giỏ hàng)
    final end = Offset(
      cartPosition.dx + cartSize.width / 2 - 15, // -15 để center ảnh 30x30
      cartPosition.dy + cartSize.height / 2 - 15,
    );

    // Tạo overlay entry
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _FlyingProductImage(
        imageUrl: imageUrl,
        start: start,
        end: end,
        startSize: startSize,
        onComplete: () {
          overlayEntry.remove();
          _animateCartIcon();
          onComplete?.call();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  /// Animate icon giỏ hàng (phóng to, thu nhỏ) khi ảnh bay vào
  void _animateCartIcon() {
    if (cartIconKey?.currentContext == null) return;
    
    // Animation bounce được xử lý tự động trong RootShell
    // thông qua cart service listener
  }
}

/// Widget hiển thị ảnh bay từ vị trí bắt đầu đến giỏ hàng
class _FlyingProductImage extends StatefulWidget {
  final String imageUrl;
  final Offset start;
  final Offset end;
  final Size startSize;
  final VoidCallback onComplete;

  const _FlyingProductImage({
    required this.imageUrl,
    required this.start,
    required this.end,
    required this.startSize,
    required this.onComplete,
  });

  @override
  State<_FlyingProductImage> createState() => _FlyingProductImageState();
}

class _FlyingProductImageState extends State<_FlyingProductImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animation curve giống Shopee (bắt đầu nhanh, kết thúc chậm)
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Scale animation: bắt đầu lớn, thu nhỏ dần khi bay
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Tính vị trí hiện tại với đường cong Bezier (giống Shopee)
        final t = _animation.value;
        
        // Tạo đường cong Bezier để ảnh bay theo đường cong
        // Control point ở giữa và cao hơn một chút
        final controlPoint = Offset(
          (widget.start.dx + widget.end.dx) / 2,
          (widget.start.dy + widget.end.dy) / 2 - 100, // Bay lên cao hơn một chút
        );

        // Quadratic Bezier curve
        final currentX = (1 - t) * (1 - t) * widget.start.dx +
            2 * (1 - t) * t * controlPoint.dx +
            t * t * widget.end.dx;

        final currentY = (1 - t) * (1 - t) * widget.start.dy +
            2 * (1 - t) * t * controlPoint.dy +
            t * t * widget.end.dy;

        final currentScale = _scaleAnimation.value;
        final currentSize = widget.startSize.width > 60 
            ? 60.0 
            : widget.startSize.width.toDouble();

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.scale(
            scale: currentScale,
            child: Container(
              width: currentSize,
              height: currentSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

