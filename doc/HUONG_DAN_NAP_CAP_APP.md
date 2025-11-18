# 🔄 HƯỚNG DẪN NÂNG CẤP APP LÊN GOOGLE PLAY STORE

## Khi nào cần nâng cấp app?

- Thêm tính năng mới
- Sửa lỗi (bug fixes)
- Cải thiện hiệu suất
- Cập nhật giao diện
- Thêm ngôn ngữ mới
- Cập nhật dependencies

---

## 📋 QUY TRÌNH NÂNG CẤP APP

### Bước 1: Tăng Version trong pubspec.yaml

⚠️ **QUAN TRỌNG**: Mỗi lần nâng cấp, bạn PHẢI tăng version!

**Cách làm:**

1. Mở file `pubspec.yaml` (ở thư mục gốc dự án)

2. Tìm dòng `version:` (thường ở dòng 19)

3. Tăng version theo quy tắc:
   ```yaml
   version: 1.0.0+1  # Version hiện tại
   ```
   
   **Quy tắc tăng version:**
   - Số trước dấu `+` là **versionName** (hiển thị cho người dùng)
   - Số sau dấu `+` là **versionCode** (phải TĂNG mỗi lần update)
   
   **Ví dụ:**
   ```yaml
   # Lần đầu: 1.0.0+1
   # Lần 2 (sửa lỗi nhỏ): 1.0.1+2
   # Lần 3 (thêm tính năng): 1.1.0+3
   # Lần 4 (sửa lỗi): 1.1.1+4
   # Lần 5 (cập nhật lớn): 2.0.0+5
   ```

4. **Lưu file** (`Ctrl + S`)

**Lưu ý:**
- `versionCode` (số sau dấu `+`) **PHẢI TĂNG** mỗi lần (1 → 2 → 3 → 4...)
- `versionCode` **KHÔNG ĐƯỢC** giảm hoặc giữ nguyên
- `versionName` (số trước dấu `+`) có thể tăng theo ý bạn

---

### Bước 2: Build AAB mới

Sau khi tăng version, build lại AAB:

**Cách 1: Dùng Script (Khuyến nghị)**

1. Mở Command Prompt
2. Di chuyển vào thư mục dự án:
   ```bash
   cd C:\laragon\www\socdo_mobile
   ```
3. Chạy script:
   ```bash
   build_release.bat
   ```

**Cách 2: Build thủ công**

1. Mở Command Prompt
2. Di chuyển vào thư mục dự án:
   ```bash
   cd C:\laragon\www\socdo_mobile
   ```
3. Clean build cũ (tùy chọn):
   ```bash
   flutter clean
   ```
4. Lấy dependencies:
   ```bash
   flutter pub get
   ```
5. Build AAB:
   ```bash
   flutter build appbundle --release
   ```

**Kết quả:**
- File AAB mới sẽ được tạo tại:
  ```
  C:\laragon\www\socdo_mobile\build\app\outputs\bundle\release\app-release.aab
  ```

---

### Bước 3: Upload AAB mới lên Google Play Console

1. **Đăng nhập Google Play Console**
   - Truy cập: https://play.google.com/console
   - Đăng nhập bằng tài khoản nhà phát triển

2. **Chọn app cần nâng cấp**
   - Click vào app của bạn trong danh sách

3. **Vào Production (hoặc Testing)**
   - Trong menu bên trái, click **"Production"** (hoặc **"Testing"** nếu muốn test trước)

4. **Tạo Release mới**
   - Click nút **"Create new release"** (màu xanh)

5. **Upload file AAB mới**
   - Click nút **"Upload"**
   - Chọn file AAB mới: `C:\laragon\www\socdo_mobile\build\app\outputs\bundle\release\app-release.aab`
   - Đợi Google Play xử lý (2-5 phút)

6. **Kiểm tra kết quả**
   - ✅ **No errors**: Có thể tiếp tục
   - ❌ **Errors**: Đọc lỗi và sửa
     - Thường gặp: "Version code already used" → Tăng version code trong `pubspec.yaml` và build lại

---

### Bước 4: Điền Release Notes

1. **Release name**: Nhập version mới (ví dụ: `1.0.1`)

2. **Release notes**: Mô tả những gì đã thay đổi

**Ví dụ Release Notes:**

```
Phiên bản 1.0.1

Cải thiện:
- Sửa lỗi đăng nhập
- Cải thiện hiệu suất tải trang
- Tối ưu hóa bộ nhớ

Tính năng mới:
- Thêm tính năng tìm kiếm nâng cao
- Thêm hỗ trợ ngôn ngữ tiếng Anh

Sửa lỗi:
- Sửa lỗi crash khi mở app
- Sửa lỗi hiển thị hình ảnh
```

**Lưu ý:**
- Viết bằng tiếng Việt hoặc tiếng Anh (tùy app của bạn)
- Mô tả rõ ràng, dễ hiểu
- Người dùng sẽ thấy release notes này trên Play Store

---

### Bước 5: Review và Publish

1. **Review lại thông tin**
   - ✅ File AAB đã upload thành công
   - ✅ Version code đã tăng
   - ✅ Release notes đã điền
   - ✅ Không có lỗi

2. **Lưu Release**
   - Click nút **"Save"** (ở cuối trang)

3. **Review Release**
   - Click nút **"Review release"** để xem lại

4. **Publish**
   - Nếu mọi thứ OK, click nút **"Start rollout to Production"** (màu xanh)

5. **Chờ Google Review**
   - Lần đầu: 1-7 ngày
   - Các lần sau: 1-3 ngày (thường nhanh hơn)

---

## ⚠️ LƯU Ý QUAN TRỌNG

### 1. Version Code PHẢI TĂNG

❌ **SAI:**
```yaml
version: 1.0.0+1  # Lần đầu
version: 1.0.1+1  # Lần 2 - SAI! Version code không tăng
```

✅ **ĐÚNG:**
```yaml
version: 1.0.0+1  # Lần đầu
version: 1.0.1+2  # Lần 2 - ĐÚNG! Version code đã tăng
```

### 2. Không được giảm Version Code

❌ **SAI:**
```yaml
version: 1.0.0+5  # Lần trước
version: 1.0.1+3  # Lần này - SAI! Version code giảm
```

✅ **ĐÚNG:**
```yaml
version: 1.0.0+5  # Lần trước
version: 1.0.1+6  # Lần này - ĐÚNG! Version code tăng
```

### 3. Keystore phải giống nhau

- **QUAN TRỌNG**: Mỗi lần build AAB, phải dùng **CÙNG MỘT** keystore
- File `keystore.properties` đã được cấu hình sẵn, không cần thay đổi
- Nếu dùng keystore khác → Google Play sẽ từ chối

### 4. Release Notes

- Viết rõ ràng, dễ hiểu
- Người dùng sẽ đọc release notes trước khi update
- Release notes tốt giúp tăng tỷ lệ update

---

## 📊 VÍ DỤ QUY TRÌNH NÂNG CẤP

### Lần 1: Phát hành lần đầu
- Version: `1.0.0+1`
- Release notes: "Phiên bản 1.0.0 - Phát hành lần đầu"

### Lần 2: Sửa lỗi nhỏ
- Version: `1.0.1+2`
- Release notes: "Sửa lỗi đăng nhập và cải thiện hiệu suất"

### Lần 3: Thêm tính năng
- Version: `1.1.0+3`
- Release notes: "Thêm tính năng chat và cải thiện giao diện"

### Lần 4: Sửa lỗi
- Version: `1.1.1+4`
- Release notes: "Sửa lỗi crash và tối ưu hóa bộ nhớ"

### Lần 5: Cập nhật lớn
- Version: `2.0.0+5`
- Release notes: "Phiên bản 2.0 - Thiết kế lại giao diện và thêm nhiều tính năng mới"

---

## 🆘 XỬ LÝ LỖI THƯỜNG GẶP

### ❌ Lỗi: "Version code already used"

**Nguyên nhân**: Version code đã được sử dụng trước đó

**Cách sửa:**
1. Mở file `pubspec.yaml`
2. Tăng version code (số sau dấu `+`)
3. Build lại AAB
4. Upload lại

**Ví dụ:**
```yaml
# Trước: version: 1.0.1+2
# Sau:   version: 1.0.1+3  # Tăng từ 2 lên 3
```

### ❌ Lỗi: "App rejected by Google"

**Nguyên nhân**: App vi phạm chính sách của Google

**Cách sửa:**
1. Đọc kỹ email từ Google để biết lý do
2. Sửa lỗi (thường là Data safety, Content rating, Policy violation)
3. Build lại AAB
4. Upload lại

---

## ✅ CHECKLIST NÂNG CẤP APP

Trước khi upload:

- [ ] Đã tăng version trong `pubspec.yaml`
- [ ] Version code (số sau dấu `+`) đã tăng
- [ ] Đã build AAB mới thành công
- [ ] File AAB mới có version code mới
- [ ] Đã chuẩn bị release notes
- [ ] Đã kiểm tra app hoạt động tốt
- [ ] Đã test trên thiết bị thật (nếu có thể)

---

## 📚 TÀI LIỆU THAM KHẢO

- **Hướng dẫn publish lần đầu**: Xem file `QUICK_START_PLAY_STORE.md`
- **Hướng dẫn chi tiết**: Xem file `HUONG_DAN_PUBLISH_PLAY_STORE.md`
- **Google Play Console Help**: https://support.google.com/googleplay/android-developer

---

**Tóm lại: Mỗi lần nâng cấp app, bạn cần:**
1. ✅ Tăng version trong `pubspec.yaml`
2. ✅ Build lại AAB
3. ✅ Upload AAB mới lên Play Console
4. ✅ Điền release notes
5. ✅ Publish

**Chúc bạn nâng cấp thành công! 🎉**

