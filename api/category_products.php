<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
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
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        $type = isset($_GET['type']) ? addslashes($_GET['type']) : 'featured';
        $category_id = isset($_GET['category_id']) ? intval($_GET['category_id']) : 0;
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 500;
        
        // Validate parameters
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        if ($limit > 500) $limit = 500;
        if ($limit < 1) $limit = 100;
        if ($page < 1) $page = 1;
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        
        $start = ($page - 1) * $limit;
        
        if ($category_id > 0) {
            // Lấy chi tiết một danh mục
            $query = "SELECT * FROM category_sanpham WHERE cat_id = $category_id LIMIT 1";
            $result = mysqli_query($conn, $query);
            
            if (!$result || mysqli_num_rows($result) == 0) {
                http_response_code(404);
                echo json_encode([
                    "success" => false,
                    "message" => "Không tìm thấy danh mục"
                ]);
                exit;
            }
            
            $category = mysqli_fetch_assoc($result);
            
            // Xử lý hình ảnh thumbnail với CDN
            $original_image = $category['cat_minhhoa'];
            $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/list_danhmuc_noibat/', $original_image);
            
            if (!empty($thumb_image)) {
                $category['image_url'] = getImageUrlWithCDN($thumb_image);
            } elseif (!empty($original_image)) {
                $category['image_url'] = getImageUrlWithCDN($original_image);
            } else {
                $category['image_url'] = 'https://socdo.vn/images/no-images.jpg';
            }
            
            // Tạo URL danh mục
            $category['category_url'] = 'https://socdo.vn/danh-muc/' . $category['cat_id'] . '/' . $category['cat_link'] . '.html';
            
            // Đếm số sản phẩm trong danh mục
            // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
            //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
            $count_query = "SELECT COUNT(DISTINCT s.id) as total 
                            FROM sanpham s
                            WHERE FIND_IN_SET($category_id, s.cat) > 0 
                            AND s.active = 0
                            AND s.kho >= 0
                            AND (
                                -- Sản phẩm không có phân loại: check kho chính
                                (NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = s.id) AND s.kho > 0)
                                OR
                                -- Sản phẩm có phân loại: check kho phân loại (không check kho chính)
                                EXISTS (
                                    SELECT 1 FROM phanloai_sanpham pl 
                                    WHERE pl.sp_id = s.id 
                                    AND pl.kho_sanpham_socdo > 0
                                )
                            )";
            $count_result = mysqli_query($conn, $count_query);
            $category['total_products'] = mysqli_fetch_assoc($count_result)['total'];
            
            $response = [
                "success" => true,
                "message" => "Lấy chi tiết danh mục thành công",
                "data" => $category
            ];
            
        } else {
            // Lấy danh sách danh mục
            $where_conditions = array();
            
            switch ($type) {
                case 'featured':
                    // Danh mục nổi bật - theo logic hàm list_category_noibat
                    $where_conditions[] = "cat_noibat = '1'";
                    $order_by = "cat_thutu ASC";
                    break;
                case 'index':
                    // Danh mục hiển thị trang chủ
                    $where_conditions[] = "cat_index = '1'";
                    $order_by = "cat_thutu DESC";
                    break;
                case 'all':
                default:
                    // Tất cả danh mục
                    $order_by = "cat_thutu ASC, cat_id DESC";
                    break;
            }
            
            $where_clause = !empty($where_conditions) ? 'WHERE ' . implode(' AND ', $where_conditions) : '';
            
            // Đếm tổng số danh mục
            $count_query = "SELECT COUNT(*) as total FROM category_sanpham $where_clause";
            $count_result = mysqli_query($conn, $count_query);
            $total_categories = mysqli_fetch_assoc($count_result)['total'];
            
            // Lấy danh sách danh mục
            $query = "SELECT * FROM category_sanpham $where_clause ORDER BY $order_by LIMIT $start, $limit";
            $result = mysqli_query($conn, $query);
            
            if (!$result) {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
                ]);
                exit;
            }
            
            $categories = array();
            while ($row = mysqli_fetch_assoc($result)) {
                // Xử lý hình ảnh thumbnail với CDN - theo logic hàm list_category_noibat
                $original_image = $row['cat_minhhoa'];
                $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/list_danhmuc_noibat/', $original_image);
                
                if (!empty($thumb_image)) {
                    $row['image_url'] = getImageUrlWithCDN($thumb_image);
                } elseif (!empty($original_image)) {
                    $row['image_url'] = getImageUrlWithCDN($original_image);
                } else {
                    $row['image_url'] = 'https://socdo.vn/images/no-images.jpg';
                }
                
                // Tạo URL danh mục
                $row['category_url'] = 'https://socdo.vn/danh-muc/' . $row['cat_id'] . '/' . $row['cat_link'] . '.html';
                
                // Đếm số sản phẩm trong danh mục
                // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
                //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
                $cat_id = $row['cat_id'];
                $count_query = "SELECT COUNT(DISTINCT s.id) as total 
                                FROM sanpham s
                                WHERE FIND_IN_SET($cat_id, s.cat) > 0 
                                AND s.active = 0
                                AND s.kho >= 0
                                AND (
                                    -- Sản phẩm không có phân loại: check kho chính
                                    (NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = s.id) AND s.kho > 0)
                                    OR
                                    -- Sản phẩm có phân loại: check kho phân loại (không check kho chính)
                                    EXISTS (
                                        SELECT 1 FROM phanloai_sanpham pl 
                                        WHERE pl.sp_id = s.id 
                                        AND pl.kho_sanpham_socdo > 0
                                    )
                                )";
                $count_result = mysqli_query($conn, $count_query);
                $row['total_products'] = mysqli_fetch_assoc($count_result)['total'];
                
                // Thêm thông tin bổ sung
                $row['is_featured'] = $row['cat_noibat'] == 1 ? true : false;
                $row['is_index'] = $row['cat_index'] == 1 ? true : false;
                
                $categories[] = $row;
            }
            
            // Tính toán thông tin phân trang
            $total_pages = ceil($total_categories / $limit);
            
            $response = [
                "success" => true,
                "message" => "Lấy danh sách danh mục thành công",
                "data" => [
                    "categories" => $categories,
                    "pagination" => [
                        "current_page" => $page,
                        "total_pages" => $total_pages,
                        "total_categories" => $total_categories,
                        "limit" => $limit,
                        "has_next" => $page < $total_pages,
                        "has_prev" => $page > 1
                    ],
                    "filters" => [
                        "type" => $type
                    ]
                ]
            ];
        }
        
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
