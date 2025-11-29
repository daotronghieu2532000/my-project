import 'dart:async';
import 'package:flutter/foundation.dart';

/// Image Optimizer - Giống Shopee/Lazada
/// 
/// Chức năng:
/// 1. CDN + resize để giảm kích thước ảnh
/// 2. Giới hạn concurrent image loads (max 10 cùng lúc)
/// 3. Priority queue cho ảnh visible
class ImageOptimizer {
  static final ImageOptimizer _instance = ImageOptimizer._internal();
  factory ImageOptimizer() => _instance;
  ImageOptimizer._internal();

  // Giới hạn số ảnh load đồng thời (giống Shopee: 5-10)
  static const int maxConcurrentLoads = 10;
  
  // Track số ảnh đang load
  int _currentLoads = 0;
  
  // Queue cho các request đang chờ
  final List<_ImageLoadRequest> _queue = [];
  
  /// Optimize image URL với CDN + resize
  /// 
  /// Ví dụ:
  /// - Input: https://socdo.vn/uploads/product.jpg
  /// - Output: https://socdo.cdn.vccloud.vn/uploads/product.jpg?w=600&h=600&q=85
  /// 
  /// Quality 85 = cân bằng tốt giữa nét và dung lượng (Shopee dùng 80-85)
  static String getOptimizedUrl(
    String originalUrl, {
    int width = 600,
    int height = 600,
    int quality = 85,
  }) {
    if (originalUrl.isEmpty) return '';
    
    // Nếu đã là URL đầy đủ
    if (originalUrl.startsWith('http://') || originalUrl.startsWith('https://')) {
      String url = originalUrl;
      
      // Chuyển sang CDN nếu đang dùng domain chính
      if (url.contains('socdo.vn') && !url.contains('socdo.cdn.vccloud.vn')) {
        url = url.replaceFirst('socdo.vn', 'socdo.cdn.vccloud.vn');
      }
      
      // Thêm query params cho resize (nếu CDN hỗ trợ)
      // Note: Cần kiểm tra xem CDN có hỗ trợ resize không
      // Nếu không, có thể thêm API endpoint riêng để resize
      if (url.contains('socdo.cdn.vccloud.vn')) {
        final separator = url.contains('?') ? '&' : '?';
        url = '$url${separator}w=$width&h=$height&q=$quality';
      }
      
      return url;
    }
    
    // Nếu là relative path
    String path = originalUrl;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    
    return 'https://socdo.cdn.vccloud.vn/$path?w=$width&h=$height&q=$quality';
  }
  
  /// Load ảnh với concurrent limit
  /// Đảm bảo không quá [maxConcurrentLoads] ảnh load cùng lúc
  Future<void> loadImage(
    String url, {
    VoidCallback? onComplete,
    int priority = 0, // Priority cao = load trước (0 = normal, 1 = high, 2 = urgent)
  }) async {
    final request = _ImageLoadRequest(
      url: url,
      onComplete: onComplete,
      priority: priority,
      completer: Completer<void>(),
    );
    
    // Nếu đang load ít hơn max, load ngay
    if (_currentLoads < maxConcurrentLoads) {
      _executeLoad(request);
    } else {
      // Thêm vào queue
      _queue.add(request);
      // Sort theo priority (high priority trước)
      _queue.sort((a, b) => b.priority.compareTo(a.priority));
    }
    
    return request.completer.future;
  }
  
  void _executeLoad(_ImageLoadRequest request) {
    _currentLoads++;
    
    // Simulate image load (thực tế CachedNetworkImage sẽ load)
    Future.delayed(Duration.zero, () {
      request.onComplete?.call();
      request.completer.complete();
      
      _currentLoads--;
      
      // Load request tiếp theo trong queue
      if (_queue.isNotEmpty) {
        final nextRequest = _queue.removeAt(0);
        _executeLoad(nextRequest);
      }
    });
  }
  
  /// Clear queue (khi dispose screen)
  void clearQueue() {
    _queue.clear();
  }
  
  /// Get current load stats (để debug)
  Map<String, int> getStats() {
    return {
      'currentLoads': _currentLoads,
      'queueLength': _queue.length,
    };
  }
}

class _ImageLoadRequest {
  final String url;
  final VoidCallback? onComplete;
  final int priority;
  final Completer<void> completer;
  
  _ImageLoadRequest({
    required this.url,
    this.onComplete,
    required this.priority,
    required this.completer,
  });
}

/// Size presets cho các loại ảnh
/// 
/// Note: Kích thước này ĐÃ x2 cho màn hình cao DPI (Retina/2x/3x)
/// - Ảnh hiển thị 150px → cần 300-450px gốc để nét
/// - Quality 80-85 (cân bằng giữa nét và dung lượng)
class ImageSizes {
  // Product card thumbnail (nhỏ, trong grid)
  static const int thumbnailWidth = 400;  // x2 cho DPI cao
  static const int thumbnailHeight = 400;
  
  // Product card normal (trong danh sách)
  // Hiển thị ~180px → cần 540px (3x) hoặc 360px (2x)
  // Dùng 600px để đảm bảo nét trên mọi màn hình
  static const int cardWidth = 600;
  static const int cardHeight = 600;
  
  // Product detail main image (có thể zoom)
  // Cần lớn hơn để zoom vào vẫn nét
  static const int detailWidth = 1200;
  static const int detailHeight = 1200;
  
  // Banner/slider images (giữ nguyên để nét)
  static const int bannerWidth = 1200;
  static const int bannerHeight = 600;
  
  // Avatar/logo
  static const int avatarWidth = 200;  // x2 cho DPI cao
  static const int avatarHeight = 200;
}

