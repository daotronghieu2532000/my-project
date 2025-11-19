# ✅ CHECKLIST ĐẦY ĐỦ - SUBMIT APP 2025

**Ngày:** 19/11/2025  
**App:** Socdo  
**Bundle ID:** `com.socdo.mobile`

---

## 📱 PHẦN 1: CẤU HÌNH KỸ THUẬT

### Android
- [x] ✅ Bundle ID: `com.socdo.mobile`
- [x] ✅ Version: `1.0.0+1`
- [x] ✅ Tên app: "Socdo"
- [x] ✅ HTTP Cleartext Traffic: Đã tắt (chỉ HTTPS)
- [x] ✅ Network Security Config: Chỉ cho phép HTTPS
- [x] ✅ Firebase: Có `google-services.json`
- [x] ✅ Keystore: Đã cấu hình
- [x] ✅ Signing: Đã cấu hình
- [ ] ⚠️ **CẦN TEST**: Build AAB và test app

### iOS
- [x] ✅ Bundle ID: `com.socdo.mobile`
- [x] ✅ Version: `1.0.0+1`
- [x] ✅ Tên app: "Socdo"
- [x] ✅ Privacy Permissions: Đã có đầy đủ
- [x] ✅ Export Compliance: Đã khai báo
- [ ] ⚠️ **THIẾU**: `GoogleService-Info.plist` (cần thêm)
- [ ] ⚠️ **CẦN**: Apple Developer Account ($99/năm)
- [ ] ⚠️ **CẦN**: Code Signing trong Xcode
- [ ] ⚠️ **CẦN TEST**: Build IPA và test app

---

## 🔥 PHẦN 2: FIREBASE

### Android
- [x] ✅ Có file `google-services.json`
- [x] ✅ File ở đúng vị trí: `android/app/google-services.json`
- [x] ✅ Bundle ID trong Firebase: `com.socdo.mobile`

### iOS
- [ ] ❌ **THIẾU**: File `GoogleService-Info.plist`
- [ ] ⚠️ **CẦN**: Tải từ Firebase Console
- [ ] ⚠️ **CẦN**: Thêm vào `ios/Runner/`
- [ ] ⚠️ **CẦN**: Thêm vào Xcode project
- [ ] ⚠️ **CẦN**: Kiểm tra Bundle ID trong Firebase: `com.socdo.mobile`

**Hướng dẫn:** Xem `ios/HUONG_DAN_FIREBASE_IOS.md`

---

## 📋 PHẦN 3: KHAI BÁO TRONG CONSOLE

### Google Play Console

#### Data Safety (BẮT BUỘC)
- [ ] ⚠️ Khai báo dữ liệu thu thập:
  - [ ] User profile (tên, email, số điện thoại)
  - [ ] Device information
  - [ ] Push notification tokens
  - [ ] Photos (khi người dùng chọn ảnh)
  - [ ] Location (nếu có)
- [ ] ⚠️ Khai báo mục đích sử dụng
- [ ] ⚠️ Khai báo cách bảo vệ dữ liệu

#### Thông tin nhà phát triển (BẮT BUỘC cho EU từ 2/2025)
- [ ] ⚠️ Công khai tên nhà phát triển
- [ ] ⚠️ Công khai địa chỉ liên hệ

#### App Information
- [ ] ⚠️ App Name: "Socdo"
- [ ] ⚠️ Short Description
- [ ] ⚠️ Full Description
- [ ] ⚠️ Screenshots (tối thiểu 1 ảnh)
- [ ] ⚠️ App Icon (512x512)
- [ ] ⚠️ Feature Graphic (1024x500)
- [ ] ⚠️ Privacy Policy URL

### App Store Connect

#### App Privacy (BẮT BUỘC)
- [ ] ⚠️ Khai báo dữ liệu thu thập:
  - [ ] User profile
  - [ ] Device information
  - [ ] Push notification tokens
  - [ ] Photos
  - [ ] Location (nếu có)
- [ ] ⚠️ Khai báo mục đích sử dụng
- [ ] ⚠️ Khai báo cách bảo vệ dữ liệu

#### App Information
- [ ] ⚠️ App Name: "Socdo"
- [ ] ⚠️ Subtitle
- [ ] ⚠️ Description
- [ ] ⚠️ Keywords
- [ ] ⚠️ Screenshots (tối thiểu 1 ảnh cho mỗi kích thước)
- [ ] ⚠️ App Icon (1024x1024)
- [ ] ⚠️ Privacy Policy URL

---

## 📄 PHẦN 4: PRIVACY POLICY

- [ ] ⚠️ Có Privacy Policy URL công khai
- [ ] ⚠️ Privacy Policy mô tả đầy đủ:
  - [ ] Dữ liệu thu thập
  - [ ] Mục đích sử dụng
  - [ ] Cách bảo vệ dữ liệu
  - [ ] Quyền của người dùng
- [ ] ⚠️ Privacy Policy bằng tiếng Việt (hoặc ngôn ngữ phù hợp)
- [ ] ⚠️ Privacy Policy có thể truy cập công khai

---

## 🧪 PHẦN 5: TEST

### Android
- [ ] ⚠️ Build AAB thành công
- [ ] ⚠️ Test app trên thiết bị thật
- [ ] ⚠️ Test push notifications
- [ ] ⚠️ Test tất cả chức năng chính
- [ ] ⚠️ Test không có lỗi crash

### iOS
- [ ] ⚠️ Build IPA thành công
- [ ] ⚠️ Test app trên thiết bị thật
- [ ] ⚠️ Test push notifications
- [ ] ⚠️ Test tất cả chức năng chính
- [ ] ⚠️ Test không có lỗi crash
- [ ] ⚠️ Test permissions (Camera, Photo Library)

---

## 📦 PHẦN 6: BUILD VÀ UPLOAD

### Android (AAB)
- [ ] ⚠️ Build AAB: `flutter build appbundle --release`
- [ ] ⚠️ File AAB: `build/app/outputs/bundle/release/app-release.aab`
- [ ] ⚠️ Upload lên Google Play Console
- [ ] ⚠️ Chọn track: Internal Testing / Alpha / Beta / Production

### iOS (IPA)
- [ ] ⚠️ Mở Xcode: `open ios/Runner.xcworkspace`
- [ ] ⚠️ Chọn Team trong Signing & Capabilities
- [ ] ⚠️ Archive: Product → Archive
- [ ] ⚠️ Distribute App → App Store Connect
- [ ] ⚠️ Upload thành công

---

## ✅ PHẦN 7: SUBMIT

### Google Play Console
- [ ] ⚠️ Hoàn thiện tất cả thông tin
- [ ] ⚠️ Chọn build AAB
- [ ] ⚠️ Review lại tất cả
- [ ] ⚠️ Submit for Review

### App Store Connect
- [ ] ⚠️ Hoàn thiện tất cả thông tin
- [ ] ⚠️ Chọn build IPA
- [ ] ⚠️ Review lại tất cả
- [ ] ⚠️ Submit for Review

---

## 🎯 TỶ LỆ THÀNH CÔNG

### Hiện tại (sau khi sửa các vấn đề kỹ thuật):
- **Google Play**: 85-90%
- **Apple App Store**: 75-80%

### Sau khi hoàn thành tất cả checklist:
- **Google Play**: **90-95%** ✅
- **Apple App Store**: **85-90%** ✅

---

## 📚 TÀI LIỆU THAM KHẢO

- **Quy định mới nhất 2025**: Xem `QUY_DINH_MOI_NHAT_2025.md`
- **So sánh Android iOS**: Xem `SO_SANH_ANDROID_IOS.md`
- **Hướng dẫn Firebase iOS**: Xem `ios/HUONG_DAN_FIREBASE_IOS.md`
- **Hướng dẫn tạo IPA**: Xem `ios/CHUAN_BI_TAO_IPA.md`

---

## ⚠️ LƯU Ý QUAN TRỌNG

1. **Firebase iOS**: Phải có `GoogleService-Info.plist` trước khi build IPA
2. **Data Safety / App Privacy**: Phải khai báo đúng, nếu sai sẽ bị từ chối
3. **Privacy Policy**: Phải có URL công khai
4. **Thông tin nhà phát triển**: Bắt buộc công khai cho EU (Google Play)
5. **Test kỹ**: Test app trên thiết bị thật trước khi submit

---

**Chúc bạn submit thành công! 🎉**

