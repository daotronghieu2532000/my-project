<?php
/**
 * Script áp dụng cache cho tất cả các file API
 * 
 * Chạy script này để tự động thêm cache vào tất cả các file API
 */

// Danh sách các file API cần áp dụng cache
$api_files = [
    'affiliate_orders.php',
    'affiliate_products.php', 
    'favorite_products.php',
    'orders_list.php',
    'user_profile.php',
    'product_detail.php',
    'app_flash_sale.php',
    'menu_articles.php',
    'related_products.php',
    'shipping_quote.php',
    'products_freeship.php',
    'affiliate_withdrawal_history.php',
    'affiliate_simple.php',
    'notifications_list.php',
    'order_management.php',
    'products_by_category.php',
    'products_same_shop.php',
    'affiliate_commission_history.php',
    'affiliate_my_links.php',
    'order_detail.php',
    'affiliate_follow_product.php',
    'affiliate_create_link.php',
    'affiliate_balance_info.php',
    'affiliate_banks_list.php',
    'affiliate_bank_accounts.php',
    'affiliate_dashboard.php',
    'affiliate_claim_commission.php',
    'affiliate_withdraw.php',
    'voucher_list.php',
    'create_order.php',
    'order_cancel_request.php',
    'notification_mark_read.php',
    'locations.php',
    'add_favorite.php',
    'change_password.php',
    'get_otp.php',
    'forgot_password.php',
    'wishlist.php',
    'address_book.php',
    'order_status.php',
    'register.php',
    'get_token.php',
    'login.php',
    'signup.php',
    'user_info.php'
];

// Template cache để thêm vào đầu file
$cache_template = '
// Khởi tạo Memcached
$memcached = new Memcached();
$memcached->addServer(\'127.0.0.1\', 11211);
';

// Template cache để thêm vào logic
$cache_logic_template = '
    // Tạo cache key duy nhất
    $cache_key = \'{api_name}_\' . md5(serialize($_GET)) . \'_\' . date(\'YmdH\');
    
    // Kiểm tra cache
    $cached_data = $memcached->get($cache_key);
    
    if ($cached_data === false) {
        // Cache miss - Query database
';

$cache_end_template = '
        // Lưu vào cache với thời gian phù hợp
        $memcached->set($cache_key, $response_data, 300); // 5 phút
        
    } else {
        // Cache hit - Dùng data từ cache
        $response_data = $cached_data;
    }
';

// Hàm thêm cache vào file
function addCacheToFile($filename) {
    global $cache_template, $cache_logic_template, $cache_end_template;
    
    $filepath = __DIR__ . '/' . $filename;
    
    if (!file_exists($filepath)) {
        echo "File không tồn tại: $filename\n";
        return false;
    }
    
    $content = file_get_contents($filepath);
    
    // Kiểm tra xem đã có cache chưa
    if (strpos($content, 'Memcached') !== false) {
        echo "File $filename đã có cache\n";
        return true;
    }
    
    // Thêm cache template vào đầu file (sau require_once)
    $pattern = '/(require_once [\'"]\.\/includes\/config\.php[\'"];)/';
    $replacement = '$1' . $cache_template;
    $content = preg_replace($pattern, $replacement, $content);
    
    // Thêm cache logic vào method GET
    $pattern = '/(if \(\$method === [\'"]GET[\'"]\) \{[^}]*)/';
    $replacement = '$1' . $cache_logic_template;
    $content = preg_replace($pattern, $replacement, $content);
    
    // Thêm cache end trước response
    $pattern = '/(\$response = \[[^]]*\];)/';
    $replacement = $cache_end_template . '$1';
    $content = preg_replace($pattern, $replacement, $content);
    
    // Lưu file
    if (file_put_contents($filepath, $content)) {
        echo "Đã thêm cache vào file: $filename\n";
        return true;
    } else {
        echo "Lỗi khi thêm cache vào file: $filename\n";
        return false;
    }
}

// Chạy script
echo "Bắt đầu áp dụng cache cho các file API...\n\n";

$success_count = 0;
$total_count = count($api_files);

foreach ($api_files as $file) {
    if (addCacheToFile($file)) {
        $success_count++;
    }
}

echo "\nHoàn thành! Đã áp dụng cache cho $success_count/$total_count file.\n";
echo "Các file đã được cache:\n";
echo "- banners.php (5 phút)\n";
echo "- product_suggest.php (10 phút)\n";
echo "- search_products.php (5 phút)\n";
echo "- flash_sale.php (5 phút)\n";
echo "- categories_list.php (1 giờ)\n";
echo "- Và $success_count file khác (5 phút)\n";

echo "\nLưu ý:\n";
echo "1. Đảm bảo Memcached đang chạy trên port 11211\n";
echo "2. Kiểm tra lại các file đã được cache\n";
echo "3. Test API để đảm bảo cache hoạt động đúng\n";
echo "4. Có thể điều chỉnh thời gian cache theo nhu cầu\n";
?>
