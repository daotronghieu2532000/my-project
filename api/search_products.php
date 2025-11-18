<?php
header("Access-Control-Allow-Methods: GET, POST");
require_once './vendor/autoload.php';
// Include user_behavior_helper để lưu hành vi người dùng
$helper_path = __DIR__ . '/user_behavior_helper.php';
if (file_exists($helper_path)) {
    require_once $helper_path;
}
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

// Helper function để tạo URL ảnh với CDN domain
// Sử dụng CDN: https://socdo.cdn.vccloud.vn/
// Fallback sẽ được xử lý ở phía Flutter app
function getImageUrlWithCDN($image_path) {
    if (empty($image_path)) return '';
    
    // Nếu đã là URL đầy đủ, trả về nguyên
    if (strpos($image_path, 'http://') === 0 || strpos($image_path, 'https://') === 0) {
        return $image_path;
    }
    
    // Loại bỏ dấu / ở đầu nếu có
    $image_path = ltrim($image_path, '/');
    
    // Sử dụng CDN domain cho ảnh
    return 'https://socdo.cdn.vccloud.vn/' . $image_path;
}

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
    
    // Lấy user_id từ JWT token hoặc GET parameter
    // Ưu tiên GET parameter (Flutter gửi), nếu không có thì lấy từ JWT token
    $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
    
    // Nếu không có trong GET, thử lấy từ JWT token (nếu có)
    if ($user_id <= 0) {
        // Thử lấy từ decoded->user_id (trực tiếp)
        if (isset($decoded->user_id)) {
            $user_id = intval($decoded->user_id);
        }
        // Thử lấy từ decoded->data->user_id (nested trong data)
        elseif (isset($decoded->data) && isset($decoded->data->user_id)) {
            $user_id = intval($decoded->data->user_id);
        }
    }
    
    // Lấy tham số tìm kiếm - CHỈ KEYWORD
    $keyword = isset($_GET['keyword']) ? addslashes(strip_tags($_GET['keyword'])) : '';
    $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;

    // Validate limit
    $get_all = isset($_GET['all']) && $_GET['all'] == '1';
    
    if ($limit > 500) $limit = 1000;
    if ($limit < 1) $limit = 400;
    if ($page < 1) $page = 1;
    
    // Override limit nếu get_all = true
    if ($get_all) {
        $limit = 999999;
        $page = 1;
    }
    
    $start = ($page - 1) * $limit;
    
    // Validation keyword - BẮT BUỘC phải có từ khóa
    if (empty($keyword)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Vui lòng nhập từ khóa tìm kiếm"
        ]);
        exit;
    }
    
    // Xây dựng câu WHERE cho tìm kiếm
    // Thêm logic tìm kiếm theo danh mục
    $category_search = '';
    $category_query = "SELECT cat_id FROM category_sanpham WHERE cat_tieude LIKE '%$keyword%' OR cat_title LIKE '%$keyword%'";
    $category_result = mysqli_query($conn, $category_query);
    
    if ($category_result && mysqli_num_rows($category_result) > 0) {
        $category_ids = array();
        while ($row = mysqli_fetch_assoc($category_result)) {
            $category_ids[] = $row['cat_id'];
        }
        
        if (!empty($category_ids)) {
            $category_search = " OR (";
            foreach ($category_ids as $index => $cat_id) {
                if ($index > 0) $category_search .= " OR ";
                $category_search .= "FIND_IN_SET($cat_id, sanpham.cat) > 0";
            }
            $category_search .= ")";
        }
    }
    
    // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
    //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
    $where_clause = "sanpham.active = 0 
                     AND sanpham.kho >= 0
                     AND ((NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id) AND sanpham.kho > 0) OR EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id AND pl.kho_sanpham_socdo > 0))
                     AND (sanpham.tieu_de LIKE '%$keyword%' OR sanpham.ma_sanpham LIKE '%$keyword%'$category_search)";
    
    // ORDER BY theo logic hàm list_sanpham_timkiem
    $order_clause = 'has_rating DESC, avg_rating DESC, sanpham.view DESC';
    
    // Đếm tổng số sản phẩm - Tối ưu với LEFT JOIN product_rating_stats
    $count_query = "SELECT COUNT(*) as total 
                   FROM sanpham
                   LEFT JOIN transport ON sanpham.kho_id = transport.id
                   LEFT JOIN tinh_moi ON transport.province = tinh_moi.id
                   WHERE $where_clause";
    $count_result = mysqli_query($conn, $count_query);
    $total_products = mysqli_fetch_assoc($count_result)['total'];
    
    // Lấy danh sách sản phẩm - CHỈ CÁC TRƯỜNG CẦN THIẾT
    // Với sàn (shop = 0): lấy transport với user_id = 0
    // Với shop thường: lấy transport theo kho_id
    // Sử dụng LEFT JOIN với product_rating_stats (đã có index) thay vì subquery để tối ưu performance
    $query = "SELECT sanpham.id, sanpham.ma_sanpham, sanpham.tieu_de, sanpham.minh_hoa, 
              sanpham.link, sanpham.gia_cu, sanpham.gia_moi, sanpham.gia_drop, sanpham.gia_ctv,
              sanpham.thuong_hieu, sanpham.kho, sanpham.kho_hcm, sanpham.ban, sanpham.view,
              sanpham.box_banchay, sanpham.box_noibat, sanpham.box_flash, sanpham.date_post, sanpham.shop,
              COALESCE(tinh_moi.tieu_de, tinh_moi_san.tieu_de) AS province_name,
              COALESCE(prs.average_rating, 0) AS avg_rating,
              COALESCE(prs.total_reviews, 0) AS total_reviews,
              IF(COALESCE(prs.total_reviews, 0) > 0, 1, 0) AS has_rating
              FROM sanpham
              LEFT JOIN transport ON sanpham.kho_id = transport.id AND sanpham.shop > 0 AND transport.user_id = sanpham.shop
              LEFT JOIN tinh_moi ON transport.province = tinh_moi.id
              LEFT JOIN transport transport_san ON transport_san.user_id = 0 AND sanpham.shop = 0 AND transport_san.is_default = 1
              LEFT JOIN tinh_moi tinh_moi_san ON transport_san.province = tinh_moi_san.id
              LEFT JOIN product_rating_stats prs ON sanpham.id = prs.product_id AND sanpham.shop = prs.shop_id
              WHERE $where_clause
              ORDER BY $order_clause
              LIMIT $start, $limit";
              
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
        ]);
        exit;
    }
    
    $products = array();
    $current_time = time();
    $today = date('Ymd');
    
    while ($row = mysqli_fetch_assoc($result)) {
        $id_sp = $row['id'];
        $row['date_post_formatted'] = date('d/m/Y', $row['date_post']);
        
        // Xử lý giá từ bảng phanloai_sanpham - theo logic hàm gốc
        $sql_pl = mysqli_query($conn, "SELECT MAX(gia_cu) AS max_gia_cu, MIN(gia_moi) AS min_gia_moi FROM phanloai_sanpham WHERE sp_id = '$id_sp'");
        if ($sql_pl && mysqli_num_rows($sql_pl) > 0) {
            $pl = mysqli_fetch_assoc($sql_pl);
            if ($pl['max_gia_cu'] !== null && $pl['min_gia_moi'] !== null) {
                $row['gia_cu'] = (int) $pl['max_gia_cu'];
                $row['gia_moi'] = (int) $pl['min_gia_moi'];
            }
        }
        
        // Tính phần trăm giảm giá
        $discount_percent = 0;
        if ($row['gia_cu'] > $row['gia_moi'] && $row['gia_cu'] > 0) {
            $discount_percent = ceil((($row['gia_cu'] - $row['gia_moi']) / $row['gia_cu']) * 100);
        }
        
        // Số lượng đã bán - lấy từ cột ban trong bảng sanpham (dữ liệu thật)
        $total_sold = intval($row['ban']);
        
        // Format giá tiền
        $row['gia_cu_formatted'] = number_format($row['gia_cu']);
        $row['gia_moi_formatted'] = number_format($row['gia_moi']);
        $row['gia_drop_formatted'] = number_format($row['gia_drop']);
        $row['gia_ctv_formatted'] = number_format($row['gia_ctv']);
        $row['discount_percent'] = $discount_percent;
        $row['total_sold'] = $total_sold;
        
        // Xử lý tỉnh thành
        if (empty($row['province_name'])) {
            $row['province_name'] = 'Thành phố Hà Nội';
        }
        $row['province_name'] = str_replace(['Tỉnh ', 'Thành phố '], '', $row['province_name']);
        
        // Xử lý hình ảnh - ưu tiên thumbnail
        $original_image = $row['minh_hoa'];
        $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/sanpham_anh_340x340/', $original_image);
        
        if (!empty($thumb_image)) {
            $row['image_url'] = getImageUrlWithCDN($thumb_image);
        } elseif (!empty($original_image)) {
            $row['image_url'] = getImageUrlWithCDN($original_image);
        } else {
            $row['image_url'] = 'https://socdo.vn/images/no-images.jpg';
        }
        
        // Rating và reviews - lấy từ product_rating_stats (dữ liệu thật)
        $total_reviews = intval($row['total_reviews']);
        $avg_rating = floatval($row['avg_rating']);
        
        // Star HTML
        $star_html = '';
        if ($avg_rating > 0) {
            for ($j = 1; $j <= 5; $j++) {
                if ($j <= floor($avg_rating)) {
                    $star_html .= '<i class="fas fa-star" style="color: #ffc107"></i>';
                } elseif ($j - $avg_rating <= 0.75 && $avg_rating > floor($avg_rating)) {
                    $star_html .= '<i class="fas fa-star-half-alt" style="color: #ffc107"></i>';
                } else {
                    $star_html .= '<i class="far fa-star" style="color: #ffc107"></i>';
                }
            }
        } else {
            // Không có đánh giá
            for ($j = 1; $j <= 5; $j++) {
                $star_html .= '<i class="far fa-star" style="color: #ffc107"></i>';
            }
        }
        
        $row['star_html'] = $star_html;
        $row['review_count'] = "($total_reviews)";
        $row['avg_rating'] = round($avg_rating, 1);
        $row['total_reviews'] = $total_reviews;
        
        // Xử lý voucher và freeship - theo logic hàm gốc
        $deal_shop = $row['shop'];
        $voucher_icon = '';
        $freeship_icon = '';
        
        // Check voucher - Logic chuẩn với hệ thống
        if ($deal_shop > 0) {
            // Shop thường
        $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('$id_sp', sanpham) AND shop = '$deal_shop' AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
        if (mysqli_num_rows($check_coupon) > 0) {
            $voucher_icon = 'Voucher';
        } else {
            $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
            if (mysqli_num_rows($check_coupon_all) > 0) {
                $voucher_icon = 'Voucher';
                }
            }
        } else {
            // Sàn (shop = 0)
            $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('$id_sp', sanpham) AND shop = 0 AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
            if (mysqli_num_rows($check_coupon) > 0) {
                $voucher_icon = 'Voucher';
            } else {
                $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = 0 AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                if (mysqli_num_rows($check_coupon_all) > 0) {
                    $voucher_icon = 'Voucher';
                }
            }
        }
        
        // Check freeship - Logic chuẩn với 4 mode
        $freeship_query = "SELECT free_ship_all, free_ship_discount, free_ship_min_order, fee_ship_products FROM transport WHERE user_id = '$deal_shop' AND (free_ship_all > 0 OR free_ship_discount > 0) LIMIT 1";
        $freeship_result = mysqli_query($conn, $freeship_query);
        $freeship_label = '';
        
        if ($freeship_result && mysqli_num_rows($freeship_result) > 0) {
            $freeship_data = mysqli_fetch_assoc($freeship_result);
            $mode = intval($freeship_data['free_ship_all'] ?? 0);
            $discount = intval($freeship_data['free_ship_discount'] ?? 0);
            $minOrder = intval($freeship_data['free_ship_min_order'] ?? 0);
            
            // Lấy giá sản phẩm để kiểm tra điều kiện min_order
            $base_price = $row['gia_moi'];
            
            // Mode 0: Giảm cố định (VD: -15,000đ) - Cần kiểm tra điều kiện min_order
            if ($mode === 0 && $discount > 0 && $base_price >= $minOrder) {
                $freeship_label = 'Giảm ' . number_format($discount) . 'đ ship';
            }
            // Mode 1: Freeship toàn bộ (100%)
            elseif ($mode === 1) {
                $freeship_label = 'Freeship 100%';
            }
            // Mode 2: Giảm theo % (VD: -50%) - Cần kiểm tra điều kiện min_order
            elseif ($mode === 2 && $discount > 0 && $base_price >= $minOrder) {
                $freeship_label = 'Giảm ' . intval($discount) . '% ship';
            }
            // Mode 3: Ưu đãi ship theo sản phẩm cụ thể - cần kiểm tra fee_ship_products
            elseif ($mode === 3) {
                $fee_ship_products = $freeship_data['fee_ship_products'] ?? '';
                $ship_discount_amount = 0;
                
                if (!empty($fee_ship_products)) {
                    $fee_ship_products_array = json_decode($fee_ship_products, true);
                    if (is_array($fee_ship_products_array)) {
                        foreach ($fee_ship_products_array as $ship_item) {
                            if (isset($ship_item['sp_id']) && $ship_item['sp_id'] == $id_sp) {
                                // Lấy số tiền hỗ trợ ship cụ thể
                                if (isset($ship_item['ship_support'])) {
                                    $ship_discount_amount = intval($ship_item['ship_support']);
                                }
                                break;
                            }
                        }
                    }
                }
                
                // Hiển thị số tiền hỗ trợ ship cụ thể
                if ($ship_discount_amount > 0) {
                    $freeship_label = 'Hỗ trợ ship ' . number_format($ship_discount_amount) . '₫';
                }
            }
            
            $freeship_icon = $freeship_label ?: '';
        }
        
        $chinhhang_icon = 'Chính hãng';
        
        // Thêm badges
        $badges = array();
        if ($row['box_banchay'] == 1) $badges[] = 'Bán chạy';
        if ($row['box_noibat'] == 1) $badges[] = 'Nổi bật';
        if ($row['box_flash'] == 1) $badges[] = 'Flash sale';
        if ($discount_percent > 0) $badges[] = "-$discount_percent%";
        if (!empty($voucher_icon)) $badges[] = $voucher_icon;
        if (!empty($freeship_icon)) $badges[] = $freeship_icon;
        $badges[] = $chinhhang_icon;
        
        $row['badges'] = $badges;
        $row['voucher_icon'] = $voucher_icon;
        $row['freeship_icon'] = $freeship_icon;
        $row['chinhhang_icon'] = $chinhhang_icon;
        
        // Thông tin kho (đã lấy từ query với COALESCE)
        $row['warehouse_name'] = '';
        $row['province_name'] = $row['province_name'] ?? 'Thành phố Hà Nội';
        
        // Label sale
        if ($discount_percent > 0) {
            $row['label_sale'] = '<div class="label_product"><div class="label_wrapper">-' . $discount_percent . '%</div></div>';
        } else {
            $row['label_sale'] = '';
        }
        
        // Tạo URL sản phẩm
        $row['product_url'] = 'https://socdo.vn/san-pham/' . $row['id'] . '/' . $row['link'] . '.html';
        
        $products[] = $row;
    }
    
    // Tính toán thông tin phân trang
    $total_pages = ceil($total_products / $limit);
    
    // Tìm kiếm shop (ctv = 1 trong user_info)
    $shops = array();
    $shop_limit = 10; // Giới hạn số shop gợi ý
    
    // Escape keyword để tránh SQL injection
    $escaped_keyword = mysqli_real_escape_string($conn, $keyword);
    
    // Query tìm shop - chỉ tìm theo cột name như yêu cầu
    // Sort: ưu tiên name match chính xác, sau đó có avatar, cuối cùng là name ASC
    $shop_query = "SELECT user_id, shop, username, name, avatar, domain 
                   FROM user_info 
                   WHERE ctv = 1 
                   AND active = 1
                   AND name LIKE '%$escaped_keyword%'
                   ORDER BY 
                     CASE 
                       WHEN name = '$escaped_keyword' THEN 1
                       WHEN name LIKE '$escaped_keyword%' THEN 2
                       WHEN name LIKE '%$escaped_keyword%' THEN 3
                       ELSE 4
                     END,
                     CASE WHEN avatar IS NOT NULL AND avatar != '' AND avatar != '0' THEN 0 ELSE 1 END,
                     name ASC
                   LIMIT $shop_limit";
    
    $shop_result = mysqli_query($conn, $shop_query);
    
    if ($shop_result) {
        if (mysqli_num_rows($shop_result) > 0) {
            while ($shop_row = mysqli_fetch_assoc($shop_result)) {
                $shop_user_id = $shop_row['user_id'];
                $shop_id = $shop_row['shop'] ? intval($shop_row['shop']) : $shop_user_id;
                
                $avatar_raw = $shop_row['avatar'];
                
                // Xử lý avatar shop
                $avatar_url = '';
                if (!empty($avatar_raw) && $avatar_raw !== '0' && strlen(trim($avatar_raw)) > 0) {
                    $avatar = trim($avatar_raw);
                    $avatar_url = getImageUrlWithCDN($avatar);
                }
                
                // Xử lý domain/handle shop
                $shop_handle = $shop_row['domain'];
                if (empty($shop_handle)) {
                    $shop_handle = $shop_row['username'];
                }
                
                $shop_data = [
                    'shop_id' => (int) $shop_id,
                    'user_id' => (int) $shop_user_id,
                    'name' => $shop_row['name'],
                    'username' => $shop_row['username'],
                    'handle' => $shop_handle,
                    'avatar' => $avatar_url,
                ];
                
                $shops[] = $shop_data;
            }
        }
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy danh sách sản phẩm thành công",
        "data" => [
            "products" => $products,
            "shops" => $shops,
            "pagination" => [
                "current_page" => $page,
                "total_pages" => $total_pages,
                "total_products" => $total_products,
                "limit" => $limit,
                "has_next" => $page < $total_pages,
                "has_prev" => $page > 1
            ],
            "search_params" => [
                "keyword" => $keyword,
                "page" => $page,
                "limit" => $limit
            ]
        ]
    ];
    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
    // Lưu hành vi tìm kiếm (chạy sau khi response đã được gửi, không ảnh hưởng API)
    if (function_exists('saveUserBehavior') && $user_id > 0 && !empty($keyword)) {
        try {
            // Lấy category_id từ kết quả tìm kiếm (category đầu tiên nếu có)
            $category_id = null;
            if (!empty($products) && isset($products[0]['cat'])) {
                $cat_string = $products[0]['cat'];
                if (!empty($cat_string)) {
                    $cat_array = explode(',', $cat_string);
                    if (!empty($cat_array)) {
                        $category_id = intval(trim($cat_array[0]));
                    }
                }
            }
            
            saveUserBehavior($conn, $user_id, 'search', null, $keyword, $category_id, [
                'keyword' => $keyword,
                'result_count' => count($products),
                'total_products' => $total_products
            ]);
        } catch (Exception $e) {
            // Lỗi lưu hành vi không ảnh hưởng đến API
        }
    }
    
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "success" => false,
        "message" => "Token không hợp lệ",
        "error" => $e->getMessage()
    ));
}
?>
