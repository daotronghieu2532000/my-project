-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Oct 19, 2025 at 05:52 PM
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
-- Table structure for table `user_info`
--

CREATE TABLE `user_info` (
  `user_id` bigint(11) NOT NULL,
  `shop` int(10) NOT NULL,
  `username` varchar(160) NOT NULL,
  `password` varchar(160) NOT NULL,
  `email` varchar(256) NOT NULL,
  `name` varchar(160) NOT NULL,
  `avatar` text NOT NULL,
  `user_money` int(10) NOT NULL,
  `user_money2` int(10) NOT NULL,
  `mobile` varchar(160) NOT NULL,
  `domain` varchar(255) NOT NULL,
  `ngaysinh` varchar(160) NOT NULL,
  `gioi_tinh` varchar(160) NOT NULL,
  `cmnd` varchar(160) NOT NULL,
  `ngaycap` varchar(160) NOT NULL,
  `noicap` varchar(160) NOT NULL,
  `tinh` int(10) NOT NULL,
  `huyen` int(10) NOT NULL,
  `xa` int(10) NOT NULL,
  `dia_chi` varchar(255) NOT NULL,
  `maso_thue` varchar(255) NOT NULL,
  `maso_thue_cap` varchar(255) NOT NULL,
  `maso_thue_noicap` varchar(255) NOT NULL,
  `code_active` varchar(160) NOT NULL,
  `active` int(1) NOT NULL,
  `nhan_vien` int(1) NOT NULL,
  `chinh_thuc` int(1) NOT NULL,
  `dropship` int(1) NOT NULL,
  `ctv` int(1) NOT NULL,
  `leader` int(1) NOT NULL,
  `leader_start` varchar(11) NOT NULL,
  `gia_leader` int(1) NOT NULL,
  `aff` varchar(160) NOT NULL,
  `doitac` varchar(160) NOT NULL,
  `about` text NOT NULL,
  `nhom` varchar(160) NOT NULL,
  `status_cre` int(1) DEFAULT NULL,
  `created` varchar(11) NOT NULL,
  `date_update` varchar(11) NOT NULL,
  `ip_address` varchar(160) NOT NULL,
  `logined` varchar(11) NOT NULL,
  `end_online` varchar(11) NOT NULL,
  `dk_aff` int(11) NOT NULL,
  `is_self_operated` int(2) NOT NULL DEFAULT '0' COMMENT '1 = Tự vận hành\r\n\r\n0 = Do hệ thống vận hành'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `user_info`
--
ALTER TABLE `user_info`
  ADD PRIMARY KEY (`user_id`),
  ADD KEY `shop` (`shop`),
  ADD KEY `username` (`username`),
  ADD KEY `email` (`email`(255)),
  ADD KEY `mobile` (`mobile`),
  ADD KEY `domain` (`domain`),
  ADD KEY `dropship` (`dropship`),
  ADD KEY `ctv` (`ctv`),
  ADD KEY `aff` (`aff`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `user_info`
--
ALTER TABLE `user_info`
  MODIFY `user_id` bigint(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
