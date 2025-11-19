-- =====================================================
-- Script tự động tạo đơn hàng và đánh giá
-- Chỉ cần cung cấp shop_id, script tự động:
-- 1. Lấy 5 sản phẩm đầu tiên của shop (giới hạn để tránh timeout)
-- 2. Lấy tất cả biến thể của 5 sản phẩm đó
-- 3. Tạo đơn hàng (30 đơn/sản phẩm/biến thể)
-- 4. Tạo đánh giá (30 đánh giá/sản phẩm)
-- 5. Cập nhật thống kê đánh giá
-- 
-- LƯU Ý: Script chỉ xử lý 5 sản phẩm mỗi lần chạy để tránh timeout.
-- Nếu shop có nhiều sản phẩm, cần chạy script nhiều lần.
-- Mỗi lần chạy sẽ xử lý 5 sản phẩm tiếp theo.
-- =====================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

-- =====================================================
-- CẤU HÌNH
-- =====================================================
SET @shop_id = 23933;  -- Shop ID cần tạo đơn hàng và đánh giá
SET @orders_per_product = 30;  -- Số đơn hàng mỗi sản phẩm/biến thể
SET @reviews_per_product_min = 30;  -- Số đánh giá tối thiểu mỗi sản phẩm
SET @reviews_per_product_max = 30;  -- Số đánh giá tối đa mỗi sản phẩm
SET @products_per_batch = 5;  -- Số sản phẩm xử lý mỗi lần chạy (để tránh timeout)

-- =====================================================
-- KIỂM TRA SỐ SẢN PHẨM CÒN LẠI CẦN XỬ LÝ
-- =====================================================
-- Query này hiển thị số sản phẩm còn lại chưa có đủ đơn hàng
SELECT 
    COUNT(DISTINCT sp.id) as total_products,
    COUNT(DISTINCT CASE 
        WHEN order_counts.order_count IS NULL OR order_counts.order_count < @orders_per_product 
        THEN sp.id 
    END) as products_need_orders,
    COUNT(DISTINCT CASE 
        WHEN order_counts.order_count IS NULL OR order_counts.order_count < @orders_per_product 
        THEN sp.id 
    END) DIV 5 + IF(COUNT(DISTINCT CASE 
        WHEN order_counts.order_count IS NULL OR order_counts.order_count < @orders_per_product 
        THEN sp.id 
    END) MOD 5 > 0, 1, 0) as batches_remaining
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
) order_counts ON sp.id = order_counts.product_id
WHERE sp.shop = @shop_id
  AND sp.status = 1
  AND sp.active = 0;

-- =====================================================
-- BƯỚC 1: TẠO ĐƠN HÀNG TỰ ĐỘNG CHO TẤT CẢ SẢN PHẨM CÓ BIẾN THỂ
-- =====================================================

INSERT INTO `donhang` (
    `ma_don`, `minh_hoa`, `minh_hoa2`, `user_id`, `ho_ten`, `email`, `dien_thoai`, 
    `dia_chi`, `tinh`, `huyen`, `xa`, `dropship`, `sanpham`, `tamtinh`, `coupon`, 
    `giam`, `voucher_tmdt`, `phi_ship`, `tongtien`, `kho`, `status`, `thanhtoan`, 
    `ghi_chu`, `utm_source`, `utm_campaign`, `date_update`, `date_post`, `shop_id`, 
    `shipping_provider`, `ninja_response`, `ship_support`, `sales_channel`
)
SELECT 
    CONCAT('DH', UNIX_TIMESTAMP(), '_', u.user_id, '_', FLOOR(RAND() * 10000)) as ma_don,
    '' as minh_hoa,
    '' as minh_hoa2,
    u.user_id,
    COALESCE(u.name, CONCAT('Khách hàng ', u.user_id)) as ho_ten,
    COALESCE(u.email, CONCAT('user', u.user_id, '@example.com')) as email,
    COALESCE(u.mobile, CONCAT('0900000', LPAD(u.user_id, 3, '0'))) as dien_thoai,
    COALESCE(u.dia_chi, '123 Đường ABC, Phường XYZ') as dia_chi,
    COALESCE(u.tinh, 1) as tinh,
    COALESCE(u.huyen, 1) as huyen,
    COALESCE(u.xa, 1) as xa,
    0 as dropship,
    CONCAT(
        '{"', pv.product_id, '_', pv.variant_id, '":{',
        '"id":', pv.product_id, ',',
        '"pl":', pv.variant_id, ',',
        '"quantity":1,',
        '"tieu_de":"', REPLACE(REPLACE(pv.tieu_de, '"', '\\"'), '\n', ' '), '",',
        '"anh_chinh":"', pv.minh_hoa, '",',
        '"gia_moi":', pv.gia_moi, ',',
        '"gia_cu":', pv.gia_cu, ',',
        '"ten_color":"', pv.ten_color, '",',
        '"ten_size":"', pv.ten_size, '"',
        '}}'
    ) as sanpham,
    pv.gia_moi as tamtinh,
    '' as coupon,
    0 as giam,
    NULL as voucher_tmdt,
    CASE 
        WHEN pv.gia_moi >= 3000000 THEN 50000
        ELSE 30000
    END as phi_ship,
    pv.gia_moi + CASE 
        WHEN pv.gia_moi >= 3000000 THEN 50000
        ELSE 30000
    END as tongtien,
    '' as kho,
    5 as status,
    'COD' as thanhtoan,
    '' as ghi_chu,
    '' as utm_source,
    '' as utm_campaign,
    UNIX_TIMESTAMP() as date_update,
    UNIX_TIMESTAMP() - FLOOR(RAND() * 2592000) as date_post,
    CAST(@shop_id AS CHAR) as shop_id,
    'ninja' as shipping_provider,
    NULL as ninja_response,
    0 as ship_support,
    'socdo' as sales_channel
FROM (
    -- Lấy biến thể của 5 sản phẩm đầu tiên (giới hạn để tránh timeout)
    SELECT 
        pl.id as variant_id,
        pl.sp_id as product_id,
        pl.gia_moi,
        pl.gia_cu,
        pl.ten_color,
        pl.ten_size,
        sp.tieu_de,
        sp.minh_hoa
    FROM phanloai_sanpham pl
    INNER JOIN sanpham sp ON pl.sp_id = sp.id
    INNER JOIN (
        -- Chỉ lấy 5 sản phẩm đầu tiên chưa có đủ đơn hàng
        SELECT sp2.id
        FROM sanpham sp2
        LEFT JOIN (
            SELECT 
                CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(d.sanpham, '"id":', -1), ',', 1) AS UNSIGNED) as product_id,
                COUNT(*) as order_count
            FROM donhang d
            WHERE d.shop_id = CAST(@shop_id AS CHAR)
              AND d.status = 5
              AND d.sanpham LIKE '%"id":%'
            GROUP BY product_id
        ) existing_orders ON sp2.id = existing_orders.product_id
        WHERE sp2.shop = @shop_id
          AND sp2.status = 1
          AND sp2.active = 0
          AND (existing_orders.order_count IS NULL OR existing_orders.order_count < @orders_per_product)
        ORDER BY sp2.id
        LIMIT 5
    ) selected_products ON sp.id = selected_products.id
    WHERE sp.shop = @shop_id
      AND sp.status = 1
      AND sp.active = 0
) as pv
CROSS JOIN (
    -- Lấy user từ 1-500 để phân bố đều (giới hạn 100 user để giảm timeout)
    SELECT user_id, name, email, mobile, dia_chi, tinh, huyen, xa 
    FROM user_info 
    WHERE user_id BETWEEN 1 AND 500 
    ORDER BY RAND()
    LIMIT 100
) u;

-- =====================================================
-- BƯỚC 2: TẠO ĐƠN HÀNG CHO SẢN PHẨM KHÔNG CÓ BIẾN THỂ
-- =====================================================

INSERT INTO `donhang` (
    `ma_don`, `minh_hoa`, `minh_hoa2`, `user_id`, `ho_ten`, `email`, `dien_thoai`, 
    `dia_chi`, `tinh`, `huyen`, `xa`, `dropship`, `sanpham`, `tamtinh`, `coupon`, 
    `giam`, `voucher_tmdt`, `phi_ship`, `tongtien`, `kho`, `status`, `thanhtoan`, 
    `ghi_chu`, `utm_source`, `utm_campaign`, `date_update`, `date_post`, `shop_id`, 
    `shipping_provider`, `ninja_response`, `ship_support`, `sales_channel`
)
SELECT 
    CONCAT('DH', UNIX_TIMESTAMP(), '_', u.user_id, '_', FLOOR(RAND() * 10000)) as ma_don,
    '' as minh_hoa,
    '' as minh_hoa2,
    u.user_id,
    COALESCE(u.name, CONCAT('Khách hàng ', u.user_id)) as ho_ten,
    COALESCE(u.email, CONCAT('user', u.user_id, '@example.com')) as email,
    COALESCE(u.mobile, CONCAT('0900000', LPAD(u.user_id, 3, '0'))) as dien_thoai,
    COALESCE(u.dia_chi, '123 Đường ABC, Phường XYZ') as dia_chi,
    COALESCE(u.tinh, 1) as tinh,
    COALESCE(u.huyen, 1) as huyen,
    COALESCE(u.xa, 1) as xa,
    0 as dropship,
    CONCAT(
        '{"', pnv.id, '_0":{',
        '"id":', pnv.id, ',',
        '"pl":0,',
        '"quantity":1,',
        '"tieu_de":"', REPLACE(REPLACE(pnv.tieu_de, '"', '\\"'), '\n', ' '), '",',
        '"anh_chinh":"', pnv.minh_hoa, '",',
        '"gia_moi":', pnv.gia_moi, ',',
        '"gia_cu":', pnv.gia_cu, ',',
        '"ten_color":"",',
        '"ten_size":""',
        '}}'
    ) as sanpham,
    pnv.gia_moi as tamtinh,
    '' as coupon,
    0 as giam,
    NULL as voucher_tmdt,
    CASE 
        WHEN pnv.gia_moi >= 3000000 THEN 50000
        ELSE 30000
    END as phi_ship,
    pnv.gia_moi + CASE 
        WHEN pnv.gia_moi >= 3000000 THEN 50000
        ELSE 30000
    END as tongtien,
    '' as kho,
    5 as status,
    'COD' as thanhtoan,
    '' as ghi_chu,
    '' as utm_source,
    '' as utm_campaign,
    UNIX_TIMESTAMP() as date_update,
    UNIX_TIMESTAMP() - FLOOR(RAND() * 2592000) as date_post,
    CAST(@shop_id AS CHAR) as shop_id,
    'ninja' as shipping_provider,
    NULL as ninja_response,
    0 as ship_support,
    'socdo' as sales_channel
FROM (
    -- Lấy 5 sản phẩm không có biến thể đầu tiên (giới hạn để tránh timeout)
    SELECT sp.id, sp.tieu_de, sp.minh_hoa, sp.gia_moi, sp.gia_cu
    FROM sanpham sp
    LEFT JOIN phanloai_sanpham pl ON sp.id = pl.sp_id
    INNER JOIN (
        -- Chỉ lấy 5 sản phẩm đầu tiên chưa có đủ đơn hàng
        SELECT sp2.id
        FROM sanpham sp2
        LEFT JOIN (
            SELECT 
                CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(d.sanpham, '"id":', -1), ',', 1) AS UNSIGNED) as product_id,
                COUNT(*) as order_count
            FROM donhang d
            WHERE d.shop_id = CAST(@shop_id AS CHAR)
              AND d.status = 5
              AND d.sanpham LIKE '%"id":%'
            GROUP BY product_id
        ) existing_orders ON sp2.id = existing_orders.product_id
        WHERE sp2.shop = @shop_id
          AND sp2.status = 1
          AND sp2.active = 0
          AND (existing_orders.order_count IS NULL OR existing_orders.order_count < @orders_per_product)
        ORDER BY sp2.id
        LIMIT 5
    ) selected_products ON sp.id = selected_products.id
    WHERE sp.shop = @shop_id
      AND sp.status = 1
      AND sp.active = 0
      AND pl.id IS NULL
) as pnv
CROSS JOIN (
    SELECT user_id, name, email, mobile, dia_chi, tinh, huyen, xa 
    FROM user_info 
    WHERE user_id BETWEEN 1 AND 500 
    ORDER BY RAND() 
    LIMIT 100
) u;

-- =====================================================
-- BƯỚC 3: TẠO ĐÁNH GIÁ TỰ ĐỘNG CHO TẤT CẢ SẢN PHẨM
-- =====================================================

-- Tạo đánh giá cho sản phẩm có biến thể (lấy 100 đánh giá mới nhất cho mỗi sản phẩm)
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
        WHEN MOD(d.id, 30) = 0 THEN CONCAT(
            'Đã nhận ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            CASE WHEN pl.ten_size != '' AND pl.ten_size IS NOT NULL THEN CONCAT(' ', pl.ten_size) ELSE '' END,
            '. Đúng mô tả, dùng ổn. Giao hơi chậm nhưng chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 1 THEN CONCAT(
            'Mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            '. Chất lượng ổn, giá hợp lý. Shop giao đúng hẹn.'
        )
        WHEN MOD(d.id, 30) = 2 THEN CONCAT(
            'Nhận hàng rồi. ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' đúng như hình. Đóng gói kỹ, không bị hư. Hài lòng.'
        )
        WHEN MOD(d.id, 30) = 3 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' khá tốt. Đúng mô tả, sử dụng ổn. Có thể cải thiện bao bì nhưng nhìn chung ổn.'
        )
        WHEN MOD(d.id, 30) = 4 THEN CONCAT(
            'Mình đã mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            '. Chất lượng tốt, đáp ứng kỳ vọng. Sẽ mua lại nếu cần.'
        )
        WHEN MOD(d.id, 30) = 5 THEN CONCAT(
            'Nhận được ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' rồi. Đúng mô tả, dùng tốt. Giao hàng nhanh, đóng gói cẩn thận.'
        )
        WHEN MOD(d.id, 30) = 6 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' ổn. Chất lượng đúng như hình, giá cả hợp lý. Shop phục vụ tốt.'
        )
        WHEN MOD(d.id, 30) = 7 THEN CONCAT(
            'Mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' và thấy ổn. Đúng mô tả, sử dụng tốt. Giao hơi lâu một chút nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 8 THEN CONCAT(
            'Đã nhận ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            '. Tốt, đúng như mong đợi. Đóng gói kỹ, không hư hỏng. Hài lòng.'
        )
        WHEN MOD(d.id, 30) = 9 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' chất lượng ổn. Đúng mô tả, giá hợp lý. Shop giao đúng hẹn, nhân viên nhiệt tình.'
        )
        WHEN MOD(d.id, 30) = 10 THEN CONCAT(
            'Mình mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' và khá hài lòng. Đúng mô tả, dùng ổn. Có thể cải thiện dịch vụ nhưng nhìn chung tốt.'
        )
        WHEN MOD(d.id, 30) = 11 THEN CONCAT(
            'Nhận hàng rồi. ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' đúng như quảng cáo. Chất lượng ổn, giá cả hợp lý. Sẽ ủng hộ shop tiếp.'
        )
        WHEN MOD(d.id, 30) = 12 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' tốt. Đúng mô tả, chất lượng ổn định. Giao hàng nhanh, đóng gói cẩn thận. Đáng mua.'
        )
        WHEN MOD(d.id, 30) = 13 THEN CONCAT(
            'Đã mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            '. Chất lượng ổn, đúng như hình. Giao hơi chậm nhưng vẫn trong thời gian chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 14 THEN CONCAT(
            'Nhận được ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' rồi. Tốt, đúng mô tả. Đóng gói kỹ, không bị hư. Shop phục vụ nhiệt tình.'
        )
        WHEN MOD(d.id, 30) = 15 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' khá ổn. Chất lượng đúng mô tả, giá cả hợp lý. Có thể cải thiện thời gian giao hàng nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 16 THEN CONCAT(
            'Mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' và thấy ổn. Đúng mô tả, sử dụng tốt. Giao hàng đúng hẹn. Sẽ cân nhắc mua thêm.'
        )
        WHEN MOD(d.id, 30) = 17 THEN CONCAT(
            'Đã nhận ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            '. Chất lượng tốt, đúng như hình ảnh. Shop giao đúng hẹn, nhân viên thân thiện. Hài lòng.'
        )
        WHEN MOD(d.id, 30) = 18 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' ổn định. Đúng mô tả, giá cả hợp lý. Giao hàng nhanh, đóng gói cẩn thận. Đáng giá tiền.'
        )
        WHEN MOD(d.id, 30) = 19 THEN CONCAT(
            'Mình mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' và khá hài lòng. Chất lượng ổn, đúng mô tả. Giao hơi lâu một chút nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 20 THEN CONCAT(
            'Nhận hàng rồi. ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' đúng như quảng cáo. Chất lượng ổn, giá hợp lý. Shop tư vấn nhiệt tình.'
        )
        WHEN MOD(d.id, 30) = 21 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' tốt. Đúng mô tả, chất lượng ổn định. Giao hàng nhanh. Sẽ giới thiệu cho bạn bè.'
        )
        WHEN MOD(d.id, 30) = 22 THEN CONCAT(
            'Đã mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            '. Chất lượng ổn, đúng như hình. Đóng gói kỹ, không hư hỏng. Có thể cải thiện dịch vụ nhưng nhìn chung ổn.'
        )
        WHEN MOD(d.id, 30) = 23 THEN CONCAT(
            'Nhận được ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' rồi. Tốt, đúng mô tả. Giao hàng đúng hẹn, đóng gói cẩn thận. Hài lòng.'
        )
        WHEN MOD(d.id, 30) = 24 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' khá tốt. Chất lượng đúng mô tả, giá cả hợp lý. Giao hơi chậm nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 25 THEN CONCAT(
            'Mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' và thấy ổn. Đúng mô tả, sử dụng tốt. Shop phục vụ nhiệt tình. Sẽ mua lại nếu cần.'
        )
        WHEN MOD(d.id, 30) = 26 THEN CONCAT(
            'Đã nhận ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            '. Chất lượng ổn, đúng như hình ảnh. Giao hàng nhanh, đóng gói kỹ. Đáng mua.'
        )
        WHEN MOD(d.id, 30) = 27 THEN CONCAT(
            sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' ổn. Đúng mô tả, giá cả hợp lý. Có thể cải thiện thời gian giao hàng nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 28 THEN CONCAT(
            'Mình mua ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' và khá hài lòng. Chất lượng tốt, đúng mô tả. Giao hàng đúng hẹn. Sẽ cân nhắc mua thêm nếu cần.'
        )
        ELSE CONCAT(
            'Nhận hàng rồi. ', sp.tieu_de, 
            CASE WHEN pl.ten_color != '' AND pl.ten_color IS NOT NULL THEN CONCAT(' ', pl.ten_color) ELSE '' END,
            ' đúng như quảng cáo. Chất lượng ổn, giá hợp lý. Shop tư vấn nhiệt tình, giao đúng hẹn.'
        )
    END as content,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 5
        WHEN MOD(d.id, 30) < 27 THEN 4
        ELSE 3
    END as rating,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 5
        WHEN MOD(d.id, 30) < 27 THEN 4
        ELSE 3
    END as delivery_rating,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 5
        WHEN MOD(d.id, 30) < 27 THEN 4
        ELSE 3
    END as shop_rating,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 1
        WHEN MOD(d.id, 30) < 27 THEN 1
        ELSE 0
    END as matches_description,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 1
        WHEN MOD(d.id, 30) < 27 THEN 1
        ELSE 0
    END as is_satisfied,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 'yes'
        WHEN MOD(d.id, 30) < 27 THEN 'maybe'
        ELSE 'no'
    END as will_buy_again,
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
  AND NOT EXISTS (
      SELECT 1 FROM product_comments pc3
      WHERE pc3.product_id = pl.sp_id
        AND pc3.user_id = d.user_id
        AND pc3.shop_id = @shop_id
        AND pc3.status = 'approved'
  )
  AND (
      SELECT COUNT(*) 
      FROM product_comments pc2 
      WHERE pc2.product_id = pl.sp_id 
        AND pc2.shop_id = @shop_id 
        AND pc2.status = 'approved'
  ) < 30
ORDER BY RAND();

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
        WHEN MOD(d.id, 30) = 0 THEN CONCAT(
            'Đã nhận ', sp.tieu_de, 
            '. Đúng mô tả, dùng ổn. Giao hơi chậm nhưng chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 1 THEN CONCAT(
            'Mua ', sp.tieu_de, 
            '. Chất lượng ổn, giá hợp lý. Shop giao đúng hẹn.'
        )
        WHEN MOD(d.id, 30) = 2 THEN CONCAT(
            'Nhận hàng rồi. ', sp.tieu_de, 
            ' đúng như hình. Đóng gói kỹ, không bị hư. Hài lòng.'
        )
        WHEN MOD(d.id, 30) = 3 THEN CONCAT(
            sp.tieu_de, 
            ' khá tốt. Đúng mô tả, sử dụng ổn. Có thể cải thiện bao bì nhưng nhìn chung ổn.'
        )
        WHEN MOD(d.id, 30) = 4 THEN CONCAT(
            'Mình đã mua ', sp.tieu_de, 
            '. Chất lượng tốt, đáp ứng kỳ vọng. Sẽ mua lại nếu cần.'
        )
        WHEN MOD(d.id, 30) = 5 THEN CONCAT(
            'Nhận được ', sp.tieu_de, 
            ' rồi. Đúng mô tả, dùng tốt. Giao hàng nhanh, đóng gói cẩn thận.'
        )
        WHEN MOD(d.id, 30) = 6 THEN CONCAT(
            sp.tieu_de, 
            ' ổn. Chất lượng đúng như hình, giá cả hợp lý. Shop phục vụ tốt.'
        )
        WHEN MOD(d.id, 30) = 7 THEN CONCAT(
            'Mua ', sp.tieu_de, 
            ' và thấy ổn. Đúng mô tả, sử dụng tốt. Giao hơi lâu một chút nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 8 THEN CONCAT(
            'Đã nhận ', sp.tieu_de, 
            '. Tốt, đúng như mong đợi. Đóng gói kỹ, không hư hỏng. Hài lòng.'
        )
        WHEN MOD(d.id, 30) = 9 THEN CONCAT(
            sp.tieu_de, 
            ' chất lượng ổn. Đúng mô tả, giá hợp lý. Shop giao đúng hẹn, nhân viên nhiệt tình.'
        )
        WHEN MOD(d.id, 30) = 10 THEN CONCAT(
            'Mình mua ', sp.tieu_de, 
            ' và khá hài lòng. Đúng mô tả, dùng ổn. Có thể cải thiện dịch vụ nhưng nhìn chung tốt.'
        )
        WHEN MOD(d.id, 30) = 11 THEN CONCAT(
            'Nhận hàng rồi. ', sp.tieu_de, 
            ' đúng như quảng cáo. Chất lượng ổn, giá cả hợp lý. Sẽ ủng hộ shop tiếp.'
        )
        WHEN MOD(d.id, 30) = 12 THEN CONCAT(
            sp.tieu_de, 
            ' tốt. Đúng mô tả, chất lượng ổn định. Giao hàng nhanh, đóng gói cẩn thận. Đáng mua.'
        )
        WHEN MOD(d.id, 30) = 13 THEN CONCAT(
            'Đã mua ', sp.tieu_de, 
            '. Chất lượng ổn, đúng như hình. Giao hơi chậm nhưng vẫn trong thời gian chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 14 THEN CONCAT(
            'Nhận được ', sp.tieu_de, 
            ' rồi. Tốt, đúng mô tả. Đóng gói kỹ, không bị hư. Shop phục vụ nhiệt tình.'
        )
        WHEN MOD(d.id, 30) = 15 THEN CONCAT(
            sp.tieu_de, 
            ' khá ổn. Chất lượng đúng mô tả, giá cả hợp lý. Có thể cải thiện thời gian giao hàng nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 16 THEN CONCAT(
            'Mua ', sp.tieu_de, 
            ' và thấy ổn. Đúng mô tả, sử dụng tốt. Giao hàng đúng hẹn. Sẽ cân nhắc mua thêm.'
        )
        WHEN MOD(d.id, 30) = 17 THEN CONCAT(
            'Đã nhận ', sp.tieu_de, 
            '. Chất lượng tốt, đúng như hình ảnh. Shop giao đúng hẹn, nhân viên thân thiện. Hài lòng.'
        )
        WHEN MOD(d.id, 30) = 18 THEN CONCAT(
            sp.tieu_de, 
            ' ổn định. Đúng mô tả, giá cả hợp lý. Giao hàng nhanh, đóng gói cẩn thận. Đáng giá tiền.'
        )
        WHEN MOD(d.id, 30) = 19 THEN CONCAT(
            'Mình mua ', sp.tieu_de, 
            ' và khá hài lòng. Chất lượng ổn, đúng mô tả. Giao hơi lâu một chút nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 20 THEN CONCAT(
            'Nhận hàng rồi. ', sp.tieu_de, 
            ' đúng như quảng cáo. Chất lượng ổn, giá hợp lý. Shop tư vấn nhiệt tình.'
        )
        WHEN MOD(d.id, 30) = 21 THEN CONCAT(
            sp.tieu_de, 
            ' tốt. Đúng mô tả, chất lượng ổn định. Giao hàng nhanh. Sẽ giới thiệu cho bạn bè.'
        )
        WHEN MOD(d.id, 30) = 22 THEN CONCAT(
            'Đã mua ', sp.tieu_de, 
            '. Chất lượng ổn, đúng như hình. Đóng gói kỹ, không hư hỏng. Có thể cải thiện dịch vụ nhưng nhìn chung ổn.'
        )
        WHEN MOD(d.id, 30) = 23 THEN CONCAT(
            'Nhận được ', sp.tieu_de, 
            ' rồi. Tốt, đúng mô tả. Giao hàng đúng hẹn, đóng gói cẩn thận. Hài lòng.'
        )
        WHEN MOD(d.id, 30) = 24 THEN CONCAT(
            sp.tieu_de, 
            ' khá tốt. Chất lượng đúng mô tả, giá cả hợp lý. Giao hơi chậm nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 25 THEN CONCAT(
            'Mua ', sp.tieu_de, 
            ' và thấy ổn. Đúng mô tả, sử dụng tốt. Shop phục vụ nhiệt tình. Sẽ mua lại nếu cần.'
        )
        WHEN MOD(d.id, 30) = 26 THEN CONCAT(
            'Đã nhận ', sp.tieu_de, 
            '. Chất lượng ổn, đúng như hình ảnh. Giao hàng nhanh, đóng gói kỹ. Đáng mua.'
        )
        WHEN MOD(d.id, 30) = 27 THEN CONCAT(
            sp.tieu_de, 
            ' ổn. Đúng mô tả, giá cả hợp lý. Có thể cải thiện thời gian giao hàng nhưng vẫn chấp nhận được.'
        )
        WHEN MOD(d.id, 30) = 28 THEN CONCAT(
            'Mình mua ', sp.tieu_de, 
            ' và khá hài lòng. Chất lượng tốt, đúng mô tả. Giao hàng đúng hẹn. Sẽ cân nhắc mua thêm nếu cần.'
        )
        ELSE CONCAT(
            'Nhận hàng rồi. ', sp.tieu_de, 
            ' đúng như quảng cáo. Chất lượng ổn, giá hợp lý. Shop tư vấn nhiệt tình, giao đúng hẹn.'
        )
    END as content,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 5
        WHEN MOD(d.id, 30) < 27 THEN 4
        ELSE 3
    END as rating,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 5
        WHEN MOD(d.id, 30) < 27 THEN 4
        ELSE 3
    END as delivery_rating,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 5
        WHEN MOD(d.id, 30) < 27 THEN 4
        ELSE 3
    END as shop_rating,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 1
        WHEN MOD(d.id, 30) < 27 THEN 1
        ELSE 0
    END as matches_description,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 1
        WHEN MOD(d.id, 30) < 27 THEN 1
        ELSE 0
    END as is_satisfied,
    CASE 
        WHEN MOD(d.id, 30) < 24 THEN 'yes'
        WHEN MOD(d.id, 30) < 27 THEN 'maybe'
        ELSE 'no'
    END as will_buy_again,
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
  AND NOT EXISTS (
      SELECT 1 FROM product_comments pc3
      WHERE pc3.product_id = sp.id
        AND pc3.user_id = d.user_id
        AND pc3.shop_id = @shop_id
        AND pc3.status = 'approved'
  )
  AND (
      SELECT COUNT(*) 
      FROM product_comments pc2 
      WHERE pc2.product_id = sp.id 
        AND pc2.shop_id = @shop_id 
        AND pc2.status = 'approved'
  ) < 30
ORDER BY RAND();

-- =====================================================
-- BƯỚC 4: CẬP NHẬT THỐNG KÊ ĐÁNH GIÁ TỰ ĐỘNG
-- =====================================================

-- Xóa thống kê cũ và tạo mới
DELETE FROM product_rating_stats WHERE shop_id = @shop_id;

-- Cập nhật thống kê cho tất cả sản phẩm của shop
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

-- =====================================================
-- KIỂM TRA KẾT QUẢ SAU KHI CHẠY
-- =====================================================
-- Query này hiển thị số sản phẩm còn lại cần xử lý sau lần chạy này
SELECT 
    'Tổng số sản phẩm' as info,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
WHERE sp.shop = @shop_id
  AND sp.status = 1
  AND sp.active = 0

UNION ALL

SELECT 
    'Sản phẩm đã có đủ đơn hàng' as info,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN (
    SELECT 
        CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(d.sanpham, '"id":', -1), ',', 1) AS UNSIGNED) as product_id,
        COUNT(*) as order_count
    FROM donhang d
    WHERE d.shop_id = CAST(@shop_id AS CHAR)
      AND d.status = 5
      AND d.sanpham LIKE '%"id":%'
    GROUP BY product_id
    HAVING COUNT(*) >= @orders_per_product
) order_counts ON sp.id = order_counts.product_id
WHERE sp.shop = @shop_id
  AND sp.status = 1
  AND sp.active = 0

UNION ALL

SELECT 
    'Sản phẩm còn cần xử lý' as info,
    COUNT(DISTINCT sp.id) as value
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
) order_counts ON sp.id = order_counts.product_id
WHERE sp.shop = @shop_id
  AND sp.status = 1
  AND sp.active = 0
  AND (order_counts.order_count IS NULL OR order_counts.order_count < @orders_per_product)

UNION ALL

SELECT 
    'Số lần chạy còn lại (ước tính)' as info,
    CEIL(COUNT(DISTINCT sp.id) / 5.0) as value
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
) order_counts ON sp.id = order_counts.product_id
WHERE sp.shop = @shop_id
  AND sp.status = 1
  AND sp.active = 0
  AND (order_counts.order_count IS NULL OR order_counts.order_count < @orders_per_product);

-- =====================================================
-- HOÀN TẤT
-- =====================================================
-- Script đã tự động:
-- 1. Lấy 5 sản phẩm đầu tiên chưa có đủ đơn hàng
-- 2. Lấy tất cả biến thể của 5 sản phẩm đó
-- 3. Tạo đơn hàng (30 đơn/sản phẩm/biến thể)
-- 4. Tạo đánh giá (30 đánh giá/sản phẩm)
-- 5. Cập nhật thống kê đánh giá
-- 
-- LƯU Ý: 
-- - Script chỉ xử lý 5 sản phẩm mỗi lần chạy để tránh timeout
-- - Script tự động bỏ qua sản phẩm đã có đủ đơn hàng (>= 30 đơn)
-- - Chạy lại script nhiều lần cho đến khi "Sản phẩm còn cần xử lý" = 0
-- =====================================================
