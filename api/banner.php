<?php
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
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
        // Lấy danh sách banner hoặc chi tiết banner
        $banner_id = isset($_GET['banner_id']) ? intval($_GET['banner_id']) : 0;
        
        if ($banner_id > 0) {
            // Lấy chi tiết banner
            $query = "SELECT * FROM banner WHERE id = $banner_id LIMIT 1";
            $result = mysqli_query($conn, $query);
            
            if (!$result || mysqli_num_rows($result) == 0) {
                http_response_code(404);
                echo json_encode([
                    "success" => false,
                    "message" => "Không tìm thấy banner"
                ]);
                exit;
            }
            
            $banner = mysqli_fetch_assoc($result);
            
            // Xử lý đường dẫn hình ảnh
            if (!empty($banner['minh_hoa']) && file_exists($banner['minh_hoa'])) {
                $banner['image_url'] = 'https://socdo.vn/' . $banner['minh_hoa'];
            } else {
                $banner['image_url'] = '';
            }
            
            // Xử lý background banner
            if (!empty($banner['bg_banner']) && file_exists($banner['bg_banner'])) {
                $banner['bg_url'] = 'https://socdo.vn/' . $banner['bg_banner'];
            } else {
                $banner['bg_url'] = '';
            }
            
            $response = [
                "success" => true,
                "message" => "Lấy chi tiết banner thành công",
                "data" => $banner
            ];
            
        } else {
            // Lấy danh sách banner
            $vi_tri = isset($_GET['vi_tri']) ? addslashes($_GET['vi_tri']) : '';
            $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : -1;
            $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
            $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
            
            // Validate parameters
            $get_all = isset($_GET['all']) && $_GET['all'] == '1';
            
            if ($limit > 500) $limit = 500;
            if ($limit < 1) $limit = 50;
            if ($page < 1) $page = 1;
            
            // Override limit nếu get_all = true
            if ($get_all) {
                $limit = 999999;
                $page = 1;
            }
            
            $start = ($page - 1) * $limit;
            
            // Xây dựng điều kiện WHERE
            $where_conditions = array();
            
            if (!empty($vi_tri)) {
                $where_conditions[] = "vi_tri = '$vi_tri'";
            }
            
            if ($shop_id >= 0) {
                $where_conditions[] = "shop_id = $shop_id";
            }
            
            $where_clause = !empty($where_conditions) ? 'WHERE ' . implode(' AND ', $where_conditions) : '';
            
            // Đếm tổng số banner
            $count_query = "SELECT COUNT(*) as total FROM banner $where_clause";
            $count_result = mysqli_query($conn, $count_query);
            $total_banners = mysqli_fetch_assoc($count_result)['total'];
            
            // Lấy danh sách banner
            $query = "SELECT * FROM banner $where_clause ORDER BY thu_tu ASC, id DESC LIMIT $start, $limit";
            $result = mysqli_query($conn, $query);
            
            if (!$result) {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
                ]);
                exit;
            }
            
            $banners = array();
            while ($row = mysqli_fetch_assoc($result)) {
                // Xử lý đường dẫn hình ảnh
                if (!empty($row['minh_hoa']) && file_exists($row['minh_hoa'])) {
                    $row['image_url'] = 'https://socdo.vn/' . $row['minh_hoa'];
                } else {
                    $row['image_url'] = '';
                }
                
                // Xử lý background banner
                if (!empty($row['bg_banner']) && file_exists($row['bg_banner'])) {
                    $row['bg_url'] = 'https://socdo.vn/' . $row['bg_banner'];
                } else {
                    $row['bg_url'] = '';
                }
                
                $banners[] = $row;
            }
            
            // Tính toán thông tin phân trang
            $total_pages = ceil($total_banners / $limit);
            
            $response = [
                "success" => true,
                "message" => "Lấy danh sách banner thành công",
                "data" => [
                    "banners" => $banners,
                    "pagination" => [
                        "current_page" => $page,
                        "total_pages" => $total_pages,
                        "total_banners" => $total_banners,
                        "limit" => $limit,
                        "has_next" => $page < $total_pages,
                        "has_prev" => $page > 1
                    ],
                    "filters" => [
                        "vi_tri" => $vi_tri,
                        "shop_id" => $shop_id
                    ]
                ]
            ];
        }
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
    } elseif ($method === 'POST') {
        // Tạo banner mới
        $data = json_decode(file_get_contents("php://input"), true);
        
        // Validate required fields
        $required_fields = ['tieu_de', 'minh_hoa', 'vi_tri'];
        foreach ($required_fields as $field) {
            if (empty($data[$field])) {
                http_response_code(400);
                echo json_encode([
                    "success" => false,
                    "message" => "Thiếu trường bắt buộc: $field"
                ]);
                exit;
            }
        }
        
        $tieu_de = addslashes(strip_tags($data['tieu_de']));
        $minh_hoa = addslashes($data['minh_hoa']);
        $link = isset($data['link']) ? addslashes($data['link']) : '';
        $bg_banner = isset($data['bg_banner']) ? addslashes($data['bg_banner']) : '';
        $target = isset($data['target']) ? addslashes($data['target']) : '_self';
        $thu_tu = isset($data['thu_tu']) ? intval($data['thu_tu']) : 0;
        $vi_tri = addslashes($data['vi_tri']);
        $shop_id = isset($data['shop_id']) ? intval($data['shop_id']) : 0;
        
        // Insert vào database
        $insert_query = "INSERT INTO banner (tieu_de, minh_hoa, link, bg_banner, target, thu_tu, vi_tri, shop_id) 
                        VALUES ('$tieu_de', '$minh_hoa', '$link', '$bg_banner', '$target', '$thu_tu', '$vi_tri', '$shop_id')";
        
        $result = mysqli_query($conn, $insert_query);
        
        if ($result) {
            $banner_id = mysqli_insert_id($conn);
            
            // Xử lý đường dẫn hình ảnh cho response
            $image_url = '';
            if (!empty($minh_hoa) && file_exists($minh_hoa)) {
                $image_url = 'https://socdo.vn/' . $minh_hoa;
            }
            
            $bg_url = '';
            if (!empty($bg_banner) && file_exists($bg_banner)) {
                $bg_url = 'https://socdo.vn/' . $bg_banner;
            }
            
            http_response_code(201);
            echo json_encode([
                "success" => true,
                "message" => "Tạo banner thành công",
                "data" => [
                    "banner_id" => $banner_id,
                    "tieu_de" => $data['tieu_de'],
                    "vi_tri" => $vi_tri,
                    "thu_tu" => $thu_tu,
                    "image_url" => $image_url,
                    "bg_url" => $bg_url
                ]
            ]);
        } else {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi tạo banner: " . mysqli_error($conn)
            ]);
        }
        
    } elseif ($method === 'PUT') {
        // Cập nhật banner
        $data = json_decode(file_get_contents("php://input"), true);
        
        if (!isset($data['banner_id'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu banner_id"
            ]);
            exit;
        }
        
        $banner_id = intval($data['banner_id']);
        
        // Kiểm tra banner có tồn tại không
        $check_query = "SELECT id FROM banner WHERE id = $banner_id LIMIT 1";
        $check_result = mysqli_query($conn, $check_query);
        
        if (!$check_result || mysqli_num_rows($check_result) == 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Không tìm thấy banner"
            ]);
            exit;
        }
        
        // Xây dựng câu lệnh UPDATE
        $update_fields = array();
        
        if (isset($data['tieu_de'])) {
            $tieu_de = addslashes(strip_tags($data['tieu_de']));
            $update_fields[] = "tieu_de = '$tieu_de'";
        }
        
        if (isset($data['minh_hoa'])) {
            $minh_hoa = addslashes($data['minh_hoa']);
            $update_fields[] = "minh_hoa = '$minh_hoa'";
        }
        
        if (isset($data['link'])) {
            $link = addslashes($data['link']);
            $update_fields[] = "link = '$link'";
        }
        
        if (isset($data['bg_banner'])) {
            $bg_banner = addslashes($data['bg_banner']);
            $update_fields[] = "bg_banner = '$bg_banner'";
        }
        
        if (isset($data['target'])) {
            $target = addslashes($data['target']);
            $update_fields[] = "target = '$target'";
        }
        
        if (isset($data['thu_tu'])) {
            $thu_tu = intval($data['thu_tu']);
            $update_fields[] = "thu_tu = $thu_tu";
        }
        
        if (isset($data['vi_tri'])) {
            $vi_tri = addslashes($data['vi_tri']);
            $update_fields[] = "vi_tri = '$vi_tri'";
        }
        
        if (isset($data['shop_id'])) {
            $shop_id = intval($data['shop_id']);
            $update_fields[] = "shop_id = $shop_id";
        }
        
        if (empty($update_fields)) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Không có trường nào để cập nhật"
            ]);
            exit;
        }
        
        $update_query = "UPDATE banner SET " . implode(', ', $update_fields) . " WHERE id = $banner_id";
        $result = mysqli_query($conn, $update_query);
        
        if ($result) {
            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => "Cập nhật banner thành công",
                "data" => [
                    "banner_id" => $banner_id,
                    "updated_fields" => count($update_fields)
                ]
            ]);
        } else {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi cập nhật banner: " . mysqli_error($conn)
            ]);
        }
        
    } elseif ($method === 'DELETE') {
        // Xóa banner
        $data = json_decode(file_get_contents("php://input"), true);
        
        if (!isset($data['banner_id'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu banner_id"
            ]);
            exit;
        }
        
        $banner_id = intval($data['banner_id']);
        
        // Kiểm tra banner có tồn tại không
        $check_query = "SELECT id, minh_hoa, bg_banner FROM banner WHERE id = $banner_id LIMIT 1";
        $check_result = mysqli_query($conn, $check_query);
        
        if (!$check_result || mysqli_num_rows($check_result) == 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Không tìm thấy banner"
            ]);
            exit;
        }
        
        $banner_info = mysqli_fetch_assoc($check_result);
        
        // Xóa banner khỏi database
        $delete_query = "DELETE FROM banner WHERE id = $banner_id";
        $result = mysqli_query($conn, $delete_query);
        
        if ($result) {
            // Xóa file ảnh (tùy chọn - có thể bỏ comment nếu muốn xóa file)
            /*
            if (!empty($banner_info['minh_hoa']) && file_exists($banner_info['minh_hoa'])) {
                unlink($banner_info['minh_hoa']);
            }
            if (!empty($banner_info['bg_banner']) && file_exists($banner_info['bg_banner'])) {
                unlink($banner_info['bg_banner']);
            }
            */
            
            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => "Xóa banner thành công",
                "data" => [
                    "banner_id" => $banner_id
                ]
            ]);
        } else {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi xóa banner: " . mysqli_error($conn)
            ]);
        }
        
    } else {
        http_response_code(405);
        echo json_encode([
            "success" => false,
            "message" => "Phương thức không được hỗ trợ"
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
