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
-- Table structure for table `coupon`
--

CREATE TABLE `coupon` (
  `id` int(10) NOT NULL,
  `shop` int(10) NOT NULL,
  `ma` varchar(255) NOT NULL,
  `giam` int(10) NOT NULL,
  `giam_toi_da` int(11) DEFAULT NULL,
  `loai` varchar(255) NOT NULL,
  `kieu` varchar(160) NOT NULL,
  `sanpham` varchar(255) NOT NULL,
  `dieu_kien` int(10) NOT NULL,
  `start` varchar(11) NOT NULL,
  `expired` varchar(11) NOT NULL,
  `status` int(1) NOT NULL,
  `mota` varchar(255) DEFAULT NULL,
  `img_loai` varchar(255) DEFAULT NULL,
  `min_price` int(11) DEFAULT '0',
  `max_price` int(11) DEFAULT '0',
  `allow_combination` tinyint(4) DEFAULT '0',
  `max_uses_per_user` int(11) DEFAULT '0',
  `max_global_uses` int(11) DEFAULT '0',
  `current_uses` int(11) DEFAULT '0',
  `date_post` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `coupon`
--
ALTER TABLE `coupon`
  ADD PRIMARY KEY (`id`),
  ADD KEY `shop` (`shop`),
  ADD KEY `start` (`start`),
  ADD KEY `expired` (`expired`),
  ADD KEY `sanpham` (`sanpham`),
  ADD KEY `kieu` (`kieu`),
  ADD KEY `loai` (`loai`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `coupon`
--
ALTER TABLE `coupon`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
