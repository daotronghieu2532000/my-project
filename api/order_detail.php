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

// Lấy token từ header Authorization
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$user_id = 0;

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
        // JWT invalid, user_id remains 0
    }
}

// Lấy user_id từ query (ưu tiên), nếu không có thì lấy từ token
if ($user_id <= 0) {
    $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
}

if ($user_id <= 0) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "User ID is required"
    ]);
    exit;
}

try {
    // Get order ID
    $order_id = isset($_GET['order_id']) ? intval($_GET['order_id']) : 0;
    $ma_don = isset($_GET['ma_don']) ? trim($_GET['ma_don']) : '';
    
    if (!$order_id && !$ma_don) {
        throw new Exception('Thiếu thông tin đơn hàng');
    }
    
    // Build WHERE clause
    $where_clause = "user_id = '$user_id'";
    if ($order_id) {
        $where_clause .= " AND id = '$order_id'";
    } else {
        $where_clause .= " AND ma_don = '$ma_don'";
    }
    
    // Get order details
    $query = "SELECT * FROM donhang WHERE $where_clause";
    $result = mysqli_query($conn, $query);
    
    if (!$result || mysqli_num_rows($result) == 0) {
        throw new Exception('Không tìm thấy đơn hàng');
    }
    
    $order = mysqli_fetch_assoc($result);
    
    // Status mapping
    $status_map = [
        0 => ['text' => 'Chờ xử lý', 'class' => 'pending', 'icon' => 'fa-clock-o'],
        1 => ['text' => 'Đã tiếp nhận đơn', 'class' => 'received', 'icon' => 'fa-check-circle'],
        2 => ['text' => 'Đã giao đơn vị vận chuyển', 'class' => 'shipping', 'icon' => 'fa-truck'],
        3 => ['text' => 'Yêu cầu hủy đơn', 'class' => 'cancel-request', 'icon' => 'fa-exclamation-triangle'],
        4 => ['text' => 'Đã hủy đơn', 'class' => 'cancelled', 'icon' => 'fa-times-circle'],
        5 => ['text' => 'Giao thành công', 'class' => 'delivered', 'icon' => 'fa-check-circle'],
        6 => ['text' => 'Đã hoàn đơn', 'class' => 'returned', 'icon' => 'fa-undo'],
        7 => ['text' => 'Lỗi khi giao hàng', 'class' => 'error', 'icon' => 'fa-exclamation-triangle'],
        8 => ['text' => 'Đang vận chuyển', 'class' => 'in-transit', 'icon' => 'fa-truck'],
        9 => ['text' => 'Đang chờ lên lịch lại', 'class' => 'reschedule', 'icon' => 'fa-calendar'],
        10 => ['text' => 'Đã phân công tài xế', 'class' => 'assigned', 'icon' => 'fa-user'],
        11 => ['text' => 'Đã lấy hàng', 'class' => 'picked', 'icon' => 'fa-hand-grab-o'],
        12 => ['text' => 'Đã đến bưu cục', 'class' => 'arrived', 'icon' => 'fa-building'],
        14 => ['text' => 'Ngoại lệ trả hàng', 'class' => 'exception', 'icon' => 'fa-warning']
    ];
    
    // Get address info
    $tinh_name = '';
    $huyen_name = '';
    $xa_name = '';
    
    if ($order['tinh']) {
        $tinh_query = "SELECT ten_tinh FROM tinh WHERE id = '{$order['tinh']}'";
        $tinh_result = mysqli_query($conn, $tinh_query);
        if ($tinh_result && mysqli_num_rows($tinh_result) > 0) {
            $tinh_name = mysqli_fetch_assoc($tinh_result)['ten_tinh'];
        }
    }
    
    if ($order['huyen']) {
        $huyen_query = "SELECT ten_huyen FROM huyen WHERE id = '{$order['huyen']}'";
        $huyen_result = mysqli_query($conn, $huyen_query);
        if ($huyen_result && mysqli_num_rows($huyen_result) > 0) {
            $huyen_name = mysqli_fetch_assoc($huyen_result)['ten_huyen'];
        }
    }
    
    if ($order['xa']) {
        $xa_query = "SELECT ten_xa FROM xa WHERE id = '{$order['xa']}'";
        $xa_result = mysqli_query($conn, $xa_query);
        if ($xa_result && mysqli_num_rows($xa_result) > 0) {
            $xa_name = mysqli_fetch_assoc($xa_result)['ten_xa'];
        }
    }
    
    // Parse products
    $products = json_decode($order['sanpham'], true);
    $product_list = [];
    
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
            
            // Get shop_id from order JSON first, fallback to database
            $shop_id = 0;
            $shop_name = '';
            
            // Try to get shop from order JSON (newest format)
            if (isset($product['shop']) && is_numeric($product['shop'])) {
                $shop_id = intval($product['shop']);
            }
            
            // If not in JSON, get from database
            if ($shop_id <= 0 && $sp_id > 0) {
                $shop_query = "SELECT s.shop, u.name as shop_name 
                              FROM sanpham s 
                              LEFT JOIN user_info u ON s.shop = u.user_id 
                              WHERE s.id = '$sp_id' LIMIT 1";
                $shop_res = mysqli_query($conn, $shop_query);
                if ($shop_res && mysqli_num_rows($shop_res) > 0) {
                    $shop_row = mysqli_fetch_assoc($shop_res);
                    $shop_id = intval($shop_row['shop'] ?? 0);
                    $shop_name = $shop_row['shop_name'] ?? '';
                }
            } elseif ($shop_id > 0) {
                // If we got shop_id from JSON, get shop_name from database
                $shop_name_query = "SELECT name FROM user_info WHERE user_id = '$shop_id' LIMIT 1";
                $shop_name_res = mysqli_query($conn, $shop_name_query);
                if ($shop_name_res && mysqli_num_rows($shop_name_res) > 0) {
                    $shop_name_row = mysqli_fetch_assoc($shop_name_res);
                    $shop_name = $shop_name_row['name'] ?? '';
                }
            }
            
            // Get variant info if pl > 0
            $size = '';
            $color = '';
            if ($pl > 0) {
                $pl_query = "SELECT ten_size, ten_color, image_phanloai, gia_moi, gia_cu 
                            FROM phanloai_sanpham WHERE id = '$pl' LIMIT 1";
                $pl_res = mysqli_query($conn, $pl_query);
                if ($pl_res && mysqli_num_rows($pl_res) > 0) {
                    $pl_row = mysqli_fetch_assoc($pl_res);
                    $size = $pl_row['ten_size'] ?? '';
                    $color = $pl_row['ten_color'] ?? '';
                    
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

            $product_list[] = [
                'id' => $sp_id,
                'name' => $name,
                'image' => $image,
                'product_url' => $product_url,
                'quantity' => $quantity,
                'price' => $price,
                'price_formatted' => number_format($price) . 'đ',
                'old_price' => $old_price,
                'old_price_formatted' => number_format($old_price) . 'đ',
                'total' => $line_total,
                'total_formatted' => number_format($line_total) . 'đ',
                'size' => $size,
                'color' => $color,
                'variant_id' => $pl,
                'shop_id' => $shop_id,
                'shop' => $shop_id, // Alias for compatibility
                'shop_name' => $shop_name
            ];
        }
    }
    
    // Get status info
    $status_info = $status_map[$order['status']] ?? $status_map[0];
    
    // Build timeline
    $timeline = [
        [
            'id' => 0,
            'title' => 'Đơn hàng đã được đặt',
            'description' => 'Đơn hàng của bạn đã được tiếp nhận và đang chờ xác nhận',
            'icon' => 'fa-check',
            'class' => $order['status'] >= 0 ? 'completed' : 'pending',
            'date' => $order['date_post']
        ],
        [
            'id' => 1,
            'title' => 'Đã tiếp nhận đơn',
            'description' => 'Đơn hàng đã được tiếp nhận và đang chuẩn bị',
            'icon' => 'fa-check-circle',
            'class' => $order['status'] >= 1 ? 'completed' : 'pending',
            'date' => $order['status'] >= 1 ? $order['date_update'] : null
        ],
        [
            'id' => 2,
            'title' => 'Đã giao đơn vị vận chuyển',
            'description' => 'Đơn hàng đã được giao cho đơn vị vận chuyển',
            'icon' => 'fa-shipping-fast',
            'class' => $order['status'] >= 2 ? 'completed' : 'pending',
            'date' => $order['status'] >= 2 ? $order['date_update'] : null
        ],
        [
            'id' => 3,
            'title' => 'Đang giao hàng',
            'description' => 'Đơn hàng đang trên đường giao đến bạn',
            'icon' => 'fa-truck',
            'class' => $order['status'] >= 5 ? 'completed' : ($order['status'] >= 3 ? 'in-progress' : 'pending'),
            'date' => $order['status'] >= 3 ? $order['date_update'] : null
        ],
        [
            'id' => 4,
            'title' => 'Giao thành công',
            'description' => 'Đơn hàng đã được giao thành công',
            'icon' => 'fa-check-circle',
            'class' => $order['status'] >= 5 ? 'completed' : 'pending',
            'date' => $order['status'] >= 5 ? $order['date_update'] : null
        ]
    ];
    
    // Calculate total discount
    $giam = intval($order['giam']);
    $voucher_tmdt = intval($order['voucher_tmdt'] ?? 0);
    $ship_support = intval($order['ship_support'] ?? 0);
    $total_discount = $giam + $voucher_tmdt + $ship_support;
    
    // Response
    $response = [
        'success' => true,
        'data' => [
            'order' => [
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
                'ghi_chu' => $order['ghi_chu'],
                'shipping_provider' => $order['shipping_provider'],
                'date_post' => intval($order['date_post']),
                'date_post_formatted' => date('d/m/Y H:i', $order['date_post']),
                'date_update' => intval($order['date_update']),
                'date_update_formatted' => date('d/m/Y H:i', $order['date_update']),
                'products' => $product_list,
                'product_count' => count($product_list),
                'customer_info' => [
                    'ho_ten' => $order['ho_ten'],
                    'email' => $order['email'],
                    'dien_thoai' => $order['dien_thoai'],
                    'dia_chi' => $order['dia_chi'],
                    'tinh' => intval($order['tinh']),
                    'tinh_name' => $tinh_name,
                    'huyen' => intval($order['huyen']),
                    'huyen_name' => $huyen_name,
                    'xa' => intval($order['xa']),
                    'xa_name' => $xa_name,
                    'full_address' => trim($order['dia_chi'] . ', ' . $xa_name . ', ' . $huyen_name . ', ' . $tinh_name, ', ')
                ],
                

                
                'timeline' => $timeline,
                'can_cancel' => in_array($order['status'], [0, 1]),
                'can_reorder' => $order['status'] == 5,
                'tracking_info' => [
                    'shipping_provider' => $order['shipping_provider'],
                    'ninja_response' => $order['ninja_response'] ? json_decode($order['ninja_response'], true) : null
                ]
            ]
        ]
    ];
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
?>