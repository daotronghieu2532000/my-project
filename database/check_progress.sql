-- =====================================================
-- Script kiểm tra tiến độ tạo đơn hàng và đánh giá
-- Chạy script này để xem:
-- 1. Tổng số sản phẩm của shop
-- 2. Số sản phẩm đã có đủ đơn hàng
-- 3. Số sản phẩm đã có đủ đánh giá
-- 4. Số sản phẩm còn cần xử lý
-- =====================================================

SET @shop_id = 35681;  -- Shop ID cần kiểm tra
SET @orders_per_product = 100;  -- Số đơn hàng mỗi sản phẩm cần có
SET @reviews_per_product_min = 30;  -- Số đánh giá tối thiểu mỗi sản phẩm

-- =====================================================
-- THỐNG KÊ TỔNG QUAN
-- =====================================================
SELECT 
    'TỔNG SỐ SẢN PHẨM' as metric,
    COUNT(*) as value
FROM sanpham
WHERE shop = @shop_id
  AND status = 1
  AND active = 0

UNION ALL

SELECT 
    'SẢN PHẨM ĐÃ CÓ ĐỦ ĐƠN HÀNG' as metric,
    COUNT(*) as value
FROM (
    SELECT sp.id
    FROM sanpham sp
    LEFT JOIN (
        SELECT 
            CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(d.sanpham, '"id":', -1), ',', 1) AS UNSIGNED) as product_id,
            COUNT(*) as order_count
        FROM donhang d
        WHERE d.shop_id = CAST(@shop_id AS CHAR)
          AND d.status = 5
          AND d.sanpham LIKE '%"id":%'
        GROUP BY product_id
    ) existing_orders ON sp.id = existing_orders.product_id
    WHERE sp.shop = @shop_id
      AND sp.status = 1
      AND sp.active = 0
      AND existing_orders.order_count >= @orders_per_product
    GROUP BY sp.id
) products_with_enough_orders

UNION ALL

SELECT 
    'SẢN PHẨM ĐÃ CÓ ĐỦ ĐÁNH GIÁ' as metric,
    COUNT(*) as value
FROM (
    SELECT product_id
    FROM product_comments
    WHERE shop_id = @shop_id
      AND status = 'approved'
    GROUP BY product_id
    HAVING COUNT(*) >= @reviews_per_product_min
) products_with_enough_reviews

UNION ALL

SELECT 
    'SẢN PHẨM CẦN XỬ LÝ' as metric,
    COUNT(*) as value
FROM sanpham sp
LEFT JOIN (
    SELECT 
        CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(d.sanpham, '"id":', -1), ',', 1) AS UNSIGNED) as product_id,
        COUNT(*) as order_count
    FROM donhang d
    WHERE d.shop_id = CAST(@shop_id AS CHAR)
      AND d.status = 5
      AND d.sanpham LIKE '%"id":%'
    GROUP BY product_id
) existing_orders ON sp.id = existing_orders.product_id
WHERE sp.shop = @shop_id
  AND sp.status = 1
  AND sp.active = 0
  AND (existing_orders.order_count IS NULL OR existing_orders.order_count < @orders_per_product);

-- =====================================================
-- CHI TIẾT SẢN PHẨM CẦN XỬ LÝ (10 sản phẩm đầu tiên)
-- =====================================================
SELECT 
    sp.id as product_id,
    sp.tieu_de as product_name,
    COALESCE(existing_orders.order_count, 0) as current_orders,
    @orders_per_product as required_orders,
    (@orders_per_product - COALESCE(existing_orders.order_count, 0)) as orders_needed,
    COALESCE(existing_reviews.review_count, 0) as current_reviews,
    @reviews_per_product_min as required_reviews,
    (@reviews_per_product_min - COALESCE(existing_reviews.review_count, 0)) as reviews_needed
FROM sanpham sp
LEFT JOIN (
    SELECT 
        CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(d.sanpham, '"id":', -1), ',', 1) AS UNSIGNED) as product_id,
        COUNT(*) as order_count
    FROM donhang d
    WHERE d.shop_id = CAST(@shop_id AS CHAR)
      AND d.status = 5
      AND d.sanpham LIKE '%"id":%'
    GROUP BY product_id
) existing_orders ON sp.id = existing_orders.product_id
LEFT JOIN (
    SELECT 
        product_id,
        COUNT(*) as review_count
    FROM product_comments
    WHERE shop_id = @shop_id
      AND status = 'approved'
    GROUP BY product_id
) existing_reviews ON sp.id = existing_reviews.product_id
WHERE sp.shop = @shop_id
  AND sp.status = 1
  AND sp.active = 0
  AND (existing_orders.order_count IS NULL OR existing_orders.order_count < @orders_per_product)
ORDER BY sp.id
LIMIT 10;

