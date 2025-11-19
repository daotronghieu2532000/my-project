-- =====================================================
-- SCRIPT KIỂM TRA VÀ XÁC MINH CẬP NHẬT CỘT BAN
-- Chạy script này TRƯỚC và SAU khi chạy update_ban_from_reviews.sql
-- =====================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

-- =====================================================
-- BƯỚC 1: KIỂM TRA TRƯỚC KHI CẬP NHẬT
-- =====================================================
-- Xem tình trạng hiện tại
SELECT 
    '=== TÌNH TRẠNG HIỆN TẠI ===' as section,
    '' as product_id,
    '' as product_name,
    '' as current_ban,
    '' as total_reviews,
    '' as expected_ban_range;

-- Tổng số sản phẩm có đánh giá
SELECT 
    'Tổng sản phẩm có đánh giá' as metric,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved';

-- Sản phẩm có đánh giá nhưng ban = 0 (sẽ được cập nhật)
SELECT 
    'Sản phẩm có đánh giá nhưng ban = 0 (sẽ cập nhật)' as metric,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban = 0;

-- Sản phẩm đã có ban > 0 (sẽ bỏ qua)
SELECT 
    'Sản phẩm đã có ban > 0 (sẽ bỏ qua)' as metric,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
WHERE sp.ban > 0;

-- =====================================================
-- BƯỚC 2: XEM VÍ DỤ SẢN PHẨM SẼ ĐƯỢC CẬP NHẬT
-- =====================================================
-- Xem 10 sản phẩm đầu tiên sẽ được cập nhật (ban = 0)
SELECT 
    '=== 10 SẢN PHẨM SẼ ĐƯỢC CẬP NHẬT (ban = 0) ===' as section,
    '' as product_id,
    '' as product_name,
    '' as current_ban,
    '' as total_reviews,
    '' as expected_ban_range;

SELECT 
    sp.id as product_id,
    LEFT(sp.tieu_de, 50) as product_name,
    sp.ban as current_ban,
    COUNT(pc.id) as total_reviews,
    CONCAT(COUNT(pc.id), ' + random(1-10) = ', COUNT(pc.id) + 1, ' đến ', COUNT(pc.id) + 10) as expected_ban_range
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban = 0
GROUP BY sp.id, sp.tieu_de, sp.ban
ORDER BY sp.id
LIMIT 10;

-- =====================================================
-- BƯỚC 3: XEM VÍ DỤ SẢN PHẨM SẼ BỊ BỎ QUA
-- =====================================================
-- Xem 5 sản phẩm có ban > 0 (sẽ bị bỏ qua)
SELECT 
    '=== 5 SẢN PHẨM SẼ BỊ BỎ QUA (ban > 0) ===' as section,
    '' as product_id,
    '' as product_name,
    '' as current_ban,
    '' as total_reviews,
    '' as note;

SELECT 
    sp.id as product_id,
    LEFT(sp.tieu_de, 50) as product_name,
    sp.ban as current_ban,
    COUNT(pc.id) as total_reviews,
    'Sẽ BỎ QUA (ban đã có giá trị)' as note
FROM sanpham sp
LEFT JOIN product_comments pc ON sp.id = pc.product_id AND pc.status = 'approved'
WHERE sp.ban > 0
GROUP BY sp.id, sp.tieu_de, sp.ban
ORDER BY sp.id
LIMIT 5;

-- =====================================================
-- BƯỚC 4: KIỂM TRA SAU KHI CẬP NHẬT
-- (Chạy phần này SAU khi chạy UPDATE)
-- =====================================================
-- Tổng số sản phẩm đã được cập nhật
SELECT 
    '=== KẾT QUẢ SAU KHI CẬP NHẬT ===' as section,
    '' as product_id,
    '' as product_name,
    '' as current_ban,
    '' as total_reviews,
    '' as random_added;

SELECT 
    'Tổng sản phẩm đã được cập nhật (ban > 0)' as metric,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban > 0;

-- Sản phẩm vẫn còn ban = 0 (nếu có)
SELECT 
    'Sản phẩm vẫn còn ban = 0 (có thể không có đánh giá)' as metric,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban = 0;

-- =====================================================
-- BƯỚC 5: XÁC MINH CÔNG THỨC ĐÚNG
-- =====================================================
-- Xem 20 sản phẩm đã cập nhật và kiểm tra công thức
SELECT 
    '=== XÁC MINH CÔNG THỨC: ban = tổng đánh giá + random(1-10) ===' as section,
    '' as product_id,
    '' as product_name,
    '' as ban_value,
    '' as total_reviews,
    '' as random_added,
    '' as is_correct;

SELECT 
    sp.id as product_id,
    LEFT(sp.tieu_de, 40) as product_name,
    sp.ban as ban_value,
    COUNT(pc.id) as total_reviews,
    sp.ban - COUNT(pc.id) as random_added,
    CASE 
        WHEN (sp.ban - COUNT(pc.id)) BETWEEN 1 AND 10 THEN '✅ ĐÚNG'
        ELSE '❌ SAI'
    END as is_correct
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban > 0
GROUP BY sp.id, sp.tieu_de, sp.ban
HAVING (sp.ban - COUNT(pc.id)) NOT BETWEEN 1 AND 10  -- Chỉ hiển thị nếu SAI
ORDER BY sp.id
LIMIT 20;

-- Nếu query trên trả về 0 rows, nghĩa là TẤT CẢ đều đúng!

-- =====================================================
-- BƯỚC 6: THỐNG KÊ CHI TIẾT
-- =====================================================
-- Phân bố số lượng random đã cộng
SELECT 
    '=== PHÂN BỐ SỐ RANDOM ĐÃ CỘNG ===' as section,
    '' as random_value,
    '' as count_products;

SELECT 
    random_value,
    COUNT(*) as count_products
FROM (
    SELECT 
        sp.id,
        (sp.ban - COUNT(pc.id)) as random_value
    FROM sanpham sp
    INNER JOIN product_comments pc ON sp.id = pc.product_id
    WHERE pc.status = 'approved'
    AND sp.ban > 0
    GROUP BY sp.id, sp.ban
    HAVING (sp.ban - COUNT(pc.id)) BETWEEN 1 AND 10
) as product_random
GROUP BY random_value
ORDER BY random_value;

-- =====================================================
-- BƯỚC 7: VÍ DỤ CỤ THỂ
-- =====================================================
-- Xem 10 sản phẩm với thông tin chi tiết
SELECT 
    '=== 10 SẢN PHẨM MẪU SAU KHI CẬP NHẬT ===' as section,
    '' as product_id,
    '' as product_name,
    '' as ban_value,
    '' as total_reviews,
    '' as random_added,
    '' as formula;

SELECT 
    sp.id as product_id,
    LEFT(sp.tieu_de, 35) as product_name,
    sp.ban as ban_value,
    COUNT(pc.id) as total_reviews,
    sp.ban - COUNT(pc.id) as random_added,
    CONCAT(COUNT(pc.id), ' + ', sp.ban - COUNT(pc.id), ' = ', sp.ban) as formula
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban > 0
GROUP BY sp.id, sp.tieu_de, sp.ban
ORDER BY sp.id
LIMIT 10;

-- =====================================================
-- KẾT LUẬN
-- =====================================================
-- Nếu tất cả các sản phẩm có:
-- - ban > 0
-- - (ban - total_reviews) BETWEEN 1 AND 10
-- 
-- Thì script đã hoạt động ĐÚNG! ✅
-- =====================================================

