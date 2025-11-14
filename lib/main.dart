import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'src/app.dart';
import 'src/core/services/app_initialization_service.dart';
import 'src/core/services/app_lifecycle_manager.dart';

void main() async {
  // Khởi tạo Flutter binding
  WidgetsFlutterBinding.ensureInitialized();
  
  // KHỞI TẠO FIREBASE TRƯỚC TIÊN
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
  }
  
  // Khởi tạo app services
  await _initializeApp();
  
  runApp(const SocdoApp());
}

Future<void> _initializeApp() async {
  try {
    print('🚀 Đang khởi tạo ứng dụng...');
    
    // Khởi tạo AppLifecycleManager (không blocking)
    final lifecycleManager = AppLifecycleManager();
    lifecycleManager.initialize();
    
    // Khởi tạo token (chạy background, không block UI)
    final initService = AppInitializationService();
    initService.initializeApp().then((success) {
      if (success) {
        print('✅ Khởi tạo ứng dụng thành công');
      } else {
        print('⚠️ Khởi tạo ứng dụng thất bại, tiếp tục chạy app');
      }
    });
    
    // KHÔNG delay - vào Flutter splash screen NGAY LẬP TỨC
    
  } catch (e) {
    print('❌ Lỗi khởi tạo ứng dụng: $e');
    // Vẫn tiếp tục chạy app dù có lỗi
  }
}