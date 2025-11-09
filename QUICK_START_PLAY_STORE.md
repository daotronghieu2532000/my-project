# 🚀 QUICK START - PUBLISH LÊN PLAY STORE

## Hướng dẫn chi tiết từng bước để publish app lên Google Play Store

---

## 📍 BƯỚC 1: TẠO KEYSTORE (Chỉ làm 1 lần duy nhất)

Keystore là file quan trọng để ký (sign) app. **LƯU Ý**: Nếu mất keystore, bạn sẽ KHÔNG THỂ cập nhật app lên Play Store!

### 🔹 Cách làm trên Windows:

**Bước 1.1: Mở Command Prompt (CMD) hoặc PowerShell**

Có 3 cách để mở:
- **Cách 1**: Nhấn phím `Windows + R`, gõ `cmd`, nhấn Enter
- **Cách 2**: Nhấn phím `Windows`, gõ "Command Prompt" hoặc "PowerShell", nhấn Enter
- **Cách 3**: Mở File Explorer, vào thư mục dự án `C:\laragon\www\socdo_mobile`, click chuột phải vào khoảng trống, chọn "Open in Terminal" hoặc "Open PowerShell window here"

**Bước 1.2: Di chuyển vào thư mục dự án**

Trong cửa sổ Command Prompt/PowerShell vừa mở, bạn sẽ thấy dòng chữ như:
```
C:\Users\TenCuaBan>
```

Bây giờ gõ lệnh sau để vào thư mục dự án:
```bash
cd C:\laragon\www\socdo_mobile
```

Nhấn Enter. Bạn sẽ thấy đường dẫn thay đổi thành:
```
C:\laragon\www\socdo_mobile>
```

**Bước 1.3: Di chuyển vào thư mục android**

Tiếp tục gõ:
```bash
cd android
```

Nhấn Enter. Bạn sẽ thấy:
```
C:\laragon\www\socdo_mobile\android>
```

**Bước 1.4: Chạy script tạo keystore**

Gõ lệnh:
```bash
create_keystore.bat
```

Nhấn Enter. Script sẽ chạy và yêu cầu bạn nhập thông tin.

**⚠️ Nếu gặp lỗi: `'keytool' is not recognized`**

Điều này có nghĩa là Java JDK chưa được cài đặt hoặc chưa có trong PATH.

**Cách xử lý:**

1. **Cài đặt JDK** (nếu chưa cài):
   - Bạn đã tải file `jdk-25_windows-x64_bin.exe` rồi
   - Tìm file này trong thư mục Downloads
   - **Double-click** vào file để cài đặt
   - Làm theo hướng dẫn cài đặt (click Next, Next, Install, Close)

2. **Cấu hình PATH** (QUAN TRỌNG!):
   - Nhấn phím `Windows + R`
   - Gõ: `sysdm.cpl`
   - Nhấn Enter
   - Click tab **"Advanced"**
   - Click nút **"Environment Variables..."**
   - Trong phần **"System variables"**, tìm và click vào **"Path"**
   - Click nút **"Edit..."**
   - Click nút **"New"**
   - Gõ: `C:\Program Files\Java\jdk-25\bin`
   - Click **"OK"** ở tất cả các cửa sổ

3. **Đóng và mở lại Command Prompt** (QUAN TRỌNG!):
   - Đóng TẤT CẢ cửa sổ Command Prompt/PowerShell
   - Mở Command Prompt mới (nhấn `Windows + R`, gõ `cmd`, nhấn Enter)

4. **Kiểm tra cài đặt thành công**:
   - Trong Command Prompt mới, gõ: `keytool -version`
   - Nhấn Enter
   - Nếu thấy thông tin version → Thành công! ✅
   - Nếu vẫn báo lỗi → Xem file `HUONG_DAN_CAI_DAT_JDK.md` để biết chi tiết

5. **Quay lại tạo keystore**:
   - Sau khi cài đặt JDK xong, quay lại Bước 1.2 ở trên
   - Làm lại từ đầu: `cd C:\laragon\www\socdo_mobile\android`
   - Chạy lại: `create_keystore.bat`

**Xem hướng dẫn chi tiết**: File `HUONG_DAN_CAI_DAT_JDK.md`

---

**Bước 1.5: Nhập thông tin khi được hỏi**

Bạn sẽ được hỏi các thông tin sau (nhập từng cái và nhấn Enter sau mỗi câu hỏi):

1. **Enter keystore password**: Nhập mật khẩu (ví dụ: `MyPassword123!`)
   - ⚠️ **LƯU LẠI MẬT KHẨU NÀY CẨN THẬN!**
   - Nhập lại mật khẩu khi được yêu cầu

2. **What is your first and last name?**: Nhập tên của bạn (ví dụ: `Nguyen Van A`)

3. **What is the name of your organizational unit?**: Có thể để trống hoặc nhập tên bộ phận, nhấn Enter

4. **What is the name of your organization?**: Nhập tên công ty (ví dụ: `Socdo Company`)

5. **What is the name of your City or Locality?**: Nhập tên thành phố (ví dụ: `Ho Chi Minh`)

6. **What is the name of your State or Province?**: Nhập tên tỉnh/thành phố (ví dụ: `Ho Chi Minh`)

7. **What is the two-letter country code for this unit?**: Nhập `VN` (cho Việt Nam)

8. **Is CN=... correct? [no]**: Nhập `yes` và nhấn Enter

9. **Enter key password for <upload>**: Nhập mật khẩu **GIỐNG** mật khẩu ở bước 1 (ví dụ: `MyPassword123!`)
   - ⚠️ **QUAN TRỌNG**: Mật khẩu này phải GIỐNG mật khẩu keystore

10. **Re-enter new password**: Nhập lại mật khẩu giống bước 9

**Bước 1.6: Hoàn thành**

Nếu thành công, bạn sẽ thấy thông báo:
```
========================================
TẠO KEYSTORE THÀNH CÔNG!
========================================
```

File keystore đã được tạo tại: `C:\laragon\www\socdo_mobile\android\app\upload-keystore.jks`

**⚠️ LƯU Ý QUAN TRỌNG:**
- Lưu lại file `upload-keystore.jks` và mật khẩu ở nơi an toàn
- Nếu mất file hoặc mật khẩu, bạn sẽ KHÔNG THỂ cập nhật app lên Play Store

---

### 🔹 Cách làm trên Linux/Mac:

**Bước 1.1: Mở Terminal**

- **Linux**: Nhấn `Ctrl + Alt + T` hoặc tìm "Terminal" trong menu
- **Mac**: Nhấn `Cmd + Space`, gõ "Terminal", nhấn Enter

**Bước 1.2: Di chuyển vào thư mục dự án**

Gõ lệnh (thay đường dẫn bằng đường dẫn thực tế của bạn):
```bash
cd /path/to/socdo_mobile
```

**Bước 1.3: Di chuyển vào thư mục android**

```bash
cd android
```

**Bước 1.4: Cấp quyền thực thi cho script**

```bash
chmod +x create_keystore.sh
```

**Bước 1.5: Chạy script**

```bash
./create_keystore.sh
```

Sau đó làm tương tự như bước 1.5 ở trên để nhập thông tin.

---

## 📍 BƯỚC 2: CẤU HÌNH KEYSTORE

Sau khi tạo keystore xong, bạn cần tạo file cấu hình để Flutter biết sử dụng keystore nào.

### 🔹 Cách làm trên Windows:

**Bước 2.1: Mở Command Prompt/PowerShell**

Làm tương tự như Bước 1.1 ở trên.

**Bước 2.2: Di chuyển vào thư mục android**

```bash
cd C:\laragon\www\socdo_mobile\android
```

**Bước 2.3: Copy file example**

Gõ lệnh:
```bash
copy keystore.properties.example keystore.properties
```

Nhấn Enter. Bạn sẽ thấy thông báo:
```
1 file(s) copied.
```

**Bước 2.4: Mở file keystore.properties để chỉnh sửa**

Có 2 cách:

**Cách 1: Dùng Notepad**
- Mở File Explorer, vào `C:\laragon\www\socdo_mobile\android`
- Tìm file `keystore.properties`
- Click chuột phải vào file, chọn "Open with" → "Notepad"

**Cách 2: Dùng lệnh**
```bash
notepad keystore.properties
```

**Bước 2.5: Điền thông tin vào file**

File sẽ có nội dung như sau:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD_HERE
keyPassword=YOUR_KEY_PASSWORD_HERE
keyAlias=upload
storeFile=app/upload-keystore.jks
```

Bạn cần thay thế:
- `YOUR_KEYSTORE_PASSWORD_HERE` → Mật khẩu bạn đã nhập khi tạo keystore (ví dụ: `MyPassword123!`)
- `YOUR_KEY_PASSWORD_HERE` → Mật khẩu bạn đã nhập khi tạo keystore (ví dụ: `MyPassword123!` - phải GIỐNG storePassword)

**Ví dụ sau khi điền:**
```properties
storePassword=MyPassword123!
keyPassword=MyPassword123!
keyAlias=upload
storeFile=app/upload-keystore.jks
```

**Bước 2.6: Lưu file**

- Nhấn `Ctrl + S` để lưu
- Đóng Notepad

---

### 🔹 Cách làm trên Linux/Mac:

**Bước 2.1-2.2: Tương tự Windows**

```bash
cd /path/to/socdo_mobile/android
cp keystore.properties.example keystore.properties
```

**Bước 2.3: Mở file để chỉnh sửa**

```bash
nano keystore.properties
```

Hoặc dùng editor khác như `vim`, `code`, v.v.

Điền thông tin tương tự như Bước 2.5 ở trên, sau đó:
- Nếu dùng `nano`: Nhấn `Ctrl + X`, sau đó `Y`, sau đó Enter để lưu
- Nếu dùng `vim`: Nhấn `Esc`, gõ `:wq`, nhấn Enter

---

## 📍 BƯỚC 3: BUILD APP BUNDLE (AAB)

Sau khi cấu hình keystore xong, bạn cần build file AAB để upload lên Play Store.

### 🔹 Cách 1: Dùng Script (Khuyến nghị - Dễ nhất)

**Bước 3.1: Mở Command Prompt/PowerShell**

Làm tương tự như Bước 1.1.

**Bước 3.2: Di chuyển vào thư mục dự án**

```bash
cd C:\laragon\www\socdo_mobile
```

**Bước 3.3: Chạy script build**

Gõ lệnh:
```bash
build_release.bat
```

Nhấn Enter. Script sẽ tự động:
- Kiểm tra keystore có tồn tại không
- Clean build cũ
- Lấy dependencies
- Build file AAB

Quá trình này có thể mất **5-15 phút**, tùy vào máy tính của bạn.

**Bước 3.4: Kiểm tra kết quả**

Nếu thành công, bạn sẽ thấy:
```
========================================
BUILD THÀNH CÔNG!
========================================

File AAB đã được tạo tại:
build\app\outputs\bundle\release\app-release.aab
```

File AAB của bạn nằm tại:
```
C:\laragon\www\socdo_mobile\build\app\outputs\bundle\release\app-release.aab
```

---

### 🔹 Cách 2: Build thủ công (Nếu script không chạy được)

**Bước 3.1: Mở Command Prompt/PowerShell**

Làm tương tự như Bước 1.1.

**Bước 3.2: Di chuyển vào thư mục dự án**

```bash
cd C:\laragon\www\socdo_mobile
```

**Bước 3.3: Clean build cũ (tùy chọn, nhưng nên làm)**

```bash
flutter clean
```

Nhấn Enter, đợi hoàn thành.

**Bước 3.4: Lấy dependencies**

```bash
flutter pub get
```

Nhấn Enter, đợi hoàn thành.

**Bước 3.5: Build AAB**

```bash
flutter build appbundle --release
```

Nhấn Enter. Quá trình này có thể mất **5-15 phút**.

**Bước 3.6: Kiểm tra file AAB**

Sau khi build xong, file AAB sẽ nằm tại:
```
C:\laragon\www\socdo_mobile\build\app\outputs\bundle\release\app-release.aab
```

Bạn có thể mở File Explorer, vào đường dẫn trên để kiểm tra file có tồn tại không.

---

## 📍 BƯỚC 4: TẠO APP TRÊN GOOGLE PLAY CONSOLE

### 🔹 Bước 4.1: Đăng nhập Google Play Console

1. Mở trình duyệt web (Chrome, Firefox, Edge, v.v.)
2. Truy cập: https://play.google.com/console
3. Đăng nhập bằng tài khoản Google của bạn (tài khoản đã có quyền truy cập Play Console)

### 🔹 Bước 4.2: Tạo App mới

1. Trên trang chủ Play Console, click nút **"Create app"** (màu xanh, ở góc trên bên trái)
2. Điền thông tin:
   - **App name**: `Socdo` (hoặc tên bạn muốn)
   - **Default language**: Chọn `Vietnamese` hoặc `English`
   - **App or game**: Chọn **App**
   - **Free or paid**: Chọn **Free** (hoặc Paid nếu bạn muốn bán app)
   - **Declarations**: Tích vào các ô đồng ý với điều khoản
3. Click nút **"Create app"** (màu xanh)

### 🔹 Bước 4.3: Hoàn thiện thông tin App

Sau khi tạo app, bạn sẽ thấy menu bên trái với nhiều mục cần hoàn thiện. Làm theo thứ tự:

**4.3.1. App access**
- Click vào **"App access"** trong menu bên trái
- Chọn **"All functionality is available without restrictions"** (hoặc tùy chọn phù hợp)
- Click **"Save"**

**4.3.2. Ads**
- Click vào **"Ads"** trong menu bên trái
- Chọn **"No"** nếu app không có quảng cáo
- Chọn **"Yes"** nếu app có quảng cáo
- Click **"Save"**

**4.3.3. Content rating**
- Click vào **"Content rating"** trong menu bên trái
- Click **"Start questionnaire"**
- Điền form đánh giá nội dung (có khoảng 10-15 câu hỏi)
- Google sẽ tự động đánh giá dựa trên thông tin bạn cung cấp
- Click **"Save"**

**4.3.4. Target audience**
- Click vào **"Target audience"** trong menu bên trái
- Chọn độ tuổi mục tiêu (ví dụ: 13+, 18+, v.v.)
- Nếu app phù hợp cho trẻ em, tích vào **"Designed for families"**
- Click **"Save"**

**4.3.5. Data safety** ⚠️ **QUAN TRỌNG NHẤT!**
- Click vào **"Data safety"** trong menu bên trái
- Khai báo các dữ liệu app thu thập và sử dụng
- **LƯU Ý**: Phải khai báo CHÍNH XÁC, nếu không app sẽ bị từ chối
- Các mục cần khai báo:
  - Dữ liệu thu thập (ví dụ: Email, Tên, Địa chỉ, v.v.)
  - Mục đích sử dụng (ví dụ: Xác thực tài khoản, Xử lý đơn hàng, v.v.)
  - Dữ liệu chia sẻ với bên thứ ba (nếu có)
- Click **"Save"**

**4.3.6. App content**
- Click vào **"App content"** trong menu bên trái
- **App category**: Chọn danh mục phù hợp (ví dụ: Shopping, Social, Business, v.v.)
- **Tags**: Thêm các tag liên quan (ví dụ: shopping, ecommerce, marketplace)
- Click **"Save"**

---

## 📍 BƯỚC 5: UPLOAD VÀ PUBLISH APP

### 🔹 Bước 5.1: Vào mục Production

1. Trong menu bên trái, tìm và click vào **"Production"** (nằm trong phần "Release")
2. Nếu đây là lần đầu, bạn sẽ thấy nút **"Create new release"**

### 🔹 Bước 5.2: Tạo Release mới

1. Click nút **"Create new release"** (màu xanh)
2. Bạn sẽ thấy form upload file AAB

### 🔹 Bước 5.3: Upload file AAB

1. Click nút **"Upload"** hoặc kéo thả file vào vùng upload
2. Chọn file AAB: `C:\laragon\www\socdo_mobile\build\app\outputs\bundle\release\app-release.aab`
3. Đợi Google Play xử lý file (có thể mất **2-5 phút**)
4. Kiểm tra kết quả:
   - ✅ **No errors**: Có thể tiếp tục
   - ❌ **Errors**: Đọc lỗi và sửa (thường là version code đã tồn tại, cần tăng version trong `pubspec.yaml`)

### 🔹 Bước 5.4: Điền Release notes

1. **Release name**: Nhập `1.0.0` (hoặc version hiện tại)
2. **Release notes**: Mô tả các tính năng, sửa lỗi, cải tiến

**Ví dụ Release notes:**
```
Phiên bản 1.0.0 - Phát hành lần đầu

Tính năng chính:
- Mua sắm trực tuyến
- Đăng nhập/Đăng ký tài khoản
- Quản lý đơn hàng
- Chat với shop
- Hệ thống affiliate
- Thanh toán đơn giản
```

### 🔹 Bước 5.5: Review và Publish

1. Review lại tất cả thông tin:
   - ✅ File AAB đã upload thành công
   - ✅ Release notes đã điền
   - ✅ Tất cả thông tin app đã hoàn thiện (Data safety, Content rating, v.v.)

2. Click nút **"Save"** (ở cuối trang) để lưu release

3. Click nút **"Review release"** để xem lại một lần nữa

4. Nếu mọi thứ đều OK, click nút **"Start rollout to Production"** (màu xanh) để publish

5. Xác nhận publish

### 🔹 Bước 5.6: Chờ Google Review

- Lần đầu publish có thể mất **1-7 ngày** để Google review
- Bạn sẽ nhận email khi có kết quả
- Sau khi được duyệt, app sẽ xuất hiện trên Play Store trong vài giờ

---

## ⚠️ LƯU Ý QUAN TRỌNG

### 🔴 Keystore
- **Lưu giữ cẩn thận**, không được mất!
- Backup file `upload-keystore.jks` và mật khẩu ở nhiều nơi an toàn
- Nếu mất, bạn sẽ **KHÔNG THỂ** cập nhật app lên Play Store

### 🔴 Version Code
- Mỗi lần update app, phải **TĂNG** số sau dấu `+` trong `pubspec.yaml`
- Ví dụ: `1.0.0+1` → `1.0.1+2` → `1.0.2+3`
- Số này phải **LUÔN TĂNG**, không được giảm hoặc giữ nguyên

### 🔴 Data Safety
- Khai báo **CHÍNH XÁC** các dữ liệu app thu thập
- Nếu khai báo sai, app sẽ bị **TỪ CHỐI**
- Xem lại code của bạn để biết app thu thập dữ liệu gì

### 🔴 Review Time
- Lần đầu publish: **1-7 ngày**
- Các lần update sau: **1-3 ngày** (thường nhanh hơn)

---

## 🆘 XỬ LÝ LỖI THƯỜNG GẶP

### ❌ Lỗi: "Keystore file not found"
**Nguyên nhân**: File keystore không tồn tại hoặc đường dẫn sai

**Cách sửa**:
1. Kiểm tra file `upload-keystore.jks` có tồn tại tại `android/app/` không
2. Kiểm tra đường dẫn trong `keystore.properties` có đúng không (phải là `app/upload-keystore.jks`)

### ❌ Lỗi: "Wrong password"
**Nguyên nhân**: Mật khẩu trong `keystore.properties` sai

**Cách sửa**:
1. Mở file `android/keystore.properties`
2. Kiểm tra lại `storePassword` và `keyPassword` có đúng không
3. Đảm bảo 2 mật khẩu này **GIỐNG NHAU**

### ❌ Lỗi: "Version code already used"
**Nguyên nhân**: Version code đã được sử dụng trước đó

**Cách sửa**:
1. Mở file `pubspec.yaml`
2. Tìm dòng `version: 1.0.0+1`
3. Tăng số sau dấu `+` lên (ví dụ: `1.0.0+2`)
4. Build lại AAB: `flutter build appbundle --release`

### ❌ Lỗi: "App rejected by Google"
**Nguyên nhân**: App vi phạm chính sách của Google

**Cách sửa**:
1. Đọc kỹ email từ Google để biết lý do cụ thể
2. Thường gặp:
   - Data safety không chính xác → Sửa lại Data safety
   - Content rating sai → Sửa lại Content rating
   - Policy violation → Sửa code hoặc tính năng vi phạm
3. Sửa lỗi và submit lại

---

## 📚 TÀI LIỆU THAM KHẢO

- **Hướng dẫn chi tiết**: Xem file `HUONG_DAN_PUBLISH_PLAY_STORE.md`
- **Google Play Console Help**: https://support.google.com/googleplay/android-developer
- **Flutter Documentation**: https://flutter.dev/docs/deployment/android

---

## 📋 THÔNG TIN APP HIỆN TẠI

- **Application ID**: `com.socdo.mobile`
- **Version**: `1.0.0+1` (versionName: 1.0.0, versionCode: 1)
- **App Name**: `Socdo`
- **Keystore file**: `android/app/upload-keystore.jks` (sau khi tạo)
- **Keystore config**: `android/keystore.properties` (sau khi cấu hình)
- **AAB file**: `build/app/outputs/bundle/release/app-release.aab` (sau khi build)

---

**Chúc bạn publish thành công! 🎉**

Nếu gặp vấn đề, hãy xem lại từng bước hoặc tham khảo file `HUONG_DAN_PUBLISH_PLAY_STORE.md` để biết chi tiết hơn.
