-- phpMyAdmin SQL Dump
-- Table: device_tokens
-- Mô tả: Lưu vér các thiết bị để gửi push notifications

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `socdo`
--

-- --------------------------------------------------------

--
-- Table structure for table `device_tokens`
--

CREATE TABLE IF NOT EXISTS `device_tokens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(11) NOT NULL COMMENT 'ID người dùng',
  `device_token` varchar(191) NOT NULL COMMENT 'FCM Token từ Firebase',
  `platform` enum('android','ios') NOT NULL COMMENT 'Nền tảng: android hoặc ios',
  `app_version` varchar(20) DEFAULT NULL COMMENT 'Version của app (ví dụ: 1.0.0)',
  `device_model` varchar(100) DEFAULT NULL COMMENT 'Model thiết bị (ví dụ: Samsung Galaxy S21)',
  `is_active` tinyint(1) DEFAULT 1 COMMENT '1: active (nhận push), 0: inactive',
  `last_used_at` int(11) DEFAULT NULL COMMENT 'Timestamp lần cuối sử dụng token',
  `created_at` int(11) NOT NULL COMMENT 'Timestamp tạo record',
  `updated_at` int(11) DEFAULT NULL COMMENT 'Timestamp cập nhật',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_device_token` (`user_id`,`device_token`),
  KEY `device_token` (`device_token`),
  KEY `user_id` (`user_id`),
  KEY `is_active` (`is_active`),
  KEY `platform` (`platform`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Lưu FCM tokens để gửi push notifications';

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
COMMIT;

