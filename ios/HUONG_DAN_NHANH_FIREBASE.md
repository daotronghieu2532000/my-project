# ⚡ HƯỚNG DẪN NHANH - LẤY FIREBASE CHO iOS

## 📋 THÔNG TIN CẦN ĐIỀN (Bạn đang ở bước này)

### ✅ Thông tin đã điền đúng:
1. **ID gói Apple**: `com.socdo.mobile` ✅ **ĐÚNG RỒI**
2. **Tên người dùng ứng dụng**: `Socdo` ✅ **OK**

### ⚠️ Cần sửa:
3. **ID App Store**: `123456789` 
   - ⚠️ Đây là số mẫu, **XÓA ĐI** hoặc để trống
   - ✅ Chỉ cần điền sau khi app đã publish lên App Store

---

## 🚀 CÁC BƯỚC TIẾP THEO

### Bước 1: Sửa và đăng ký
1. **Xóa hoặc để trống** trường "ID App Store" (xóa số `123456789`)
2. **Click nút "Đăng ký ứng dụng"** (màu xanh)
3. Chờ vài giây để Firebase xử lý

### Bước 2: Tải file GoogleService-Info.plist
1. Sau khi đăng ký xong, **bước 2 sẽ mở ra**
2. Tìm nút **"Tải xuống GoogleService-Info.plist"**
3. **Click để tải file**
4. File sẽ được tải về (thường ở thư mục Downloads)

### Bước 3: Thêm file vào Xcode
1. **Mở Xcode:**
   ```bash
   cd C:\laragon\www\socdo_mobile
   open ios/Runner.xcworkspace
   ```
   ⚠️ **QUAN TRỌNG**: Phải mở `.xcworkspace`, KHÔNG phải `.xcodeproj`

2. **Kéo file vào project:**
   - Tìm file `GoogleService-Info.plist` vừa tải về
   - Trong Xcode, kéo file vào thư mục **"Runner"** (sidebar trái)
   - Hộp thoại hiện ra:
     - ✅ Tích **"Copy items if needed"**
     - ✅ Tích **"Add to targets: Runner"**
     - Click **"Finish"**

3. **Kiểm tra:**
   - File `GoogleService-Info.plist` xuất hiện trong thư mục "Runner"
   - Click vào file → Kiểm tra "Target Membership" có tích "Runner"

---

## ✅ XONG!

Sau khi thêm file:
- ✅ Firebase hoạt động trên iOS
- ✅ Push notifications hoạt động (giống Android)
- ✅ Cùng project Firebase với Android

**Bạn có thể bỏ qua các bước 3, 4, 5** trong Firebase Console vì Flutter đã tự động xử lý.

---

## 📝 TÓM TẮT

1. ✅ Xóa ID App Store (để trống)
2. ✅ Click "Đăng ký ứng dụng"
3. ✅ Tải file `GoogleService-Info.plist`
4. ✅ Thêm file vào Xcode project

**Xong! 🎉**

