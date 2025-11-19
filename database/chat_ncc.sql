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
-- Table structure for table `chat_ncc`
--

CREATE TABLE `chat_ncc` (
  `id` int(11) NOT NULL,
  `phien` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `shop_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `sender_id` int(11) NOT NULL,
  `sender_type` enum('customer','ncc') COLLATE utf8mb4_unicode_ci NOT NULL,
  `noi_dung` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `doc` tinyint(1) DEFAULT '0',
  `active` tinyint(1) DEFAULT '1',
  `date_post` int(11) NOT NULL,
  `product_id` int(11) DEFAULT '0',
  `variant_id` int(11) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `chat_ncc`
--

INSERT INTO `chat_ncc` (`id`, `phien`, `shop_id`, `customer_id`, `sender_id`, `sender_type`, `noi_dung`, `doc`, `active`, `date_post`, `product_id`, `variant_id`) VALUES
(1, 'ad40d88e9c458f050eabc2d8b6d94b41', 12400, 8050, 8050, 'customer', 'xin chào', 0, 1, 1754013393, 0, 0),
(2, '230f2c4729b6373246bd5edff8188ffa', 9016, 8050, 8050, 'customer', 'heloo nhà bán , , tôi cần mua chiếc điện thoại này', 1, 1, 1754013746, 0, 0),
(3, '230f2c4729b6373246bd5edff8188ffa', 9016, 8050, 9016, 'ncc', 'bạn cần mua gì', 1, 1, 1754013758, 0, 0),
(4, '4fe1c083eb1be20d45947804348af1da', 12400, 23570, 23570, 'customer', 'áp dụng voucher chỗ nào thế shop', 0, 1, 1754017900, 0, 0),
(5, 'add8acfc5c161296efad3446e340df1b', 20755, 25807, 25807, 'customer', 'hello', 1, 1, 1754124518, 0, 0),
(6, 'add8acfc5c161296efad3446e340df1b', 20755, 25807, 25807, 'customer', 'tôi muốn hỏi về thông tin sản phẩm', 1, 1, 1754124553, 0, 0),
(7, 'add8acfc5c161296efad3446e340df1b', 20755, 25807, 25807, 'customer', ':))', 1, 1, 1754124567, 0, 0),
(8, 'add8acfc5c161296efad3446e340df1b', 20755, 25807, 25807, 'customer', 'mày đùa ta à', 1, 1, 1754124579, 0, 0),
(9, 'add8acfc5c161296efad3446e340df1b', 20755, 25807, 20755, 'ncc', 'anh đi chết đi', 0, 1, 1754129372, 0, 0),
(10, 'add8acfc5c161296efad3446e340df1b', 20755, 25807, 20755, 'ncc', 'dám trêu em', 0, 1, 1754129382, 0, 0),
(11, '663d47e86972fce5461996b6b5e4bed4', 23933, 8185, 8185, 'customer', 'hihi xin chào .', 1, 1, 1754575025, 0, 0),
(12, '663d47e86972fce5461996b6b5e4bed4', 23933, 8185, 23933, 'ncc', 'Chào bạn', 1, 1, 1754636850, 0, 0),
(13, 'ad9341c69a007923b3b136ff69b42baf', 23933, 27306, 27306, 'customer', 'hello hellooooo', 1, 1, 1755058005, 0, 0),
(14, 'ad9341c69a007923b3b136ff69b42baf', 23933, 27306, 27306, 'customer', 'abcassđf', 1, 1, 1755058024, 0, 0),
(15, 'ad9341c69a007923b3b136ff69b42baf', 23933, 27306, 27306, 'customer', 'xin chao socdo choice', 1, 1, 1755058064, 0, 0),
(16, 'e0eaa70470cdb1c0e6c366e1add84d18', 23933, 8050, 8050, 'customer', 'chào o', 1, 1, 1755680434, 0, 0),
(17, 'e0eaa70470cdb1c0e6c366e1add84d18', 23933, 8050, 8050, 'customer', 'hihi', 1, 1, 1755680460, 0, 0),
(18, 'e0eaa70470cdb1c0e6c366e1add84d18', 23933, 8050, 8050, 'customer', 'chào nhà bán', 1, 1, 1755680499, 0, 0),
(19, '230f2c4729b6373246bd5edff8188ffa', 9016, 8050, 8050, 'customer', 'tôi cần mua túi sách', 1, 1, 1755680519, 0, 0),
(20, 'c74fec6d5d19d36f3cb4738fc786a6b4', 23933, 28456, 28456, 'customer', 'hihi chào cậu', 1, 1, 1755711928, 0, 0),
(21, 'c74fec6d5d19d36f3cb4738fc786a6b4', 23933, 28456, 28456, 'customer', 'chào', 1, 1, 1755711940, 0, 0),
(22, '068ae68c27590c76f55301cfc15d4a07', 16552, 28456, 28456, 'customer', 'chào', 1, 1, 1755711979, 0, 0),
(23, '068ae68c27590c76f55301cfc15d4a07', 16552, 28456, 28456, 'customer', 'bên đó là >', 1, 1, 1755711984, 0, 0),
(24, '068ae68c27590c76f55301cfc15d4a07', 16552, 28456, 28456, 'customer', 'gì vậy', 1, 1, 1755711987, 0, 0),
(25, '068ae68c27590c76f55301cfc15d4a07', 16552, 28456, 28456, 'customer', 'xin chào', 1, 1, 1755712025, 0, 0),
(26, '068ae68c27590c76f55301cfc15d4a07', 16552, 28456, 28456, 'customer', 'hih', 1, 1, 1755712027, 0, 0),
(27, '068ae68c27590c76f55301cfc15d4a07', 16552, 28456, 28456, 'customer', 'hihih', 1, 1, 1755712029, 0, 0),
(28, '59cb9182441e9f5819547fd88fe1fc56', 20755, 28456, 28456, 'customer', 'xin chào qưuyeiqu yeiquw uq eq ưiyei uqwe qưeqwe q', 1, 1, 1755712069, 0, 0),
(29, '1ef193463d589ae8a7923c66a0b38cc4', 17768, 28456, 28456, 'customer', 'xin chào', 0, 1, 1755712242, 0, 0),
(30, '1ef193463d589ae8a7923c66a0b38cc4', 17768, 28456, 28456, 'customer', 'xin chào', 0, 1, 1755712250, 0, 0),
(31, '0081ba21906af43014379d22b100fb45', 10143, 28456, 28456, 'customer', 'xin chào', 0, 1, 1755712303, 0, 0),
(32, 'c74fec6d5d19d36f3cb4738fc786a6b4', 23933, 28456, 28456, 'customer', 'hihi', 1, 1, 1755713772, 0, 0),
(33, '5630b4910c23849f3020d3f24898793b', 17768, 8050, 8050, 'customer', 'xin chào', 0, 1, 1755718001, 0, 0),
(34, '5630b4910c23849f3020d3f24898793b', 17768, 8050, 8050, 'customer', 'tôi quan tâm xe máy', 0, 1, 1755718007, 0, 0),
(35, '068ae68c27590c76f55301cfc15d4a07', 16552, 28456, 16552, 'ncc', 'Dạ chào anh chị', 1, 1, 1755740949, 0, 0),
(36, '068ae68c27590c76f55301cfc15d4a07', 16552, 28456, 16552, 'ncc', 'Anh chị đang gặp vấn đề gì cần hỗ trợ ạ?', 1, 1, 1755740975, 0, 0),
(37, '59cb9182441e9f5819547fd88fe1fc56', 20755, 28456, 20755, 'ncc', 'Spam à anh', 0, 1, 1755771463, 0, 0),
(38, '230f2c4729b6373246bd5edff8188ffa', 9016, 8050, 8050, 'customer', 'hihi', 1, 1, 1756011191, 0, 0),
(39, '230f2c4729b6373246bd5edff8188ffa', 9016, 8050, 8050, 'customer', 'xin chào', 1, 1, 1756011194, 0, 0),
(40, '230f2c4729b6373246bd5edff8188ffa', 9016, 8050, 8050, 'customer', 'tôi cần mua điện thoại di động', 1, 1, 1756011206, 0, 0),
(41, 'e0eaa70470cdb1c0e6c366e1add84d18', 23933, 8050, 8050, 'customer', 'hii xin chào', 1, 1, 1756086481, 0, 0),
(42, '230f2c4729b6373246bd5edff8188ffa', 9016, 8050, 8050, 'customer', 'điện thoài', 1, 1, 1756086865, 0, 0),
(43, 'e0eaa70470cdb1c0e6c366e1add84d18', 23933, 8050, 8050, 'customer', 'test chát', 1, 1, 1756652616, 0, 0),
(44, '8ae4650fec025d58922982df485c3b5a', 31469, 8316, 8316, 'customer', '123', 1, 1, 1759393778, 0, 0),
(45, '933e49beb7580f45380028aa739ee03b', 31503, 8316, 8316, 'customer', 'xin chào bạn', 1, 1, 1760248472, 0, 0),
(46, '933e49beb7580f45380028aa739ee03b', 31503, 8316, 31503, 'ncc', 'dạ shop chào anh ạ', 0, 1, 1760411800, 0, 0),
(47, '933e49beb7580f45380028aa739ee03b', 31503, 8316, 31503, 'ncc', 'anh cần shop hỗ trợ thông tin gì ạ', 0, 1, 1760411822, 0, 0);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `chat_ncc`
--
ALTER TABLE `chat_ncc`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_phien` (`phien`),
  ADD KEY `idx_shop_customer` (`shop_id`,`customer_id`),
  ADD KEY `idx_date_post` (`date_post`),
  ADD KEY `idx_sender` (`sender_id`,`sender_type`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `chat_ncc`
--
ALTER TABLE `chat_ncc`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=48;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
