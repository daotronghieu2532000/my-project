# Tóm Tắt Cải Thiện Logic User Categories

## ✅ Các Cải Thiện Đã Thực Hiện

### 1. **Cải Thiện `getUserPreferredCategories()` - Lấy Category Từ Keyword**

**Trước:**
- ❌ Chỉ lấy category_id trực tiếp từ `user_behavior.category_id`
- ❌ Khi user search "dầu gội" nhưng không có category_id → không lấy được

**Sau:**
- ✅ Lấy category từ cả 2 nguồn:
  1. **Category_id trực tiếp** (ưu tiên cao, nhân frequency x2)
  2. **Từ keyword search** (JOIN với bảng `sanpham` để tìm category của sản phẩm có keyword trong tên)
- ✅ Sắp xếp theo frequency và last_activity
- ✅ Ưu tiên category_id trực tiếp hơn keyword search

**Ví dụ:**
```
User search "dầu gội":
- Query 1: Lấy category_id trực tiếp (nếu có) → [15, 20]
- Query 2: Tìm sản phẩm có "dầu gội" trong tên → category [15, 25, 30]
- Merge: [15 (frequency cao), 20, 25, 30]
```

### 2. **Cải Thiện Fallback Query - Ưu Tiên Category Phổ Biến**

**Trước:**
```sql
ORDER BY RAND($seed)  -- Random thuần túy
```

**Sau:**
```sql
ORDER BY c.cat_noibat DESC, product_count DESC, RAND($seed)
-- Ưu tiên: Nổi bật → Nhiều sản phẩm → Random
```

**Lợi ích:**
- ✅ Category nổi bật được ưu tiên
- ✅ Category có nhiều sản phẩm được ưu tiên
- ✅ Vẫn có random để đa dạng

### 3. **Tối Ưu Performance**

**Query 2 trong `getUserPreferredCategories()`:**
- Chỉ chạy khi Query 1 không đủ kết quả
- Sử dụng `INNER JOIN` thay vì subquery phức tạp
- Filter `active = 0` và `kho > 0` để chỉ lấy sản phẩm hợp lệ

## 📊 So Sánh Trước/Sau

### Scenario: User Search "Dầu Gội"

#### **Trước (Logic Cũ):**
```
1. getUserPreferredCategories() → []
   (vì category_id = NULL trong user_behavior)
   
2. Fallback → Random 4 categories
   → Có thể là: [Điện thoại, Laptop, Quần áo, Giày]
   ❌ Không liên quan đến "dầu gội"
```

#### **Sau (Logic Mới):**
```
1. getUserPreferredCategories():
   - Query 1: category_id trực tiếp → []
   - Query 2: Tìm sản phẩm "dầu gội" → category [15, 25]
   → Kết quả: [15, 25] (Mỹ phẩm/Chăm sóc cá nhân)
   
2. Bổ sung random:
   - Ưu tiên category phổ biến
   → Kết quả: [15, 25, 30, 40]
   ✅ Có category liên quan đến "dầu gội"
```

## 🎯 Kết Quả

### ✅ Đã Cải Thiện:
1. **Logic thông minh hơn**: Lấy category từ cả keyword search
2. **Fallback tốt hơn**: Ưu tiên category phổ biến thay vì random thuần túy
3. **Performance**: Query tối ưu hơn (chỉ chạy Query 2 khi cần)

### ⚠️ Còn Có Thể Cải Thiện (Chưa Làm):
1. **Cache layer**: Chưa có cache (có thể thêm Redis/Memcached)
2. **Database index**: Cần thêm index cho query keyword → category
3. **Query optimization**: Có thể gộp Query 1 và Query 2 thành 1 query với UNION

## 📝 Ghi Chú

- Logic mới sẽ chậm hơn một chút khi có nhiều keyword search (do JOIN với bảng `sanpham`)
- Nhưng kết quả chính xác hơn nhiều, đặc biệt khi user search keyword mà không có category_id
- Có thể tối ưu thêm bằng cách cache kết quả hoặc tạo bảng mapping keyword → category

