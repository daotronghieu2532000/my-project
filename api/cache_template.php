<?php
/**
 * Template Cache cho API
 * 
 * Cách sử dụng:
 * 1. Copy đoạn code này vào đầu file API
 * 2. Thay đổi các tham số cache theo từng API
 * 3. Wrap logic query database trong if ($cached_data === false)
 * 4. Lưu kết quả vào cache với thời gian phù hợp
 */

// Khởi tạo Memcached
$memcached = new Memcached();
$memcached->addServer('127.0.0.1', 11211);

// Tạo cache key duy nhất dựa trên parameters
$cache_key = 'api_name_' . md5(serialize($_GET)) . '_' . date('YmdH');

// Kiểm tra cache
$cached_data = $memcached->get($cache_key);

if ($cached_data === false) {
    // Cache miss - Query database
    // ... Logic query database ở đây ...
    
    // Lưu vào cache với thời gian phù hợp
    $memcached->set($cache_key, $response_data, 300); // 5 phút
    
} else {
    // Cache hit - Dùng data từ cache
    $response_data = $cached_data;
}

// Trả về response
echo json_encode($response_data, JSON_UNESCAPED_UNICODE);

/**
 * Các thời gian cache phù hợp:
 * 
 * 60 giây (60): Dữ liệu real-time, thay đổi liên tục
 * 5 phút (300): Dữ liệu thường xuyên thay đổi (banners, flash sale)
 * 10 phút (600): Dữ liệu ít thay đổi (gợi ý sản phẩm)
 * 30 phút (1800): Dữ liệu tương đối ổn định (danh mục con)
 * 1 giờ (3600): Dữ liệu ít thay đổi (danh mục cha, thông tin cơ bản)
 * 6 giờ (21600): Dữ liệu rất ổn định (cấu hình hệ thống)
 * 24 giờ (86400): Dữ liệu tĩnh (thông tin liên hệ, chính sách)
 */

/**
 * Cache Key Strategy:
 * 
 * Format: {api_name}_{hash_params}_{time_period}
 * 
 * Ví dụ:
 * - banners_mobile_123abc_2025011514 (banners mobile, hash params, 14h ngày 15/01/2025)
 * - products_category_456def_2025011514 (products theo category, hash params, 14h)
 * - search_keyword_789ghi_2025011514 (search theo keyword, hash params, 14h)
 * 
 * Time periods:
 * - YmdH: Cache theo giờ (1h)
 * - Ymd: Cache theo ngày (24h)
 * - Ym: Cache theo tháng (30 ngày)
 */

/**
 * Cache Invalidation Strategy:
 * 
 * 1. Time-based: Cache tự động hết hạn
 * 2. Manual: Xóa cache khi có thay đổi dữ liệu
 * 3. Pattern-based: Xóa nhiều cache cùng lúc
 * 
 * Ví dụ xóa cache:
 * $memcached->delete('banners_mobile_123abc_2025011514');
 * $memcached->delete('products_category_456def_2025011514');
 * 
 * Hoặc xóa theo pattern:
 * $keys = $memcached->getAllKeys();
 * foreach ($keys as $key) {
 *     if (strpos($key, 'banners_') === 0) {
 *         $memcached->delete($key);
 *     }
 * }
 */
?>
