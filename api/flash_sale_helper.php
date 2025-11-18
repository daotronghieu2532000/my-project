<?php
/**
 * Helper functions for flash sale
 * Reusable functions to check if product is in flash sale and get flash sale price
 */

/**
 * Check if product is in flash sale and get flash sale price
 * 
 * @param mysqli $conn Database connection
 * @param int $product_id Product ID
 * @param int $gia_moi Original price
 * @param int $gia_cu Original old price
 * @return array Array with flash sale info
 */
function getFlashSaleInfo($conn, $product_id, $gia_moi, $gia_cu) {
    $current_time = time();
    
    // Check if product is in flash sale
    $flash_sale_info = array(
        'is_flash_sale' => false,
        'flash_price' => $gia_moi,
        'flash_old_price' => $gia_cu,
        'time_remaining' => 0,
        'time_remaining_formatted' => '00:00:00',
        'deal_id' => 0,
    );
    
    // Check status IN (1,2) - status 1: web con, status 2: Đăng sàn
    $check_flash_sale = mysqli_query($conn, "SELECT * FROM deal WHERE loai = 'flash_sale' AND status IN (1, 2) AND '$current_time' BETWEEN date_start AND date_end LIMIT 50");
    
    if ($check_flash_sale && mysqli_num_rows($check_flash_sale) > 0) {
        // Loop through all active flash sales to find if this product is included
        while ($flash_deal = mysqli_fetch_assoc($check_flash_sale)) {
            $is_in_flash_sale = false;
            
            // Check main_product
            if (!empty($flash_deal['main_product'])) {
                $main_product_ids = explode(',', $flash_deal['main_product']);
                $main_product_ids_int = array_map('intval', $main_product_ids);
                if (in_array(intval($product_id), $main_product_ids_int)) {
                    $is_in_flash_sale = true;
                }
            }
            
            // Check sub_product (JSON) - product_id can be string or int in JSON
            if (!$is_in_flash_sale && !empty($flash_deal['sub_product'])) {
                $sub_json = json_decode($flash_deal['sub_product'], true);
                if (json_last_error() === JSON_ERROR_NONE && is_array($sub_json)) {
                    // Check both string and int keys - try all possible formats
                    $product_id_str = (string)$product_id;
                    $product_id_int = intval($product_id);
                    if (isset($sub_json[$product_id_str]) || isset($sub_json[$product_id_int])) {
                        $is_in_flash_sale = true;
                    }
                }
            }
            
            if ($is_in_flash_sale) {
                // Parse sub_product JSON để tìm giá flash sale cho sản phẩm này
                $flash_price = null;
                $flash_old_price = null;
                
                if (!empty($flash_deal['sub_product'])) {
                    $sub_json = json_decode($flash_deal['sub_product'], true);
                    if (json_last_error() === JSON_ERROR_NONE && is_array($sub_json)) {
                        // Check both string and int keys - try all possible formats
                        $product_id_str = (string)$product_id;
                        $product_id_int = intval($product_id);
                        
                        $product_variants = null;
                        if (isset($sub_json[$product_id_str])) {
                            $product_variants = $sub_json[$product_id_str];
                        } elseif (isset($sub_json[$product_id_int])) {
                            $product_variants = $sub_json[$product_id_int];
                        }
                        
                        // Lấy giá đầu tiên
                        if (!empty($product_variants) && is_array($product_variants)) {
                            $first_variant = reset($product_variants);
                            $flash_price = isset($first_variant['gia']) ? intval($first_variant['gia']) : null;
                            $flash_old_price = isset($first_variant['gia_cu']) ? intval($first_variant['gia_cu']) : null;
                        }
                    }
                }
                
                // Nếu không tìm thấy trong sub_product, check main_product
                if ($flash_price === null) {
                    // Sử dụng giá hiện tại của sản phẩm
                    $flash_price = $gia_moi;
                    $flash_old_price = $gia_cu;
                }
                
                // Tính thời gian còn lại
                $time_remaining = $flash_deal['date_end'] - $current_time;
                
                $flash_sale_info = array(
                    'is_flash_sale' => true,
                    'deal_id' => $flash_deal['id'],
                    'flash_price' => $flash_price,
                    'flash_old_price' => $flash_old_price,
                    'time_remaining' => $time_remaining,
                    'time_remaining_formatted' => gmdate('H:i:s', $time_remaining),
                    'date_start' => $flash_deal['date_start'],
                    'date_end' => $flash_deal['date_end'],
                );
                
                break; // Found matching flash sale, exit loop
            }
        }
    }
    
    return $flash_sale_info;
}

