-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Oct 19, 2025 at 05:51 PM
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
-- Table structure for table `category_sanpham`
--

CREATE TABLE `category_sanpham` (
  `cat_id` int(10) NOT NULL,
  `cat_icon` varchar(160) NOT NULL,
  `cat_tieude` text NOT NULL,
  `cat_noidung` text NOT NULL,
  `cat_main` int(10) NOT NULL,
  `cat_blank` text NOT NULL,
  `cat_index` int(1) NOT NULL,
  `cat_link` varchar(255) NOT NULL,
  `cat_img` varchar(255) NOT NULL,
  `cat_minhhoa` varchar(255) NOT NULL,
  `cat_trend` int(1) NOT NULL,
  `cat_noibat` int(1) NOT NULL,
  `cat_title` varchar(160) NOT NULL,
  `cat_description` varchar(256) NOT NULL,
  `cat_thutu` int(4) NOT NULL,
  `hoa_hong` varchar(160) NOT NULL,
  `status` int(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `category_sanpham`
--
ALTER TABLE `category_sanpham`
  ADD PRIMARY KEY (`cat_id`),
  ADD KEY `cat_trend` (`cat_trend`),
  ADD KEY `cat_noibat` (`cat_noibat`),
  ADD KEY `hoa_hong` (`hoa_hong`),
  ADD KEY `cat_main` (`cat_main`),
  ADD KEY `cat_index` (`cat_index`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `category_sanpham`
--
ALTER TABLE `category_sanpham`
  MODIFY `cat_id` int(10) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
