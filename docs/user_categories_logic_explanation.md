# Giải Thích Logic: User Categories Suggestions

## 📋 Tổng Quan

Hệ thống gợi ý danh mục dựa trên hành vi người dùng cho trang tìm kiếm, với fallback về random categories nếu chưa có hành vi.

## 🔍 Logic Hiện Tại

### 1. Flow Hoạt Động

```
User mở trang Search
    ↓
App gọi: getUserCategoriesSuggestions(userId, limit=4)
    ↓
API: /product_suggest?type=user_categories&user_id={userId}&limit=4
    ↓
Backend xử lý:
    1. Lấy category từ hành vi (getUserPreferredCategories)
    2. Nếu không đủ → bổ sung random
    3. Nếu không có → fallback random
    ↓
Trả về 4 categories → Hiển thị trên UI
```

### 2. Chi Tiết Logic Backend (`product_suggest.php`)

#### Case: `user_categories`

```php
1. Kiểm tra user_id > 0
   ├─ YES → Gọi getUserPreferredCategories($user_id, 10)
   │         └─ Lấy category_id từ user_behavior WHERE category_id IS NOT NULL
   │
   └─ NO → Bỏ qua, đi thẳng đến random

2. Nếu có category từ hành vi:
   ├─ Query: SELECT * FROM category_sanpham WHERE cat_id IN (...)
   └─ Lấy thông tin chi tiết (tên, ảnh, ...)

3. Nếu count < 4:
   ├─ Tính needed = 4 - count
   ├─ Query random: SELECT * FROM category_sanpham 
   │                WHERE cat_id NOT IN (đã chọn)
   │                ORDER BY RAND(seed)
   └─ Bổ sung vào danh sách

4. Nếu vẫn empty:
   └─ Fallback: Random 4 categories bất kỳ
```

### 3. Hàm `getUserPreferredCategories()`

**Query hiện tại:**
```sql
SELECT ub.category_id, COUNT(*) as frequency
FROM user_behavior ub
WHERE ub.user_id = $user_id
  AND ub.created_at >= $thirty_days_ago
  AND ub.category_id IS NOT NULL  -- ⚠️ CHỈ lấy category_id trực tiếp
GROUP BY ub.category_id
ORDER BY frequency DESC
LIMIT $limit
```

**Vấn đề:**
- ❌ Chỉ lấy category_id trực tiếp từ `user_behavior.category_id`
- ❌ Không phân tích keyword để tìm category liên quan
- ❌ Khi user search "dầu gội" nhưng không có category_id → không lấy được

## 🎯 Ví Dụ: User Search "Dầu Gội"

### Scenario 1: User đã có hành vi category trước đó
```
1. User search "dầu gội" → Lưu vào user_behavior:
   - behavior_type: 'search'
   - keyword: 'dầu gội'
   - category_id: 15 (từ sản phẩm đầu tiên trong kết quả)
   
2. getUserPreferredCategories() trả về: [15, 20, 25]
   → Category 15 (Mỹ phẩm/Chăm sóc cá nhân) được ưu tiên
   
3. Kết quả: Hiển thị 4 categories, trong đó có category 15
```

### Scenario 2: User mới, chưa có hành vi
```
1. getUserPreferredCategories() trả về: []
   
2. Logic fallback:
   → Random 4 categories có ảnh
   
3. Kết quả: 4 categories random (có thể là: Điện thoại, Laptop, Quần áo, Giày)
```

### Scenario 3: User search "dầu gội" nhưng category_id = NULL
```
1. User search "dầu gội" → Lưu vào user_behavior:
   - behavior_type: 'search'
   - keyword: 'dầu gội'
   - category_id: NULL  ⚠️ Vấn đề ở đây!
   
2. getUserPreferredCategories() trả về: []
   (vì WHERE category_id IS NOT NULL)
   
3. Fallback về random → Không liên quan đến "dầu gội"
```

## ⚠️ Vấn Đề Hiện Tại

### 1. **Thiếu Logic Phân Tích Keyword**
- Khi search "dầu gội", nếu không có category_id → không lấy được category liên quan
- Cần thêm logic: keyword → category (từ sản phẩm đã search)

### 2. **Chưa Tối Ưu Tốc Độ**
- ❌ Không có cache
- ❌ Query nhiều lần (getUserPreferredCategories + query category details)
- ❌ Không có index tối ưu cho keyword → category mapping

### 3. **Thiếu Logic Thông Minh**
- ❌ Không phân tích keyword để tìm category tương tự
- ❌ Không ưu tiên category từ search gần đây
- ❌ Không có decay theo thời gian (category cũ = ít quan trọng hơn)

## 🚀 Đề Xuất Cải Thiện

### 1. **Cải Thiện `getUserPreferredCategories()`**

**Thêm logic lấy category từ keyword:**

```php
function getUserPreferredCategories($conn, $user_id, $limit = 10) {
    // ... existing code ...
    
    // ===== CẢI THIỆN: Lấy category từ cả keyword search =====
    // Query 1: Lấy category_id trực tiếp (như cũ)
    $query1 = "SELECT ub.category_id, COUNT(*) as frequency
               FROM user_behavior ub
               WHERE ub.user_id = $user_id
                 AND ub.created_at >= $thirty_days_ago
                 AND ub.category_id IS NOT NULL
               GROUP BY ub.category_id
               ORDER BY frequency DESC";
    
    // Query 2: Lấy category từ keyword search (MỚI)
    // Tìm category của sản phẩm mà user đã search
    $query2 = "SELECT DISTINCT s.cat as category_ids
               FROM user_behavior ub
               JOIN sanpham s ON s.id IN (
                   SELECT id FROM sanpham 
                   WHERE tieu_de LIKE CONCAT('%', ub.keyword, '%')
                   LIMIT 10
               )
               WHERE ub.user_id = $user_id
                 AND ub.behavior_type = 'search'
                 AND ub.created_at >= $thirty_days_ago
                 AND ub.keyword IS NOT NULL
                 AND ub.category_id IS NULL";
    
    // Merge kết quả và tính frequency
    // ...
}
```

**Hoặc cách tối ưu hơn - Query duy nhất:**

```sql
SELECT 
    COALESCE(ub.category_id, 
             (SELECT SUBSTRING_INDEX(s.cat, ',', 1) 
              FROM sanpham s 
              WHERE s.tieu_de LIKE CONCAT('%', ub.keyword, '%') 
              LIMIT 1)
    ) as category_id,
    COUNT(*) as frequency,
    MAX(ub.created_at) as last_activity
FROM user_behavior ub
WHERE ub.user_id = $user_id
  AND ub.created_at >= $thirty_days_ago
  AND (
      ub.category_id IS NOT NULL 
      OR (ub.behavior_type = 'search' AND ub.keyword IS NOT NULL)
  )
GROUP BY category_id
ORDER BY frequency DESC, last_activity DESC
LIMIT $limit
```

### 2. **Thêm Cache Layer**

```php
// Trong product_suggest.php
$cache_key = "user_categories_{$user_id}_" . date('Y-m-d');
$cached = getCache($cache_key);

if ($cached !== false) {
    return $cached;
}

// ... logic lấy categories ...

// Cache 1 giờ
setCache($cache_key, $categories, 3600);
```

### 3. **Tối Ưu Query Performance**

**Thêm Index:**
```sql
-- Index cho query getUserPreferredCategories
ALTER TABLE user_behavior 
ADD INDEX idx_user_category_time (user_id, category_id, created_at);

-- Index cho keyword search
ALTER TABLE user_behavior 
ADD INDEX idx_user_keyword_time (user_id, behavior_type, keyword, created_at);
```

**Tối ưu Query trong `product_suggest.php`:**
```php
// Thay vì query riêng biệt, dùng JOIN
$query = "SELECT c.cat_id, c.cat_tieude, c.cat_minhhoa, 
                 COUNT(ub.id) as frequency
          FROM category_sanpham c
          LEFT JOIN user_behavior ub ON (
              ub.user_id = $user_id 
              AND ub.created_at >= $thirty_days_ago
              AND (
                  ub.category_id = c.cat_id
                  OR (ub.behavior_type = 'search' 
                      AND EXISTS (
                          SELECT 1 FROM sanpham s 
                          WHERE FIND_IN_SET(c.cat_id, s.cat) > 0
                          AND s.tieu_de LIKE CONCAT('%', ub.keyword, '%')
                      ))
              )
          )
          WHERE c.cat_minhhoa IS NOT NULL 
            AND c.cat_minhhoa != ''
          GROUP BY c.cat_id
          ORDER BY frequency DESC, c.cat_noibat DESC
          LIMIT $limit";
```

### 4. **Cải Thiện Logic Fallback**

```php
// Thay vì random thuần túy, ưu tiên category phổ biến
$fallback_query = "SELECT cat_id, cat_tieude, cat_minhhoa, 
                          (SELECT COUNT(*) FROM sanpham 
                           WHERE FIND_IN_SET(cat_id, cat) > 0 
                           AND active = 0 AND kho > 0) as product_count
                   FROM category_sanpham
                   WHERE cat_minhhoa IS NOT NULL 
                     AND cat_minhhoa != ''
                   ORDER BY cat_noibat DESC, product_count DESC, RAND($seed)
                   LIMIT $limit";
```

### 5. **Thêm Logic Phân Tích Keyword → Category**

```php
function getCategoriesFromKeyword($conn, $keyword, $limit = 5) {
    // Tìm category từ sản phẩm có keyword trong tên
    $query = "SELECT DISTINCT 
                 SUBSTRING_INDEX(s.cat, ',', 1) as category_id,
                 COUNT(*) as product_count
              FROM sanpham s
              WHERE s.tieu_de LIKE '%" . mysqli_real_escape_string($conn, $keyword) . "%'
                AND s.active = 0
                AND s.kho > 0
                AND s.cat IS NOT NULL
                AND s.cat != ''
              GROUP BY category_id
              ORDER BY product_count DESC
              LIMIT $limit";
    
    // ... execute và return category_ids
}
```

## 📊 So Sánh Performance

### Trước (Logic Hiện Tại):
```
1. getUserPreferredCategories() → 1 query
2. Query category details → 1 query  
3. Query random fallback → 1 query (nếu cần)
Total: 2-3 queries, ~50-100ms
```

### Sau (Logic Cải Thiện):
```
1. Query tối ưu với JOIN → 1 query
2. Cache check → <1ms (nếu hit)
Total: 1 query + cache, ~20-30ms (giảm 50-70%)
```

## 🎯 Kết Luận

### Logic Hiện Tại:
- ✅ Hoạt động cơ bản
- ✅ Có fallback random
- ⚠️ Chưa tối ưu tốc độ
- ⚠️ Thiếu logic phân tích keyword

### Cần Cải Thiện:
1. **Thêm logic lấy category từ keyword search**
2. **Tối ưu query (JOIN thay vì nhiều query)**
3. **Thêm cache layer**
4. **Thêm index database**
5. **Cải thiện fallback (ưu tiên category phổ biến)**

### Ưu Tiên:
1. **Cao**: Thêm logic keyword → category
2. **Trung bình**: Tối ưu query và cache
3. **Thấp**: Cải thiện fallback logic

