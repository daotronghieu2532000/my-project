-- ========================================
-- TẠO BẢNG POPUP_BANNERS
-- ========================================
-- Mục đích: Lưu trữ thông tin popup banner hiển thị trên app
-- Popup sẽ xuất hiện khi người dùng mở app, có nút X để đóng
-- Popup sẽ xuất hiện lại khi người dùng reload app

SET collation_connection = 'utf8_general_ci';

-- ========================================
-- XÓA BẢNG CŨ NẾU TỒN TẠI (CẨN THẬN!)
-- ========================================
-- DROP TABLE IF EXISTS popup_banners;

-- ========================================
-- TẠO BẢNG POPUP_BANNERS
-- ========================================
CREATE TABLE IF NOT EXISTS `popup_banners` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL COMMENT 'Tiêu đề popup banner',
  `image_url` text NOT NULL COMMENT 'URL ảnh popup banner',
  `target_url` text DEFAULT NULL COMMENT 'URL khi click vào popup (tùy chọn)',
  `start_at` datetime DEFAULT NULL COMMENT 'Thời gian bắt đầu hiển thị',
  `end_at` datetime DEFAULT NULL COMMENT 'Thời gian kết thúc hiển thị',
  `is_active` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'Trạng thái: 1 = bật, 0 = tắt',
  `priority` int(11) NOT NULL DEFAULT 0 COMMENT 'Độ ưu tiên (số cao hơn = ưu tiên hơn)',
  `display_limit_per_user` int(11) NOT NULL DEFAULT 1 COMMENT 'Số lần hiển thị tối đa cho mỗi user (0 = không giới hạn)',
  `click_count` int(11) NOT NULL DEFAULT 0 COMMENT 'Số lần click vào popup',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật',
  PRIMARY KEY (`id`),
  KEY `is_active` (`is_active`),
  KEY `priority` (`priority`),
  KEY `start_at` (`start_at`),
  KEY `end_at` (`end_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu trữ popup banner hiển thị trên app';

-- ========================================
-- KIỂM TRA SAU KHI TẠO
-- ========================================
-- SELECT * FROM popup_banners LIMIT 10;
-- DESCRIBE popup_banners;

