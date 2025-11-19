# 📱 TÓM TẮT CẤU HÌNH iOS - SOCDO MOBILE

## 📋 THÔNG TIN DỰ ÁN

- **Tên App**: Socdo
- **Bundle ID**: `com.socdo.mobile`
- **Version**: `1.0.0+1`
- **Platform**: Flutter iOS
- **iOS Deployment Target**: `13.0`
- **Swift Version**: `5.0`

---

## ✅ CẤU HÌNH ĐÃ HOÀN THÀNH

### 1. Cấu hình cơ bản
- ✅ Bundle Identifier: `com.socdo.mobile`
- ✅ Display Name: `Socdo`
- ✅ Version: `1.0.0+1` (từ `pubspec.yaml`)
- ✅ iOS Deployment Target: `13.0`
- ✅ Podfile: Đã uncomment `platform :ios, '13.0'`

### 2. Privacy Permissions
- ✅ `NSPhotoLibraryUsageDescription` - Quyền truy cập thư viện ảnh
- ✅ `NSCameraUsageDescription` - Quyền truy cập camera
- ✅ `ITSAppUsesNonExemptEncryption` - Khai báo export compliance

### 3. App Icons
- ✅ Đã có đầy đủ các kích thước icon (20x20 đến 1024x1024)
- ✅ Hỗ trợ cả iPhone và iPad

### 4. Launch Screen
- ✅ Đã có LaunchScreen.storyboard
- ✅ Đã có LaunchImage assets

### 5. Dependencies
- ✅ Firebase Core: `^2.24.0`
- ✅ Firebase Messaging: `^14.7.9`
- ✅ Flutter Local Notifications: `^17.2.1`
- ✅ Image Picker: `^1.0.7`
- ✅ Các dependencies khác đã được cấu hình

---

## ⚠️ CẦN HOÀN THÀNH TRƯỚC KHI TẠO IPA

### 1. Firebase Configuration
- ⚠️ **Cần thêm**: File `GoogleService-Info.plist` vào `ios/Runner/`
- ⚠️ **Cách lấy**: 
  1. Vào Firebase Console: https://console.firebase.google.com/
  2. Chọn project `socdomobile`
  3. Vào Project Settings → Your apps
  4. Tạo app iOS (nếu chưa có) với Bundle ID: `com.socdo.mobile`
  5. Download `GoogleService-Info.plist`
  6. Thêm vào Xcode project tại `ios/Runner/`

### 2. Apple Developer Account
- ⚠️ **Cần có**: Apple Developer Program ($99 USD/năm)
- ⚠️ **Cần cấu hình**: 
  - Đăng nhập Apple ID trong Xcode Preferences
  - Chọn Team trong Signing & Capabilities
  - Bật "Automatically manage signing"

### 3. Code Signing
- ⚠️ **Cần cấu hình trong Xcode**:
  - Mở `ios/Runner.xcworkspace` trong Xcode
  - Chọn Target "Runner" → Tab "Signing & Capabilities"
  - Chọn Team
  - Xcode sẽ tự động tạo Certificate và Provisioning Profile

---

## 📁 CẤU TRÚC THƯ MỤC iOS

```
ios/
├── Runner/
│   ├── AppDelegate.swift          ✅ Entry point
│   ├── Info.plist                 ✅ App configuration
│   ├── Assets.xcassets/           ✅ Icons & images
│   ├── Base.lproj/                ✅ Storyboards
│   └── GoogleService-Info.plist   ⚠️ CẦN THÊM
├── Flutter/
│   ├── Generated.xcconfig         ✅ Flutter config
│   ├── Debug.xcconfig             ✅ Debug config
│   └── Release.xcconfig           ✅ Release config
├── Podfile                        ✅ Dependencies
└── Runner.xcworkspace             ✅ Xcode workspace
```

---

## 🔧 CÁC FILE QUAN TRỌNG

### 1. `ios/Podfile`
- ✅ Đã uncomment `platform :ios, '13.0'`
- ✅ Đã cấu hình CocoaPods

### 2. `ios/Runner/Info.plist`
- ✅ Đã có privacy permissions
- ✅ Đã có export compliance declaration
- ✅ Đã có app configuration cơ bản

### 3. `ios/Runner/AppDelegate.swift`
- ✅ Đã cấu hình Flutter entry point
- ✅ Đã register plugins

### 4. `pubspec.yaml`
- ✅ Version: `1.0.0+1`
- ✅ Dependencies đã được khai báo

---

## 🚀 CÁC BƯỚC TIẾP THEO

### Bước 1: Thêm Firebase Configuration
1. Tải `GoogleService-Info.plist` từ Firebase Console
2. Thêm vào `ios/Runner/` và Xcode project

### Bước 2: Cấu hình Xcode
1. Mở `ios/Runner.xcworkspace` trong Xcode
2. Chọn Team trong Signing & Capabilities
3. Kiểm tra không có lỗi

### Bước 3: Build và Test
1. Chạy `flutter pub get`
2. Chạy `cd ios && pod install && cd ..`
3. Build: `flutter build ios --release`

### Bước 4: Tạo Archive
1. Mở Xcode
2. Chọn "Any iOS Device"
3. Product → Archive
4. Distribute App → App Store Connect

---

## 📚 TÀI LIỆU THAM KHẢO

- **Hướng dẫn chi tiết**: Xem `ios/CHUAN_BI_TAO_IPA.md`
- **Hướng dẫn publish**: Xem `doc/HUONG_DAN_PUBLISH_APP_STORE.md`
- **Flutter iOS**: https://docs.flutter.dev/deployment/ios

---

## ✅ CHECKLIST NHANH

- [x] ✅ Podfile đã được cập nhật
- [x] ✅ Info.plist đã có privacy permissions
- [x] ✅ Info.plist đã có export compliance
- [ ] ⚠️ Cần thêm GoogleService-Info.plist
- [ ] ⚠️ Cần cấu hình Team trong Xcode
- [ ] ⚠️ Cần test build release

---

**Cập nhật lần cuối**: Hôm nay
**Trạng thái**: Sẵn sàng để cấu hình Xcode và tạo IPA

