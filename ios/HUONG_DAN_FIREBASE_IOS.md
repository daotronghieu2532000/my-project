# 🔥 HƯỚNG DẪN THÊM FIREBASE CHO iOS

## 📋 TỔNG QUAN

Bạn đã có Firebase cho Android (`google-services.json`), bây giờ cần thêm Firebase cho iOS (`GoogleService-Info.plist`).

**Lưu ý quan trọng:**
- ✅ Cùng một Firebase project: `socdomobile`
- ✅ Cùng mục đích: **Firebase Cloud Messaging** (push notifications)
- ✅ Bundle ID iOS: `com.socdo.mobile` (giống Android package name)

---

## 🔧 CÁC BƯỚC THÊM FIREBASE CHO iOS

### BƯỚC 1: Truy cập Firebase Console

1. **Mở trình duyệt:**
   - Truy cập: https://console.firebase.google.com/
   - Đăng nhập bằng tài khoản Google của bạn

2. **Chọn project:**
   - Chọn project: **`socdomobile`** (cùng project với Android)

---

### BƯỚC 2: Kiểm tra hoặc tạo iOS App

1. **Vào Project Settings:**
   - Click vào icon **⚙️** (Settings) ở góc trên bên trái
   - Chọn **"Project settings"**

2. **Scroll xuống phần "Your apps":**
   - Bạn sẽ thấy app Android đã có: `com.socdo.mobile`
   - Kiểm tra xem có app iOS chưa

3. **Nếu chưa có app iOS:**
   - Click nút **"Add app"** hoặc icon **iOS** (🍎)
   - Điền thông tin:
     - **iOS bundle ID**: `com.socdo.mobile`
     - **App nickname** (tùy chọn): `Socdo iOS`
     - **App Store ID** (tùy chọn): Để trống nếu chưa có
   - Click **"Register app"**

4. **Nếu đã có app iOS:**
   - Kiểm tra Bundle ID có đúng `com.socdo.mobile` không
   - Nếu khác, cần tạo app iOS mới với Bundle ID đúng

---

### BƯỚC 3: Tải file GoogleService-Info.plist

1. **Trong phần app iOS:**
   - Tìm phần **"Download GoogleService-Info.plist"**
   - Click nút **"Download GoogleService-Info.plist"**

2. **Lưu file:**
   - File sẽ được tải về với tên: `GoogleService-Info.plist`
   - Lưu file này vào thư mục tạm (Desktop hoặc Downloads)

---

### BƯỚC 4: Thêm file vào Xcode Project

#### Cách 1: Dùng Xcode (Khuyến nghị)

1. **Mở Xcode:**
   ```bash
   cd /path/to/socdo_mobile
   open ios/Runner.xcworkspace
   ```
   ⚠️ **LƯU Ý**: Phải mở file `.xcworkspace`, KHÔNG phải `.xcodeproj`

2. **Kéo file vào project:**
   - Trong Xcode, tìm thư mục **"Runner"** ở sidebar trái
   - Kéo file `GoogleService-Info.plist` từ Finder vào thư mục **"Runner"** trong Xcode
   - Hộp thoại sẽ hiện ra:
     - ✅ Tích vào **"Copy items if needed"**
     - ✅ Đảm bảo **"Add to targets: Runner"** được chọn
     - Click **"Finish"**

3. **Kiểm tra:**
   - File `GoogleService-Info.plist` sẽ xuất hiện trong thư mục **"Runner"**
   - Click vào file, kiểm tra trong **"Target Membership"** có tích **"Runner"**

#### Cách 2: Copy trực tiếp (Nhanh hơn, nhưng cần thêm vào Xcode sau)

1. **Copy file:**
   ```bash
   # Copy file vào thư mục ios/Runner/
   cp ~/Downloads/GoogleService-Info.plist ios/Runner/
   ```

2. **Thêm vào Xcode:**
   - Mở Xcode: `open ios/Runner.xcworkspace`
   - Right-click vào thư mục **"Runner"** → **"Add Files to Runner..."**
   - Chọn file `GoogleService-Info.plist`
   - ✅ Đảm bảo **"Copy items if needed"** được tích
   - ✅ Đảm bảo **"Add to targets: Runner"** được chọn
   - Click **"Add"**

---

### BƯỚC 5: Kiểm tra cấu hình

1. **Mở file GoogleService-Info.plist:**
   - Trong Xcode, click vào file `GoogleService-Info.plist`
   - Kiểm tra các giá trị:
     - **BUNDLE_ID**: Phải là `com.socdo.mobile`
     - **PROJECT_ID**: Phải là `socdomobile`
     - **GOOGLE_APP_ID**: Phải có giá trị (bắt đầu bằng `1:`)

2. **Kiểm tra trong code:**
   - File `lib/main.dart` đã có:
     ```dart
     await Firebase.initializeApp();
     ```
   - Điều này sẽ tự động load `GoogleService-Info.plist` cho iOS

---

## ✅ KIỂM TRA SAU KHI THÊM

### 1. Build và test

```bash
cd /path/to/socdo_mobile

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Install CocoaPods
cd ios
pod install
cd ..

# Build iOS (hoặc chạy trên simulator)
flutter run -d ios
```

### 2. Kiểm tra Firebase hoạt động

- App sẽ khởi tạo Firebase khi mở
- Push notifications sẽ hoạt động trên iOS (giống Android)

---

## 🚨 XỬ LÝ LỖI THƯỜNG GẶP

### ❌ Lỗi: "GoogleService-Info.plist not found"

**Nguyên nhân**: File chưa được thêm vào Xcode project

**Cách sửa:**
1. Mở Xcode: `open ios/Runner.xcworkspace`
2. Right-click vào thư mục "Runner" → "Add Files to Runner..."
3. Chọn file `GoogleService-Info.plist`
4. ✅ Tích "Copy items if needed"
5. ✅ Tích "Add to targets: Runner"

### ❌ Lỗi: "Bundle ID mismatch"

**Nguyên nhân**: Bundle ID trong Firebase khác với project

**Cách sửa:**
1. Kiểm tra Bundle ID trong Firebase Console
2. Phải là: `com.socdo.mobile`
3. Nếu khác, tạo app iOS mới với Bundle ID đúng

### ❌ Lỗi: "Firebase initialization failed"

**Cách sửa:**
1. Clean build: `flutter clean`
2. Xóa Pods: `cd ios && rm -rf Pods Podfile.lock && pod install && cd ..`
3. Build lại: `flutter run -d ios`

---

## 📋 CHECKLIST

- [ ] Đã truy cập Firebase Console
- [ ] Đã chọn project `socdomobile`
- [ ] Đã tạo app iOS (nếu chưa có) với Bundle ID: `com.socdo.mobile`
- [ ] Đã tải file `GoogleService-Info.plist`
- [ ] Đã thêm file vào Xcode project tại `ios/Runner/`
- [ ] Đã kiểm tra Target Membership có "Runner"
- [ ] Đã build và test thành công

---

## 📚 TÀI LIỆU THAM KHẢO

- **Firebase iOS Setup**: https://firebase.google.com/docs/ios/setup
- **Flutter Firebase**: https://firebase.flutter.dev/
- **Firebase Console**: https://console.firebase.google.com/

---

## ✅ KẾT LUẬN

Sau khi hoàn thành các bước trên:
- ✅ Firebase sẽ hoạt động trên iOS (giống Android)
- ✅ Push notifications sẽ hoạt động trên cả hai platform
- ✅ Cùng một Firebase project, cùng cấu hình

**Lưu ý:** File `GoogleService-Info.plist` cho iOS tương đương với `google-services.json` cho Android - cả hai đều dùng cho Firebase Cloud Messaging (push notifications).

