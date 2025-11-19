<?php
/**
 * Template chuẩn cho logic badges sản phẩm
 * Bao gồm: Voucher, Freeship 4 mode, Warehouse info
 * Sử dụng cho tất cả API sản phẩm
 */

/**
 * Kiểm tra voucher cho sản phẩm
 * @param mysqli $conn Database connection
 * @param int $product_id ID sản phẩm
 * @param int $shop_id ID shop
 * @param int $current_time Thời gian hiện tại
 * @return array Thông tin voucher
 */
function checkProductVoucher($conn, $product_id, $shop_id, $current_time) {
    $voucher_info = [
        'has_voucher' => false,
        'voucher_label' => '',
        'voucher_details' => ''
    ];
    
    // Check voucher cho sản phẩm cụ thể
    $check_coupon = mysqli_query($conn, "SELECT id, ma, loai, giam FROM coupon WHERE FIND_IN_SET('$product_id', sanpham) AND shop = '$shop_id' AND '$current_time' BETWEEN start AND expired LIMIT 1");
    if ($check_coupon && mysqli_num_rows($check_coupon) > 0) {
        $voucher_data = mysqli_fetch_assoc($check_coupon);
        $voucher_info['has_voucher'] = true;
        $voucher_info['voucher_label'] = 'Voucher';
        
        if ($voucher_data['loai'] == 'tru') {
            $voucher_info['voucher_details'] = 'Giảm ' . number_format($voucher_data['giam']) . 'đ';
        } else {
            $voucher_info['voucher_details'] = 'Giảm ' . $voucher_data['giam'] . '%';
        }
    } else {
        // Check voucher cho toàn shop
        $check_coupon_all = mysqli_query($conn, "SELECT id, ma, loai, giam FROM coupon WHERE shop = '$shop_id' AND kieu = 'all' AND '$current_time' BETWEEN start AND expired LIMIT 1");
        if ($check_coupon_all && mysqli_num_rows($check_coupon_all) > 0) {
            $voucher_data = mysqli_fetch_assoc($check_coupon_all);
            $voucher_info['has_voucher'] = true;
            $voucher_info['voucher_label'] = 'Voucher';
            
            if ($voucher_data['loai'] == 'tru') {
                $voucher_info['voucher_details'] = 'Giảm ' . number_format($voucher_data['giam']) . 'đ';
            } else {
                $voucher_info['voucher_details'] = 'Giảm ' . $voucher_data['giam'] . '%';
            }
        }
    }
    
    return $voucher_info;
}

/**
 * Kiểm tra freeship với 4 mode
 * @param mysqli $conn Database connection
 * @param int $shop_id ID shop
 * @param int $product_id ID sản phẩm (cho mode 3)
 * @return array Thông tin freeship
 */
function checkProductFreeship($conn, $shop_id, $product_id = 0) {
    $freeship_info = [
        'has_freeship' => false,
        'freeship_label' => '',
        'freeship_details' => '',
        'freeship_mode' => 0,
        'freeship_color' => '#4CAF50'
    ];
    
    $freeship_query = "SELECT free_ship_all, free_ship_discount, free_ship_min_order, fee_ship_products FROM transport WHERE user_id = '$shop_id' AND (free_ship_all > 0 OR free_ship_discount > 0) LIMIT 1";
    $freeship_result = mysqli_query($conn, $freeship_query);
    
    if ($freeship_result && mysqli_num_rows($freeship_result) > 0) {
        $freeship_data = mysqli_fetch_assoc($freeship_result);
        $mode = intval($freeship_data['free_ship_all'] ?? 0);
        $discount = intval($freeship_data['free_ship_discount'] ?? 0);
        $minOrder = intval($freeship_data['free_ship_min_order'] ?? 0);
        
        $freeship_info['has_freeship'] = true;
        $freeship_info['freeship_mode'] = $mode;
        
        // Mode 0: Giảm cố định (VD: -15,000đ)
        if ($mode === 0 && $discount > 0) {
            $freeship_info['freeship_label'] = 'Giảm ' . number_format($discount) . 'đ';
            $freeship_info['freeship_color'] = '#2196F3'; // Blue
            $freeship_info['freeship_details'] = $minOrder > 0 ? 
                'Giảm ' . number_format($discount) . 'đ phí ship cho đơn từ ' . number_format($minOrder) . 'đ' :
                'Giảm ' . number_format($discount) . 'đ phí ship';
        }
        // Mode 1: Freeship toàn bộ (100%)
        elseif ($mode === 1) {
            $freeship_info['freeship_label'] = 'Freeship 100%';
            $freeship_info['freeship_color'] = '#FF5722'; // Red-Orange
            $freeship_info['freeship_details'] = $minOrder > 0 ? 
                'Miễn phí ship 100% cho đơn từ ' . number_format($minOrder) . 'đ' :
                'Miễn phí ship 100% - Không điều kiện';
        }
        // Mode 2: Giảm theo % (VD: -50%)
        elseif ($mode === 2 && $discount > 0) {
            $freeship_info['freeship_label'] = 'Giảm ' . intval($discount) . '% ship';
            $freeship_info['freeship_color'] = '#9C27B0'; // Purple
            $freeship_info['freeship_details'] = $minOrder > 0 ? 
                'Giảm ' . intval($discount) . '% phí ship cho đơn từ ' . number_format($minOrder) . 'đ' :
                'Giảm ' . intval($discount) . '% phí ship';
        }
        // Mode 3: Freeship theo sản phẩm cụ thể
        elseif ($mode === 3 && $product_id > 0) {
            $freeship_info['freeship_color'] = '#FF9800'; // Orange
            
            // Parse fee_ship_products để xem sản phẩm này có trong danh sách không
            $feeShipProducts = json_decode($freeship_data['fee_ship_products'] ?? '[]', true);
            $hasSupport = false;
            
            if (is_array($feeShipProducts)) {
                foreach ($feeShipProducts as $cfg) {
                    if (intval($cfg['sp_id'] ?? 0) === $product_id) {
                        $hasSupport = true;
                        $stype = $cfg['ship_type'] ?? 'vnd';
                        $val = floatval($cfg['ship_support'] ?? 0);
                        if ($stype === 'percent') {
                            $freeship_info['freeship_label'] = 'Giảm ' . intval($val) . '% ship';
                            $freeship_info['freeship_details'] = 'Giảm ' . intval($val) . '% phí ship';
                        } else {
                            $freeship_info['freeship_label'] = 'Giảm ' . number_format($val) . 'đ';
                            $freeship_info['freeship_details'] = 'Giảm ' . number_format($val) . 'đ phí ship';
                        }
                        break;
                    }
                }
            }
            
            if (!$hasSupport) {
                $freeship_info['freeship_label'] = 'Ưu đãi ship';
                $freeship_info['freeship_details'] = 'Ưu đãi phí ship cho sản phẩm này';
            }
        }
    }
    
    return $freeship_info;
}

/**
 * Lấy thông tin warehouse
 * @param mysqli $conn Database connection
 * @param int $product_id ID sản phẩm
 * @return array Thông tin warehouse
 */
function getProductWarehouse($conn, $product_id) {
    $warehouse_info = [
        'warehouse_name' => '',
        'province_name' => '',
        'location' => ''
    ];
    
    $warehouse_query = "SELECT t.ten_kho AS warehouse_name, tm.tieu_de AS province_name 
                       FROM sanpham s 
                       LEFT JOIN transport t ON s.kho_id = t.id 
                       LEFT JOIN tinh_moi tm ON t.province = tm.id 
                       WHERE s.id = $product_id LIMIT 1";
    $warehouse_result = mysqli_query($conn, $warehouse_query);
    
    if ($warehouse_result && mysqli_num_rows($warehouse_result) > 0) {
        $warehouse_data = mysqli_fetch_assoc($warehouse_result);
        $warehouse_info['warehouse_name'] = $warehouse_data['warehouse_name'] ?? '';
        $warehouse_info['province_name'] = $warehouse_data['province_name'] ?? '';
        
        // Tạo location string
        $location_parts = [];
        if (!empty($warehouse_info['warehouse_name'])) {
            $location_parts[] = $warehouse_info['warehouse_name'];
        }
        if (!empty($warehouse_info['province_name'])) {
            $location_parts[] = $warehouse_info['province_name'];
        }
        $warehouse_info['location'] = implode(', ', $location_parts);
    }
    
    return $warehouse_info;
}

/**
 * Tạo badges cho sản phẩm
 * @param array $product_data Dữ liệu sản phẩm
 * @param array $voucher_info Thông tin voucher
 * @param array $freeship_info Thông tin freeship
 * @return array Danh sách badges
 */
function createProductBadges($product_data, $voucher_info, $freeship_info) {
    $badges = [];
    
    // Discount badge
    if (isset($product_data['discount_percent']) && $product_data['discount_percent'] > 0) {
        $badges[] = [
            'text' => 'Giảm ' . $product_data['discount_percent'] . '%',
            'type' => 'discount',
            'color' => '#E53E3E'
        ];
    }
    
    // Flash sale badge
    if (isset($product_data['box_flash']) && $product_data['box_flash'] == 1) {
        $badges[] = [
            'text' => 'Flash Sale',
            'type' => 'flash_sale',
            'color' => '#FF6B35'
        ];
    }
    
    // Bestseller badge
    if (isset($product_data['box_banchay']) && $product_data['box_banchay'] == 1) {
        $badges[] = [
            'text' => 'Bán chạy',
            'type' => 'bestseller',
            'color' => '#38A169'
        ];
    }
    
    // Featured badge
    if (isset($product_data['box_noibat']) && $product_data['box_noibat'] == 1) {
        $badges[] = [
            'text' => 'Nổi bật',
            'type' => 'featured',
            'color' => '#805AD5'
        ];
    }
    
    // Voucher badge
    if ($voucher_info['has_voucher']) {
        $badges[] = [
            'text' => $voucher_info['voucher_label'],
            'type' => 'voucher',
            'color' => '#3182CE',
            'details' => $voucher_info['voucher_details']
        ];
    }
    
    // Freeship badge
    if ($freeship_info['has_freeship']) {
        $badges[] = [
            'text' => $freeship_info['freeship_label'],
            'type' => 'freeship',
            'color' => $freeship_info['freeship_color'],
            'details' => $freeship_info['freeship_details']
        ];
    }
    
    // Chính hãng badge (mặc định)
    $badges[] = [
        'text' => 'Chính hãng',
        'type' => 'authentic',
        'color' => '#2D3748'
    ];
    
    return $badges;
}

/**
 * Áp dụng template chuẩn cho sản phẩm
 * @param mysqli $conn Database connection
 * @param array $product_data Dữ liệu sản phẩm gốc
 * @return array Dữ liệu sản phẩm đã được xử lý
 */
function applyProductTemplate($conn, $product_data) {
    $current_time = time();
    $product_id = $product_data['id'];
    $shop_id = $product_data['shop'] ?? 1;
    
    // Kiểm tra voucher
    $voucher_info = checkProductVoucher($conn, $product_id, $shop_id, $current_time);
    
    // Kiểm tra freeship
    $freeship_info = checkProductFreeship($conn, $shop_id, $product_id);
    
    // Lấy thông tin warehouse
    $warehouse_info = getProductWarehouse($conn, $product_id);
    
    // Tạo badges
    $badges = createProductBadges($product_data, $voucher_info, $freeship_info);
    
    // Cập nhật dữ liệu sản phẩm
    $product_data['voucher_info'] = $voucher_info;
    $product_data['freeship_info'] = $freeship_info;
    $product_data['warehouse_info'] = $warehouse_info;
    $product_data['badges'] = $badges;
    $product_data['hasVoucher'] = $voucher_info['has_voucher'];
    $product_data['isFreeship'] = $freeship_info['has_freeship'];
    
    return $product_data;
}
?>
