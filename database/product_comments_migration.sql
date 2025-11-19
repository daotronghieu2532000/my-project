-- Migration: Thêm các cột mới cho đánh giá chi tiết
-- Date: 2025-11-16

ALTER TABLE `product_comments` 
  ADD COLUMN `delivery_rating` int(11) DEFAULT NULL COMMENT 'Đánh giá tốc độ giao hàng (1-5 sao)' AFTER `rating`,
  ADD COLUMN `shop_rating` int(11) DEFAULT NULL COMMENT 'Đánh giá shop (1-5 sao)' AFTER `delivery_rating`,
  ADD COLUMN `matches_description` tinyint(1) DEFAULT NULL COMMENT 'Đúng với mô tả: 1=đúng, 0=không đúng' AFTER `shop_rating`,
  ADD COLUMN `is_satisfied` tinyint(1) DEFAULT NULL COMMENT 'Hài lòng: 1=hài lòng, 0=không hài lòng' AFTER `matches_description`,
  ADD COLUMN `will_buy_again` enum('yes','no','maybe') DEFAULT NULL COMMENT 'Sẽ quay lại mua: yes=có, no=không, maybe=sẽ cân nhắc' AFTER `is_satisfied`;

-- Thêm index cho các cột mới nếu cần
ALTER TABLE `product_comments`
  ADD KEY `idx_delivery_rating` (`delivery_rating`),
  ADD KEY `idx_shop_rating` (`shop_rating`);

