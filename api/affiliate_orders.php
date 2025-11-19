<?php
/**
 * API: Affiliate Orders
 * Method: GET
 * URL: /v1/affiliate_orders?user_id={user_id}&page=1&limit=20
 * 
 * Description: Get list of orders with commission for affiliate
 * 
 * Response: {
 *   "success": true,
 *   "data": {
 *     "orders": [...],
 *     "pagination": {...}
 *   }
 * }
 */

require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

header('Content-Type: application/json; charset=utf-8');

// Get parameters
$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
$page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
$limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 100;
$get_all = isset($_GET['all']) && $_GET['all'] == '1';

if ($user_id <= 0) {
    // Fallback to JWT
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    
    if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        $jwt = $matches[1];
        
        try {
            $key_query = mysqli_query($conn, "SELECT value FROM index_setting WHERE name='key' LIMIT 1");
            $key_row = mysqli_fetch_assoc($key_query);
            $secret_key = $key_row['value'] ?? 'default_secret_key';
            
            $issuer_query = mysqli_query($conn, "SELECT value FROM index_setting WHERE name='issuer' LIMIT 1");
            $issuer_row = mysqli_fetch_assoc($issuer_query);
            $issuer = $issuer_row['value'] ?? 'default_issuer';
            
            $decoded = JWT::decode($jwt, new Key($secret_key, 'HS256'));
            
            if ($decoded->iss === $issuer) {
                $user_id = $decoded->data->user_id ?? 0;
            }
        } catch (Exception $e) {
            // JWT invalid
        }
    }
}

if ($user_id <= 0) {
    echo json_encode([
        'success' => false,
        'message' => 'User ID is required'
    ]);
    exit;
}

// Get orders with affiliate tracking (filter by utm_source)
$all_orders_query = "SELECT * FROM donhang WHERE utm_source = '$user_id' ORDER BY date_post DESC";
$all_orders_result = mysqli_query($conn, $all_orders_query);
$affiliate_orders = [];

while ($order = mysqli_fetch_assoc($all_orders_result)) {
    $products = json_decode($order['sanpham'], true);
    $total_commission = 0;
    $affiliate_products = [];
    
    if (is_array($products)) {
        foreach ($products as $key => $product) {
            // Parse sp_id from different JSON formats
            $sp_id = 0;
            $pl_id = 0;
            
            if (is_string($key) && strpos($key, '_') !== false) {
                $parts = explode('_', $key);
                $sp_id = intval($parts[0]);
                $pl_id = intval($parts[1]);
            } elseif (isset($product['id'])) {
                $sp_id = intval($product['id']);
                $pl_id = intval($product['pl'] ?? 0);
            } elseif (is_int($key) || ctype_digit($key)) {
                $sp_id = intval($key);
            } elseif (isset($product['sp_id'])) {
                $sp_id = intval($product['sp_id']);
                $pl_id = intval($product['pl'] ?? 0);
            }
            
            // Parse commission
            $commission_raw = $product['hoa_hong'] ?? 0;
            if (is_string($commission_raw)) {
                $commission = floatval(str_replace(',', '', $commission_raw));
            } else {
                $commission = floatval($commission_raw);
            }
            
            $total_commission += $commission;
            
            // Get product details from sanpham and phanloai_sanpham
            $product_name = $product['tieu_de'] ?? '';
            $product_image = $product['anh_chinh'] ?? $product['minh_hoa'] ?? '';
            $product_url = '';
            $shop_name = '';
            $variant_size = $product['size'] ?? '';
            $variant_color = $product['color'] ?? '';
            $variant_price = 0;
            $variant_old_price = 0;
            
            if ($sp_id > 0) {
                // Get product info
                $sp_query = "SELECT s.tieu_de, s.minh_hoa, s.slug, s.shop, u.name as shop_name 
                            FROM sanpham s 
                            LEFT JOIN user_info u ON s.shop = u.user_id 
                            WHERE s.id = '$sp_id' LIMIT 1";
                $sp_result = mysqli_query($conn, $sp_query);
                
                if ($sp_result && mysqli_num_rows($sp_result) > 0) {
                    $sp_data = mysqli_fetch_assoc($sp_result);
                    if (empty($product_name)) $product_name = $sp_data['tieu_de'];
                    if (empty($product_image)) $product_image = $sp_data['minh_hoa'];
                    $shop_name = $sp_data['shop_name'] ?? '';
                    
                    // Build product URL
                    $slug = $sp_data['slug'] ?? $product['link'] ?? '';
                    if ($slug) {
                        $product_url = "https://socdo.vn/san-pham/$sp_id/$slug.html";
                    } else {
                        $product_url = "https://socdo.vn/san-pham/$sp_id.html";
                    }
                }
                
                // Get variant info if exists
                if ($pl_id > 0) {
                    $pl_query = "SELECT ten_size, ten_color, gia_moi, gia_cu, image_phanloai 
                                FROM phanloai_sanpham 
                                WHERE id = '$pl_id' LIMIT 1";
                    $pl_result = mysqli_query($conn, $pl_query);
                    
                    if ($pl_result && mysqli_num_rows($pl_result) > 0) {
                        $pl_data = mysqli_fetch_assoc($pl_result);
                        $variant_size = $pl_data['ten_size'] ?? $variant_size;
                        $variant_color = $pl_data['ten_color'] ?? $variant_color;
                        $variant_price = intval($pl_data['gia_moi'] ?? 0);
                        $variant_old_price = intval($pl_data['gia_cu'] ?? 0);
                        if (!empty($pl_data['image_phanloai'])) {
                            $product_image = $pl_data['image_phanloai'];
                        }
                    }
                }
            }
            
            // Normalize image URL
            if ($product_image && strpos($product_image, 'http') !== 0) {
                $product_image = 'https://socdo.vn/' . ltrim($product_image, '/');
            }
            
            // Parse quantity and price
            $quantity = intval($product['quantity'] ?? $product['soluong'] ?? 1);
            
            $price_raw = $product['gia_moi'] ?? $product['gia'] ?? 0;
            if (is_string($price_raw)) {
                $price = intval(str_replace(',', '', $price_raw));
            } else {
                $price = intval($price_raw);
            }
            
            // Use variant price if available
            if ($variant_price > 0) {
                $price = $variant_price;
            }
            
            $affiliate_products[] = [
                'sp_id' => $sp_id,
                'variant_id' => $pl_id,
                'name' => $product_name,
                'image' => $product_image,
                'product_url' => $product_url,
                'quantity' => $quantity,
                'price' => $price,
                'price_formatted' => number_format($price) . 'đ',
                'old_price' => $variant_old_price,
                'old_price_formatted' => number_format($variant_old_price) . 'đ',
                'total' => $price * $quantity,
                'total_formatted' => number_format($price * $quantity) . 'đ',
                'size' => $variant_size,
                'color' => $variant_color,
                'shop_name' => $shop_name,
                'commission' => $commission,
                'commission_formatted' => number_format($commission) . 'đ'
            ];
        }
    }
    
    if (count($affiliate_products) > 0) {
        $affiliate_orders[] = [
            'order_data' => $order,
            'total_commission' => $total_commission,
            'affiliate_products' => $affiliate_products
        ];
    }
}

// Override limit nếu get_all = true
if ($get_all) {
    $limit = 999999;
    $page = 1;
}

$total_orders = count($affiliate_orders);
$total_pages = ceil($total_orders / $limit);

// Get orders for current page
$start = ($page - 1) * $limit;
$current_page_orders = array_slice($affiliate_orders, $start, $limit);

$orders = [];

$status_map = [
    0 => ['text' => 'Chờ xử lý', 'color' => '#FFA500'],
    1 => ['text' => 'Đã tiếp nhận đơn', 'color' => '#2196F3'],
    2 => ['text' => 'Đã giao đơn vị vận chuyển', 'color' => '#9C27B0'],
    3 => ['text' => 'Yêu cầu hủy đơn', 'color' => '#FF9800'],
    4 => ['text' => 'Đã hủy đơn', 'color' => '#F44336'],
    5 => ['text' => 'Giao thành công', 'color' => '#4CAF50'],
    6 => ['text' => 'Đã hoàn đơn', 'color' => '#607D8B']
];

foreach ($current_page_orders as $item) {
    $order = $item['order_data'];
    $status_info = $status_map[$order['status']] ?? $status_map[0];
    
    // Calculate commission stats
    $total_amount = floatval($order['tongtien']);
    $total_commission = $item['total_commission'];
    $commission_rate = $total_amount > 0 ? ($total_commission / $total_amount) * 100 : 0;
    
    // Commission status logic
    $commission_status = 'pending'; // Đang chờ
    $commission_status_text = 'Chờ xác nhận';
    $can_claim = false;
    
    if ((int) $order['status'] === 5) {
        // Đơn giao thành công
        $commission_status = 'completed';
        $commission_status_text = 'Đã thanh toán';
        $can_claim = false; // Đã được thanh toán tự động
    } elseif (in_array((int) $order['status'], [4, 6])) {
        // Đơn bị hủy hoặc hoàn
        $commission_status = 'cancelled';
        $commission_status_text = 'Đã hủy';
        $can_claim = false;
    } elseif (in_array((int) $order['status'], [0, 1, 2, 8, 10, 11, 12])) {
        // Đơn đang xử lý
        $commission_status = 'processing';
        $commission_status_text = 'Đang xử lý';
        $can_claim = false;
    }
    
    $orders[] = [
        'order_id' => (int) $order['id'],
        'ma_don' => $order['ma_don'],
        'products' => $item['affiliate_products'],
        'product_count' => count($item['affiliate_products']),
        
        // Financial info
        'subtotal' => intval($order['tamtinh']),
        'subtotal_formatted' => number_format($order['tamtinh']) . 'đ',
        'shipping_fee' => intval($order['phi_ship']),
        'shipping_fee_formatted' => number_format($order['phi_ship']) . 'đ',
        'discount' => intval($order['giam']) + intval($order['voucher_tmdt'] ?? 0),
        'discount_formatted' => number_format(intval($order['giam']) + intval($order['voucher_tmdt'] ?? 0)) . 'đ',
        'total_amount' => intval($total_amount),
        'total_amount_formatted' => number_format($total_amount) . 'đ',
        
        // Commission info
        'commission' => intval($total_commission),
        'commission_formatted' => number_format($total_commission) . 'đ',
        'commission_rate' => round($commission_rate, 2),
        'commission_rate_formatted' => round($commission_rate, 2) . '%',
        'commission_status' => $commission_status,
        'commission_status_text' => $commission_status_text,
        'can_claim_commission' => $can_claim,
        'commission_paid_at' => (int) $order['status'] === 5 && $order['date_update'] ? date('d/m/Y H:i', $order['date_update']) : null,
        
        // Order status
        'status' => [
            'code' => (int) $order['status'],
            'text' => $status_info['text'],
            'color' => $status_info['color']
        ],
    
        // Payment & Shipping
        'payment_method' => $order['thanhtoan'] ?? 'COD',
        'shipping_provider' => $order['shipping_provider'] ?? '',
        // Tracking info
        'short_link' => "https://socdo.xyz/x/" . ($order['ma_don'] ?? ''),
        'click_count' => 0, // Cần JOIN với rut_gon_shop nếu muốn lấy clicks
        // Dates
        'date_post' => intval($order['date_post']),
        'date_post_formatted' => date('d/m/Y H:i', $order['date_post']),
        'date_update' => intval($order['date_update']),
        'date_update_formatted' => $order['date_update'] > 0 ? date('d/m/Y H:i', $order['date_update']) : '',
        // Customer privacy (limited for affiliate)
        'has_customer_bought_before' => false, // Có thể thêm logic kiểm tra
        'is_first_order' => true // Có thể thêm logic kiểm tra
    ];
}

echo json_encode([
    'success' => true,
    'data' => [
        'orders' => $orders,
        'pagination' => [
            'current_page' => $page,
            'total_pages' => $total_pages,
            'total_orders' => $total_orders,
            'limit' => $limit
        ]
    ]
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

