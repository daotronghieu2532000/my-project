-- =====================================================
-- Script tạo đánh giá từ các đơn hàng đã tạo
-- Mỗi sản phẩm: 100 đánh giá
-- Chạy sau khi đã chạy generate_orders_and_reviews.sql (phần tạo đơn hàng)
-- =====================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

-- =====================================================
-- BƯỚC 1: TẠO ĐÁNH GIÁ CHO 5 SẢN PHẨM
-- Mỗi sản phẩm 100 đánh giá từ các đơn hàng đã tạo
-- =====================================================

-- Đánh giá cho sản phẩm 1: KATA ACC220 (product_id: 3781, variant_id: 4238)
INSERT INTO `product_comments` (
    `product_id`, `variant_id`, `user_id`, `shop_id`, `parent_id`, `content`, 
    `rating`, `delivery_rating`, `shop_rating`, `matches_description`, 
    `is_satisfied`, `will_buy_again`, `images`, `is_verified_purchase`, 
    `order_id`, `likes_count`, `dislikes_count`, `status`, `is_pinned`
)
SELECT 
    3781 as product_id,
    4238 as variant_id,
    d.user_id,
    23933 as shop_id,
    0 as parent_id,
    CASE 
        WHEN MOD(d.id, 5) = 0 THEN 'Sản phẩm rất tốt, đo nhanh và chính xác. Màn hình LCD rõ ràng, dễ sử dụng. Đáng mua!'
        WHEN MOD(d.id, 5) = 1 THEN 'Máy đo cồn chất lượng tốt, thiết kế nhỏ gọn dễ mang theo. Pin bền, dùng được nhiều lần. Hài lòng với sản phẩm.'
        WHEN MOD(d.id, 5) = 2 THEN 'Đúng như mô tả, cảm biến nhạy, kết quả chính xác. Giao hàng nhanh, đóng gói cẩn thận. Sẽ mua lại nếu cần.'
        WHEN MOD(d.id, 5) = 3 THEN 'Sản phẩm tốt, giá hợp lý. Màn hình hiển thị rõ, cảnh báo âm thanh rõ ràng. Phù hợp cho tài xế.'
        ELSE 'Máy hoạt động ổn định, thiết kế đẹp. Đo nhanh trong vài giây, kết quả chính xác. Shop giao hàng đúng hẹn.'
    END as content,
    5 as rating,
    5 as delivery_rating,
    5 as shop_rating,
    1 as matches_description,
    1 as is_satisfied,
    'yes' as will_buy_again,
    NULL as images,
    1 as is_verified_purchase,
    d.id as order_id,
    FLOOR(RAND() * 10) as likes_count,
    FLOOR(RAND() * 2) as dislikes_count,
    'approved' as status,
    0 as is_pinned
FROM donhang d
WHERE d.shop_id = '23933' 
  AND d.status = 5
  AND d.sanpham LIKE CONCAT('%"', 3781, '_', 4238, '%":%')
  AND d.sanpham LIKE CONCAT('%"id":', 3781, '%')
ORDER BY d.id DESC
LIMIT 100;

-- Đánh giá cho sản phẩm 2: KATA ACC110 (product_id: 3783, variant_id: 4240)
INSERT INTO `product_comments` (
    `product_id`, `variant_id`, `user_id`, `shop_id`, `parent_id`, `content`, 
    `rating`, `delivery_rating`, `shop_rating`, `matches_description`, 
    `is_satisfied`, `will_buy_again`, `images`, `is_verified_purchase`, 
    `order_id`, `likes_count`, `dislikes_count`, `status`, `is_pinned`
)
SELECT 
    3783 as product_id,
    4240 as variant_id,
    d.user_id,
    23933 as shop_id,
    0 as parent_id,
    CASE 
        WHEN MOD(d.id, 5) = 0 THEN 'Máy đo cồn nhỏ gọn, tiện lợi. Cảm biến chính xác, đo nhanh trong 6 giây. Giá tốt so với chất lượng.'
        WHEN MOD(d.id, 5) = 1 THEN 'Sản phẩm đúng mô tả, thiết kế đẹp, dễ sử dụng. Màn hình LCD rõ ràng. Giao hàng nhanh, đóng gói tốt.'
        WHEN MOD(d.id, 5) = 2 THEN 'Máy hoạt động tốt, pin bền. Thổi không tiếp xúc nên vệ sinh. Phù hợp cho cá nhân và doanh nghiệp.'
        WHEN MOD(d.id, 5) = 3 THEN 'Chất lượng tốt, giá hợp lý. Đo chính xác, cảnh báo kịp thời. Shop tư vấn nhiệt tình.'
        ELSE 'Sản phẩm ổn, đáp ứng nhu cầu. Thiết kế nhỏ gọn, dễ mang theo. Sẽ cân nhắc mua thêm nếu cần.'
    END as content,
    5 as rating,
    5 as delivery_rating,
    5 as shop_rating,
    1 as matches_description,
    1 as is_satisfied,
    'yes' as will_buy_again,
    NULL as images,
    1 as is_verified_purchase,
    d.id as order_id,
    FLOOR(RAND() * 10) as likes_count,
    FLOOR(RAND() * 2) as dislikes_count,
    'approved' as status,
    0 as is_pinned
FROM donhang d
WHERE d.shop_id = '23933' 
  AND d.status = 5
  AND d.sanpham LIKE CONCAT('%"', 3783, '_', 4240, '%":%')
  AND d.sanpham LIKE CONCAT('%"id":', 3783, '%')
ORDER BY d.id DESC
LIMIT 100;

-- Đánh giá cho sản phẩm 3: KATAG1 (product_id: 3784, variant_id: 4242)
INSERT INTO `product_comments` (
    `product_id`, `variant_id`, `user_id`, `shop_id`, `parent_id`, `content`, 
    `rating`, `delivery_rating`, `shop_rating`, `matches_description`, 
    `is_satisfied`, `will_buy_again`, `images`, `is_verified_purchase`, 
    `order_id`, `likes_count`, `dislikes_count`, `status`, `is_pinned`
)
SELECT 
    3784 as product_id,
    4242 as variant_id,
    d.user_id,
    23933 as shop_id,
    0 as parent_id,
    CASE 
        WHEN MOD(d.id, 5) = 0 THEN 'Máy tăm nước rất tốt, làm sạch kẽ răng hiệu quả. 5 chế độ phun linh hoạt, pin bền. Đáng mua!'
        WHEN MOD(d.id, 5) = 1 THEN 'Sản phẩm chất lượng cao, thiết kế đẹp. Làm sạch sâu, không gây đau. Giao hàng nhanh, đóng gói cẩn thận.'
        WHEN MOD(d.id, 5) = 2 THEN 'Máy hoạt động tốt, 4 đầu thay thế tiện lợi. Chống nước IPX7 an toàn. Phù hợp cho người niềng răng.'
        WHEN MOD(d.id, 5) = 3 THEN 'Chất lượng tốt, giá hợp lý. Pin 2000mAh dùng lâu, sạc nhanh. Shop hỗ trợ tốt.'
        ELSE 'Sản phẩm ổn, đáp ứng nhu cầu. Làm sạch hiệu quả hơn chỉ nha khoa. Sẽ mua lại nếu cần.'
    END as content,
    5 as rating,
    5 as delivery_rating,
    5 as shop_rating,
    1 as matches_description,
    1 as is_satisfied,
    'yes' as will_buy_again,
    NULL as images,
    1 as is_verified_purchase,
    d.id as order_id,
    FLOOR(RAND() * 10) as likes_count,
    FLOOR(RAND() * 2) as dislikes_count,
    'approved' as status,
    0 as is_pinned
FROM donhang d
WHERE d.shop_id = '23933' 
  AND d.status = 5
  AND d.sanpham LIKE CONCAT('%"', 3784, '_', 4242, '%":%')
  AND d.sanpham LIKE CONCAT('%"id":', 3784, '%')
ORDER BY d.id DESC
LIMIT 100;

-- Đánh giá cho sản phẩm 4: SKG G7 PRO-FOLD (product_id: 3913, variant_id: 0)
INSERT INTO `product_comments` (
    `product_id`, `variant_id`, `user_id`, `shop_id`, `parent_id`, `content`, 
    `rating`, `delivery_rating`, `shop_rating`, `matches_description`, 
    `is_satisfied`, `will_buy_again`, `images`, `is_verified_purchase`, 
    `order_id`, `likes_count`, `dislikes_count`, `status`, `is_pinned`
)
SELECT 
    3913 as product_id,
    NULL as variant_id,
    d.user_id,
    23933 as shop_id,
    0 as parent_id,
    CASE 
        WHEN MOD(d.id, 5) = 0 THEN 'Máy massage cổ tuyệt vời! 9 đầu massage mạnh mẽ, chườm nóng dễ chịu. Thiết kế gập gọn tiện lợi. Đáng mua!'
        WHEN MOD(d.id, 5) = 1 THEN 'Sản phẩm cao cấp, chất lượng tốt. Massage sâu, giảm đau mỏi hiệu quả. Ánh sáng đỏ thư giãn tốt. Giao hàng nhanh.'
        WHEN MOD(d.id, 5) = 2 THEN 'Máy hoạt động tốt, nhiều chế độ. Tần số xung 6000Hz mạnh mẽ. Pin bền, sạc nhanh. Phù hợp cho văn phòng.'
        WHEN MOD(d.id, 5) = 3 THEN 'Chất lượng tốt, giá hợp lý. Massage chân thực như tay người. Shop tư vấn nhiệt tình, đóng gói cẩn thận.'
        ELSE 'Sản phẩm ổn, đáp ứng nhu cầu. Giảm đau mỏi cổ vai gáy hiệu quả. Sẽ mua lại nếu cần.'
    END as content,
    5 as rating,
    5 as delivery_rating,
    5 as shop_rating,
    1 as matches_description,
    1 as is_satisfied,
    'yes' as will_buy_again,
    NULL as images,
    1 as is_verified_purchase,
    d.id as order_id,
    FLOOR(RAND() * 10) as likes_count,
    FLOOR(RAND() * 2) as dislikes_count,
    'approved' as status,
    0 as is_pinned
FROM donhang d
WHERE d.shop_id = '23933' 
  AND d.status = 5
  AND d.sanpham LIKE CONCAT('%"', 3913, '_0"%":%')
  AND d.sanpham LIKE CONCAT('%"id":', 3913, '%')
ORDER BY d.id DESC
LIMIT 100;

-- Đánh giá cho sản phẩm 5: SKG G7 Pro-E (product_id: 3914, variant_id: 0)
INSERT INTO `product_comments` (
    `product_id`, `variant_id`, `user_id`, `shop_id`, `parent_id`, `content`, 
    `rating`, `delivery_rating`, `shop_rating`, `matches_description`, 
    `is_satisfied`, `will_buy_again`, `images`, `is_verified_purchase`, 
    `order_id`, `likes_count`, `dislikes_count`, `status`, `is_pinned`
)
SELECT 
    3914 as product_id,
    NULL as variant_id,
    d.user_id,
    23933 as shop_id,
    0 as parent_id,
    CASE 
        WHEN MOD(d.id, 5) = 0 THEN 'Máy massage cổ rất tốt! 9 đầu Shiatsu massage sâu, xung TENS+EMS hiệu quả. Ánh sáng đỏ 630nm thư giãn tốt.'
        WHEN MOD(d.id, 5) = 1 THEN 'Sản phẩm chất lượng cao, thiết kế đẹp. Chườm nóng Nano 37-43°C dễ chịu. Điều khiển qua app tiện lợi.'
        WHEN MOD(d.id, 5) = 2 THEN 'Máy hoạt động tốt, 4 chế độ massage linh hoạt. Giảm đau mỏi cổ vai gáy hiệu quả. Giao hàng nhanh.'
        WHEN MOD(d.id, 5) = 3 THEN 'Chất lượng tốt, giá hợp lý. Massage chân thực, thư giãn sâu. Shop hỗ trợ tốt, đóng gói cẩn thận.'
        ELSE 'Sản phẩm ổn, đáp ứng nhu cầu. Phù hợp cho người làm việc văn phòng. Sẽ cân nhắc mua thêm nếu cần.'
    END as content,
    5 as rating,
    5 as delivery_rating,
    5 as shop_rating,
    1 as matches_description,
    1 as is_satisfied,
    'yes' as will_buy_again,
    NULL as images,
    1 as is_verified_purchase,
    d.id as order_id,
    FLOOR(RAND() * 10) as likes_count,
    FLOOR(RAND() * 2) as dislikes_count,
    'approved' as status,
    0 as is_pinned
FROM donhang d
WHERE d.shop_id = '23933' 
  AND d.status = 5
  AND d.sanpham LIKE CONCAT('%"', 3914, '_0"%":%')
  AND d.sanpham LIKE CONCAT('%"id":', 3914, '%')
ORDER BY d.id DESC
LIMIT 100;

-- =====================================================
-- BƯỚC 2: CẬP NHẬT THỐNG KÊ ĐÁNH GIÁ (product_rating_stats)
-- =====================================================

-- Cập nhật thống kê cho sản phẩm 1: KATA ACC220
INSERT INTO `product_rating_stats` (
    `product_id`, `shop_id`, `total_reviews`, `average_rating`, 
    `rating_5`, `rating_4`, `rating_3`, `rating_2`, `rating_1`
)
SELECT 
    3781 as product_id,
    23933 as shop_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(rating), 2) as average_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments
WHERE product_id = 3781 AND shop_id = 23933 AND status = 'approved'
ON DUPLICATE KEY UPDATE
    total_reviews = VALUES(total_reviews),
    average_rating = VALUES(average_rating),
    rating_5 = VALUES(rating_5),
    rating_4 = VALUES(rating_4),
    rating_3 = VALUES(rating_3),
    rating_2 = VALUES(rating_2),
    rating_1 = VALUES(rating_1);

-- Cập nhật thống kê cho sản phẩm 2: KATA ACC110
INSERT INTO `product_rating_stats` (
    `product_id`, `shop_id`, `total_reviews`, `average_rating`, 
    `rating_5`, `rating_4`, `rating_3`, `rating_2`, `rating_1`
)
SELECT 
    3783 as product_id,
    23933 as shop_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(rating), 2) as average_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments
WHERE product_id = 3783 AND shop_id = 23933 AND status = 'approved'
ON DUPLICATE KEY UPDATE
    total_reviews = VALUES(total_reviews),
    average_rating = VALUES(average_rating),
    rating_5 = VALUES(rating_5),
    rating_4 = VALUES(rating_4),
    rating_3 = VALUES(rating_3),
    rating_2 = VALUES(rating_2),
    rating_1 = VALUES(rating_1);

-- Cập nhật thống kê cho sản phẩm 3: KATAG1
INSERT INTO `product_rating_stats` (
    `product_id`, `shop_id`, `total_reviews`, `average_rating`, 
    `rating_5`, `rating_4`, `rating_3`, `rating_2`, `rating_1`
)
SELECT 
    3784 as product_id,
    23933 as shop_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(rating), 2) as average_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments
WHERE product_id = 3784 AND shop_id = 23933 AND status = 'approved'
ON DUPLICATE KEY UPDATE
    total_reviews = VALUES(total_reviews),
    average_rating = VALUES(average_rating),
    rating_5 = VALUES(rating_5),
    rating_4 = VALUES(rating_4),
    rating_3 = VALUES(rating_3),
    rating_2 = VALUES(rating_2),
    rating_1 = VALUES(rating_1);

-- Cập nhật thống kê cho sản phẩm 4: SKG G7 PRO-FOLD
INSERT INTO `product_rating_stats` (
    `product_id`, `shop_id`, `total_reviews`, `average_rating`, 
    `rating_5`, `rating_4`, `rating_3`, `rating_2`, `rating_1`
)
SELECT 
    3913 as product_id,
    23933 as shop_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(rating), 2) as average_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments
WHERE product_id = 3913 AND shop_id = 23933 AND status = 'approved'
ON DUPLICATE KEY UPDATE
    total_reviews = VALUES(total_reviews),
    average_rating = VALUES(average_rating),
    rating_5 = VALUES(rating_5),
    rating_4 = VALUES(rating_4),
    rating_3 = VALUES(rating_3),
    rating_2 = VALUES(rating_2),
    rating_1 = VALUES(rating_1);

-- Cập nhật thống kê cho sản phẩm 5: SKG G7 Pro-E
INSERT INTO `product_rating_stats` (
    `product_id`, `shop_id`, `total_reviews`, `average_rating`, 
    `rating_5`, `rating_4`, `rating_3`, `rating_2`, `rating_1`
)
SELECT 
    3914 as product_id,
    23933 as shop_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(rating), 2) as average_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments
WHERE product_id = 3914 AND shop_id = 23933 AND status = 'approved'
ON DUPLICATE KEY UPDATE
    total_reviews = VALUES(total_reviews),
    average_rating = VALUES(average_rating),
    rating_5 = VALUES(rating_5),
    rating_4 = VALUES(rating_4),
    rating_3 = VALUES(rating_3),
    rating_2 = VALUES(rating_2),
    rating_1 = VALUES(rating_1);

-- =====================================================
-- HOÀN TẤT
-- =====================================================
-- Đã tạo:
-- - 500 đánh giá (100 đánh giá/sản phẩm x 5 sản phẩm) với status='approved'
-- - Cập nhật thống kê đánh giá cho 5 sản phẩm
-- =====================================================

