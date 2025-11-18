-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Oct 19, 2025 at 05:49 PM
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
-- Table structure for table `sanpham`
--

CREATE TABLE `sanpham` (
  `id` int(10) NOT NULL,
  `ma_sanpham` text NOT NULL,
  `tieu_de` varchar(255) NOT NULL,
  `minh_hoa` varchar(255) NOT NULL,
  `link` varchar(255) NOT NULL,
  `cat` varchar(255) NOT NULL,
  `gia_cu` int(10) NOT NULL,
  `gia_moi` int(10) NOT NULL,
  `gia_drop` int(10) NOT NULL,
  `drop_min` int(10) NOT NULL,
  `gia_ctv` int(10) NOT NULL,
  `ctv_min` int(10) NOT NULL,
  `noi_ban` varchar(160) NOT NULL,
  `noi_bat` text NOT NULL,
  `noi_dung` longtext NOT NULL,
  `mau` varchar(160) NOT NULL,
  `thuong_hieu` varchar(160) NOT NULL,
  `size` varchar(255) NOT NULL,
  `kich_thuoc` varchar(255) NOT NULL,
  `thongtin` text NOT NULL,
  `can_nang` varchar(160) NOT NULL,
  `anh` text NOT NULL,
  `sale` int(1) NOT NULL,
  `kho` int(10) NOT NULL,
  `kho_hcm` int(10) NOT NULL,
  `ban` int(10) NOT NULL,
  `box_banchay` int(1) NOT NULL,
  `box_noibat` int(1) NOT NULL,
  `cat_ma` int(1) NOT NULL,
  `box_flash` int(1) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` varchar(255) NOT NULL,
  `view` int(10) NOT NULL,
  `shop` int(11) NOT NULL,
  `status` int(11) NOT NULL,
  `date_post` varchar(11) NOT NULL,
  `can_nang_tinhship` int(11) DEFAULT NULL,
  `kho_id` int(11) NOT NULL,
  `active` int(2) DEFAULT '0' COMMENT '0:Hiển thị , 1:Ẩn Hiển Thị'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `sanpham`
--
ALTER TABLE `sanpham`
  ADD PRIMARY KEY (`id`),
  ADD KEY `kho` (`kho`),
  ADD KEY `ban` (`ban`),
  ADD KEY `noi_ban` (`noi_ban`),
  ADD KEY `cat` (`cat`),
  ADD KEY `date_post` (`date_post`),
  ADD KEY `kho_hcm` (`kho_hcm`),
  ADD KEY `box_banchay` (`box_banchay`),
  ADD KEY `box_noibat` (`box_noibat`),
  ADD KEY `box_flash` (`box_flash`),
  ADD KEY `shop` (`shop`),
  ADD KEY `link` (`link`),
  ADD KEY `status` (`status`),
  ADD KEY `tieu_de` (`tieu_de`),
  ADD KEY `kho_id` (`kho_id`),
  ADD KEY `cat_ma` (`cat_ma`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `sanpham`
--
ALTER TABLE `sanpham`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
