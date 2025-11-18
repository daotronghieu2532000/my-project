-- =====================================================
-- Script tạo đơn hàng và đánh giá từ dữ liệu thực tế
-- Mỗi sản phẩm: 100 đơn hàng (status=5) + 100 đánh giá
-- Sử dụng user_id từ 1-500
-- =====================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

-- =====================================================
-- BƯỚC 1: TẠO ĐƠN HÀNG CHO 5 SẢN PHẨM
-- =====================================================

-- Sản phẩm 1: KATA ACC220 (product_id: 3781, variant_id: 4238, shop_id: 23933, gia_moi: 999000)
INSERT INTO `donhang` (
    `ma_don`, `minh_hoa`, `minh_hoa2`, `user_id`, `ho_ten`, `email`, `dien_thoai`, 
    `dia_chi`, `tinh`, `huyen`, `xa`, `dropship`, `sanpham`, `tamtinh`, `coupon`, 
    `giam`, `voucher_tmdt`, `phi_ship`, `tongtien`, `kho`, `status`, `thanhtoan`, 
    `ghi_chu`, `utm_source`, `utm_campaign`, `date_update`, `date_post`, `shop_id`, 
    `shipping_provider`, `ninja_response`, `ship_support`, `sales_channel`
)
SELECT 
    CONCAT('DH', UNIX_TIMESTAMP(), '_', u.user_id, '_', FLOOR(RAND() * 10000)) as ma_don,
    '' as minh_hoa,
    '' as minh_hoa2,
    u.user_id,
    COALESCE(u.name, CONCAT('Khách hàng ', u.user_id)) as ho_ten,
    COALESCE(u.email, CONCAT('user', u.user_id, '@example.com')) as email,
    COALESCE(u.mobile, CONCAT('0900000', LPAD(u.user_id, 3, '0'))) as dien_thoai,
    COALESCE(u.dia_chi, '123 Đường ABC, Phường XYZ') as dia_chi,
    COALESCE(u.tinh, 1) as tinh,
    COALESCE(u.huyen, 1) as huyen,
    COALESCE(u.xa, 1) as xa,
    0 as dropship,
    CONCAT('{"', 3781, '_', 4238, '":{"id":3781,"pl":4238,"quantity":1,"tieu_de":"Máy đo nồng độ cồn cầm tay KATA ACC220 – Màn hình LCD, cảm biến thông minh, đo nhanh, cảnh báo chính xác","anh_chinh":"/uploads/minh-hoa/may-do-nong-do-con-cam-tay-kata-acc220-man-hinh-lcd-cam-bien-thong-minh-do-nhanh-canh-bao-chinh-xac-1753929235.jpg","gia_moi":999000,"gia_cu":1089000,"ten_color":"Màu đen","ten_size":"Size M"}}') as sanpham,
    999000 as tamtinh,
    '' as coupon,
    0 as giam,
    NULL as voucher_tmdt,
    30000 as phi_ship,
    1029000 as tongtien,
    '' as kho,
    5 as status,
    'COD' as thanhtoan,
    '' as ghi_chu,
    '' as utm_source,
    '' as utm_campaign,
    UNIX_TIMESTAMP() as date_update,
    UNIX_TIMESTAMP() - FLOOR(RAND() * 2592000) as date_post,
    '23933' as shop_id,
    'ninja' as shipping_provider,
    NULL as ninja_response,
    0 as ship_support,
    'socdo' as sales_channel
FROM (
    SELECT user_id, name, email, mobile, dia_chi, tinh, huyen, xa 
    FROM user_info 
    WHERE user_id BETWEEN 1 AND 500 
    ORDER BY RAND() 
    LIMIT 100
) u;

-- Sản phẩm 2: KATA ACC110 (product_id: 3783, variant_id: 4240, shop_id: 23933, gia_moi: 699000)
INSERT INTO `donhang` (
    `ma_don`, `minh_hoa`, `minh_hoa2`, `user_id`, `ho_ten`, `email`, `dien_thoai`, 
    `dia_chi`, `tinh`, `huyen`, `xa`, `dropship`, `sanpham`, `tamtinh`, `coupon`, 
    `giam`, `voucher_tmdt`, `phi_ship`, `tongtien`, `kho`, `status`, `thanhtoan`, 
    `ghi_chu`, `utm_source`, `utm_campaign`, `date_update`, `date_post`, `shop_id`, 
    `shipping_provider`, `ninja_response`, `ship_support`, `sales_channel`
)
SELECT 
    CONCAT('DH', UNIX_TIMESTAMP(), '_', u.user_id, '_', FLOOR(RAND() * 10000)) as ma_don,
    '' as minh_hoa,
    '' as minh_hoa2,
    u.user_id,
    COALESCE(u.name, CONCAT('Khách hàng ', u.user_id)) as ho_ten,
    COALESCE(u.email, CONCAT('user', u.user_id, '@example.com')) as email,
    COALESCE(u.mobile, CONCAT('0900000', LPAD(u.user_id, 3, '0'))) as dien_thoai,
    COALESCE(u.dia_chi, '123 Đường ABC, Phường XYZ') as dia_chi,
    COALESCE(u.tinh, 1) as tinh,
    COALESCE(u.huyen, 1) as huyen,
    COALESCE(u.xa, 1) as xa,
    0 as dropship,
    CONCAT('{"', 3783, '_', 4240, '":{"id":3783,"pl":4240,"quantity":1,"tieu_de":"Máy đo nồng độ cồn cầm tay KATA ACC110 – Màn hình LCD, cảm biến nhanh, cảnh báo an toàn chính xác cao","anh_chinh":"/uploads/minh-hoa/may-do-nong-do-con-cam-tay-kata-acc110-man-hinh-lcd-cam-bien-nhanh-canh-bao-an-toan-chinh-xac-cao-1753870388.jpg","gia_moi":699000,"gia_cu":759000,"ten_color":"Màu đen","ten_size":"Size M"}}') as sanpham,
    699000 as tamtinh,
    '' as coupon,
    0 as giam,
    NULL as voucher_tmdt,
    30000 as phi_ship,
    729000 as tongtien,
    '' as kho,
    5 as status,
    'COD' as thanhtoan,
    '' as ghi_chu,
    '' as utm_source,
    '' as utm_campaign,
    UNIX_TIMESTAMP() as date_update,
    UNIX_TIMESTAMP() - FLOOR(RAND() * 2592000) as date_post,
    '23933' as shop_id,
    'ninja' as shipping_provider,
    NULL as ninja_response,
    0 as ship_support,
    'socdo' as sales_channel
FROM (
    SELECT user_id, name, email, mobile, dia_chi, tinh, huyen, xa 
    FROM user_info 
    WHERE user_id BETWEEN 1 AND 500 
    ORDER BY RAND() 
    LIMIT 100
) u;

-- Sản phẩm 3: KATAG1 (product_id: 3784, variant_id: 4242, shop_id: 23933, gia_moi: 999000)
INSERT INTO `donhang` (
    `ma_don`, `minh_hoa`, `minh_hoa2`, `user_id`, `ho_ten`, `email`, `dien_thoai`, 
    `dia_chi`, `tinh`, `huyen`, `xa`, `dropship`, `sanpham`, `tamtinh`, `coupon`, 
    `giam`, `voucher_tmdt`, `phi_ship`, `tongtien`, `kho`, `status`, `thanhtoan`, 
    `ghi_chu`, `utm_source`, `utm_campaign`, `date_update`, `date_post`, `shop_id`, 
    `shipping_provider`, `ninja_response`, `ship_support`, `sales_channel`
)
SELECT 
    CONCAT('DH', UNIX_TIMESTAMP(), '_', u.user_id, '_', FLOOR(RAND() * 10000)) as ma_don,
    '' as minh_hoa,
    '' as minh_hoa2,
    u.user_id,
    COALESCE(u.name, CONCAT('Khách hàng ', u.user_id)) as ho_ten,
    COALESCE(u.email, CONCAT('user', u.user_id, '@example.com')) as email,
    COALESCE(u.mobile, CONCAT('0900000', LPAD(u.user_id, 3, '0'))) as dien_thoai,
    COALESCE(u.dia_chi, '123 Đường ABC, Phường XYZ') as dia_chi,
    COALESCE(u.tinh, 1) as tinh,
    COALESCE(u.huyen, 1) as huyen,
    COALESCE(u.xa, 1) as xa,
    0 as dropship,
    CONCAT('{"', 3784, '_', 4242, '":{"id":3784,"pl":4242,"quantity":1,"tieu_de":"Máy tăm nước KATA G1 – Làm sạch kẽ răng, 5 chế độ phun, 4 đầu thay, pin sạc 2000mAh, chống nước IPX7","anh_chinh":"/uploads/minh-hoa/may-tam-nuoc-kata-g1-lam-sach-ke-rang-5-che-do-phun-4-dau-thay-pin-sac-2000mah-chong-nuoc-ipx7-1753868897.jpg","gia_moi":999000,"gia_cu":1529000,"ten_color":"Màu trắng","ten_size":"Size M"}}') as sanpham,
    999000 as tamtinh,
    '' as coupon,
    0 as giam,
    NULL as voucher_tmdt,
    30000 as phi_ship,
    1029000 as tongtien,
    '' as kho,
    5 as status,
    'COD' as thanhtoan,
    '' as ghi_chu,
    '' as utm_source,
    '' as utm_campaign,
    UNIX_TIMESTAMP() as date_update,
    UNIX_TIMESTAMP() - FLOOR(RAND() * 2592000) as date_post,
    '23933' as shop_id,
    'ninja' as shipping_provider,
    NULL as ninja_response,
    0 as ship_support,
    'socdo' as sales_channel
FROM (
    SELECT user_id, name, email, mobile, dia_chi, tinh, huyen, xa 
    FROM user_info 
    WHERE user_id BETWEEN 1 AND 500 
    ORDER BY RAND() 
    LIMIT 100
) u;

-- Sản phẩm 4: SKG G7 PRO-FOLD (product_id: 3913, variant_id: NULL, shop_id: 23933, gia_moi: 4190000)
INSERT INTO `donhang` (
    `ma_don`, `minh_hoa`, `minh_hoa2`, `user_id`, `ho_ten`, `email`, `dien_thoai`, 
    `dia_chi`, `tinh`, `huyen`, `xa`, `dropship`, `sanpham`, `tamtinh`, `coupon`, 
    `giam`, `voucher_tmdt`, `phi_ship`, `tongtien`, `kho`, `status`, `thanhtoan`, 
    `ghi_chu`, `utm_source`, `utm_campaign`, `date_update`, `date_post`, `shop_id`, 
    `shipping_provider`, `ninja_response`, `ship_support`, `sales_channel`
)
SELECT 
    CONCAT('DH', UNIX_TIMESTAMP(), '_', u.user_id, '_', FLOOR(RAND() * 10000)) as ma_don,
    '' as minh_hoa,
    '' as minh_hoa2,
    u.user_id,
    COALESCE(u.name, CONCAT('Khách hàng ', u.user_id)) as ho_ten,
    COALESCE(u.email, CONCAT('user', u.user_id, '@example.com')) as email,
    COALESCE(u.mobile, CONCAT('0900000', LPAD(u.user_id, 3, '0'))) as dien_thoai,
    COALESCE(u.dia_chi, '123 Đường ABC, Phường XYZ') as dia_chi,
    COALESCE(u.tinh, 1) as tinh,
    COALESCE(u.huyen, 1) as huyen,
    COALESCE(u.xa, 1) as xa,
    0 as dropship,
    CONCAT('{"', 3913, '_0":{"id":3913,"pl":0,"quantity":1,"tieu_de":"Máy Massage KATA SKG G7 PRO-FOLD chính hãng, gập gọn, có nhiệt, thư giãn, giảm đau","anh_chinh":"/uploads/minh-hoa/may-massage-skg-g7-pro-fold-chinh-hang-takatech-gap-gon-co-nhiet-thu-gian-giam-dau-1753935859.png","gia_moi":4190000,"gia_cu":5489000,"ten_color":"Màu xanh đậm","ten_size":"179x221x96mm"}}') as sanpham,
    4190000 as tamtinh,
    '' as coupon,
    0 as giam,
    NULL as voucher_tmdt,
    50000 as phi_ship,
    4240000 as tongtien,
    '' as kho,
    5 as status,
    'COD' as thanhtoan,
    '' as ghi_chu,
    '' as utm_source,
    '' as utm_campaign,
    UNIX_TIMESTAMP() as date_update,
    UNIX_TIMESTAMP() - FLOOR(RAND() * 2592000) as date_post,
    '23933' as shop_id,
    'ninja' as shipping_provider,
    NULL as ninja_response,
    0 as ship_support,
    'socdo' as sales_channel
FROM (
    SELECT user_id, name, email, mobile, dia_chi, tinh, huyen, xa 
    FROM user_info 
    WHERE user_id BETWEEN 1 AND 500 
    ORDER BY RAND() 
    LIMIT 100
) u;

-- Sản phẩm 5: SKG G7 Pro-E (product_id: 3914, variant_id: NULL, shop_id: 23933, gia_moi: 3590000)
INSERT INTO `donhang` (
    `ma_don`, `minh_hoa`, `minh_hoa2`, `user_id`, `ho_ten`, `email`, `dien_thoai`, 
    `dia_chi`, `tinh`, `huyen`, `xa`, `dropship`, `sanpham`, `tamtinh`, `coupon`, 
    `giam`, `voucher_tmdt`, `phi_ship`, `tongtien`, `kho`, `status`, `thanhtoan`, 
    `ghi_chu`, `utm_source`, `utm_campaign`, `date_update`, `date_post`, `shop_id`, 
    `shipping_provider`, `ninja_response`, `ship_support`, `sales_channel`
)
SELECT 
    CONCAT('DH', UNIX_TIMESTAMP(), '_', u.user_id, '_', FLOOR(RAND() * 10000)) as ma_don,
    '' as minh_hoa,
    '' as minh_hoa2,
    u.user_id,
    COALESCE(u.name, CONCAT('Khách hàng ', u.user_id)) as ho_ten,
    COALESCE(u.email, CONCAT('user', u.user_id, '@example.com')) as email,
    COALESCE(u.mobile, CONCAT('0900000', LPAD(u.user_id, 3, '0'))) as dien_thoai,
    COALESCE(u.dia_chi, '123 Đường ABC, Phường XYZ') as dia_chi,
    COALESCE(u.tinh, 1) as tinh,
    COALESCE(u.huyen, 1) as huyen,
    COALESCE(u.xa, 1) as xa,
    0 as dropship,
    CONCAT('{"', 3914, '_0":{"id":3914,"pl":0,"quantity":1,"tieu_de":"Máy massage cổ KATA SKG G7 Pro-E 9 đầu Shiatsu, xung TENS+EMS, ánh sáng đỏ 630nm, chườm nóng Nano","anh_chinh":"/uploads/minh-hoa/may-massage-co-skg-g7-pro-e-1753935643.png","gia_moi":3590000,"gia_cu":3949000,"ten_color":"Màu xám bạc","ten_size":"1 x 1 x 1"}}') as sanpham,
    3590000 as tamtinh,
    '' as coupon,
    0 as giam,
    NULL as voucher_tmdt,
    50000 as phi_ship,
    3640000 as tongtien,
    '' as kho,
    5 as status,
    'COD' as thanhtoan,
    '' as ghi_chu,
    '' as utm_source,
    '' as utm_campaign,
    UNIX_TIMESTAMP() as date_update,
    UNIX_TIMESTAMP() - FLOOR(RAND() * 2592000) as date_post,
    '23933' as shop_id,
    'ninja' as shipping_provider,
    NULL as ninja_response,
    0 as ship_support,
    'socdo' as sales_channel
FROM (
    SELECT user_id, name, email, mobile, dia_chi, tinh, huyen, xa 
    FROM user_info 
    WHERE user_id BETWEEN 1 AND 500 
    ORDER BY RAND() 
    LIMIT 100
) u;

