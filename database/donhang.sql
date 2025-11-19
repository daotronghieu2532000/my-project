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
-- Table structure for table `donhang`
--

CREATE TABLE `donhang` (
  `id` int(10) NOT NULL,
  `ma_don` varchar(160) NOT NULL,
  `minh_hoa` text NOT NULL,
  `minh_hoa2` text NOT NULL,
  `user_id` int(10) NOT NULL,
  `ho_ten` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `dien_thoai` varchar(160) NOT NULL,
  `dia_chi` varchar(255) NOT NULL,
  `tinh` int(10) NOT NULL,
  `huyen` int(10) NOT NULL,
  `xa` int(10) NOT NULL,
  `dropship` int(1) NOT NULL,
  `sanpham` text NOT NULL,
  `tamtinh` int(10) NOT NULL,
  `coupon` varchar(255) NOT NULL,
  `giam` int(10) NOT NULL,
  `voucher_tmdt` int(11) DEFAULT NULL,
  `phi_ship` int(10) NOT NULL,
  `tongtien` int(10) NOT NULL,
  `kho` varchar(160) NOT NULL,
  `status` int(1) NOT NULL,
  `thanhtoan` varchar(160) NOT NULL,
  `ghi_chu` text NOT NULL,
  `utm_source` varchar(160) NOT NULL,
  `utm_campaign` varchar(160) NOT NULL,
  `date_update` varchar(11) NOT NULL,
  `date_post` varchar(11) NOT NULL,
  `shop_id` varchar(255) NOT NULL,
  `shipping_provider` varchar(100) NOT NULL,
  `ninja_response` longtext,
  `ship_support` int(11) NOT NULL DEFAULT '0',
  `sales_channel` varchar(11) NOT NULL DEFAULT 'socdo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `donhang`
--
ALTER TABLE `donhang`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `date_post` (`date_post`),
  ADD KEY `status` (`status`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `donhang`
--
ALTER TABLE `donhang`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
