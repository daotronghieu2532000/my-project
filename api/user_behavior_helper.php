<?php
/**
 * Helper functions để lưu và xử lý hành vi người dùng
 * Phục vụ cho hệ thống gợi ý sản phẩm dựa trên hành vi
 */

/**
 * Lưu hành vi người dùng vào database
 * 
 * @param mysqli $conn Kết nối database
 * @param int $user_id ID người dùng
 * @param string $behavior_type Loại hành vi: search, view, cart, favorite, order
 * @param int|null $product_id ID sản phẩm (null nếu là search)
 * @param string|null $keyword Từ khóa tìm kiếm (chỉ dùng cho search)
 * @param int|null $category_id ID danh mục (nếu có)
 * @param array|null $metadata Thông tin bổ sung dạng array
 * @return bool true nếu thành công, false nếu thất bại
 */
function saveUserBehavior($conn, $user_id, $behavior_type, $product_id = null, $keyword = null, $category_id = null, $metadata = null) {
    error_log("💾 [saveUserBehavior] Attempting to save: user_id=$user_id, behavior_type=$behavior_type, product_id=" . ($product_id ?? 'NULL') . ", keyword=" . ($keyword ?? 'NULL'));
    
    if ($user_id <= 0) {
        error_log("⚠️ [saveUserBehavior] user_id <= 0: $user_id - cannot save");
        return false; // Không lưu nếu user_id không hợp lệ
    }
    
    // Validate behavior_type
    $valid_types = ['search', 'view', 'cart', 'favorite', 'order'];
    if (!in_array($behavior_type, $valid_types)) {
        error_log("❌ [saveUserBehavior] Invalid behavior_type: $behavior_type");
        return false;
    }
    
    // ===== CẢI THIỆN: Filter hành vi bất thường (spam detection) =====
    $current_time = time();
    $one_hour_ago = $current_time - (60 * 60);
    
    // Kiểm tra xem bảng user_behavior có tồn tại không
    $check_table = mysqli_query($conn, "SHOW TABLES LIKE 'user_behavior'");
    if (mysqli_num_rows($check_table) > 0) {
        // Kiểm tra hành vi spam: quá nhiều hành vi trong 1 giờ
        $spam_check_query = "SELECT COUNT(*) as count 
                            FROM user_behavior 
                            WHERE user_id = " . intval($user_id) . " 
                            AND behavior_type = '$behavior_type' 
                            AND created_at >= $one_hour_ago";
        
        $spam_result = mysqli_query($conn, $spam_check_query);
        if ($spam_result) {
            $spam_row = mysqli_fetch_assoc($spam_result);
            $recent_count = intval($spam_row['count']);
            
            // Ngưỡng spam (có thể điều chỉnh)
            $spam_thresholds = [
                'view' => 50,      // > 50 views trong 1 giờ = spam
                'search' => 30,    // > 30 searches trong 1 giờ = spam
                'cart' => 20,      // > 20 carts trong 1 giờ = spam
                'favorite' => 20,  // > 20 favorites trong 1 giờ = spam
                'order' => 10      // > 10 orders trong 1 giờ = spam (hiếm khi xảy ra)
            ];
            
            $threshold = isset($spam_thresholds[$behavior_type]) ? $spam_thresholds[$behavior_type] : 50;
            
            if ($recent_count >= $threshold) {
                error_log("⚠️ [saveUserBehavior] SPAM DETECTED: user_id=$user_id, behavior_type=$behavior_type, count=$recent_count (threshold=$threshold) - Skipping save");
                return false; // Không lưu hành vi spam
            }
        }
    }
    
    // Chuyển đổi metadata thành JSON
    // ===== CẢI THIỆN: Thêm context vào metadata =====
    if ($metadata === null || !is_array($metadata)) {
        $metadata = [];
    }
    
    // Thêm thông tin context (nếu chưa có)
    if (!isset($metadata['time_of_day'])) {
        $metadata['time_of_day'] = date('H'); // 0-23
    }
    if (!isset($metadata['day_of_week'])) {
        $metadata['day_of_week'] = date('w'); // 0-6 (0 = Sunday)
    }
    if (!isset($metadata['timestamp'])) {
        $metadata['timestamp'] = time();
    }
    
    $metadata_json = json_encode($metadata, JSON_UNESCAPED_UNICODE);
    
    // Escape các giá trị
    $user_id = intval($user_id);
    $behavior_type = addslashes($behavior_type);
    $product_id = $product_id !== null ? intval($product_id) : 'NULL';
    $keyword = $keyword !== null ? "'" . mysqli_real_escape_string($conn, $keyword) . "'" : 'NULL';
    $category_id = $category_id !== null ? intval($category_id) : 'NULL';
    $metadata_json = $metadata_json !== null ? "'" . mysqli_real_escape_string($conn, $metadata_json) . "'" : 'NULL';
    $created_at = time();
    
    // Kiểm tra xem bảng user_behavior có tồn tại không
    $check_table = mysqli_query($conn, "SHOW TABLES LIKE 'user_behavior'");
    if (mysqli_num_rows($check_table) == 0) {
        error_log("❌ [saveUserBehavior] Table user_behavior does not exist");
        return false;
    }
    
    // Lưu hành vi
    $query = "INSERT INTO user_behavior (user_id, behavior_type, product_id, keyword, category_id, metadata, created_at) 
              VALUES ($user_id, '$behavior_type', $product_id, $keyword, $category_id, $metadata_json, $created_at)";
    
    error_log("💾 [saveUserBehavior] Executing query: $query");
    
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        error_log("❌ [saveUserBehavior] Query failed: " . mysqli_error($conn));
        return false;
    }
    
    $insert_id = mysqli_insert_id($conn);
    error_log("✅ [saveUserBehavior] Behavior saved successfully: id=$insert_id, user_id=$user_id, behavior_type=$behavior_type");
    
    // ===== CẢI THIỆN: Cache invalidation signal =====
    // Ghi log để Flutter có thể detect và clear cache
    error_log("🔄 [saveUserBehavior] CACHE_INVALIDATION: user_id=$user_id, behavior_type=$behavior_type");
    
    // Xóa dữ liệu cũ hơn 90 ngày để tối ưu database
    $old_timestamp = time() - (90 * 24 * 60 * 60);
    $cleanup_query = "DELETE FROM user_behavior WHERE created_at < $old_timestamp";
    mysqli_query($conn, $cleanup_query);
    
    return true;
}

/**
 * Lấy danh sách sản phẩm gợi ý dựa trên hành vi người dùng
 * 
 * @param mysqli $conn Kết nối database
 * @param int $user_id ID người dùng
 * @param int $limit Số lượng sản phẩm cần lấy
 * @param array $exclude_ids Danh sách ID sản phẩm cần loại trừ
 * @return array Danh sách ID sản phẩm được gợi ý
 */
function getUserBasedProductIds($conn, $user_id, $limit = 50, $exclude_ids = []) {
    if ($user_id <= 0) {
        return [];
    }
    
    // Kiểm tra xem bảng user_behavior có tồn tại không
    $check_table = mysqli_query($conn, "SHOW TABLES LIKE 'user_behavior'");
    if (mysqli_num_rows($check_table) == 0) {
        return [];
    }
    
    $user_id = intval($user_id);
    $limit = intval($limit);
    $exclude_condition = '';
    
    if (!empty($exclude_ids) && is_array($exclude_ids)) {
        $exclude_ids = array_map('intval', $exclude_ids);
        $exclude_ids_str = implode(',', $exclude_ids);
        $exclude_condition = " AND ub.product_id NOT IN ($exclude_ids_str)";
    }
    
    // Lấy hành vi trong 30 ngày gần nhất
    $thirty_days_ago = time() - (30 * 24 * 60 * 60);
    $current_time = time();
    
    // Tính điểm cho từng loại hành vi (theo logic Shopee)
    // Order: 10 điểm (đã mua - quan tâm cao nhất)
    // Cart: 8 điểm (đã thêm giỏ hàng - quan tâm cao)
    // Favorite: 6 điểm (đã yêu thích - quan tâm trung bình-cao)
    // View: 3 điểm (đã xem - quan tâm thấp)
    // Search: 5 điểm (đã tìm kiếm - quan tâm trung bình, vì user chủ động)
    // 
    // Logic Shopee: Search quan trọng hơn View vì user chủ động tìm kiếm
    // Order > Cart > Favorite > Search > View
    
    // ===== CẢI THIỆN: Thêm logic decay theo thời gian =====
    // Hành vi cũ hơn → điểm số thấp hơn
    // Decay factor: 1.0 (hôm nay) → 0.1 (30 ngày trước)
    // Công thức: decay = max(0.1, 1 - (days_ago / 30))
    // created_at đã là Unix timestamp, nên dùng $current_time - created_at
    
    $query = "SELECT 
                ub.product_id,
                SUM(
                    CASE ub.behavior_type
                        WHEN 'order' THEN 10
                        WHEN 'cart' THEN 8
                        WHEN 'favorite' THEN 6
                        WHEN 'view' THEN 3
                        WHEN 'search' THEN 5
                        ELSE 0
                    END
                    * GREATEST(0.1, 1 - (($current_time - ub.created_at) / (30 * 24 * 60 * 60)))
                ) as score,
                COUNT(*) as behavior_count,
                MAX(ub.created_at) as last_behavior_time,
                AVG(($current_time - ub.created_at) / (24 * 60 * 60)) as avg_days_ago
              FROM user_behavior ub
              WHERE ub.user_id = $user_id
              AND ub.created_at >= $thirty_days_ago
              AND ub.product_id IS NOT NULL
              AND ub.behavior_type IN ('order', 'cart', 'favorite', 'view', 'search')
              $exclude_condition
              GROUP BY ub.product_id
              ORDER BY score DESC, behavior_count DESC, last_behavior_time DESC
              LIMIT $limit";
    
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        return [];
    }
    
    $product_ids = [];
    while ($row = mysqli_fetch_assoc($result)) {
        $product_ids[] = intval($row['product_id']);
    }
    
    return $product_ids;
}

/**
 * Lấy danh sách category_id từ lịch sử tìm kiếm và xem sản phẩm
 * CẢI THIỆN: Lấy category từ cả category_id trực tiếp và từ keyword search
 * 
 * @param mysqli $conn Kết nối database
 * @param int $user_id ID người dùng
 * @param int $limit Số lượng category cần lấy
 * @return array Danh sách category_id với frequency
 */
function getUserPreferredCategories($conn, $user_id, $limit = 10) {
    if ($user_id <= 0) {
        return [];
    }
    
    // Kiểm tra xem bảng user_behavior có tồn tại không
    $check_table = mysqli_query($conn, "SHOW TABLES LIKE 'user_behavior'");
    if (mysqli_num_rows($check_table) == 0) {
        return [];
    }
    
    $user_id = intval($user_id);
    $limit = intval($limit);
    
    // Lấy hành vi trong 30 ngày gần nhất
    $thirty_days_ago = time() - (30 * 24 * 60 * 60);
    
    // ===== CẢI THIỆN: Lấy category từ cả category_id và keyword search =====
    // Query 1: Lấy category_id trực tiếp (ưu tiên cao nhất)
    $query1 = "SELECT 
                ub.category_id,
                COUNT(*) * 2 as frequency,  -- Nhân 2 để ưu tiên category_id trực tiếp
                MAX(ub.created_at) as last_activity
              FROM user_behavior ub
              WHERE ub.user_id = $user_id
              AND ub.created_at >= $thirty_days_ago
              AND ub.category_id IS NOT NULL
              GROUP BY ub.category_id";
    
    // Query 2: Lấy category từ keyword search (từ sản phẩm đã search)
    $query2 = "SELECT 
                CAST(SUBSTRING_INDEX(s.cat, ',', 1) AS UNSIGNED) as category_id,
                COUNT(*) as frequency,
                MAX(ub.created_at) as last_activity
              FROM user_behavior ub
              INNER JOIN sanpham s ON s.tieu_de LIKE CONCAT('%', ub.keyword, '%')
              WHERE ub.user_id = $user_id
              AND ub.behavior_type = 'search'
              AND ub.created_at >= $thirty_days_ago
              AND ub.keyword IS NOT NULL
              AND ub.keyword != ''
              AND ub.category_id IS NULL  -- Chỉ lấy khi không có category_id
              AND s.cat IS NOT NULL
              AND s.cat != ''
              AND s.active = 0
              GROUP BY category_id
              HAVING category_id > 0";
    
    // Union và merge kết quả
    $category_frequency = [];
    
    // Execute query 1
    $result1 = mysqli_query($conn, $query1);
    if ($result1) {
        while ($row = mysqli_fetch_assoc($result1)) {
            $cat_id = intval($row['category_id']);
            if ($cat_id > 0) {
                if (!isset($category_frequency[$cat_id])) {
                    $category_frequency[$cat_id] = [
                        'frequency' => 0,
                        'last_activity' => 0
                    ];
                }
                $category_frequency[$cat_id]['frequency'] += intval($row['frequency']);
                $category_frequency[$cat_id]['last_activity'] = max(
                    $category_frequency[$cat_id]['last_activity'],
                    intval($row['last_activity'])
                );
            }
        }
    }
    
    // Execute query 2 (chỉ khi query 1 không đủ kết quả)
    if (count($category_frequency) < $limit) {
        $result2 = mysqli_query($conn, $query2);
        if ($result2) {
            while ($row = mysqli_fetch_assoc($result2)) {
                $cat_id = intval($row['category_id']);
                if ($cat_id > 0) {
                    if (!isset($category_frequency[$cat_id])) {
                        $category_frequency[$cat_id] = [
                            'frequency' => 0,
                            'last_activity' => 0
                        ];
                    }
                    $category_frequency[$cat_id]['frequency'] += intval($row['frequency']);
                    $category_frequency[$cat_id]['last_activity'] = max(
                        $category_frequency[$cat_id]['last_activity'],
                        intval($row['last_activity'])
                    );
                }
            }
        }
    }
    
    // Sắp xếp theo frequency và last_activity
    uasort($category_frequency, function($a, $b) {
        if ($a['frequency'] != $b['frequency']) {
            return $b['frequency'] - $a['frequency']; // DESC
        }
        return $b['last_activity'] - $a['last_activity']; // DESC
    });
    
    // Lấy top $limit
    $category_ids = array_slice(array_keys($category_frequency), 0, $limit);
    
    return $category_ids;
}

/**
 * Lấy từ khóa tìm kiếm phổ biến của người dùng
 * 
 * @param mysqli $conn Kết nối database
 * @param int $user_id ID người dùng
 * @param int $limit Số lượng từ khóa cần lấy
 * @return array Danh sách từ khóa
 */
function getUserSearchKeywords($conn, $user_id, $limit = 10) {
    if ($user_id <= 0) {
        error_log("⚠️ [getUserSearchKeywords] user_id <= 0: $user_id");
        return [];
    }
    
    // Kiểm tra xem bảng user_behavior có tồn tại không
    $check_table = mysqli_query($conn, "SHOW TABLES LIKE 'user_behavior'");
    if (mysqli_num_rows($check_table) == 0) {
        error_log("⚠️ [getUserSearchKeywords] Table user_behavior does not exist");
        return [];
    }
    
    $user_id = intval($user_id);
    $limit = intval($limit);
    
    // Lấy hành vi trong 30 ngày gần nhất
    $thirty_days_ago = time() - (30 * 24 * 60 * 60);
    
    error_log("🔑 [getUserSearchKeywords] Query for user_id=$user_id, limit=$limit, thirty_days_ago=$thirty_days_ago");
    
    $query = "SELECT 
                ub.keyword,
                COUNT(*) as frequency
              FROM user_behavior ub
              WHERE ub.user_id = $user_id
              AND ub.created_at >= $thirty_days_ago
              AND ub.behavior_type = 'search'
              AND ub.keyword IS NOT NULL
              AND ub.keyword != ''
              GROUP BY ub.keyword
              ORDER BY frequency DESC
              LIMIT $limit";
    
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        error_log("❌ [getUserSearchKeywords] Query failed: " . mysqli_error($conn));
        return [];
    }
    
    $keywords = [];
    while ($row = mysqli_fetch_assoc($result)) {
        $keywords[] = $row['keyword'];
    }
    
    error_log("✅ [getUserSearchKeywords] Found " . count($keywords) . " keywords for user_id=$user_id: " . json_encode($keywords));
    
    return $keywords;
}

?>

