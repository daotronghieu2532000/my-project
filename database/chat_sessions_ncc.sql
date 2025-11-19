-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Oct 20, 2025 at 04:13 PM
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
-- Table structure for table `chat_sessions_ncc`
--

CREATE TABLE `chat_sessions_ncc` (
  `id` int(11) NOT NULL,
  `phien` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `shop_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `product_id` int(11) DEFAULT '0',
  `variant_id` int(11) DEFAULT '0',
  `last_message_time` int(11) NOT NULL,
  `unread_count_customer` int(11) DEFAULT '0',
  `unread_count_ncc` int(11) DEFAULT '0',
  `status` enum('active','closed') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `created_at` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `chat_sessions_ncc`
--
ALTER TABLE `chat_sessions_ncc`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `phien` (`phien`),
  ADD KEY `idx_phien` (`phien`),
  ADD KEY `idx_shop_customer` (`shop_id`,`customer_id`),
  ADD KEY `idx_last_message` (`last_message_time`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `chat_sessions_ncc`
--
ALTER TABLE `chat_sessions_ncc`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
