-- =====================================================
-- Script kiểm tra số lượng đánh giá
-- =====================================================

-- Tổng số đánh giá trong bảng
SELECT COUNT(*) as total_reviews 
FROM product_comments 
WHERE status = 'approved';

-- Tổng số đánh giá theo shop
SELECT 
    shop_id,
    COUNT(*) as total_reviews,
    AVG(rating) as avg_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments 
WHERE status = 'approved'
GROUP BY shop_id
ORDER BY total_reviews DESC;

-- Chi tiết đánh giá theo shop_id cụ thể (thay 32854 bằng shop_id bạn muốn xem)
SELECT 
    shop_id,
    COUNT(*) as total_reviews,
    AVG(rating) as avg_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments 
WHERE shop_id = 32854 
  AND status = 'approved'
GROUP BY shop_id;

-- Số đánh giá theo từng sản phẩm của shop
SELECT 
    product_id,
    COUNT(*) as total_reviews,
    AVG(rating) as avg_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments 
WHERE shop_id = 32854 
  AND status = 'approved'
GROUP BY product_id
ORDER BY total_reviews DESC;

-- Kiểm tra user đánh giá nhiều lần cho cùng 1 sản phẩm (không nên có)
SELECT 
    product_id,
    user_id,
    COUNT(*) as review_count
FROM product_comments 
WHERE shop_id = 32854 
  AND status = 'approved'
GROUP BY product_id, user_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC;

