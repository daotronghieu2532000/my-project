# 🍎 HƯỚNG DẪN PUBLISH APP LÊN APPLE APP STORE

## 📋 TỔNG QUAN DỰ ÁN

### Thông tin App hiện tại:
- **App Name**: `Socdo`
- **Bundle Identifier**: `com.socdo.mobile`
- **Version**: `1.0.0+1`
- **Platform**: Flutter (iOS + Android)
- **Loại App**: E-commerce / Marketplace (cho công ty doanh nghiệp)

### Cấu hình iOS hiện tại:
- ✅ Đã có cấu hình iOS cơ bản
- ✅ Bundle ID: `com.socdo.mobile`
- ✅ App Name: `Socdo`
- ✅ Version: `1.0.0+1`
- ✅ Đã có icon và launch screen

---

## 💰 KINH PHÍ VÀ YÊU CẦU

### 1. Phí Apple Developer Program

**Phí đăng ký: $99 USD/năm**

- **Loại tài khoản:**
  - **Cá nhân (Individual)**: $99 USD/năm
  - **Doanh nghiệp (Company/Organization)**: $99 USD/năm
  
- **Lưu ý:**
  - Phí thanh toán **HÀNG NĂM** (không phải một lần như Google Play)
  - Phải gia hạn mỗi năm để tiếp tục publish app
  - Nếu không gia hạn, app sẽ bị gỡ khỏi App Store

### 2. Yêu cầu kỹ thuật

**Bắt buộc:**
- ✅ **Mac** (MacBook, iMac, Mac mini, v.v.) - **BẮT BUỘC**
  - Không thể build iOS app trên Windows/Linux
  - Cần Mac để cài Xcode và build app
- ✅ **Xcode** (miễn phí, tải từ Mac App Store)
- ✅ **Apple Developer Account** ($99 USD/năm)

**Khuyến nghị:**
- iPhone/iPad để test app (tùy chọn, có thể dùng simulator)
- Internet ổn định để upload app

### 3. Yêu cầu tài liệu (cho tài khoản doanh nghiệp)

**Bắt buộc:**
- ✅ **Mã số D-U-N-S** (9 chữ số)
  - Cần thiết để xác minh công ty
  - Miễn phí, nhưng cần 5-7 ngày để xử lý
  - Đăng ký tại: https://www.dnb.com/duns-number.html
- ✅ **Giấy phép đăng ký kinh doanh**
- ✅ **Giấy chứng nhận đăng ký doanh nghiệp**
- ✅ **Mã số thuế doanh nghiệp**
- ✅ **Thông tin công ty**:
  - Tên công ty (tiếng Anh nếu có)
  - Địa chỉ công ty
  - Số điện thoại công ty
  - Email công ty
  - Website công ty (nếu có)

**Tùy chọn:**
- Logo công ty
- Thông tin người đại diện pháp luật

---

## 📝 CÁC BƯỚC CHI TIẾT

### BƯỚC 1: ĐĂNG KÝ APPLE DEVELOPER PROGRAM

#### 1.1. Chuẩn bị thông tin

**Nếu chưa có mã số D-U-N-S:**

1. **Kiểm tra công ty đã có D-U-N-S chưa:**
   - Truy cập: https://www.dnb.com/duns-number/lookup.html
   - Tìm kiếm theo tên công ty, địa chỉ, mã số thuế

2. **Nếu chưa có → Đăng ký mới:**
   - Truy cập: https://www.dnb.com/duns-number.html
   - Click "Get a D-U-N-S Number"
   - Điền thông tin công ty:
     - Tên công ty (tiếng Anh nếu có)
     - Địa chỉ công ty
     - Số điện thoại
     - Email
     - Mã số thuế
     - Ngành nghề kinh doanh
   - **Thời gian xử lý**: 5-7 ngày làm việc (miễn phí)

#### 1.2. Đăng ký Apple Developer Program

1. **Truy cập Apple Developer:**
   - Website: https://developer.apple.com/programs/
   - Click "Enroll" (Đăng ký)

2. **Chọn loại tài khoản:**
   - Chọn **"Company/Organization"** (cho doanh nghiệp)
   - Hoặc **"Individual"** (cho cá nhân)

3. **Điền thông tin:**
   - **Apple ID**: Đăng nhập bằng Apple ID (nếu chưa có thì tạo mới)
   - **Thông tin cá nhân**: Tên, địa chỉ, số điện thoại, email
   - **Thông tin công ty** (nếu chọn Company):
     - Tên công ty
     - Mã số D-U-N-S (9 chữ số)
     - Địa chỉ công ty
     - Số điện thoại công ty
     - Email công ty
     - Website công ty (nếu có)
     - Thông tin người đại diện pháp luật

4. **Xác minh:**
   - Apple sẽ gọi điện hoặc gửi email để xác minh thông tin
   - Thời gian xác minh: 1-3 ngày làm việc

5. **Thanh toán:**
   - Thanh toán phí $99 USD/năm
   - Có thể dùng thẻ tín dụng/ghi nợ quốc tế
   - Sau khi thanh toán, tài khoản được kích hoạt trong 24-48 giờ

---

### BƯỚC 2: CÀI ĐẶT XCODE VÀ CẤU HÌNH MÔI TRƯỜNG

#### 2.1. Cài đặt Xcode

**Yêu cầu:**
- ✅ Phải có **Mac** (không thể cài trên Windows/Linux)
- ✅ macOS phiên bản mới nhất (khuyến nghị)

**Cách cài đặt:**

1. **Mở Mac App Store:**
   - Trên Mac, mở **App Store**
   - Tìm kiếm "Xcode"

2. **Tải Xcode:**
   - Click "Get" hoặc "Download"
   - Xcode rất lớn (~10-15GB), cần thời gian tải
   - Sau khi tải xong, cài đặt như app bình thường

3. **Cài đặt Command Line Tools:**
   - Mở **Terminal** trên Mac
   - Gõ lệnh:
     ```bash
     xcode-select --install
     ```
   - Làm theo hướng dẫn để cài đặt

4. **Chấp nhận License:**
   - Mở **Terminal**
   - Gõ lệnh:
     ```bash
     sudo xcodebuild -license accept
     ```
   - Nhập mật khẩu Mac của bạn

#### 2.2. Cấu hình Xcode với Apple Developer Account

1. **Mở Xcode:**
   - Mở **Xcode** trên Mac

2. **Đăng nhập Apple Developer Account:**
   - Vào **Xcode** → **Preferences** (hoặc **Settings**)
   - Click tab **"Accounts"**
   - Click nút **"+"** (Add Account)
   - Đăng nhập bằng **Apple ID** đã đăng ký Apple Developer Program

3. **Kiểm tra Team:**
   - Sau khi đăng nhập, bạn sẽ thấy **Team** của bạn
   - Ghi lại tên Team (sẽ cần dùng sau)

---

### BƯỚC 3: CẤU HÌNH DỰ ÁN iOS

#### 3.1. Mở dự án trong Xcode

1. **Mở dự án:**
   - Trên Mac, mở **Terminal**
   - Di chuyển vào thư mục dự án:
     ```bash
     cd /path/to/socdo_mobile
     ```
   - Mở Xcode:
     ```bash
     open ios/Runner.xcworkspace
     ```
   - ⚠️ **LƯU Ý**: Phải mở file `.xcworkspace`, KHÔNG phải `.xcodeproj`

2. **Chờ Xcode load dự án:**
   - Xcode sẽ mất vài phút để load dự án lần đầu
   - Đợi cho đến khi Xcode load xong

#### 3.2. Cấu hình Bundle Identifier

1. **Chọn project:**
   - Trong Xcode, click vào **"Runner"** (icon màu xanh ở bên trái)

2. **Chọn Target:**
   - Click tab **"Signing & Capabilities"**

3. **Cấu hình Bundle Identifier:**
   - Tìm **"Bundle Identifier"**
   - Đảm bảo là: `com.socdo.mobile`
   - Nếu khác, sửa lại cho đúng

4. **Chọn Team:**
   - Tìm **"Team"**
   - Chọn Team của bạn (từ Apple Developer Account)
   - Nếu chưa thấy Team, đăng nhập lại Apple ID trong Xcode Preferences

5. **Xcode tự động tạo Certificate:**
   - Xcode sẽ tự động tạo **Certificate** và **Provisioning Profile**
   - Đợi Xcode hoàn tất (có thể mất vài phút)

#### 3.3. Cấu hình App Information

1. **Chọn Target "Runner":**
   - Trong Xcode, click vào **"Runner"** (icon màu xanh)

2. **Tab "General":**
   - **Display Name**: `Socdo` (tên hiển thị trên iPhone)
   - **Bundle Identifier**: `com.socdo.mobile` (đã cấu hình ở trên)
   - **Version**: `1.0.0` (từ `pubspec.yaml`)
   - **Build**: `1` (từ `pubspec.yaml`)

3. **Tab "Signing & Capabilities":**
   - **Team**: Chọn Team của bạn
   - **Automatically manage signing**: ✅ Tích vào (khuyến nghị)
   - Xcode sẽ tự động quản lý certificates và provisioning profiles

#### 3.4. Cấu hình Capabilities (nếu cần)

Nếu app của bạn sử dụng:
- **Push Notifications**: Tích vào "Push Notifications"
- **Background Modes**: Tích vào các mode cần thiết
- **App Transport Security**: Cấu hình nếu cần

---

### BƯỚC 4: BUILD APP CHO APP STORE

#### 4.1. Cập nhật dependencies

1. **Mở Terminal trên Mac:**
   - Di chuyển vào thư mục dự án:
     ```bash
     cd /path/to/socdo_mobile
     ```

2. **Lấy dependencies:**
   ```bash
     flutter pub get
     ```

3. **Cài đặt CocoaPods:**
   ```bash
     cd ios
     pod install
     cd ..
     ```

#### 4.2. Build app

**Cách 1: Dùng Flutter (Khuyến nghị)**

1. **Mở Terminal:**
   ```bash
   cd /path/to/socdo_mobile
   ```

2. **Build iOS app:**
   ```bash
   flutter build ios --release
   ```

3. **Kết quả:**
   - File `.app` sẽ được tạo tại: `build/ios/iphoneos/Runner.app`
   - File này sẽ được dùng để tạo Archive

**Cách 2: Dùng Xcode (Chi tiết hơn)**

1. **Mở Xcode:**
   - Mở `ios/Runner.xcworkspace` trong Xcode

2. **Chọn Scheme:**
   - Ở thanh toolbar phía trên, chọn **"Runner"** → **"Any iOS Device"**
   - ⚠️ **QUAN TRỌNG**: Phải chọn "Any iOS Device", KHÔNG chọn simulator

3. **Archive app:**
   - Vào menu: **Product** → **Archive**
   - Xcode sẽ build và tạo Archive
   - Quá trình này có thể mất 5-15 phút

4. **Kết quả:**
   - Sau khi Archive xong, cửa sổ **Organizer** sẽ hiện ra
   - Bạn sẽ thấy Archive của app

---

### BƯỚC 5: UPLOAD APP LÊN APP STORE CONNECT

#### 5.1. Tạo App trên App Store Connect

1. **Đăng nhập App Store Connect:**
   - Truy cập: https://appstoreconnect.apple.com/
   - Đăng nhập bằng **Apple ID** đã đăng ký Apple Developer Program

2. **Tạo App mới:**
   - Click **"My Apps"** → **"+"** (Create App)
   - Điền thông tin:
     - **Platform**: iOS
     - **Name**: `Socdo` (tên hiển thị trên App Store)
     - **Primary Language**: Vietnamese hoặc English
     - **Bundle ID**: `com.socdo.mobile` (phải khớp với Bundle ID trong Xcode)
     - **SKU**: `socdo-mobile` (mã định danh nội bộ, có thể tự đặt)
   - Click **"Create"**

#### 5.2. Hoàn thiện thông tin App

1. **App Information:**
   - **Name**: `Socdo`
   - **Subtitle**: Mô tả ngắn (tùy chọn)
   - **Category**: Chọn danh mục phù hợp (ví dụ: Shopping, Business)
   - **Privacy Policy URL**: Link đến chính sách bảo mật (bắt buộc)

2. **Pricing and Availability:**
   - **Price**: Chọn Free hoặc Paid
   - **Availability**: Chọn các quốc gia muốn phân phối

3. **App Privacy:**
   - Khai báo các dữ liệu app thu thập
   - **QUAN TRỌNG**: Phải khai báo chính xác, nếu không app sẽ bị từ chối

#### 5.3. Upload Build từ Xcode

1. **Mở Xcode Organizer:**
   - Trong Xcode, sau khi Archive xong, cửa sổ **Organizer** sẽ hiện ra
   - Hoặc vào menu: **Window** → **Organizer**

2. **Chọn Archive:**
   - Chọn Archive vừa tạo
   - Click nút **"Distribute App"**

3. **Chọn phương thức phân phối:**
   - Chọn **"App Store Connect"**
   - Click **"Next"**

4. **Chọn phương thức upload:**
   - Chọn **"Upload"** (khuyến nghị)
   - Click **"Next"**

5. **Chọn Distribution Options:**
   - Chọn **"Automatically manage signing"** (khuyến nghị)
   - Click **"Next"**

6. **Review:**
   - Xem lại thông tin
   - Click **"Upload"**

7. **Đợi upload:**
   - Quá trình upload có thể mất 10-30 phút (tùy kích thước app)
   - Sau khi upload xong, bạn sẽ thấy thông báo thành công

#### 5.4. Chờ Build xuất hiện trên App Store Connect

1. **Kiểm tra Build:**
   - Vào App Store Connect → **My Apps** → Chọn app của bạn
   - Vào tab **"TestFlight"** hoặc **"App Store"**
   - Tìm phần **"Build"**
   - Build vừa upload sẽ xuất hiện sau **10-30 phút**

2. **Xử lý Build:**
   - Apple sẽ xử lý Build (có thể mất 10-30 phút)
   - Sau khi xử lý xong, Build sẽ sẵn sàng để submit

---

### BƯỚC 6: CHUẨN BỊ THÔNG TIN CHO APP STORE

#### 6.1. Screenshots (Ảnh chụp màn hình)

**Yêu cầu:**
- **iPhone 6.7" (iPhone 14 Pro Max, 15 Pro Max, v.v.)**: Tối thiểu 1 ảnh, tối đa 10 ảnh
- **iPhone 6.5" (iPhone 11 Pro Max, XS Max, v.v.)**: Tối thiểu 1 ảnh, tối đa 10 ảnh
- **iPhone 5.5" (iPhone 8 Plus, v.v.)**: Tối thiểu 1 ảnh, tối đa 10 ảnh
- **iPad Pro 12.9"**: Tối thiểu 1 ảnh, tối đa 10 ảnh (nếu app hỗ trợ iPad)

**Kích thước:**
- **iPhone 6.7"**: 1290 x 2796 pixels
- **iPhone 6.5"**: 1242 x 2688 pixels
- **iPhone 5.5"**: 1242 x 2208 pixels
- **iPad Pro 12.9"**: 2048 x 2732 pixels

**Cách tạo:**
1. Chạy app trên simulator hoặc thiết bị thật
2. Chụp màn hình các màn hình chính của app
3. Cắt và resize theo kích thước yêu cầu
4. Upload lên App Store Connect

#### 6.2. App Description (Mô tả App)

**Yêu cầu:**
- **Name**: Tên app (tối đa 30 ký tự)
- **Subtitle**: Mô tả ngắn (tối đa 30 ký tự)
- **Description**: Mô tả chi tiết (tối đa 4000 ký tự)
- **Keywords**: Từ khóa tìm kiếm (tối đa 100 ký tự, phân cách bằng dấu phẩy)
- **Promotional Text**: Text quảng cáo (tối đa 170 ký tự, có thể cập nhật không cần review)

**Ví dụ:**
```
Name: Socdo
Subtitle: Mua sắm trực tuyến
Description: 
Socdo là ứng dụng mua sắm trực tuyến hàng đầu Việt Nam. 
Với Socdo, bạn có thể:
- Mua sắm hàng ngàn sản phẩm chất lượng
- Thanh toán an toàn và tiện lợi
- Nhận hàng nhanh chóng
- Hỗ trợ khách hàng 24/7

Keywords: shopping, ecommerce, marketplace, mua sắm, thương mại điện tử
```

#### 6.3. App Icon (Icon App)

**Yêu cầu:**
- **Kích thước**: 1024 x 1024 pixels
- **Format**: PNG hoặc JPEG
- **Không có alpha channel** (không trong suốt)
- **Không có rounded corners** (Apple sẽ tự động bo góc)

**Cách tạo:**
1. Tạo icon 1024 x 1024 pixels
2. Không bo góc, không trong suốt
3. Upload lên App Store Connect

#### 6.4. Privacy Policy (Chính sách Bảo mật)

**Yêu cầu:**
- **Bắt buộc**: Phải có Privacy Policy URL
- URL phải truy cập được công khai
- Phải viết bằng ngôn ngữ phù hợp với app

**Nội dung cần có:**
- Dữ liệu nào app thu thập
- Mục đích sử dụng dữ liệu
- Cách bảo vệ dữ liệu
- Quyền của người dùng

---

### BƯỚC 7: SUBMIT APP ĐỂ REVIEW

#### 7.1. Hoàn thiện thông tin

1. **Vào App Store Connect:**
   - Vào **My Apps** → Chọn app của bạn
   - Vào tab **"App Store"**

2. **Hoàn thiện các mục:**
   - ✅ App Information
   - ✅ Pricing and Availability
   - ✅ App Privacy
   - ✅ Version Information:
     - Screenshots
     - Description
     - Keywords
     - App Icon
     - Privacy Policy URL

3. **Chọn Build:**
   - Vào phần **"Build"**
   - Chọn Build vừa upload
   - Click **"Done"**

#### 7.2. Submit for Review

1. **Review lại thông tin:**
   - Kiểm tra lại tất cả thông tin
   - Đảm bảo không có lỗi

2. **Submit:**
   - Click nút **"Submit for Review"** (màu xanh)
   - Xác nhận submit

3. **Trạng thái:**
   - App sẽ chuyển sang trạng thái **"Waiting for Review"**
   - Apple sẽ review app trong **24-48 giờ** (thường)

---

### BƯỚC 8: CHỜ APPLE REVIEW

#### 8.1. Thời gian Review

- **Thời gian thông thường**: 24-48 giờ
- **Có thể kéo dài**: 3-7 ngày (nếu app phức tạp hoặc có vấn đề)
- **Lần đầu**: Có thể mất lâu hơn

#### 8.2. Trạng thái Review

1. **Waiting for Review**: Đang chờ review
2. **In Review**: Apple đang review
3. **Pending Developer Release**: Đã được approve, chờ bạn release
4. **Ready for Sale**: App đã live trên App Store
5. **Rejected**: App bị từ chối (cần sửa và submit lại)

#### 8.3. Nếu App bị Rejected

1. **Đọc email từ Apple:**
   - Apple sẽ gửi email giải thích lý do từ chối
   - Đọc kỹ và hiểu vấn đề

2. **Sửa lỗi:**
   - Sửa các vấn đề Apple chỉ ra
   - Build lại app
   - Upload lại

3. **Submit lại:**
   - Submit lại app sau khi sửa
   - Apple sẽ review lại

---

## 📊 TÓM TẮT KINH PHÍ

### Chi phí một lần:
- **Apple Developer Program**: $99 USD/năm
- **Mã số D-U-N-S**: Miễn phí (nhưng cần 5-7 ngày)

### Chi phí hàng năm:
- **Apple Developer Program**: $99 USD/năm (phải gia hạn)

### Chi phí khác:
- **Mac**: Cần Mac để build app (nếu chưa có)
- **Internet**: Để upload app

---

## 📋 CHECKLIST TRƯỚC KHI PUBLISH

### Chuẩn bị:
- [ ] Đã có Mac (bắt buộc)
- [ ] Đã cài Xcode
- [ ] Đã đăng ký Apple Developer Program ($99 USD/năm)
- [ ] Đã có mã số D-U-N-S (nếu tài khoản doanh nghiệp)
- [ ] Đã cấu hình Bundle ID trong Xcode
- [ ] Đã build app thành công
- [ ] Đã upload build lên App Store Connect

### Thông tin App:
- [ ] Đã tạo app trên App Store Connect
- [ ] Đã điền App Information
- [ ] Đã chọn Category
- [ ] Đã điền Pricing
- [ ] Đã khai báo App Privacy
- [ ] Đã có Privacy Policy URL

### Tài liệu:
- [ ] Đã có Screenshots (tối thiểu 1 ảnh cho mỗi kích thước)
- [ ] Đã có App Icon (1024 x 1024)
- [ ] Đã viết App Description
- [ ] Đã điền Keywords
- [ ] Đã có Privacy Policy

### Submit:
- [ ] Đã chọn Build
- [ ] Đã review lại tất cả thông tin
- [ ] Đã Submit for Review

---

## 🆘 XỬ LÝ LỖI THƯỜNG GẶP

### ❌ Lỗi: "No Mac available"

**Nguyên nhân**: Không có Mac để build iOS app

**Cách sửa:**
- Phải có Mac (MacBook, iMac, Mac mini, v.v.)
- Không thể build iOS app trên Windows/Linux
- Có thể thuê Mac cloud service (nhưng phức tạp và tốn kém)

### ❌ Lỗi: "Bundle ID already exists"

**Nguyên nhân**: Bundle ID đã được sử dụng bởi app khác

**Cách sửa:**
- Đổi Bundle ID trong Xcode (ví dụ: `com.socdo.mobile.v2`)
- Hoặc xóa app cũ trên App Store Connect

### ❌ Lỗi: "App rejected by Apple"

**Nguyên nhân**: App vi phạm chính sách của Apple

**Cách sửa:**
- Đọc email từ Apple để biết lý do
- Sửa các vấn đề Apple chỉ ra
- Submit lại

---

## 📚 TÀI LIỆU THAM KHẢO

- **Apple Developer**: https://developer.apple.com/
- **App Store Connect**: https://appstoreconnect.apple.com/
- **App Store Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **Flutter iOS Deployment**: https://docs.flutter.dev/deployment/ios

---

## ✅ KẾT LUẬN

Để publish app lên Apple App Store, bạn cần:

1. ✅ **Mac** (bắt buộc)
2. ✅ **Apple Developer Program** ($99 USD/năm)
3. ✅ **Xcode** (miễn phí)
4. ✅ **Mã số D-U-N-S** (nếu tài khoản doanh nghiệp)
5. ✅ **Cấu hình dự án iOS**
6. ✅ **Build và upload app**
7. ✅ **Chuẩn bị tài liệu** (screenshots, description, icon, privacy policy)
8. ✅ **Submit for Review**

**Thời gian tổng cộng**: 1-2 tuần (tùy vào thời gian xử lý D-U-N-S và review của Apple)

**Chúc bạn publish thành công! 🎉**

