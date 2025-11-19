# 🔥 HƯỚNG DẪN CHI TIẾT - LẤY FIREBASE CHO iOS

## 📋 THÔNG TIN CẦN ĐIỀN TRONG FIREBASE CONSOLE

### Bước 1: Đăng ký ứng dụng (Register app)

Bạn đang ở bước này. Thông tin cần điền:

#### 1. ID gói Apple (Apple bundle ID)
- ✅ **Giá trị**: `com.socdo.mobile`
- ✅ **Đã điền đúng**: Khớp với Bundle ID trong Xcode project
- ⚠️ **Lưu ý**: Phải chính xác 100%, không được sai

#### 2. Tên người dùng ứng dụng (App nickname) - TÙY CHỌN
- ✅ **Giá trị**: `Socdo` (hoặc để mặc định)
- ℹ️ **Mục đích**: Chỉ để phân biệt trong Firebase Console   
- ✅ **Có thể để**: `Socdo` hoặc `Socdo iOS`

#### 3. ID App Store (App Store ID) - TÙY CHỌN
- ⚠️ **Giá trị hiện tại**: `123456789` (có thể là số mẫu)
- ✅ **Nếu chưa có App Store ID**: Để trống hoặc xóa số này
- ℹ️ **Khi nào cần**: Chỉ cần điền sau khi app đã được publish lên App Store
- ✅ **Bây giờ**: Có thể để trống hoặc xóa

---

## ✅ CÁC BƯỚC TIẾP THEO

### Bước 1: Điền thông tin và đăng ký

1. **Kiểm tra lại thông tin:**
   - ✅ ID gói Apple: `com.socdo.mobile`
   - ✅ Tên ứng dụng: `Socdo` (hoặc để mặc định)
   - ⚠️ ID App Store: Xóa hoặc để trống (nếu chưa có)

2. **Click nút "Đăng ký ứng dụng" (Register app)**
   - Firebase sẽ tạo app iOS trong project
   - Chờ vài giây để xử lý

---

### Bước 2: Tải xuống tệp cấu hình (Download configuration file)

Sau khi đăng ký xong, bạn sẽ thấy bước 2:

1. **Click vào bước 2**: "Tải xuống tệp cấu hình"
2. **Tìm nút "Tải xuống GoogleService-Info.plist"** (Download GoogleService-Info.plist)
3. **Click để tải file**
4. **Lưu file**: File sẽ được tải về với tên `GoogleService-Info.plist`

---

### Bước 3: Thêm file vào Xcode Project

#### Cách 1: Dùng Xcode (Khuyến nghị)

1. **Mở Xcode:**
   ```bash
   cd C:\laragon\www\socdo_mobile
   open ios/Runner.xcworkspace
   ```
   ⚠️ **LƯU Ý**: Phải mở file `.xcworkspace`, KHÔNG phải `.xcodeproj`

2. **Kéo file vào project:**
   - Tìm file `GoogleService-Info.plist` vừa tải về (thường ở Downloads)
   - Trong Xcode, tìm thư mục **"Runner"** ở sidebar trái
   - Kéo file `GoogleService-Info.plist` vào thư mục **"Runner"** trong Xcode
   - Hộp thoại sẽ hiện ra:
     - ✅ Tích vào **"Copy items if needed"**
     - ✅ Đảm bảo **"Add to targets: Runner"** được chọn
     - Click **"Finish"**

3. **Kiểm tra:**
   - File `GoogleService-Info.plist` sẽ xuất hiện trong thư mục **"Runner"**
   - Click vào file, kiểm tra trong **"Target Membership"** có tích **"Runner"**

#### Cách 2: Copy trực tiếp (Nếu không dùng Xcode ngay)

1. **Copy file:**
   - Copy file `GoogleService-Info.plist` từ Downloads
   - Paste vào: `C:\laragon\www\socdo_mobile\ios\Runner\GoogleService-Info.plist`

2. **Thêm vào Xcode sau:**
   - Mở Xcode: `open ios/Runner.xcworkspace`
   - Right-click vào thư mục **"Runner"** → **"Add Files to Runner..."**
   - Chọn file `GoogleService-Info.plist`
   - ✅ Tích **"Copy items if needed"**
   - ✅ Tích **"Add to targets: Runner"**
   - Click **"Add"**

---

### Bước 4: Kiểm tra cấu hình

1. **Mở file GoogleService-Info.plist trong Xcode:**
   - Click vào file `GoogleService-Info.plist` trong Xcode
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

## ⚠️ LƯU Ý QUAN TRỌNG

### 1. App Store ID
- **Nếu chưa có**: Để trống hoặc xóa số `123456789`
- **Khi nào cần**: Chỉ cần điền sau khi app đã được publish lên App Store
- **Không ảnh hưởng**: Việc để trống không ảnh hưởng đến push notifications

### 2. Bundle ID
- **Phải chính xác**: `com.socdo.mobile`
- **Không được sai**: Nếu sai, push notifications sẽ không hoạt động

### 3. File GoogleService-Info.plist
- **Phải thêm vào Xcode project**: Không chỉ copy vào thư mục
- **Phải có trong Target Membership**: Phải tích "Runner"

---

## ✅ CHECKLIST

- [ ] Đã điền ID gói Apple: `com.socdo.mobile`
- [ ] Đã điền tên ứng dụng: `Socdo` (hoặc để mặc định)
- [ ] Đã xóa/để trống ID App Store (nếu chưa có)
- [ ] Đã click "Đăng ký ứng dụng"
- [ ] Đã tải file `GoogleService-Info.plist`
- [ ] Đã thêm file vào Xcode project tại `ios/Runner/`
- [ ] Đã kiểm tra Target Membership có "Runner"
- [ ] Đã kiểm tra Bundle ID trong file là `com.socdo.mobile`

---

## 🎯 SAU KHI HOÀN THÀNH

Sau khi thêm file `GoogleService-Info.plist`:
- ✅ Firebase sẽ hoạt động trên iOS
- ✅ Push notifications sẽ hoạt động (giống Android)
- ✅ Cùng một Firebase project với Android

**Bạn có thể bỏ qua các bước 3, 4, 5 trong Firebase Console** vì Flutter đã tự động xử lý SDK và initialization code.

---

## 📚 TÀI LIỆU THAM KHẢO

- **Hướng dẫn tổng quát**: Xem `ios/HUONG_DAN_FIREBASE_IOS.md`
- **Giải đáp về Firebase**: Xem `FIREBASE_FILE_GIAI_DAP.md`

---

**Chúc bạn thành công! 🎉**

