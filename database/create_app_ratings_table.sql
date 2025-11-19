-- Bảng lưu đánh giá ứng dụng
CREATE TABLE IF NOT EXISTS `app_ratings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL COMMENT 'ID người dùng đánh giá',
  `rating` decimal(2,1) NOT NULL COMMENT 'Số sao đánh giá (0.5 - 5.0)',
  `comment` text DEFAULT NULL COMMENT 'Nội dung góp ý',
  `device_info` varchar(255) DEFAULT NULL COMMENT 'Thông tin thiết bị',
  `app_version` varchar(50) DEFAULT NULL COMMENT 'Phiên bản ứng dụng',
  `status` tinyint(1) DEFAULT 1 COMMENT '1: hiển thị, 0: ẩn',
  `created_at` int(11) NOT NULL COMMENT 'Thời gian tạo (timestamp)',
  `updated_at` int(11) DEFAULT NULL COMMENT 'Thời gian cập nhật (timestamp)',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `rating` (`rating`),
  KEY `created_at` (`created_at`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu đánh giá ứng dụng từ người dùng';

