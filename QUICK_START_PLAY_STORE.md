RR# 🚀 QUICK START - PUBLISH LÊN PLAY STORE

## Các bước nhanh để publish app lên Google Play Store

### 1️⃣ Tạo Keystore (Chỉ làm 1 lần)

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

**Lưu lại mật khẩu cẩn thận!** Nếu mất sẽ không thể update app.

---

### 2️⃣ Cấu hình Keystore

```bash
# Copy file example
cd android
copy keystore.properties.example keystore.properties  # Windows
# hoặc
cp keystore.properties.example keystore.properties       # Linux/Mac
```

Mở `android/keystore.properties` và điền:
```properties
storePassword=MAT_KHAU_CUA_BAN
keyPassword=MAT_KHAU_CUA_BAN
keyAlias=upload
storeFile=app/upload-keystore.jks
```

---

### 3️⃣ Build AAB

**Windows:**
```bash
build_release.bat
```

**Linux/Mac:**
```bash
chmod +x build_release.sh
./build_release.sh
```

**Hoặc thủ công:**
```bash
flutter build appbundle --release
```

File AAB: `build/app/outputs/bundle/release/app-release.aab`

---

### 4️⃣ Tạo App trên Play Console

1. Đăng nhập: https://play.google.com/console
2. Click **"Create app"**
3. Điền thông tin cơ bản
4. Hoàn thiện các mục:
   - ✅ App access
   - ✅ Ads
   - ✅ Content rating
   - ✅ Target audience
   - ✅ **Data safety** (QUAN TRỌNG!)
   - ✅ App content

---

### 5️⃣ Upload và Publish

1. Vào **Production** → **Create new release**
2. Upload file `app-release.aab`
3. Điền release notes
4. Click **"Start rollout to Production"**

---

## ⚠️ LƯU Ý QUAN TRỌNG

- **Keystore**: Lưu giữ cẩn thận, không được mất!
- **Version Code**: Phải tăng mỗi lần update (1, 2, 3, ...)
- **Data Safety**: Khai báo chính xác, nếu không app sẽ bị từ chối
- **Review Time**: Lần đầu có thể mất 1-7 ngày

---

## 📚 Xem hướng dẫn chi tiết

Xem file `HUONG_DAN_PUBLISH_PLAY_STORE.md` để biết chi tiết từng bước.

---

**Thông tin App hiện tại:**
- **App ID**: `com.socdo.mobile`
- **Version**: `1.0.0+1`
- **App Name**: `Socdo`

