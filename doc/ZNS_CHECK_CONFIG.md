# Kiểm tra cấu hình ZNS

## 📋 OA Secret Key là gì?

**OA Secret Key** là mã bí mật dùng để **xác thực webhook** từ Zalo gửi đến server của bạn.

### ⚠️ Quan trọng:
- **KHÔNG cần OA Secret Key** để gửi ZNS (OTP)
- OA Secret Key chỉ cần khi bạn **nhận webhook** từ Zalo (ví dụ: nhận tin nhắn từ người dùng)
- Với chức năng **gửi OTP qua ZNS**, bạn chỉ cần các mã sau:

## ✅ Các mã CẦN THIẾT cho ZNS:

### 1. **App ID** ✅
- **Trong config:** `3972457551268168177`
- **Trong ảnh:** URL `developers.zalo.me/app/3972457551268168177/webhook`
- **Kiểm tra:** ✅ **ĐÚNG** - Khớp với App ID trong URL

### 2. **App Secret** (KHÁC với OA Secret Key)
- **Trong config:** `PedQcRl79956tEHG2dC9`
- **Lấy từ:** https://developers.zalo.me/app/3972457551268168177/basic-info
- **Mục đích:** Dùng để lấy Access Token và Refresh Token
- **Kiểm tra:** Cần xác minh trong Zalo Cloud Console

### 3. **OA ID** (Official Account ID)
- **Trong config:** `2813091073440910336`
- **Lấy từ:** Zalo Cloud Console → OA Management
- **Mục đích:** Xác định tài khoản OA nào sẽ gửi ZNS
- **Kiểm tra:** Cần xác minh trong Zalo Cloud Console

### 4. **Template ID**
- **Trong config:** `505716`
- **Lấy từ:** ZNS Management → Template List
- **Mục đích:** Template OTP đã được duyệt
- **Kiểm tra:** Cần xác minh template đã được gán cho OA

### 5. **Access Token & Refresh Token**
- **Lấy từ:** https://developers.zalo.me/app/3972457551268168177/access-token
- **Mục đích:** Xác thực khi gọi ZNS API
- **Kiểm tra:** Đã có trong config

## 🔍 Cách kiểm tra các mã:

### Bước 1: Kiểm tra App Secret
1. Vào: https://developers.zalo.me/app/3972457551268168177/basic-info
2. Tìm mục **"App Secret"**
3. So sánh với `PedQcRl79956tEHG2dC9` trong config
4. Nếu khác → Cập nhật lại trong `zns_config.php`

### Bước 2: Kiểm tra OA ID
1. Vào: https://developers.zalo.me/app/3972457551268168177/oa-management
2. Tìm OA "Sóc Đỏ VN"
3. Lấy OA ID (số dài)
4. So sánh với `2813091073440910336` trong config
5. Nếu khác → Cập nhật lại trong `zns_config.php`

### Bước 3: Kiểm tra Template ID
1. Vào: https://account.zalo.cloud/KGUWDZB7Q6E4YKRQ/tool/zns/manage/template
2. Tìm template `505716` ("Thông báo OTP thay đổi mật khẩu D")
3. Kiểm tra:
   - Template đã được **duyệt** chưa?
   - Template đã được **gán cho OA** `2813091073440910336` chưa?
   - Template đang ở trạng thái **"Kích hoạt"** chưa?

### Bước 4: Kiểm tra Access Token
1. Vào: https://developers.zalo.me/app/3972457551268168177/access-token
2. Đảm bảo đã cấp quyền **"Gửi thông báo ZNS"**
3. Lấy Access Token và Refresh Token mới
4. Cập nhật vào `zns_config.php`

## ❌ OA Secret Key - KHÔNG CẦN cho ZNS

**OA Secret Key** trong ảnh webhook:
- Chỉ dùng để xác thực webhook từ Zalo
- **KHÔNG dùng** cho ZNS API
- Bạn có thể bỏ qua nếu chỉ gửi OTP, không nhận webhook

## 📝 Tóm tắt:

| Mã | Trong Config | Cần Kiểm Tra | Vị trí Kiểm Tra |
|---|---|---|---|
| App ID | `3972457551268168177` | ✅ Đúng | URL trong ảnh |
| App Secret | `PedQcRl79956tEHG2dC9` | ⚠️ Cần xác minh | Basic Info |
| OA ID | `2813091073440910336` | ⚠️ Cần xác minh | OA Management |
| Template ID | `505716` | ⚠️ Cần xác minh | ZNS Template |
| Access Token | Đã có | ⚠️ Cần cập nhật | Access Token page |
| Refresh Token | Đã có | ⚠️ Cần cập nhật | Access Token page |
| **OA Secret Key** | ❌ Không có | ✅ **KHÔNG CẦN** | Webhook (không dùng) |

## 🎯 Hành động tiếp theo:

1. ✅ **App ID** - Đã đúng, không cần thay đổi
2. ⚠️ **Kiểm tra App Secret** - So sánh với Basic Info
3. ⚠️ **Kiểm tra OA ID** - So sánh với OA Management
4. ⚠️ **Kiểm tra Template** - Đảm bảo đã gán cho OA
5. ⚠️ **Lấy Token mới** - Sau khi cấp quyền mới
6. ❌ **OA Secret Key** - Bỏ qua, không cần

