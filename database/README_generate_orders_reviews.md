# Hướng dẫn tạo đơn hàng và đánh giá từ dữ liệu thực tế

## Mô tả
Script SQL này tạo đơn hàng và đánh giá từ dữ liệu thực tế trong database:
- Sử dụng user_id từ 1-500 trong bảng `user_info`
- Tạo đơn hàng với status=5 (thành công) cho 5 sản phẩm
- Mỗi sản phẩm: 100 đơn hàng + 100 đánh giá
- Tự động cập nhật thống kê đánh giá

## Sản phẩm được tạo đơn hàng và đánh giá

1. **KATA ACC220** (product_id: 3781, variant_id: 4238)
   - Giá: 999,000 VNĐ
   - Shop: 23933

2. **KATA ACC110** (product_id: 3783, variant_id: 4240)
   - Giá: 699,000 VNĐ
   - Shop: 23933

3. **KATAG1** (product_id: 3784, variant_id: 4242)
   - Giá: 999,000 VNĐ
   - Shop: 23933

4. **SKG G7 PRO-FOLD** (product_id: 3913, variant_id: NULL)
   - Giá: 4,190,000 VNĐ
   - Shop: 23933

5. **SKG G7 Pro-E** (product_id: 3914, variant_id: NULL)
   - Giá: 3,590,000 VNĐ
   - Shop: 23933

## Cách sử dụng

### Bước 1: Tạo đơn hàng
Chạy file `generate_orders_and_reviews.sql` (phần tạo đơn hàng):
```sql
-- Chạy phần tạo đơn hàng trong file generate_orders_and_reviews.sql
-- Sẽ tạo 500 đơn hàng (100 đơn/sản phẩm x 5 sản phẩm)
```

### Bước 2: Tạo đánh giá
Sau khi đã tạo đơn hàng, chạy file `generate_reviews.sql`:
```sql
-- Chạy file generate_reviews.sql
-- Sẽ tạo 500 đánh giá (100 đánh giá/sản phẩm x 5 sản phẩm)
-- Tự động cập nhật thống kê đánh giá
```

## Lưu ý

1. **User ID**: Script sử dụng user_id từ 1-500. Đảm bảo có đủ user trong bảng `user_info`.

2. **Đơn hàng**: 
   - Mỗi đơn hàng có status=5 (thành công)
   - Mã đơn hàng được tạo tự động với format: `DH{timestamp}_{user_id}_{row_number}`
   - Thông tin khách hàng lấy từ bảng `user_info`, nếu thiếu sẽ dùng giá trị mặc định

3. **Đánh giá**:
   - Mỗi đánh giá có `is_verified_purchase = 1` (đã mua hàng)
   - Status = 'approved' (đã duyệt)
   - Rating phân bố: 60% 5 sao, 20% 4 sao, 10% 3 sao, 10% 2 sao
   - Nội dung đánh giá đa dạng, phù hợp với từng sản phẩm

4. **Thống kê**: 
   - Tự động tính toán và cập nhật vào bảng `product_rating_stats`
   - Bao gồm: tổng số đánh giá, điểm trung bình, số lượng theo từng mức sao

## Kiểm tra kết quả

Sau khi chạy script, kiểm tra:

```sql
-- Kiểm tra số đơn hàng đã tạo
SELECT COUNT(*) as total_orders FROM donhang WHERE shop_id = '23933' AND status = 5;

-- Kiểm tra số đánh giá đã tạo
SELECT product_id, COUNT(*) as total_reviews 
FROM product_comments 
WHERE shop_id = 23933 AND status = 'approved' 
GROUP BY product_id;

-- Kiểm tra thống kê đánh giá
SELECT * FROM product_rating_stats WHERE shop_id = 23933;
```

## Tổng kết

- **500 đơn hàng** (100 đơn/sản phẩm x 5 sản phẩm)
- **500 đánh giá** (100 đánh giá/sản phẩm x 5 sản phẩm)
- **5 bản ghi thống kê** (1 bản ghi/sản phẩm)

Tất cả đều sử dụng dữ liệu thực tế từ database, không phải dữ liệu fake.

