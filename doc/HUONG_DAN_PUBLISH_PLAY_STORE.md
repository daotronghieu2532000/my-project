# HƯỚNG DẪN PUBLISH APP LÊN GOOGLE PLAY STORE

## 📋 MỤC LỤC
1. [Chuẩn bị](#chuẩn-bị)
2. [Tạo Keystore](#tạo-keystore)
3. [Cấu hình Signing](#cấu-hình-signing)
4. [Build App Bundle (AAB)](#build-app-bundle-aab)
5. [Tạo App trên Google Play Console](#tạo-app-trên-google-play-console)
6. [Upload và Publish](#upload-và-publish)
7. [Cập nhật App](#cập-nhật-app)

---

## 🔧 CHUẨN BỊ

### Yêu cầu:
- ✅ Đã có tài khoản Google Play Console (đã có)
- ✅ Đã cài đặt Flutter SDK
- ✅ Đã cài đặt Java JDK (để tạo keystore)
- ✅ Đã cấu hình Firebase (đã có file `google-services.json`)

### Thông tin App hiện tại:
- **Application ID**: `com.socdo.mobile`
- **App Name**: `Socdo`
- **Version**: `1.0.0+1` (từ `pubspec.yaml`)

---

## 🔐 TẠO KEYSTORE

Keystore là file quan trọng để ký (sign) app. **LƯU Ý**: Nếu mất keystore, bạn sẽ KHÔNG THỂ cập nhật app lên Play Store!

### Cách 1: Dùng Script (Khuyến nghị)

**Windows:**
```bash
cd android
create_keystore.bat
```

**Linux/Mac:**
```bash
cd android
chmod +x create_keystore.sh
./create_keystore.sh
```

### Cách 2: Tạo thủ công

```bash
cd android/app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Thông tin cần nhập:**
- **First and last name**: Tên của bạn hoặc tên công ty
- **Organizational Unit**: Bộ phận (có thể để trống)
- **Organization**: Tên công ty
- **City**: Thành phố
- **State**: Tỉnh/Thành phố
- **Country code**: VN (cho Việt Nam)
- **Password**: Nhập mật khẩu (LƯU LẠI CẨN THẬN!)
- **Re-enter password**: Nhập lại mật khẩu

**LƯU Ý**: Mật khẩu keystore và key password phải **GIỐNG NHAU** (theo yêu cầu của Google Play).

---

## ⚙️ CẤU HÌNH SIGNING

### Bước 1: Tạo file `keystore.properties`

```bash
# Copy file example
cd android
copy keystore.properties.example keystore.properties
```

### Bước 2: Điền thông tin vào `keystore.properties`

Mở file `android/keystore.properties` và điền thông tin:

```properties
storePassword=MAT_KHAU_BAN_VUA_NHAP
keyPassword=MAT_KHAU_BAN_VUA_NHAP
keyAlias=upload
storeFile=app/upload-keystore.jks
```

**LƯU Ý**: 
- Thay `MAT_KHAU_BAN_VUA_NHAP` bằng mật khẩu bạn đã nhập khi tạo keystore
- File này đã được thêm vào `.gitignore` nên sẽ KHÔNG bị commit lên Git

### Bước 3: Kiểm tra cấu hình

File `android/app/build.gradle.kts` đã được cấu hình sẵn để đọc `keystore.properties` và tự động sign app khi build release.

---

## 📦 BUILD APP BUNDLE (AAB)

Google Play Store yêu cầu file **AAB (Android App Bundle)** thay vì APK.

### Build AAB:

```bash
flutter build appbundle --release
```

File AAB sẽ được tạo tại: `build/app/outputs/bundle/release/app-release.aab`

### Kiểm tra kích thước file:

```bash
# Windows
dir build\app\outputs\bundle\release\app-release.aab

# Linux/Mac
ls -lh build/app/outputs/bundle/release/app-release.aab
```

**LƯU Ý**: 
- File AAB thường nhỏ hơn APK khoảng 15-20%
- Google Play sẽ tự động tạo APK tối ưu cho từng thiết bị

---

## 🎯 TẠO APP TRÊN GOOGLE PLAY CONSOLE

### Bước 1: Đăng nhập Google Play Console

Truy cập: https://play.google.com/console

### Bước 2: Tạo App mới

1. Click **"Create app"**
2. Điền thông tin:
   - **App name**: `Socdo` (hoặc tên bạn muốn)
   - **Default language**: Vietnamese (hoặc English)
   - **App or game**: Chọn **App**
   - **Free or paid**: Chọn **Free** (hoặc Paid nếu bạn muốn)
   - **Declarations**: Đồng ý với các điều khoản
3. Click **"Create app"**

### Bước 3: Hoàn thiện thông tin App

#### 3.1. App access
- Chọn **"All functionality is available without restrictions"** (hoặc tùy chọn phù hợp)

#### 3.2. Ads
- Chọn **"No"** nếu app không có quảng cáo
- Chọn **"Yes"** nếu app có quảng cáo

#### 3.3. Content rating
- Điền form đánh giá nội dung
- Google sẽ tự động đánh giá dựa trên thông tin bạn cung cấp

#### 3.4. Target audience
- Chọn độ tuổi mục tiêu
- Chọn **"Designed for families"** nếu phù hợp

#### 3.5. Data safety
- Khai báo các dữ liệu app thu thập và sử dụng
- **QUAN TRỌNG**: Phải khai báo chính xác, nếu không app có thể bị từ chối

#### 3.6. App content
- **App category**: Chọn danh mục phù hợp (ví dụ: Shopping, Social, etc.)
- **Tags**: Thêm các tag liên quan

---

## 📤 UPLOAD VÀ PUBLISH

### Bước 1: Tạo Release

1. Vào **"Production"** (hoặc **"Testing"** để test trước)
2. Click **"Create new release"**

### Bước 2: Upload AAB

1. Click **"Upload"** và chọn file `app-release.aab`
2. Đợi Google Play xử lý (có thể mất vài phút)
3. Kiểm tra kết quả:
   - ✅ **No errors**: Có thể tiếp tục
   - ❌ **Errors**: Sửa lỗi trước khi tiếp tục

### Bước 3: Điền Release notes

- **Release name**: `1.0.0` (hoặc version hiện tại)
- **Release notes**: Mô tả các tính năng mới, sửa lỗi, cải tiến

**Ví dụ:**
```
Phiên bản 1.0.0 - Phát hành lần đầu
- Tính năng mua sắm trực tuyến
- Hệ thống đăng nhập/đăng ký
- Quản lý đơn hàng
- Chat với shop
- Hệ thống affiliate
```

### Bước 4: Review và Publish

1. Review lại tất cả thông tin
2. Click **"Save"** để lưu release
3. Click **"Review release"** để xem lại
4. Click **"Start rollout to Production"** để publish

**LƯU Ý**: 
- Lần đầu publish có thể mất **1-7 ngày** để Google review
- Sau khi được duyệt, app sẽ xuất hiện trên Play Store trong vài giờ

---

## 🔄 CẬP NHẬT APP

### Bước 1: Tăng Version

Cập nhật trong `pubspec.yaml`:

```yaml
version: 1.0.1+2  # 1.0.1 là versionName, 2 là versionCode
```

**LƯU Ý**:
- `versionCode` (số sau dấu +) phải **TĂNG** mỗi lần update
- `versionName` (số trước dấu +) có thể tăng theo ý bạn (1.0.1, 1.1.0, 2.0.0, etc.)

### Bước 2: Build AAB mới

```bash
flutter build appbundle --release
```

### Bước 3: Upload lên Play Console

1. Vào **"Production"** → **"Create new release"**
2. Upload file AAB mới
3. Điền release notes
4. Publish

---

## ✅ CHECKLIST TRƯỚC KHI PUBLISH

- [ ] Đã tạo keystore và cấu hình `keystore.properties`
- [ ] Đã build AAB thành công
- [ ] Đã tạo app trên Google Play Console
- [ ] Đã hoàn thiện tất cả thông tin app (App access, Ads, Content rating, etc.)
- [ ] Đã khai báo Data safety chính xác
- [ ] Đã upload AAB lên Play Console
- [ ] Đã điền release notes
- [ ] Đã kiểm tra lại tất cả thông tin
- [ ] Đã sẵn sàng chờ Google review

---

## 🆘 XỬ LÝ LỖI THƯỜNG GẶP

### Lỗi: "Keystore file not found"
- Kiểm tra đường dẫn trong `keystore.properties`
- Đảm bảo file keystore tồn tại tại `android/app/upload-keystore.jks`

### Lỗi: "Wrong password"
- Kiểm tra lại mật khẩu trong `keystore.properties`
- Đảm bảo `storePassword` và `keyPassword` giống nhau

### Lỗi: "Version code already used"
- Tăng `versionCode` trong `pubspec.yaml`
- Build lại AAB

### Lỗi: "App rejected by Google"
- Đọc kỹ email từ Google để biết lý do
- Thường gặp: Data safety không chính xác, Content rating sai, Policy violation
- Sửa lỗi và submit lại

---

## 📞 HỖ TRỢ

Nếu gặp vấn đề, tham khảo:
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Flutter Documentation](https://flutter.dev/docs/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)

---

**Chúc bạn publish thành công! 🎉**

