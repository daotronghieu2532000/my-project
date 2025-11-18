# TÀI LIỆU PHÂN TÍCH NGHIỆP VỤ (BA)
## ỨNG DỤNG DI ĐỘNG SOCDO

---

**Phiên bản:** 1.0.0  
**Ngày tạo:** 2024  
**Người soạn:** Business Analyst  
**Dự án:** Socdo Mobile Application

---

## MỤC LỤC

1. [TỔNG QUAN DỰ ÁN](#1-tổng-quan-dự-án)
2. [CÔNG NGHỆ SỬ DỤNG](#2-công-nghệ-sử-dụng)
3. [KIẾN TRÚC HỆ THỐNG](#3-kiến-trúc-hệ-thống)
4. [CẤU TRÚC ỨNG DỤNG](#4-cấu-trúc-ứng-dụng)
5. [CHỨC NĂNG CHI TIẾT THEO TRANG](#5-chức-năng-chi-tiết-theo-trang)
6. [LUỒNG NGHIỆP VỤ](#6-luồng-nghiệp-vụ)
7. [API & BACKEND](#7-api--backend)
8. [CƠ SỞ DỮ LIỆU](#8-cơ-sở-dữ-liệu)
9. [BẢO MẬT & XỬ LÝ LỖI](#9-bảo-mật--xử-lý-lỗi)
10. [TÍNH NĂNG NỔI BẬT](#10-tính-năng-nổi-bật)

---

## 1. TỔNG QUAN DỰ ÁN

### 1.1. Mô tả dự án

**Socdo Mobile** là ứng dụng thương mại điện tử (E-commerce) được phát triển trên nền tảng Flutter, cho phép người dùng:

- Mua sắm sản phẩm trực tuyến
- Quản lý đơn hàng và thanh toán
- Tham gia chương trình Affiliate Marketing
- Tương tác với shop qua chat
- Nhận thông báo và khuyến mãi

### 1.2. Mục tiêu dự án

- Cung cấp trải nghiệm mua sắm mượt mà, hiện đại
- Tối ưu hóa hiệu suất và tốc độ tải trang
- Hỗ trợ đa nền tảng (Android, iOS)
- Tích hợp hệ thống Affiliate Marketing
- Quản lý đơn hàng và thanh toán hiệu quả

### 1.3. Đối tượng sử dụng

- **Người mua hàng:** Mua sắm, quản lý đơn hàng, đánh giá sản phẩm
- **Affiliate Marketer:** Tạo link giới thiệu, theo dõi hoa hồng
- **Shop/Nhà cung cấp:** Quản lý sản phẩm, đơn hàng (qua web)

---

## 2. CÔNG NGHỆ SỬ DỤNG

### 2.1. Frontend Framework

**Flutter 3.9.2+**
- Framework đa nền tảng (Android, iOS)
- Ngôn ngữ: Dart
- UI Framework: Material Design

### 2.2. Dependencies chính

| Package | Version | Mục đích |
|---------|---------|----------|
| `http` | ^1.1.0 | HTTP client cho API calls |
| `shared_preferences` | ^2.2.2 | Lưu trữ dữ liệu local |
| `cached_network_image` | ^3.3.1 | Cache và hiển thị ảnh |
| `firebase_core` | ^2.24.0 | Firebase core |
| `firebase_messaging` | ^14.7.9 | Push notifications |
| `flutter_local_notifications` | ^17.2.1 | Local notifications |
| `image_picker` | ^1.0.7 | Chọn ảnh từ thư viện/camera |
| `carousel_slider` | ^5.0.0 | Slider/carousel UI |
| `flutter_html` | ^3.0.0-beta.2 | Hiển thị HTML content |
| `share_plus` | ^7.2.1 | Chia sẻ nội dung |
| `url_launcher` | ^6.2.1 | Mở URL/links |
| `web_socket_channel` | ^2.4.0 | WebSocket cho chat |
| `socket_io_client` | ^1.0.2 | Socket.IO client |
| `flutter_rating_bar` | ^4.0.1 | Rating/đánh giá UI |
| `google_fonts` | ^6.2.1 | Google Fonts (Inter) |
| `font_awesome_flutter` | ^10.7.0 | Font Awesome icons |

### 2.3. Backend & API

- **Base URL:** `https://api.socdo.vn/v1`
- **Authentication:** Bearer Token (JWT)
- **API Key/Secret:** Sử dụng API key và secret để lấy token
- **Chat Server:** `https://chat.socdo.vn` (Socket.IO)

### 2.4. Database

- **MySQL/MariaDB** (Backend)
- **SQLite** (Local storage - qua SharedPreferences)
- Các bảng chính: `sanpham`, `donhang`, `user_info`, `yeu_thich_san_pham`, `notification_mobile`, v.v.

### 2.5. Push Notifications

- **Firebase Cloud Messaging (FCM)**
- **Local Notifications** (khi app ở foreground)

---

## 3. KIẾN TRÚC HỆ THỐNG

### 3.1. Kiến trúc tổng quan

```
┌─────────────────────────────────────────┐
│         SOCDO MOBILE APP                │
│         (Flutter/Dart)                  │
├─────────────────────────────────────────┤
│  Presentation Layer                     │
│  - Screens (UI)                         │
│  - Widgets (Components)                 │
├─────────────────────────────────────────┤
│  Core Layer                             │
│  - Services (API, Auth, Cart, etc.)     │
│  - Models (Data Models)                 │
│  - Utils (Helpers)                      │
├─────────────────────────────────────────┤
│  Data Layer                             │
│  - SharedPreferences (Local Storage)    │
│  - Cache (Memory Cache)                │
└─────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│         BACKEND API                     │
│  https://api.socdo.vn/v1                │
│  - RESTful API                          │
│  - Token-based Auth                     │
└─────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│         DATABASE                        │
│  MySQL/MariaDB                          │
└─────────────────────────────────────────┘
```

### 3.2. Cấu trúc thư mục

```
lib/
├── main.dart                    # Entry point
├── src/
│   ├── app.dart                # App configuration
│   ├── core/
│   │   ├── models/             # Data models
│   │   ├── services/           # Business logic services
│   │   ├── theme/              # App theme
│   │   ├── utils/              # Utility functions
│   │   └── widgets/            # Reusable widgets
│   └── presentation/
│       ├── auth/                # Authentication screens
│       ├── home/                # Home screen
│       ├── product/             # Product screens
│       ├── cart/                # Cart screens
│       ├── checkout/             # Checkout screens
│       ├── orders/              # Order management
│       ├── account/             # Account management
│       ├── affiliate/           # Affiliate features
│       ├── search/              # Search functionality
│       ├── category/            # Category browsing
│       ├── shop/                 # Shop pages
│       ├── chat/                # Chat functionality
│       ├── notifications/       # Notifications
│       └── root_shell.dart      # Main navigation
```

### 3.3. Design Patterns

- **Singleton Pattern:** Services (ApiService, AuthService, CartService)
- **Repository Pattern:** API services với caching
- **Observer Pattern:** Listeners cho cart, auth state changes
- **State Management:** StatefulWidget với setState
- **Service Layer:** Tách biệt business logic khỏi UI

---

## 4. CẤU TRÚC ỨNG DỤNG

### 4.1. Navigation Structure

```
SplashScreen
    │
    ▼
RootShell (Bottom Navigation)
    ├── HomeScreen (Tab 0)
    ├── CategoryScreen (Tab 1)
    └── AffiliateScreen (Tab 2)
    │
    ├── CartScreen (Modal/Stack)
    └── AccountScreen (Modal/Stack)
```

### 4.2. Bottom Navigation Bar

**4 tabs chính:**
1. **Trang chủ** - HomeScreen
2. **Danh mục** - CategoryScreen
3. **Affiliate** - AffiliateScreen
4. **Giỏ hàng** - CartScreen (với badge số lượng)

**Đặc điểm:**
- Sử dụng `IndexedStack` để giữ state khi chuyển tab
- Badge hiển thị số lượng sản phẩm trong giỏ hàng
- Nút "Đặt mua" hiển thị tổng tiền và số lượng đã chọn

---

## 5. CHỨC NĂNG CHI TIẾT THEO TRANG

### 5.1. Splash Screen (`splash_screen.dart`)

**Mục đích:** Màn hình khởi động, hiển thị logo và loading

**Chức năng:**
- Hiển thị splash screen từ API hoặc ảnh mặc định
- Animation fade-in và scale
- Tự động chuyển sang RootShell sau 3 giây
- Preload ảnh splash để hiển thị nhanh

**Luồng:**
1. App khởi động → Hiển thị splash screen
2. Load splash screen từ API (`/splash_screen`)
3. Hiển thị ảnh (từ API hoặc asset)
4. Sau 3 giây → Navigate to RootShell

**API:**
- `GET /splash_screen` - Lấy thông tin splash screen

---

### 5.2. Home Screen (`home_screen.dart`)

**Mục đích:** Trang chủ hiển thị sản phẩm, banner, khuyến mãi

**Các thành phần:**

#### 5.2.1. Home App Bar
- Logo/Icon app
- Thanh tìm kiếm
- Icon thông báo
- Icon giỏ hàng (với badge)

#### 5.2.2. Partner Banner Slider
- Banner quảng cáo đối tác
- Carousel tự động chuyển
- Full width, height 160px
- API: `GET /home_banners`

#### 5.2.3. Service Guarantees
- "Trả hàng 15 ngày"
- "Chính hãng 100%"
- "Giao miễn phí"

#### 5.2.4. Quick Actions
- Các nút nhanh: Flash Sale, Freeship, Voucher, v.v.

#### 5.2.5. Banner Products Widget
- Banner sản phẩm theo vị trí:
  - `dau_trang` - Đầu trang
  - `giua_trang` - Giữa trang
  - `cuoi_trang` - Cuối trang
- API: `GET /banner_products?position={position}`

#### 5.2.6. Flash Sale Section
- Sản phẩm flash sale với countdown timer
- Horizontal scroll
- API: `GET /home_flash_sale`

#### 5.2.7. Featured Brands Slider
- Thương hiệu nổi bật
- Horizontal scroll
- API: `GET /home_featured_brands`

#### 5.2.8. Product Grid
- Lưới sản phẩm gợi ý
- Personalized suggestions (dựa trên user behavior)
- Infinite scroll
- API: `GET /home_suggestions?limit=100&user_id={userId}`

#### 5.2.9. Popup Banner
- Popup banner hiển thị khi vào trang chủ
- Chỉ hiển thị banner chưa xem
- Preload ảnh trước khi hiển thị
- API: `GET /popup_banner?exclude_ids={ids}`

**Tính năng đặc biệt:**
- **Scroll Position Preservation:** Lưu và khôi phục vị trí scroll khi quay lại
- **Pull to Refresh:** Kéo xuống để làm mới dữ liệu
- **Preloading:** Preload dữ liệu trước khi hiển thị
- **Caching:** Cache dữ liệu để tải nhanh hơn

**APIs sử dụng:**
- `GET /home_banners`
- `GET /home_flash_sale`
- `GET /home_partner_banners`
- `GET /home_featured_brands`
- `GET /home_suggestions`
- `GET /banner_products`
- `GET /popup_banner`

---

### 5.3. Category Screen (`category_screen.dart`)

**Mục đích:** Duyệt danh mục sản phẩm

**Layout:**
- **Bên trái:** Danh sách danh mục cha (parent categories)
- **Bên phải:** Danh sách danh mục con (child categories) hoặc sản phẩm

**Chức năng:**
- Chọn danh mục cha → Hiển thị danh mục con
- Click danh mục con → Navigate to CategoryProductsScreen
- Hiển thị số lượng sản phẩm mỗi danh mục
- Cache danh mục để tải nhanh

**APIs:**
- `GET /categories?type=parents&include_children=true`
- `GET /categories?parent_id={id}`

**Navigation:**
- CategoryProductsScreen - Danh sách sản phẩm theo danh mục

---

### 5.4. Search Screen (`search_screen.dart`)

**Mục đích:** Tìm kiếm sản phẩm và shop

**Chức năng:**

#### 5.4.1. Tìm kiếm sản phẩm
- Nhập từ khóa → Tự động gợi ý
- Kết quả tìm kiếm với phân trang
- Lọc theo:
  - Giá (price range)
  - Freeship
  - Còn hàng
  - Có voucher
- Sắp xếp theo:
  - Liên quan (relevance)
  - Giá tăng dần/giảm dần
  - Đánh giá
  - Đã bán

#### 5.4.2. Gợi ý từ khóa
- Gợi ý từ khóa khi đang nhập (debounce)
- Lịch sử tìm kiếm
- Danh mục nổi bật

#### 5.4.3. Gợi ý shop
- Tìm kiếm shop theo từ khóa
- Navigate to ShopDetailScreen khi click

**APIs:**
- `GET /search_products?keyword={keyword}&page={page}&sort={sort}&filters={filters}`
- `GET /search_suggestions?keyword={keyword}`
- `GET /shop_suggestions?keyword={keyword}`

**Navigation:**
- ProductDetailScreen - Chi tiết sản phẩm
- ShopDetailScreen - Chi tiết shop

---

### 5.5. Product Detail Screen (`product_detail_screen.dart`)

**Mục đích:** Chi tiết sản phẩm, thêm vào giỏ hàng, mua ngay

**Các thành phần:**

#### 5.5.1. Product Images
- Carousel ảnh sản phẩm
- Swipe để xem ảnh khác
- Zoom ảnh (nếu có)

#### 5.5.2. Product Info
- Tên sản phẩm
- Giá (giá gốc, giá khuyến mãi)
- Đánh giá (rating, số lượng đánh giá)
- Số lượng đã bán
- Flash sale timer (nếu có)

#### 5.5.3. Variant Selection
- Chọn biến thể (màu sắc, kích thước, v.v.)
- Dialog chọn variant với hình ảnh
- Cập nhật giá theo variant

#### 5.5.4. Vouchers
- Danh sách voucher áp dụng được
- Hiển thị giá trị giảm

#### 5.5.5. Shop Info
- Tên shop
- Đánh giá shop
- Số lượng sản phẩm
- Nút "Xem shop" → Navigate to ShopDetailScreen
- Nút "Chat" → Navigate to ChatScreen

#### 5.5.6. Product Description
- Mô tả sản phẩm (HTML)
- Thông số kỹ thuật
- Hướng dẫn sử dụng

#### 5.5.7. Related Products
- Sản phẩm liên quan (horizontal scroll)
- Sản phẩm cùng shop (horizontal scroll)

#### 5.5.8. Reviews & Ratings
- Xem đánh giá sản phẩm
- Navigate to ProductReviewScreen để xem tất cả

#### 5.5.9. Bottom Actions
- Nút "Thêm vào giỏ hàng"
- Nút "Mua ngay"
- Nút "Yêu thích" (heart icon)

**Chức năng:**
- **Thêm vào giỏ hàng:** Thêm sản phẩm với variant đã chọn
- **Mua ngay:** Navigate to CheckoutScreen với sản phẩm đã chọn
- **Yêu thích:** Thêm/xóa khỏi danh sách yêu thích
- **Chia sẻ:** Share link sản phẩm

**APIs:**
- `GET /product_detail?product_id={id}`
- `POST /add_favorite` - Thêm/xóa yêu thích
- `GET /related_products?product_id={id}`
- `GET /products_same_shop?product_id={id}&shop_id={shopId}`

**Navigation:**
- ShopDetailScreen - Chi tiết shop
- ChatScreen - Chat với shop
- CheckoutScreen - Thanh toán
- ProductReviewScreen - Xem đánh giá

---

### 5.6. Cart Screen (`cart_screen.dart`)

**Mục đích:** Quản lý giỏ hàng, chọn sản phẩm để thanh toán

**Các thành phần:**

#### 5.6.1. Cart Items by Shop
- Nhóm sản phẩm theo shop
- Mỗi shop có:
  - Checkbox chọn tất cả
  - Danh sách sản phẩm
  - Voucher áp dụng
  - Phí vận chuyển

#### 5.6.2. Cart Item
- Ảnh sản phẩm
- Tên sản phẩm
- Giá (giá gốc, giá khuyến mãi)
- Số lượng (tăng/giảm)
- Checkbox chọn
- Nút xóa

#### 5.6.3. Voucher Section
- Hiển thị voucher đã áp dụng
- Nút chọn voucher khác
- Tự động áp dụng voucher tốt nhất

#### 5.6.4. Bottom Checkout Bar
- Tổng tiền hàng
- Tổng tiền thanh toán
- Nút "Thanh toán" → Navigate to CheckoutScreen

#### 5.6.5. Suggest Section
- Gợi ý sản phẩm liên quan
- Horizontal scroll

**Chức năng:**
- **Chọn/Bỏ chọn:** Chọn từng sản phẩm hoặc chọn tất cả
- **Tăng/Giảm số lượng:** Cập nhật số lượng sản phẩm
- **Xóa sản phẩm:** Xóa khỏi giỏ hàng
- **Áp dụng voucher:** Tự động hoặc chọn thủ công
- **Tính phí vận chuyển:** Tính phí ship theo địa chỉ

**State Management:**
- Sử dụng `CartService` (Singleton) để quản lý giỏ hàng
- Listeners để cập nhật UI khi giỏ hàng thay đổi

**APIs:**
- Cart được lưu local (SharedPreferences)
- `POST /create_order` - Tạo đơn hàng (từ CheckoutScreen)

**Navigation:**
- CheckoutScreen - Thanh toán
- ProductDetailScreen - Chi tiết sản phẩm

---

### 5.7. Checkout Screen (`checkout_screen.dart`)

**Mục đích:** Xác nhận đơn hàng và thanh toán

**Các thành phần:**

#### 5.7.1. Delivery Info Section
- Thông tin người nhận
- Địa chỉ giao hàng
- Số điện thoại
- Nút "Chọn địa chỉ" → Navigate to AddressBookScreen

#### 5.7.2. Product Section
- Danh sách sản phẩm đã chọn
- Hiển thị theo shop
- Tổng tiền mỗi shop

#### 5.7.3. Order Summary Section
- Tổng tiền hàng
- Phí vận chuyển (tính theo địa chỉ)
- Giảm giá voucher
- Tổng thanh toán

#### 5.7.4. Voucher Section
- Voucher shop đã áp dụng
- Voucher sàn đã áp dụng
- Nút chọn voucher khác

#### 5.7.5. Payment Methods Section
- Phương thức thanh toán:
  - COD (Thanh toán khi nhận hàng) - Chỉ hỗ trợ COD

#### 5.7.6. Payment Details Section
- Chi tiết thanh toán
- Tổng tiền

#### 5.7.7. Terms Section
- Điều khoản và điều kiện
- Checkbox đồng ý

#### 5.7.8. Bottom Order Bar
- Tổng thanh toán
- Nút "Đặt hàng"

**Chức năng:**
- **Tính phí vận chuyển:** Gọi API tính phí ship theo địa chỉ
- **Áp dụng voucher:** Tự động hoặc chọn thủ công
- **Đặt hàng:**
  1. Validate thông tin
  2. Gọi API `POST /create_order`
  3. Navigate to OrderSuccessScreen
  4. Xóa sản phẩm đã đặt khỏi giỏ hàng

**APIs:**
- `POST /create_order` - Tạo đơn hàng
- `GET /shipping_quote` - Tính phí vận chuyển
- `GET /vouchers?shop_id={id}` - Lấy voucher shop
- `GET /platform_vouchers` - Lấy voucher sàn

**Navigation:**
- AddressBookScreen - Chọn địa chỉ
- OrderSuccessScreen - Màn hình thành công

---

### 5.8. Orders Screen (`orders_screen.dart`)

**Mục đích:** Quản lý đơn hàng

**Các tab:**
- **Tất cả** - Tất cả đơn hàng
- **Chờ xác nhận** - Đơn hàng chờ shop xác nhận
- **Đang giao** - Đơn hàng đang vận chuyển
- **Đã giao** - Đơn hàng đã giao
- **Đã hủy** - Đơn hàng đã hủy

**Chức năng:**
- Xem danh sách đơn hàng theo trạng thái
- Click đơn hàng → Navigate to OrderDetailScreen
- Pull to refresh

**APIs:**
- `GET /orders_list?user_id={id}&status={status}`

**Navigation:**
- OrderDetailScreen - Chi tiết đơn hàng

---

### 5.9. Order Detail Screen (`order_detail_screen.dart`)

**Mục đích:** Chi tiết đơn hàng

**Các thành phần:**
- Thông tin đơn hàng (mã đơn, ngày đặt, trạng thái)
- Thông tin người nhận
- Danh sách sản phẩm
- Tổng tiền (tiền hàng, phí ship, giảm giá, tổng thanh toán)
- Thông tin vận chuyển
- Nút "Đánh giá" (nếu đã giao)
- Nút "Hủy đơn" (nếu chưa giao)

**Chức năng:**
- Xem chi tiết đơn hàng
- Đánh giá sản phẩm → Navigate to ProductReviewScreen
- Hủy đơn hàng (nếu được phép)

**APIs:**
- `GET /order_detail?order_id={id}`
- `POST /cancel_order` - Hủy đơn hàng

**Navigation:**
- ProductReviewScreen - Đánh giá sản phẩm

---

### 5.10. Account Screen (`account_screen.dart`)

**Mục đích:** Quản lý tài khoản

**Các thành phần:**

#### 5.10.1. Header Card
- Avatar người dùng
- Tên người dùng
- Số điện thoại
- Nút "Chỉnh sửa" → Navigate to ProfileEditScreen

#### 5.10.2. Action List
- **Lịch sử mua hàng** → Navigate to AllOrdersAccountScreen
- **Sản phẩm đã mua** → Navigate to PurchasedProductsScreen
- **Sản phẩm yêu thích** → Navigate to FavoriteProductsScreen
- **Mã giảm giá** → Navigate to VoucherScreen

#### 5.10.3. Product Suggestions
- Sản phẩm gợi ý dành cho bạn

**Navigation:**
- ProfileEditScreen - Chỉnh sửa thông tin
- AddressBookScreen - Sổ địa chỉ
- SettingsScreen - Cài đặt

---

### 5.11. Affiliate Screen (`affiliate_screen.dart`)

**Mục đích:** Quản lý chương trình Affiliate Marketing

**Các tab:**
- **Dashboard** - Tổng quan
- **Sản phẩm** - Danh sách sản phẩm affiliate
- **Đơn hàng** - Đơn hàng từ link affiliate
- **Rút tiền** - Rút hoa hồng

#### 5.11.1. Dashboard Tab
- Tổng quan:
  - Tổng hoa hồng
  - Số đơn hàng
  - Số link đã tạo
- Nút "Đăng ký Affiliate" (nếu chưa đăng ký)
- Quick actions:
  - Tạo link
  - Xem đơn hàng
  - Rút tiền

#### 5.11.2. Products Tab
- Danh sách sản phẩm có thể tạo link affiliate
- Tìm kiếm và lọc:
  - Theo từ khóa
  - Chỉ sản phẩm đã follow
  - Chỉ sản phẩm đã có link
  - Sắp xếp (mới nhất, hoa hồng cao, v.v.)
- Actions:
  - Follow/Unfollow shop
  - Tạo link affiliate
  - Copy link
  - Share link

#### 5.11.3. Orders Tab
- Danh sách đơn hàng từ link affiliate
- Lọc theo trạng thái
- Chi tiết hoa hồng

#### 5.11.4. Withdraw Tab
- Thông tin tài khoản ngân hàng
- Lịch sử rút tiền
- Nút "Rút tiền" → Navigate to AffiliateWithdrawScreen

**APIs:**
- `GET /affiliate_dashboard?user_id={id}`
- `GET /affiliate_products?page={page}&filters={filters}`
- `POST /affiliate_create_link`
- `GET /affiliate_orders?user_id={id}`
- `GET /commission_history?user_id={id}`
- `GET /withdrawal_history?user_id={id}`
- `POST /affiliate_withdraw`

**Navigation:**
- AffiliateLinksScreen - Quản lý links
- AffiliateOrdersScreen - Đơn hàng affiliate
- AffiliateWithdrawScreen - Rút tiền
- CommissionHistoryScreen - Lịch sử hoa hồng
- WithdrawalHistoryScreen - Lịch sử rút tiền

---

### 5.12. Shop Detail Screen (`shop_detail_screen.dart`)

**Mục đích:** Chi tiết shop, xem sản phẩm của shop

**Các thành phần:**
- Shop banner
- Thông tin shop (tên, đánh giá, số sản phẩm)
- Tabs:
  - **Tất cả** - Tất cả sản phẩm
  - **Flash Sale** - Sản phẩm flash sale
  - **Danh mục** - Sản phẩm theo danh mục
- Nút "Chat" → Navigate to ChatScreen
- Nút "Follow" - Theo dõi shop

**Chức năng:**
- Xem sản phẩm của shop
- Tìm kiếm sản phẩm trong shop
- Chat với shop
- Follow/Unfollow shop

**APIs:**
- `GET /shop_detail?shop_id={id}`
- `GET /shop_products?shop_id={id}&page={page}`
- `GET /shop_flash_sales?shop_id={id}`

**Navigation:**
- ProductDetailScreen - Chi tiết sản phẩm
- ChatScreen - Chat với shop
- ShopCategoryProductsScreen - Sản phẩm theo danh mục

---

### 5.13. Chat Screen (`chat_screen.dart`)

**Mục đích:** Chat với shop

**Chức năng:**
- Gửi/nhận tin nhắn real-time
- Sử dụng Socket.IO
- Hiển thị lịch sử chat
- Gửi ảnh (nếu có)

**APIs:**
- `POST /chat/create_session` - Tạo phiên chat
- `GET /chat/messages?session_id={id}`
- Socket.IO events:
  - `message` - Nhận tin nhắn
  - `send_message` - Gửi tin nhắn

---

### 5.14. Notifications Screen (`notifications_screen.dart`)

**Mục đích:** Xem thông báo

**Chức năng:**
- Danh sách thông báo
- Đánh dấu đã đọc
- Click thông báo → Navigate to trang liên quan
- Pull to refresh

**APIs:**
- `GET /notifications?user_id={id}`
- `POST /notifications/mark_read`

---

### 5.15. Authentication Screens

#### 5.15.1. Login Screen (`login_screen.dart`)
- Đăng nhập bằng username/phone và password
- Quên mật khẩu → Navigate to ForgotPasswordScreen
- Đăng ký → Navigate to RegisterScreen

**APIs:**
- `POST /login`

#### 5.15.2. Register Screen (`register_screen.dart`)
- Đăng ký tài khoản mới
- Nhập: Họ tên, Số điện thoại, Mật khẩu, Xác nhận mật khẩu
- OTP verification (nếu có)

**APIs:**
- `POST /register`
- `POST /verify_otp` (nếu có)

#### 5.15.3. Forgot Password Screen (`forgot_password_screen.dart`)
- Quên mật khẩu
- Nhập số điện thoại → Gửi OTP
- Đặt lại mật khẩu

**APIs:**
- `POST /forgot_password`
- `POST /reset_password`

---

## 6. LUỒNG NGHIỆP VỤ

### 6.1. Luồng đăng nhập/đăng ký

```
Start
  │
  ▼
SplashScreen (3 giây)
  │
  ▼
RootShell
  │
  ▼
[Chưa đăng nhập?]
  │
  ├─ Yes → LoginScreen
  │         │
  │         ├─ Login thành công → RootShell (đã đăng nhập)
  │         │
  │         └─ Register → RegisterScreen
  │                        │
  │                        └─ Đăng ký thành công → LoginScreen
  │
  └─ No → HomeScreen (đã đăng nhập)
```

### 6.2. Luồng mua hàng

```
HomeScreen / SearchScreen / CategoryScreen
  │
  ▼
ProductDetailScreen
  │
  ├─ Thêm vào giỏ hàng → CartScreen
  │                        │
  │                        └─ Chọn sản phẩm → CheckoutScreen
  │
  └─ Mua ngay → CheckoutScreen
                 │
                 ├─ Chọn địa chỉ → AddressBookScreen
                 │
                 ├─ Chọn voucher → VoucherScreen
                 │
                 └─ Đặt hàng → OrderSuccessScreen
                                │
                                └─ Xem đơn hàng → OrdersScreen
```

### 6.3. Luồng thanh toán

```
CheckoutScreen
  │
  ├─ Validate thông tin
  │   ├─ Địa chỉ giao hàng ✓
  │   ├─ Sản phẩm đã chọn ✓
  │   └─ Phương thức thanh toán ✓
  │
  ├─ Tính phí vận chuyển
  │   └─ API: GET /shipping_quote
  │
  ├─ Áp dụng voucher
  │   └─ Tự động hoặc chọn thủ công
  │
  ├─ Tính tổng thanh toán
  │
  └─ Đặt hàng
      └─ API: POST /create_order
          │
          ├─ Thành công → OrderSuccessScreen
          │                 └─ Xóa sản phẩm khỏi giỏ hàng
          │
          └─ Thất bại → Hiển thị lỗi
```

### 6.4. Luồng Affiliate

```
AffiliateScreen
  │
  ├─ [Chưa đăng ký?]
  │   │
  │   └─ Yes → Đăng ký Affiliate
  │              └─ API: POST /register_affiliate
  │
  └─ [Đã đăng ký]
      │
      ├─ Dashboard → Xem tổng quan
      │
      ├─ Products → Chọn sản phẩm
      │              │
      │              └─ Tạo link → Copy/Share link
      │
      ├─ Orders → Xem đơn hàng từ link
      │
      └─ Withdraw → Rút hoa hồng
                     │
                     └─ Nhập thông tin ngân hàng
                        └─ API: POST /affiliate_withdraw
```

### 6.5. Luồng chat

```
ShopDetailScreen / ProductDetailScreen
  │
  └─ Click "Chat" → ChatScreen
                      │
                      ├─ [Chưa có session?]
                      │   │
                      │   └─ Tạo session → API: POST /chat/create_session
                      │
                      ├─ Kết nối Socket.IO
                      │
                      ├─ Gửi tin nhắn → Socket.IO: send_message
                      │
                      └─ Nhận tin nhắn → Socket.IO: message event
```

---

## 7. API & BACKEND

### 7.1. Authentication

**Base URL:** `https://api.socdo.vn/v1`

**Token Management:**
- Lấy token: `POST /get_token`
  - Body: `{ "api_key": "...", "api_secret": "..." }`
  - Response: `{ "success": true, "token": "..." }`
- Token được lưu local và tự động refresh khi hết hạn
- Tất cả API calls (trừ `/get_token`) đều cần header: `Authorization: Bearer {token}`

### 7.2. User APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/login` | POST | Đăng nhập |
| `/register` | POST | Đăng ký |
| `/forgot_password` | POST | Quên mật khẩu |
| `/user_profile` | POST | Lấy/cập nhật thông tin user |
| `/register_affiliate` | POST | Đăng ký affiliate |

### 7.3. Product APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/product_detail` | GET | Chi tiết sản phẩm |
| `/search_products` | GET | Tìm kiếm sản phẩm |
| `/home_suggestions` | GET | Gợi ý sản phẩm (trang chủ) |
| `/related_products` | GET | Sản phẩm liên quan |
| `/products_same_shop` | GET | Sản phẩm cùng shop |
| `/add_favorite` | POST | Thêm/xóa yêu thích |

### 7.4. Category APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/categories` | GET | Danh sách danh mục |
| `/category_products` | GET | Sản phẩm theo danh mục |

### 7.5. Cart & Order APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/create_order` | POST | Tạo đơn hàng |
| `/orders_list` | GET | Danh sách đơn hàng |
| `/order_detail` | GET | Chi tiết đơn hàng |
| `/cancel_order` | POST | Hủy đơn hàng |
| `/shipping_quote` | GET | Tính phí vận chuyển |

### 7.6. Shop APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/shop_detail` | GET | Chi tiết shop |
| `/shop_products` | GET | Sản phẩm của shop |
| `/shop_flash_sales` | GET | Flash sale của shop |

### 7.7. Affiliate APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/affiliate_dashboard` | GET | Dashboard affiliate |
| `/affiliate_products` | GET | Sản phẩm affiliate |
| `/affiliate_create_link` | POST | Tạo link affiliate |
| `/affiliate_orders` | GET | Đơn hàng affiliate |
| `/commission_history` | GET | Lịch sử hoa hồng |
| `/affiliate_withdraw` | POST | Rút tiền |

### 7.8. Voucher APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/vouchers` | GET | Danh sách voucher |
| `/platform_vouchers` | GET | Voucher sàn |
| `/apply_voucher` | POST | Áp dụng voucher |

### 7.9. Notification APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/notifications` | GET | Danh sách thông báo |
| `/notifications/mark_read` | POST | Đánh dấu đã đọc |

### 7.10. Chat APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/chat/create_session` | POST | Tạo phiên chat |
| `/chat/messages` | GET | Lấy tin nhắn |
| Socket.IO: `chat.socdo.vn` | - | Real-time chat |

### 7.11. Banner & Home APIs

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/home_banners` | GET | Banner trang chủ |
| `/home_flash_sale` | GET | Flash sale trang chủ |
| `/home_partner_banners` | GET | Banner đối tác |
| `/home_featured_brands` | GET | Thương hiệu nổi bật |
| `/banner_products` | GET | Banner sản phẩm |
| `/popup_banner` | GET | Popup banner |

---

## 8. CƠ SỞ DỮ LIỆU

### 8.1. Các bảng chính

#### 8.1.1. User & Authentication
- `user_info` - Thông tin người dùng
- `code_otp` - Mã OTP xác thực

#### 8.1.2. Products
- `sanpham` - Sản phẩm
- `phanloai_sanpham` - Phân loại sản phẩm
- `category_sanpham` - Danh mục sản phẩm
- `category_sanpham_shop` - Danh mục shop
- `thuong_hieu` - Thương hiệu
- `product_comments` - Bình luận sản phẩm
- `product_rating_stats` - Thống kê đánh giá

#### 8.1.3. Orders
- `donhang` - Đơn hàng
- `lichsu_chitieu` - Lịch sử chi tiêu

#### 8.1.4. Cart & Favorites
- `yeu_thich_san_pham` - Sản phẩm yêu thích
- (Cart lưu local trong app)

#### 8.1.5. Shop
- `rut_gon_shop` - Thông tin shop

#### 8.1.6. Affiliate
- `sanpham_aff` - Sản phẩm affiliate
- (Các bảng liên quan đến hoa hồng, rút tiền)

#### 8.1.7. Vouchers & Deals
- `coupon` - Mã giảm giá
- `deal` - Deal/khuyến mãi

#### 8.1.8. Shipping
- `transport` - Vận chuyển
- `dia_chi` - Địa chỉ
- `tinh_moi`, `huyen_moi`, `xa_moi` - Địa chỉ hành chính

#### 8.1.9. Notifications
- `notification` - Thông báo
- `notification_mobile` - Thông báo mobile
- `device_tokens` - FCM tokens

#### 8.1.10. Chat
- `chat_sessions_ncc` - Phiên chat
- `chat_ncc` - Tin nhắn chat

#### 8.1.11. Banners
- `banner` - Banner
- `popup_banners` - Popup banner
- `ncc_yeu_cau_banner_sanpham` - Banner sản phẩm

#### 8.1.12. Other
- `splash_screens` - Splash screen
- `user_behavior` - Hành vi người dùng (cho gợi ý)
- `app_ratings` - Đánh giá app
- `app_reports` - Báo cáo lỗi app

---

## 9. BẢO MẬT & XỬ LÝ LỖI

### 9.1. Bảo mật

#### 9.1.1. Authentication
- Token-based authentication (JWT)
- Token tự động refresh khi hết hạn
- Logout xóa toàn bộ token và user data

#### 9.1.2. Network Security
- **HTTPS only:** Tất cả API calls đều dùng HTTPS
- **Android:** `cleartextTrafficPermitted="false"`
- **iOS:** App Transport Security enabled

#### 9.1.3. Data Storage
- User data lưu trong SharedPreferences (encrypted)
- Token được lưu an toàn
- Clear data khi logout

#### 9.1.4. Permissions
- **iOS:** Khai báo đầy đủ privacy permissions:
  - `NSPhotoLibraryUsageDescription` - Truy cập thư viện ảnh
  - `NSCameraUsageDescription` - Truy cập camera

### 9.2. Xử lý lỗi

#### 9.2.1. API Errors
- Hiển thị thông báo lỗi thân thiện
- Retry logic cho network errors
- Fallback data khi API fail

#### 9.2.2. Network Errors
- Kiểm tra kết nối internet
- Hiển thị thông báo khi mất kết nối
- Cache data để hiển thị offline

#### 9.2.3. Validation
- Validate input trước khi gửi API
- Hiển thị lỗi validation rõ ràng

---

## 10. TÍNH NĂNG NỔI BẬT

### 10.1. Performance Optimization

#### 10.1.1. Caching
- **Memory Cache:** Cache dữ liệu trong memory
- **Image Cache:** Cache ảnh với `cached_network_image`
- **API Cache:** Cache API responses để giảm số lần gọi API

#### 10.1.2. Lazy Loading
- Infinite scroll cho danh sách sản phẩm
- Load more khi scroll gần cuối

#### 10.1.3. Preloading
- Preload dữ liệu trang chủ trước khi hiển thị
- Preload ảnh splash screen
- Preload ảnh popup banner

#### 10.1.4. State Preservation
- Lưu scroll position khi chuyển tab
- Khôi phục scroll position khi quay lại
- Giữ state của các tab khi switch

### 10.2. User Experience

#### 10.2.1. Personalized Suggestions
- Gợi ý sản phẩm dựa trên hành vi người dùng
- API: `GET /home_suggestions?user_id={id}`

#### 10.2.2. Auto Apply Vouchers
- Tự động áp dụng voucher tốt nhất khi vào giỏ hàng/checkout
- Tính toán voucher shop và voucher sàn

#### 10.2.3. Real-time Updates
- Cart updates real-time với listeners
- Push notifications cho đơn hàng
- Chat real-time với Socket.IO

#### 10.2.4. Smooth Animations
- Fade-in/scale animations
- Smooth transitions giữa các màn hình
- Loading indicators

### 10.3. Affiliate Marketing

#### 10.3.1. Link Generation
- Tạo link affiliate cho từng sản phẩm
- Copy và share link dễ dàng

#### 10.3.2. Commission Tracking
- Theo dõi hoa hồng real-time
- Lịch sử hoa hồng chi tiết

#### 10.3.3. Withdrawal
- Rút tiền hoa hồng
- Lịch sử rút tiền

### 10.4. Push Notifications

#### 10.4.1. Firebase Cloud Messaging
- Đăng ký FCM token khi đăng nhập
- Nhận push notifications cho:
  - Đơn hàng mới
  - Trạng thái đơn hàng thay đổi
  - Khuyến mãi
  - Thông báo từ shop

#### 10.4.2. Local Notifications
- Hiển thị notification khi app ở foreground
- Sử dụng `flutter_local_notifications`

### 10.5. Search & Discovery

#### 10.5.1. Advanced Search
- Tìm kiếm sản phẩm với nhiều bộ lọc
- Gợi ý từ khóa khi đang nhập
- Lịch sử tìm kiếm

#### 10.5.2. Category Browsing
- Duyệt danh mục 2 cấp (parent/child)
- Hiển thị số lượng sản phẩm mỗi danh mục

### 10.6. Social Features

#### 10.6.1. Chat with Shop
- Chat real-time với shop
- Socket.IO integration
- Lịch sử chat

#### 10.6.2. Reviews & Ratings
- Đánh giá sản phẩm sau khi mua
- Xem đánh giá của người khác
- Thống kê đánh giá

---

## 11. KẾT LUẬN

### 11.1. Tóm tắt

**Socdo Mobile** là ứng dụng thương mại điện tử hoàn chỉnh với:

- ✅ **UI/UX hiện đại:** Material Design, animations mượt mà
- ✅ **Performance cao:** Caching, lazy loading, preloading
- ✅ **Tính năng đầy đủ:** Mua sắm, thanh toán, affiliate, chat
- ✅ **Bảo mật tốt:** HTTPS, token-based auth, secure storage
- ✅ **Đa nền tảng:** Android và iOS

### 11.2. Điểm mạnh

1. **Kiến trúc rõ ràng:** Tách biệt presentation, core, data layers
2. **Code organization tốt:** Dễ maintain và mở rộng
3. **Performance optimization:** Caching, lazy loading, state preservation
4. **User experience tốt:** Personalized suggestions, auto apply vouchers
5. **Affiliate marketing:** Hệ thống affiliate hoàn chỉnh

### 11.3. Hướng phát triển

1. **Payment Integration:** Tích hợp thêm các phương thức thanh toán (VNPay, MoMo, v.v.)
2. **Live Streaming:** Tích hợp live streaming để bán hàng
3. **AR/VR:** Thử sản phẩm bằng AR
4. **AI Recommendations:** Cải thiện gợi ý sản phẩm bằng AI
5. **Multi-language:** Hỗ trợ đa ngôn ngữ

---

**Tài liệu này được tạo tự động dựa trên phân tích codebase.  
Cập nhật lần cuối: 2024**

---

