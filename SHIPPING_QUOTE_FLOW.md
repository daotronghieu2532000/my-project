# 📦 Giải Thích Flow: Từ Giỏ Hàng Đến Thanh Toán

## 🎯 Tổng Quan

Hệ thống shipping quote đã được tối ưu với **retry, timeout, fallback, cache, và debounce** để đảm bảo:
- ✅ **Reliability**: Vẫn hoạt động khi API fail
- ✅ **Performance**: Cache giảm số lần gọi API
- ✅ **User Experience**: Phản hồi nhanh, không bị treo
- ✅ **Accuracy**: Fallback tính chính xác dựa trên giá thực tế

---

## 📋 Flow Chi Tiết

### **BƯỚC 1: User Thêm Sản Phẩm Vào Giỏ Hàng**

```
User click "Thêm vào giỏ" 
  ↓
CartService.addItem(item)
  ↓
- Kiểm tra item đã tồn tại? 
  → Có: Tăng quantity
  → Không: Thêm mới
  ↓
- notifyListeners() → UI tự động cập nhật
  ↓
- _saveCart() → Lưu vào SharedPreferences (local storage)
  ↓
- _saveCartBehavior() → Lưu hành vi vào database (async, không block UI)
```

**💡 Lưu ý:**
- Giỏ hàng được lưu local ngay lập tức
- Behavior tracking chạy async, không ảnh hưởng UI
- UI cập nhật ngay qua `notifyListeners()`

---

### **BƯỚC 2: User Vào Trang Checkout**

```
User navigate đến CheckoutScreen
  ↓
CheckoutScreen.build()
  ↓
OrderSummarySection được render
  ↓
OrderSummarySection.initState()
  ↓
_load() được gọi
```

---

### **BƯỚC 3: Tính Phí Ship (OrderSummarySection._load)**

```
_load() được gọi
  ↓
✅ DEBOUNCE (500ms)
  → Nếu user thay đổi items nhanh, chỉ gọi API 1 lần sau 500ms
  ↓
_loadShippingQuote()
  ↓
1. Kiểm tra đăng nhập
   → Chưa đăng nhập: Hiển thị "Vui lòng đăng nhập"
   → Đã đăng nhập: Tiếp tục
  ↓
2. Lấy items đã chọn từ CartService
   → Chỉ lấy items có isSelected = true
   → Bao gồm: product_id, quantity, price (giá thực tế)
  ↓
3. Gọi ShippingQuoteService.getShippingQuote()
```

---

### **BƯỚC 4: ShippingQuoteService - Xử Lý Thông Minh**

```
getShippingQuote(userId, items)
  ↓
┌─────────────────────────────────────────┐
│  BƯỚC 4.1: KIỂM TRA CACHE              │
└─────────────────────────────────────────┘
  ↓
Kiểm tra cache trong SharedPreferences
  → Cache key = "shipping_quote_cache_{userId}_{product_ids}"
  ↓
Có cache và chưa hết hạn (10 phút)?
  ✅ CÓ → Trả về ngay (0ms, không gọi API)
  ❌ KHÔNG → Tiếp tục
  ↓
┌─────────────────────────────────────────┐
│  BƯỚC 4.2: GỌI API VỚI RETRY            │
└─────────────────────────────────────────┘
  ↓
Thử gọi API (tối đa 3 lần):
  Attempt 1: Gọi API
    → Thành công? ✅ Trả về + Lưu cache
    → Thất bại? ❌ Chờ 1s → Attempt 2
  ↓
  Attempt 2: Gọi API lại
    → Thành công? ✅ Trả về + Lưu cache
    → Thất bại? ❌ Chờ 2s → Attempt 3
  ↓
  Attempt 3: Gọi API lần cuối
    → Thành công? ✅ Trả về + Lưu cache
    → Thất bại? ❌ Chuyển sang Fallback
  ↓
Timeout: Nếu API không phản hồi trong 15s → TimeoutException → Retry
  ↓
┌─────────────────────────────────────────┐
│  BƯỚC 4.3: FALLBACK (Nếu API Fail)      │
└─────────────────────────────────────────┘
  ↓
Tất cả retry đều fail?
  ✅ CÓ → Tính phí ship ước tính
  ↓
Tính toán fallback:
  1. Tính tổng giá trị đơn hàng từ giá thực tế
     → totalValue = Σ(price × quantity)
  2. Tính phí ship dựa trên giá trị:
     → < 500k: 30k
     → 500k - 1M: 25k
     → 1M - 2M: 20k
     → > 2M: 15k
  3. Tính ETA: "Dự kiến từ DD/MM - DD/MM"
  ↓
Trả về fallback quote với flag is_fallback = true
```

---

### **BƯỚC 5: Hiển Thị Kết Quả**

```
OrderSummarySection nhận được quote
  ↓
setState() → Cập nhật UI
  ↓
Hiển thị:
  - Phí vận chuyển: {fee}₫
  - Dự kiến: {eta_text}
  - Đơn vị vận chuyển: {provider}
  ↓
Nếu is_fallback = true:
  → Hiển thị cảnh báo: "⚠️ Đang sử dụng phí ship ước tính"
  → Vẫn cho phép checkout
```

---

## 🔄 Các Trường Hợp Đặc Biệt

### **Trường Hợp 1: User Thay Đổi Items Nhanh**

```
User bỏ chọn item A → Chọn item B → Bỏ chọn item B
  ↓
_load() được gọi 3 lần
  ↓
✅ DEBOUNCE hoạt động:
  - Hủy timer cũ
  - Tạo timer mới (500ms)
  - Chỉ gọi API 1 lần sau khi user dừng thao tác
  ↓
→ Tiết kiệm 2 API calls không cần thiết
```

### **Trường Hợp 2: API Bị Lỗi**

```
API trả về 500 error
  ↓
Retry lần 1: Fail
  → Chờ 1s
  ↓
Retry lần 2: Fail
  → Chờ 2s
  ↓
Retry lần 3: Fail
  ↓
✅ Fallback được kích hoạt
  → Tính phí ship ước tính
  → Hiển thị cảnh báo
  → User vẫn có thể checkout
```

### **Trường Hợp 3: API Chậm (Timeout)**

```
API không phản hồi sau 15s
  ↓
TimeoutException được throw
  ↓
Retry với timeout mới
  ↓
Nếu vẫn timeout sau 3 lần
  → Fallback được kích hoạt
```

### **Trường Hợp 4: Cache Hit**

```
User vào checkout lần 2 (trong 10 phút)
  ↓
Kiểm tra cache
  ↓
✅ Cache hit!
  → Trả về ngay (0ms)
  → Không gọi API
  → UI hiển thị ngay lập tức
```

---

## ⚡ Tối Ưu Đã Áp Dụng

### **1. Cache (10 phút)**
- ✅ Giảm số lần gọi API
- ✅ Phản hồi tức thì khi có cache
- ✅ Tự động expire sau 10 phút

### **2. Retry với Exponential Backoff**
- ✅ Retry 3 lần
- ✅ Delay tăng dần: 1s, 2s, 3s
- ✅ Xử lý timeout

### **3. Fallback Calculation**
- ✅ Dùng giá thực tế từ cart (không ước tính)
- ✅ Công thức phí ship hợp lý
- ✅ Vẫn cho phép checkout

### **4. Debounce (500ms)**
- ✅ Tránh gọi API quá nhiều lần
- ✅ Chỉ gọi khi user dừng thao tác

### **5. Timeout (15s)**
- ✅ Không để app bị treo
- ✅ Tự động retry hoặc fallback

---

## 📊 So Sánh: Trước vs Sau

| Tiêu Chí | Trước | Sau |
|----------|-------|-----|
| **API Fail** | ❌ Hiển thị "đang tính..." mãi | ✅ Fallback tự động |
| **Cache** | ❌ Không có | ✅ Cache 10 phút |
| **Retry** | ❌ Không có | ✅ Retry 3 lần |
| **Timeout** | ❌ Có thể treo app | ✅ Timeout 15s |
| **Debounce** | ❌ Gọi API mỗi lần thay đổi | ✅ Debounce 500ms |
| **Fallback Accuracy** | ❌ Ước tính 100k/sp | ✅ Dùng giá thực tế |

---

## 🎯 Kết Luận

Hệ thống đã được **tối ưu toàn diện** với:
- ✅ **Reliability**: Vẫn hoạt động khi API fail
- ✅ **Performance**: Cache + Debounce giảm API calls
- ✅ **User Experience**: Phản hồi nhanh, không bị treo
- ✅ **Accuracy**: Fallback tính chính xác dựa trên giá thực tế

**User có thể checkout ngay cả khi API shipping bị lỗi!** 🎉

