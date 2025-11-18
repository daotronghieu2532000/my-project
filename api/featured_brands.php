<?php
header("Access-Control-Allow-Methods: GET");
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
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 20;
        $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : 0;
        $sort = isset($_GET['sort']) ? addslashes($_GET['sort']) : 'order'; // order, name-asc, name-desc
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        // Validate parameters
        if ($page < 1) $page = 1;
        if ($limit < 1 || $limit > 100) $limit = 20;
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        
        $offset = ($page - 1) * $limit;
        
        // Xây dựng WHERE clause
        $where_conditions = array("thuong_hieu.status = 1");
        
        // Filter theo shop_id (0 = thương hiệu hệ thống, > 0 = thương hiệu shop)
        if ($shop_id >= 0) {
            $where_conditions[] = "thuong_hieu.shop = '$shop_id'";
        }
        
        $where_clause = "WHERE " . implode(" AND ", $where_conditions);
        
        // Xử lý sắp xếp
        $allowed_sorts = ['order', 'name-asc', 'name-desc'];
        $sort = in_array($sort, $allowed_sorts) ? $sort : 'order';
        
        switch ($sort) {
            case 'name-asc':
                $order_by = "ORDER BY thuong_hieu.tieu_de ASC";
                break;
            case 'name-desc':
                $order_by = "ORDER BY thuong_hieu.tieu_de DESC";
                break;
            case 'order':
            default:
                $order_by = "ORDER BY thuong_hieu.thu_tu ASC, thuong_hieu.id ASC";
                break;
        }
        
        // Đếm tổng số thương hiệu
        $count_query = "SELECT COUNT(*) as total FROM thuong_hieu $where_clause";
        $count_result = mysqli_query($conn, $count_query);
        $total_brands = 0;
        if ($count_result) {
            $count_row = mysqli_fetch_assoc($count_result);
            $total_brands = intval($count_row['total']);
        }
        
        $total_pages = ceil($total_brands / $limit);
        
        // Lấy danh sách thương hiệu
        $brands_query = "
            SELECT 
                thuong_hieu.*,
                COUNT(DISTINCT sanpham.id) as product_count
            FROM thuong_hieu
            LEFT JOIN sanpham ON sanpham.thuong_hieu = thuong_hieu.id 
                AND sanpham.status = 1 
                AND sanpham.active = 0
                AND (sanpham.kho > 0 OR EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id AND pl.kho_sanpham_socdo > 0))
            $where_clause
            GROUP BY thuong_hieu.id
            $order_by
            LIMIT $offset, $limit
        ";
        
        $brands_result = mysqli_query($conn, $brands_query);
        
        if (!$brands_result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
            ]);
            exit;
        }
        
        $brands = array();
        
        while ($brand = mysqli_fetch_assoc($brands_result)) {
            // Format thương hiệu
            $brand_data = array(
                'id' => intval($brand['id']),
                'shop_id' => intval($brand['shop']),
                'name' => $brand['tieu_de'],
                'order' => intval($brand['thu_tu']),
                'id_thuonghieu_socdo' => intval($brand['id_thuonghieu_socdo']),
                'product_count' => intval($brand['product_count']),
                'status' => intval($brand['status']),
                'approval_status' => intval($brand['trang_thai_duyet'] ?? 0)
            );
            
            // Xử lý hình ảnh thương hiệu
            if (!empty($brand['anh_thuong_hieu'])) {
                // Format ảnh: thay /uploads/thuong-hieu/ thành /uploads/thumbs/thuong_hieu/
                $image_path = str_replace('/uploads/thuong-hieu/', '/uploads/thumbs/thuong_hieu/', $brand['anh_thuong_hieu']);
                $brand_data['logo'] = 'https://socdo.vn/' . ltrim($image_path, '/');
                $brand_data['logo_original'] = 'https://socdo.vn/' . ltrim($brand['anh_thuong_hieu'], '/');
            } else {
                $brand_data['logo'] = '';
                $brand_data['logo_original'] = '';
            }
            
            // Link thương hiệu
            if (!empty($brand['link_anh'])) {
                $brand_data['link'] = $brand['link_anh'];
            } else {
                // Tạo link mặc định: /san-pham?brand={id}
                $brand_data['link'] = '/san-pham?brand=' . $brand['id'];
            }
            
            // URL đầy đủ
            $brand_data['url'] = 'https://socdo.vn' . $brand_data['link'];
            
            // Thông tin shop (nếu có)
            if ($brand['shop'] > 0) {
                $shop_query = "SELECT user_id, username, name, avatar FROM user_info WHERE user_id = '{$brand['shop']}' LIMIT 1";
                $shop_result = mysqli_query($conn, $shop_query);
                if ($shop_result && mysqli_num_rows($shop_result) > 0) {
                    $shop_info = mysqli_fetch_assoc($shop_result);
                    $brand_data['shop_info'] = array(
                        'id' => intval($shop_info['user_id']),
                        'username' => $shop_info['username'] ?? '',
                        'name' => $shop_info['name'] ?? '',
                        'avatar' => !empty($shop_info['avatar']) ? 'https://socdo.vn/' . ltrim($shop_info['avatar'], '/') : ''
                    );
                } else {
                    $brand_data['shop_info'] = null;
                }
            } else {
                $brand_data['shop_info'] = null; // Thương hiệu hệ thống
            }
            
            $brands[] = $brand_data;
        }
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách thương hiệu nổi bật thành công",
            "data" => [
                "brands" => $brands,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_brands" => $total_brands,
                    "per_page" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                ],
                "filters" => [
                    "shop_id" => $shop_id,
                    "sort" => $sort
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
    
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "success" => false,
        "message" => "Token không hợp lệ",
        "error" => $e->getMessage()
    ));
}
?>

