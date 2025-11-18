-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Oct 03, 2025 at 03:09 PM
-- Server version: 10.1.48-MariaDB
-- PHP Version: 7.3.31

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;


-- Database: `socdo`
--

-- --------------------------------------------------------

--
-- Table structure for table `phanloai_sanpham`
--

CREATE TABLE `phanloai_sanpham` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `sp_id` int(11) NOT NULL,
  `ma_sp` varchar(255) NOT NULL,
  `color` varchar(160) DEFAULT NULL,
  `size` varchar(160) NOT NULL,
  `ten_size` varchar(160) NOT NULL,
  `ten_color` varchar(160) NOT NULL,
  `ma_mau` varchar(160) NOT NULL,
  `can_nang` decimal(10,2) NOT NULL,
  `gia_cu` int(11) NOT NULL,
  `gia_moi` int(11) NOT NULL,
  `gia_drop` int(11) NOT NULL,
  `gia_ctv` int(11) NOT NULL,
  `drop_min` int(11) NOT NULL,
  `kho_sanpham_socdo` int(10) NOT NULL,
  `can_nang_tinhship` decimal(10,2) NOT NULL,
  `date_post` varchar(11) NOT NULL,
  `image_phanloai` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `phanloai_sanpham`
--
ALTER TABLE `phanloai_sanpham`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sp_id` (`sp_id`),
  ADD KEY `ma_sp` (`ma_sp`),
  ADD KEY `size` (`size`),
  ADD KEY `color` (`color`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `phanloai_sanpham`
--
ALTER TABLE `phanloai_sanpham`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
