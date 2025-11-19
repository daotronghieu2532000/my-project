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
        $type = isset($_GET['type']) ? trim($_GET['type']) : 'all'; // 'all', 'parents', 'children'
        $parent_id = isset($_GET['parent_id']) ? intval($_GET['parent_id']) : 0;
        $include_children = isset($_GET['include_children']) ? intval($_GET['include_children']) : 1;
        $include_products_count = isset($_GET['include_products_count']) ? intval($_GET['include_products_count']) : 0;
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 500;
        
        // Validate parameters
        if ($page < 1) $page = 1;
        if ($limit < 1 || $limit > 1000) $limit = 500;
        
        $offset = ($page - 1) * $limit;
        
        // Xây dựng query dựa trên type
        if ($type === 'parents') {
            // Chỉ lấy danh mục cha (cat_main = 0)
            $base_query = "FROM category_sanpham WHERE cat_main = 0";
            
        } elseif ($type === 'children') {
            // Chỉ lấy danh mục con (cat_main > 0)
            $base_query = "FROM category_sanpham WHERE cat_main > 0";
            if ($parent_id > 0) {
                $base_query .= " AND cat_main = $parent_id";
            }
            
        } else {
            // Lấy tất cả danh mục
            $base_query = "FROM category_sanpham WHERE 1=1";
            if ($parent_id > 0) {
                $base_query .= " AND cat_main = $parent_id";
            }
        }
        
        // Đếm tổng số danh mục
        $count_query = "SELECT COUNT(*) as total " . $base_query;
        $count_result = mysqli_query($conn, $count_query);
        $total_records = 0;
        if ($count_result) {
            $count_row = mysqli_fetch_assoc($count_result);
            $total_records = $count_row['total'];
        }
        
        $total_pages = ceil($total_records / $limit);
        
        // Lấy danh sách danh mục
        $categories_query = "SELECT * " . $base_query . " ORDER BY cat_thutu ASC, cat_id ASC LIMIT $offset, $limit";
        $categories_result = mysqli_query($conn, $categories_query);
        
        if (!$categories_result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database"
            ]);
            exit;
        }
        
        $categories = array();
        
        while ($category = mysqli_fetch_assoc($categories_result)) {
            // Format dữ liệu danh mục
            $category_data = array();
            $category_data['id'] = intval($category['cat_id']);
            $category_data['name'] = $category['cat_tieude'];
            $category_data['slug'] = $category['cat_blank'];
            $category_data['parent_id'] = intval($category['cat_main']);
            $category_data['order'] = intval($category['cat_thutu']);
            $category_data['icon'] = $category['cat_icon'];
            $category_data['image'] = $category['cat_minhhoa'];
            $category_data['description'] = $category['cat_noidung'];
            $category_data['title'] = $category['cat_title'];
            $category_data['meta_description'] = $category['cat_description'];
            $category_data['is_featured'] = intval($category['cat_noibat']);
            $category_data['is_trending'] = intval($category['cat_trend']);
            $category_data['show_on_homepage'] = intval($category['cat_index']);
            $category_data['status'] = intval($category['status']);
            
            // Tạo URL danh mục
            $category_data['category_url'] = 'https://socdo.vn/danh-muc/' . $category_data['id'] . '/' . $category_data['slug'] . '.html';
            
            // Xử lý icon
            $icon_data = array();
            if (!empty($category['cat_icon'])) {
                $icon_extension = pathinfo($category['cat_icon'], PATHINFO_EXTENSION);
                $icon_extension = strtolower($icon_extension);
                
                if (in_array($icon_extension, array('jpg', 'png', 'gif', 'jpeg', 'webp'))) {
                    // Nếu là ảnh
                    $icon_data['type'] = 'image';
                    $icon_data['url'] = 'https://socdo.vn/' . $category['cat_icon'];
                    $icon_data['alt'] = $category['cat_tieude'];
                } else {
                    // Nếu là text/icon font
                    $icon_data['type'] = 'text';
                    $icon_data['content'] = $category['cat_icon'];
                }
            } else {
                $icon_data['type'] = 'default';
                $icon_data['content'] = '<i class="fa fa-folder"></i>';
            }
            $category_data['icon_data'] = $icon_data;
            
            // Xử lý hình ảnh
            if (!empty($category['cat_minhhoa'])) {
                $category_data['image_url'] = 'https://socdo.vn/' . $category['cat_minhhoa'];
                
                // Tạo thumbnail
                $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/list_danhmuc_noibat/', $category['cat_minhhoa']);
                $category_data['thumb_url'] = 'https://socdo.vn/' . $thumb_image;
            } else {
                $category_data['image_url'] = '';
                $category_data['thumb_url'] = '';
            }
            
            // Kiểm tra là danh mục cha hay con
            $category_data['is_parent'] = ($category['cat_main'] == 0);
            $category_data['level'] = $category_data['is_parent'] ? 1 : 2;
            
            // Thông tin danh mục cha (nếu là danh mục con)
            if (!$category_data['is_parent']) {
                $parent_query = "SELECT cat_id, cat_tieude, cat_blank FROM category_sanpham WHERE cat_id = '{$category['cat_main']}' LIMIT 1";
                $parent_result = mysqli_query($conn, $parent_query);
                if ($parent_result && mysqli_num_rows($parent_result) > 0) {
                    $parent_info = mysqli_fetch_assoc($parent_result);
                    $category_data['parent_info'] = array(
                        'id' => intval($parent_info['cat_id']),
                        'name' => $parent_info['cat_tieude'],
                        'slug' => $parent_info['cat_blank'],
                        'url' => 'https://socdo.vn/danh-muc/' . $parent_info['cat_id'] . '/' . $parent_info['cat_blank'] . '.html'
                    );
                } else {
                    $category_data['parent_info'] = null;
                }
            } else {
                $category_data['parent_info'] = null;
            }
            
            // Đếm số sản phẩm (nếu yêu cầu)
            // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
            //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
            if ($include_products_count) {
                $products_count_query = "SELECT COUNT(DISTINCT s.id) as total 
                                        FROM sanpham s
                                        WHERE FIND_IN_SET('{$category['cat_id']}', s.cat) > 0 
                                        AND s.status = 1 
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
                $products_count_result = mysqli_query($conn, $products_count_query);
                if ($products_count_result) {
                    $products_count = mysqli_fetch_assoc($products_count_result);
                    $category_data['products_count'] = intval($products_count['total']);
                } else {
                    $category_data['products_count'] = 0;
                }
            } else {
                $category_data['products_count'] = null;
            }
            
            // Lấy danh mục con (nếu yêu cầu và là danh mục cha)
            if ($include_children && $category_data['is_parent']) {
                $children_query = "SELECT cat_id, cat_tieude, cat_blank, cat_thutu FROM category_sanpham WHERE cat_main = '{$category['cat_id']}' ORDER BY cat_thutu ASC";
                $children_result = mysqli_query($conn, $children_query);
                
                $children = array();
                if ($children_result) {
                    while ($child = mysqli_fetch_assoc($children_result)) {
                        $children[] = array(
                            'id' => intval($child['cat_id']),
                            'name' => $child['cat_tieude'],
                            'slug' => $child['cat_blank'],
                            'order' => intval($child['cat_thutu']),
                            'url' => 'https://socdo.vn/danh-muc/' . $child['cat_id'] . '/' . $child['cat_blank'] . '.html'
                        );
                    }
                }
                $category_data['children'] = $children;
                $category_data['children_count'] = count($children);
            } else {
                $category_data['children'] = array();
                $category_data['children_count'] = 0;
            }
            
            // Badges/Flags
            $badges = array();
            if ($category_data['is_featured']) $badges[] = 'Nổi bật';
            if ($category_data['is_trending']) $badges[] = 'Xu hướng';
            if ($category_data['show_on_homepage']) $badges[] = 'Hiển thị trang chủ';
            $category_data['badges'] = $badges;
            
            $categories[] = $category_data;
        }
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách danh mục thành công",
            "data" => [
                "categories" => $categories,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_records" => $total_records,
                    "per_page" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                ],
                "filters" => [
                    "type" => $type,
                    "parent_id" => $parent_id,
                    "include_children" => $include_children,
                    "include_products_count" => $include_products_count
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
