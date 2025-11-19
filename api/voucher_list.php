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
        $type = isset($_GET['type']) ? trim($_GET['type']) : 'platform'; // 'platform' hoặc 'shop'
        $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : 0;
        $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
        $product_id = isset($_GET['product_id']) ? intval($_GET['product_id']) : 0;
        // Bỏ giới hạn hiển thị theo yêu cầu: luôn trả về toàn bộ voucher thỏa điều kiện
        // Giữ tham số page/limit nếu client cũ gửi lên, nhưng không dùng trong truy vấn
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 0; // 0 = không giới hạn

        // Chuẩn hóa root_shop_id theo nguyên tắc:
        //  - Nếu type=shop và truyền vào shop_id là user con (user_info.shop > 0)
        //    thì root_shop_id = user_info.shop
        //  - Nếu là tài khoản gốc (user_info.shop = 0) thì root_shop_id = user_info.user_id
        if ($type === 'shop' && $shop_id > 0) {
            $root_rs = mysqli_query($conn, "SELECT user_id, shop, name, avatar FROM user_info WHERE user_id = '$shop_id' LIMIT 1");
            if ($root_rs && mysqli_num_rows($root_rs) > 0) {
                $root = mysqli_fetch_assoc($root_rs);
                $root_shop = intval($root['shop']);
                if ($root_shop > 0) {
                    $shop_id = $root_shop; // map về shop gốc
                } else {
                    $shop_id = intval($root['user_id']);
                }
            }
        }
        
        // Validate parameters - Cho phép lấy tất cả voucher shop nếu không có shop_id
        // Chỉ validate khi có shop_id cụ thể
        if ($type === 'shop' && $shop_id < 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "shop_id không hợp lệ"
            ]);
            exit;
        }
        
        // Bỏ ràng buộc limit khi trả full list
        if ($page < 1) $page = 1;
        
        $offset = 0; // không dùng khi không giới hạn
        $current_time = time();
        
        // Xây dựng query dựa trên type
        if ($type === 'platform') {
            // Voucher sàn (shop = 0)
            $base_query = "FROM coupon 
                          WHERE shop = 0 
                          AND start <= $current_time 
                          AND expired >= $current_time 
                          AND status = 2";
                          
            // Nếu có product_id thì lọc theo sản phẩm
            if ($product_id > 0) {
                $base_query .= " AND (kieu = 'all' OR (kieu = 'sanpham' AND FIND_IN_SET('$product_id', sanpham)))";
            }
            
        } else {
            // Voucher shop
            if ($shop_id > 0) {
                // Lấy voucher của shop cụ thể
                $base_query = "FROM coupon 
                              WHERE shop = $shop_id 
                              AND start <= $current_time 
                              AND expired >= $current_time 
                              AND status = 2";
            } else {
                // Lấy tất cả voucher shop (shop > 0)
                $base_query = "FROM coupon 
                              WHERE shop > 0 
                              AND start <= $current_time 
                              AND expired >= $current_time 
                              AND status = 2";
            }
                          
            // Nếu có product_id thì lọc theo sản phẩm
            if ($product_id > 0) {
                $base_query .= " AND (kieu = 'all' OR (kieu = 'sanpham' AND FIND_IN_SET('$product_id', sanpham)))";
            }
        }
        
        // Đếm tổng số voucher
        $count_query = "SELECT COUNT(*) as total " . $base_query;
        $count_result = mysqli_query($conn, $count_query);
        $total_records = 0;
        if ($count_result) {
            $count_row = mysqli_fetch_assoc($count_result);
            $total_records = $count_row['total'];
        }
        
        $total_pages = 1; // không phân trang
        
        // Lấy danh sách voucher
        // Trả về toàn bộ kết quả, không phân trang
        $vouchers_query = "SELECT * " . $base_query . " ORDER BY id DESC";
        $vouchers_result = mysqli_query($conn, $vouchers_query);
        
        if (!$vouchers_result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database"
            ]);
            exit;
        }
        
        $vouchers = array();
        
        while ($voucher = mysqli_fetch_assoc($vouchers_result)) {
            // Format dữ liệu voucher
            $voucher_data = array();
            $voucher_data['id'] = $voucher['id'];
            $voucher_data['ma'] = $voucher['ma'];
            $voucher_data['loai'] = $voucher['loai'];
            $voucher_data['kieu'] = $voucher['kieu'];
            $voucher_data['giam'] = intval($voucher['giam']);
            $voucher_data['giam_toi_da'] = intval($voucher['giam_toi_da']);
            $voucher_data['min_price'] = intval($voucher['min_price']);
            $voucher_data['max_price'] = intval($voucher['max_price']);
            $voucher_data['start'] = intval($voucher['start']);
            $voucher_data['expired'] = intval($voucher['expired']);
            $voucher_data['max_global_uses'] = intval($voucher['max_global_uses']);
            $voucher_data['current_uses'] = intval($voucher['current_uses']);
            $voucher_data['max_uses_per_user'] = intval($voucher['max_uses_per_user']);
            $voucher_data['allow_combination'] = intval($voucher['allow_combination']);
            $voucher_data['sanpham'] = $voucher['sanpham'];
            $voucher_data['shop'] = intval($voucher['shop']);
            
            // Tính số lượng còn lại
            $remaining_uses = $voucher_data['max_global_uses'] - $voucher_data['current_uses'];
            $voucher_data['remaining_uses'] = max(0, $remaining_uses);
            
            // Format giảm giá
            if ($voucher['loai'] == 'phantram') {
                $voucher_data['giam_formatted'] = $voucher['giam'] . '%';
            } else {
                $voucher_data['giam_formatted'] = number_format($voucher['giam']) . 'đ';
            }
            
            // Format thời gian
            $voucher_data['start_formatted'] = date('H:i d/m/Y', $voucher['start']);
            $voucher_data['expired_formatted'] = date('H:i d/m/Y', $voucher['expired']);
            
            // Format giá tối thiểu, tối đa
            $voucher_data['min_price_formatted'] = $voucher['min_price'] > 0 ? number_format($voucher['min_price']) . 'đ' : '';
            $voucher_data['max_price_formatted'] = $voucher['max_price'] > 0 ? number_format($voucher['max_price']) . 'đ' : '';
            $voucher_data['giam_toi_da_formatted'] = $voucher['giam_toi_da'] > 0 ? number_format($voucher['giam_toi_da']) . 'đ' : '';
            
            // Kiểm tra trạng thái có thể áp dụng
            $can_apply = true;
            $error_message = '';
            
            // Kiểm tra số lần sử dụng
            if ($voucher_data['max_global_uses'] > 0 && $voucher_data['current_uses'] >= $voucher_data['max_global_uses']) {
                $can_apply = false;
                $error_message = 'Voucher đã hết lượt sử dụng';
            }
            
            // Kiểm tra số lần sử dụng của user
            if ($can_apply && $user_id > 0 && $voucher_data['max_uses_per_user'] > 0) {
                $user_usage_query = "SELECT COUNT(*) as used_count FROM voucher_usage WHERE voucher_id = '{$voucher['id']}' AND user_id = '$user_id'";
                $user_usage_result = mysqli_query($conn, $user_usage_query);
                if ($user_usage_result) {
                    $user_usage = mysqli_fetch_assoc($user_usage_result);
                    if ($user_usage['used_count'] >= $voucher_data['max_uses_per_user']) {
                        $can_apply = false;
                        $error_message = 'Bạn đã sử dụng hết lượt cho voucher này';
                    }
                }
            }
            
            $voucher_data['can_apply'] = $can_apply;
            $voucher_data['error_message'] = $error_message;
            
            // Thông tin sản phẩm áp dụng
            $applicable_products = array();
            if ($voucher['kieu'] == 'sanpham' && !empty($voucher['sanpham'])) {
                $product_ids = explode(',', $voucher['sanpham']);
                $product_ids = array_map('intval', array_filter($product_ids));
                
                if (!empty($product_ids)) {
                    $products_query = "SELECT id, tieu_de, minh_hoa FROM sanpham WHERE id IN (" . implode(',', $product_ids) . ") LIMIT 5";
                    $products_result = mysqli_query($conn, $products_query);
                    if ($products_result) {
                        while ($product = mysqli_fetch_assoc($products_result)) {
                            $applicable_products[] = array(
                                'id' => $product['id'],
                                'tieu_de' => $product['tieu_de'],
                                'minh_hoa' => !empty($product['minh_hoa']) ? 'https://socdo.vn/' . $product['minh_hoa'] : ''
                            );
                        }
                    }
                }
            }
            $voucher_data['applicable_products'] = $applicable_products;
            $voucher_data['is_all_products'] = ($voucher['kieu'] == 'all');
            
            // Thông tin shop (nếu là voucher shop)
            if ($voucher_data['shop'] > 0) {
                // Lấy thông tin shop theo user_id (root_shop_id)
                $shop_query = "SELECT name, avatar FROM user_info WHERE user_id = '{$voucher_data['shop']}' LIMIT 1";
                $shop_result = mysqli_query($conn, $shop_query);
                if ($shop_result && mysqli_num_rows($shop_result) > 0) {
                    $shop_info = mysqli_fetch_assoc($shop_result);
                    $voucher_data['shop_info'] = array(
                        'name' => $shop_info['name'],
                        'avatar' => !empty($shop_info['avatar']) ? 'https://socdo.vn/' . $shop_info['avatar'] : ''
                    );
                } else {
                    $voucher_data['shop_info'] = null;
                }
            } else {
                $voucher_data['shop_info'] = null;
            }
            
            // Trạng thái button
            if (!$can_apply) {
                $voucher_data['button_text'] = 'Không khả dụng';
                $voucher_data['button_class'] = 'disabled';
            } else {
                $voucher_data['button_text'] = 'Sử dụng ngay';
                $voucher_data['button_class'] = 'active';
            }
            
            $vouchers[] = $voucher_data;
        }
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách voucher thành công",
            "data" => [
                "vouchers" => $vouchers,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_records" => $total_records,
                "per_page" => $total_records,
                "has_next" => false,
                "has_prev" => false
                ],
                "filters" => [
                    "type" => $type,
                    "shop_id" => $shop_id > 0 ? $shop_id : "all",
                    "product_id" => $product_id
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
