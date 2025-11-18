-- ========================================
-- SET COLLATION CONNECTION TRƯỚC KHI TẠO TRIGGER
-- ========================================

-- Set collation connection để đồng nhất với database
SET collation_connection = 'utf8_general_ci';

-- Kiểm tra collation hiện tại
SELECT @@collation_connection as 'Current Collation Connection';

-- ========================================
-- XÓA TẤT CẢ TRIGGER CŨ TRƯỚC KHI TẠO MỚI
-- ========================================
DROP TRIGGER IF EXISTS tr_donhang_status_update;
DROP TRIGGER IF EXISTS tr_lichsu_chitieu_insert;
DROP TRIGGER IF EXISTS tr_coupon_insert;
DROP TRIGGER IF EXISTS tr_sanpham_aff_insert;

-- ========================================
-- 1. TRIGGER CHO BẢNG DONHANG (Đơn hàng)
-- ========================================
SET collation_connection = 'utf8_general_ci';
DELIMITER $$

CREATE TRIGGER tr_donhang_status_update
AFTER UPDATE ON donhang
FOR EACH ROW
BEGIN
    DECLARE product_title VARCHAR(255) DEFAULT '';
    DECLARE product_image TEXT DEFAULT '';
    DECLARE product_price INT DEFAULT 0;
    DECLARE first_product_id VARCHAR(255) DEFAULT '';
    DECLARE notification_title VARCHAR(255) DEFAULT '';
    DECLARE notification_content TEXT DEFAULT '';
    DECLARE priority VARCHAR(20) DEFAULT 'medium';
    DECLARE temp_image TEXT DEFAULT '';
    DECLARE temp_id VARCHAR(20) DEFAULT '';
    DECLARE v_user_exists INT DEFAULT 0;

    IF OLD.status <> NEW.status THEN
        -- Kiểm tra user tồn tại (user đăng nhập); khách vãng lai sẽ không có trong user_info
        IF NEW.user_id IS NOT NULL AND NEW.user_id > 0 THEN
            SELECT COUNT(1)
              INTO v_user_exists
              FROM user_info ui
             WHERE ui.user_id = NEW.user_id
             LIMIT 1;
        ELSE
            SET v_user_exists = 0;
        END IF;

        -- Chỉ tạo thông báo khi user hợp lệ (tránh lỗi FK)
        IF v_user_exists = 1 THEN
            -- Lấy sp_id đầu tiên từ nhiều format JSON khác nhau
            IF NEW.sanpham LIKE '%":{%' THEN
                SET temp_id = SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.sanpham, '":', 1), '"', -1);
                IF LOCATE('_', temp_id) > 0 THEN
                    SET first_product_id = SUBSTRING_INDEX(temp_id, '_', 1);
                ELSE
                    SET first_product_id = temp_id;
                END IF;
            ELSEIF NEW.sanpham LIKE '%[{%' AND NEW.sanpham LIKE '%"id":%' THEN
                SET first_product_id = SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.sanpham, '"id":', 2), '"id":', -1);
                SET first_product_id = SUBSTRING_INDEX(first_product_id, ',', 1);
                SET first_product_id = TRIM(BOTH ' ' FROM first_product_id);
            END IF;

            -- Tiêu đề
            IF NEW.sanpham LIKE '%"tieu_de":"%' THEN
                SET product_title = SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.sanpham, '"tieu_de":"', 2), '"tieu_de":"', -1);
                SET product_title = SUBSTRING_INDEX(product_title, '"', 1);
            END IF;

            -- Ảnh: minh_hoa -> anh_chinh
            SET temp_image = '';
            IF NEW.sanpham LIKE '%"minh_hoa":"%' THEN
                SET temp_image = SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.sanpham, '"minh_hoa":"', 2), '"minh_hoa":"', -1);
                SET temp_image = SUBSTRING_INDEX(temp_image, '"', 1);
                IF temp_image NOT LIKE '[%' AND temp_image NOT LIKE '{%' AND temp_image <> '' THEN
                    SET product_image = temp_image;
                END IF;
            END IF;

            IF (product_image = '' OR product_image IS NULL) AND NEW.sanpham LIKE '%"anh_chinh":"%' THEN
                SET temp_image = SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.sanpham, '"anh_chinh":"', 2), '"anh_chinh":"', -1);
                SET temp_image = SUBSTRING_INDEX(temp_image, '"', 1);
                IF temp_image NOT LIKE '[%' AND temp_image NOT LIKE '{%' AND temp_image <> '' THEN
                    SET product_image = temp_image;
                END IF;
            END IF;

            -- Giá
            IF NEW.sanpham LIKE '%"gia_moi":"%' THEN
                SET temp_image = SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.sanpham, '"gia_moi":"', 2), '"gia_moi":"', -1);
                SET temp_image = SUBSTRING_INDEX(temp_image, '"', 1);
                SET temp_image = REPLACE(temp_image, ',', '');
                SET product_price = CAST(temp_image AS UNSIGNED);
            END IF;

            -- Fallback sang bảng sanpham nếu thiếu dữ liệu
            IF (product_title = '' OR product_image = '' OR product_price = 0)
               AND first_product_id <> '' AND CAST(first_product_id AS UNSIGNED) > 0 THEN
                SELECT s.tieu_de,
                       s.minh_hoa,
                       CAST(REPLACE(COALESCE(s.gia_moi, '0'), ',', '') AS UNSIGNED)
                  INTO product_title, product_image, product_price
                FROM sanpham s
                WHERE s.id = CAST(first_product_id AS UNSIGNED)
                LIMIT 1;
            END IF;

            IF product_title = '' OR product_title IS NULL THEN SET product_title = 'Sản phẩm'; END IF;
            IF product_image = '' OR product_image IS NULL OR product_image LIKE '[%' OR product_image LIKE '{%' THEN SET product_image = ''; END IF;
            IF product_price = 0 OR product_price IS NULL THEN SET product_price = NEW.tongtien; END IF;

            -- Nội dung theo trạng thái
            CASE NEW.status
                WHEN 1 THEN
                    SET notification_title = 'Đơn hàng đã được xác nhận';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được xác nhận thành công. Chúng tôi sẽ chuẩn bị hàng và giao đến bạn sớm nhất. Cảm ơn bạn đã tin tưởng!');
                    SET priority = 'medium';
                WHEN 2 THEN
                    SET notification_title = 'Đơn hàng đang được giao';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đang được giao hàng. Vui lòng chuẩn bị nhận hàng và thanh toán khi nhận được. Cảm ơn bạn!');
                    SET priority = 'high';
                WHEN 3 THEN
                    SET notification_title = 'Đơn hàng đã giao thành công';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được giao thành công. Cảm ơn bạn đã mua sắm tại cửa hàng của chúng tôi!');
                    SET priority = 'medium';
                WHEN 4 THEN
                    SET notification_title = 'Đơn hàng đã bị hủy';
                    SET notification_content = CONCAT('Rất tiếc, đơn hàng "', product_title, '" đã bị hủy. Nếu bạn có thắc mắc, vui lòng liên hệ với chúng tôi để được hỗ trợ.');
                    SET priority = 'high';
                WHEN 5 THEN
                    SET notification_title = 'Đơn hàng đã hoàn trả';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được hoàn trả thành công. Số tiền sẽ được chuyển về tài khoản của bạn trong thời gian sớm nhất.');
                    SET priority = 'high';
                ELSE
                    SET notification_title = 'Cập nhật đơn hàng';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được cập nhật trạng thái. Vui lòng kiểm tra chi tiết trong ứng dụng.');
            END CASE;

            INSERT INTO notification_mobile (
                user_id, type, title, content, data, related_id, related_type, priority, is_read, created_at
            ) VALUES (
                NEW.user_id, 'order', notification_title, notification_content,
                CONCAT('{"order_id":', NEW.id, ',"order_code":"', NEW.ma_don, '","product_title":"', product_title, '","product_image":"', product_image, '","product_price":', product_price, ',"old_status":', OLD.status, ',"new_status":', NEW.status, ',"total_amount":', NEW.tongtien, '}'),
                NEW.id, 'order', priority, 0, UNIX_TIMESTAMP()
            );
        END IF; -- v_user_exists
    END IF; -- status changed
END$$

DELIMITER ;

-- ========================================
-- 2. TRIGGER CHO BẢNG LICHSU_CHITIEU (Nạp/Rút tiền)
-- ========================================
CREATE TRIGGER tr_lichsu_chitieu_insert 
AFTER INSERT ON lichsu_chitieu 
FOR EACH ROW 
BEGIN
    DECLARE notification_title VARCHAR(255) DEFAULT '';
    DECLARE notification_content TEXT DEFAULT '';
    DECLARE notification_type VARCHAR(50) DEFAULT '';
    DECLARE priority VARCHAR(20) DEFAULT 'medium';
    
    IF NEW.noidung LIKE '%nạp%' OR NEW.noidung LIKE '%deposit%' THEN
        SET notification_title = 'Nạp tiền thành công';
        SET notification_content = CONCAT('Chúc mừng! Bạn đã nạp thành công ', FORMAT(NEW.sotien, 0), '₫ vào tài khoản. Số dư hiện tại đã được cập nhật. Cảm ơn bạn!');
        SET notification_type = 'deposit';
        SET priority = 'medium';
        
        INSERT INTO notification_mobile (
            user_id, type, title, content, data, related_id, related_type, priority, is_read, created_at
        ) VALUES (
            NEW.user_id, notification_type, notification_title, notification_content,
            CONCAT('{"amount":', NEW.sotien, ',"method":"Chuyển khoản","transaction_type":"deposit","balance_after":', NEW.sotien, '}'),
            NEW.id, 'transaction', priority, 0, UNIX_TIMESTAMP()
        );
        
    ELSEIF NEW.noidung LIKE '%rút%' OR NEW.noidung LIKE '%withdrawal%' THEN
        SET notification_title = 'Yêu cầu rút tiền đã được gửi';
        SET notification_content = CONCAT('Yêu cầu rút ', FORMAT(NEW.sotien, 0), '₫ của bạn đã được gửi thành công. Chúng tôi sẽ xử lý trong thời gian sớm nhất và thông báo lại cho bạn. Cảm ơn!');
        SET notification_type = 'withdrawal';
        SET priority = 'medium';
        
        INSERT INTO notification_mobile (
            user_id, type, title, content, data, related_id, related_type, priority, is_read, created_at
        ) VALUES (
            NEW.user_id, notification_type, notification_title, notification_content,
            CONCAT('{"amount":', NEW.sotien, ',"status":"pending","method":"Chuyển khoản","transaction_type":"withdrawal","estimated_time":"1-3 ngày làm việc"}'),
            NEW.id, 'transaction', priority, 0, UNIX_TIMESTAMP()
        );
    END IF;
END$$

-- ========================================
-- 3. TRIGGER CHO BẢNG COUPON (Voucher mới)
-- ========================================
CREATE TRIGGER tr_coupon_insert 
AFTER INSERT ON coupon 
FOR EACH ROW 
BEGIN
    INSERT INTO notification_mobile (
        user_id, type, title, content, data, related_id, related_type, priority, is_read, created_at
    ) 
    SELECT 
        u.user_id, 'voucher_new', CONCAT('Voucher mới: ', NEW.ma),
        CONCAT('🎉 Tin vui! Bạn có voucher mới "', NEW.ma, '" giảm ', FORMAT(NEW.giam, 0), '₫. Hạn sử dụng đến ', DATE_FORMAT(FROM_UNIXTIME(NEW.expired), '%d/%m/%Y'), '. Đừng bỏ lỡ cơ hội tiết kiệm này nhé!'),
        CONCAT('{"voucher_code":"', NEW.ma, '","discount_amount":', NEW.giam, ',"expired_date":', NEW.expired, ',"shop_id":', NEW.shop, ',"min_order":', IFNULL(NEW.dieu_kien, 0), '}'),
        NEW.id, 'coupon', 'medium', 0, UNIX_TIMESTAMP()
    FROM user_info u 
    WHERE u.shop = NEW.shop AND u.active = 1;
END$$

-- ========================================
-- 4. TRIGGER CHO BẢNG SANPHAM_AFF (Affiliate)
-- ========================================
CREATE TRIGGER tr_sanpham_aff_insert 
AFTER INSERT ON sanpham_aff 
FOR EACH ROW 
BEGIN
    INSERT INTO notification_mobile (
        user_id, type, title, content, data, related_id, related_type, priority, is_read, created_at
    ) 
    SELECT 
        u.user_id, 'affiliate_order', CONCAT('Sản phẩm Affiliate mới: ', NEW.tieu_de),
        CONCAT('💰 Cơ hội kiếm tiền mới! Sản phẩm "', NEW.tieu_de, '" đã được thêm vào chương trình affiliate với hoa hồng hấp dẫn. Hãy chia sẻ ngay để kiếm thêm thu nhập nhé!'),
        CONCAT('{"product_title":"', NEW.tieu_de, '","shop_id":', NEW.shop, ',"date_start":', NEW.date_start, ',"date_end":', NEW.date_end, ',"commission_rate":"10%"}'),
        NEW.id, 'affiliate_product', 'high', 0, UNIX_TIMESTAMP()
    FROM user_info u 
    WHERE u.aff = '1' AND u.active = 1;
END$$

DELIMITER ;

-- ========================================
-- KIỂM TRA COLLATION SAU KHI TẠO TRIGGER
-- ========================================
SELECT @@collation_connection as 'Final Collation Connection';
SHOW TRIGGERS;

-- ========================================
-- HOÀN THÀNH SỬA COLLATION CONNECTION
-- ========================================
