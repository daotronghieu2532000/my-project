# 📋 Business Analysis: Gửi Sản Phẩm & Đơn Hàng trong Chat

## 🎯 Mục đích
Cho phép người dùng gửi sản phẩm hoặc đơn hàng vào chat với nhà bán để:
- **Sản phẩm**: Hỏi về sản phẩm cụ thể (giá, tồn kho, thông tin kỹ thuật, v.v.)
- **Đơn hàng**: Hỏi về đơn hàng đã mua (trạng thái, vận chuyển, đổi trả, v.v.)

## 🔍 Phân tích Database & API

### 1. **Xác định Shop ID trong Chat**

**Nguồn dữ liệu:**
- `ChatScreen` đã có `widget.shopId` - đây là shop_id của nhà bán đang chat
- `chat_sessions_ncc` table có `shop_id` và `customer_id`

**Cách lấy:**
```dart
// Trong ChatScreen
final int shopId = widget.shopId; // ✅ Đã có sẵn
```

---

### 2. **Lấy Sản Phẩm của Shop**

**Database:**
- Table: `sanpham`
- Field: `shop` (int) - shop_id của nhà bán
- Field: `active` (int) - 0 = hiển thị, 1 = ẩn

**API hiện có:**
- `search_products.php` - tìm kiếm sản phẩm (có thể filter theo shop)
- `shop_detail` API - lấy sản phẩm của shop (đã có trong `api_service.dart`)

**Cách lấy:**
```sql
-- Query lấy sản phẩm của shop
SELECT id, tieu_de, minh_hoa, gia_moi, gia_cu, link, kho
FROM sanpham
WHERE shop = {shop_id}
AND active = 0  -- Chỉ lấy sản phẩm đang hiển thị
ORDER BY date_post DESC
LIMIT 50
```

**API cần tạo mới:**
```
GET /api/v1/chat_products?shop_id={shop_id}&user_id={user_id}&page=1&limit=50
```

---

### 3. **Lấy Đơn Hàng của User với Shop cụ thể**

**Database:**
- Table: `donhang`
- Field: `user_id` (int) - ID người dùng
- Field: `shop_id` (varchar) - **CÓ THỂ CHỨA NHIỀU SHOP_ID** (phân cách bằng dấu phẩy)
- Field: `sanpham` (text) - JSON chứa danh sách sản phẩm, mỗi sản phẩm có `shop` field

**Vấn đề:**
- `donhang.shop_id` là VARCHAR, có thể chứa: `"123,456,789"` hoặc `"123"`
- Cần parse và check xem shop_id có trong danh sách không
- Hoặc parse `sanpham` JSON và check `shop` của từng sản phẩm

**Cách lấy chính xác:**

**Option 1: Parse shop_id từ field `shop_id`**
```sql
-- Tìm đơn hàng có shop_id trong danh sách
SELECT * FROM donhang
WHERE user_id = {user_id}
AND (
    shop_id = '{shop_id}'  -- Trường hợp shop_id đơn lẻ
    OR FIND_IN_SET('{shop_id}', shop_id) > 0  -- Trường hợp shop_id là danh sách
)
ORDER BY date_post DESC
LIMIT 20
```

**Option 2: Parse từ `sanpham` JSON (CHÍNH XÁC HƠN)**
```php
// Trong orders_list.php, đã có logic parse sanpham JSON
// Mỗi product có thể có shop_id từ sanpham.shop
// Filter đơn hàng chỉ lấy những đơn có ít nhất 1 sản phẩm thuộc shop_id
```

**API cần tạo mới:**
```
GET /api/v1/chat_orders?user_id={user_id}&shop_id={shop_id}&page=1&limit=20
```

**Logic filter trong API:**
```php
// 1. Lấy tất cả đơn hàng của user
// 2. Parse sanpham JSON
// 3. Check xem có sản phẩm nào có shop = shop_id không
// 4. Chỉ trả về đơn hàng có ít nhất 1 sản phẩm thuộc shop_id
```

---

## 📐 Kiến trúc Giải pháp

### **Flow 1: Gửi Sản Phẩm**

```
User click icon "Gửi sản phẩm" 
  → Mở bottom sheet/dialog
  → Load danh sách sản phẩm của shop (API: /chat_products?shop_id=X)
  → User chọn sản phẩm
  → Gửi message với type="product", product_id=X
  → Hiển thị product card trong chat
```

### **Flow 2: Gửi Đơn Hàng**

```
User click icon "Gửi đơn hàng"
  → Mở bottom sheet/dialog
  → Load danh sách đơn hàng của user với shop (API: /chat_orders?user_id=X&shop_id=Y)
  → User chọn đơn hàng
  → Gửi message với type="order", order_id=X
  → Hiển thị order card trong chat
```

---

## 🗄️ Database Schema

### **Table: `chat_ncc` (đã có)**
```sql
-- Cần thêm fields:
ALTER TABLE chat_ncc ADD COLUMN message_type VARCHAR(20) DEFAULT 'text' COMMENT 'text|product|order';
ALTER TABLE chat_ncc ADD COLUMN product_id INT(10) DEFAULT 0 COMMENT 'ID sản phẩm nếu type=product';
ALTER TABLE chat_ncc ADD COLUMN order_id INT(10) DEFAULT 0 COMMENT 'ID đơn hàng nếu type=order';
```

---

## 🔌 API Endpoints Cần Tạo

### **1. GET /api/v1/chat_products**
**Mục đích:** Lấy danh sách sản phẩm của shop để gửi vào chat

**Parameters:**
- `shop_id` (required): ID của shop
- `user_id` (required): ID người dùng (để check quyền)
- `page` (optional): Trang (default: 1)
- `limit` (optional): Số lượng (default: 50)
- `keyword` (optional): Tìm kiếm sản phẩm

**Response:**
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "id": 123,
        "name": "Tên sản phẩm",
        "image": "https://socdo.vn/uploads/...",
        "price": 100000,
        "old_price": 150000,
        "discount_percent": 33,
        "stock": 10,
        "product_url": "https://socdo.vn/san-pham/123/..."
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 100,
      "total_pages": 2
    }
  }
}
```

**SQL Query:**
```sql
SELECT 
    s.id,
    s.tieu_de as name,
    s.minh_hoa as image,
    s.gia_moi as price,
    s.gia_cu as old_price,
    s.kho as stock,
    s.link,
    CASE 
        WHEN s.gia_cu > s.gia_moi AND s.gia_cu > 0 
        THEN CEIL(((s.gia_cu - s.gia_moi) / s.gia_cu) * 100)
        ELSE 0
    END as discount_percent
FROM sanpham s
WHERE s.shop = {shop_id}
AND s.active = 0
AND s.kho > 0  -- Chỉ lấy sản phẩm còn hàng
ORDER BY s.date_post DESC
LIMIT {limit} OFFSET {offset}
```

---

### **2. GET /api/v1/chat_orders**
**Mục đích:** Lấy danh sách đơn hàng của user với shop cụ thể

**Parameters:**
- `user_id` (required): ID người dùng
- `shop_id` (required): ID của shop
- `page` (optional): Trang (default: 1)
- `limit` (optional): Số lượng (default: 20)

**Response:**
```json
{
  "success": true,
  "data": {
    "orders": [
      {
        "id": 456,
        "ma_don": "DH20250101001",
        "status": 5,
        "status_text": "Giao thành công",
        "tongtien": 500000,
        "tongtien_formatted": "500,000đ",
        "date_post": 1704067200,
        "date_post_formatted": "01/01/2025 10:00",
        "product_count": 3,
        "products": [
          {
            "id": 123,
            "name": "Sản phẩm 1",
            "image": "https://...",
            "quantity": 2,
            "price": 100000
          }
        ]
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 5,
      "total_pages": 1
    }
  }
}
```

**SQL Query Logic:**
```php
// 1. Lấy tất cả đơn hàng của user
$orders_query = "SELECT * FROM donhang WHERE user_id = {user_id} ORDER BY date_post DESC";

// 2. Loop qua từng đơn hàng, parse sanpham JSON
foreach ($orders as $order) {
    $products = json_decode($order['sanpham'], true);
    $has_shop_product = false;
    
    // 3. Check xem có sản phẩm nào thuộc shop_id không
    foreach ($products as $product) {
        // Parse shop_id từ product
        $sp_id = $product['id'] ?? 0;
        
        // Query để lấy shop_id của sản phẩm
        $shop_query = "SELECT shop FROM sanpham WHERE id = $sp_id LIMIT 1";
        $shop_result = mysqli_query($conn, $shop_query);
        if ($shop_result && mysqli_num_rows($shop_result) > 0) {
            $shop_row = mysqli_fetch_assoc($shop_result);
            if ($shop_row['shop'] == $shop_id) {
                $has_shop_product = true;
                break;
            }
        }
    }
    
    // 4. Chỉ thêm đơn hàng nếu có sản phẩm thuộc shop
    if ($has_shop_product) {
        $filtered_orders[] = $order;
    }
}
```

**Tối ưu hơn (1 query duy nhất):**
```sql
-- Tìm đơn hàng có ít nhất 1 sản phẩm thuộc shop_id
SELECT DISTINCT d.*
FROM donhang d
INNER JOIN (
    SELECT 
        d2.id as order_id,
        JSON_EXTRACT(d2.sanpham, '$[*].id') as product_ids
    FROM donhang d2
    WHERE d2.user_id = {user_id}
) as order_products ON d.id = order_products.order_id
INNER JOIN sanpham s ON FIND_IN_SET(s.id, REPLACE(REPLACE(order_products.product_ids, '[', ''), ']', '')) > 0
WHERE s.shop = {shop_id}
ORDER BY d.date_post DESC
LIMIT {limit} OFFSET {offset}
```

**⚠️ Lưu ý:** JSON parsing trong MySQL phức tạp, nên dùng PHP để parse và filter.

---

## 🎨 UI/UX Design

### **1. Icon trong Chat Input**
- Thêm icon "📎" (attach) bên trái input field
- Click vào mở bottom sheet với 2 options:
  - "📦 Sản phẩm"
  - "🛒 Đơn hàng"

### **2. Bottom Sheet chọn Sản Phẩm**
```
┌─────────────────────────────┐
│  Chọn sản phẩm              │
├─────────────────────────────┤
│ [🔍 Tìm kiếm...]            │
├─────────────────────────────┤
│ ┌─────┐ Sản phẩm 1         │
│ │ IMG │ Giá: 100,000đ      │
│ └─────┘ Còn: 10 sản phẩm   │
├─────────────────────────────┤
│ ┌─────┐ Sản phẩm 2         │
│ │ IMG │ Giá: 200,000đ      │
│ └─────┘ Còn: 5 sản phẩm    │
└─────────────────────────────┘
```

### **3. Bottom Sheet chọn Đơn Hàng**
```
┌─────────────────────────────┐
│  Chọn đơn hàng              │
├─────────────────────────────┤
│ ┌─────┐ ĐH001              │
│ │ IMG │ 3 sản phẩm         │
│ └─────┘ 500,000đ • Đã giao │
├─────────────────────────────┤
│ ┌─────┐ ĐH002              │
│ │ IMG │ 2 sản phẩm         │
│ └─────┘ 300,000đ • Đang VC │
└─────────────────────────────┘
```

### **4. Hiển thị trong Chat**

**Product Card:**
```
┌─────────────────────────────┐
│ [IMG] Tên sản phẩm          │
│      100,000đ (150,000đ)    │
│      Còn: 10 sản phẩm      │
│      [Xem chi tiết →]       │
└─────────────────────────────┘
```

**Order Card:**
```
┌─────────────────────────────┐
│ Đơn hàng: DH001            │
│ 3 sản phẩm • 500,000đ      │
│ Trạng thái: Đã giao        │
│ [Xem chi tiết →]           │
└─────────────────────────────┘
```

---

## 📝 Implementation Steps

### **Phase 1: Database & API**
1. ✅ Thêm fields vào `chat_ncc` table
2. ✅ Tạo API `/chat_products` 
3. ✅ Tạo API `/chat_orders`
4. ✅ Test API với Postman/curl

### **Phase 2: Flutter Service**
1. ✅ Thêm methods vào `ChatService`:
   - `getChatProducts(shopId, userId)`
   - `getChatOrders(userId, shopId)`
2. ✅ Thêm method `sendProductMessage(phien, productId)`
3. ✅ Thêm method `sendOrderMessage(phien, orderId)`

### **Phase 3: UI Components**
1. ✅ Tạo `ProductSelectorBottomSheet`
2. ✅ Tạo `OrderSelectorBottomSheet`
3. ✅ Tạo `ProductMessageCard` widget
4. ✅ Tạo `OrderMessageCard` widget
5. ✅ Thêm icon attach vào chat input

### **Phase 4: Integration**
1. ✅ Integrate vào `ChatScreen`
2. ✅ Handle message type trong `_buildMessageBubble`
3. ✅ Handle tap vào product/order card (navigate to detail)
4. ✅ Test end-to-end

---

## 🔐 Security & Validation

1. **Check quyền:**
   - User chỉ có thể gửi sản phẩm/đơn hàng của shop đang chat
   - User chỉ có thể gửi đơn hàng của chính mình

2. **Validate:**
   - Check `shop_id` trong chat session
   - Check `user_id` trong JWT token
   - Check sản phẩm/đơn hàng có tồn tại không

---

## 📊 Data Flow

```
┌─────────┐
│  User   │
└────┬────┘
     │ Click "Gửi sản phẩm"
     ▼
┌─────────────────┐
│ ChatScreen      │
│ - shopId        │
│ - userId        │
└────┬────────────┘
     │ Call API
     ▼
┌─────────────────┐
│ /chat_products  │
│ ?shop_id=X      │
│ &user_id=Y      │
└────┬────────────┘
     │ Query DB
     ▼
┌─────────────────┐
│ SELECT * FROM   │
│ sanpham         │
│ WHERE shop = X  │
└────┬────────────┘
     │ Return products
     ▼
┌─────────────────┐
│ Show bottom     │
│ sheet with      │
│ products        │
└────┬────────────┘
     │ User selects
     ▼
┌─────────────────┐
│ Send message    │
│ type=product    │
│ product_id=123  │
└────┬────────────┘
     │ Save to DB
     ▼
┌─────────────────┐
│ INSERT INTO     │
│ chat_ncc        │
│ (message_type,  │
│  product_id)    │
└─────────────────┘
```

---

## ✅ Checklist

- [ ] Database: Thêm fields vào `chat_ncc`
- [ ] API: Tạo `/chat_products`
- [ ] API: Tạo `/chat_orders`
- [ ] Flutter: Thêm methods vào `ChatService`
- [ ] Flutter: Tạo UI components
- [ ] Flutter: Integrate vào `ChatScreen`
- [ ] Test: API endpoints
- [ ] Test: UI flow
- [ ] Test: Security & validation

---

## 🚀 Next Steps

1. **Review BA document này với team**
2. **Tạo API endpoints** (`chat_products.php`, `chat_orders.php`)
3. **Update Flutter models** (thêm `message_type`, `product_id`, `order_id`)
4. **Implement UI components**
5. **Test & Deploy**

