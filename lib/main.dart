import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'src/app.dart';
import 'src/core/services/app_initialization_service.dart';
import 'src/core/services/app_lifecycle_manager.dart';
import 'src/core/services/deep_link_service.dart';
import 'src/core/config/image_cache_config.dart';

void main() async {
  // Khởi tạo Flutter binding
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Khởi tạo Image Cache Config (QUAN TRỌNG - tránh skip frames)
  ImageCacheConfig.initialize();
  
  // KHỞI TẠO FIREBASE TRƯỚC TIÊN
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Log lỗi để debug
    print('Firebase initialization error: $e');
    // Tiếp tục chạy app dù Firebase lỗi
  }
  
  // Khởi tạo app services
  await _initializeApp();
  
  runApp(const SocdoApp());
}

Future<void> _initializeApp() async {
  try {
   
    
    // Khởi tạo AppLifecycleManager (không blocking)
    final lifecycleManager = AppLifecycleManager();
    lifecycleManager.initialize();
    
    // Khởi tạo Deep Link Service
    final deepLinkService = DeepLinkService();
    deepLinkService.init();
    
    // Khởi tạo token (chạy background, không block UI)
    final initService = AppInitializationService();
    initService.initializeApp().then((success) {
     
    });
    
    // KHÔNG delay - vào Flutter splash screen NGAY LẬP TỨC
    
  } catch (e) {
   
  }
}