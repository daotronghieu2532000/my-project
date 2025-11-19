-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Nov 14, 2025 at 11:15 AM
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
-- Table structure for table `ncc_yeu_cau_banner_sanpham`
--

CREATE TABLE `ncc_yeu_cau_banner_sanpham` (
  `id` int(11) NOT NULL,
  `ncc_id` bigint(11) NOT NULL COMMENT 'user_id của NCC (từ user_info)',
  `shop_name` varchar(255) NOT NULL COMMENT 'Tên shop (lấy từ user_info.name)',
  `banner_path` varchar(500) NOT NULL COMMENT 'Đường dẫn file banner',
  `banner_type` varchar(20) NOT NULL COMMENT 'banner_doc hoặc banner_ngang',
  `banner_width` int(11) DEFAULT NULL COMMENT 'Chiều rộng banner',
  `banner_height` int(11) DEFAULT NULL COMMENT 'Chiều cao banner',
  `sanpham_ids` text NOT NULL COMMENT 'Danh sách ID sản phẩm, cách nhau bởi dấu phẩy (10 sản phẩm)',
  `banner_link` varchar(500) DEFAULT NULL COMMENT 'Link khi click vào banner',
  `vi_tri_hien_thi` varchar(20) DEFAULT NULL COMMENT 'dau_trang, giua_trang, cuoi_trang',
  `status` int(1) NOT NULL DEFAULT '0' COMMENT '0=chờ duyệt, 1=đang hiển thị, 2=chờ hiển thị, 3=từ chối',
  `ly_do_tu_choi` text COMMENT 'Lý do từ chối từ admin',
  `date_created` varchar(11) NOT NULL COMMENT 'Thời gian tạo yêu cầu (timestamp)',
  `date_approved` varchar(11) DEFAULT NULL COMMENT 'Thời gian admin duyệt (timestamp)',
  `date_display_start` varchar(11) DEFAULT NULL COMMENT 'Thời gian bắt đầu hiển thị (timestamp)',
  `date_display_end` varchar(11) DEFAULT NULL COMMENT 'Thời gian kết thúc hiển thị (timestamp)',
  `so_ngay_hien_thi` int(11) DEFAULT NULL COMMENT 'Số ngày hiển thị admin chọn',
  `admin_approved_id` int(11) DEFAULT NULL COMMENT 'ID admin duyệt (từ user_info của admin)',
  `date_updated` varchar(11) DEFAULT NULL COMMENT 'Thời gian cập nhật cuối'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `ncc_yeu_cau_banner_sanpham`
--
ALTER TABLE `ncc_yeu_cau_banner_sanpham`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ncc_id` (`ncc_id`),
  ADD KEY `status` (`status`),
  ADD KEY `vi_tri_hien_thi` (`vi_tri_hien_thi`),
  ADD KEY `date_display_end` (`date_display_end`),
  ADD KEY `date_created` (`date_created`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `ncc_yeu_cau_banner_sanpham`
--
ALTER TABLE `ncc_yeu_cau_banner_sanpham`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
