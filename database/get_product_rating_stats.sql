-- SQL query để lấy tổng đánh giá và đánh giá trung bình của sản phẩm từ một shop cụ thể
-- Ví dụ: shop_id = 23933, product_id = 3781

-- Cách 1: Lấy từ bảng product_comments (dữ liệu thật, chính xác nhất)
SELECT 
    COUNT(*) as total_reviews,
    AVG(rating) as average_rating,
    MIN(rating) as min_rating,
    MAX(rating) as max_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments
WHERE product_id = 3781
  AND shop_id = 23933
  AND parent_id = 0
  AND status = 'approved';

-- Cách 2: Lấy từ bảng product_rating_stats (nếu đã có thống kê)
SELECT 
    total_reviews,
    average_rating,
    rating_5,
    rating_4,
    rating_3,
    rating_2,
    rating_1,
    updated_at
FROM product_rating_stats
WHERE product_id = 3781
  AND shop_id = 23933
LIMIT 1;

-- Cách 3: Kết hợp cả 2 (ưu tiên product_comments, fallback về product_rating_stats)
SELECT 
    COALESCE(
        (SELECT COUNT(*) 
         FROM product_comments 
         WHERE product_id = 3781 
           AND shop_id = 23933 
           AND parent_id = 0 
           AND status = 'approved'),
        (SELECT total_reviews 
         FROM product_rating_stats 
         WHERE product_id = 3781 
           AND shop_id = 23933 
         LIMIT 1),
        0
    ) as total_reviews,
    COALESCE(
        (SELECT AVG(rating) 
         FROM product_comments 
         WHERE product_id = 3781 
           AND shop_id = 23933 
           AND parent_id = 0 
           AND status = 'approved'),
        (SELECT average_rating 
         FROM product_rating_stats 
         WHERE product_id = 3781 
           AND shop_id = 23933 
         LIMIT 1),
        0.0
    ) as average_rating;

-- Cách 4: Query chi tiết với thông tin bổ sung
SELECT 
    pc.product_id,
    pc.shop_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(pc.rating), 2) as average_rating,
    MIN(pc.rating) as min_rating,
    MAX(pc.rating) as max_rating,
    SUM(CASE WHEN pc.rating = 5 THEN 1 ELSE 0 END) as rating_5_count,
    SUM(CASE WHEN pc.rating = 4 THEN 1 ELSE 0 END) as rating_4_count,
    SUM(CASE WHEN pc.rating = 3 THEN 1 ELSE 0 END) as rating_3_count,
    SUM(CASE WHEN pc.rating = 2 THEN 1 ELSE 0 END) as rating_2_count,
    SUM(CASE WHEN pc.rating = 1 THEN 1 ELSE 0 END) as rating_1_count,
    SUM(CASE WHEN pc.images IS NOT NULL AND pc.images != '' AND pc.images != '[]' THEN 1 ELSE 0 END) as reviews_with_images,
    SUM(CASE WHEN pc.is_verified_purchase = 1 THEN 1 ELSE 0 END) as verified_purchases
FROM product_comments pc
WHERE pc.product_id = 3781
  AND pc.shop_id = 23933
  AND pc.parent_id = 0
  AND pc.status = 'approved'
GROUP BY pc.product_id, pc.shop_id;

