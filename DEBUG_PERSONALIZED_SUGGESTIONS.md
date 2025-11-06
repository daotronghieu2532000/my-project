# Hướng dẫn Debug Personalized Suggestions

## Tổng quan
Đã thêm debug logs vào cả Flutter và PHP để kiểm tra tại sao personalized suggestions chưa hoạt động.

## Các điểm cần kiểm tra

### 1. Kiểm tra Flutter Console Logs

Khi mở app và vào trang chủ, bạn sẽ thấy các logs sau:

**a) Lấy userId từ token:**
```
⚠️ Token is null - user chưa đăng nhập
```
HOẶC
```
🔍 JWT Payload: {...}
✅ Lấy được userId từ token: 8050
```

**b) Gọi API:**
```
👤 Đang tải gợi ý cá nhân hóa cho user_id: 8050
HOẶC
👤 User chưa đăng nhập - sử dụng gợi ý chung
```

**c) API Request:**
```
🔍 Product Suggestions API Endpoint: /product_suggest?type=user_based&user_id=8050&limit=100
📤 Đang gọi API: GET /product_suggest?type=user_based&user_id=8050&limit=100
📥 API Response Status: 200
```

**d) API Response:**
```
📋 API Response: success=true, message=...
📦 Số lượng sản phẩm trong response: 50
✅ Lấy gợi ý sản phẩm thành công: 50 sản phẩm
🆔 Product IDs (5 đầu tiên): 4715, 4530, 4713, ...
```

### 2. Kiểm tra PHP Error Logs

Kiểm tra error log của PHP (thường ở `/var/log/apache2/error.log` hoặc `error_log` trong thư mục API):

```
🔍 [product_suggest] user_based/personalized called with user_id=8050
🔍 [product_suggest] Getting behavior data for user_id=8050, limit=100
📦 [product_suggest] Behavior product IDs: [4715,4530,4713,...]
📂 [product_suggest] Preferred categories: [10,11]
🔑 [product_suggest] Search keywords: [...]
```

### 3. Các vấn đề có thể gặp

#### Vấn đề 1: UserId không được lấy từ token
**Triệu chứng:**
- Log: `⚠️ Token is null - user chưa đăng nhập`
- Hoặc: `⚠️ Không tìm thấy user_id trong token payload`

**Nguyên nhân:**
- JWT token không có trong SharedPreferences
- JWT payload có cấu trúc khác (có thể là `data.user_id` thay vì `user_id`)

**Giải pháp:**
- Đã cập nhật `TokenManager.getUserId()` để thử cả 2 vị trí: `payload['user_id']` và `payload['data']['user_id']`
- Kiểm tra log `🔍 JWT Payload: {...}` để xem cấu trúc thực tế

#### Vấn đề 2: API không được gọi với type=user_based
**Triệu chứng:**
- Log: `🔍 Gọi API với type=home_suggest (user chưa đăng nhập)`

**Nguyên nhân:**
- `userId` là null

**Giải pháp:**
- Kiểm tra xem user có đăng nhập không
- Kiểm tra JWT token có hợp lệ không

#### Vấn đề 3: API trả về ít hoặc không có sản phẩm
**Triệu chứng:**
- Log: `📦 Số lượng sản phẩm trong response: 0`
- Hoặc: `⚠️ API trả về thành công nhưng không có sản phẩm nào`

**Nguyên nhân:**
- Không có hành vi người dùng trong DB
- SQL query có vấn đề
- Không có sản phẩm phù hợp với điều kiện

**Giải pháp:**
- Kiểm tra PHP error logs để xem SQL query
- Kiểm tra DB có dữ liệu user_behavior cho user_id=8050
- Test trực tiếp API với Postman/curl

### 4. Test trực tiếp API

**Test với curl:**
```bash
curl -X GET "https://api.socdo.vn/product_suggest?type=user_based&user_id=8050&limit=100" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Test với Postman:**
- Method: GET
- URL: `https://api.socdo.vn/product_suggest?type=user_based&user_id=8050&limit=100`
- Headers: `Authorization: Bearer YOUR_JWT_TOKEN`

**Kết quả mong đợi:**
```json
{
  "success": true,
  "message": "Lấy gợi ý sản phẩm thành công",
  "data": {
    "type": "user_based",
    "total_products": 50,
    "products": [...]
  }
}
```

### 5. Kiểm tra Database

**Kiểm tra user_behavior table:**
```sql
SELECT * FROM user_behavior 
WHERE user_id = 8050 
ORDER BY created_at DESC 
LIMIT 10;
```

**Kiểm tra hàm helper:**
```sql
-- Test getUserBasedProductIds
SELECT 
  ub.product_id,
  SUM(
    CASE ub.behavior_type
      WHEN 'order' THEN 5
      WHEN 'cart' THEN 4
      WHEN 'favorite' THEN 3
      WHEN 'view' THEN 2
      WHEN 'search' THEN 1
      ELSE 0
    END
  ) as score,
  COUNT(*) as behavior_count
FROM user_behavior ub
WHERE ub.user_id = 8050
AND ub.created_at >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY))
AND ub.product_id IS NOT NULL
AND ub.behavior_type IN ('order', 'cart', 'favorite', 'view')
GROUP BY ub.product_id
ORDER BY score DESC, behavior_count DESC, ub.created_at DESC
LIMIT 100;
```

### 6. Checklist Debug

- [ ] User đã đăng nhập (có JWT token)
- [ ] JWT token có chứa user_id
- [ ] Flutter logs hiển thị userId đúng
- [ ] API endpoint được gọi với type=user_based
- [ ] PHP logs hiển thị user_id đúng
- [ ] DB có dữ liệu user_behavior cho user_id
- [ ] API trả về sản phẩm (không phải empty)
- [ ] UI hiển thị sản phẩm mới

## Next Steps

1. Chạy app và xem Flutter console logs
2. Kiểm tra PHP error logs
3. Test API trực tiếp với user_id=8050
4. So sánh kết quả với dữ liệu trong DB
5. Báo lại kết quả để tiếp tục debug

