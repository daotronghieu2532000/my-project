# 📊 BÁO CÁO SO SÁNH ANDROID VÀ iOS - SOCDO MOBILE

## ✅ CÁC ĐIỂM ĐÃ GIỐNG NHAU

### 1. Bundle ID / Application ID
- ✅ Android: `com.socdo.mobile`
- ✅ iOS: `com.socdo.mobile`
- **Kết luận**: ✅ GIỐNG NHAU

### 2. Version
- ✅ Android: `1.0.0+1` (từ `pubspec.yaml`)
- ✅ iOS: `1.0.0+1` (từ `pubspec.yaml`)
- **Kết luận**: ✅ GIỐNG NHAU

### 3. Splash Screen
- ✅ Android: Dùng Flutter splash screen (từ `lib/src/presentation/splash/splash_screen.dart`)
- ✅ iOS: Dùng Flutter splash screen (từ `lib/src/presentation/splash/splash_screen.dart`)
- **Kết luận**: ✅ GIỐNG NHAU - Cả hai đều vào thẳng Flutter splash screen

### 4. Firebase Configuration
- ✅ Android: Có `google-services.json` tại `android/app/google-services.json`
- ⚠️ iOS: Cần thêm `GoogleService-Info.plist` tại `ios/Runner/`
- **Lưu ý**: Cùng một Firebase project (`socdomobile`), chỉ cần tải file cho iOS

### 5. Permissions
- ✅ Android: `INTERNET`, `ACCESS_NETWORK_STATE`
- ✅ iOS: Không cần khai báo INTERNET (tự động), đã có `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`
- **Kết luận**: ✅ TƯƠNG ĐƯƠNG

### 6. Tính năng
- ✅ Cả hai đều dùng cùng Flutter codebase
- ✅ Cùng dependencies trong `pubspec.yaml`
- ✅ Cùng giao diện và chức năng
- **Kết luận**: ✅ GIỐNG NHAU

---

## ⚠️ CÁC ĐIỂM CẦN SỬA

### 1. ❌ TÊN APP KHÁC NHAU

**Hiện tại:**
- Android: `"Socdo"` (chữ hoa đầu)
- iOS: `"socdo"` (chữ thường)

**Cần sửa:**
- iOS: Đổi thành `"Socdo"` để giống Android

**File cần sửa:**
- `ios/Runner/Info.plist` - Dòng `CFBundleDisplayName` và `CFBundleName`

---

### 2. ⚠️ FIREBASE CONFIGURATION CHO iOS

**Hiện tại:**
- Android: ✅ Có `google-services.json`
- iOS: ❌ Chưa có `GoogleService-Info.plist`

**Cách lấy file Firebase cho iOS:**

1. **Truy cập Firebase Console:**
   - Vào: https://console.firebase.google.com/
   - Chọn project: `socdomobile` (cùng project với Android)

2. **Tải GoogleService-Info.plist:**
   - Vào **Project Settings** (⚙️)
   - Scroll xuống phần **Your apps**
   - Tìm app iOS (hoặc tạo mới nếu chưa có)
   - **Bundle ID iOS phải là**: `com.socdo.mobile`
   - Click **Download GoogleService-Info.plist**

3. **Thêm vào project:**
   - Copy file vào: `ios/Runner/GoogleService-Info.plist`
   - Mở Xcode: `ios/Runner.xcworkspace`
   - Kéo file vào project trong Xcode
   - ✅ Đảm bảo tích vào "Copy items if needed"
   - ✅ Đảm bảo target "Runner" được chọn

**Lưu ý:** File Firebase này dùng cho **Firebase Cloud Messaging** (push notifications) - đúng như bạn đang dùng cho Android.

---

## 📋 CHECKLIST ĐỒNG BỘ

### Tên App
- [x] ✅ Android: "Socdo"
- [ ] ⚠️ iOS: Cần sửa thành "Socdo" (hiện tại là "socdo")

### Firebase
- [x] ✅ Android: Có `google-services.json`
- [ ] ⚠️ iOS: Cần thêm `GoogleService-Info.plist`

### Permissions
- [x] ✅ Android: INTERNET, ACCESS_NETWORK_STATE
- [x] ✅ iOS: Photo Library, Camera (đã có)

### Splash Screen
- [x] ✅ Cả hai đều dùng Flutter splash screen

### App Icon
- [x] ✅ Android: Có icon tại `android/app/src/main/res/mipmap-*/ic_launcher.png`
- [x] ✅ iOS: Có icon tại `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

---

## 🔧 CÁC BƯỚC SỬA

### Bước 1: Sửa tên app iOS
Đã được sửa trong file `ios/Runner/Info.plist`:
- `CFBundleDisplayName`: "Socdo"
- `CFBundleName`: "socdo" (giữ nguyên - đây là internal name)

### Bước 2: Thêm Firebase cho iOS
1. Tải `GoogleService-Info.plist` từ Firebase Console
2. Thêm vào `ios/Runner/`
3. Thêm vào Xcode project

---

## ✅ KẾT LUẬN

Sau khi sửa:
- ✅ Tên app sẽ giống nhau: "Socdo"
- ✅ Firebase sẽ hoạt động trên cả hai platform
- ✅ Giao diện, tính năng, chức năng đã giống nhau (cùng Flutter codebase)
- ✅ Splash screen đã giống nhau (cùng Flutter splash screen)

**Chỉ còn thiếu:** File `GoogleService-Info.plist` cho iOS (cần tải từ Firebase Console).

