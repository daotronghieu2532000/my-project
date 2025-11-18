-- Tạo bảng splash_screens để quản lý ảnh splash screen cho app mobile
CREATE TABLE IF NOT EXISTS `splash_screens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL COMMENT 'Tiêu đề splash screen',
  `image_url` varchar(500) NOT NULL COMMENT 'URL ảnh splash screen',
  `is_active` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Trạng thái: 1=Bật, 0=Tắt',
  `priority` int(11) NOT NULL DEFAULT '0' COMMENT 'Độ ưu tiên (số cao hơn = ưu tiên cao hơn)',
  `start_at` datetime DEFAULT NULL COMMENT 'Thời gian bắt đầu hiển thị',
  `end_at` datetime DEFAULT NULL COMMENT 'Thời gian kết thúc hiển thị',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật',
  PRIMARY KEY (`id`),
  KEY `idx_active_priority` (`is_active`, `priority`),
  KEY `idx_time_range` (`start_at`, `end_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng quản lý splash screen cho app mobile';

