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
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 100;
        $menu_vitri = isset($_GET['menu_vitri']) ? trim($_GET['menu_vitri']) : '';
        $menu_loai = isset($_GET['menu_loai']) ? trim($_GET['menu_loai']) : '';
        $sort = isset($_GET['sort']) ? trim($_GET['sort']) : 'thutu-asc'; // thutu-asc, thutu-desc, id-desc, id-asc
        
        // Validate parameters
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        if ($page < 1) $page = 1;
        if ($limit < 1 || $limit > 500) $limit = 100;
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        
        $offset = ($page - 1) * $limit;
        
        // Xây dựng WHERE clause
        $where_conditions = array();
        
        // Lọc theo vị trí menu
        if (!empty($menu_vitri)) {
            $where_conditions[] = "menu_vitri = '" . mysqli_real_escape_string($conn, $menu_vitri) . "'";
        }
        
        // Lọc theo loại menu
        if (!empty($menu_loai)) {
            $where_conditions[] = "menu_loai = '" . mysqli_real_escape_string($conn, $menu_loai) . "'";
        }
        
        $where_clause = !empty($where_conditions) ? "WHERE " . implode(" AND ", $where_conditions) : "";
        
        // Đếm tổng số bài viết
        $count_query = "SELECT COUNT(*) as total FROM menu $where_clause";
        $count_result = mysqli_query($conn, $count_query);
        $total_records = 0;
        if ($count_result) {
            $count_row = mysqli_fetch_assoc($count_result);
            $total_records = $count_row['total'];
        }
        
        $total_pages = ceil($total_records / $limit);
        
        // Xử lý sắp xếp
        $allowed_sorts = ['thutu-asc', 'thutu-desc', 'id-desc', 'id-asc'];
        $sort = in_array($sort, $allowed_sorts) ? $sort : 'thutu-asc';
        
        switch ($sort) {
            case 'thutu-asc':
                $order_by = "ORDER BY menu_thutu ASC, menu_id ASC";
                break;
            case 'thutu-desc':
                $order_by = "ORDER BY menu_thutu DESC, menu_id DESC";
                break;
            case 'id-desc':
                $order_by = "ORDER BY menu_id DESC";
                break;
            case 'id-asc':
                $order_by = "ORDER BY menu_id ASC";
                break;
            default:
                $order_by = "ORDER BY menu_thutu ASC, menu_id ASC";
        }
        
        // Lấy danh sách bài viết trong menu
        $menu_query = "
            SELECT 
                menu_id,
                menu_main,
                menu_tieude,
                menu_cat,
                menu_link,
                menu_target,
                menu_thutu,
                menu_loai,
                menu_vitri
            FROM menu 
            $where_clause 
            $order_by 
            LIMIT $offset, $limit
        ";
        
        $menu_result = mysqli_query($conn, $menu_query);
        
        if (!$menu_result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database"
            ]);
            exit;
        }
        
        $articles = array();
        
        while ($menu_item = mysqli_fetch_assoc($menu_result)) {
            // Format dữ liệu bài viết
            $article_data = array();
            $article_data['id'] = intval($menu_item['menu_id']);
            $article_data['title'] = $menu_item['menu_tieude'];
            $article_data['link'] = $menu_item['menu_link'];
            $article_data['target'] = $menu_item['menu_target'];
            $article_data['order'] = intval($menu_item['menu_thutu']);
            $article_data['type'] = $menu_item['menu_loai'];
            $article_data['position'] = $menu_item['menu_vitri'];
            $article_data['parent_id'] = intval($menu_item['menu_main']);
            $article_data['category_id'] = intval($menu_item['menu_cat']);
            
            // Tạo URL đầy đủ nếu link là relative
            if (!empty($article_data['link'])) {
                if (strpos($article_data['link'], 'http') === 0) {
                    $article_data['full_url'] = $article_data['link'];
                } else {
                    $article_data['full_url'] = 'https://socdo.vn' . $article_data['link'];
                }
            } else {
                $article_data['full_url'] = '';
            }
            
            // Xác định target type
            $target_type = 'same_window';
            if ($article_data['target'] == '_blank' || $article_data['target'] == '2') {
                $target_type = 'new_window';
            } elseif ($article_data['target'] == '1') {
                $target_type = 'same_window';
            }
            $article_data['target_type'] = $target_type;
            
            // Thông tin bổ sung
            $article_data['is_external'] = false;
            if (strpos($article_data['link'], 'http') === 0 && strpos($article_data['link'], 'socdo.vn') === false) {
                $article_data['is_external'] = true;
            }
            
            // Metadata
            $article_data['created_at'] = null; // Bảng menu không có trường thời gian
            $article_data['updated_at'] = null;
            
            $articles[] = $article_data;
        }
        
        // Lấy thống kê theo vị trí và loại
        $stats_query = "
            SELECT 
                menu_vitri,
                menu_loai,
                COUNT(*) as count
            FROM menu 
            GROUP BY menu_vitri, menu_loai
            ORDER BY menu_vitri, menu_loai
        ";
        
        $stats_result = mysqli_query($conn, $stats_query);
        $statistics = array();
        
        if ($stats_result) {
            while ($stat = mysqli_fetch_assoc($stats_result)) {
                $statistics[] = [
                    'position' => $stat['menu_vitri'],
                    'type' => $stat['menu_loai'],
                    'count' => intval($stat['count'])
                ];
            }
        }
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách bài viết menu thành công",
            "data" => [
                "articles" => $articles,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_records" => $total_records,
                    "per_page" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                ],
                "statistics" => $statistics,
                "filters" => [
                    "menu_vitri" => $menu_vitri,
                    "menu_loai" => $menu_loai,
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
