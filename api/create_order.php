<?php
header('Content-Type: application/json; charset=utf-8');
// Harden output: capture and diagnose stray output and fatals
ini_set('display_errors', '0');
error_reporting(E_ALL);
ob_start();
register_shutdown_function(function() {
    $err = error_get_last();
    $buf = ob_get_contents();
    if ($err) {
        file_put_contents(__DIR__ . '/debug_create_order.log', date('Y-m-d H:i:s') . ' - FATAL: ' . json_encode($err, JSON_UNESCAPED_UNICODE) . "\n", FILE_APPEND);
    }
    if ($buf !== '' && $buf !== false) {
        file_put_contents(__DIR__ . '/debug_create_order.log', date('Y-m-d H:i:s') . ' - BUFFER: ' . substr($buf, 0, 500) . "\n", FILE_APPEND);
    }
});
header("Access-Control-Allow-Methods: POST, OPTIONS");
require_once './vendor/autoload.php';
require_once './includes/config.php';
// Include user_behavior_helper để lưu hành vi người dùng
$helper_path = __DIR__ . '/user_behavior_helper.php';
if (file_exists($helper_path)) {
    require_once $helper_path;
}
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Debug POST log
file_put_contents(__DIR__ . '/debug_create_order.log', date('Y-m-d H:i:s') . ' - ' . json_encode($_POST, JSON_UNESCAPED_UNICODE) . "\n", FILE_APPEND);

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
	http_response_code(200);
	exit;
}

$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

$headers = function_exists('apache_request_headers') ? apache_request_headers() : [];
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$jwt = null;
if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
	$jwt = $matches[1];
}

$user_id = isset($_POST['user_id']) ? intval($_POST['user_id']) : (isset($_GET['user_id']) ? intval($_GET['user_id']) : 0);

try {
	if (!$user_id && $jwt) {
		$decoded = JWT::decode($jwt, new Key($key, 'HS256'));
		if (!isset($decoded->iss) || $decoded->iss !== $issuer) {
			http_response_code(401);
			echo json_encode(["success" => false, "message" => "Issuer không hợp lệ"]);
			exit;
		}
		$user_id = isset($decoded->user_id) ? intval($decoded->user_id) : 0;
	}
	if ($user_id <= 0) {
		http_response_code(401);
		echo json_encode(["success" => false, "message" => "Thông tin người dùng không hợp lệ"]);
		exit;
	}

	if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
		http_response_code(405);
		echo json_encode(["success" => false, "message" => "Chỉ hỗ trợ phương thức POST"]);
		exit;
	}

	// Input
	$ho_ten = addslashes(trim($_POST['ho_ten'] ?? ''));
	$email = addslashes(trim($_POST['email'] ?? ''));
	$dien_thoai = addslashes(trim($_POST['dien_thoai'] ?? ''));
	$dia_chi = addslashes(trim($_POST['dia_chi'] ?? ''));
	$tinh = intval($_POST['tinh'] ?? 0);
	$huyen = intval($_POST['huyen'] ?? 0);
	$xa = intval($_POST['xa'] ?? 0);
	$sanpham = $_POST['sanpham'] ?? '[]'; // JSON string
	$thanhtoan = addslashes(trim($_POST['thanhtoan'] ?? 'COD'));
	$ghi_chu = addslashes(trim($_POST['ghi_chu'] ?? ''));
	$coupon = addslashes(trim($_POST['coupon'] ?? ''));
	$giam = intval($_POST['giam'] ?? 0);
	$voucher_tmdt = intval($_POST['voucher_tmdt'] ?? 0);
	$phi_ship = intval($_POST['phi_ship'] ?? 0);
	$ship_support = intval($_POST['ship_support'] ?? 0);
	$shipping_provider = addslashes(trim($_POST['shipping_provider'] ?? ''));
	$utm_source = addslashes(trim($_POST['utm_source'] ?? ''));
	$utm_campaign = addslashes(trim($_POST['utm_campaign'] ?? ''));

	// Basic validation
	if (!$ho_ten || !$dien_thoai || !$dia_chi || !$tinh || !$huyen) {
		http_response_code(400);
		echo json_encode(["success" => false, "message" => "Thiếu thông tin giao hàng bắt buộc"]);
		exit;
	}

	// Parse products and group by shop_id
	$items = json_decode($sanpham, true);
	if (!is_array($items)) $items = [];
	
	// Group products by shop_id
	$shop_orders = array();
	$total_tamtinh = 0;
	
	foreach ($items as $it) {
		$shop_id = intval($it['shop'] ?? 0);
		
		// Initialize shop order if not exists
		if (!isset($shop_orders[$shop_id])) {
			$shop_orders[$shop_id] = array(
				'shop_id' => $shop_id,
				'products' => array(),
				'tamtinh' => 0
			);
		}
		
		// Calculate line total
		$line_total = intval($it['thanh_tien'] ?? 0);
		if ($line_total <= 0) {
			$gia_moi = intval($it['gia_moi'] ?? 0);
			$qty = max(1, intval($it['quantity'] ?? 1));
			$line_total = $gia_moi * $qty;
		}
		
		// Add product to shop order
		$shop_orders[$shop_id]['products'][] = $it;
		$shop_orders[$shop_id]['tamtinh'] += $line_total;
		$total_tamtinh += $line_total;
	}
	
	// Calculate shipping and discounts for each shop (proportional to tamtinh)
	$created_orders = array();
	$hientai = time();
	$ma_don_base = 'DH' . date('ymdHis') . rand(100, 999);
	
	foreach ($shop_orders as $shop_id => &$shop_order) {
		// Calculate proportional values for this shop
		$shop_tamtinh = $shop_order['tamtinh'];
		$shop_ratio = ($total_tamtinh > 0) ? ($shop_tamtinh / $total_tamtinh) : 1;
		
		// Calculate shop-specific values (proportional)
		$shop_giam = ($giam > 0) ? ceil($giam * $shop_ratio) : 0;
		$shop_voucher_tmdt = ($voucher_tmdt > 0) ? ceil($voucher_tmdt * $shop_ratio) : 0;
		$shop_phi_ship = ($phi_ship > 0) ? ceil($phi_ship * $shop_ratio) : 0;
		$shop_ship_support = ($ship_support > 0) ? ceil($ship_support * $shop_ratio) : 0;
		
		// Calculate final total for this shop
		$shop_tongtien = max(0, $shop_tamtinh - $shop_giam - $shop_voucher_tmdt + $shop_phi_ship - $shop_ship_support);
		
		// Generate order code for this shop
		$ma_don = $ma_don_base . '_' . $shop_id;
		
		// ✅ Lấy shipping_provider riêng cho shop này từ item đầu tiên
		$shop_shipping_provider = $shipping_provider; // Fallback: dùng provider tổng hợp
		if (!empty($shop_order['products']) && is_array($shop_order['products'])) {
			$first_product = $shop_order['products'][0];
			if (isset($first_product['shipping_provider']) && !empty($first_product['shipping_provider'])) {
				$shop_shipping_provider = addslashes(trim($first_product['shipping_provider']));
				error_log("🚚 [CreateOrder] Shop $shop_id: Using provider from item = $shop_shipping_provider");
			} else {
				error_log("🚚 [CreateOrder] Shop $shop_id: No shipping_provider in item, using fallback = $shop_shipping_provider");
			}
		} else {
			error_log("🚚 [CreateOrder] Shop $shop_id: No products, using fallback = $shop_shipping_provider");
		}
		
		// Prepare product JSON for this shop
		$shop_sanpham_json = json_encode($shop_order['products'], JSON_UNESCAPED_UNICODE);
		$sanpham_sql = mysqli_real_escape_string($conn, $shop_sanpham_json);
		
		// Escape shop_id
		$shop_id_escaped = intval($shop_id);
		
		// Insert order for this shop
		$query = "INSERT INTO donhang (
			ma_don,minh_hoa,minh_hoa2,user_id,ho_ten,email,dien_thoai,dia_chi,tinh,huyen,xa,dropship,
			sanpham,tamtinh,coupon,giam,voucher_tmdt,phi_ship,tongtien,kho,status,thanhtoan,ghi_chu,
			utm_source,utm_campaign,date_update,date_post,shop_id,shipping_provider,ninja_response,ship_support
		) VALUES (
			'$ma_don','','','$user_id','$ho_ten','$email','$dien_thoai','$dia_chi','$tinh','$huyen','$xa','0',
			'$sanpham_sql','$shop_tamtinh','$coupon','$shop_giam','$shop_voucher_tmdt','$shop_phi_ship','$shop_tongtien','',0,'$thanhtoan','$ghi_chu',
			'$utm_source','$utm_campaign','$hientai','$hientai','$shop_id_escaped','$shop_shipping_provider','','$shop_ship_support'
		)";
		
		$ok = mysqli_query($conn, $query);
		if (!$ok) {
			http_response_code(500);
			echo json_encode(["success" => false, "message" => "Lỗi tạo đơn hàng cho shop_id $shop_id", "error" => mysqli_error($conn)]);
			exit;
		}
		
		$order_id = mysqli_insert_id($conn);
		$created_orders[] = array(
			'order_id' => $order_id,
			'ma_don' => $ma_don,
			'shop_id' => $shop_id,
			'tamtinh' => $shop_tamtinh,
			'giam' => $shop_giam,
			'voucher_tmdt' => $shop_voucher_tmdt,
			'phi_ship' => $shop_phi_ship,
			'ship_support' => $shop_ship_support,
			'tongtien' => $shop_tongtien
		);
		
		// Notification for shop
		if ($shop_id > 0) {
			$noidung_notification = "Bạn có đơn hàng sàn TMĐT: #$ma_don - $ho_ten - $dien_thoai";
			mysqli_query($conn, "INSERT INTO notification (user_id, sp_id, noi_dung, doc, bo_phan, admin, date_post) VALUES ('$shop_id_escaped','0','$noidung_notification','','donhang','0','$hientai')");
		}
	}
	unset($shop_order);
	
	// Calculate total for all orders
	$total_tongtien = 0;
	$total_giam = 0;
	$total_voucher_tmdt = 0;
	$total_phi_ship = 0;
	$total_ship_support = 0;
	foreach ($created_orders as $ord) {
		$total_tongtien += $ord['tongtien'];
		$total_giam += $ord['giam'];
		$total_voucher_tmdt += $ord['voucher_tmdt'];
		$total_phi_ship += $ord['phi_ship'];
		$total_ship_support += $ord['ship_support'];
	}

    // ✅ BỎ TẠO NOTIFICATION TRỰC TIẾP - ĐỂ QUEUE PROCESSOR XỬ LÝ
    // Notification sẽ được tạo bởi trigger tr_donhang_insert (AFTER INSERT) với push_sent = 0
    // Queue processor sẽ tự động xử lý notification với push_sent = 0
    // KHÔNG INSERT notification trực tiếp, KHÔNG gọi push notification ngay, KHÔNG dùng register_shutdown_function

    // Prepare response with all created orders
    $response_orders = array();
    foreach ($created_orders as $ord) {
		$response_orders[] = array(
			'ma_don' => $ord['ma_don'],
			'shop_id' => $ord['shop_id'],
			'order' => array(
				'user_id' => $user_id,
				'tamtinh' => $ord['tamtinh'],
				'giam' => $ord['giam'],
				'voucher_tmdt' => $ord['voucher_tmdt'],
				'phi_ship' => $ord['phi_ship'],
				'ship_support' => $ord['ship_support'],
				'tongtien' => $ord['tongtien'],
				'status' => 0,
				'date_post' => $hientai
			)
		);
	}
	
	$response = [
		'success' => true,
		'message' => 'Tạo đơn hàng thành công',
		'data' => [
			'ma_don' => $ma_don_base, // Base order code
			'orders' => $response_orders, // Array of orders grouped by shop
			'summary' => [
				'total_tamtinh' => $total_tamtinh,
				'total_giam' => $total_giam,
				'total_voucher_tmdt' => $total_voucher_tmdt,
				'total_phi_ship' => $total_phi_ship,
				'total_ship_support' => $total_ship_support,
				'total_tongtien' => $total_tongtien,
				'total_orders' => count($created_orders)
			]
		]
	];
    $payload = json_encode($response, JSON_UNESCAPED_UNICODE);
    file_put_contents(__DIR__ . '/debug_create_order.log', date('Y-m-d H:i:s') . ' - OUTPUT: ' . $payload . "\n", FILE_APPEND);
    http_response_code(200);
    // Clear any prior output before sending JSON
    if (ob_get_length() !== false) { ob_clean(); }
    echo $payload;
    flush();
    
    // Lưu hành vi đặt đơn (chạy sau khi response đã được gửi, không ảnh hưởng API)
    if (function_exists('saveUserBehavior') && $user_id > 0 && !empty($items)) {
        try {
            foreach ($items as $item) {
                $product_id = intval($item['product_id'] ?? $item['id'] ?? 0);
                if ($product_id <= 0) continue;
                
                // Lấy category_id từ sản phẩm
                $category_id = null;
                $cat_query = "SELECT cat FROM sanpham WHERE id = $product_id LIMIT 1";
                $cat_result = mysqli_query($conn, $cat_query);
                if ($cat_result && mysqli_num_rows($cat_result) > 0) {
                    $cat_row = mysqli_fetch_assoc($cat_result);
                    if (!empty($cat_row['cat'])) {
                        $cat_array = explode(',', $cat_row['cat']);
                        if (!empty($cat_array)) {
                            $category_id = intval(trim($cat_array[0]));
                        }
                    }
                }
                
                saveUserBehavior($conn, $user_id, 'order', $product_id, null, $category_id, [
                    'order_id' => $created_orders[0]['order_id'] ?? 0,
                    'ma_don' => $ma_don_base ?? '',
                    'product_title' => $item['tieu_de'] ?? '',
                    'product_price' => intval($item['gia_moi'] ?? 0),
                    'quantity' => intval($item['quantity'] ?? 1),
                    'total_amount' => intval($item['thanh_tien'] ?? 0),
                    'shop_id' => intval($item['shop'] ?? 0)
                ]);
            }
        } catch (Exception $e) {
            error_log("Error saving order behavior: " . $e->getMessage());
        }
    }
    
    // Kết thúc NGAY lập tức: hậu xử lý sẽ do cron/queue đảm nhiệm
    exit;

} catch (Exception $e) {
    $errPayload = json_encode(["success" => false, "message" => "Lỗi hệ thống", "error" => $e->getMessage()], JSON_UNESCAPED_UNICODE);
    file_put_contents(__DIR__ . '/debug_create_order.log', date('Y-m-d H:i:s') . ' - OUTPUT_ERR: ' . $errPayload . "\n", FILE_APPEND);
    http_response_code(500);
    if (ob_get_length() !== false) { ob_clean(); }
    echo $errPayload;
    flush();
    exit;
}
// No closing PHP tag to avoid stray output