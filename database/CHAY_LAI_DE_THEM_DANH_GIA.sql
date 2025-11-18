-- =====================================================
-- Script chạy lại để thêm đánh giá cho các sản phẩm chưa đủ 30-50 đánh giá
-- Chạy script này nhiều lần cho đến khi mỗi sản phẩm có đủ 30-50 đánh giá
-- =====================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";
SET @shop_id = 20755;  -- Shop ID

-- Tạo đánh giá cho sản phẩm có biến thể (chỉ cho sản phẩm chưa đủ 50 đánh giá)
INSERT INTO `product_comments` (
    `product_id`, `variant_id`, `user_id`, `shop_id`, `parent_id`, `content`, 
    `rating`, `delivery_rating`, `shop_rating`, `matches_description`, 
    `is_satisfied`, `will_buy_again`, `images`, `is_verified_purchase`, 
    `order_id`, `likes_count`, `dislikes_count`, `status`, `is_pinned`
)
SELECT 
    pl.sp_id as product_id,
    pl.id as variant_id,
    d.user_id,
    @shop_id as shop_id,
    0 as parent_id,
    CASE 
        WHEN MOD(d.id, 10) < 2 THEN CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' - ', pl.ten_color) ELSE '' END,
            CASE WHEN pl.ten_size != '' AND pl.ten_size IS NOT NULL THEN CONCAT(' - ', pl.ten_size) ELSE '' END,
            ' khá tốt, đúng như mô tả. Giao hàng ổn, đóng gói cẩn thận. Có thể cải thiện thêm về bao bì nhưng nhìn chung hài lòng.'
        )
        WHEN MOD(d.id, 10) < 4 THEN CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' - ', pl.ten_color) ELSE '' END,
            CASE WHEN pl.ten_size != '' AND pl.ten_size IS NOT NULL THEN CONCAT(' - ', pl.ten_size) ELSE '' END,
            ' chất lượng tốt, đáp ứng kỳ vọng. Shop giao hàng đúng hẹn, sản phẩm đúng mô tả. Có thể cân nhắc mua lại.'
        )
        WHEN MOD(d.id, 10) < 6 THEN CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' - ', pl.ten_color) ELSE '' END,
            CASE WHEN pl.ten_size != '' AND pl.ten_size IS NOT NULL THEN CONCAT(' - ', pl.ten_size) ELSE '' END,
            ' rất tốt, chất lượng ổn định. Giao hàng nhanh, đóng gói chắc chắn. Đáng mua và sẽ giới thiệu cho bạn bè.'
        )
        WHEN MOD(d.id, 10) < 8 THEN CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' - ', pl.ten_color) ELSE '' END,
            CASE WHEN pl.ten_size != '' AND pl.ten_size IS NOT NULL THEN CONCAT(' - ', pl.ten_size) ELSE '' END,
            ' tốt, đúng như mong đợi. Shop phục vụ nhiệt tình, giao hàng đúng hẹn. Sẽ mua lại nếu có nhu cầu.'
        )
        ELSE CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' - ', pl.ten_color) ELSE '' END,
            CASE WHEN pl.ten_size != '' AND pl.ten_size IS NOT NULL THEN CONCAT(' - ', pl.ten_size) ELSE '' END,
            ' chất lượng tốt, đúng mô tả. Giao hàng nhanh, đóng gói cẩn thận. Hài lòng với sản phẩm và dịch vụ.'
        )
    END as content,
    CASE WHEN MOD(d.id, 10) < 8 THEN 5 ELSE 4 END as rating,
    CASE WHEN MOD(d.id, 10) < 8 THEN 5 ELSE 4 END as delivery_rating,
    CASE WHEN MOD(d.id, 10) < 8 THEN 5 ELSE 4 END as shop_rating,
    CASE WHEN MOD(d.id, 10) < 8 THEN 1 ELSE 1 END as matches_description,
    CASE WHEN MOD(d.id, 10) < 8 THEN 1 ELSE 1 END as is_satisfied,
    CASE WHEN MOD(d.id, 10) < 8 THEN 'yes' ELSE 'maybe' END as will_buy_again,
    NULL as images,
    1 as is_verified_purchase,
    d.id as order_id,
    FLOOR(RAND() * 10) as likes_count,
    0 as dislikes_count,
    'approved' as status,
    0 as is_pinned
FROM donhang d
INNER JOIN phanloai_sanpham pl ON d.sanpham LIKE CONCAT('%"', pl.sp_id, '_', pl.id, '%":%')
INNER JOIN sanpham sp ON pl.sp_id = sp.id
WHERE d.shop_id = CAST(@shop_id AS CHAR)
  AND d.status = 5
  AND sp.shop = @shop_id
  AND NOT EXISTS (
      SELECT 1 FROM product_comments pc 
      WHERE pc.order_id = d.id 
        AND pc.product_id = pl.sp_id
  )
  AND (
      SELECT COUNT(*) 
      FROM product_comments pc2 
      WHERE pc2.product_id = pl.sp_id 
        AND pc2.shop_id = @shop_id 
        AND pc2.status = 'approved'
  ) < 50
ORDER BY RAND()
LIMIT 500;

-- Tạo đánh giá cho sản phẩm không có biến thể
INSERT INTO `product_comments` (
    `product_id`, `variant_id`, `user_id`, `shop_id`, `parent_id`, `content`, 
    `rating`, `delivery_rating`, `shop_rating`, `matches_description`, 
    `is_satisfied`, `will_buy_again`, `images`, `is_verified_purchase`, 
    `order_id`, `likes_count`, `dislikes_count`, `status`, `is_pinned`
)
SELECT 
    sp.id as product_id,
    NULL as variant_id,
    d.user_id,
    @shop_id as shop_id,
    0 as parent_id,
    CASE 
        WHEN MOD(d.id, 10) < 2 THEN CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            ' khá tốt, đúng như mô tả. Giao hàng ổn, đóng gói cẩn thận. Có thể cải thiện thêm về bao bì nhưng nhìn chung hài lòng.'
        )
        WHEN MOD(d.id, 10) < 4 THEN CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            ' chất lượng tốt, đáp ứng kỳ vọng. Shop giao hàng đúng hẹn, sản phẩm đúng mô tả. Có thể cân nhắc mua lại.'
        )
        WHEN MOD(d.id, 10) < 6 THEN CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            ' rất tốt, chất lượng ổn định. Giao hàng nhanh, đóng gói chắc chắn. Đáng mua và sẽ giới thiệu cho bạn bè.'
        )
        WHEN MOD(d.id, 10) < 8 THEN CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            ' tốt, đúng như mong đợi. Shop phục vụ nhiệt tình, giao hàng đúng hẹn. Sẽ mua lại nếu có nhu cầu.'
        )
        ELSE CONCAT(
            'Sản phẩm ', sp.tieu_de, 
            ' chất lượng tốt, đúng mô tả. Giao hàng nhanh, đóng gói cẩn thận. Hài lòng với sản phẩm và dịch vụ.'
        )
    END as content,
    CASE WHEN MOD(d.id, 10) < 8 THEN 5 ELSE 4 END as rating,
    CASE WHEN MOD(d.id, 10) < 8 THEN 5 ELSE 4 END as delivery_rating,
    CASE WHEN MOD(d.id, 10) < 8 THEN 5 ELSE 4 END as shop_rating,
    CASE WHEN MOD(d.id, 10) < 8 THEN 1 ELSE 1 END as matches_description,
    CASE WHEN MOD(d.id, 10) < 8 THEN 1 ELSE 1 END as is_satisfied,
    CASE WHEN MOD(d.id, 10) < 8 THEN 'yes' ELSE 'maybe' END as will_buy_again,
    NULL as images,
    1 as is_verified_purchase,
    d.id as order_id,
    FLOOR(RAND() * 10) as likes_count,
    0 as dislikes_count,
    'approved' as status,
    0 as is_pinned
FROM donhang d
INNER JOIN sanpham sp ON d.sanpham LIKE CONCAT('%"', sp.id, '_0"%":%')
WHERE d.shop_id = CAST(@shop_id AS CHAR)
  AND d.status = 5
  AND sp.shop = @shop_id
  AND NOT EXISTS (
      SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sp.id
  )
  AND NOT EXISTS (
      SELECT 1 FROM product_comments pc 
      WHERE pc.order_id = d.id 
        AND pc.product_id = sp.id
  )
  AND (
      SELECT COUNT(*) 
      FROM product_comments pc2 
      WHERE pc2.product_id = sp.id 
        AND pc2.shop_id = @shop_id 
        AND pc2.status = 'approved'
  ) < 50
ORDER BY RAND()
LIMIT 500;

-- Cập nhật lại thống kê
DELETE FROM product_rating_stats WHERE shop_id = @shop_id;

INSERT INTO `product_rating_stats` (
    `product_id`, `shop_id`, `total_reviews`, `average_rating`, 
    `rating_5`, `rating_4`, `rating_3`, `rating_2`, `rating_1`
)
SELECT 
    product_id,
    @shop_id as shop_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(rating), 2) as average_rating,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
FROM product_comments
WHERE shop_id = @shop_id 
  AND status = 'approved'
GROUP BY product_id;

