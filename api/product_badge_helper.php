<?php
/**
 * Product Badge Helper
 * Xử lý logic voucher và freeship badges cho sản phẩm
 */

/**
 * Kiểm tra voucher cho sản phẩm
 * @param int $product_id ID sản phẩm
 * @param int $shop_id ID shop
 * @param mysqli $conn Database connection
 * @return array Thông tin voucher
 */
function checkProductVoucher($product_id, $shop_id, $conn) {
    $current_time = time();
    
    // Check voucher cho sản phẩm cụ thể
    $check_coupon = mysqli_query($conn, "SELECT id, ma, giam, giam_toi_da, loai, kieu, dieu_kien, min_price, max_price FROM coupon WHERE FIND_IN_SET('$product_id', sanpham) AND shop = '$shop_id' AND '$current_time' BETWEEN start AND expired AND status = 1 LIMIT 1");
    
    if (mysqli_num_rows($check_coupon) > 0) {
        $coupon = mysqli_fetch_assoc($check_coupon);
        return [
            'has_voucher' => true,
            'voucher_type' => 'product',
            'voucher_code' => $coupon['ma'],
            'voucher_discount' => $coupon['giam'],
            'voucher_max_discount' => $coupon['giam_toi_da'],
            'voucher_type_text' => $coupon['loai'],
            'voucher_min_price' => $coupon['min_price'],
            'voucher_max_price' => $coupon['max_price']
        ];
    }
    
    // Check voucher cho tất cả sản phẩm của shop
    $check_coupon_all = mysqli_query($conn, "SELECT id, ma, giam, giam_toi_da, loai, kieu, dieu_kien, min_price, max_price FROM coupon WHERE shop = '$shop_id' AND kieu = 'all' AND '$current_time' BETWEEN start AND expired AND status = 1 LIMIT 1");
    
    if (mysqli_num_rows($check_coupon_all) > 0) {
        $coupon = mysqli_fetch_assoc($check_coupon_all);
        return [
            'has_voucher' => true,
            'voucher_type' => 'shop',
            'voucher_code' => $coupon['ma'],
            'voucher_discount' => $coupon['giam'],
            'voucher_max_discount' => $coupon['giam_toi_da'],
            'voucher_type_text' => $coupon['loai'],
            'voucher_min_price' => $coupon['min_price'],
            'voucher_max_price' => $coupon['max_price']
        ];
    }
    
    return [
        'has_voucher' => false,
        'voucher_type' => null,
        'voucher_code' => null,
        'voucher_discount' => 0,
        'voucher_max_discount' => 0,
        'voucher_type_text' => null,
        'voucher_min_price' => 0,
        'voucher_max_price' => 0
    ];
}

/**
 * Kiểm tra freeship cho sản phẩm
 * @param int $product_id ID sản phẩm
 * @param int $shop_id ID shop
 * @param mysqli $conn Database connection
 * @return array Thông tin freeship
 */
function checkProductFreeship($product_id, $shop_id, $conn) {
    // Lấy thông tin transport của shop
    $transport_query = "SELECT free_ship_all, free_ship_min_order, free_ship_discount, fee_ship_products FROM transport WHERE user_id = '$shop_id' LIMIT 1";
    $transport_result = mysqli_query($conn, $transport_query);
    
    if (!$transport_result || mysqli_num_rows($transport_result) == 0) {
        return [
            'has_freeship' => false,
            'freeship_type' => null,
            'freeship_label' => null,
            'freeship_min_order' => 0,
            'freeship_discount' => 0
        ];
    }
    
    $transport = mysqli_fetch_assoc($transport_result);
    $mode = intval($transport['free_ship_all'] ?? 0);
    
    // Logic freeship chi tiết với 4 modes
    switch ($mode) {
        case 1:
            return [
                'has_freeship' => true,
                'freeship_type' => 'full',
                'freeship_label' => 'Freeship 100%',
                'freeship_min_order' => intval($transport['free_ship_min_order']),
                'freeship_discount' => 100
            ];
            
        case 2:
            return [
                'has_freeship' => true,
                'freeship_type' => 'partial',
                'freeship_label' => 'Freeship một phần',
                'freeship_min_order' => intval($transport['free_ship_min_order']),
                'freeship_discount' => intval($transport['free_ship_discount'])
            ];
            
        case 3:
            return [
                'has_freeship' => true,
                'freeship_type' => 'conditional',
                'freeship_label' => 'Freeship có điều kiện',
                'freeship_min_order' => intval($transport['free_ship_min_order']),
                'freeship_discount' => intval($transport['free_ship_discount'])
            ];
            
        case 4:
            return [
                'has_freeship' => true,
                'freeship_type' => 'special',
                'freeship_label' => 'Freeship đặc biệt',
                'freeship_min_order' => intval($transport['free_ship_min_order']),
                'freeship_discount' => intval($transport['free_ship_discount'])
            ];
            
        default:
            return [
                'has_freeship' => false,
                'freeship_type' => null,
                'freeship_label' => null,
                'freeship_min_order' => 0,
                'freeship_discount' => 0
            ];
    }
}

/**
 * Lấy thông tin location của sản phẩm
 * @param int $product_id ID sản phẩm
 * @param mysqli $conn Database connection
 * @return array Thông tin location
 */
function getProductLocation($product_id, $conn) {
    $location_query = "SELECT t.ten_kho, t.province, t.district, t.ward, tm.tieu_de as province_name 
                       FROM sanpham s 
                       LEFT JOIN transport t ON s.kho_id = t.id 
                       LEFT JOIN tinh_moi tm ON t.province = tm.id 
                       WHERE s.id = '$product_id' LIMIT 1";
    
    $location_result = mysqli_query($conn, $location_query);
    
    if (!$location_result || mysqli_num_rows($location_result) == 0) {
        return [
            'warehouse_name' => null,
            'province' => null,
            'district' => null,
            'ward' => null,
            'province_name' => null,
            'location_text' => null
        ];
    }
    
    $location = mysqli_fetch_assoc($location_result);
    
    // Tạo text location
    $location_parts = [];
    if (!empty($location['ward'])) $location_parts[] = $location['ward'];
    if (!empty($location['district'])) $location_parts[] = $location['district'];
    if (!empty($location['province_name'])) $location_parts[] = $location['province_name'];
    
    $location_text = !empty($location_parts) ? implode(', ', $location_parts) : null;
    
    return [
        'warehouse_name' => $location['ten_kho'],
        'province' => $location['province'],
        'district' => $location['district'],
        'ward' => $location['ward'],
        'province_name' => $location['province_name'],
        'location_text' => $location_text
    ];
}

/**
 * Thêm badges và location vào sản phẩm
 * @param array $product Dữ liệu sản phẩm
 * @param mysqli $conn Database connection
 * @return array Sản phẩm với badges và location
 */
function addProductBadgesAndLocation($product, $conn) {
    $product_id = $product['id'];
    $shop_id = $product['shop'];
    
    // Thêm voucher info
    $voucher_info = checkProductVoucher($product_id, $shop_id, $conn);
    $product = array_merge($product, $voucher_info);
    
    // Thêm freeship info
    $freeship_info = checkProductFreeship($product_id, $shop_id, $conn);
    $product = array_merge($product, $freeship_info);
    
    // Thêm location info
    $location_info = getProductLocation($product_id, $conn);
    $product = array_merge($product, $location_info);
    
    return $product;
}

/**
 * Thêm badges và location cho danh sách sản phẩm
 * @param array $products Danh sách sản phẩm
 * @param mysqli $conn Database connection
 * @return array Danh sách sản phẩm với badges và location
 */
function addProductBadgesAndLocationToList($products, $conn) {
    foreach ($products as &$product) {
        $product = addProductBadgesAndLocation($product, $conn);
    }
    return $products;
}
?>
