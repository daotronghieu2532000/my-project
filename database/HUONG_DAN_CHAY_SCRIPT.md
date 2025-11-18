# Hướng dẫn chạy script tự động tạo đơn hàng và đánh giá

## 📋 Các bước thực hiện

### Bước 1: Kiểm tra và cấu hình
1. Mở file `database/auto_generate_orders_reviews.sql`
2. Kiểm tra `shop_id` (mặc định: 23933) - đảm bảo đúng shop bạn muốn tạo đánh giá
3. Kiểm tra số lượng user_id có sẵn (script cần user_id từ 1-500 trong bảng `user_info`)

### Bước 2: Backup database (QUAN TRỌNG!)
```sql
-- Backup các bảng quan trọng trước khi chạy
CREATE TABLE donhang_backup AS SELECT * FROM donhang;
CREATE TABLE product_comments_backup AS SELECT * FROM product_comments;
CREATE TABLE product_rating_stats_backup AS SELECT * FROM product_rating_stats;
```

### Bước 3: Chạy script
**Cách 1: Chạy qua phpMyAdmin**
1. Đăng nhập phpMyAdmin
2. Chọn database `socdo`
3. Vào tab "SQL"
4. Copy toàn bộ nội dung file `auto_generate_orders_reviews.sql`
5. Paste vào và click "Go"

**Cách 2: Chạy qua command line**
```bash
mysql -u [username] -p [database_name] < database/auto_generate_orders_reviews.sql
```

**Cách 3: Chạy từng phần (nếu gặp lỗi)**
- Chạy phần tạo đơn hàng trước
- Kiểm tra kết quả
- Sau đó chạy phần tạo đánh giá

### Bước 4: Kiểm tra kết quả

```sql
-- Kiểm tra số đơn hàng đã tạo
SELECT COUNT(*) as total_orders 
FROM donhang 
WHERE shop_id = '23933' AND status = 5;

-- Kiểm tra số đánh giá đã tạo
SELECT 
    product_id, 
    COUNT(*) as total_reviews,
    AVG(rating) as avg_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4
FROM product_comments 
WHERE shop_id = 23933 AND status = 'approved' 
GROUP BY product_id;

-- Kiểm tra thống kê đánh giá
SELECT * FROM product_rating_stats WHERE shop_id = 23933;
```

## ⚠️ Lưu ý quan trọng

1. **Backup trước khi chạy**: Script sẽ tạo nhiều dữ liệu, nên backup để có thể rollback nếu cần
2. **Thời gian chạy**: Script có thể mất vài phút tùy số lượng sản phẩm
3. **Kiểm tra user_id**: Đảm bảo có đủ user_id từ 1-500 trong bảng `user_info`
4. **Số lượng đánh giá**: Mỗi sản phẩm sẽ có khoảng 30-50 đánh giá (trung bình 40)
5. **Tỉ lệ rating**: 80% 5 sao, 20% 4 sao

## 🔄 Nếu muốn chạy lại

Nếu muốn xóa và tạo lại:
```sql
-- Xóa đánh giá cũ (cẩn thận!)
DELETE FROM product_comments WHERE shop_id = 23933;
DELETE FROM product_rating_stats WHERE shop_id = 23933;

-- Sau đó chạy lại script
```

## ✅ Kết quả mong đợi

- Mỗi sản phẩm có khoảng 30-50 đánh giá
- 80% đánh giá 5 sao, 20% đánh giá 4 sao
- Tất cả đánh giá có `is_verified_purchase = 1` (đã mua hàng)
- Thống kê đánh giá được tự động cập nhật

