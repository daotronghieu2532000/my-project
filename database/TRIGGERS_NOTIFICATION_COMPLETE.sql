-- ========================================
-- TRIGGER NOTIFICATION HOÀN CHỈNH - TẤT CẢ LOGIC ĐÃ SỬA
-- ========================================
-- Mục đích: 
-- - Đơn hàng: Gửi notification cho user khi tạo đơn mới và thay đổi trạng thái
-- - Voucher: Chỉ gửi cho user có ctv = 0, shop = 0, active = 1 VÀ có device_token active
-- - Affiliate: Chỉ gửi cho user có device_token active và last_used_at trong vòng 90 ngày
-- - Nạp/Rút tiền: Gửi notification cho user khi nạp/rút tiền
-- - Tất cả notification đều có push_sent = 0 để queue processor xử lý

SET collation_connection = 'utf8_general_ci';

-- ========================================
-- XÓA TẤT CẢ TRIGGER CŨ TRƯỚC KHI TẠO MỚI
-- ========================================
DROP TRIGGER IF EXISTS tr_donhang_insert;
DROP TRIGGER IF EXISTS tr_donhang_status_update;
DROP TRIGGER IF EXISTS tr_lichsu_chitieu_insert;
DROP TRIGGER IF EXISTS tr_coupon_insert;
DROP TRIGGER IF EXISTS tr_sanpham_aff_insert;

-- ========================================
-- 1. TRIGGER CHO BẢNG DONHANG - INSERT (Đơn hàng mới)
-- ========================================
DELIMITER $$

CREATE TRIGGER tr_donhang_insert
AFTER INSERT ON donhang
FOR EACH ROW
BEGIN
    DECLARE v_user_exists INT DEFAULT 0;
    
    -- Kiểm tra user tồn tại
    IF NEW.user_id IS NOT NULL AND NEW.user_id > 0 THEN
        SELECT COUNT(1) INTO v_user_exists
        FROM user_info ui
        WHERE ui.user_id = NEW.user_id
        LIMIT 1;
    END IF;
    
    -- Chỉ tạo notification khi user hợp lệ và status = 0 (đơn hàng mới)
    IF v_user_exists = 1 AND NEW.status = 0 THEN
        INSERT INTO notification_mobile (
            user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
        ) VALUES (
            NEW.user_id,
            'order',
            CONCAT('Đơn hàng mới #', NEW.ma_don),
            CONCAT('Bạn vừa đặt đơn hàng #', NEW.ma_don, ' với tổng giá trị ', FORMAT(NEW.tongtien, 0), '₫. Đơn hàng đang được xử lý.'),
            CONCAT('{"order_id":', NEW.id, ',"order_code":"', NEW.ma_don, '","total_amount":', NEW.tongtien, ',"status":', NEW.status, '}'),
            NEW.id,
            'order',
            'high',
            0,
            0,
            UNIX_TIMESTAMP()
        );
    END IF;
END$$

-- ========================================
-- 2. TRIGGER CHO BẢNG DONHANG - UPDATE (Thay đổi trạng thái đơn hàng)
-- ========================================
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

            -- Nội dung theo trạng thái (theo đúng mapping trong orders_list.php)
            CASE NEW.status
                WHEN 1 THEN
                    -- 1: Đã tiếp nhận đơn
                    SET notification_title = 'Đơn hàng đã được tiếp nhận';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được tiếp nhận thành công. Chúng tôi sẽ chuẩn bị hàng và giao đến bạn sớm nhất. Cảm ơn bạn đã tin tưởng!');
                    SET priority = 'medium';
                WHEN 2 THEN
                    -- 2: Đã giao đơn vị vận chuyển
                    SET notification_title = 'Đơn hàng đã giao cho đơn vị vận chuyển';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được giao cho đơn vị vận chuyển. Đơn hàng sẽ được giao đến bạn trong thời gian sớm nhất. Cảm ơn bạn!');
                    SET priority = 'high';
                WHEN 3 THEN
                    -- 3: Yêu cầu hủy đơn
                    SET notification_title = 'Yêu cầu hủy đơn hàng';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã có yêu cầu hủy đơn. Chúng tôi đang xử lý yêu cầu của bạn và sẽ thông báo kết quả sớm nhất.');
                    SET priority = 'high';
                WHEN 4 THEN
                    -- 4: Đã hủy đơn
                    SET notification_title = 'Đơn hàng đã bị hủy';
                    SET notification_content = CONCAT('Rất tiếc, đơn hàng "', product_title, '" đã bị hủy. Nếu bạn có thắc mắc, vui lòng liên hệ với chúng tôi để được hỗ trợ.');
                    SET priority = 'high';
                WHEN 5 THEN
                    -- 5: Giao thành công
                    SET notification_title = 'Đơn hàng đã giao thành công';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được giao thành công. Cảm ơn bạn đã mua sắm tại cửa hàng của chúng tôi!');
                    SET priority = 'medium';
                WHEN 6 THEN
                    -- 6: Đã hoàn đơn
                    SET notification_title = 'Đơn hàng đã hoàn trả';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được hoàn trả thành công. Số tiền sẽ được chuyển về tài khoản của bạn trong thời gian sớm nhất.');
                    SET priority = 'high';
                WHEN 7 THEN
                    -- 7: Lỗi khi giao hàng
                    SET notification_title = 'Lỗi khi giao hàng';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" gặp lỗi khi giao hàng. Chúng tôi đang xử lý và sẽ liên hệ với bạn sớm nhất.');
                    SET priority = 'high';
                WHEN 8 THEN
                    -- 8: Đang vận chuyển
                    SET notification_title = 'Đơn hàng đang vận chuyển';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đang được vận chuyển. Vui lòng chuẩn bị nhận hàng và thanh toán khi nhận được. Cảm ơn bạn!');
                    SET priority = 'high';
                WHEN 9 THEN
                    -- 9: Đang chờ lên lịch lại
                    SET notification_title = 'Đang chờ lên lịch lại giao hàng';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đang chờ lên lịch lại giao hàng. Chúng tôi sẽ thông báo thời gian giao hàng mới cho bạn sớm nhất.');
                    SET priority = 'medium';
                WHEN 10 THEN
                    -- 10: Đã phân công tài xế
                    SET notification_title = 'Đã phân công tài xế giao hàng';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được phân công tài xế. Đơn hàng sẽ được giao đến bạn trong thời gian sớm nhất.');
                    SET priority = 'high';
                WHEN 11 THEN
                    -- 11: Đã lấy hàng
                    SET notification_title = 'Đã lấy hàng';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được lấy hàng. Đơn hàng đang trên đường đến bạn. Cảm ơn bạn!');
                    SET priority = 'high';
                WHEN 12 THEN
                    -- 12: Đã đến bưu cục
                    SET notification_title = 'Đơn hàng đã đến bưu cục';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã đến bưu cục. Đơn hàng sẽ được giao đến bạn trong thời gian sớm nhất.');
                    SET priority = 'high';
                WHEN 14 THEN
                    -- 14: Ngoại lệ trả hàng
                    SET notification_title = 'Ngoại lệ trả hàng';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" có ngoại lệ trả hàng. Chúng tôi đang xử lý và sẽ liên hệ với bạn sớm nhất.');
                    SET priority = 'high';
                ELSE
                    -- Trạng thái khác (0: Chờ xử lý hoặc status không xác định)
                    SET notification_title = 'Cập nhật đơn hàng';
                    SET notification_content = CONCAT('Đơn hàng "', product_title, '" đã được cập nhật trạng thái. Vui lòng kiểm tra chi tiết trong ứng dụng.');
                    SET priority = 'medium';
            END CASE;

            -- ✅ THÊM push_sent = 0 vào INSERT
            INSERT INTO notification_mobile (
                user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
            ) VALUES (
                NEW.user_id, 'order', notification_title, notification_content,
                CONCAT('{"order_id":', NEW.id, ',"order_code":"', NEW.ma_don, '","product_title":"', product_title, '","product_image":"', product_image, '","product_price":', product_price, ',"old_status":', OLD.status, ',"new_status":', NEW.status, ',"total_amount":', NEW.tongtien, '}'),
                NEW.id, 'order', priority, 0, 0, UNIX_TIMESTAMP()
            );
        END IF; -- v_user_exists
    END IF; -- status changed
END$$

-- ========================================
-- 3. TRIGGER CHO BẢNG LICHSU_CHITIEU (Nạp/Rút tiền)
-- ========================================
CREATE TRIGGER tr_lichsu_chitieu_insert 
AFTER INSERT ON lichsu_chitieu 
FOR EACH ROW 
BEGIN
    DECLARE notification_title VARCHAR(255) DEFAULT '';
    DECLARE notification_content TEXT DEFAULT '';
    DECLARE notification_type VARCHAR(50) DEFAULT '';
    DECLARE priority VARCHAR(20) DEFAULT 'medium';
    DECLARE v_user_exists INT DEFAULT 0;
    
    -- Kiểm tra user tồn tại
    IF NEW.user_id IS NOT NULL AND NEW.user_id > 0 THEN
        SELECT COUNT(1) INTO v_user_exists
        FROM user_info ui
        WHERE ui.user_id = NEW.user_id
        LIMIT 1;
    END IF;
    
    -- Chỉ tạo notification cho user hợp lệ
    IF v_user_exists = 1 THEN
        IF NEW.noidung LIKE '%nạp%' OR NEW.noidung LIKE '%deposit%' THEN
            SET notification_title = 'Nạp tiền thành công';
            SET notification_content = CONCAT('Chúc mừng! Bạn đã nạp thành công ', FORMAT(NEW.sotien, 0), '₫ vào tài khoản. Số dư của bạn đã được cập nhật và sẵn sàng để sử dụng. Cảm ơn bạn đã tin tưởng dịch vụ của chúng tôi!');
            SET notification_type = 'deposit';
            SET priority = 'medium';
            
            INSERT INTO notification_mobile (
                user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
            ) VALUES (
                NEW.user_id, notification_type, notification_title, notification_content,
                CONCAT('{"amount":', NEW.sotien, ',"method":"Chuyển khoản","transaction_type":"deposit","balance_after":', NEW.sotien, '}'),
                NEW.id, 'transaction', priority, 0, 0, UNIX_TIMESTAMP()
            );
            
        ELSEIF NEW.noidung LIKE '%rút%' OR NEW.noidung LIKE '%withdrawal%' THEN
            SET notification_title = 'Yêu cầu rút tiền đã được tiếp nhận';
            SET notification_content = CONCAT('Yêu cầu rút ', FORMAT(NEW.sotien, 0), '₫ của bạn đã được tiếp nhận thành công. Chúng tôi đang xử lý yêu cầu của bạn và sẽ hoàn tất trong thời gian sớm nhất. Cảm ơn bạn đã kiên nhẫn!');
            SET notification_type = 'withdrawal';
            SET priority = 'medium';
            
            INSERT INTO notification_mobile (
                user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
            ) VALUES (
                NEW.user_id, notification_type, notification_title, notification_content,
                CONCAT('{"amount":', NEW.sotien, ',"status":"pending","method":"Chuyển khoản","transaction_type":"withdrawal","estimated_time":"1-3 ngày làm việc"}'),
                NEW.id, 'transaction', priority, 0, 0, UNIX_TIMESTAMP()
            );
        END IF;
    END IF;
END$$

-- ========================================
-- 4. TRIGGER CHO BẢNG COUPON (Voucher mới)
-- ========================================
-- ✅ CHỈ GỬI CHO USER CÓ ctv = 0, shop = 0, active = 1 VÀ CÓ DEVICE_TOKEN ACTIVE
CREATE TRIGGER tr_coupon_insert 
AFTER INSERT ON coupon 
FOR EACH ROW 
BEGIN
    DECLARE discount_text VARCHAR(255) DEFAULT '';
    DECLARE expired_date_text VARCHAR(50) DEFAULT '';
    
    -- Format discount
    IF NEW.loai = 'phantram' THEN
        SET discount_text = CONCAT(NEW.giam, '%');
    ELSE
        SET discount_text = CONCAT(FORMAT(NEW.giam, 0), '₫');
    END IF;
    
    -- Format expired date
    SET expired_date_text = DATE_FORMAT(FROM_UNIXTIME(NEW.expired), '%d/%m/%Y');
    
    -- ✅ CHỈ GỬI ĐẾN USER CÓ ctv = 0, shop = 0, active = 1 VÀ CÓ DEVICE_TOKEN ACTIVE (KHÁCH HÀNG THỰC TẾ DÙNG APP)
    INSERT INTO notification_mobile (
        user_id, type, title, content, data, related_id, related_type, priority, is_read, push_sent, created_at
    ) 
    SELECT DISTINCT
        u.user_id, 
        'voucher_new', 
        CONCAT('Voucher mới: ', NEW.ma),
        CONCAT('Tin vui! Bạn có voucher mới "', NEW.ma, '" giảm ', discount_text, '. Áp dụng cho tất cả sản phẩm. Hạn sử dụng đến ', expired_date_text, '. Đừng bỏ lỡ cơ hội tiết kiệm tuyệt vời này nhé!'),
        CONCAT('{"voucher_code":"', NEW.ma, '","discount_amount":', NEW.giam, ',"discount_type":"', NEW.loai, '","expired_date":', NEW.expired, ',"shop_id":', NEW.shop, ',"min_order":', IFNULL(NEW.dieu_kien, 0), ',"voucher_type":"all"}'),
        NEW.id, 
        'coupon', 
        'medium', 
        0, 
        0, 
        UNIX_TIMESTAMP()
    FROM user_info u 
    INNER JOIN device_tokens dt ON u.user_id = dt.user_id
    WHERE u.ctv = 0 
    AND u.shop = 0
    AND u.active = 1
    AND dt.is_active = 1;
    -- ✅ Điều kiện: 
    -- - ctv = 0 (khách hàng, không phải CTV)
    -- - shop = 0 (không phải shop owner, chỉ khách hàng thông thường)
    -- - active = 1 (tài khoản hoạt động)
    -- - có device_token active (user thực tế dùng app)
END$$

-- ========================================
-- 5. TRIGGER CHO BẢNG SANPHAM_AFF (Affiliate product mới)
-- ========================================
-- ✅ CHỈ GỬI CHO USER CÓ DEVICE_TOKEN ACTIVE VÀ last_used_at TRONG VÒNG 90 NGÀY
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

-- ========================================
-- KIỂM TRA SAU KHI TẠO
-- ========================================
SHOW TRIGGERS;

-- ========================================
-- KIỂM TRA CHI TIẾT TỪNG TRIGGER
-- ========================================
SHOW TRIGGERS LIKE 'tr_donhang%';
SHOW TRIGGERS LIKE 'tr_lichsu%';
SHOW TRIGGERS LIKE 'tr_coupon%';
SHOW TRIGGERS LIKE 'tr_sanpham%';

