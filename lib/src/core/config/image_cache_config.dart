import 'package:flutter/material.dart';

/// Image Cache Configuration - Tối ưu cho performance
/// 
/// Cấu hình:
/// 1. Tăng memory cache để giảm reload
/// 2. Decode image trên isolate (tự động từ Flutter 2.x)
/// 3. Giới hạn cache size để tránh OOM
class ImageCacheConfig {
  /// Initialize image cache với cấu hình tối ưu
  static void initialize() {
    // Cấu hình PaintingBinding image cache
    final PaintingBinding binding = PaintingBinding.instance;
    
    // Tăng memory cache lên 150MB (mặc định: 100MB)
    // Với 500 products, mỗi ảnh ~300KB → 150MB là hợp lý
    binding.imageCache.maximumSizeBytes = 150 * 1024 * 1024; // 150MB
    
    // Tăng số lượng images trong cache (mặc định: 1000)
    binding.imageCache.maximumSize = 500; // Giữ 500 images
    
    debugPrint('✅ Image cache initialized: 150MB, 500 images');
  }
  
  /// Clear image cache (khi cần giải phóng memory)
  static void clearCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

  }
  
  /// Get cache stats (để debug)
  static Map<String, dynamic> getCacheStats() {
    final cache = PaintingBinding.instance.imageCache;
    return {
      'currentSize': cache.currentSize,
      'currentSizeBytes': cache.currentSizeBytes,
      'maximumSize': cache.maximumSize,
      'maximumSizeBytes': cache.maximumSizeBytes,
    };
  }
  
}

/// Cách sử dụng:
/// 
/// 1. Trong main.dart, gọi trước runApp:
///    ```dart
///    void main() {
///      WidgetsFlutterBinding.ensureInitialized();
///      ImageCacheConfig.initialize();
///      runApp(MyApp());
///    }
///    ```
/// 
/// 2. Trong debug mode, có thể print stats:
///    ```dart
///    ImageCacheConfig.printCacheStats();
///    ```
/// 
/// 3. Clear cache khi cần (ví dụ: logout):
///    ```dart
///    ImageCacheConfig.clearCache();
///    ```

