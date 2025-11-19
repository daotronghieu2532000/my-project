<?php
header("Access-Control-Allow-Methods: GET, POST");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(array("message" => "Không tìm thấy token"));
    exit;
}

$jwt = $matches[1]; // Lấy token từ Bearer

try {
    // Giải mã JWT
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    
    // Kiểm tra issuer
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(array("message" => "Issuer không hợp lệ"));
        exit;
    }
    
    // Lấy tham số từ request
    $keyword = isset($_GET['keyword']) ? addslashes(strip_tags($_GET['keyword'])) : '';
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 5;
    
    // Validate limit
    if ($limit > 10) $limit = 10;
    if ($limit < 1) $limit = 5;
    
    // Validation keyword - BẮT BUỘC phải có từ khóa (trừ trường hợp lấy random categories)
    if (empty($keyword) || (strlen($keyword) < 2 && $keyword != 'random_categories')) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Từ khóa phải có ít nhất 2 ký tự"
        ]);
        exit;
    }
    
    // Nếu keyword là "random_categories", chỉ trả về danh mục ngẫu nhiên
    if ($keyword === 'random_categories') {
        $randomCategories = getRandomCategories($conn, $limit);
        
        $response = [
            "success" => true,
            "message" => "Lấy danh mục ngẫu nhiên thành công",
            "data" => [
                "keyword" => $keyword,
                "suggestions" => $randomCategories,
                "total" => count($randomCategories)
            ]
        ];
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    $suggestions = array();
    
    // 1. Tìm kiếm từ khóa từ tên sản phẩm (bảng sanpham) - Ưu tiên cao nhất
    $product_query = "SELECT DISTINCT tieu_de, view, ban
                      FROM sanpham 
                      WHERE tieu_de LIKE '%$keyword%' 
                      AND kho > 0 
                      ORDER BY view DESC, ban DESC, tieu_de ASC 
                      LIMIT " . ($limit * 2);
    
    $product_result = mysqli_query($conn, $product_query);
    if ($product_result && mysqli_num_rows($product_result) > 0) {
        while ($row = mysqli_fetch_assoc($product_result)) {
            $suggestions[] = $row['tieu_de'];
        }
    }
    
    // 2. Tìm kiếm từ khóa từ danh mục (bảng category_sanpham)
    $category_query = "SELECT DISTINCT cat_tieude 
                       FROM category_sanpham 
                       WHERE cat_tieude LIKE '%$keyword%' 
                       ORDER BY cat_tieude ASC 
                       LIMIT $limit";
    
    $category_result = mysqli_query($conn, $category_query);
    if ($category_result && mysqli_num_rows($category_result) > 0) {
        while ($row = mysqli_fetch_assoc($category_result)) {
            $suggestions[] = $row['cat_tieude'];
        }
    }
    
    // 3. Tìm kiếm từ khóa từ phân loại sản phẩm (bảng phanloai_sanpham)
    $phanloai_query = "SELECT DISTINCT ten_loai 
                       FROM phanloai_sanpham 
                       WHERE ten_loai LIKE '%$keyword%' 
                       ORDER BY ten_loai ASC 
                       LIMIT $limit";
    
    $phanloai_result = mysqli_query($conn, $phanloai_query);
    if ($phanloai_result && mysqli_num_rows($phanloai_result) > 0) {
        while ($row = mysqli_fetch_assoc($phanloai_result)) {
            $suggestions[] = $row['ten_loai'];
        }
    }
    
    // 4. Gợi ý thông minh từ tiêu đề sản phẩm thực tế
    $smartSuggestions = getSmartSuggestionsFromProducts($keyword, $conn, $limit);
    $suggestions = array_merge($suggestions, $smartSuggestions);
    
    // 5. Thêm danh mục ngẫu nhiên (4 danh mục, random sau 24h)
    $randomCategories = getRandomCategories($conn, 4);
    $suggestions = array_merge($suggestions, $randomCategories);
    
    // 6. Gợi ý từ mapping nếu cần thiết
    if (count($suggestions) < $limit) {
        $mappedSuggestions = getMappedSuggestions($keyword, $limit - count($suggestions));
        $suggestions = array_merge($suggestions, $mappedSuggestions);
    }
    
    // Loại bỏ trùng lặp và giới hạn số lượng
    $suggestions = array_unique($suggestions);
    $suggestions = array_slice($suggestions, 0, $limit);
    
    // Nếu không có gợi ý từ database, dùng gợi ý mặc định
    if (empty($suggestions)) {
        $suggestions = [
            $keyword . ' nam',
            $keyword . ' nữ', 
            $keyword . ' giá rẻ',
            $keyword . ' chính hãng',
            $keyword . ' tốt nhất'
        ];
        $suggestions = array_slice($suggestions, 0, $limit);
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy gợi ý từ khóa thành công",
        "data" => [
            "keyword" => $keyword,
            "suggestions" => $suggestions,
            "total" => count($suggestions)
        ]
    ];
    
    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "success" => false,
        "message" => "Token không hợp lệ",
        "error" => $e->getMessage()
    ));
}

function getSmartSuggestionsFromProducts($keyword, $conn, $limit) {
    $keywordLower = strtolower(trim($keyword));
    $suggestions = array();
    
    // 1. Tìm từ khóa liên quan từ tiêu đề sản phẩm phổ biến
    $related_query = "SELECT DISTINCT tieu_de, view, ban
                      FROM sanpham 
                      WHERE kho > 0 AND active = 0 AND active = 0 AND active = 0 
                      AND (
                          tieu_de LIKE '%" . substr($keyword, 0, 2) . "%' OR
                          tieu_de LIKE '%" . substr($keyword, 0, 3) . "%'
                      )
                      ORDER BY view DESC, ban DESC, tieu_de ASC 
                      LIMIT 20";
    
    $related_result = mysqli_query($conn, $related_query);
    if ($related_result && mysqli_num_rows($related_result) > 0) {
        while ($row = mysqli_fetch_assoc($related_result)) {
            $title = $row['tieu_de'];
            $titleLower = strtolower($title);
            
            // Tìm từ khóa liên quan trong tiêu đề
            $words = explode(' ', $titleLower);
            foreach ($words as $word) {
                $word = trim($word);
                if (strlen($word) >= 2 && strlen($word) <= 20) {
                    // Kiểm tra từ có chứa keyword hoặc keyword chứa từ
                    if (strpos($word, $keywordLower) !== false || 
                        strpos($keywordLower, $word) !== false ||
                        similar_text($keywordLower, $word) >= 2) {
                        $suggestions[] = $word;
                    }
                }
            }
        }
    }
    
    // 1.1. Tìm từ khóa từ tiêu đề sản phẩm có chứa từ khóa tương tự
    $similar_query = "SELECT DISTINCT tieu_de, view, ban
                     FROM sanpham 
                     WHERE kho > 0 AND active = 0 AND active = 0 
                     AND tieu_de REGEXP '[[:space:]]" . substr($keyword, 0, 2) . "[[:alnum:]]*[[:space:]]'
                     ORDER BY view DESC, ban DESC, tieu_de ASC 
                     LIMIT 15";
    
    $similar_result = mysqli_query($conn, $similar_query);
    if ($similar_result && mysqli_num_rows($similar_result) > 0) {
        while ($row = mysqli_fetch_assoc($similar_result)) {
            $title = $row['tieu_de'];
            $titleLower = strtolower($title);
            
            // Tách từ và tìm từ có chứa keyword
            preg_match_all('/\b\w+\b/', $titleLower, $matches);
            foreach ($matches[0] as $word) {
                if (strlen($word) >= 2 && strlen($word) <= 15) {
                    if (strpos($word, $keywordLower) !== false || 
                        strpos($keywordLower, $word) !== false) {
                        $suggestions[] = $word;
                    }
                }
            }
        }
    }
    
    // 2. Tìm từ khóa từ thương hiệu phổ biến
    $brand_query = "SELECT DISTINCT thuong_hieu, COUNT(*) as count
                    FROM sanpham 
                    WHERE kho > 0 AND active = 0 
                    AND thuong_hieu IS NOT NULL 
                    AND thuong_hieu != ''
                    AND thuong_hieu LIKE '%$keyword%'
                    GROUP BY thuong_hieu
                    ORDER BY count DESC, thuong_hieu ASC 
                    LIMIT 5";
    
    $brand_result = mysqli_query($conn, $brand_query);
    if ($brand_result && mysqli_num_rows($brand_result) > 0) {
        while ($row = mysqli_fetch_assoc($brand_result)) {
            $suggestions[] = $row['thuong_hieu'];
        }
    }
    
    // 3. Tìm từ khóa từ danh mục phổ biến
    $category_query = "SELECT DISTINCT cat_tieude, COUNT(*) as count
                       FROM category_sanpham c
                       INNER JOIN sanpham s ON FIND_IN_SET(c.cat_id, s.cat)
                       WHERE s.kho > 0 AND s.active = 0 
                       AND cat_tieude LIKE '%$keyword%'
                       GROUP BY cat_tieude
                       ORDER BY count DESC, cat_tieude ASC 
                       LIMIT 5";
    
    $category_result = mysqli_query($conn, $category_query);
    if ($category_result && mysqli_num_rows($category_result) > 0) {
        while ($row = mysqli_fetch_assoc($category_result)) {
            $suggestions[] = $row['cat_tieude'];
        }
    }
    
    // 4. Tạo gợi ý từ từ khóa phổ biến trong tiêu đề
    $popular_words_query = "SELECT 
                            SUBSTRING_INDEX(SUBSTRING_INDEX(tieu_de, ' ', numbers.n), ' ', -1) as word,
                            COUNT(*) as frequency
                            FROM sanpham
                            CROSS JOIN (
                                SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 
                                UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
                            ) numbers
                            WHERE kho > 0 AND active = 0 AND active = 0 AND active = 0 AND active = 0 AND active = 0 
                            AND CHAR_LENGTH(tieu_de) - CHAR_LENGTH(REPLACE(tieu_de, ' ', '')) >= numbers.n - 1
                            AND SUBSTRING_INDEX(SUBSTRING_INDEX(tieu_de, ' ', numbers.n), ' ', -1) LIKE '%$keyword%'
                            AND CHAR_LENGTH(SUBSTRING_INDEX(SUBSTRING_INDEX(tieu_de, ' ', numbers.n), ' ', -1)) >= 2
                            GROUP BY word
                            HAVING frequency >= 2
                            ORDER BY frequency DESC, word ASC
                            LIMIT 5";
    
    $popular_result = mysqli_query($conn, $popular_words_query);
    if ($popular_result && mysqli_num_rows($popular_result) > 0) {
        while ($row = mysqli_fetch_assoc($popular_result)) {
            $suggestions[] = $row['word'];
        }
    }
    
    // 5. Tìm từ khóa từ các từ phổ biến có chứa keyword
    $common_words_query = "SELECT 
                           SUBSTRING_INDEX(SUBSTRING_INDEX(tieu_de, ' ', numbers.n), ' ', -1) as word,
                           COUNT(*) as frequency,
                           AVG(view) as avg_view
                           FROM sanpham
                           CROSS JOIN (
                               SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 
                               UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
                           ) numbers
                           WHERE kho > 0 AND active = 0 AND active = 0 AND active = 0 AND active = 0 
                           AND CHAR_LENGTH(tieu_de) - CHAR_LENGTH(REPLACE(tieu_de, ' ', '')) >= numbers.n - 1
                           AND SUBSTRING_INDEX(SUBSTRING_INDEX(tieu_de, ' ', numbers.n), ' ', -1) LIKE '%$keyword%'
                           AND CHAR_LENGTH(SUBSTRING_INDEX(SUBSTRING_INDEX(tieu_de, ' ', numbers.n), ' ', -1)) BETWEEN 3 AND 15
                           GROUP BY word
                           HAVING frequency >= 1
                           ORDER BY frequency DESC, avg_view DESC, word ASC
                           LIMIT 8";
    
    $common_result = mysqli_query($conn, $common_words_query);
    if ($common_result && mysqli_num_rows($common_result) > 0) {
        while ($row = mysqli_fetch_assoc($common_result)) {
            $suggestions[] = $row['word'];
        }
    }
    
    // Loại bỏ trùng lặp và giới hạn
    $suggestions = array_unique($suggestions);
    $suggestions = array_slice($suggestions, 0, $limit);
    
    return $suggestions;
}

function getRandomCategories($conn, $limit) {
    $suggestions = array();
    
    // Tạo seed dựa trên ngày hiện tại để random sau 24h
    $current_date = date('Y-m-d');
    $seed = crc32($current_date); // Tạo seed từ ngày hiện tại
    
    // Sử dụng seed để random
    $random_query = "SELECT cat_tieude, cat_minhhoa 
                     FROM category_sanpham 
                     WHERE cat_minhhoa IS NOT NULL 
                     AND cat_minhhoa != '' 
                     AND cat_tieude IS NOT NULL 
                     AND cat_tieude != ''
                     ORDER BY RAND($seed)
                     LIMIT $limit";
    
    $random_result = mysqli_query($conn, $random_query);
    if ($random_result && mysqli_num_rows($random_result) > 0) {
        while ($row = mysqli_fetch_assoc($random_result)) {
            $suggestions[] = $row['cat_tieude'];
        }
    }
    
    return $suggestions;
}

function getMappedSuggestions($keyword, $limit) {
    $keywordLower = strtolower(trim($keyword));
    
    // Mapping từ khóa gợi ý thông minh với từ khóa liên quan
    $suggestionMap = [
        // Điện tử
        'điện' => ['điện thoại', 'điện gia dụng', 'điện tử', 'điện máy'],
        'điện thoại' => ['điện thoại iphone', 'điện thoại samsung', 'điện thoại oppo', 'điện thoại xiaomi'],
        'laptop' => ['laptop gaming', 'laptop dell', 'laptop hp', 'laptop asus', 'laptop lenovo'],
        'tai nghe' => ['tai nghe bluetooth', 'tai nghe có dây', 'airpods', 'tai nghe gaming'],
        
        // Thực phẩm & đồ uống
        'sữa' => ['sữa tươi', 'sữa bột', 'sữa chua', 'sữa đậu nành', 'sữa công thức'],
        'thực phẩm' => ['thực phẩm chức năng', 'thực phẩm sạch', 'đồ ăn nhanh', 'thực phẩm organic'],
        'bánh' => ['bánh mì', 'bánh ngọt', 'bánh kẹo', 'bánh quy'],
        'kẹo' => ['kẹo ngọt', 'kẹo cao su', 'kẹo dẻo', 'kẹo chocolate'],
        'nước' => ['nước suối', 'nước ngọt', 'nước ép', 'nước khoáng'],
        
        // Mỹ phẩm & chăm sóc
        'mỹ phẩm' => ['mỹ phẩm hàn quốc', 'kem dưỡng da', 'son môi', 'phấn nền', 'serum'],
        'kem' => ['kem dưỡng da', 'kem chống nắng', 'kem đánh răng', 'kem body'],
        'dầu gội' => ['dầu gội đầu', 'dầu xả', 'dầu gội trị gàu', 'dầu gội organic'],
        
        // Thời trang
        'quần áo' => ['quần áo nam', 'quần áo nữ', 'quần áo trẻ em', 'quần áo thể thao'],
        'giày' => ['giày thể thao', 'giày cao gót', 'giày boot', 'giày sneaker'],
        
        // Gia dụng
        'chảo' => ['chảo chống dính', 'chảo inox', 'chảo gang', 'chảo ceramic'],
        'nước giặt' => ['nước giặt tide', 'nước giặt omo', 'nước xả vải', 'nước giặt persil'],
        
        // Giáo dục & giải trí
        'sách' => ['sách giáo khoa', 'sách tiểu thuyết', 'sách kỹ năng', 'sách thiếu nhi'],
        'đồ chơi' => ['đồ chơi trẻ em', 'đồ chơi giáo dục', 'đồ chơi điện tử', 'đồ chơi lego'],
        
        // Thể thao & du lịch
        'thể thao' => ['dụng cụ thể thao', 'quần áo thể thao', 'giày thể thao', 'phụ kiện thể thao'],
        'du lịch' => ['vali du lịch', 'balo du lịch', 'phụ kiện du lịch', 'đồ dùng du lịch'],
    ];
    
    // Tìm gợi ý phù hợp - cải thiện logic matching
    foreach ($suggestionMap as $key => $values) {
        // Kiểm tra từ khóa chứa key hoặc key chứa từ khóa
        if (strpos($keywordLower, $key) !== false || strpos($key, $keywordLower) !== false) {
            return array_slice($values, 0, $limit);
        }
        
        // Kiểm tra từ khóa có thể là viết tắt hoặc từ liên quan
        if (strlen($keywordLower) >= 2) {
            // Kiểm tra 2-3 ký tự đầu của key
            $keyPrefix = substr($key, 0, min(3, strlen($key)));
            if (strpos($keywordLower, $keyPrefix) !== false || strpos($keyPrefix, $keywordLower) !== false) {
                return array_slice($values, 0, $limit);
            }
        }
    }
    
    // Gợi ý thông minh dựa trên từ khóa ngắn
    if (strlen($keywordLower) <= 3) {
        $shortKeywordSuggestions = [
            'cha' => ['chảo', 'chảo chống dính', 'chảo inox', 'chảo gang'],
            'ke' => ['kem', 'kem dưỡng da', 'kem chống nắng', 'kem đánh răng'],
            'su' => ['sữa', 'sữa tươi', 'sữa bột', 'sữa chua'],
            'nu' => ['nước', 'nước suối', 'nước ngọt', 'nước ép'],
            'ba' => ['bánh', 'bánh mì', 'bánh ngọt', 'bánh kẹo'],
            'qu' => ['quần áo', 'quần áo nam', 'quần áo nữ'],
            'gi' => ['giày', 'giày thể thao', 'giày cao gót'],
            'da' => ['dầu gội', 'dầu xả', 'dầu gội trị gàu'],
            'my' => ['mỹ phẩm', 'mỹ phẩm hàn quốc', 'kem dưỡng da'],
            'th' => ['thực phẩm', 'thực phẩm chức năng', 'thực phẩm sạch'],
        ];
        
        if (isset($shortKeywordSuggestions[$keywordLower])) {
            return array_slice($shortKeywordSuggestions[$keywordLower], 0, $limit);
        }
    }
    
    // Gợi ý mặc định nếu không tìm thấy
    return [
        $keyword . ' nam',
        $keyword . ' nữ', 
        $keyword . ' giá rẻ',
        $keyword . ' chính hãng',
        $keyword . ' tốt nhất'
    ];
}
?>
