# BUSINESS ANALYSIS - CHỨC NĂNG YÊU CẦU BANNER VÀ SẢN PHẨM TỪ NCC

## 1. TỔNG QUAN CHỨC NĂNG

### 1.1. Mục đích
Cho phép NCC (Nhà cung cấp) gửi yêu cầu hiển thị banner và sản phẩm lên admin để được duyệt và hiển thị trên sàn thương mại điện tử.

### 1.2. Đối tượng sử dụng
- **NCC (Nhà cung cấp)**: Tài khoản có `ctv = 1` trong bảng `user_info`
- **Admin**: Tài khoản quản trị viên có quyền duyệt yêu cầu

---

## 2. PHÂN TÍCH CHI TIẾT

### 2.1. CHỨC NĂNG BÊN NCC

#### 2.1.1. Gửi yêu cầu banner và sản phẩm

**Mô tả:**
NCC có thể tạo yêu cầu gồm:
- **1 banner** (bắt buộc): 
  - **Banner dọc**: Kích thước bằng 1 card sản phẩm trong app mobile
    - Chiều rộng: (screenWidth - 16) / 2 (bằng chiều rộng 1 card sản phẩm)
      - Ví dụ: màn hình 360px → (360 - 16) / 2 = 172px
      - Ví dụ: màn hình 414px → (414 - 16) / 2 = 199px
    - Chiều cao: 256px (188px image + ~68px info section, bằng chiều cao 1 card)
    - Tỉ lệ width/height: khoảng 0.67 - 0.78 (tùy theo kích thước màn hình)
  - **Banner ngang**: Tỉ lệ 1:3 (ví dụ: 300x900, 400x1200, etc.)
    - Chiều cao: (screenWidth / 3).clamp(100.0, 150.0) — tối đa 150px
    - Chiều rộng: toàn màn hình (double.infinity)
- **10 sản phẩm mong muốn** (bắt buộc): Chỉ được chọn từ những sản phẩm đã được duyệt trên sàn của NCC đó

**Điều kiện:**
- NCC phải đã đăng nhập (`ctv = 1` trong `user_info`)
- Sản phẩm được chọn phải:
  - Thuộc về NCC đó (`sanpham.shop = user_id` của NCC)
  - Đã được duyệt trên sàn (`sanpham.status = 1`)
  - Tồn tại trong bảng `sanpham`

**Quy trình:**
1. NCC truy cập trang tạo yêu cầu (ví dụ: `/ncc/yeu-cau-banner-sanpham`)
2. Kiểm tra số lượng yêu cầu:
   - Đếm số yêu cầu hiện có của NCC (status != 3 - không tính yêu cầu bị từ chối)
   - Nếu đã có 2 yêu cầu → Thông báo: "Bạn đã đạt giới hạn 2 yêu cầu. Vui lòng xóa hoặc đợi yêu cầu cũ được xử lý."
3. Upload banner:
   - Chọn file ảnh
   - Hệ thống kiểm tra kích thước:
     - **Banner dọc**: 
       * Chiều cao phải = 256px
       * Chiều rộng phải = (screenWidth - 16) / 2 (tùy theo màn hình)
       * Tỉ lệ width/height: khoảng 0.67 - 0.78 (tolerance ±0.05)
       * Ví dụ: 172x256px (màn hình 360px), 199x256px (màn hình 414px)
     - **Banner ngang**: 
       * Tỉ lệ chiều rộng/chiều cao ≈ 0.33 (1/3, tolerance ±0.05)
     - Nếu không đúng → Báo lỗi
4. Chọn 10 sản phẩm:
   - Hiển thị danh sách sản phẩm đã duyệt của NCC (status = 1)
   - Cho phép tìm kiếm, lọc sản phẩm
   - Chọn đúng 10 sản phẩm (không ít hơn, không nhiều hơn)
5. Gửi yêu cầu:
   - Lưu vào database
   - Trạng thái ban đầu: `cho_duyet` (status = 0)

**Validation:**
- Số lượng yêu cầu: Mỗi NCC chỉ được gửi tối đa 2 yêu cầu (không tính yêu cầu bị từ chối)
- Banner: Bắt buộc, đúng kích thước
- Sản phẩm: Bắt buộc, đúng 10 sản phẩm, thuộc NCC, đã duyệt

---

### 2.2. CHỨC NĂNG BÊN ADMIN

#### 2.2.1. Danh sách yêu cầu

**Mô tả:**
Admin xem danh sách tất cả yêu cầu từ NCC với các thông tin:
- ID yêu cầu
- Tên shop (NCC)
- Banner (xem trước)
- Số lượng sản phẩm (10)
- Vị trí hiển thị (đầu trang, giữa trang, cuối trang)
- Trạng thái (chờ duyệt, đã duyệt, từ chối, chờ hiển thị)
- Thời gian tạo
- Thời gian duyệt (nếu có)
- Thời gian hiển thị đến (nếu đã duyệt)

**Lọc và tìm kiếm:**
- Tìm kiếm theo tên shop
- Lọc theo trạng thái:
  - Chờ duyệt (status = 0)
  - Đã duyệt - Đang hiển thị (status = 1)
  - Đã duyệt - Chờ hiển thị (status = 2)
  - Từ chối (status = 3)
- Phân trang

#### 2.2.2. Duyệt yêu cầu

**Mô tả:**
Admin duyệt yêu cầu và cấu hình hiển thị:
- Chọn vị trí hiển thị: Đầu trang, Giữa trang, hoặc Cuối trang (bắt buộc)
- Chọn thời gian hiển thị (số ngày)
- Khi duyệt:
  - Kiểm tra số lượng yêu cầu đang hiển thị tại vị trí đó (status = 1 và vi_tri_hien_thi = vị trí đã chọn)
  - Nếu vị trí đó chưa đủ 1 yêu cầu:
    - status = 1 (đang hiển thị)
    - date_display_start = time()
    - date_display_end = time() + (so_ngay_hien_thi * 86400)
    - vi_tri_hien_thi = vị trí admin chọn
  - Nếu vị trí đó đã có 1 yêu cầu đang hiển thị:
    - status = 2 (chờ hiển thị)
    - date_approved = time()
    - vi_tri_hien_thi = vị trí admin chọn
  - Lưu thời gian hiển thị đến (date_display_end)

**Quy tắc:**
- Mỗi vị trí (đầu trang, giữa trang, cuối trang) chỉ có **1 yêu cầu** được hiển thị tại một thời điểm
- Tổng cộng có **3 vị trí** = **3 yêu cầu** đang hiển thị tối đa
- Nếu vị trí đã có yêu cầu đang hiển thị → Yêu cầu mới sẽ ở trạng thái "chờ hiển thị"
- Khi một yêu cầu hết thời gian → Tự động chuyển về "chờ duyệt" (status = 0)
- Admin phải bấm duyệt lại với thời gian mới để yêu cầu được hiển thị lại

#### 2.2.3. Từ chối yêu cầu

**Mô tả:**
Admin có thể từ chối yêu cầu với lý do:
- Bắt buộc nhập lý do từ chối
- Lưu lý do vào database
- Chuyển trạng thái sang "từ chối" (status = 3)
- NCC có thể xem lý do từ chối

#### 2.2.4. Sửa yêu cầu

**Mô tả:**
Admin có thể sửa yêu cầu khi:
- Trạng thái là "Đang hiển thị" (status = 1) hoặc "Chờ hiển thị" (status = 2)

**Quy trình:**
1. Admin click nút "Sửa" trên yêu cầu
2. Modal sửa hiển thị với:
   - Vị trí hiển thị hiện tại (có thể thay đổi)
   - Số ngày hiển thị hiện tại (có thể thay đổi)
3. Admin chỉnh sửa và lưu:
   - Cập nhật vị trí hiển thị
   - Cập nhật số ngày hiển thị
   - Tính lại thời gian hết hạn (date_display_end) dựa trên date_display_start và số ngày mới
   - Nếu đổi vị trí và vị trí mới trống → Có thể tự động chuyển từ "chờ hiển thị" sang "đang hiển thị"

**Validation:**
- Chỉ cho phép sửa khi status = 1 hoặc 2
- Vị trí hiển thị: Bắt buộc chọn
- Số ngày hiển thị: 1-30 ngày
- Kiểm tra vị trí mới có trống không (trừ chính yêu cầu này)

**Lưu ý:**
- Admin chỉ có thể sửa vị trí và số ngày hiển thị
- Không thể sửa banner, sản phẩm, hoặc các thông tin khác

#### 2.2.5. Xóa yêu cầu

**Mô tả:**
Admin có thể xóa yêu cầu:
- Xóa vĩnh viễn khỏi database
- Xóa file banner đã upload (nếu có)
- Cảnh báo trước khi xóa
- Admin có thể xóa yêu cầu ở bất kỳ trạng thái nào

#### 2.2.6. Tự động cập nhật trạng thái

**Mô tả:**
Hệ thống tự động kiểm tra và cập nhật:
- Khi yêu cầu hết thời gian hiển thị (`date_display_end < current_time`):
  - Chuyển từ "đang hiển thị" (status = 1) → "chờ duyệt" (status = 0)
  - Giải phóng 1 vị trí hiển thị
  - date_display_start = NULL
  - date_display_end = NULL
  - so_ngay_hien_thi = NULL
  - vi_tri_hien_thi = NULL
  - **KHÔNG tự động đưa yêu cầu "chờ hiển thị" lên** - Admin phải duyệt lại

**Cron job hoặc scheduled task:**
- Chạy định kỳ (ví dụ: mỗi phút hoặc mỗi giờ)
- Kiểm tra tất cả yêu cầu có `status = 1` và `date_display_end < current_time`

---

## 3. CẤU TRÚC DATABASE

### 3.1. Bảng: `ncc_yeu_cau_banner_sanpham`

```sql
CREATE TABLE `ncc_yeu_cau_banner_sanpham` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ncc_id` bigint(11) NOT NULL COMMENT 'user_id của NCC (từ user_info)',
  `shop_name` varchar(255) NOT NULL COMMENT 'Tên shop (lấy từ user_info.name)',
  `banner_path` varchar(500) NOT NULL COMMENT 'Đường dẫn file banner',
  `banner_link` varchar(500) DEFAULT NULL COMMENT 'Link khi click vào banner',
  `banner_type` varchar(20) NOT NULL COMMENT 'banner_doc hoặc banner_ngang',
  `banner_width` int(11) DEFAULT NULL COMMENT 'Chiều rộng banner',
  `banner_height` int(11) DEFAULT NULL COMMENT 'Chiều cao banner',
  `sanpham_ids` text NOT NULL COMMENT 'Danh sách ID sản phẩm, cách nhau bởi dấu phẩy (10 sản phẩm)',
  `vi_tri_hien_thi` varchar(20) DEFAULT NULL COMMENT 'dau_trang, giua_trang, cuoi_trang',
  `status` int(1) NOT NULL DEFAULT '0' COMMENT '0=chờ duyệt, 1=đang hiển thị, 2=chờ hiển thị, 3=từ chối',
  `ly_do_tu_choi` text DEFAULT NULL COMMENT 'Lý do từ chối từ admin',
  `date_created` varchar(11) NOT NULL COMMENT 'Thời gian tạo yêu cầu (timestamp)',
  `date_approved` varchar(11) DEFAULT NULL COMMENT 'Thời gian admin duyệt (timestamp)',
  `date_display_start` varchar(11) DEFAULT NULL COMMENT 'Thời gian bắt đầu hiển thị (timestamp)',
  `date_display_end` varchar(11) DEFAULT NULL COMMENT 'Thời gian kết thúc hiển thị (timestamp)',
  `so_ngay_hien_thi` int(11) DEFAULT NULL COMMENT 'Số ngày hiển thị admin chọn',
  `admin_approved_id` int(11) DEFAULT NULL COMMENT 'ID admin duyệt (từ user_info của admin)',
  `date_updated` varchar(11) DEFAULT NULL COMMENT 'Thời gian cập nhật cuối',
  PRIMARY KEY (`id`),
  KEY `ncc_id` (`ncc_id`),
  KEY `status` (`status`),
  KEY `vi_tri_hien_thi` (`vi_tri_hien_thi`),
  KEY `date_display_end` (`date_display_end`),
  KEY `date_created` (`date_created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

**Giải thích các trường:**
- `ncc_id`: ID của NCC (user_id từ user_info)
- `shop_name`: Tên shop để tìm kiếm nhanh
- `banner_path`: Đường dẫn file banner (ví dụ: `/uploads/banner-ncc/xxx.jpg`)
- `banner_link`: Link khi click vào banner (tùy chọn, có thể NULL)
- `banner_type`: Loại banner (banner_doc hoặc banner_ngang)
- `sanpham_ids`: Danh sách ID sản phẩm, format: "123,456,789,..." (10 ID)
- `vi_tri_hien_thi`: Vị trí hiển thị banner và sản phẩm:
  - `dau_trang`: Đầu trang
  - `giua_trang`: Giữa trang
  - `cuoi_trang`: Cuối trang
- `status`: 
  - 0 = Chờ duyệt
  - 1 = Đang hiển thị (1 trong 3 vị trí)
  - 2 = Chờ hiển thị (đã duyệt nhưng chưa có slot)
  - 3 = Từ chối
- `ly_do_tu_choi`: Lý do admin từ chối
- `so_ngay_hien_thi`: Số ngày admin chọn để hiển thị
- `date_display_end`: Tính từ `date_display_start + (so_ngay_hien_thi * 86400)`

---

## 4. LUỒNG XỬ LÝ CHI TIẾT

### 4.1. Luồng NCC gửi yêu cầu

```
1. NCC đăng nhập → Truy cập /ncc/add-yeucau
2. Kiểm tra số lượng yêu cầu:
   - SELECT COUNT(*) FROM ncc_yeu_cau_banner_sanpham 
     WHERE ncc_id = ncc_id AND status != 3
   - Nếu >= 2 → Thông báo lỗi, không cho tạo mới
3. Upload banner:
   - Chọn file
   - Validate kích thước:
     * Banner dọc: 
       - Chiều cao = 256px (cố định)
       - Chiều rộng = (screenWidth - 16) / 2 (tùy theo màn hình)
       - Tỉ lệ width/height: khoảng 0.67 - 0.78 (tolerance ±0.05)
       - Ví dụ: 172x256px (màn hình 360px), 199x256px (màn hình 414px)
     * Banner ngang: width/height ≈ 0.33 (1/3, tolerance ±0.05)
   - Lưu file vào /uploads/banner-ncc/
4. Nhập link banner (tùy chọn):
   - Input text để nhập URL
5. Chọn sản phẩm:
   - Load danh sách sản phẩm: SELECT * FROM sanpham WHERE shop = ncc_id AND status = 1
   - Hiển thị danh sách dạng grid, click vào sản phẩm để chọn (không dùng checkbox)
   - Sản phẩm được chọn sẽ có màu nền xanh lá cây
   - Lưu trữ danh sách sản phẩm đã chọn vào localStorage để giữ lại khi tìm kiếm/phân trang
   - Validate: Phải chọn đúng 10 sản phẩm
6. Submit form (AJAX):
   - Validate dữ liệu
   - Upload banner (FormData)
   - Lưu vào database:
     * INSERT INTO ncc_yeu_cau_banner_sanpham
     * status = 0 (chờ duyệt)
     * date_created = time()
     * banner_link = link đã nhập (nếu có)
   - Xóa localStorage sau khi thành công
7. Thông báo thành công → Redirect về danh sách
```

### 4.1.1. Luồng NCC sửa yêu cầu

```
1. NCC truy cập /ncc/list-yeucau
2. Click nút "Sửa" trên yêu cầu (chỉ hiện khi status = 0 hoặc 3)
3. Truy cập /ncc/edit-yeucau?id=yeu_cau_id
4. Form sửa hiển thị với dữ liệu hiện tại:
   - Banner hiện tại (preview)
   - Input upload banner mới (tùy chọn)
   - Input link banner (có thể sửa)
   - Danh sách sản phẩm đã chọn (có thể thay đổi)
5. NCC chỉnh sửa và submit (AJAX):
   - Nếu có banner mới → Upload và xóa banner cũ
   - Cập nhật link banner
   - Cập nhật danh sách sản phẩm
   - Nếu status = 3 (từ chối):
     * Tự động chuyển status = 0 (chờ duyệt)
     * Xóa ly_do_tu_choi
   - date_updated = time()
6. Thông báo thành công → Redirect về danh sách
```

### 4.1.2. Luồng NCC xóa yêu cầu

```
1. NCC truy cập /ncc/list-yeucau
2. Click nút "Xóa" trên yêu cầu (chỉ hiện khi status = 0 hoặc 3)
3. Xác nhận xóa
4. Gửi AJAX request:
   - Lấy banner_path từ database
   - Xóa file banner: unlink(banner_path)
   - DELETE FROM ncc_yeu_cau_banner_sanpham WHERE id = yeu_cau_id AND ncc_id = ncc_id
5. Thông báo thành công → Reload trang
```

### 4.2. Luồng Admin duyệt yêu cầu

```
1. Admin truy cập /admincp/list-yeucau
2. Xem danh sách yêu cầu với tìm kiếm và lọc theo trạng thái
3. Click "Duyệt" → Mở modal:
   - Hiển thị banner preview
   - Hiển thị link banner (nếu có)
   - Hiển thị 10 sản phẩm (grid layout)
   - Chọn vị trí hiển thị: Đầu trang / Giữa trang / Cuối trang (bắt buộc)
   - Nhập số ngày hiển thị (1-30 ngày)
   - Hiển thị thông tin vị trí: "Vị trí này đang trống" hoặc "Vị trí này đã có X yêu cầu đang hiển thị"
4. Submit duyệt (AJAX):
   - Kiểm tra số lượng yêu cầu đang hiển thị tại vị trí đã chọn:
     * SELECT COUNT(*) FROM ncc_yeu_cau_banner_sanpham 
       WHERE status = 1 AND vi_tri_hien_thi = 'vi_tri_da_chon'
   - Nếu vị trí đó chưa có yêu cầu đang hiển thị (count = 0): 
       - status = 1 (đang hiển thị)
       - date_display_start = time()
       - date_display_end = time() + (so_ngay_hien_thi * 86400)
       - vi_tri_hien_thi = vị trí đã chọn
   - Nếu vị trí đó đã có yêu cầu đang hiển thị (count >= 1):
       - status = 2 (chờ hiển thị)
       - vi_tri_hien_thi = vị trí đã chọn
   - date_approved = time()
   - admin_approved_id = admin_user_id
5. Cập nhật database
6. Thông báo thành công → Reload trang
```

### 4.3. Luồng Tự động cập nhật trạng thái

```
1. Cron job chạy định kỳ (mỗi phút/giờ)
2. Query: SELECT * FROM ncc_yeu_cau_banner_sanpham 
          WHERE status = 1 AND date_display_end < UNIX_TIMESTAMP()
3. Với mỗi yêu cầu hết hạn:
   - UPDATE status = 0 (chờ duyệt)
   - date_display_start = NULL
   - date_display_end = NULL
   - so_ngay_hien_thi = NULL
   - vi_tri_hien_thi = NULL
   - Giải phóng vị trí hiển thị
4. KHÔNG tự động đưa yêu cầu "chờ hiển thị" lên
   - Admin phải duyệt lại yêu cầu với thời gian mới
```

### 4.4. Luồng Admin từ chối yêu cầu

```
1. Admin click "Từ chối" → Mở modal
2. Nhập lý do từ chối (bắt buộc)
3. Submit:
   - UPDATE ncc_yeu_cau_banner_sanpham 
     SET status = 3, 
         ly_do_tu_choi = 'lý do',
         date_updated = time()
     WHERE id = request_id
4. Thông báo thành công
```

### 4.5. Luồng Admin sửa yêu cầu

```
1. Admin truy cập /admincp/list-yeucau
2. Click nút "Sửa" trên yêu cầu (chỉ hiện khi status = 1 hoặc 2)
3. Mở modal sửa:
   - Hiển thị vị trí hiển thị hiện tại (select, có thể thay đổi)
   - Hiển thị số ngày hiển thị hiện tại (input number, có thể thay đổi)
   - Hiển thị thông tin vị trí khi chọn vị trí mới
4. Admin chỉnh sửa và submit (AJAX):
   - Validate vị trí và số ngày
   - Kiểm tra vị trí mới có trống không (trừ chính yêu cầu này)
   - Cập nhật:
     * vi_tri_hien_thi = vị trí mới
     * so_ngay_hien_thi = số ngày mới
     * Tính lại date_display_end dựa trên date_display_start và số ngày mới
   - Nếu đổi vị trí và vị trí mới trống, status = 2 → tự động chuyển status = 1
   - date_updated = time()
5. Thông báo thành công → Reload trang
```

### 4.6. Luồng Admin xóa yêu cầu

```
1. Admin click "Xóa" → Confirm dialog
2. Nếu confirm (AJAX):
   - Lấy banner_path từ database
   - Xóa file banner: unlink(banner_path)
   - DELETE FROM ncc_yeu_cau_banner_sanpham WHERE id = request_id
3. Thông báo thành công → Reload trang
```

---

## 5. GIAO DIỆN VÀ TRẢI NGHIỆM NGƯỜI DÙNG

### 5.1. Giao diện NCC

#### 5.1.1. Trang tạo yêu cầu (`/ncc/add-yeucau`)
- **Form upload banner:**
  - Input file upload
  - Preview banner sau khi chọn
  - Hiển thị kích thước và loại banner (dọc/ngang)
  - Thông báo lỗi nếu kích thước không đúng
  
- **Input link banner:**
  - Input text để nhập URL (tùy chọn)
  - Link sẽ được lưu vào database
  
- **Form chọn sản phẩm:**
  - Danh sách sản phẩm dạng grid
  - Click vào sản phẩm để chọn (không dùng checkbox)
  - Sản phẩm được chọn có màu nền xanh lá cây
  - Hiển thị: Ảnh, tên, giá
  - Tìm kiếm sản phẩm (theo tên) - lưu trữ sản phẩm đã chọn vào localStorage
  - Phân trang - lưu trữ sản phẩm đã chọn vào localStorage
  - Bộ đếm: "Đã chọn: X/10 sản phẩm"
  - Disable submit nếu chưa chọn đủ 10 sản phẩm
  - Sử dụng localStorage để giữ lại sản phẩm đã chọn khi tìm kiếm/phân trang

- **Nút gửi yêu cầu:**
  - Disable nếu chưa đủ điều kiện
  - Loading overlay khi submit (AJAX)
  - Thông báo kết quả bằng overlay (không dùng alert)
  - Xóa localStorage sau khi thành công

#### 5.1.2. Trang danh sách yêu cầu (`/ncc/list-yeucau`)
- Hiển thị tất cả yêu cầu của NCC:
  - Banner preview
  - Số lượng sản phẩm
  - Link banner (nếu có, hiển thị icon link)
  - Trạng thái (badge màu)
  - Vị trí hiển thị (nếu đã duyệt)
  - Thời gian tạo
  - Thời gian duyệt (nếu có)
  - Thời gian hiển thị đến (nếu đã duyệt)
  - Lý do từ chối (nếu bị từ chối)
- Nút "Gửi yêu cầu mới" (chỉ hiện khi chưa đạt giới hạn 2 yêu cầu)
- Cảnh báo: "(đã đạt giới hạn gửi yêu cầu)" sau tổng số yêu cầu
- Phân trang
- Nút "Sửa" và "Xóa" (chỉ hiện khi status = 0 hoặc 3)

#### 5.1.3. Trang sửa yêu cầu (`/ncc/edit-yeucau?id=yeu_cau_id`)
- **Form sửa:**
  - Hiển thị banner hiện tại (preview)
  - Input upload banner mới (tùy chọn, nếu có sẽ xóa banner cũ)
  - Input link banner (có thể sửa)
  - Danh sách sản phẩm đã chọn (có thể thay đổi, tương tự trang tạo)
  - Sử dụng localStorage để giữ lại sản phẩm đã chọn
- **Nút hành động:**
  - "Lưu thay đổi" - submit AJAX
  - "Quay lại" - về danh sách
- **Lưu ý:**
  - Nếu status = 3 (từ chối) → Tự động chuyển về status = 0 (chờ duyệt) khi lưu

### 5.2. Giao diện Admin

#### 5.2.1. Trang danh sách yêu cầu (`/admincp/list-yeucau`)
- **Bảng danh sách:**
  - Cột: STT, Banner (preview), Thông tin (Shop, Số SP, Loại banner, Lý do từ chối), Link banner, Vị trí, Trạng thái, Thời gian, Hành động
  - Tìm kiếm theo tên shop (search box)
  - Lọc theo trạng thái (dropdown): Tất cả, Chờ duyệt, Đang hiển thị, Chờ hiển thị, Từ chối
  - Hiển thị tổng số yêu cầu
  - Phân trang

- **Các nút hành động:**
  - "Duyệt" (màu xanh) - chỉ hiện khi status = 0 hoặc 2
  - "Từ chối" (màu vàng) - chỉ hiện khi status = 0 hoặc 2
  - "Sửa" (màu xanh dương) - chỉ hiện khi status = 1 hoặc 2
  - "Xóa" (màu đỏ) - luôn hiện

#### 5.2.2. Modal/Form duyệt yêu cầu
- Preview banner lớn
- Danh sách 10 sản phẩm (grid)
- Select: Vị trí hiển thị (bắt buộc):
  - Đầu trang
  - Giữa trang
  - Cuối trang
- Input: Số ngày hiển thị (number, min=1, max=30)
- Thông báo: "Vị trí [tên vị trí] hiện có X/1 yêu cầu đang hiển thị"
- Nút "Duyệt và hiển thị ngay" hoặc "Duyệt và chờ hiển thị"

#### 5.2.3. Modal từ chối yêu cầu
- Textarea: Lý do từ chối (required)
- Nút "Xác nhận từ chối"
- Sử dụng overlay loading khi xử lý

#### 5.2.4. Modal sửa yêu cầu
- Select: Vị trí hiển thị (bắt buộc):
  - Đầu trang
  - Giữa trang
  - Cuối trang
  - Hiển thị vị trí hiện tại (selected)
- Input: Số ngày hiển thị (number, min=1, max=30)
  - Hiển thị số ngày hiện tại
- Thông báo: "Vị trí này đang trống" hoặc "Vị trí này đã có X yêu cầu đang hiển thị"
- Nút "Lưu thay đổi"
- Sử dụng overlay loading khi xử lý

---

## 6. VALIDATION VÀ RÀNG BUỘC

### 6.1. Validation bên NCC

**Banner:**
- Bắt buộc upload (khi tạo mới)
- Tùy chọn upload mới (khi sửa)
- Định dạng: jpg, jpeg, png, webp
- Kích thước tối đa: 5MB
- **Banner dọc**:
  - Chiều cao: 256px (cố định, bằng chiều cao 1 card sản phẩm)
  - Chiều rộng: (screenWidth - 16) / 2 (bằng chiều rộng 1 card sản phẩm)
    - Ví dụ: màn hình 360px → 172px
    - Ví dụ: màn hình 414px → 199px
  - Tỉ lệ width/height: khoảng 0.67 - 0.78 (tolerance ±0.05)
  - **Lưu ý**: Banner dọc có kích thước bằng 1 card sản phẩm, có thể đặt cạnh các card sản phẩm trong phần gợi ý
- **Banner ngang**:
  - Tỉ lệ width/height ≈ 0.33 (1/3, tolerance ±0.05)
  - Chiều cao: (screenWidth / 3).clamp(100.0, 150.0) — tối đa 150px
  - Chiều rộng: toàn màn hình

**Link banner:**
- Tùy chọn (có thể để trống)
- Nếu có, phải là URL hợp lệ

**Sản phẩm:**
- Bắt buộc chọn đúng 10 sản phẩm
- Sản phẩm phải thuộc NCC đó
- Sản phẩm phải có status = 1 (đã duyệt)
- Không được chọn trùng sản phẩm

**Số lượng yêu cầu:**
- Mỗi NCC chỉ được gửi tối đa 2 yêu cầu (không tính yêu cầu bị từ chối - status = 3)

### 6.2. Validation bên Admin

**Duyệt yêu cầu:**
- Vị trí hiển thị: Bắt buộc chọn (đầu trang, giữa trang, cuối trang)
- Số ngày hiển thị: 1-30 ngày
- Kiểm tra số lượng yêu cầu đang hiển thị tại vị trí đã chọn (mỗi vị trí tối đa 1)

**Từ chối:**
- Lý do từ chối: Bắt buộc, không được để trống

**Sửa yêu cầu (Admin):**
- Chỉ cho phép sửa khi status = 1 hoặc 2
- Vị trí hiển thị: Bắt buộc chọn
- Số ngày hiển thị: 1-30 ngày
- Kiểm tra vị trí mới có trống không (trừ chính yêu cầu này)

---

## 7. XỬ LÝ LỖI VÀ NGOẠI LỆ

### 7.1. Lỗi upload banner
- File quá lớn → Thông báo: "File banner không được vượt quá 5MB"
- Định dạng không đúng → Thông báo: "Chỉ chấp nhận file ảnh (jpg, jpeg, png, webp)"
- Kích thước không đúng:
  - Banner dọc → Thông báo: "Banner dọc phải có chiều cao 256px và chiều rộng phù hợp (tỉ lệ khoảng 0.67-0.78). Ví dụ: 172x256px hoặc 199x256px"
  - Banner ngang → Thông báo: "Banner ngang phải có tỉ lệ 1:3 (width/height ≈ 0.33)"

### 7.2. Lỗi chọn sản phẩm
- Chưa chọn đủ 10 sản phẩm → Thông báo: "Vui lòng chọn đúng 10 sản phẩm"
- Sản phẩm không thuộc NCC → Thông báo: "Sản phẩm không hợp lệ"
- Sản phẩm chưa được duyệt → Thông báo: "Sản phẩm chưa được duyệt trên sàn"

### 7.3. Lỗi số lượng yêu cầu
- Đã đạt giới hạn 2 yêu cầu → Thông báo: "Bạn đã đạt giới hạn 2 yêu cầu. Vui lòng xóa hoặc đợi yêu cầu cũ được xử lý."

### 7.4. Lỗi hệ thống
- Lỗi lưu database → Thông báo: "Có lỗi xảy ra, vui lòng thử lại"
- Lỗi upload file → Thông báo: "Không thể upload banner, vui lòng thử lại"

---

## 8. BẢO MẬT

### 8.1. Phân quyền
- NCC chỉ xem và tạo yêu cầu của chính mình
- Admin có quyền xem tất cả, duyệt, từ chối, xóa

### 8.2. Validation phía server
- Kiểm tra quyền truy cập
- Validate dữ liệu đầu vào
- Sanitize input để tránh SQL injection, XSS

### 8.3. Upload file
- Validate file type và size
- Đổi tên file để tránh conflict
- Lưu file vào thư mục an toàn

---

## 9. KẾ HOẠCH TRIỂN KHAI

### 9.1. Giai đoạn 1: Database và Backend
- Tạo bảng `ncc_yeu_cau_banner_sanpham` với cột `vi_tri_hien_thi`
- Tạo các function xử lý trong class

### 9.2. Giai đoạn 2: Chức năng NCC
- ✅ Trang tạo yêu cầu (`/ncc/add-yeucau`) - có validation số lượng tối đa 2
- ✅ Trang danh sách yêu cầu (`/ncc/list-yeucau`)
- ✅ Upload và validate banner
- ✅ Chọn sản phẩm (click để chọn, localStorage để giữ lại khi tìm kiếm/phân trang)
- ✅ Input link banner (tùy chọn)
- ✅ Trang sửa yêu cầu (`/ncc/edit-yeucau`) - chỉ khi status = 0 hoặc 3
- ✅ Chức năng xóa yêu cầu - chỉ khi status = 0 hoặc 3
- ✅ Tự động chuyển status từ 3 → 0 khi sửa yêu cầu bị từ chối

### 9.3. Giai đoạn 3: Chức năng Admin
- ✅ Trang danh sách yêu cầu (`/admincp/list-yeucau`) - hiển thị vị trí, link banner
- ✅ Duyệt yêu cầu (chọn vị trí hiển thị, số ngày) - modal với preview banner và sản phẩm
- ✅ Từ chối yêu cầu - modal với textarea lý do
- ✅ Sửa yêu cầu - chỉ sửa vị trí và số ngày hiển thị (status = 1 hoặc 2)
- ✅ Xóa yêu cầu - có thể xóa ở bất kỳ trạng thái nào
- ✅ Tìm kiếm theo tên shop
- ✅ Lọc theo trạng thái

### 9.4. Giai đoạn 4: Tự động hóa
- Cron job cập nhật trạng thái
- Tự động chuyển về chờ duyệt khi hết hạn (không tự động đưa lên hiển thị)

### 9.5. Giai đoạn 5: Testing và tối ưu
- Test các luồng xử lý
- Tối ưu hiệu năng
- Fix bugs

---

## 10. CẤU TRÚC FILE VÀ URL

### 10.1. Bên NCC

**Action files:**
- `ncc/action/add_yeucau.php` - Trang tạo yêu cầu
- `ncc/action/list_yeucau.php` - Trang danh sách yêu cầu
- `ncc/action/edit_yeucau.php` - Trang sửa yêu cầu

**Process files:**
- `ncc/process/add_yeucau.php` - Xử lý tạo yêu cầu (AJAX)
- `ncc/process/update_yeucau.php` - Xử lý sửa yêu cầu (AJAX)
- `ncc/process/delete_yeucau.php` - Xử lý xóa yêu cầu (AJAX)

**Template files:**
- `skin_ncc/box_action/add_yeucau.tpl` - Template trang tạo
- `skin_ncc/box_action/add_yeucau_form.tpl` - Form tạo yêu cầu
- `skin_ncc/box_action/list_yeucau.tpl` - Template danh sách
- `skin_ncc/box_action/tr_yeucau.tpl` - Template row trong danh sách
- `skin_ncc/box_action/edit_yeucau.tpl` - Template trang sửa
- `skin_ncc/box_action/edit_yeucau_form.tpl` - Form sửa yêu cầu

**URLs:**
- `/ncc/add-yeucau` - Tạo yêu cầu mới
- `/ncc/list-yeucau` - Danh sách yêu cầu
- `/ncc/edit-yeucau?id=xxx` - Sửa yêu cầu

### 10.2. Bên Admin

**Action files:**
- `admincp/action/list_yeucau.php` - Trang danh sách yêu cầu

**Process files:**
- `admincp/process/get_yeucau.php` - Lấy chi tiết yêu cầu (AJAX)
- `admincp/process/check_vitri.php` - Kiểm tra trạng thái vị trí (AJAX)
- `admincp/process/approve_yeucau.php` - Duyệt yêu cầu (AJAX)
- `admincp/process/reject_yeucau.php` - Từ chối yêu cầu (AJAX)
- `admincp/process/update_yeucau.php` - Sửa yêu cầu (AJAX)
- `admincp/process/delete_yeucau.php` - Xóa yêu cầu (AJAX)

**Template files:**
- `skin_cpanel/box_action/list_yeucau.tpl` - Template danh sách (có modals)
- `skin_cpanel/box_action/tr_yeucau.tpl` - Template row trong danh sách

**URLs:**
- `/admincp/list-yeucau` - Danh sách yêu cầu

### 10.3. Class Functions

**Trong `includes/class_ncc.php`:**
- `list_sanpham_duyet_ncc()` - Lấy danh sách sản phẩm đã duyệt của NCC
- `count_sanpham_duyet_ncc()` - Đếm số sản phẩm đã duyệt
- `check_so_luong_yeu_cau()` - Kiểm tra số lượng yêu cầu
- `list_yeu_cau_banner_sanpham_ncc()` - Danh sách yêu cầu của NCC
- `count_yeu_cau_banner_sanpham_ncc()` - Đếm số yêu cầu của NCC
- `get_yeu_cau_by_id()` - Lấy chi tiết yêu cầu theo ID
- `update_yeu_cau_banner_sanpham()` - Cập nhật yêu cầu (NCC)
- `delete_yeu_cau_banner_sanpham()` - Xóa yêu cầu (NCC)

**Trong `includes/class_cpanel.php`:**
- `list_yeu_cau_banner_sanpham_admin()` - Danh sách yêu cầu cho admin
- `count_yeu_cau_banner_sanpham_admin()` - Đếm số yêu cầu cho admin
- `approve_yeu_cau_banner_sanpham()` - Duyệt yêu cầu
- `reject_yeu_cau_banner_sanpham()` - Từ chối yêu cầu
- `update_yeu_cau_banner_sanpham_admin()` - Sửa yêu cầu (admin)
- `delete_yeu_cau_banner_sanpham_admin()` - Xóa yêu cầu (admin)

---

## 11. CÂU HỎI CẦN LÀM RÕ

1. **Số lượng sản phẩm:**
   - Có thể thay đổi số lượng sản phẩm (hiện tại 10) không?

2. **Thời gian hiển thị:**
   - Giới hạn số ngày hiển thị (min/max) - ✅ Đã implement: 1-30 ngày
   - Có thể gia hạn thời gian hiển thị không? - ✅ Đã implement: Admin có thể sửa số ngày

3. **Banner:**
   - Có thể chỉnh sửa yêu cầu sau khi gửi không? - ✅ Đã implement: NCC có thể sửa khi status = 0 hoặc 3

---

## 12. KẾT LUẬN

BA này mô tả chi tiết chức năng yêu cầu banner và sản phẩm từ NCC, đã được triển khai đầy đủ:

### ✅ Đã hoàn thành:

**Chức năng NCC:**
- ✅ Yêu cầu gồm 1 banner (dọc 256px cao, rộng bằng 1 card sản phẩm hoặc ngang tỉ lệ 1:3) và 10 sản phẩm
- ✅ Chỉ chọn sản phẩm đã duyệt của NCC đó
- ✅ Mỗi NCC chỉ được gửi tối đa 2 yêu cầu (không tính yêu cầu bị từ chối)
- ✅ Upload banner với validation kích thước
- ✅ Input link banner (tùy chọn)
- ✅ Chọn sản phẩm bằng cách click (không dùng checkbox)
- ✅ Sử dụng localStorage để giữ lại sản phẩm đã chọn khi tìm kiếm/phân trang
- ✅ Sửa yêu cầu (khi status = 0 hoặc 3) - tự động chuyển từ "từ chối" về "chờ duyệt"
- ✅ Xóa yêu cầu (khi status = 0 hoặc 3)
- ✅ Xem danh sách yêu cầu với đầy đủ thông tin

**Chức năng Admin:**
- ✅ Database lưu trữ yêu cầu với cột vị trí hiển thị (đầu trang, giữa trang, cuối trang)
- ✅ Database có cột `banner_link` để lưu link banner
- ✅ Danh sách yêu cầu với tìm kiếm theo tên shop và lọc theo trạng thái
- ✅ Duyệt yêu cầu với 3 vị trí hiển thị (mỗi vị trí 1 yêu cầu), còn lại chờ hiển thị
- ✅ Modal duyệt hiển thị banner preview, link banner, và 10 sản phẩm
- ✅ Từ chối yêu cầu với lý do (bắt buộc)
- ✅ Sửa yêu cầu - chỉ sửa vị trí và số ngày hiển thị (khi status = 1 hoặc 2)
- ✅ Xóa yêu cầu (có thể xóa ở bất kỳ trạng thái nào)
- ✅ Tự động chuyển về chờ duyệt khi hết thời gian (cần cron job)

**Giao diện và UX:**
- ✅ Sử dụng overlay loading thay vì alert()
- ✅ Thông báo lỗi rõ ràng khi vượt quá giới hạn yêu cầu
- ✅ Hiển thị cảnh báo khi đã đạt giới hạn
- ✅ Responsive design

**Cần hoàn thiện:**
- ⏳ Cron job tự động cập nhật trạng thái khi hết thời gian hiển thị

