# 🔄 Hướng Dẫn Build Lại AAB (Update App)

## ⚠️ QUAN TRỌNG: Tăng Version Code

Trước khi build lại, **BẮT BUỘC** phải tăng **version code** (số sau dấu `+`) trong file `pubspec.yaml`.

### Tại sao?
- Google Play Store yêu cầu version code phải **LUÔN TĂNG** mỗi lần upload
- Nếu version code không tăng hoặc giảm, Play Store sẽ **TỪ CHỐI** upload

### Cách kiểm tra version code hiện tại trên Play Store:

1. Đăng nhập [Google Play Console](https://play.google.com/console)
2. Vào app của bạn
3. Vào **Production** → Xem version code của release mới nhất
4. Version code mới phải **LỚN HƠN** version code trên Play Store

### Ví dụ:
- Version trên Play Store: `1.0.0+1` (version code = 1)
- Version mới phải là: `1.0.0+2` hoặc `1.0.1+2` hoặc `1.1.0+2` (version code ≥ 2)

---

## 📝 Các Bước Build Lại AAB

### Bước 1: Tăng Version Code

Mở file `pubspec.yaml` và tìm dòng:
```yaml
version: 1.0.0+1
```

**Tăng số sau dấu `+` lên**, ví dụ:
```yaml
version: 1.0.0+2
```

Hoặc nếu có thay đổi lớn, tăng cả version name:
```yaml
version: 1.0.1+2
```

**Lưu file** sau khi sửa.

---

### Bước 2: Chạy Script Build

Mở Command Prompt/PowerShell và chạy:

```bash
cd C:\laragon\www\socdo_mobile
build_release.bat
```

Script sẽ:
- ✅ Kiểm tra keystore
- ✅ Hiển thị version hiện tại
- ✅ Clean build cũ
- ✅ Lấy dependencies
- ✅ Build AAB mới

**Thời gian**: 5-15 phút tùy máy tính

---

### Bước 3: Kiểm Tra File AAB

Sau khi build thành công, file AAB sẽ ở:
```
C:\laragon\www\socdo_mobile\build\app\outputs\bundle\release\app-release.aab
```

---

### Bước 4: Upload Lên Play Store

1. Đăng nhập [Google Play Console](https://play.google.com/console)
2. Vào app của bạn
3. Vào **Production** → **Create new release**
4. Upload file `app-release.aab`
5. Điền **Release notes** (mô tả các thay đổi)
6. Click **Save** → **Review release** → **Start rollout to Production**

---

## 🚀 Build Nhanh (Không cần script)

Nếu muốn build nhanh mà không dùng script:

```bash
cd C:\laragon\www\socdo_mobile
flutter clean
flutter pub get
flutter build appbundle --release
```

---

## ⚠️ Lưu Ý

1. **Version Code**: Phải tăng mỗi lần upload
2. **Keystore**: Dùng cùng keystore như lần trước (đã có sẵn)
3. **Release Notes**: Nên mô tả rõ các thay đổi để người dùng biết
4. **Testing**: Nên test app trên thiết bị thật trước khi upload

---

## 🆘 Xử Lý Lỗi

### Lỗi: "Version code already used"
**Nguyên nhân**: Version code đã được sử dụng trên Play Store

**Cách sửa**: Tăng version code trong `pubspec.yaml` lên số lớn hơn

### Lỗi: "Keystore not found"
**Nguyên nhân**: File keystore bị mất hoặc đường dẫn sai

**Cách sửa**: Kiểm tra file `android/app/upload-keystore.jks` có tồn tại không

---

## 📋 Checklist Trước Khi Upload

- [ ] Đã tăng version code trong `pubspec.yaml`
- [ ] Đã test app trên thiết bị thật
- [ ] Đã build AAB thành công
- [ ] Đã chuẩn bị release notes
- [ ] Đã kiểm tra version code trên Play Store

---

**Chúc bạn update thành công! 🎉**

