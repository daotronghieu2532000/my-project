# 🍎 HƯỚNG DẪN CHUẨN BỊ TẠO FILE IPA CHO APPLE STORE

## 📋 TỔNG QUAN CẤU HÌNH iOS HIỆN TẠI

### ✅ Thông tin App đã cấu hình:
- **Bundle Identifier**: `com.socdo.mobile`
- **Display Name**: `Socdo`
- **Version**: `1.0.0+1` (từ `pubspec.yaml`)
- **iOS Deployment Target**: `13.0`
- **Swift Version**: `5.0`
- **Code Sign Style**: `Automatic`

### ✅ Các file cấu hình đã có:
- ✅ `Info.plist` - Cấu hình app cơ bản
- ✅ `Podfile` - Quản lý dependencies
- ✅ `AppDelegate.swift` - Entry point của app
- ✅ App Icons - Đã có đầy đủ các kích thước
- ✅ Launch Screen - Đã có storyboard

### ⚠️ Các file cần kiểm tra/bổ sung:
- ⚠️ `GoogleService-Info.plist` - File Firebase cho iOS (chưa thấy trong project)
- ⚠️ Development Team - Chưa được cấu hình (cần cấu hình khi có Apple Developer Account)

---

## 🔧 CÁC BƯỚC CHUẨN BỊ TẠO IPA

### BƯỚC 1: KIỂM TRA VÀ CẬP NHẬT CẤU HÌNH CƠ BẢN

#### 1.1. Kiểm tra `pubspec.yaml`
```yaml
version: 1.0.0+1  # ✅ Đã đúng
```
- **Version**: `1.0.0` (CFBundleShortVersionString)
- **Build Number**: `1` (CFBundleVersion)

#### 1.2. Kiểm tra `Info.plist`
File: `ios/Runner/Info.plist`

**Đã có:**
- ✅ `CFBundleDisplayName`: `Socdo`
- ✅ `CFBundleIdentifier`: `$(PRODUCT_BUNDLE_IDENTIFIER)` → `com.socdo.mobile`
- ✅ `NSPhotoLibraryUsageDescription` - Mô tả quyền truy cập thư viện ảnh
- ✅ `NSCameraUsageDescription` - Mô tả quyền truy cập camera

**Cần kiểm tra thêm:**
- ⚠️ `ITSAppUsesNonExemptEncryption` - Cần khai báo nếu app không dùng encryption
- ⚠️ `UIRequiredDeviceCapabilities` - Nếu app yêu cầu tính năng đặc biệt

#### 1.3. Kiểm tra `Podfile`
File: `ios/Podfile`

**Hiện tại:**
```ruby
# platform :ios, '13.0'  # ⚠️ Đang comment, nên uncomment
```

**Cần sửa:**
```ruby
platform :ios, '13.0'  # ✅ Uncomment dòng này
```

---

### BƯỚC 2: CẤU HÌNH FIREBASE CHO iOS

#### 2.1. Kiểm tra Firebase Configuration

**App đang sử dụng Firebase:**
- `firebase_core: ^2.24.0`
- `firebase_messaging: ^14.7.9`

**Cần có file:** `ios/Runner/GoogleService-Info.plist`

#### 2.2. Cách lấy `GoogleService-Info.plist`:

1. **Truy cập Firebase Console:**
   - Vào: https://console.firebase.google.com/
   - Chọn project: `socdomobile`

2. **Tải file GoogleService-Info.plist:**
   - Vào **Project Settings** (⚙️)
   - Scroll xuống phần **Your apps**
   - Tìm app iOS (hoặc tạo mới nếu chưa có)
   - Click **Download GoogleService-Info.plist**

3. **Thêm file vào project:**
   - Copy file `GoogleService-Info.plist` vào: `ios/Runner/`
   - Mở Xcode: `ios/Runner.xcworkspace`
   - Kéo file vào project trong Xcode
   - ✅ Đảm bảo tích vào "Copy items if needed"
   - ✅ Đảm bảo target "Runner" được chọn

#### 2.3. Kiểm tra Bundle ID trong Firebase:
- Firebase iOS app phải có Bundle ID: `com.socdo.mobile`
- Nếu chưa có, tạo app iOS mới trong Firebase Console

---

### BƯỚC 3: CẤU HÌNH XCODE CHO BUILD RELEASE

#### 3.1. Mở project trong Xcode

```bash
cd /path/to/socdo_mobile
open ios/Runner.xcworkspace
```

⚠️ **LƯU Ý**: Phải mở file `.xcworkspace`, KHÔNG phải `.xcodeproj`

#### 3.2. Cấu hình Signing & Capabilities

1. **Chọn Target "Runner":**
   - Click vào project "Runner" (icon màu xanh) ở sidebar trái
   - Chọn target "Runner" trong danh sách targets

2. **Tab "Signing & Capabilities":**
   - **Team**: Chọn Team của bạn (từ Apple Developer Account)
   - **Bundle Identifier**: `com.socdo.mobile` ✅
   - **Automatically manage signing**: ✅ Tích vào
   - Xcode sẽ tự động tạo Certificate và Provisioning Profile

3. **Nếu chưa có Team:**
   - Vào **Xcode** → **Preferences** (hoặc **Settings**)
   - Tab **"Accounts"**
   - Click **"+"** để thêm Apple ID
   - Đăng nhập bằng Apple ID đã đăng ký Apple Developer Program

#### 3.3. Cấu hình Build Settings

1. **Chọn Target "Runner"** → Tab **"Build Settings"**

2. **Kiểm tra các settings quan trọng:**
   - **Product Bundle Identifier**: `com.socdo.mobile` ✅
   - **iOS Deployment Target**: `13.0` ✅
   - **Swift Language Version**: `Swift 5` ✅
   - **Code Signing Identity**: `Apple Development` (tự động)
   - **Development Team**: Chọn Team của bạn

3. **Cấu hình Version:**
   - **Marketing Version**: `1.0.0` (từ `pubspec.yaml`)
   - **Current Project Version**: `$(FLUTTER_BUILD_NUMBER)` ✅

#### 3.4. Cấu hình Capabilities (nếu cần)

**Push Notifications:**
- Nếu app dùng Firebase Cloud Messaging, cần bật:
  - Tab **"Signing & Capabilities"**
  - Click **"+ Capability"**
  - Thêm **"Push Notifications"**

**Background Modes:**
- Nếu app cần chạy background:
  - Thêm **"Background Modes"**
  - Tích các mode cần thiết (ví dụ: Remote notifications)

---

### BƯỚC 4: CẬP NHẬT PODFILE VÀ CÀI ĐẶT DEPENDENCIES

#### 4.1. Cập nhật Podfile

Sửa file `ios/Podfile`:

```ruby
# Uncomment dòng này
platform :ios, '13.0'
```

#### 4.2. Cài đặt CocoaPods dependencies

```bash
cd ios
pod install
pod update  # Nếu cần cập nhật
cd ..
```

#### 4.3. Kiểm tra Flutter dependencies

```bash
flutter pub get
flutter clean
flutter pub get
```

---

### BƯỚC 5: KIỂM TRA VÀ CẬP NHẬT INFOPLIST

#### 5.1. Thêm các keys cần thiết cho App Store

Mở file `ios/Runner/Info.plist` và kiểm tra:

**Các keys đã có:**
- ✅ `NSPhotoLibraryUsageDescription`
- ✅ `NSCameraUsageDescription`

**Các keys nên thêm (nếu cần):**
- ⚠️ `ITSAppUsesNonExemptEncryption` - Khai báo nếu app không dùng encryption đặc biệt
- ⚠️ `NSLocationWhenInUseUsageDescription` - Nếu app dùng location
- ⚠️ `NSUserTrackingUsageDescription` - Nếu app dùng tracking (iOS 14.5+)

**Ví dụ thêm vào Info.plist:**
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

### BƯỚC 6: BUILD APP CHO RELEASE

#### 6.1. Build bằng Flutter (Khuyến nghị)

```bash
cd /path/to/socdo_mobile

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build iOS release
flutter build ios --release
```

**Kết quả:**
- File `.app` sẽ được tạo tại: `build/ios/iphoneos/Runner.app`

#### 6.2. Build bằng Xcode (Để tạo Archive)

1. **Mở Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Chọn Scheme và Device:**
   - Ở thanh toolbar, chọn **"Runner"** → **"Any iOS Device"**
   - ⚠️ **QUAN TRỌNG**: Phải chọn "Any iOS Device", KHÔNG chọn simulator

3. **Archive:**
   - Menu: **Product** → **Archive**
   - Xcode sẽ build và tạo Archive
   - Quá trình này có thể mất 5-15 phút

4. **Kết quả:**
   - Sau khi Archive xong, cửa sổ **Organizer** sẽ hiện ra
   - Archive sẽ được lưu và có thể export thành IPA

---

### BƯỚC 7: TẠO FILE IPA

#### 7.1. Từ Xcode Organizer

1. **Mở Organizer:**
   - Trong Xcode: **Window** → **Organizer**
   - Hoặc sau khi Archive xong, Organizer sẽ tự động mở

2. **Chọn Archive:**
   - Chọn Archive vừa tạo
   - Click **"Distribute App"**

3. **Chọn phương thức phân phối:**
   - **App Store Connect** - Để upload lên App Store
   - **Ad Hoc** - Để test trên thiết bị cụ thể
   - **Enterprise** - Cho doanh nghiệp
   - **Development** - Cho development

4. **Chọn "App Store Connect":**
   - Click **"Next"**
   - Chọn **"Upload"** (khuyến nghị)
   - Click **"Next"**

5. **Distribution Options:**
   - Chọn **"Automatically manage signing"** (khuyến nghị)
   - Click **"Next"**

6. **Review:**
   - Xem lại thông tin
   - Click **"Upload"**

7. **Đợi upload:**
   - Quá trình upload có thể mất 10-30 phút
   - Sau khi upload xong, bạn sẽ thấy thông báo thành công

#### 7.2. Export IPA để lưu trữ

Nếu muốn lưu file IPA:

1. Trong bước **"Distribution Options"**, chọn **"Export"** thay vì **"Upload"**
2. Chọn thư mục để lưu file IPA
3. File IPA sẽ được tạo tại thư mục đã chọn

---

## 📋 CHECKLIST TRƯỚC KHI TẠO IPA

### Cấu hình cơ bản:
- [ ] ✅ Bundle ID: `com.socdo.mobile`
- [ ] ✅ Version: `1.0.0+1` (từ `pubspec.yaml`)
- [ ] ✅ Display Name: `Socdo`
- [ ] ✅ iOS Deployment Target: `13.0`
- [ ] ✅ Swift Version: `5.0`

### Dependencies:
- [ ] ✅ Đã chạy `flutter pub get`
- [ ] ✅ Đã chạy `pod install` trong thư mục `ios/`
- [ ] ✅ Podfile đã uncomment `platform :ios, '13.0'`

### Firebase:
- [ ] ⚠️ Đã có file `GoogleService-Info.plist` trong `ios/Runner/`
- [ ] ⚠️ Bundle ID trong Firebase khớp với project (`com.socdo.mobile`)

### Xcode Configuration:
- [ ] ⚠️ Đã mở project bằng `.xcworkspace` (không phải `.xcodeproj`)
- [ ] ⚠️ Đã chọn Team trong Signing & Capabilities
- [ ] ⚠️ "Automatically manage signing" đã được bật
- [ ] ⚠️ Code Signing đã được cấu hình thành công (không có lỗi)

### Info.plist:
- [ ] ✅ Đã có `NSPhotoLibraryUsageDescription`
- [ ] ✅ Đã có `NSCameraUsageDescription`
- [ ] ⚠️ Đã thêm `ITSAppUsesNonExemptEncryption` (nếu cần)

### Build:
- [ ] ⚠️ Đã build thành công bằng `flutter build ios --release`
- [ ] ⚠️ Đã tạo Archive trong Xcode thành công
- [ ] ⚠️ Không có lỗi hoặc warning nghiêm trọng

---

## 🚨 CÁC LỖI THƯỜNG GẶP VÀ CÁCH SỬA

### ❌ Lỗi: "No signing certificate found"

**Nguyên nhân**: Chưa chọn Team hoặc chưa đăng nhập Apple Developer Account

**Cách sửa:**
1. Vào Xcode → Preferences → Accounts
2. Đăng nhập Apple ID đã đăng ký Apple Developer Program
3. Vào Signing & Capabilities, chọn Team

### ❌ Lỗi: "Bundle identifier is already in use"

**Nguyên nhân**: Bundle ID đã được sử dụng bởi app khác

**Cách sửa:**
- Đổi Bundle ID trong Xcode (ví dụ: `com.socdo.mobile.v2`)
- Hoặc xóa app cũ trên App Store Connect

### ❌ Lỗi: "GoogleService-Info.plist not found"

**Nguyên nhân**: Chưa thêm file Firebase configuration

**Cách sửa:**
1. Tải `GoogleService-Info.plist` từ Firebase Console
2. Thêm vào `ios/Runner/`
3. Thêm vào Xcode project

### ❌ Lỗi: "Pod install failed"

**Cách sửa:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

### ❌ Lỗi: "Archive failed"

**Cách sửa:**
1. Clean build: `flutter clean`
2. Xóa DerivedData trong Xcode
3. Build lại: `flutter build ios --release`
4. Archive lại trong Xcode

---

## 📚 TÀI LIỆU THAM KHẢO

- **Flutter iOS Deployment**: https://docs.flutter.dev/deployment/ios
- **Apple Developer**: https://developer.apple.com/
- **App Store Connect**: https://appstoreconnect.apple.com/
- **Firebase iOS Setup**: https://firebase.google.com/docs/ios/setup

---

## ✅ KẾT LUẬN

Sau khi hoàn thành các bước trên, bạn sẽ có:
1. ✅ Project iOS đã được cấu hình đầy đủ
2. ✅ Archive đã được tạo trong Xcode
3. ✅ File IPA đã được upload lên App Store Connect (hoặc export để lưu trữ)

**Bước tiếp theo**: Làm theo hướng dẫn trong `doc/HUONG_DAN_PUBLISH_APP_STORE.md` để submit app lên App Store.

**Chúc bạn thành công! 🎉**

