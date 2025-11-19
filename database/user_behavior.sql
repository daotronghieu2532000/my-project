-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Jan 19, 2025
-- Server version: 10.1.48-MariaDB
-- PHP Version: 7.3.31

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
-- Table structure for table `user_behavior`
-- Lưu tất cả hành vi người dùng để phục vụ gợi ý sản phẩm
--

CREATE TABLE `user_behavior` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(11) NOT NULL COMMENT 'ID người dùng',
  `behavior_type` varchar(50) NOT NULL COMMENT 'Loại hành vi: search, view, cart, favorite, order',
  `product_id` int(11) DEFAULT NULL COMMENT 'ID sản phẩm (null nếu là search)',
  `keyword` varchar(255) DEFAULT NULL COMMENT 'Từ khóa tìm kiếm (chỉ dùng cho search)',
  `category_id` int(11) DEFAULT NULL COMMENT 'ID danh mục (nếu có)',
  `metadata` text COMMENT 'Thông tin bổ sung dạng JSON (VD: giá, shop_id, ...)',
  `created_at` int(11) NOT NULL COMMENT 'Thời gian tạo (Unix timestamp)',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `behavior_type` (`behavior_type`),
  KEY `product_id` (`product_id`),
  KEY `created_at` (`created_at`),
  KEY `user_behavior_idx` (`user_id`, `behavior_type`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Lưu lịch sử hành vi người dùng để gợi ý sản phẩm';

COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

