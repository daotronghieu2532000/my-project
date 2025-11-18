<?php
/**
 * API: Banners
 * Method: GET
 * URL: /v1/banners?position={position}&limit={limit}
 * 
 * Description: Lấy danh sách banner theo vị trí
 * 
 * Positions:
 * - banner_index_mobile: Banner chính trang chủ mobile
 * - banner_index: Banner chính trang chủ
 * - banner_big: Banner lớn
 * - banner_doitac: Banner đối tác
 * - banner_doitac_hai: Banner đối tác 2
 * - all: Lấy tất cả banner
 */

header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get parameters
    $position = isset($_GET['position']) ? trim($_GET['position']) : 'all';
    $limit = isset($_GET['limit']) ? max(1, min(100, intval($_GET['limit']))) : 0;
    $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : 0;
    
    // Xây dựng WHERE clause
    $where_conditions = ["shop_id = '$shop_id'"];
    
    if ($position !== 'all') {
        $where_conditions[] = "vi_tri = '" . mysqli_real_escape_string($conn, $position) . "'";
    }
    
    $where_clause = "WHERE " . implode(" AND ", $where_conditions);
    $limit_clause = $limit > 0 ? "LIMIT $limit" : "";
    
    // Query banners first
    $query = "SELECT * FROM banner $where_clause ORDER BY thu_tu ASC $limit_clause";
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Lỗi truy vấn database: ' . mysqli_error($conn)
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    $banners = [];
    $grouped_banners = []; // Group by position
    
    while ($banner = mysqli_fetch_assoc($result)) {
        $vi_tri = $banner['vi_tri'];
        $image_url = $banner['minh_hoa'];
        
        // Extract product ID from link if it's a product link
        $product_id = null;
        $banner_link = $banner['link'] ?? '';
        
        if (!empty($banner_link) && (strpos($banner_link, 'https://socdo.vn/product/') !== false || strpos($banner_link, 'https://www.socdo.vn/product/') !== false)) {
            // Extract slug from URL: https://socdo.vn/product/slug.html -> slug
            $slug = '';
            if (preg_match('/product\/([^\.]+)\.html/', $banner_link, $matches)) {
                $slug = $matches[1];
            } elseif (preg_match('/product\/([^\/\?]+)/', $banner_link, $matches)) {
                $slug = $matches[1];
            }
            
            if (!empty($slug)) {
                // Query product ID from sanpham table using slug
                $product_query = "SELECT id FROM sanpham WHERE link = '" . mysqli_real_escape_string($conn, $slug) . "' LIMIT 1";
                $product_result = mysqli_query($conn, $product_query);
                if ($product_result && $product_row = mysqli_fetch_assoc($product_result)) {
                    $product_id = intval($product_row['id']);
                }
            }
        }
        
        // Format image URL theo từng vị trí
        switch ($vi_tri) {
            case 'banner_big':
                $image_url = 'https://socdo.cdn.vccloud.vn' . str_replace('/uploads/minh-hoa/', '/uploads/thumbs/banner_big/', $image_url);
                break;
                
            case 'banner_doitac':
                $image_url = 'https://socdo.cdn.vccloud.vn' . str_replace('/uploads/minh-hoa/', '/uploads/minh-hoa/', $image_url);
                break;
                
            case 'banner_doitac_hai':
                $image_url = 'https://socdo.cdn.vccloud.vn' . str_replace('/uploads/minh-hoa/', '/uploads/thumbs/banner_doitac_hai/', $image_url);
                break;
                
            case 'banner_index_mobile':
                $image_url = 'https://socdo.cdn.vccloud.vn' . str_replace('/uploads/minh-hoa/', '/uploads/thumbs/banner_mobile_default/', $image_url);
                break;
                
            default:
                // Fallback
                if (strpos($image_url, 'http') !== 0) {
                    $image_url = 'https://socdo.cdn.vccloud.vn' . str_replace('/uploads/minh-hoa/', '/uploads/minh-hoa/', $image_url);
                }
                break;
        }
        
        $banner_data = [
            'id' => intval($banner['id']),
            'title' => $banner['tieu_de'] ?? '',
            'image' => $image_url,
            'link' => $banner['link'] ?? '',
            'position' => $vi_tri,
            'order' => intval($banner['thu_tu']),
            'shop_id' => intval($banner['shop_id']),
            'type' => 'image',
            'is_active' => true,
            'product_id' => $product_id
        ];
        
        // Add to main array
        $banners[] = $banner_data;
        
        // Group by position
        if (!isset($grouped_banners[$vi_tri])) {
            $grouped_banners[$vi_tri] = [];
        }
        $grouped_banners[$vi_tri][] = $banner_data;
    }
    
    // Response structure
    $response = [
        'success' => true,
        'message' => 'Lấy danh sách banner thành công',
        'data' => [
            'banners' => $banners,
            'total' => count($banners),
            'position' => $position
        ]
    ];
    
    // Nếu lấy tất cả, thêm grouped data
    if ($position === 'all') {
        $response['data']['grouped'] = $grouped_banners;
    }
    
    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} else {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Chỉ hỗ trợ phương thức GET'
    ]);
}

