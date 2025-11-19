<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

// Lấy user_id từ query parameter hoặc JWT token
$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;

// Nếu không có user_id từ query, thử lấy từ JWT token
if ($user_id == 0) {
    $headers = apache_request_headers();
    $authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
    
    if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
        $jwt = $matches[1]; // Lấy token từ Bearer
        
        try {
            // Giải mã JWT
            $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
            
            // Kiểm tra issuer
            if ($decoded->iss === $issuer) {
                $user_id = $decoded->data->user_id ?? 0;
            }
        } catch (Exception $e) {
            // JWT invalid, continue without user_id
        }
    }
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get parameters
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 500;
    $get_all = isset($_GET['all']) && $_GET['all'] == '1';
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $category = isset($_GET['category']) ? intval($_GET['category']) : 0;
    $brand = isset($_GET['brand']) ? intval($_GET['brand']) : 0;
    $min_price = isset($_GET['min_price']) ? intval($_GET['min_price']) : 0;
    $max_price = isset($_GET['max_price']) ? intval($_GET['max_price']) : 0;
    $sort_by = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'newest'; // newest, price_asc, price_desc, commission_asc, commission_desc
    $commission_min = isset($_GET['commission_min']) ? floatval($_GET['commission_min']) : 0;
    
    // Validate parameters
    if ($page < 1) $page = 1;
    if ($limit < 1 || $limit > 500) $limit = 300;
    
    // Override limit nếu get_all = true
    if ($get_all) {
        $limit = 999999;
        $page = 1;
    }

    $offset = ($page - 1) * $limit;
    
    // Xây dựng WHERE clause
    // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
    //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
    $where_conditions = array(
        "sanpham.status = 1", 
        "sanpham.active = 0",
        "sanpham.kho >= 0",
        "((NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id) AND sanpham.kho > 0) OR EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id AND pl.kho_sanpham_socdo > 0))"
    );
    
    // Lọc theo tìm kiếm (tìm theo tên, mô tả, ID)
    if (!empty($search)) {
        $search_escaped = mysqli_real_escape_string($conn, $search);
        $where_conditions[] = "(sanpham.tieu_de LIKE '%$search_escaped%' 
                                OR sanpham.noi_dung LIKE '%$search_escaped%' 
                                OR sanpham.id = '$search_escaped')";
    }
    
    // Lọc theo danh mục
    if ($category > 0) {
        $where_conditions[] = "FIND_IN_SET('$category', sanpham.cat) > 0";
    }
    
    // Lọc theo thương hiệu
    if ($brand > 0) {
        $where_conditions[] = "sanpham.thuong_hieu = $brand";
    }
    
    // Lọc theo giá
    if ($min_price > 0) {
        $where_conditions[] = "sanpham.gia_moi >= $min_price";
    }
    if ($max_price > 0) {
        $where_conditions[] = "sanpham.gia_moi <= $max_price";
    }
    
    // Chỉ lấy sản phẩm có chương trình affiliate active
    $current_time = time();
    $where_conditions[] = "EXISTS (
        SELECT 1 FROM sanpham_aff aff 
        WHERE (FIND_IN_SET(sanpham.id, aff.main_product) > 0 OR aff.sub_product LIKE CONCAT('%\"', sanpham.id, '\"%'))
        AND aff.date_start <= $current_time 
        AND aff.date_end >= $current_time
    )";
    
    $where_clause = "WHERE " . implode(" AND ", $where_conditions);
    
    // Xây dựng ORDER BY clause
    $order_by = "ORDER BY ";
    switch ($sort_by) {
        case 'price_asc':
            $order_by .= "sanpham.gia_moi ASC";
            break;
        case 'price_desc':
            $order_by .= "sanpham.gia_moi DESC";
            break;
        case 'name_asc':
            $order_by .= "sanpham.tieu_de ASC";
            break;
        case 'name_desc':
            $order_by .= "sanpham.tieu_de DESC";
            break;
        case 'popular':
            $order_by .= "sanpham.luot_mua DESC";
            break;
        case 'discount':
            $order_by .= "(CASE WHEN sanpham.gia_cu > 0 THEN ((sanpham.gia_cu - sanpham.gia_moi) / sanpham.gia_cu * 100) ELSE 0 END) DESC";
            break;
        case 'newest':
        default:
            $order_by .= "sanpham.id DESC";
            break;
    }
    
    // Đếm tổng số sản phẩm
    $count_query = "SELECT COUNT(*) as total FROM sanpham $where_clause";
    $count_result = mysqli_query($conn, $count_query);
    $total_records = 0;
    if ($count_result) {
        $count_row = mysqli_fetch_assoc($count_result);
        $total_records = $count_row['total'];
    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi count query: " . mysqli_error($conn),
            "query" => $count_query
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    $total_pages = ceil($total_records / $limit);
    
    // Lấy danh sách sản phẩm affiliate
    $products_query = "
        SELECT 
            sanpham.*,
            th.tieu_de as brand_name,
            th.anh_thuong_hieu as brand_logo
        FROM sanpham 
        LEFT JOIN thuong_hieu th ON th.id = sanpham.thuong_hieu
        $where_clause 
        $order_by 
        LIMIT $offset, $limit
    ";
    
    $products_result = mysqli_query($conn, $products_query);
    
    if (!$products_result) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi truy vấn database: " . mysqli_error($conn),
            "query" => $products_query
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    $products = array();
    
    while ($product = mysqli_fetch_assoc($products_result)) {
        // Get affiliate campaign info
        $sp_id = $product['id'];
        $aff_query = "SELECT tieu_de, sub_product 
                      FROM sanpham_aff 
                      WHERE (FIND_IN_SET($sp_id, main_product) > 0 OR sub_product LIKE '%\"$sp_id\"%')
                      AND date_start <= $current_time 
                      AND date_end >= $current_time 
                      ORDER BY date_post DESC 
                      LIMIT 1";
        $aff_result = mysqli_query($conn, $aff_query);
        $aff_info = mysqli_fetch_assoc($aff_result);
        
        $commission_info = array();
        if ($aff_info && !empty($aff_info['sub_product'])) {
            $sub_product = json_decode($aff_info['sub_product'], true);
            if (isset($sub_product[$sp_id]) && is_array($sub_product[$sp_id])) {
                foreach ($sub_product[$sp_id] as $commission) {
                    $commission_info[] = array(
                        'variant_id' => $commission['variant_id'] ?? 'main',
                        'type' => $commission['loai'] ?? 'tru',
                        'value' => (float) ($commission['hoa_hong'] ?? 0)
                    );
                }
            }
        }
        
        // Check if user already has a short link for this product (only if user_id provided)
        $short_link = null;
        $is_following = false;
        if ($user_id > 0) {
            $link_query = "SELECT rut_gon FROM rut_gon_shop 
                           WHERE sp_id = $sp_id AND user_id = $user_id 
                           ORDER BY date_post DESC LIMIT 1";
            $link_result = mysqli_query($conn, $link_query);
            $link_info = mysqli_fetch_assoc($link_result);
            $short_link = $link_info && !empty($link_info['rut_gon']) 
                ? "https://socdo.xyz/x/" . $link_info['rut_gon'] 
                : null;
            
            // Check if user is following this product
            $follow_query = "SELECT id FROM follow_aff WHERE sp_id = $sp_id AND user_id = $user_id";
            $follow_result = mysqli_query($conn, $follow_query);
            $is_following = $follow_result && mysqli_num_rows($follow_result) > 0;
        }
        
        // Format dữ liệu sản phẩm
        $product_data = array();
        $product_data['id'] = intval($product['id']);
        $product_data['name'] = $product['tieu_de'];
        $product_data['slug'] = $product['link'];
        $product_data['price'] = intval($product['gia_moi']);
        $product_data['old_price'] = intval($product['gia_cu']);
        $product_data['discount_percent'] = 0;
        
        // Tính % giảm giá
        if ($product['gia_cu'] > 0 && $product['gia_moi'] < $product['gia_cu']) {
            $product_data['discount_percent'] = round((($product['gia_cu'] - $product['gia_moi']) / $product['gia_cu']) * 100);
        }
        
        $product_data['shop_id'] = intval($product['shop']);
        $product_data['category_ids'] = explode(',', $product['cat']);
        $product_data['category_ids'] = array_filter(array_map('intval', $product_data['category_ids']));
        $product_data['brand_id'] = intval($product['thuong_hieu']);
        $product_data['brand_name'] = $product['brand_name'] ?: '';
        $product_data['brand_logo'] = $product['brand_logo'] ? 'https://' . $_SERVER['HTTP_HOST'] . '/' . $product['brand_logo'] : '';
        
        // Xử lý hình ảnh
        if (!empty($product['minh_hoa'])) {
            $product_data['image'] = 'https://' . $_SERVER['HTTP_HOST'] . '/' . $product['minh_hoa'];
        } else {
            $product_data['image'] = '';
        }
        
        // Tạo URL sản phẩm
        $product_data['product_url'] = 'https://' . $_SERVER['HTTP_HOST'] . '/product/' . $product_data['slug'] . '.html';
        
        // Thông tin affiliate
        $product_data['commission_info'] = $commission_info;
        $product_data['short_link'] = $short_link;
        $product_data['campaign_name'] = $aff_info['tieu_de'] ?? '';
        $product_data['is_following'] = $is_following;
        
        // Format giá
        $product_data['price_formatted'] = number_format($product_data['price'], 0, ',', '.') . ' ₫';
        $product_data['old_price_formatted'] = $product_data['old_price'] > 0 ? number_format($product_data['old_price'], 0, ',', '.') . ' ₫' : '';
        
        // Thông tin bổ sung
        $product_data['is_featured'] = intval($product['box_noibat']);
        $product_data['is_flash_sale'] = intval($product['box_flash']);
        $product_data['created_at'] = intval($product['date_post']);
        $product_data['updated_at'] = intval($product['date_post']);
        
        $products[] = $product_data;
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy danh sách sản phẩm affiliate thành công",
        "data" => [
            "products" => $products,
            "pagination" => [
                "current_page" => $page,
                "total_pages" => $total_pages,
                "total_records" => $total_records,
                "per_page" => $limit,
                "has_next" => $page < $total_pages,
                "has_prev" => $page > 1
            ],
            "filters" => [
                "search" => $search,
                "category" => $category,
                "brand" => $brand,
                "min_price" => $min_price,
                "max_price" => $max_price,
                "sort_by" => $sort_by,
                "commission_min" => $commission_min,
                "user_id" => $user_id
            ]
        ]
    ];
    
    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} else {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Chỉ hỗ trợ phương thức GET"
    ]);
}

