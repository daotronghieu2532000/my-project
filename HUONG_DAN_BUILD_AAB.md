# Hướng Dẫn Tạo AAB Cho Google Play Store

## Tổng Quan

File AAB (Android App Bundle) là định dạng yêu cầu để upload ứng dụng lên Google Play Store. File này nhỏ hơn APK và Google Play sẽ tự động tạo APK tối ưu cho từng thiết bị.

## Các Bước Thực Hiện

### Bước 1: Kiểm Tra Keystore

Đảm bảo bạn đã có:
- ✅ File keystore: `android/app/upload-keystore.jks`
- ✅ File cấu hình: `android/keystore.properties`

**Nếu chưa có keystore:**
1. Chạy script: `android\create_keystore.bat`
2. Nhập thông tin khi được yêu cầu
3. **QUAN TRỌNG**: Lưu giữ mật khẩu và keystore file cẩn thận - nếu mất sẽ không thể update app!

### Bước 2: Kiểm Tra Version

Mở file `pubspec.yaml` và kiểm tra version:
```yaml
version: 1.0.0+1
```

- **Version name** (1.0.0): Hiển thị cho người dùng
- **Version code** (+1): Phải tăng mỗi lần upload lên Play Store

**Lưu ý**: Mỗi lần upload lên Play Store, version code phải lớn hơn lần trước.

### Bước 3: Build AAB

Có 2 cách:

#### Cách 1: Sử dụng Script (Khuyến nghị)
```bash
build_release.bat
```

Script này sẽ:
- Kiểm tra keystore và cấu hình
- Clean build cũ
- Lấy dependencies
- Build AAB release

#### Cách 2: Build thủ công
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Bước 4: Tìm File AAB

Sau khi build thành công, file AAB sẽ ở:
```
build\app\outputs\bundle\release\app-release.aab
```

## Upload Lên Google Play Store

### Bước 1: Đăng nhập Google Play Console
Truy cập: https://play.google.com/console

### Bước 2: Tạo App (nếu chưa có)
1. Click **Create app**
2. Điền thông tin:
   - App name: Socdo Mobile
   - Default language: Tiếng Việt
   - App or game: App
   - Free or paid: Chọn theo nhu cầu
3. Click **Create**

### Bước 3: Hoàn Thiện Thông Tin App
Trước khi upload, cần hoàn thiện:
- **Store listing**: Mô tả, ảnh, icon, screenshots
- **Content rating**: Đánh giá nội dung
- **Privacy policy**: Chính sách bảo mật (bắt buộc)
- **App access**: Quyền truy cập

### Bước 4: Upload AAB
1. Vào **Production** (hoặc **Testing** > **Internal testing**)
2. Click **Create new release**
3. Upload file `app-release.aab`
4. Điền **Release notes** (ghi chú phiên bản)
5. Click **Save** > **Review release** > **Start rollout to Production**

### Bước 5: Review và Publish
- Google sẽ review app (thường 1-7 ngày)
- Sau khi được duyệt, app sẽ xuất hiện trên Play Store

## Lưu Ý Quan Trọng

### Về Keystore
- ⚠️ **KHÔNG BAO GIỜ** mất keystore file và mật khẩu
- ⚠️ Nếu mất keystore, bạn sẽ **KHÔNG THỂ** update app lên Play Store
- ✅ Backup keystore ở nhiều nơi an toàn
- ✅ Lưu mật khẩu trong password manager

### Về Version Code
- Mỗi lần upload, version code phải tăng
- Ví dụ: Lần 1 là `+1`, lần 2 phải là `+2`, `+3`, ...
- Version code không thể giảm

### Về Signing
- App phải được ký bằng cùng một keystore mỗi lần
- File `keystore.properties` đã được cấu hình tự động
- Không cần thay đổi gì nếu đã setup đúng

## Troubleshooting

### Lỗi: "Keystore file not found"
- Kiểm tra file `android/app/upload-keystore.jks` có tồn tại không
- Nếu chưa có, chạy `android\create_keystore.bat`

### Lỗi: "Keystore properties not found"
- Kiểm tra file `android/keystore.properties` có tồn tại không
- Copy từ `android/keystore.properties.example` và điền thông tin

### Lỗi: "Version code already used"
- Tăng version code trong `pubspec.yaml`
- Ví dụ: từ `1.0.0+1` thành `1.0.0+2`

### Lỗi Build
- Chạy `flutter clean` và build lại
- Kiểm tra lỗi trong console
- Đảm bảo đã cài đặt đầy đủ Flutter SDK và Android SDK

## Checklist Trước Khi Upload

- [ ] Keystore đã được tạo và backup
- [ ] `keystore.properties` đã được cấu hình đúng
- [ ] Version code đã được tăng (nếu là update)
- [ ] Đã test app trên thiết bị thật
- [ ] Đã build AAB thành công
- [ ] Đã chuẩn bị screenshots, mô tả, icon cho Play Store
- [ ] Đã có Privacy Policy URL
- [ ] Đã hoàn thiện thông tin app trong Play Console

## Liên Kết Hữu Ích

- [Google Play Console](https://play.google.com/console)
- [Flutter Build Documentation](https://docs.flutter.dev/deployment/android)
- [Android App Bundle Guide](https://developer.android.com/guide/app-bundle)
- [Play Store Policies](https://play.google.com/about/developer-content-policy/)

