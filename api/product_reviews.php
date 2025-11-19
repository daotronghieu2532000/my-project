<?php
header("Access-Control-Allow-Methods: GET, POST, PUT, PATCH");
header('Content-Type: application/json; charset=utf-8');
require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
    $config_path = '../../../../../includes/config.php';
}
require_once $config_path;
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

// Lấy token từ header Authorization
$headers = function_exists('apache_request_headers') ? apache_request_headers() : [];
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$jwt = null;
if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    $jwt = $matches[1];
}

$method = $_SERVER['REQUEST_METHOD'];

try {
    // Giải mã JWT nếu có
    $decoded = null;
    $jwt_user_id = 0;
    if ($jwt) {
        try {
            $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
            if ($decoded->iss !== $issuer) {
                throw new Exception("Issuer không hợp lệ");
            }
            $jwt_user_id = isset($decoded->user_id) ? intval($decoded->user_id) : 0;
        } catch (Exception $e) {
            // JWT không hợp lệ, nhưng vẫn cho phép GET requests không cần auth
            if ($method !== 'GET') {
                http_response_code(401);
                echo json_encode(array("success" => false, "message" => "Token không hợp lệ"));
                exit;
            }
        }
    }
    
    if ($method === 'POST') {
        // Submit đánh giá sản phẩm
        if (!$jwt || !$decoded) {
            http_response_code(401);
            echo json_encode(array("success" => false, "message" => "Yêu cầu đăng nhập"));
            exit;
        }
        
        // Lấy dữ liệu từ POST (MultipartFormData) hoặc JSON
        $data = array();
        if (!empty($_POST)) {
            $data = $_POST;
        } else {
            $raw_input = file_get_contents("php://input");
            $json_data = json_decode($raw_input, true);
            if ($json_data) {
                $data = $json_data;
            }
        }
        
        // Validate required fields
        $user_id = isset($data['user_id']) ? intval($data['user_id']) : $jwt_user_id;
        $product_id = isset($data['product_id']) ? intval($data['product_id']) : 0;
        $shop_id = isset($data['shop_id']) ? intval($data['shop_id']) : 0;
        $content = isset($data['content']) ? trim($data['content']) : '';
        $rating = isset($data['rating']) ? intval($data['rating']) : 0;
        $variant_id = isset($data['variant_id']) && intval($data['variant_id']) > 0 ? intval($data['variant_id']) : null;
        
        $order_id = isset($data['order_id']) ? intval($data['order_id']) : null;
        $images = isset($data['images']) ? $data['images'] : null;
        $delivery_rating = isset($data['delivery_rating']) ? intval($data['delivery_rating']) : null;
        $shop_rating = isset($data['shop_rating']) ? intval($data['shop_rating']) : null;
        $matches_description = isset($data['matches_description']) ? intval($data['matches_description']) : null;
        $is_satisfied = isset($data['is_satisfied']) ? intval($data['is_satisfied']) : null;
        $will_buy_again = isset($data['will_buy_again']) ? trim($data['will_buy_again']) : null;
        
        // Lấy thông tin sản phẩm từ bảng sanpham
        $product_info = null;
        $shop_name = '';
        $product_query = "SELECT s.id, s.tieu_de, s.minh_hoa, s.shop, u.name as shop_name 
                         FROM sanpham s 
                         LEFT JOIN user_info u ON s.shop = u.user_id 
                         WHERE s.id = $product_id LIMIT 1";
        $product_result = mysqli_query($conn, $product_query);
        if ($product_result && mysqli_num_rows($product_result) > 0) {
            $product_info = mysqli_fetch_assoc($product_result);
            // Nếu shop_id chưa có, lấy từ sản phẩm
            if ($shop_id <= 0) {
                $shop_id = intval($product_info['shop']);
            }
            // Lấy tên shop
            $shop_name = $product_info['shop_name'] ?? '';
        }
        
        // Lấy variant_id và thông tin biến thể từ donhang.sanpham nếu có order_id
        $variant_info = null;
        if ($order_id > 0) {
            $order_check = mysqli_query($conn, "SELECT sanpham FROM donhang WHERE id = $order_id AND user_id = $user_id LIMIT 1");
            if ($order_check && mysqli_num_rows($order_check) > 0) {
                $order_info = mysqli_fetch_assoc($order_check);
                $order_products_json = $order_info['sanpham'];
                if (!empty($order_products_json)) {
                    $order_products = json_decode($order_products_json, true);
                    if (is_array($order_products)) {
                        foreach ($order_products as $key => $item) {
                            // Parse product_id và variant_id từ key hoặc từ item
                            $item_product_id = 0;
                            $item_pl = 0;
                            
                            // Case 1: Object with key like "4215_0" (string with underscore)
                            if (is_string($key) && strpos($key, '_') !== false) {
                                $parts = explode('_', $key);
                                $item_product_id = intval($parts[0]);
                                $item_pl = intval($parts[1]);
                            }
                            // Case 2: Array with 'id' field (newest format)
                            elseif (isset($item['id'])) {
                                $item_product_id = intval($item['id']);
                                $item_pl = intval($item['pl'] ?? $item['variant_id'] ?? 0);
                            }
                            // Case 3: Object with product_id as key (oldest format)
                            elseif (is_int($key) || (is_string($key) && ctype_digit($key))) {
                                $item_product_id = intval($key);
                                $item_pl = 0;
                            }
                            
                            if ($item_product_id == $product_id) {
                                // Lấy variant_id từ item (ưu tiên từ key, sau đó từ item fields)
                                if (($variant_id === null || $variant_id <= 0)) {
                                    // Ưu tiên lấy từ key (pl)
                                    if ($item_pl > 0) {
                                        $variant_id = $item_pl;
                                    }
                                    // Sau đó thử các field khác
                                    elseif (isset($item['variant_id']) && intval($item['variant_id']) > 0) {
                                        $variant_id = intval($item['variant_id']);
                                    } elseif (isset($item['pl']) && intval($item['pl']) > 0) {
                                        $variant_id = intval($item['pl']);
                                    } elseif (isset($item['variant']) && intval($item['variant']) > 0) {
                                        $variant_id = intval($item['variant']);
                                    } elseif (isset($item['biến thể']) && intval($item['biến thể']) > 0) {
                                        $variant_id = intval($item['biến thể']);
                                    } else {
                                        // Nếu không tìm thấy variant_id từ các field, thử lấy từ tieu_de
                                        $tieu_de = $item['tieu_de'] ?? '';
                                        if (!empty($tieu_de) && strpos($tieu_de, ' - ') !== false) {
                                            $parts = explode(' - ', $tieu_de);
                                            if (count($parts) > 1) {
                                                $variant_name_from_title = trim(end($parts)); // Lấy phần cuối cùng sau dấu " - "
                                                
                                                // Tìm variant_id trong bảng phanloai_sanpham dựa trên tên biến thể
                                                if (!empty($variant_name_from_title)) {
                                                    $variant_search_query = "SELECT id FROM phanloai_sanpham 
                                                                             WHERE sp_id = $product_id 
                                                                             AND (ten_color LIKE '%" . mysqli_real_escape_string($conn, $variant_name_from_title) . "%' 
                                                                                  OR ten_size LIKE '%" . mysqli_real_escape_string($conn, $variant_name_from_title) . "%'
                                                                                  OR CONCAT(ten_color, ' ', ten_size) LIKE '%" . mysqli_real_escape_string($conn, $variant_name_from_title) . "%')
                                                                             LIMIT 1";
                                                    $variant_search_result = mysqli_query($conn, $variant_search_query);
                                                    if ($variant_search_result && mysqli_num_rows($variant_search_result) > 0) {
                                                        $variant_search_row = mysqli_fetch_assoc($variant_search_result);
                                                        $variant_id = intval($variant_search_row['id']);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Lấy thông tin biến thể từ đơn hàng
                                $tieu_de = $item['tieu_de'] ?? '';
                                $variant_name = '';
                                
                                // Extract biến thể từ tieu_de (phần sau dấu "-" cuối cùng)
                                // Ví dụ: "Máy nướng kẹp bánh mì 3 in 1 Elmich SME-8578 2 màu lựa chọn - Be"
                                // Biến thể là "Be"
                                if (!empty($tieu_de) && strpos($tieu_de, ' - ') !== false) {
                                    $parts = explode(' - ', $tieu_de);
                                    if (count($parts) > 1) {
                                        $variant_name = trim(end($parts)); // Lấy phần cuối cùng sau dấu " - "
                                    }
                                }
                                
                                // Nếu không tìm thấy biến thể từ tieu_de, thử lấy từ color/size
                                if (empty($variant_name)) {
                                    $variant_parts = array();
                                    if (!empty($item['color'])) {
                                        $variant_parts[] = $item['color'];
                                    }
                                    if (!empty($item['size'])) {
                                        $variant_parts[] = $item['size'];
                                    }
                                    if (!empty($variant_parts)) {
                                        $variant_name = implode(' - ', $variant_parts);
                                    }
                                }
                                
                                $variant_info = array(
                                    'name' => $variant_name,
                                    'full_name' => $tieu_de, // Tên đầy đủ
                                    'image' => $item['anh_chinh'] ?? '',
                                    'color' => $item['color'] ?? '',
                                    'size' => $item['size'] ?? '',
                                );
                                break;
                            }
                        }
                    } else {
                        $debug_info['order_products_not_array'] = true;
                    }
                } else {
                    $debug_info['order_products_json_empty'] = true;
                }
            } else {
                $debug_info['order_check_failed'] = true;
            }
        } else {
            $debug_info['no_order_id'] = true;
        }
        
        // Nếu chưa có thông tin biến thể từ đơn hàng và có variant_id, lấy từ bảng phanloai_sanpham
        if ($variant_info === null && $variant_id > 0) {
            $variant_query = "SELECT id, sp_id, ten_color, ten_size, image_phanloai, color, size 
                            FROM phanloai_sanpham 
                            WHERE id = $variant_id AND sp_id = $product_id LIMIT 1";
            $variant_result = mysqli_query($conn, $variant_query);
            if ($variant_result && mysqli_num_rows($variant_result) > 0) {
                $variant_row = mysqli_fetch_assoc($variant_result);
                $variant_info = array(
                    'name' => trim(($variant_row['ten_color'] ?? '') . ' ' . ($variant_row['ten_size'] ?? '')),
                    'image' => $variant_row['image_phanloai'] ?? '',
                    'color' => $variant_row['color'] ?? '',
                    'size' => $variant_row['size'] ?? '',
                );
            }
        }
        
        // Validate
        if ($user_id <= 0) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Thiếu user_id"));
            exit;
        }
        
        if ($product_id <= 0) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Thiếu product_id"));
            exit;
        }
        
        if (empty($content)) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Vui lòng nhập nội dung đánh giá"));
            exit;
        }
        
        if ($rating < 1 || $rating > 5) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Đánh giá phải từ 1 đến 5 sao"));
            exit;
        }
        
        // Kiểm tra sản phẩm có tồn tại không (đã lấy ở trên)
        if (!$product_info) {
            http_response_code(404);
            echo json_encode(array("success" => false, "message" => "Không tìm thấy sản phẩm"));
            exit;
        }
        
        // Kiểm tra user đã mua sản phẩm này chưa (nếu có order_id)
        $is_verified_purchase = 0;
        if ($order_id > 0) {
            // Kiểm tra đơn hàng có chứa sản phẩm này không
            $order_check = mysqli_query($conn, "SELECT id, user_id, status, sanpham FROM donhang WHERE id = $order_id AND user_id = $user_id LIMIT 1");
            if ($order_check && mysqli_num_rows($order_check) > 0) {
                $order_info = mysqli_fetch_assoc($order_check);
                $order_products_json = $order_info['sanpham'];
                if (!empty($order_products_json)) {
                    $order_products = json_decode($order_products_json, true);
                    if (is_array($order_products)) {
                        foreach ($order_products as $item) {
                            $item_product_id = intval($item['id'] ?? $item['product_id'] ?? 0);
                            if ($item_product_id == $product_id) {
                                $is_verified_purchase = 1;
                                break;
                            }
                        }
                    }
                }
            }
        } else {
            // Nếu không có order_id, kiểm tra xem user có đơn hàng nào chứa sản phẩm này với status = 5 (Giao thành công)
            $order_check = mysqli_query($conn, "SELECT id, sanpham FROM donhang WHERE user_id = $user_id AND status = 5 LIMIT 50");
            if ($order_check && mysqli_num_rows($order_check) > 0) {
                while ($order_row = mysqli_fetch_assoc($order_check)) {
                    $order_products_json = $order_row['sanpham'];
                    if (!empty($order_products_json)) {
                        $order_products = json_decode($order_products_json, true);
                        if (is_array($order_products)) {
                            foreach ($order_products as $item) {
                                $item_product_id = intval($item['id'] ?? $item['product_id'] ?? 0);
                                if ($item_product_id == $product_id) {
                                    $is_verified_purchase = 1;
                                    break 2; // Break cả 2 vòng lặp
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Kiểm tra user đã đánh giá sản phẩm này chưa (trong cùng đơn hàng nếu có)
        $existing_review_query = "SELECT id FROM product_comments WHERE user_id = $user_id AND product_id = $product_id";
        if ($order_id > 0) {
            $existing_review_query .= " AND order_id = $order_id";
        }
        $existing_review_query .= " LIMIT 1";
        
        $existing_review = mysqli_query($conn, $existing_review_query);
        if ($existing_review && mysqli_num_rows($existing_review) > 0) {
            http_response_code(409);
            echo json_encode(array("success" => false, "message" => "Bạn đã đánh giá sản phẩm này rồi"));
            exit;
        }
        
        // Xử lý images (base64 hoặc JSON array)
        $uploaded_images = array();
        if ($images) {
            $image_array = array();
            if (is_string($images)) {
                // Có thể là JSON string hoặc base64 string
                $decoded_images = json_decode($images, true);
                if (json_last_error() === JSON_ERROR_NONE && is_array($decoded_images)) {
                    $image_array = $decoded_images;
                } else {
                    // Base64 string đơn lẻ
                    $image_array = array($images);
                }
            } elseif (is_array($images)) {
                $image_array = $images;
            }
            
            // Xử lý từng ảnh
            foreach ($image_array as $img) {
                if (is_string($img)) {
                    // Nếu là base64 (bắt đầu với data:image/)
                    if (strpos($img, 'data:image/') === 0) {
                        // Decode base64 và lưu file
                        $base64_data = explode(',', $img);
                        if (count($base64_data) === 2) {
                            $image_data = base64_decode($base64_data[1]);
                            if ($image_data !== false) {
                                // Tạo tên file
                                $timestamp = time();
                                $random = rand(1000, 9999);
                                $filename = "comment_{$user_id}_{$timestamp}_{$random}.jpg";
                                
                                // Tạo thư mục nếu chưa có
                                $upload_dir = '/home/socdo.vn/public_html/uploads/comments/';
                                if (!is_dir($upload_dir)) {
                                    mkdir($upload_dir, 0755, true);
                                }
                                
                                $file_path = $upload_dir . $filename;
                                
                                // Lưu file
                                if (file_put_contents($file_path, $image_data)) {
                                    $uploaded_images[] = "/uploads/comments/$filename";
                                }
                            }
                        }
                    } elseif (strpos($img, '/uploads/') === 0 || strpos($img, 'http') === 0) {
                        // Đã là đường dẫn file, giữ nguyên
                        $uploaded_images[] = $img;
                    }
                }
            }
        }
        
        $images_json = !empty($uploaded_images) ? json_encode($uploaded_images, JSON_UNESCAPED_UNICODE) : null;
        
        // Escape content
        $content_escaped = mysqli_real_escape_string($conn, $content);
        
        // Insert vào product_comments
        $variant_id_sql = ($variant_id > 0) ? $variant_id : 'NULL';
        $order_id_sql = ($order_id > 0) ? $order_id : 'NULL';
        $images_sql = $images_json ? "'" . mysqli_real_escape_string($conn, $images_json) . "'" : 'NULL';
        $delivery_rating_sql = ($delivery_rating !== null && $delivery_rating >= 1 && $delivery_rating <= 5) ? $delivery_rating : 'NULL';
        $shop_rating_sql = ($shop_rating !== null && $shop_rating >= 1 && $shop_rating <= 5) ? $shop_rating : 'NULL';
        $matches_description_sql = ($matches_description !== null) ? ($matches_description ? 1 : 0) : 'NULL';
        $is_satisfied_sql = ($is_satisfied !== null) ? ($is_satisfied ? 1 : 0) : 'NULL';
        $will_buy_again_sql = ($will_buy_again !== null && in_array($will_buy_again, ['yes', 'no', 'maybe'])) ? "'" . mysqli_real_escape_string($conn, $will_buy_again) . "'" : 'NULL';
        
        $insert_query = "INSERT INTO product_comments (
            product_id, variant_id, user_id, shop_id, parent_id, content, rating, delivery_rating, shop_rating,
            matches_description, is_satisfied, will_buy_again, images, 
            is_verified_purchase, order_id, status, created_at
        ) VALUES (
            $product_id, $variant_id_sql, $user_id, $shop_id, 0, '$content_escaped', $rating, 
            $delivery_rating_sql, $shop_rating_sql, $matches_description_sql, $is_satisfied_sql, $will_buy_again_sql,
            $images_sql, $is_verified_purchase, $order_id_sql, 'approved', NOW()
        )";
        
        $insert_result = mysqli_query($conn, $insert_query);
        
        if (!$insert_result) {
            http_response_code(500);
            echo json_encode(array(
                "success" => false,
                "message" => "Lỗi thêm đánh giá: " . mysqli_error($conn)
            ));
            exit;
        }
        
        $comment_id = mysqli_insert_id($conn);
        
        // Cập nhật thống kê đánh giá trong product_rating_stats
        _updateRatingStats($conn, $product_id, $shop_id, $rating, 1);
        
        // Response với thông tin sản phẩm và biến thể
        $response_data = array(
            "comment_id" => $comment_id,
            "product_id" => $product_id,
            "user_id" => $user_id,
            "rating" => $rating,
            "is_verified_purchase" => $is_verified_purchase,
        );
        
        // Thêm thông tin sản phẩm
        if ($product_info) {
            $response_data['product_name'] = $product_info['tieu_de'] ?? '';
            $response_data['product_image'] = $product_info['minh_hoa'] ?? '';
        }
        
        // Thêm tên shop
        if (!empty($shop_name)) {
            $response_data['shop_name'] = $shop_name;
        }
        
        // Thêm thông tin biến thể nếu có
        if ($variant_info) {
            $response_data['variant_name'] = $variant_info['name'] ?? '';
            $response_data['variant_image'] = $variant_info['image'] ?? '';
            $response_data['variant_color'] = $variant_info['color'] ?? '';
            $response_data['variant_size'] = $variant_info['size'] ?? '';
        }
        
        if ($variant_id > 0) {
            $response_data['variant_id'] = $variant_id;
        }
        
        http_response_code(201);
        echo json_encode(array(
            "success" => true,
            "message" => "Đánh giá thành công",
            "data" => $response_data
        ));
        
    } elseif ($method === 'GET') {
        // Lấy danh sách đánh giá sản phẩm hoặc lịch sử đánh giá của user
        $product_id = isset($_GET['product_id']) ? intval($_GET['product_id']) : 0;
        $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 20;
        $rating = isset($_GET['rating']) ? intval($_GET['rating']) : 0; // 0 = all, 1-5 = filter
        $sort = isset($_GET['sort']) ? trim($_GET['sort']) : 'latest'; // latest, oldest, highest, lowest
        $variant_id = isset($_GET['variant_id']) ? intval($_GET['variant_id']) : null;
        $status = isset($_GET['status']) ? trim($_GET['status']) : null; // 'all', 'reviewed', 'pending' - chỉ dùng khi có user_id
        
        // Nếu có user_id và không có product_id -> lấy lịch sử đánh giá của user
        if ($user_id > 0 && $product_id <= 0) {
            // Lấy lịch sử đánh giá của user từ đơn hàng
            _getUserReviewHistory($conn, $user_id, $page, $limit, $status);
            exit;
        }
        
        // Nếu không có product_id và không có user_id -> lỗi
        if ($product_id <= 0) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Thiếu product_id hoặc user_id"));
            exit;
        }
        
        if ($page < 1) $page = 1;
        if ($limit < 1) $limit = 20;
        if ($limit > 200) $limit = 500; // Tăng max limit từ 100 lên 200
        
        $start = ($page - 1) * $limit;
        
        // Build WHERE clause cơ bản (không có filter) để tính total_reviews và average_rating
        $base_where_clause = "product_comments.product_id = $product_id AND product_comments.parent_id = 0 AND product_comments.status = 'approved'";
        
        // Đếm tổng số đánh giá và tính điểm trung bình (KHÔNG áp dụng filter)
        $count_query = "SELECT 
            COUNT(*) as total, 
            AVG(rating) as avg_rating,
            SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
            SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
            SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
            SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
            SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
            FROM product_comments WHERE $base_where_clause";
        $count_result = mysqli_query($conn, $count_query);
        $total_reviews = 0;
        $average_rating = 0.0;
        $rating_5_count = 0;
        $rating_4_count = 0;
        $rating_3_count = 0;
        $rating_2_count = 0;
        $rating_1_count = 0;
        if ($count_result) {
            $count_row = mysqli_fetch_assoc($count_result);
            $total_reviews = intval($count_row['total']);
            $average_rating = $count_row['avg_rating'] ? round(floatval($count_row['avg_rating']), 2) : 0.0;
            $rating_5_count = intval($count_row['rating_5'] ?? 0);
            $rating_4_count = intval($count_row['rating_4'] ?? 0);
            $rating_3_count = intval($count_row['rating_3'] ?? 0);
            $rating_2_count = intval($count_row['rating_2'] ?? 0);
            $rating_1_count = intval($count_row['rating_1'] ?? 0);
        }
        
        // Nếu không có đánh giá, thử lấy từ product_rating_stats (lấy tổng của tất cả shop cho product này)
        if ($total_reviews == 0) {
            $stats_query = "SELECT 
                SUM(total_reviews) as total_reviews, 
                AVG(average_rating) as average_rating,
                SUM(rating_5) as rating_5,
                SUM(rating_4) as rating_4,
                SUM(rating_3) as rating_3,
                SUM(rating_2) as rating_2,
                SUM(rating_1) as rating_1
                FROM product_rating_stats 
                WHERE product_id = $product_id";
            $stats_result = mysqli_query($conn, $stats_query);
            if ($stats_result && mysqli_num_rows($stats_result) > 0) {
                $stats_row = mysqli_fetch_assoc($stats_result);
                $total_reviews = intval($stats_row['total_reviews'] ?? 0);
                $average_rating = $stats_row['average_rating'] ? round(floatval($stats_row['average_rating']), 2) : 0.0;
                $rating_5_count = intval($stats_row['rating_5'] ?? 0);
                $rating_4_count = intval($stats_row['rating_4'] ?? 0);
                $rating_3_count = intval($stats_row['rating_3'] ?? 0);
                $rating_2_count = intval($stats_row['rating_2'] ?? 0);
                $rating_1_count = intval($stats_row['rating_1'] ?? 0);
            }
        }
        
        // Build WHERE clause cho danh sách đánh giá (có áp dụng filter)
        $where_clause = $base_where_clause;
        
        if ($rating > 0 && $rating <= 5) {
            $where_clause .= " AND product_comments.rating = $rating";
        }
        
        if ($variant_id > 0) {
            $where_clause .= " AND (product_comments.variant_id = $variant_id OR product_comments.variant_id IS NULL)";
        }
        
        // Filter by has images
        $has_images = isset($_GET['has_images']) ? intval($_GET['has_images']) : 0;
        if ($has_images == 1) {
            $where_clause .= " AND product_comments.images IS NOT NULL AND product_comments.images != '' AND product_comments.images != '[]'";
        }
        
        // Filter by is_satisfied
        $is_satisfied = isset($_GET['is_satisfied']) ? trim($_GET['is_satisfied']) : '';
        if ($is_satisfied === '1') {
            $where_clause .= " AND product_comments.is_satisfied = 1";
        } elseif ($is_satisfied === '0') {
            $where_clause .= " AND product_comments.is_satisfied = 0";
        }
        
        // Filter by matches_description
        $matches_description = isset($_GET['matches_description']) ? trim($_GET['matches_description']) : '';
        if ($matches_description === '1') {
            $where_clause .= " AND product_comments.matches_description = 1";
        } elseif ($matches_description === '0') {
            $where_clause .= " AND product_comments.matches_description = 0";
        }
        
        // Build ORDER BY clause
        $order_clause = "product_comments.created_at DESC"; // default: latest
        switch ($sort) {
            case 'oldest':
                $order_clause = "product_comments.created_at ASC";
                break;
            case 'highest':
                $order_clause = "product_comments.rating DESC, product_comments.created_at DESC";
                break;
            case 'lowest':
                $order_clause = "product_comments.rating ASC, product_comments.created_at DESC";
                break;
            case 'latest':
            default:
                $order_clause = "product_comments.is_pinned DESC, product_comments.created_at DESC";
                break;
        }
        
        // Lấy danh sách đánh giá
        $query = "SELECT 
            product_comments.id,
            product_comments.product_id,
            product_comments.variant_id,
            product_comments.user_id,
            product_comments.shop_id,
            product_comments.content,
            product_comments.rating,
            product_comments.delivery_rating,
            product_comments.shop_rating,
            product_comments.matches_description,
            product_comments.is_satisfied,
            product_comments.will_buy_again,
            product_comments.images,
            product_comments.is_verified_purchase,
            product_comments.order_id,
            product_comments.likes_count,
            product_comments.dislikes_count,
            product_comments.created_at,
            product_comments.is_pinned,
            user_info.name as user_name,
            user_info.avatar as user_avatar
        FROM product_comments
        LEFT JOIN user_info ON product_comments.user_id = user_info.user_id
        WHERE $where_clause
        ORDER BY $order_clause
        LIMIT $start, $limit";
        
        $result = mysqli_query($conn, $query);
        
        if (!$result) {
            http_response_code(500);
            echo json_encode(array(
                "success" => false,
                "message" => "Lỗi truy vấn: " . mysqli_error($conn)
            ));
            exit;
        }
        
        $reviews = array();
        while ($row = mysqli_fetch_assoc($result)) {
            // Xử lý images
            $images_array = array();
            if (!empty($row['images'])) {
                $decoded_images = json_decode($row['images'], true);
                if (is_array($decoded_images)) {
                    foreach ($decoded_images as $img) {
                        if (is_string($img)) {
                            // Base64 hoặc URL
                            if (strpos($img, 'data:image/') === 0) {
                                // Base64 - giữ nguyên
                                $images_array[] = $img;
                            } elseif (strpos($img, 'http') === 0) {
                                // Full URL
                                $images_array[] = $img;
                            } elseif (strpos($img, '/uploads/') === 0) {
                                // Relative path
                                $images_array[] = 'https://socdo.vn' . $img;
                            } else {
                                $images_array[] = 'https://socdo.vn/' . ltrim($img, '/');
                            }
                        }
                    }
                }
            }
            
            // Xử lý avatar user
            $user_avatar = '';
            if (!empty($row['user_avatar']) && $row['user_avatar'] !== '0') {
                $avatar = trim($row['user_avatar']);
                $avatar = ltrim($avatar, '/');
                $user_avatar = 'https://socdo.vn/' . $avatar;
            }
            
            // Lấy thông tin sản phẩm
            $product_info = null;
            $product_query = "SELECT id, tieu_de, minh_hoa FROM sanpham WHERE id = " . intval($row['product_id']) . " LIMIT 1";
            $product_result = mysqli_query($conn, $product_query);
            if ($product_result && mysqli_num_rows($product_result) > 0) {
                $product_info = mysqli_fetch_assoc($product_result);
            }
            
            // Lấy thông tin biến thể nếu có variant_id
            $variant_info = null;
            if ($row['variant_id']) {
                $variant_id_val = intval($row['variant_id']);
                // Thử lấy từ phanloai_sanpham trước
                $variant_query = "SELECT id, sp_id, ten_color, ten_size, image_phanloai, color, size 
                                FROM phanloai_sanpham 
                                WHERE id = $variant_id_val AND sp_id = " . intval($row['product_id']) . " LIMIT 1";
                $variant_result = mysqli_query($conn, $variant_query);
                if ($variant_result && mysqli_num_rows($variant_result) > 0) {
                    $variant_row = mysqli_fetch_assoc($variant_result);
                    $variant_parts = array();
                    if (!empty($variant_row['ten_color'])) {
                        $variant_parts[] = $variant_row['ten_color'];
                    }
                    if (!empty($variant_row['ten_size'])) {
                        $variant_parts[] = $variant_row['ten_size'];
                    }
                    $variant_name = !empty($variant_parts) ? implode(' - ', $variant_parts) : '';
                    
                    $variant_info = array(
                        'id' => intval($variant_row['id']),
                        'name' => $variant_name,
                        'image' => $variant_row['image_phanloai'] ?? '',
                        'color' => $variant_row['color'] ?? '',
                        'size' => $variant_row['size'] ?? '',
                    );
                }
            }
            
            // Nếu không có từ phanloai_sanpham và có order_id, thử lấy từ donhang.sanpham
            if ($variant_info === null && $row['order_id']) {
                $order_id_val = intval($row['order_id']);
                $order_query = "SELECT sanpham FROM donhang WHERE id = $order_id_val LIMIT 1";
                $order_result = mysqli_query($conn, $order_query);
                if ($order_result && mysqli_num_rows($order_result) > 0) {
                    $order_row = mysqli_fetch_assoc($order_result);
                    $order_products_json = $order_row['sanpham'];
                    if (!empty($order_products_json)) {
                        $order_products = json_decode($order_products_json, true);
                        if (is_array($order_products)) {
                            foreach ($order_products as $item) {
                                $item_product_id = intval($item['id'] ?? $item['product_id'] ?? 0);
                                if ($item_product_id == intval($row['product_id'])) {
                                    $tieu_de = $item['tieu_de'] ?? '';
                                    $variant_name = '';
                                    
                                    // Extract biến thể từ tieu_de
                                    if (!empty($tieu_de) && strpos($tieu_de, ' - ') !== false) {
                                        $parts = explode(' - ', $tieu_de);
                                        if (count($parts) > 1) {
                                            $variant_name = trim(end($parts));
                                        }
                                    }
                                    
                                    if (empty($variant_name)) {
                                        $variant_parts = array();
                                        if (!empty($item['color'])) {
                                            $variant_parts[] = $item['color'];
                                        }
                                        if (!empty($item['size'])) {
                                            $variant_parts[] = $item['size'];
                                        }
                                        if (!empty($variant_parts)) {
                                            $variant_name = implode(' - ', $variant_parts);
                                        }
                                    }
                                    
                                    $variant_info = array(
                                        'id' => $row['variant_id'] ? intval($row['variant_id']) : null,
                                        'name' => $variant_name,
                                        'full_name' => $tieu_de,
                                        'image' => $item['anh_chinh'] ?? '',
                                        'color' => $item['color'] ?? '',
                                        'size' => $item['size'] ?? '',
                                    );
                                    break;
                                }
                            }
                        }
                    }
                }
            }
            
            $reviews[] = array(
                'id' => intval($row['id']),
                'product_id' => intval($row['product_id']),
                'variant_id' => $row['variant_id'] ? intval($row['variant_id']) : null,
                'product_name' => $product_info ? $product_info['tieu_de'] : '',
                'product_image' => $product_info ? $product_info['minh_hoa'] : '',
                'variant' => $variant_info,
                'user_id' => intval($row['user_id']),
                'shop_id' => intval($row['shop_id']),
                'content' => $row['content'],
                'rating' => intval($row['rating']),
                'delivery_rating' => $row['delivery_rating'] ? intval($row['delivery_rating']) : null,
                'shop_rating' => $row['shop_rating'] ? intval($row['shop_rating']) : null,
                'matches_description' => $row['matches_description'] !== null ? (intval($row['matches_description']) === 1) : null,
                'is_satisfied' => $row['is_satisfied'] !== null ? (intval($row['is_satisfied']) === 1) : null,
                'will_buy_again' => $row['will_buy_again'] ?? null,
                'images' => $images_array,
                'is_verified_purchase' => intval($row['is_verified_purchase']) === 1,
                'order_id' => $row['order_id'] ? intval($row['order_id']) : null,
                'likes_count' => intval($row['likes_count']),
                'dislikes_count' => intval($row['dislikes_count']),
                'created_at' => $row['created_at'],
                'created_at_formatted' => date('d/m/Y H:i', strtotime($row['created_at'])),
                'is_pinned' => intval($row['is_pinned']) === 1,
                'user_name' => $row['user_name'] ?? 'Người dùng',
                'user_avatar' => $user_avatar,
            );
        }
        
        // Tính toán phân trang
        $total_pages = ceil($total_reviews / $limit);
        
        http_response_code(200);
        echo json_encode(array(
            "success" => true,
            "message" => "Lấy danh sách đánh giá thành công",
            "data" => array(
                "reviews" => $reviews,
                "total_reviews" => $total_reviews,
                "average_rating" => $average_rating,
                "rating_stats" => array(
                    "rating_5" => $rating_5_count,
                    "rating_4" => $rating_4_count,
                    "rating_3" => $rating_3_count,
                    "rating_2" => $rating_2_count,
                    "rating_1" => $rating_1_count,
                ),
                "pagination" => array(
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_reviews" => $total_reviews,
                    "limit" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                )
            )
        ));
        
    } elseif ($method === 'PUT' || $method === 'PATCH') {
        // Cập nhật đánh giá sản phẩm
        if (!$jwt || !$decoded) {
            http_response_code(401);
            echo json_encode(array("success" => false, "message" => "Yêu cầu đăng nhập"));
            exit;
        }
        
        // Lấy dữ liệu từ PUT/PATCH (JSON)
        $raw_input = file_get_contents("php://input");
        $data = json_decode($raw_input, true);
        
        if (!$data) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Dữ liệu không hợp lệ"));
            exit;
        }
        
        $comment_id = isset($data['comment_id']) ? intval($data['comment_id']) : 0;
        // Lấy user_id từ body trước, nếu không có thì dùng jwt_user_id (giống POST)
        $user_id = isset($data['user_id']) ? intval($data['user_id']) : $jwt_user_id;
        
        if ($comment_id <= 0) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Thiếu comment_id"));
            exit;
        }
        
        // Kiểm tra comment có tồn tại không (không kiểm tra user_id trước)
        $comment_check = mysqli_query($conn, "SELECT id, user_id, product_id, shop_id, variant_id, order_id, rating FROM product_comments WHERE id = $comment_id AND parent_id = 0 LIMIT 1");
        if (!$comment_check || mysqli_num_rows($comment_check) == 0) {
            http_response_code(404);
            echo json_encode(array("success" => false, "message" => "Không tìm thấy đánh giá"));
            exit;
        }
        
        $comment_info = mysqli_fetch_assoc($comment_check);
        $comment_user_id = intval($comment_info['user_id']);
        
        // Kiểm tra quyền sửa (user_id phải khớp)
        if ($comment_user_id != $user_id || $user_id <= 0) {
            http_response_code(404);
            echo json_encode(array("success" => false, "message" => "Không tìm thấy đánh giá hoặc bạn không có quyền sửa"));
            exit;
        }
        
        // $comment_info đã được lấy ở trên
        $product_id = intval($comment_info['product_id']);
        $shop_id = intval($comment_info['shop_id']);
        $old_rating = intval($comment_info['rating'] ?? 5);
        
        // Lấy các trường cần cập nhật
        $content = isset($data['content']) ? trim($data['content']) : null;
        $rating = isset($data['rating']) ? intval($data['rating']) : null;
        $images = isset($data['images']) ? $data['images'] : null;
        $delivery_rating = isset($data['delivery_rating']) ? intval($data['delivery_rating']) : null;
        $shop_rating = isset($data['shop_rating']) ? intval($data['shop_rating']) : null;
        $matches_description = isset($data['matches_description']) ? intval($data['matches_description']) : null;
        $is_satisfied = isset($data['is_satisfied']) ? intval($data['is_satisfied']) : null;
        $will_buy_again = isset($data['will_buy_again']) ? trim($data['will_buy_again']) : null;
        
        // Validate
        if ($content !== null && empty($content)) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Vui lòng nhập nội dung đánh giá"));
            exit;
        }
        
        if ($rating !== null && ($rating < 1 || $rating > 5)) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Đánh giá phải từ 1 đến 5 sao"));
            exit;
        }
        
        // Xử lý images (base64 hoặc JSON array)
        $uploaded_images = null;
        if ($images !== null) {
            $image_array = array();
            if (is_string($images)) {
                $decoded_images = json_decode($images, true);
                if (json_last_error() === JSON_ERROR_NONE && is_array($decoded_images)) {
                    $image_array = $decoded_images;
                } else {
                    $image_array = array($images);
                }
            } elseif (is_array($images)) {
                $image_array = $images;
            }
            
            $uploaded_images = array();
            foreach ($image_array as $img) {
                if (is_string($img)) {
                    if (strpos($img, 'data:image/') === 0) {
                        $base64_data = explode(',', $img);
                        if (count($base64_data) === 2) {
                            $image_data = base64_decode($base64_data[1]);
                            if ($image_data !== false) {
                                $timestamp = time();
                                $random = rand(1000, 9999);
                                $filename = "comment_{$user_id}_{$timestamp}_{$random}.jpg";
                                
                                $upload_dir = '/home/socdo.vn/public_html/uploads/comments/';
                                if (!is_dir($upload_dir)) {
                                    mkdir($upload_dir, 0755, true);
                                }
                                
                                $file_path = $upload_dir . $filename;
                                
                                if (file_put_contents($file_path, $image_data)) {
                                    $uploaded_images[] = "/uploads/comments/$filename";
                                }
                            }
                        }
                    } elseif (strpos($img, '/uploads/') === 0 || strpos($img, 'http') === 0) {
                        $uploaded_images[] = $img;
                    }
                }
            }
        }
        
        // Build UPDATE query
        $update_fields = array();
        
        if ($content !== null) {
            $content_escaped = mysqli_real_escape_string($conn, $content);
            $update_fields[] = "content = '$content_escaped'";
        }
        
        if ($rating !== null) {
            $update_fields[] = "rating = $rating";
        }
        
        if ($uploaded_images !== null) {
            $images_json = !empty($uploaded_images) ? json_encode($uploaded_images, JSON_UNESCAPED_UNICODE) : null;
            $images_sql = $images_json ? "'" . mysqli_real_escape_string($conn, $images_json) . "'" : 'NULL';
            $update_fields[] = "images = $images_sql";
        }
        
        if ($delivery_rating !== null) {
            $delivery_rating_sql = ($delivery_rating >= 1 && $delivery_rating <= 5) ? $delivery_rating : 'NULL';
            $update_fields[] = "delivery_rating = $delivery_rating_sql";
        }
        
        if ($shop_rating !== null) {
            $shop_rating_sql = ($shop_rating >= 1 && $shop_rating <= 5) ? $shop_rating : 'NULL';
            $update_fields[] = "shop_rating = $shop_rating_sql";
        }
        
        if ($matches_description !== null) {
            $matches_description_sql = ($matches_description ? 1 : 0);
            $update_fields[] = "matches_description = $matches_description_sql";
        }
        
        if ($is_satisfied !== null) {
            $is_satisfied_sql = ($is_satisfied ? 1 : 0);
            $update_fields[] = "is_satisfied = $is_satisfied_sql";
        }
        
        if ($will_buy_again !== null && in_array($will_buy_again, ['yes', 'no', 'maybe'])) {
            $will_buy_again_sql = "'" . mysqli_real_escape_string($conn, $will_buy_again) . "'";
            $update_fields[] = "will_buy_again = $will_buy_again_sql";
        }
        
        if (empty($update_fields)) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Không có trường nào để cập nhật"));
            exit;
        }
        
        $update_fields[] = "updated_at = NOW()";
        
        $update_query = "UPDATE product_comments SET " . implode(', ', $update_fields) . " WHERE id = $comment_id AND user_id = $user_id";
        
        $update_result = mysqli_query($conn, $update_query);
        
        if (!$update_result) {
            http_response_code(500);
            echo json_encode(array(
                "success" => false,
                "message" => "Lỗi cập nhật đánh giá: " . mysqli_error($conn)
            ));
            exit;
        }
        
        // Cập nhật thống kê đánh giá nếu rating thay đổi
        if ($rating !== null && $rating != $old_rating) {
            // Giảm rating cũ
            _updateRatingStats($conn, $product_id, $shop_id, $old_rating, -1);
            // Tăng rating mới
            _updateRatingStats($conn, $product_id, $shop_id, $rating, 1);
        }
        
        http_response_code(200);
        echo json_encode(array(
            "success" => true,
            "message" => "Cập nhật đánh giá thành công",
            "data" => array(
                "comment_id" => $comment_id,
                "product_id" => $product_id,
            )
        ));
        
    } else {
        http_response_code(405);
        echo json_encode(array("success" => false, "message" => "Chỉ hỗ trợ phương thức GET, POST, PUT và PATCH"));
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(array(
        "success" => false,
        "message" => "Lỗi hệ thống",
        "error" => $e->getMessage()
    ));
}

// Hàm lấy lịch sử đánh giá của user
function _getUserReviewHistory($conn, $user_id, $page, $limit, $status) {
    if ($page < 1) $page = 1;
    if ($limit < 1) $limit = 20;
    if ($limit > 100) $limit = 100;
    
    $start = ($page - 1) * $limit;
    
    // Lấy tất cả đơn hàng của user có status = 5 (Giao thành công)
    $orders_query = "SELECT id, ma_don, date_post, sanpham FROM donhang WHERE user_id = $user_id AND status = 5 ORDER BY date_post DESC LIMIT 100";
    $orders_result = mysqli_query($conn, $orders_query);
    
    if (!$orders_result) {
        http_response_code(500);
        echo json_encode(array("success" => false, "message" => "Lỗi truy vấn: " . mysqli_error($conn)));
        exit;
    }
    
    $all_reviews = array();
    
    while ($order_row = mysqli_fetch_assoc($orders_result)) {
        $order_id = intval($order_row['id']);
        $ma_don = $order_row['ma_don'];
        $date_post = intval($order_row['date_post']);
        $sanpham_json = $order_row['sanpham'];
        
        if (empty($sanpham_json)) continue;
        
        $products = json_decode($sanpham_json, true);
        if (!is_array($products)) continue;
        
        foreach ($products as $product_item) {
            $product_id = intval($product_item['id'] ?? $product_item['product_id'] ?? 0);
            if ($product_id <= 0) continue;
            
            // Lấy thông tin sản phẩm từ bảng sanpham
            $product_info = null;
            $product_query = "SELECT id, tieu_de, minh_hoa FROM sanpham WHERE id = $product_id LIMIT 1";
            $product_result = mysqli_query($conn, $product_query);
            if ($product_result && mysqli_num_rows($product_result) > 0) {
                $product_info = mysqli_fetch_assoc($product_result);
            }
            
            // Lấy thông tin biến thể từ donhang.sanpham
            $tieu_de = $product_item['tieu_de'] ?? '';
            $variant_name = '';
            
            // Extract biến thể từ tieu_de (phần sau dấu "-" cuối cùng)
            if (!empty($tieu_de) && strpos($tieu_de, ' - ') !== false) {
                $parts = explode(' - ', $tieu_de);
                if (count($parts) > 1) {
                    $variant_name = trim(end($parts)); // Lấy phần cuối cùng sau dấu " - "
                }
            }
            
            // Nếu không tìm thấy biến thể từ tieu_de, thử lấy từ color/size
            if (empty($variant_name)) {
                $variant_parts = array();
                if (!empty($product_item['color'])) {
                    $variant_parts[] = $product_item['color'];
                }
                if (!empty($product_item['size'])) {
                    $variant_parts[] = $product_item['size'];
                }
                if (!empty($variant_parts)) {
                    $variant_name = implode(' - ', $variant_parts);
                }
            }
            
            // Lấy ảnh sản phẩm: ưu tiên anh_chinh từ donhang, nếu không có thì lấy từ sanpham
            $product_image = $product_item['anh_chinh'] ?? $product_item['image'] ?? '';
            if (empty($product_image) && $product_info) {
                $product_image = $product_info['minh_hoa'] ?? '';
            }
            
            // Lấy tên sản phẩm: ưu tiên từ sanpham, nếu không có thì lấy từ donhang
            $product_name = $product_info ? $product_info['tieu_de'] : ($product_item['name'] ?? $tieu_de ?? '');
            
            // Kiểm tra xem user đã đánh giá sản phẩm này chưa
            $review_check = mysqli_query($conn, "SELECT id, content, rating, delivery_rating, shop_rating, matches_description, is_satisfied, will_buy_again, images, is_verified_purchase, created_at FROM product_comments WHERE user_id = $user_id AND product_id = $product_id AND order_id = $order_id AND parent_id = 0 LIMIT 1");
            $has_review = $review_check && mysqli_num_rows($review_check) > 0;
            $review_data = null;
            
            if ($has_review) {
                $review_row = mysqli_fetch_assoc($review_check);
                $images_array = array();
                if (!empty($review_row['images'])) {
                    $decoded_images = json_decode($review_row['images'], true);
                    if (is_array($decoded_images)) {
                        foreach ($decoded_images as $img) {
                            if (is_string($img)) {
                                // Nếu là base64, giữ nguyên (backward compatibility)
                                if (strpos($img, 'data:image/') === 0) {
                                    $images_array[] = $img;
                                } 
                                // Nếu là đường dẫn đầy đủ http/https
                                elseif (strpos($img, 'http') === 0) {
                                    $images_array[] = $img;
                                } 
                                // Nếu là đường dẫn tương đối /uploads/...
                                elseif (strpos($img, '/uploads/') === 0) {
                                    $images_array[] = 'https://socdo.vn' . $img;
                                } 
                                // Nếu là đường dẫn không có / ở đầu
                                else {
                                    $images_array[] = 'https://socdo.vn/' . ltrim($img, '/');
                                }
                            }
                        }
                    }
                }
                
                $review_data = array(
                    'id' => intval($review_row['id']),
                    'content' => $review_row['content'],
                    'rating' => intval($review_row['rating']),
                    'delivery_rating' => $review_row['delivery_rating'] ? intval($review_row['delivery_rating']) : null,
                    'shop_rating' => $review_row['shop_rating'] ? intval($review_row['shop_rating']) : null,
                    'matches_description' => $review_row['matches_description'] !== null ? (intval($review_row['matches_description']) === 1) : null,
                    'is_satisfied' => $review_row['is_satisfied'] !== null ? (intval($review_row['is_satisfied']) === 1) : null,
                    'will_buy_again' => $review_row['will_buy_again'] ?? null,
                    'images' => $images_array,
                    'is_verified_purchase' => intval($review_row['is_verified_purchase']) === 1,
                    'review_date' => $review_row['created_at'],
                    'review_date_formatted' => date('d/m/Y H:i', strtotime($review_row['created_at'])),
                );
            }
            
            // Lọc theo status
            if ($status === 'reviewed' && !$has_review) continue;
            if ($status === 'pending' && $has_review) continue;
            
            $all_reviews[] = array(
                'order_id' => $order_id,
                'ma_don' => $ma_don,
                'date_post' => $date_post,
                'date_post_formatted' => date('d/m/Y', $date_post),
                'products' => array(array(
                    'id' => $product_id,
                    'name' => $product_name,
                    'image' => $product_image,
                    'color' => $product_item['color'] ?? '',
                    'size' => $product_item['size'] ?? '',
                    'variant_name' => $variant_name,
                    'shop_name' => $shop_name,
                    'has_review' => $has_review,
                    'review' => $review_data,
                )),
            );
        }
    }
    
    // Phân trang
    $total_reviews = count($all_reviews);
    $total_pages = ceil($total_reviews / $limit);
    $paginated_reviews = array_slice($all_reviews, $start, $limit);
    
    http_response_code(200);
    echo json_encode(array(
        "success" => true,
        "message" => "Lấy lịch sử đánh giá thành công",
        "data" => array(
            "reviews" => $paginated_reviews,
            "pagination" => array(
                "current_page" => $page,
                "total_pages" => $total_pages,
                "total_reviews" => $total_reviews,
                "limit" => $limit,
                "has_next" => $page < $total_pages,
                "has_prev" => $page > 1
            )
        )
    ));
}

// Hàm cập nhật thống kê đánh giá
function _updateRatingStats($conn, $product_id, $shop_id, $rating, $increment) {
    // Kiểm tra xem đã có thống kê chưa
    $check_query = "SELECT id, total_reviews, average_rating, rating_5, rating_4, rating_3, rating_2, rating_1 
                    FROM product_rating_stats 
                    WHERE product_id = $product_id AND shop_id = $shop_id LIMIT 1";
    $check_result = mysqli_query($conn, $check_query);
    
    if ($check_result && mysqli_num_rows($check_result) > 0) {
        // Cập nhật thống kê hiện có
        $stats = mysqli_fetch_assoc($check_result);
        $total_reviews = intval($stats['total_reviews']) + $increment;
        $rating_5 = intval($stats['rating_5']);
        $rating_4 = intval($stats['rating_4']);
        $rating_3 = intval($stats['rating_3']);
        $rating_2 = intval($stats['rating_2']);
        $rating_1 = intval($stats['rating_1']);
        
        // Cập nhật số lượng rating theo sao
        switch ($rating) {
            case 5:
                $rating_5 += $increment;
                break;
            case 4:
                $rating_4 += $increment;
                break;
            case 3:
                $rating_3 += $increment;
                break;
            case 2:
                $rating_2 += $increment;
                break;
            case 1:
                $rating_1 += $increment;
                break;
        }
        
        // Tính lại điểm trung bình
        $total_points = ($rating_5 * 5) + ($rating_4 * 4) + ($rating_3 * 3) + ($rating_2 * 2) + ($rating_1 * 1);
        $average_rating = $total_reviews > 0 ? round($total_points / $total_reviews, 2) : 0;
        
        $update_query = "UPDATE product_rating_stats SET 
            total_reviews = $total_reviews,
            average_rating = $average_rating,
            rating_5 = $rating_5,
            rating_4 = $rating_4,
            rating_3 = $rating_3,
            rating_2 = $rating_2,
            rating_1 = $rating_1,
            updated_at = NOW()
            WHERE product_id = $product_id AND shop_id = $shop_id";
        
        mysqli_query($conn, $update_query);
    } else {
        // Tạo thống kê mới
        $rating_5 = ($rating == 5) ? 1 : 0;
        $rating_4 = ($rating == 4) ? 1 : 0;
        $rating_3 = ($rating == 3) ? 1 : 0;
        $rating_2 = ($rating == 2) ? 1 : 0;
        $rating_1 = ($rating == 1) ? 1 : 0;
        
        $insert_query = "INSERT INTO product_rating_stats (
            product_id, shop_id, total_reviews, average_rating, 
            rating_5, rating_4, rating_3, rating_2, rating_1
        ) VALUES (
            $product_id, $shop_id, 1, $rating,
            $rating_5, $rating_4, $rating_3, $rating_2, $rating_1
        )";
        
        mysqli_query($conn, $insert_query);
    }
}
?>

