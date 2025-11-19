-- Bảng lưu báo lỗi từ người dùng
CREATE TABLE IF NOT EXISTS `app_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL COMMENT 'ID người dùng báo lỗi',
  `image_urls` text DEFAULT NULL COMMENT 'Danh sách ảnh (JSON array)',
  `description` text NOT NULL COMMENT 'Mô tả chi tiết lỗi',
  `device_info` varchar(255) DEFAULT NULL COMMENT 'Thông tin thiết bị',
  `app_version` varchar(50) DEFAULT NULL COMMENT 'Phiên bản ứng dụng',
  `status` varchar(50) DEFAULT 'pending' COMMENT 'Trạng thái: pending, reviewed, fixed, rejected',
  `admin_notes` text DEFAULT NULL COMMENT 'Ghi chú từ admin',
  `created_at` int(11) NOT NULL COMMENT 'Thời gian tạo (timestamp)',
  `updated_at` int(11) DEFAULT NULL COMMENT 'Thời gian cập nhật (timestamp)',
  `reviewed_at` int(11) DEFAULT NULL COMMENT 'Thời gian admin xem (timestamp)',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `status` (`status`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu báo lỗi từ người dùng';

