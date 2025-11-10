# 🚀 QUICK START - PUBLISH LÊN APPLE APP STORE

## Tóm tắt nhanh các bước publish app lên App Store

---

## 💰 KINH PHÍ

- **Apple Developer Program**: **$99 USD/năm** (phải gia hạn hàng năm)
- **Mã số D-U-N-S**: Miễn phí (nhưng cần 5-7 ngày)
- **Mac**: Cần Mac để build app (nếu chưa có)

---

## ⚠️ YÊU CẦU BẮT BUỘC

- ✅ **Mac** (MacBook, iMac, Mac mini, v.v.) - **BẮT BUỘC**
- ✅ **Xcode** (miễn phí, tải từ Mac App Store)
- ✅ **Apple Developer Account** ($99 USD/năm)
- ✅ **Mã số D-U-N-S** (nếu tài khoản doanh nghiệp)

---

## 📋 CÁC BƯỚC CHÍNH

### 1️⃣ Đăng ký Apple Developer Program

1. Truy cập: https://developer.apple.com/programs/
2. Click "Enroll"
3. Chọn "Company/Organization" (cho doanh nghiệp)
4. Điền thông tin:
   - Apple ID
   - Thông tin công ty
   - **Mã số D-U-N-S** (nếu chưa có → đăng ký tại https://www.dnb.com/duns-number.html)
5. Thanh toán $99 USD/năm
6. Đợi Apple xác minh (1-3 ngày)

---

### 2️⃣ Cài đặt Xcode

1. Mở **Mac App Store**
2. Tìm và tải **Xcode** (miễn phí, ~10-15GB)
3. Cài đặt Xcode
4. Mở **Terminal**, gõ:
   ```bash
   xcode-select --install
   sudo xcodebuild -license accept
   ```

---

### 3️⃣ Cấu hình dự án iOS

1. **Mở dự án trong Xcode:**
   ```bash
   cd /path/to/socdo_mobile
   open ios/Runner.xcworkspace
   ```

2. **Cấu hình Signing:**
   - Chọn project "Runner"
   - Tab "Signing & Capabilities"
   - Chọn **Team** của bạn
   - ✅ Tích "Automatically manage signing"

3. **Kiểm tra Bundle ID:**
   - Đảm bảo là: `com.socdo.mobile`

---

### 4️⃣ Build app

**Cách 1: Dùng Flutter (Khuyến nghị)**
```bash
cd /path/to/socdo_mobile
flutter build ios --release
```

**Cách 2: Dùng Xcode**
1. Mở `ios/Runner.xcworkspace` trong Xcode
2. Chọn "Any iOS Device" (KHÔNG chọn simulator)
3. **Product** → **Archive**
4. Đợi Archive xong

---

### 5️⃣ Tạo App trên App Store Connect

1. Đăng nhập: https://appstoreconnect.apple.com/
2. Click **"My Apps"** → **"+"** (Create App)
3. Điền thông tin:
   - **Platform**: iOS
   - **Name**: `Socdo`
   - **Bundle ID**: `com.socdo.mobile`
   - **SKU**: `socdo-mobile`
4. Click **"Create"**

---

### 6️⃣ Upload Build

1. **Trong Xcode Organizer:**
   - Chọn Archive vừa tạo
   - Click **"Distribute App"**
   - Chọn **"App Store Connect"**
   - Chọn **"Upload"**
   - Làm theo hướng dẫn

2. **Đợi Build xuất hiện:**
   - Vào App Store Connect → **My Apps** → Chọn app
   - Vào tab **"App Store"**
   - Build sẽ xuất hiện sau 10-30 phút

---

### 7️⃣ Chuẩn bị thông tin App

1. **Screenshots** (bắt buộc):
   - iPhone 6.7": 1290 x 2796 pixels (tối thiểu 1 ảnh)
   - iPhone 6.5": 1242 x 2688 pixels (tối thiểu 1 ảnh)
   - iPhone 5.5": 1242 x 2208 pixels (tối thiểu 1 ảnh)

2. **App Icon**: 1024 x 1024 pixels (PNG/JPEG, không trong suốt)

3. **App Description**:
   - Name: `Socdo` (tối đa 30 ký tự)
   - Description: Mô tả chi tiết (tối đa 4000 ký tự)
   - Keywords: Từ khóa tìm kiếm (tối đa 100 ký tự)

4. **Privacy Policy URL** (bắt buộc):
   - Link đến chính sách bảo mật
   - Phải truy cập được công khai

5. **App Privacy**:
   - Khai báo các dữ liệu app thu thập
   - **QUAN TRỌNG**: Phải khai báo chính xác

---

### 8️⃣ Submit for Review

1. Vào App Store Connect → **My Apps** → Chọn app
2. Vào tab **"App Store"**
3. Hoàn thiện tất cả thông tin:
   - ✅ App Information
   - ✅ Screenshots
   - ✅ Description
   - ✅ App Icon
   - ✅ Privacy Policy
   - ✅ App Privacy
4. Chọn **Build** vừa upload
5. Click **"Submit for Review"**

---

## ⏱️ THỜI GIAN

- **Đăng ký D-U-N-S**: 5-7 ngày (nếu chưa có)
- **Apple xác minh**: 1-3 ngày
- **Apple Review**: 24-48 giờ (thường)
- **Tổng cộng**: 1-2 tuần

---

## ⚠️ LƯU Ý QUAN TRỌNG

1. **Phải có Mac**: Không thể build iOS app trên Windows/Linux
2. **Phí hàng năm**: $99 USD/năm (phải gia hạn)
3. **Privacy Policy**: Bắt buộc phải có
4. **App Privacy**: Phải khai báo chính xác
5. **Screenshots**: Bắt buộc phải có (tối thiểu 1 ảnh cho mỗi kích thước)

---

## 📚 XEM HƯỚNG DẪN CHI TIẾT

Xem file `HUONG_DAN_PUBLISH_APP_STORE.md` để biết chi tiết từng bước.

---

**Thông tin App hiện tại:**
- **App Name**: `Socdo`
- **Bundle ID**: `com.socdo.mobile`
- **Version**: `1.0.0+1`

**Chúc bạn publish thành công! 🎉**

