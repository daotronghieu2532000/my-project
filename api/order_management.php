<?php
header("Access-Control-Allow-Methods: GET, POST, PUT");
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
        // Lấy danh sách đơn hàng hoặc chi tiết đơn hàng
        $order_id = isset($_GET['order_id']) ? intval($_GET['order_id']) : 0;
        
        if ($order_id > 0) {
            // Lấy chi tiết đơn hàng
            $query = "SELECT * FROM donhang WHERE id = $order_id LIMIT 1";
            $result = mysqli_query($conn, $query);
            
            if (!$result || mysqli_num_rows($result) == 0) {
                http_response_code(404);
                echo json_encode([
                    "success" => false,
                    "message" => "Không tìm thấy đơn hàng"
                ]);
                exit;
            }
            
            $order = mysqli_fetch_assoc($result);
            
            // Xử lý thông tin sản phẩm
            $products = array();
            if (!empty($order['sanpham'])) {
                $sanpham_data = json_decode($order['sanpham'], true);
                if (is_array($sanpham_data)) {
                    foreach ($sanpham_data as $item) {
                        if (isset($item['id'])) {
                            $product_id = intval($item['id']);
                            $product_query = "SELECT id, tieu_de, minh_hoa, gia_moi, link FROM sanpham WHERE id = $product_id LIMIT 1";
                            $product_result = mysqli_query($conn, $product_query);
                            if ($product_result && mysqli_num_rows($product_result) > 0) {
                                $product = mysqli_fetch_assoc($product_result);
                                $product['quantity'] = isset($item['qty']) ? intval($item['qty']) : 1;
                                $product['price'] = isset($item['price']) ? intval($item['price']) : $product['gia_moi'];
                                $product['total'] = $product['quantity'] * $product['price'];
                                $product['price_formatted'] = number_format($product['price']);
                                $product['total_formatted'] = number_format($product['total']);
                                
                                if (!empty($product['minh_hoa']) && file_exists($product['minh_hoa'])) {
                                    $product['image_url'] = 'https://socdo.vn/' . $product['minh_hoa'];
                                } else {
                                    $product['image_url'] = 'https://socdo.vn/images/no-images.jpg';
                                }
                                
                                $products[] = $product;
                            }
                        }
                    }
                }
            }
            
            // Xử lý thông tin địa chỉ
            $address_info = array();
            if ($order['tinh'] > 0) {
                $tinh_query = "SELECT tieu_de FROM tinh_moi WHERE id = " . intval($order['tinh']) . " LIMIT 1";
                $tinh_result = mysqli_query($conn, $tinh_query);
                if ($tinh_result && mysqli_num_rows($tinh_result) > 0) {
                    $address_info['tinh'] = mysqli_fetch_assoc($tinh_result)['tieu_de'];
                }
            }
            
            if ($order['huyen'] > 0) {
                $huyen_query = "SELECT tieu_de FROM huyen_moi WHERE id = " . intval($order['huyen']) . " LIMIT 1";
                $huyen_result = mysqli_query($conn, $huyen_query);
                if ($huyen_result && mysqli_num_rows($huyen_result) > 0) {
                    $address_info['huyen'] = mysqli_fetch_assoc($huyen_result)['tieu_de'];
                }
            }
            
            // Format các trường
            $order['tamtinh_formatted'] = number_format($order['tamtinh']);
            $order['giam_formatted'] = number_format($order['giam']);
            $order['phi_ship_formatted'] = number_format($order['phi_ship']);
            $order['tongtien_formatted'] = number_format($order['tongtien']);
            $order['date_post_formatted'] = date('d/m/Y H:i:s', $order['date_post']);
            $order['date_update_formatted'] = date('d/m/Y H:i:s', $order['date_update']);
            
            // Trạng thái đơn hàng
            $status_text = array(
                0 => 'Chờ xác nhận',
                1 => 'Đã xác nhận',
                2 => 'Đang giao hàng',
                3 => 'Đã giao hàng',
                4 => 'Đã hủy'
            );
            
            $order['status_text'] = isset($status_text[$order['status']]) ? $status_text[$order['status']] : 'Không xác định';
            $order['products'] = $products;
            $order['address_info'] = $address_info;
            $order['full_address'] = trim($order['dia_chi'] . ', ' . 
                                        (isset($address_info['huyen']) ? $address_info['huyen'] . ', ' : '') . 
                                        (isset($address_info['tinh']) ? $address_info['tinh'] : ''));
            
            $response = [
                "success" => true,
                "message" => "Lấy chi tiết đơn hàng thành công",
                "data" => $order
            ];
            
        } else {
            // Lấy danh sách đơn hàng
            $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
            $status = isset($_GET['status']) ? intval($_GET['status']) : -1;
            $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
            $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 100;
            $date_from = isset($_GET['date_from']) ? addslashes($_GET['date_from']) : '';
            $date_to = isset($_GET['date_to']) ? addslashes($_GET['date_to']) : '';
            $search = isset($_GET['search']) ? addslashes(strip_tags($_GET['search'])) : '';
            
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
            
            // Xây dựng điều kiện WHERE
            $where_conditions = array();
            
            if ($user_id > 0) {
                $where_conditions[] = "user_id = $user_id";
            }
            
            if ($status >= 0) {
                $where_conditions[] = "status = $status";
            }
            
            if (!empty($search)) {
                $where_conditions[] = "(ma_don LIKE '%$search%' OR ho_ten LIKE '%$search%' OR dien_thoai LIKE '%$search%' OR email LIKE '%$search%')";
            }
            
            if (!empty($date_from)) {
                $date_from_timestamp = strtotime($date_from);
                if ($date_from_timestamp) {
                    $where_conditions[] = "date_post >= $date_from_timestamp";
                }
            }
            
            if (!empty($date_to)) {
                $date_to_timestamp = strtotime($date_to . ' 23:59:59');
                if ($date_to_timestamp) {
                    $where_conditions[] = "date_post <= $date_to_timestamp";
                }
            }
            
            $where_clause = !empty($where_conditions) ? 'WHERE ' . implode(' AND ', $where_conditions) : '';
            
            // Đếm tổng số đơn hàng
            $count_query = "SELECT COUNT(*) as total FROM donhang $where_clause";
            $count_result = mysqli_query($conn, $count_query);
            $total_orders = mysqli_fetch_assoc($count_result)['total'];
            
            // Lấy danh sách đơn hàng
            $query = "SELECT id, ma_don, user_id, ho_ten, email, dien_thoai, dia_chi, tinh, huyen, 
                     tamtinh, giam, phi_ship, tongtien, status, thanhtoan, date_post, date_update, utm_source
                     FROM donhang $where_clause ORDER BY date_post DESC LIMIT $start, $limit";
            $result = mysqli_query($conn, $query);
            
            if (!$result) {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
                ]);
                exit;
            }
            
            $orders = array();
            $status_text = array(
                0 => 'Chờ xác nhận',
                1 => 'Đã xác nhận', 
                2 => 'Đang giao hàng',
                3 => 'Đã giao hàng',
                4 => 'Đã hủy'
            );
            
            while ($row = mysqli_fetch_assoc($result)) {
                // Format các trường
                $row['tamtinh_formatted'] = number_format($row['tamtinh']);
                $row['giam_formatted'] = number_format($row['giam']);
                $row['phi_ship_formatted'] = number_format($row['phi_ship']);
                $row['tongtien_formatted'] = number_format($row['tongtien']);
                $row['date_post_formatted'] = date('d/m/Y H:i:s', $row['date_post']);
                $row['date_update_formatted'] = date('d/m/Y H:i:s', $row['date_update']);
                $row['status_text'] = isset($status_text[$row['status']]) ? $status_text[$row['status']] : 'Không xác định';
                
                $orders[] = $row;
            }
            
            // Tính toán thông tin phân trang
            $total_pages = ceil($total_orders / $limit);
            
            $response = [
                "success" => true,
                "message" => "Lấy danh sách đơn hàng thành công",
                "data" => [
                    "orders" => $orders,
                    "pagination" => [
                        "current_page" => $page,
                        "total_pages" => $total_pages,
                        "total_orders" => $total_orders,
                        "limit" => $limit,
                        "has_next" => $page < $total_pages,
                        "has_prev" => $page > 1
                    ],
                    "filters" => [
                        "user_id" => $user_id,
                        "status" => $status,
                        "search" => $search,
                        "date_from" => $date_from,
                        "date_to" => $date_to
                    ]
                ]
            ];
        }
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
    } elseif ($method === 'POST') {
        // Tạo đơn hàng mới
        $data = json_decode(file_get_contents("php://input"), true);
        
        // Validate required fields
        $required_fields = ['user_id', 'ho_ten', 'dien_thoai', 'dia_chi', 'sanpham', 'tamtinh', 'tongtien'];
        foreach ($required_fields as $field) {
            if (!isset($data[$field]) || (is_string($data[$field]) && trim($data[$field]) === '')) {
                http_response_code(400);
                echo json_encode([
                    "success" => false,
                    "message" => "Thiếu trường bắt buộc: $field"
                ]);
                exit;
            }
        }
        
        // Generate mã đơn hàng
        $class_index = $tlca_do->load('class_index');
        $ma_don = $class_index->creat_random($conn, 'donhang');
        
        $user_id = intval($data['user_id']);
        $ho_ten = addslashes(strip_tags($data['ho_ten']));
        $email = isset($data['email']) ? addslashes(strip_tags($data['email'])) : '';
        $dien_thoai = addslashes(strip_tags($data['dien_thoai']));
        $dia_chi = addslashes(strip_tags($data['dia_chi']));
        $tinh = isset($data['tinh']) ? intval($data['tinh']) : 0;
        $huyen = isset($data['huyen']) ? intval($data['huyen']) : 0;
        $xa = isset($data['xa']) ? intval($data['xa']) : 0;
        $dropship = isset($data['dropship']) ? intval($data['dropship']) : 0;
        $sanpham = addslashes(json_encode($data['sanpham']));
        $tamtinh = intval($data['tamtinh']);
        $coupon = isset($data['coupon']) ? addslashes($data['coupon']) : '';
        $giam = isset($data['giam']) ? intval($data['giam']) : 0;
        $phi_ship = isset($data['phi_ship']) ? intval($data['phi_ship']) : 0;
        $tongtien = intval($data['tongtien']);
        $kho = isset($data['kho']) ? addslashes($data['kho']) : '';
        $status = isset($data['status']) ? intval($data['status']) : 0;
        $thanhtoan = isset($data['thanhtoan']) ? addslashes($data['thanhtoan']) : 'cod';
        $ghi_chu = isset($data['ghi_chu']) ? addslashes(strip_tags($data['ghi_chu'])) : '';
        $utm_source = isset($data['utm_source']) ? addslashes($data['utm_source']) : '';
        $utm_campaign = isset($data['utm_campaign']) ? addslashes($data['utm_campaign']) : '';
        $shop_id = isset($data['shop_id']) ? addslashes($data['shop_id']) : '';
        
        $date_post = time();
        $date_update = $date_post;
        
        // Insert vào database
        $insert_query = "INSERT INTO donhang (ma_don, user_id, ho_ten, email, dien_thoai, dia_chi, tinh, huyen, xa, dropship, sanpham, tamtinh, coupon, giam, phi_ship, tongtien, kho, status, thanhtoan, ghi_chu, utm_source, utm_campaign, date_update, date_post, shop_id) 
                        VALUES ('$ma_don', '$user_id', '$ho_ten', '$email', '$dien_thoai', '$dia_chi', '$tinh', '$huyen', '$xa', '$dropship', '$sanpham', '$tamtinh', '$coupon', '$giam', '$phi_ship', '$tongtien', '$kho', '$status', '$thanhtoan', '$ghi_chu', '$utm_source', '$utm_campaign', '$date_update', '$date_post', '$shop_id')";
        
        $result = mysqli_query($conn, $insert_query);
        
        if ($result) {
            $order_id = mysqli_insert_id($conn);
            
            http_response_code(201);
            echo json_encode([
                "success" => true,
                "message" => "Tạo đơn hàng thành công",
                "data" => [
                    "order_id" => $order_id,
                    "ma_don" => $ma_don,
                    "ho_ten" => $data['ho_ten'],
                    "tongtien" => $tongtien,
                    "tongtien_formatted" => number_format($tongtien),
                    "status" => $status,
                    "date_post" => date('d/m/Y H:i:s', $date_post)
                ]
            ]);
        } else {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi tạo đơn hàng: " . mysqli_error($conn)
            ]);
        }
        
    } elseif ($method === 'PUT') {
        // Cập nhật trạng thái đơn hàng hoặc địa chỉ
        $data = json_decode(file_get_contents("php://input"), true);
        
        // Kiểm tra action: update_address hoặc update_status
        $action = isset($data['action']) ? $data['action'] : 'update_status';
        
        if ($action === 'update_address') {
            // Cập nhật địa chỉ đơn hàng
            // Thử lấy user_id từ nhiều nguồn
            $user_id = 0;
            if (isset($data['user_id'])) {
                // Ưu tiên lấy từ request body
                $user_id = intval($data['user_id']);
            } elseif (isset($decoded->user_id)) {
                $user_id = intval($decoded->user_id);
            } elseif (isset($decoded->userId)) {
                $user_id = intval($decoded->userId);
            } elseif (isset($decoded->sub)) {
                $user_id = intval($decoded->sub);
            }
            
            $order_id = isset($data['order_id']) ? intval($data['order_id']) : 0;
            $ma_don = isset($data['ma_don']) ? addslashes($data['ma_don']) : '';
            
            // Validate
            if ($user_id <= 0) {
                http_response_code(401);
                echo json_encode([
                    "success" => false,
                    "message" => "Thông tin người dùng không hợp lệ"
                ]);
                exit;
            }
            
            if ($order_id <= 0 && empty($ma_don)) {
                http_response_code(400);
                echo json_encode([
                    "success" => false,
                    "message" => "Thiếu order_id hoặc ma_don"
                ]);
                exit;
            }
            
            // Lấy thông tin đơn hàng
            $where_clause = $order_id > 0 ? "id = $order_id" : "ma_don = '$ma_don'";
            $where_clause .= " AND user_id = $user_id";
            $order_query = "SELECT id, status FROM donhang WHERE $where_clause LIMIT 1";
            
            $order_result = mysqli_query($conn, $order_query);
            
            if (!$order_result) {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
                ]);
                exit;
            }
            
            if (mysqli_num_rows($order_result) == 0) {
                http_response_code(404);
                echo json_encode([
                    "success" => false,
                    "message" => "Không tìm thấy đơn hàng"
                ]);
                exit;
            }
            
            $order = mysqli_fetch_assoc($order_result);
            $order_status = intval($order['status']);
            
            // Chỉ cho phép sửa địa chỉ khi status = 0 (Chờ xử lý)
            if ($order_status != 0) {
                http_response_code(400);
                echo json_encode([
                    "success" => false,
                    "message" => "Chỉ có thể thay đổi địa chỉ khi đơn hàng ở trạng thái 'Chờ xử lý'"
                ]);
                exit;
            }
            
            // Lấy thông tin địa chỉ từ request
            $ho_ten = isset($data['ho_ten']) ? addslashes(trim($data['ho_ten'])) : '';
            $email = isset($data['email']) ? addslashes(trim($data['email'])) : '';
            $dien_thoai = isset($data['dien_thoai']) ? addslashes(trim($data['dien_thoai'])) : '';
            $dia_chi = isset($data['dia_chi']) ? addslashes(trim($data['dia_chi'])) : '';
            $tinh = isset($data['tinh']) ? intval($data['tinh']) : 0;
            $huyen = isset($data['huyen']) ? intval($data['huyen']) : 0;
            $xa = isset($data['xa']) ? intval($data['xa']) : 0;
            
            // Validate địa chỉ
            if (empty($ho_ten) || empty($dien_thoai) || empty($dia_chi) || $tinh <= 0 || $huyen <= 0 || $xa <= 0) {
                http_response_code(400);
                echo json_encode([
                    "success" => false,
                    "message" => "Vui lòng điền đầy đủ thông tin địa chỉ"
                ]);
                exit;
            }
            
            // Update địa chỉ đơn hàng
            $update_query = "UPDATE donhang SET 
                ho_ten = '$ho_ten',
                email = '$email',
                dien_thoai = '$dien_thoai',
                dia_chi = '$dia_chi',
                tinh = $tinh,
                huyen = $huyen,
                xa = $xa,
                date_update = " . time() . "
                WHERE id = " . intval($order['id']);
            
            $update_result = mysqli_query($conn, $update_query);
            
            if ($update_result) {
                http_response_code(200);
                echo json_encode([
                    "success" => true,
                    "message" => "Cập nhật địa chỉ đơn hàng thành công"
                ]);
            } else {
                http_response_code(500);
                echo json_encode([
                    "success" => false,
                    "message" => "Lỗi cập nhật địa chỉ: " . mysqli_error($conn)
                ]);
            }
            exit;
        }
        
        // Cập nhật trạng thái đơn hàng (code cũ)
        if (!isset($data['order_id']) || !isset($data['status'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu order_id hoặc status"
            ]);
            exit;
        }
        
        $order_id = intval($data['order_id']);
        $status = intval($data['status']);
        $date_update = time();
        
        // Validate status
        if (!in_array($status, [0, 1, 2, 3, 4])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Trạng thái không hợp lệ (0-4)"
            ]);
            exit;
        }
        
        // Lấy thông tin đơn hàng cũ (old_status) trước khi update
        $old_order_query = "SELECT status, ma_don, user_id FROM donhang WHERE id = $order_id LIMIT 1";
        $old_order_result = mysqli_query($conn, $old_order_query);
        $old_order = null;
        $old_status = null;
        $ma_don = null;
        $user_id_order = null;
        
        if ($old_order_result && mysqli_num_rows($old_order_result) > 0) {
            $old_order = mysqli_fetch_assoc($old_order_result);
            $old_status = intval($old_order['status']);
            $ma_don = $old_order['ma_don'];
            $user_id_order = intval($old_order['user_id']);
        }
        
        // Update database
        $update_query = "UPDATE donhang SET status = $status, date_update = $date_update WHERE id = $order_id";
        $result = mysqli_query($conn, $update_query);
        
        if ($result) {
            if (mysqli_affected_rows($conn) > 0) {
                // Trigger đã tự động INSERT notification vào bảng notification_mobile
                // Bây giờ cần gửi push notification cho notification vừa được tạo
                // Chỉ gửi nếu status thay đổi và có user_id hợp lệ
                if ($old_status !== null && $old_status != $status && $user_id_order > 0) {
                    // Gửi push notification ASYNC (sau khi response)
                    register_shutdown_function(function() use ($user_id_order, $order_id, $ma_don, $old_status, $status) {
                        try {
                            $logPath = __DIR__ . '/debug_push_notifications.log';
                            file_put_contents($logPath, date('c') . " | [ORDER_STATUS_UPDATE] Shutdown started - order_id=$order_id, user_id=$user_id_order\n", FILE_APPEND);
                            
                            // Kết nối DB mới
                            $tlca_data = array();
                            $tlca_data['server'] = 'localhost';
                            $tlca_data['dbuser'] = 'socdo';
                            $tlca_data['dbpassword'] = 'Xdnt.qOPNz8!(cQi';
                            $tlca_data['dbname'] = 'socdo';
                            $conn_async = @mysqli_connect($tlca_data['server'], $tlca_data['dbuser'], $tlca_data['dbpassword'], $tlca_data['dbname']);
                            
                            if (!$conn_async) {
                                file_put_contents($logPath, date('c') . " | [ORDER_STATUS_UPDATE] DB connection failed\n", FILE_APPEND);
                                return;
                            }
                            
                            $notification_file = __DIR__ . '/notification_mobile_helper.php';
                            $fcm_cfg = __DIR__ . '/fcm_config.php';
                            $fcm_svc = __DIR__ . '/fcm_push_service_v1.php';
                            
                            if (file_exists($notification_file) && file_exists($fcm_cfg) && file_exists($fcm_svc)) {
                            require_once $notification_file;
                            $notificationHelper = new NotificationMobileHelper($conn_async);
                            
                                // Gửi push cho notification vừa được trigger tạo
                                $result = $notificationHelper->sendPushForExistingNotification($user_id_order, $order_id, 'order');
                            
                                file_put_contents($logPath, date('c') . " | [ORDER_STATUS_UPDATE] Push sent - result: " . var_export($result, true) . "\n", FILE_APPEND);
                            } else {
                                file_put_contents($logPath, date('c') . " | [ORDER_STATUS_UPDATE] Missing FCM files\n", FILE_APPEND);
                            }
                            
                            mysqli_close($conn_async);
                        } catch (Throwable $e) {
                    $logPath = __DIR__ . '/debug_push_notifications.log';
                            file_put_contents($logPath, date('c') . " | [ORDER_STATUS_UPDATE] EXCEPTION: " . $e->getMessage() . "\n", FILE_APPEND);
                        }
                    });
                }
                
                $status_text = array(
                    0 => 'Chờ xác nhận',
                    1 => 'Đã xác nhận',
                    2 => 'Đang giao hàng', 
                    3 => 'Đã giao hàng',
                    4 => 'Đã hủy'
                );
                
                http_response_code(200);
                echo json_encode([
                    "success" => true,
                    "message" => "Cập nhật trạng thái đơn hàng thành công",
                    "data" => [
                        "order_id" => $order_id,
                        "status" => $status,
                        "status_text" => $status_text[$status],
                        "date_update" => date('d/m/Y H:i:s', $date_update)
                    ]
                ]);
            } else {
                http_response_code(404);
                echo json_encode([
                    "success" => false,
                    "message" => "Không tìm thấy đơn hàng"
                ]);
            }
        } else {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi cập nhật đơn hàng: " . mysqli_error($conn)
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
