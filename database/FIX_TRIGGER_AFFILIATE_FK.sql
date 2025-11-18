-- ========================================
-- FIX TRIGGER tr_sanpham_aff_insert - Foreign Key Constraint
-- ========================================
-- Vấn đề: Trigger đang insert notification với user_id từ device_tokens
-- nhưng user_id có thể không tồn tại trong user_info (user_id = 0 hoặc user đã bị xóa)
-- → Gây lỗi Foreign Key Constraint

SET collation_connection = 'utf8_general_ci';

-- Xóa trigger cũ
DROP TRIGGER IF EXISTS tr_sanpham_aff_insert;

-- Tạo lại trigger với JOIN user_info để đảm bảo user_id hợp lệ
DELIMITER $$

CREATE TRIGGER tr_sanpham_aff_insert 
AFTER INSERT ON sanpham_aff 
FOR EACH ROW 
BEGIN
    -- ✅ CHỈ GỬI ĐẾN USER CÓ DEVICE_TOKEN ACTIVE, user_id hợp lệ trong user_info VÀ last_used_at TRONG VÒNG 90 NGÀY (TRÁNH TOKEN CŨ)
    INSERT INTO notification_mobile (
        user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
    ) 
    SELECT DISTINCT
        dt.user_id, 
        'affiliate_product', 
        CONCAT('Sản phẩm Affiliate mới: ', NEW.tieu_de),
        CONCAT('Cơ hội kiếm tiền hấp dẫn! Sản phẩm "', NEW.tieu_de, '" vừa được thêm vào chương trình affiliate với hoa hồng hấp dẫn. Hãy chia sẻ ngay để kiếm thêm thu nhập từ mỗi đơn hàng thành công nhé!'),
        CONCAT('{"product_title":"', NEW.tieu_de, '","shop_id":', NEW.shop, ',"date_start":', NEW.date_start, ',"date_end":', NEW.date_end, ',"commission_rate":"10%"}'),
        NEW.id, 
        'affiliate_product', 
        'high', 
        0, 
        0, 
        UNIX_TIMESTAMP()
    FROM device_tokens dt
    INNER JOIN user_info u ON dt.user_id = u.user_id
    WHERE dt.is_active = 1
    AND dt.user_id > 0
    AND u.active = 1
    AND (dt.last_used_at IS NULL OR dt.last_used_at >= (UNIX_TIMESTAMP() - 90*24*3600));
    -- ✅ Điều kiện:
    -- - device_token active (is_active = 1)
    -- - user_id > 0 (không phải unregistered user)
    -- - user_id tồn tại trong user_info (JOIN để tránh FK constraint error)
    -- - user active = 1 (tài khoản hoạt động)
    -- - last_used_at trong vòng 90 ngày qua (hoặc NULL - token mới) để tránh gửi cho token cũ không dùng nữa
END$$

DELIMITER ;

-- Kiểm tra trigger đã được tạo
SHOW TRIGGERS LIKE 'tr_sanpham_aff%';

