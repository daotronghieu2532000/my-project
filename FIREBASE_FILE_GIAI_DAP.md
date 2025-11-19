# 🔥 GIẢI ĐÁP VỀ FILE FIREBASE

## ❓ CÂU HỎI

**"File Firebase có phải là cái tôi đang dùng cho Android mục đích thông báo app đến điện thoại đúng không? Hình như nó có trong dự án rồi mà."**

---

## ✅ TRẢ LỜI

### 1. File Firebase cho Android
- ✅ **ĐÚNG**: File `google-services.json` dùng cho **Firebase Cloud Messaging** (push notifications)
- ✅ **ĐÃ CÓ**: File `android/app/google-services.json` đã có trong dự án
- ✅ **Mục đích**: Thông báo app đến điện thoại (push notifications)

### 2. File Firebase cho iOS
- ⚠️ **CHƯA CÓ**: File `GoogleService-Info.plist` chưa có trong dự án
- ✅ **Cùng mục đích**: Cũng dùng cho **Firebase Cloud Messaging** (push notifications)
- ✅ **Cùng project**: Cùng Firebase project `socdomobile` với Android

---

## 📋 SO SÁNH

| Platform | File | Vị trí | Trạng thái | Mục đích |
|----------|------|--------|------------|----------|
| **Android** | `google-services.json` | `android/app/google-services.json` | ✅ Đã có | Push notifications |
| **iOS** | `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` | ❌ Chưa có | Push notifications |

---

## 🔧 CÁCH LẤY FILE FIREBASE CHO iOS

### Bước 1: Truy cập Firebase Console
1. Vào: https://console.firebase.google.com/
2. Đăng nhập bằng tài khoản Google
3. Chọn project: **`socdomobile`** (cùng project với Android)

### Bước 2: Tải file
1. Vào **Project Settings** (⚙️)
2. Scroll xuống phần **"Your apps"**
3. Tìm app iOS (hoặc tạo mới nếu chưa có)
4. **Bundle ID iOS**: `com.socdo.mobile` (phải giống với Android package name)
5. Click **"Download GoogleService-Info.plist"**

### Bước 3: Thêm vào project
1. Copy file vào: `ios/Runner/GoogleService-Info.plist`
2. Mở Xcode: `open ios/Runner.xcworkspace`
3. Kéo file vào project trong Xcode
4. ✅ Tích "Copy items if needed"
5. ✅ Tích "Add to targets: Runner"

**Chi tiết:** Xem `ios/HUONG_DAN_FIREBASE_IOS.md`

---

## ✅ KẾT LUẬN

- ✅ **Android**: Đã có file Firebase → Push notifications hoạt động
- ⚠️ **iOS**: Chưa có file Firebase → Cần thêm để push notifications hoạt động
- ✅ **Cùng mục đích**: Cả hai file đều dùng cho push notifications
- ✅ **Cùng project**: Cùng Firebase project `socdomobile`

**Sau khi thêm file Firebase cho iOS, push notifications sẽ hoạt động trên cả hai platform! 🎉**

