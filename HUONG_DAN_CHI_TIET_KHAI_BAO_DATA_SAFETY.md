# 📋 HƯỚNG DẪN CHI TIẾT KHAI BÁO DATA SAFETY & APP PRIVACY
## (Cập nhật ngày 16/11/2025)

---

## 📱 PHẦN 1: GOOGLE PLAY CONSOLE - DATA SAFETY

### 🔐 BƯỚC 1: TRUY CẬP DATA SAFETY

1. **Đăng nhập Google Play Console:**
   - Truy cập: https://play.google.com/console
   - Đăng nhập bằng tài khoản doanh nghiệp
   - Chọn app **Socdo** của bạn

2. **Vào Data Safety:**
   - Click vào menu bên trái: **Policy** → **Data safety**
   - Hoặc vào **App content** → **Data safety**
   - Click **Start** hoặc **Edit** (nếu đã có)

---

### 📊 BƯỚC 2: KHAI BÁO DỮ LIỆU THU THẬP

#### 1️⃣ PERSONAL INFO (Thông tin cá nhân)

**Giải thích:** Đây là thông tin cá nhân của người dùng được lưu trong tài khoản.

##### ✅ Name (Tên)
- **Là gì?** Tên người dùng (họ và tên)
- **Lấy ở đâu?** Từ form đăng ký/đăng nhập, lưu trong database với key `ho_ten`
- **Code tham khảo:** `lib/src/core/services/auth_service.dart` - User model có field `hoTen`
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ Account management (Quản lý tài khoản)
    - ✅ App functionality (Chức năng app)
  - **Shared (Chia sẻ):** No (hoặc Yes nếu có chia sẻ với bên thứ ba)

##### ✅ Email address (Địa chỉ email)
- **Là gì?** Email của người dùng
- **Lấy ở đâu?** Từ form đăng ký/đăng nhập, lưu trong database với key `email`
- **Code tham khảo:** `lib/src/core/services/auth_service.dart` - User model có field `email`
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ Account management (Quản lý tài khoản)
    - ✅ App functionality (Chức năng app)
    - ✅ Customer support (Hỗ trợ khách hàng)
  - **Shared (Chia sẻ):** No

##### ✅ Phone number (Số điện thoại)
- **Là gì?** Số điện thoại của người dùng
- **Lấy ở đâu?** Từ form đăng ký/đăng nhập, lưu trong database với key `dien_thoai`
- **Code tham khảo:** `lib/src/core/services/auth_service.dart` - User model có field `dienThoai`
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ Account management (Quản lý tài khoản)
    - ✅ App functionality (Chức năng app)
    - ✅ Customer support (Hỗ trợ khách hàng)
  - **Shared (Chia sẻ):** No

##### ✅ User IDs (ID người dùng)
- **Là gì?** ID duy nhất của mỗi người dùng trong hệ thống
- **Lấy ở đâu?** 
  - Từ database sau khi đăng ký/đăng nhập
  - Lưu trong app với key `user_id` hoặc `userId`
  - Code tham khảo: `lib/src/core/services/auth_service.dart` - User model có field `userId` (kiểu int)
  - Được gửi lên server trong mọi API call có dạng: `'user_id': userId`
- **Ví dụ trong code:**
  ```dart
  // lib/src/core/services/api_service.dart
  Future<Map<String, dynamic>?> getUserProfile({required int userId}) async {
    final response = await post('/user_profile', body: {
      'action': 'get_info',
      'user_id': userId,  // <-- User ID được gửi lên server
    });
  }
  ```
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ Account management (Quản lý tài khoản)
    - ✅ App functionality (Chức năng app)
    - ✅ Analytics (Phân tích) - nếu dùng để phân tích hành vi người dùng
  - **Shared (Chia sẻ):** No (hoặc Yes nếu có chia sẻ với Firebase Analytics)

---

#### 2️⃣ DEVICE OR OTHER IDs (ID thiết bị)

**Giải thích:** Đây là thông tin định danh thiết bị, không phải thông tin cá nhân.

##### ✅ Device or other IDs (ID thiết bị)
- **Là gì?** 
  - **Device Token (FCM Token):** Token từ Firebase Cloud Messaging để gửi push notification
  - **Device Model:** Thông tin model thiết bị (ví dụ: "Samsung Galaxy S21", "iPhone 13 Pro")
- **Lấy ở đâu?**
  - **Device Token:** Từ Firebase Cloud Messaging
    - Code tham khảo: `lib/src/core/services/push_notification_service.dart`
    - Được gửi lên server qua API `register_device_token` với key `device_token`
  - **Device Model:** Từ package `device_info_plus`
    - Code tham khảo: `lib/src/presentation/account/app_rating_screen.dart` dòng 54-66
    - Android: `androidInfo.brand + androidInfo.model` (ví dụ: "Samsung Galaxy S21")
    - iOS: `iosInfo.name + iosInfo.model` (ví dụ: "iPhone iPhone13,2")
- **Ví dụ trong code:**
  ```dart
  // lib/src/presentation/account/app_rating_screen.dart
  final deviceInfoPlugin = DeviceInfoPlugin();
  if (Theme.of(context).platform == TargetPlatform.android) {
    final androidInfo = await deviceInfoPlugin.androidInfo;
    deviceInfo = '${androidInfo.brand} ${androidInfo.model}'; // <-- Device model
  } else if (Theme.of(context).platform == TargetPlatform.iOS) {
    final iosInfo = await deviceInfoPlugin.iosInfo;
    deviceInfo = '${iosInfo.name} ${iosInfo.model}'; // <-- Device model
  }
  ```
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ Analytics (Phân tích) - để phân tích thiết bị người dùng sử dụng
    - ✅ App functionality (Chức năng app) - để gửi push notification
    - ✅ Fraud prevention, security, and compliance (Bảo mật, chống gian lận) - để bảo mật tài khoản
  - **Shared (Chia sẻ):** 
    - **Yes** - Vì chia sẻ với Firebase (Firebase Cloud Messaging)
    - **Với ai?** Google (Firebase)

---

#### 3️⃣ APP ACTIVITY (Hoạt động app)

**Giải thích:** Đây là dữ liệu về cách người dùng tương tác với app.

##### ✅ App interactions (Tương tác trong app)
- **Là gì?** 
  - Hành vi người dùng trong app: xem sản phẩm, thêm vào giỏ hàng, đặt hàng, đánh giá sản phẩm
  - Dữ liệu tìm kiếm (search history)
- **Lấy ở đâu?**
  - Từ các API calls khi người dùng tương tác với app
  - Code tham khảo: 
    - `lib/src/core/services/api_service.dart` - Các API như `addToCart`, `submitProductReview`, `searchProducts`
    - `lib/src/core/services/cached_api_service.dart` - Có lưu search behavior với `userId`
- **Ví dụ trong code:**
  ```dart
  // lib/src/core/services/api_service.dart
  Future<List<ProductSuggest>?> searchProducts({
    String? query,
    int? userId, // <-- User ID để lưu search behavior
  }) async {
    if (userId != null && userId > 0) {
      endpoint += '&user_id=$userId'; // <-- Lưu search với user ID
    }
  }
  ```
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ Analytics (Phân tích) - để phân tích hành vi người dùng
    - ✅ App functionality (Chức năng app) - để cung cấp tính năng mua sắm
  - **Shared (Chia sẻ):** No

##### ✅ In-app search history (Lịch sử tìm kiếm)
- **Là gì?** Từ khóa người dùng đã tìm kiếm trong app
- **Lấy ở đâu?**
  - Từ màn hình search: `lib/src/presentation/search/search_screen.dart`
  - Được gửi lên server qua API `searchProducts` với parameter `query`
  - Có thể được lưu kèm `user_id` để phân tích hành vi
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ App functionality (Chức năng app) - để cải thiện kết quả tìm kiếm
    - ✅ Analytics (Phân tích) - để phân tích xu hướng tìm kiếm
  - **Shared (Chia sẻ):** No

---

#### 4️⃣ APP INFO AND PERFORMANCE (Thông tin app và hiệu suất)

**Giải thích:** Đây là dữ liệu về hiệu suất và lỗi của app.

##### ✅ Crash logs (Nhật ký lỗi)
- **Là gì?** Thông tin về lỗi crash của app
- **Lấy ở đâu?**
  - Từ Firebase Crashlytics (nếu có tích hợp)
  - Hoặc từ app report feature: `lib/src/presentation/account/app_report_screen.dart`
  - Người dùng có thể báo lỗi kèm theo device info và app version
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ Analytics (Phân tích) - để phân tích lỗi
    - ✅ App functionality (Chức năng app) - để sửa lỗi và cải thiện app
  - **Shared (Chia sẻ):** 
    - **Yes** - Nếu dùng Firebase Crashlytics
    - **Với ai?** Google (Firebase)

##### ✅ Diagnostics (Chẩn đoán)
- **Là gì?** 
  - Thông tin về hiệu suất app
  - Device info (brand, model) khi báo lỗi
  - App version khi báo lỗi
- **Lấy ở đâu?**
  - Code tham khảo: `lib/src/presentation/account/app_report_screen.dart` dòng 138-159
  - Device info: Từ `DeviceInfoPlugin`
  - App version: Từ `PackageInfo.fromPlatform()`
- **Ví dụ trong code:**
  ```dart
  // lib/src/presentation/account/app_report_screen.dart
  String? deviceInfo;
  final deviceInfoPlugin = DeviceInfoPlugin();
  if (Theme.of(context).platform == TargetPlatform.android) {
    final androidInfo = await deviceInfoPlugin.androidInfo;
    deviceInfo = '${androidInfo.brand} ${androidInfo.model}'; // <-- Device info
  }
  
  String? appVersion;
  final packageInfo = await PackageInfo.fromPlatform();
  appVersion = packageInfo.version; // <-- App version
  ```
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ Analytics (Phân tích) - để phân tích hiệu suất
    - ✅ App functionality (Chức năng app) - để cải thiện app
  - **Shared (Chia sẻ):** No

---

#### 5️⃣ PHOTOS AND VIDEOS (Ảnh và video)

**Giải thích:** Đây là ảnh/video người dùng chọn từ thiết bị.

##### ✅ Photos (Ảnh)
- **Là gì?** Ảnh người dùng chọn từ thư viện hoặc chụp từ camera
- **Lấy ở đâu?**
  - Từ package `image_picker`
  - Code tham khảo: `lib/src/presentation/account/app_report_screen.dart` dòng 33-45
  - Được upload lên server khi báo lỗi hoặc cập nhật hồ sơ
- **Ví dụ trong code:**
  ```dart
  // lib/src/presentation/account/app_report_screen.dart
  final ImagePicker picker = ImagePicker();
  final List<XFile> images = await picker.pickMultiImage(
    maxWidth: 1200,
    imageQuality: 85,
  );
  ```
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Purpose (Mục đích):**
    - ✅ App functionality (Chức năng app) - để báo lỗi hoặc cập nhật hồ sơ
    - ✅ Customer support (Hỗ trợ khách hàng) - để hỗ trợ khi có vấn đề
  - **Shared (Chia sẻ):** No

---

### 🔐 BƯỚC 3: KHAI BÁO DỮ LIỆU CHIA SẺ

**Câu hỏi:** "Does your app share any of the collected data with third parties?"

**Trả lời:**
- ✅ **Yes** - Vì có chia sẻ với Firebase (Google)
- **Dữ liệu chia sẻ:**
  - ✅ Device or other IDs (Device Token) → Chia sẻ với Google (Firebase Cloud Messaging)
  - ✅ Crash logs (nếu có Firebase Crashlytics) → Chia sẻ với Google (Firebase)

**Khai báo chi tiết:**
1. **Google (Firebase):**
   - **Dữ liệu chia sẻ:** Device or other IDs (Device Token)
   - **Mục đích:** App functionality (Gửi push notification)
   - **Loại chia sẻ:** Service provider (Nhà cung cấp dịch vụ)

---

### 🔐 BƯỚC 4: KHAI BÁO BẢO MẬT DỮ LIỆU

**Câu hỏi 1:** "Is all user data encrypted in transit?"

**Trả lời:**
- ✅ **Yes** - Vì app chỉ dùng HTTPS (đã sửa trong code)

**Câu hỏi 2:** "Can users request that their data be deleted?"

**Trả lời:**
- ✅ **Yes** - Nếu có tính năng xóa tài khoản
- Hoặc **No** - Nếu chưa có tính năng này (nhưng nên có)

---

### 🔐 BƯỚC 5: LƯU VÀ SUBMIT

1. Click **Save** để lưu
2. Kiểm tra lại tất cả thông tin
3. Click **Submit for review** (nếu cần)

---

## 🍎 PHẦN 2: APPLE APP STORE CONNECT - APP PRIVACY

### 🔐 BƯỚC 1: TRUY CẬP APP PRIVACY

1. **Đăng nhập App Store Connect:**
   - Truy cập: https://appstoreconnect.apple.com/
   - Đăng nhập bằng tài khoản doanh nghiệp
   - Chọn app **Socdo** của bạn

2. **Vào App Privacy:**
   - Click vào app
   - Vào tab **App Privacy**
   - Click **Get Started** hoặc **Edit** (nếu đã có)

---

### 📊 BƯỚC 2: KHAI BÁO DỮ LIỆU THU THẬP

#### 1️⃣ CONTACT INFO (Thông tin liên hệ)

##### ✅ Name (Tên)
- **Là gì?** Tên người dùng (họ và tên)
- **Lấy ở đâu?** Từ form đăng ký/đăng nhập, lưu trong database
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** Yes (vì liên kết với tài khoản người dùng)
  - **Used for Tracking:** No
  - **Purpose:**
    - ✅ App Functionality
    - ✅ Customer Support

##### ✅ Email Address (Địa chỉ email)
- **Là gì?** Email của người dùng
- **Lấy ở đâu?** Từ form đăng ký/đăng nhập
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** Yes
  - **Used for Tracking:** No
  - **Purpose:**
    - ✅ App Functionality
    - ✅ Customer Support

##### ✅ Phone Number (Số điện thoại)
- **Là gì?** Số điện thoại của người dùng
- **Lấy ở đâu?** Từ form đăng ký/đăng nhập
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** Yes
  - **Used for Tracking:** No
  - **Purpose:**
    - ✅ App Functionality
    - ✅ Customer Support

---

#### 2️⃣ USER CONTENT (Nội dung người dùng)

##### ✅ Photos or Videos (Ảnh hoặc video)
- **Là gì?** Ảnh người dùng chọn từ thư viện hoặc chụp từ camera
- **Lấy ở đâu?** Từ package `image_picker` khi báo lỗi hoặc cập nhật hồ sơ
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** Yes (vì gửi kèm user ID khi báo lỗi)
  - **Used for Tracking:** No
  - **Purpose:**
    - ✅ App Functionality
    - ✅ Customer Support

---

#### 3️⃣ IDENTIFIERS (Định danh)

##### ✅ User ID (ID người dùng)
- **Là gì?** ID duy nhất của mỗi người dùng trong hệ thống
- **Lấy ở đâu?** Từ database sau khi đăng ký/đăng nhập, lưu trong app với key `userId`
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** Yes (vì là ID của chính người dùng)
  - **Used for Tracking:** No
  - **Purpose:**
    - ✅ App Functionality

##### ✅ Device ID (ID thiết bị)
- **Là gì?** 
  - Device Token (FCM Token) từ Firebase Cloud Messaging
  - Device Model (thông tin model thiết bị)
- **Lấy ở đâu?**
  - Device Token: Từ Firebase Cloud Messaging
  - Device Model: Từ `DeviceInfoPlugin` (brand + model)
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** 
    - **Yes** - Nếu Device Token được liên kết với user ID (gửi kèm user_id khi register)
    - **No** - Nếu Device Model không liên kết với user
  - **Used for Tracking:** No (hoặc Yes nếu có quảng cáo)
  - **Purpose:**
    - ✅ App Functionality (Gửi push notification)
    - ✅ Analytics

---

#### 4️⃣ USAGE DATA (Dữ liệu sử dụng)

##### ✅ Product Interaction (Tương tác sản phẩm)
- **Là gì?** Hành vi người dùng: xem sản phẩm, thêm vào giỏ hàng, đặt hàng, đánh giá
- **Lấy ở đâu?** Từ các API calls khi người dùng tương tác với app
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** Yes (vì gửi kèm user_id trong API calls)
  - **Used for Tracking:** No
  - **Purpose:**
    - ✅ Analytics
    - ✅ App Functionality

##### ✅ Advertising Data (Dữ liệu quảng cáo)
- **Là gì?** Dữ liệu về quảng cáo (nếu app có quảng cáo)
- **Lấy ở đâu?** Từ SDK quảng cáo (nếu có)
- **Cách khai báo:**
  - ✅ **Collected:** No (nếu app KHÔNG có quảng cáo)
  - Hoặc **Yes** (nếu app có quảng cáo)
  - **Linked to User:** No
  - **Used for Tracking:** Yes (nếu có quảng cáo)
  - **Purpose:**
    - ✅ Advertising or Marketing

---

#### 5️⃣ DIAGNOSTICS (Chẩn đoán)

##### ✅ Crash Data (Dữ liệu lỗi)
- **Là gì?** Thông tin về lỗi crash của app
- **Lấy ở đâu?** Từ Firebase Crashlytics (nếu có) hoặc app report feature
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** No (hoặc Yes nếu gửi kèm user_id)
  - **Used for Tracking:** No
  - **Purpose:**
    - ✅ Analytics
    - ✅ App Functionality

##### ✅ Performance Data (Dữ liệu hiệu suất)
- **Là gì?** 
  - Device info (brand, model) khi báo lỗi
  - App version khi báo lỗi
- **Lấy ở đâu?** Từ `DeviceInfoPlugin` và `PackageInfo` khi báo lỗi
- **Cách khai báo:**
  - ✅ **Collected:** Yes
  - **Linked to User:** No (hoặc Yes nếu gửi kèm user_id)
  - **Used for Tracking:** No
  - **Purpose:**
    - ✅ Analytics
    - ✅ App Functionality

---

### 🔐 BƯỚC 3: KHAI BÁO DỮ LIỆU LIÊN KẾT VỚI NGƯỜI DÙNG

**Câu hỏi:** "Is this data linked to the user's identity?"

**Trả lời:**
- **Một số dữ liệu:** Yes (User ID, Name, Email, Phone, Photos)
- **Một số dữ liệu:** No (Crash Data, Performance Data - nếu không gửi kèm user_id)

---

### 🔐 BƯỚC 4: KHAI BÁO DỮ LIỆU ĐƯỢC SỬ DỤNG ĐỂ THEO DÕI

**Câu hỏi:** "Is this data used to track the user?"

**Trả lời:**
- **Hầu hết:** No (vì không dùng để theo dõi người dùng)
- **Nếu có quảng cáo:** Yes (cho Advertising Data)

---

### 🔐 BƯỚC 5: LƯU

1. Click **Save** để lưu
2. Kiểm tra lại tất cả thông tin

---

## ✅ CHECKLIST HOÀN CHỈNH

### Google Play Console:
- [ ] Khai báo Personal info (Name, Email, Phone, User IDs)
- [ ] Khai báo Device or other IDs
- [ ] Khai báo App activity (App interactions, Search history)
- [ ] Khai báo App info and performance (Crash logs, Diagnostics)
- [ ] Khai báo Photos and videos
- [ ] Khai báo dữ liệu chia sẻ (Firebase/Google)
- [ ] Khai báo bảo mật dữ liệu (HTTPS, Delete data)
- [ ] Lưu và Submit

### Apple App Store Connect:
- [ ] Khai báo Contact Info (Name, Email, Phone)
- [ ] Khai báo User Content (Photos)
- [ ] Khai báo Identifiers (User ID, Device ID)
- [ ] Khai báo Usage Data (Product Interaction)
- [ ] Khai báo Diagnostics (Crash Data, Performance Data)
- [ ] Khai báo dữ liệu liên kết với người dùng
- [ ] Khai báo dữ liệu được sử dụng để theo dõi
- [ ] Lưu

---

## ⚠️ LƯU Ý QUAN TRỌNG

1. **Khai báo chính xác:**
   - ⚠️ Khai báo SAI sẽ bị từ chối
   - ⚠️ Phải khai báo ĐÚNG với thực tế app thu thập

2. **Privacy Policy URL:**
   - ⚠️ Bắt buộc phải có URL
   - ⚠️ URL phải truy cập được công khai
   - ⚠️ Phải mô tả đầy đủ dữ liệu thu thập

3. **Test app trước khi submit:**
   - ⚠️ Test trên thiết bị thật
   - ⚠️ Đảm bảo không có lỗi

---

**Cập nhật ngày: 16/11/2025**  
**Chúc bạn khai báo thành công! 🎉**

