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

// Lấy token từ header Authorization (tùy chọn nếu có user_id param)
$headers = function_exists('apache_request_headers') ? apache_request_headers() : [];
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$jwt = null;
if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    $jwt = $matches[1];
}

// Lấy user_id từ query (ưu tiên), nếu không có thì lấy từ token
$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;

try {
    if (!$user_id && $jwt) {
        // Giải mã JWT khi không có user_id param
        $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
        if (!isset($decoded->iss) || $decoded->iss !== $issuer) {
            http_response_code(401);
            echo json_encode(array("message" => "Issuer không hợp lệ"));
            exit;
        }
        $user_id = isset($decoded->user_id) ? intval($decoded->user_id) : 0;
    }
    
    // Nếu vẫn không có user_id thì báo lỗi xác thực
    if ($user_id <= 0) {
        http_response_code(401);
        echo json_encode(array("message" => "Thông tin người dùng không hợp lệ"));
        exit;
    }
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        // Get parameters
        $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
        $limit = isset($_GET['limit']) ? min(500, max(1, intval($_GET['limit']))) : 100;
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        $status = isset($_GET['status']) ? intval($_GET['status']) : null;
        $start_date = isset($_GET['start_date']) ? addslashes($_GET['start_date']) : null;
        $end_date = isset($_GET['end_date']) ? addslashes($_GET['end_date']) : null;
        
        $offset = ($page - 1) * $limit;
        
        // Build WHERE clause
        $where_conditions = array("user_id = '$user_id'");
        
        if ($status !== null) {
            $where_conditions[] = "status = '$status'";
        }
        
        if ($start_date) {
            $start_timestamp = strtotime($start_date);
            $where_conditions[] = "date_post >= '$start_timestamp'";
        }
        
        if ($end_date) {
            $end_timestamp = strtotime($end_date . ' 23:59:59');
            $where_conditions[] = "date_post <= '$end_timestamp'";
        }
        
        $where_clause = implode(' AND ', $where_conditions);
        
        // Get total count
        $count_query = "SELECT COUNT(*) as total FROM donhang WHERE $where_clause";
        $count_result = mysqli_query($conn, $count_query);
        $total_orders = 0;
        if ($count_result) {
            $total_orders = mysqli_fetch_assoc($count_result)['total'];
        }
        
        // Get orders
        $query = "SELECT * FROM donhang WHERE $where_clause ORDER BY date_post DESC LIMIT $offset, $limit";
        $result = mysqli_query($conn, $query);
        
        if (!$result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database"
            ]);
            exit;
        }
        
        $orders = array();
        $status_map = array(
            0 => array('text' => 'Chờ xử lý', 'class' => 'pending', 'icon' => 'fa-clock-o'),
            1 => array('text' => 'Đã tiếp nhận đơn', 'class' => 'received', 'icon' => 'fa-check-circle'),
            2 => array('text' => 'Đã giao đơn vị vận chuyển', 'class' => 'shipping', 'icon' => 'fa-truck'),
            3 => array('text' => 'Đã hủy đơn', 'class' => 'cancel-request', 'icon' => 'fa-exclamation-triangle'),
            4 => array('text' => 'Đã hủy đơn', 'class' => 'cancelled', 'icon' => 'fa-times-circle'),
            5 => array('text' => 'Giao thành công', 'class' => 'delivered', 'icon' => 'fa-check-circle'),
            6 => array('text' => 'Đã hoàn đơn', 'class' => 'returned', 'icon' => 'fa-undo'),
            7 => array('text' => 'Lỗi khi giao hàng', 'class' => 'error', 'icon' => 'fa-exclamation-triangle'),
            8 => array('text' => 'Đang vận chuyển', 'class' => 'in-transit', 'icon' => 'fa-truck'),
            9 => array('text' => 'Đang chờ lên lịch lại', 'class' => 'reschedule', 'icon' => 'fa-calendar'),
            10 => array('text' => 'Đã phân công tài xế', 'class' => 'assigned', 'icon' => 'fa-user'),
            11 => array('text' => 'Đã lấy hàng', 'class' => 'picked', 'icon' => 'fa-hand-grab-o'),
            12 => array('text' => 'Đã đến bưu cục', 'class' => 'arrived', 'icon' => 'fa-building'),
            14 => array('text' => 'Ngoại lệ trả hàng', 'class' => 'exception', 'icon' => 'fa-warning')
        );
        
        while ($order = mysqli_fetch_assoc($result)) {
            // Parse products
            $products = json_decode($order['sanpham'], true);
            $product_list = array();
            
            if ($products && is_array($products)) {
                foreach ($products as $key => $product) {
                    // Parse sp_id and pl from different JSON structures
                    $sp_id = 0;
                    $pl = 0;
                    
                    // Case 1: Object with key like "4215_0" (string with underscore)
                    if (is_string($key) && strpos($key, '_') !== false) {
                        $parts = explode('_', $key);
                        $sp_id = intval($parts[0]);
                        $pl = intval($parts[1]);
                    }
                    // Case 2: Array with 'id' field (newest format)
                    elseif (isset($product['id'])) {
                        $sp_id = intval($product['id']);
                        $pl = intval($product['pl'] ?? $product['variant_id'] ?? 0);
                    }
                    // Case 3: Object with sp_id as key (oldest format - cancelled orders)
                    elseif (is_int($key) || (is_string($key) && ctype_digit($key))) {
                        $sp_id = intval($key);
                        $pl = 0;
                    }
                    
                    // Get data from JSON (already has the data)
                    // Handle different field names
                    $quantity = intval($product['quantity'] ?? $product['soluong'] ?? 1);
                    $name = $product['tieu_de'] ?? '';
                    $image = $product['anh_chinh'] ?? $product['minh_hoa'] ?? '';
                    
                    // Fallback to product image from sanpham table if anh_chinh is empty
                    if (empty($image) && $sp_id > 0) {
                        $fallback_query = "SELECT minh_hoa FROM sanpham WHERE id = '$sp_id' LIMIT 1";
                        $fallback_res = mysqli_query($conn, $fallback_query);
                        if ($fallback_res && mysqli_num_rows($fallback_res) > 0) {
                            $fallback_row = mysqli_fetch_assoc($fallback_res);
                            $image = $fallback_row['minh_hoa'] ?? '';
                        }
                    }
                    
                    // Parse prices - handle both string with comma "220,000" and int 319000
                    $price = 0;
                    if (isset($product['gia_moi'])) {
                        if (is_string($product['gia_moi'])) {
                            $price = intval(str_replace(',', '', $product['gia_moi']));
                        } else {
                            $price = intval($product['gia_moi']);
                        }
                    }
                    
                    $old_price = 0;
                    if (isset($product['gia_cu'])) {
                        if (is_string($product['gia_cu'])) {
                            $old_price = intval(str_replace(',', '', $product['gia_cu']));
                        } else {
                            $old_price = intval($product['gia_cu']);
                        }
                    }
                    
                    // Parse total from thanhtien or thanh_tien
                    $line_total = 0;
                    if (isset($product['thanhtien'])) {
                        if (is_string($product['thanhtien'])) {
                            $line_total = intval(str_replace(',', '', $product['thanhtien']));
                        } else {
                            $line_total = intval($product['thanhtien']);
                        }
                    } elseif (isset($product['thanh_tien'])) {
                        if (is_string($product['thanh_tien'])) {
                            $line_total = intval(str_replace(',', '', $product['thanh_tien']));
                        } else {
                            $line_total = intval($product['thanh_tien']);
                        }
                    }
                    // Fallback: calculate from price * quantity if total is 0 or missing
                    if ($line_total <= 0) {
                        $line_total = $price * $quantity;
                    }
                    
                    // Get shop name from JOIN
                    $shop_name = '';
                    if ($sp_id > 0) {
                        $shop_query = "SELECT s.shop, u.name as shop_name 
                                      FROM sanpham s 
                                      LEFT JOIN user_info u ON s.shop = u.user_id 
                                      WHERE s.id = '$sp_id' LIMIT 1";
                        $shop_res = mysqli_query($conn, $shop_query);
                        if ($shop_res && mysqli_num_rows($shop_res) > 0) {
                            $shop_row = mysqli_fetch_assoc($shop_res);
                            $shop_name = $shop_row['shop_name'] ?? '';
                        }
                    }
                    
                    // Get variant info if pl > 0
                    $size = '';
                    $color = '';
                    $variant_name = '';
                    if ($pl > 0) {
                        $pl_query = "SELECT ten_size, ten_color, image_phanloai, gia_moi, gia_cu 
                                    FROM phanloai_sanpham WHERE id = '$pl' LIMIT 1";
                        $pl_res = mysqli_query($conn, $pl_query);
                        if ($pl_res && mysqli_num_rows($pl_res) > 0) {
                            $pl_row = mysqli_fetch_assoc($pl_res);
                            $size = $pl_row['ten_size'] ?? '';
                            $color = $pl_row['ten_color'] ?? '';
                            
                            // Tạo variant_name từ ten_color và ten_size
                            $variant_parts = array();
                            if (!empty($color)) {
                                $variant_parts[] = $color;
                            }
                            if (!empty($size)) {
                                $variant_parts[] = $size;
                            }
                            if (!empty($variant_parts)) {
                                $variant_name = implode(' - ', $variant_parts);
                            }
                            
                            // Override with variant data if available
                            if (!empty($pl_row['gia_moi'])) {
                                $price = intval($pl_row['gia_moi']);
                            }
                            if (!empty($pl_row['gia_cu'])) {
                                $old_price = intval($pl_row['gia_cu']);
                            }
                            if (!empty($pl_row['image_phanloai'])) {
                                $image = $pl_row['image_phanloai'];
                            }
                        }
                    } else {
                        // Nếu không có pl, thử extract từ tieu_de
                        if (!empty($name) && strpos($name, ' - ') !== false) {
                            $parts = explode(' - ', $name);
                            if (count($parts) > 1) {
                                $variant_name = trim(end($parts)); // Lấy phần cuối cùng sau dấu " - "
                            }
                        }
                    }

                    // Normalize image URL to https://socdo.vn/
                    if ($image && strpos($image, 'http') !== 0) {
                        $image = 'https://socdo.vn/' . ltrim($image, '/');
                    }
                    if (strpos($image, 'api.socdo.vn') !== false) {
                        $image = str_replace('api.socdo.vn', 'socdo.vn', $image);
                    }

                    // Generate product URL
                    $product_url = '';
                    if ($sp_id > 0) {
                        // Try to get slug from JSON first (format 3)
                        $slug = $product['link'] ?? '';
                        
                        // If not in JSON, get from database
                        if (empty($slug)) {
                            $slug_query = "SELECT slug FROM sanpham WHERE id = '$sp_id' LIMIT 1";
                            $slug_res = mysqli_query($conn, $slug_query);
                            if ($slug_res && mysqli_num_rows($slug_res) > 0) {
                                $slug_row = mysqli_fetch_assoc($slug_res);
                                $slug = $slug_row['slug'] ?? '';
                            }
                        }
                        
                        // Build URL
                        if ($slug) {
                            $product_url = "https://socdo.vn/san-pham/$sp_id/$slug.html";
                        } else {
                            $product_url = "https://socdo.vn/san-pham/$sp_id.html";
                        }
                    }

                    $product_list[] = array(
                        'id' => $sp_id,
                        'name' => $name,
                        'image' => $image,
                        'product_url' => $product_url,
                        'quantity' => $quantity,
                        'price' => $price,
                        'old_price' => $old_price,
                        'total' => $line_total,
                        'size' => $size,
                        'color' => $color,
                        'variant_id' => $pl,
                        'variant_name' => $variant_name,
                        'shop_name' => $shop_name,
                        'rating' => $rating,
                        'total_reviews' => $total_reviews,
                        'reviews_count' => $total_reviews,
                        'sold_count' => $sold_count
                    );
                }
            }
            
        // Get status info
        $status_info = isset($status_map[$order['status']]) ? $status_map[$order['status']] : $status_map[0];
        
        // Calculate delivery ETA text if not stored
        $delivery_eta_text = '';
        if (!empty($order['delivery_eta_text'])) {
            $delivery_eta_text = $order['delivery_eta_text'];
        } else {
            // Fallback: calculate ETA based on order date and shipping provider
            $order_timestamp = intval($order['date_post']);
            $shipping_provider = $order['shipping_provider'] ?? '';
            
            if (strpos($shipping_provider, 'SUPERAI') !== false || strpos($shipping_provider, 'GHTK') !== false) {
                // Standard shipping: 2-4 days
                $delivery_eta_text = 'Dự kiến từ ' . date('d/m', $order_timestamp + 2*24*3600) . ' - ' . date('d/m', $order_timestamp + 4*24*3600);
            } else {
                // Express shipping: 1-2 days  
                $delivery_eta_text = 'Dự kiến từ ' . date('d/m', $order_timestamp + 1*24*3600) . ' - ' . date('d/m', $order_timestamp + 2*24*3600);
            }
        }
        
        // Calculate total discount
        $giam = intval($order['giam']);
        $voucher_tmdt = isset($order['voucher_tmdt']) ? intval($order['voucher_tmdt']) : 0;
        $ship_support = intval($order['ship_support'] ?? 0);
        $total_discount = $giam + $voucher_tmdt + $ship_support;
        
        $orders[] = array(
            'id' => intval($order['id']),
            'ma_don' => $order['ma_don'],
            'status' => intval($order['status']),
            'status_text' => $status_info['text'],
            'status_class' => $status_info['class'],
            'status_icon' => $status_info['icon'],
            'tongtien' => intval($order['tongtien']),
            'tongtien_formatted' => number_format($order['tongtien']) . 'đ',
            'tamtinh' => intval($order['tamtinh']),
            'tamtinh_formatted' => number_format($order['tamtinh']) . 'đ',
            'phi_ship' => intval($order['phi_ship']),
            'phi_ship_formatted' => number_format($order['phi_ship']) . 'đ',
            'ship_support' => $ship_support,
            'ship_support_formatted' => number_format($ship_support) . 'đ',
            'giam' => $giam,
            'giam_formatted' => number_format($giam) . 'đ',
            'voucher_tmdt' => $voucher_tmdt,
            'voucher_tmdt_formatted' => number_format($voucher_tmdt) . 'đ',
            'total_discount' => $total_discount,
            'total_discount_formatted' => number_format($total_discount) . 'đ',
            'coupon_code' => $order['coupon'],
            'thanhtoan' => $order['thanhtoan'],
            'date_post' => intval($order['date_post']),
            'date_post_formatted' => date('d/m/Y H:i', $order['date_post']),
            'date_update' => intval($order['date_update']),
            'date_update_formatted' => $order['date_update'] > 0 ? date('d/m/Y H:i', $order['date_update']) : '',
            'products' => $product_list,
            'product_count' => count($product_list),
            'shipping_provider' => $order['shipping_provider'],
            'delivery_eta_text' => $delivery_eta_text,
            'can_cancel' => in_array($order['status'], array(0, 1)),
            'can_reorder' => $order['status'] == 5
        );
        }
        
        // Calculate pagination
        $total_pages = ceil($total_orders / $limit);
        
        // Response
        $response = array(
            'success' => true,
            'message' => 'Lấy danh sách đơn hàng thành công',
            'data' => array(
                'orders' => $orders,
                'pagination' => array(
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total_orders' => intval($total_orders),
                    'total_pages' => $total_pages,
                    'has_next' => $page < $total_pages,
                    'has_prev' => $page > 1
                ),
                'status_map' => $status_map,
                'filters' => array(
                    'status' => $status,
                    'start_date' => $start_date,
                    'end_date' => $end_date
                )
            )
        );
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
    } else {
        http_response_code(405);
        echo json_encode(array(
            "success" => false,
            "message" => "Chỉ hỗ trợ phương thức GET"
        ));
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



