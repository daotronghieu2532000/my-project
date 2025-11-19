-- =====================================================
-- Script tự động cập nhật cột BAN (số lượng đã bán) 
-- dựa trên số lượng đánh giá
-- 
-- Công thức: ban = tổng số đánh giá + random(1-10)
-- Ví dụ: 20 đánh giá → ban = 20 + random(1-10) = 21-30
-- 
-- LƯU Ý: Chỉ cập nhật sản phẩm có ban = 0
-- =====================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

-- =====================================================
-- KIỂM TRA TRƯỚC KHI CẬP NHẬT
-- =====================================================
-- Xem có bao nhiêu sản phẩm có đánh giá nhưng ban = 0
SELECT 
    'Tổng sản phẩm có đánh giá' as info,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
UNION ALL
SELECT 
    'Sản phẩm có đánh giá nhưng ban = 0' as info,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban = 0
UNION ALL
SELECT 
    'Sản phẩm có ban > 0 (sẽ bỏ qua)' as info,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
WHERE sp.ban > 0;

-- =====================================================
-- CẬP NHẬT CỘT BAN DỰA TRÊN SỐ ĐÁNH GIÁ
-- =====================================================
-- Cập nhật ban = tổng số đánh giá + random(1-10)
-- Chỉ cập nhật sản phẩm có ban = 0
UPDATE sanpham sp
INNER JOIN (
    SELECT 
        product_id,
        COUNT(*) as total_reviews
    FROM product_comments
    WHERE status = 'approved'
    GROUP BY product_id
) review_counts ON sp.id = review_counts.product_id
SET sp.ban = review_counts.total_reviews + FLOOR(1 + RAND() * 10)
WHERE sp.ban = 0;

-- =====================================================
-- KIỂM TRA KẾT QUẢ SAU KHI CẬP NHẬT
-- =====================================================
-- Xem kết quả sau khi cập nhật
SELECT 
    'Tổng sản phẩm đã cập nhật' as info,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban > 0
UNION ALL
SELECT 
    'Sản phẩm vẫn còn ban = 0' as info,
    COUNT(DISTINCT sp.id) as value
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban = 0
UNION ALL
SELECT 
    'Ví dụ: Sản phẩm có 20 đánh giá' as info,
    COUNT(*) as value
FROM sanpham sp
INNER JOIN (
    SELECT product_id, COUNT(*) as total_reviews
    FROM product_comments
    WHERE status = 'approved'
    GROUP BY product_id
    HAVING COUNT(*) = 20
) review_counts ON sp.id = review_counts.product_id
WHERE sp.ban BETWEEN 21 AND 30;

-- =====================================================
-- XEM CHI TIẾT MỘT SỐ SẢN PHẨM ĐÃ CẬP NHẬT
-- =====================================================
-- Xem 10 sản phẩm đầu tiên đã được cập nhật
SELECT 
    sp.id,
    sp.tieu_de,
    sp.ban as so_luong_ban,
    COUNT(pc.id) as tong_danh_gia,
    sp.ban - COUNT(pc.id) as so_random_da_cong
FROM sanpham sp
INNER JOIN product_comments pc ON sp.id = pc.product_id
WHERE pc.status = 'approved'
AND sp.ban > 0
GROUP BY sp.id, sp.tieu_de, sp.ban
ORDER BY sp.id
LIMIT 10;

-- =====================================================
-- HOÀN TẤT
-- =====================================================
-- Script đã tự động:
-- 1. Đếm tổng số đánh giá (status = 'approved') cho mỗi sản phẩm
-- 2. Cập nhật cột ban = tổng đánh giá + random(1-10)
-- 3. Chỉ cập nhật sản phẩm có ban = 0 (bỏ qua sản phẩm đã có ban > 0)
-- 
-- LƯU Ý:
-- - Script chỉ cập nhật 1 lần cho mỗi sản phẩm
-- - Sản phẩm đã có ban > 0 sẽ không bị thay đổi
-- - Giá trị random sẽ khác nhau cho mỗi sản phẩm
-- =====================================================

