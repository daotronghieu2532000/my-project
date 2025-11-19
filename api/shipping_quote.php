<?php
header("Access-Control-Allow-Methods: GET, POST");

// Bật bắt lỗi để trả JSON thay vì HTTP 500 trắng
error_reporting(E_ALL);
ini_set('display_errors', '0');
set_error_handler(function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});
function json_fatal($msg, $debug = [])
{
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $msg, 'debug' => $debug], JSON_UNESCAPED_UNICODE);
    exit;
}

// Database connection (inherit from global scope or create new)
if (!isset($conn) || !$conn) {
    $conn = mysqli_connect("localhost", "socdo", "Viettel@123", "socdo");
    if (!$conn) {
        json_fatal('Database connection failed: ' . mysqli_connect_error());
    }
    mysqli_set_charset($conn, "utf8mb4");
}

// Tải autoload an toàn (đường dẫn linh hoạt)
$autoload_paths = [__DIR__ . '/vendor/autoload.php', __DIR__ . '/../vendor/autoload.php', __DIR__ . '/../../vendor/autoload.php'];
$autoload_loaded = false;
foreach ($autoload_paths as $p) {
    if (file_exists($p)) {
        require_once $p;
        $autoload_loaded = true;
        break;
    }
}
// ✅ Chỉ import JWT classes nếu autoload đã được load
// Nếu không có vendor, sẽ dùng fallback HS256 thủ công (không dừng)
if ($autoload_loaded) {
    // Chỉ import khi autoload đã sẵn sàng
    // Sử dụng fully qualified name để tránh lỗi khi class không tồn tại
}

// JWT config
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

// Authorization header (fallback getallheaders/$_SERVER)
if (!function_exists('apache_request_headers')) {
    function apache_request_headers()
    {
        return function_exists('getallheaders') ? getallheaders() : [];
    }
}
$headers = apache_request_headers();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(array("message" => "Không tìm thấy token"));
    exit;
}

$jwt = $matches[1];

try {
    // Decode JWT
    if ($autoload_loaded && class_exists('\Firebase\JWT\JWT')) {
        // ✅ Sử dụng fully qualified class name và kiểm tra class tồn tại
        $decoded = \Firebase\JWT\JWT::decode($jwt, new \Firebase\JWT\Key($key, 'HS256'));
        if ($decoded->iss !== $issuer) {
            http_response_code(401);
            echo json_encode(array("message" => "Issuer không hợp lệ"));
            exit;
        }
    } else {
        // Fallback xác thực HS256 thủ công nếu thiếu vendor
        $parts = explode('.', $jwt);
        if (count($parts) !== 3) json_fatal('JWT không hợp lệ (parts)', ['paths_tried' => $autoload_paths]);
        list($h64, $p64, $s64) = $parts;
        $header = json_decode(base64_decode(strtr($h64, '-_', '+/')), true);
        $payload = json_decode(base64_decode(strtr($p64, '-_', '+/')), true);
        if (!$header || !$payload || ($header['alg'] ?? '') !== 'HS256') json_fatal('JWT không hợp lệ (alg)', ['paths_tried' => $autoload_paths]);
        $sig = base64_decode(strtr($s64, '-_', '+/'));
        $expect = hash_hmac('sha256', $h64 . '.' . $p64, $key, true);
        if (!hash_equals($expect, $sig)) json_fatal('JWT signature sai', ['paths_tried' => $autoload_paths]);
        if (($payload['iss'] ?? '') !== $issuer) json_fatal('Issuer không hợp lệ', ['paths_tried' => $autoload_paths]);
        if (isset($payload['exp']) && time() >= intval($payload['exp'])) json_fatal('JWT đã hết hạn', ['paths_tried' => $autoload_paths]);
        $decoded = (object)$payload;
    }

    // Helper: get 'mien' of a province name from tinh_moi (giống checkout.php)
    function get_mien_by_province($conn, $province_name)
    {
        $stmt = mysqli_prepare($conn, "SELECT mien FROM tinh_moi WHERE tieu_de LIKE ? LIMIT 1");
        if (!$stmt) {
            return 'mien-nam'; // default fallback
        }
        $keyword = "%" . $province_name . "%";
        mysqli_stmt_bind_param($stmt, "s", $keyword);
        mysqli_stmt_execute($stmt);
        mysqli_stmt_bind_result($stmt, $mien);
        if ($stmt->fetch()) {
            $stmt->close();
            return $mien;
        }
        $stmt->close();
        return 'mien-nam'; // default fallback
    }

    // Helper: get 'mien' of a province name from tinh_moi (fallback function)
    function get_mien_by_province_name($conn, $provinceName)
    {
        if (empty($provinceName)) return 'mien-nam';
        // Nếu không có kết nối DB thì fallback đơn giản theo tên tỉnh
        if (!$conn) {
            $name = mb_strtolower($provinceName, 'UTF-8');
            // Bắc: Hà Nội, Hải Phòng, Quảng Ninh, Bắc Ninh, Bắc Giang, Nam Định, Thái Nguyên, Hải Dương, Thái Bình, Ninh Bình, Hòa Bình, Phú Thọ...
            $is_mien_bac = preg_match('/hà nội|hai phong|hải phòng|quảng ninh|bac ninh|bắc ninh|bắc giang|bac giang|nam định|thái nguyên|thai nguyen|hải dương|hai duong|thái bình|thai binh|ninh bình|ninh binh|phú thọ|phu tho|hoà bình|hòa bình|hoa binh/i', $name);
            return $is_mien_bac ? 'mien-bac' : 'mien-nam';
        }
        $kw = mysqli_real_escape_string($conn, $provinceName);
        $sql = "SELECT mien FROM tinh_moi WHERE tieu_de LIKE '%$kw%' LIMIT 1";
        $res = mysqli_query($conn, $sql);
        if ($res && ($row = mysqli_fetch_assoc($res))) {
            return $row['mien'] ?: 'mien-nam';
        }
        return 'mien-nam';
    }

    // Hàm tính phí ship giống checkout.php
    function calculateShippingFee($provider, $sender_province, $sender_district, $receiver_province, $receiver_district, $sender_ward, $receiver_ward, $weight, $amount, $class_ghtk, $class_superai, $class_best, $class_spx)
    {
        global $conn;
        
        // Kiểm tra địa chỉ nhận hàng trước khi tính phí
        if (empty($receiver_province) || empty($receiver_district)) {
            return [
                'fee' => 0,
                'provider' => 'Chưa có địa chỉ',
                'provider_code' => 'NO_ADDRESS'
            ];
        }
        
        // Debug địa chỉ gửi và nhận
        error_log("🚢 SHIPPING CALCULATION: $provider");
        error_log("🚢   SENDER: $sender_province, $sender_district");
        error_log("🚢   RECEIVER: $receiver_province, $receiver_district");
        error_log("🚢   WEIGHT: $weight g, VALUE: $amount VND");
        
        $shipping_fee = 0;
        $provider_name = '';
        switch (strtoupper($provider)) {
            case 'GHTK':
                // GHTK sử dụng bảng giá cố định thay vì API
                try {
                    // Xác định miền gửi và nhận
                    $sender_mien = get_mien_by_province($conn, $sender_province);
                    $receiver_mien = get_mien_by_province($conn, $receiver_province);
                    
                    // Gọi hàm get_tax với các tham số cần thiết
                    $ghtk_response = $class_ghtk->get_tax(
                        $weight,              // Cân nặng (gram)
                        $amount,              // Tiền hàng
                        $sender_province,     // Tỉnh gửi
                        $sender_mien,         // Miền gửi
                        $receiver_province,   // Tỉnh nhận
                        $receiver_mien,       // Miền nhận
                        false,                // COD (mặc định false)
                        false                 // Giao lại (mặc định false)
                    );
                    
                    $ghtk_result = json_decode($ghtk_response, true);
                    if (isset($ghtk_result['phi_tong']) && $ghtk_result['phi_tong'] > 0) {
                        $shipping_fee = $ghtk_result['phi_tong'];
                        error_log("🚢 GHTK RESULT: phi_tong=$shipping_fee");
                        error_log("🚢 GHTK DETAILS: " . json_encode($ghtk_result));
                    } else {
                        $shipping_fee = 0;
                        error_log("🚢 GHTK RESULT: No fee returned");
                    }
                } catch (Exception $e) {
                    // Exception - không tính phí ship
                    $shipping_fee = 0;
                }
                
                $provider_name = 'GHTK';
                break;
            // case 'BEST':
            //     // BEST sử dụng bảng giá cố định - TẠM COMMENT VÌ CHƯA HOẠT ĐỘNG
            //     // Sẽ dùng lại sau vài tháng
            //     $shipping_fee = 0;
            //     $provider_name = 'BEST (Disabled)';
            //     break;
            case 'SPX':
                // SPX sử dụng bảng giá cố định
                try {
                    // Xác định miền gửi và nhận
                    $sender_mien = get_mien_by_province($conn, $sender_province);
                    $receiver_mien = get_mien_by_province($conn, $receiver_province);
                    
                    error_log("🚢 SPX MIEN: sender=$sender_mien, receiver=$receiver_mien");
                    
                    // Gọi hàm get_tax với các tham số cần thiết
                    $spx_response = $class_spx->get_tax(
                        $weight,              // Cân nặng (gram)
                        $amount,              // Tiền hàng
                        $sender_province,     // Tỉnh gửi
                        $sender_mien,         // Miền gửi
                        $receiver_province,   // Tỉnh nhận
                        $receiver_mien,       // Miền nhận
                        false,                // COD (mặc định false)
                        false                 // Giao lại (mặc định false)
                    );
                    $spx_result = json_decode($spx_response, true);
                    if (isset($spx_result['phi_tong']) && $spx_result['phi_tong'] > 0) {
                        $shipping_fee = $spx_result['phi_tong'];
                        error_log("🚢 SPX RESULT: phi_tong=$shipping_fee");
                        error_log("🚢 SPX DETAILS: " . json_encode($spx_result));
                    } else {
                        $shipping_fee = 0;
                        error_log("🚢 SPX RESULT: No fee returned");
                    }
                } catch (Exception $e) {
                    // Exception - không tính phí ship
                    $shipping_fee = 0;
                }
                
                $provider_name = 'SPX-EXPRESS';
                break;
            case 'SUPERAI':
            default:
                // SUPERAI API call - weight phải là gram
                $superai_data = array(
                    "sender_province" => $sender_province,
                    "sender_district" => $sender_district,
                    "receiver_province" => $receiver_province,
                    "receiver_district" => $receiver_district,
                    "weight" => $weight, // SUPERAI yêu cầu weight theo gram
                    "value" => $amount
                );
                try {
                    $superai_response = $class_superai->get_fee(
                        $sender_province,
                        $sender_district,
                        $receiver_province,
                        $receiver_district,
                        $weight,
                        $amount
                    );
                    $superai_result = json_decode($superai_response, true);
                    // Debug log SUPERAI response
                    if (isset($superai_result['error']) && $superai_result['error'] === false && isset($superai_result['data']['services'])) {
                        // Tìm carrier có phí ship thấp nhất
                        $best_service = null;
                        $lowest_total_fee = PHP_INT_MAX;
                        // Danh sách ưu tiên carrier (càng thấp càng ưu tiên)
                        $carrier_priority = [
                            10 => 1,  // SPX Express - ưu tiên cao nhất
                            6  => 2,  // BEST Express
                            3  => 3,  // J&T Express  
                            13 => 4,  // VietNamPost
                            2  => 5,  // GHN
                            4  => 6,  // Viettel Post
                            14 => 7,  // Lazada Express
                            // Ninja Van (carrier_id: 7) đã bị loại bỏ
                        ];
                        foreach ($superai_result['data']['services'] as $service) {
                            // Loại bỏ Ninja Van vì không hoạt động nữa
                            if (isset($service['carrier_id']) && $service['carrier_id'] == 7) {
                                continue;
                            }
                            $total_fee = ($service['shipment_fee'] ?? 0) + ($service['insurance_fee'] ?? 0);
                            $carrier_id = $service['carrier_id'] ?? 0;
                            $current_priority = $carrier_priority[$carrier_id] ?? 999; // 999 = lowest priority for unknown carriers
                            // Chọn service tốt hơn nếu:
                            // 1. Phí thấp hơn, HOẶC
                            // 2. Phí bằng nhau nhưng priority cao hơn (số nhỏ hơn)
                            $should_select = false;
                            if ($total_fee < $lowest_total_fee) {
                                $should_select = true;
                            } elseif ($total_fee == $lowest_total_fee && $best_service) {
                                $best_priority = $carrier_priority[$best_service['carrier_id'] ?? 0] ?? 999;
                                if ($current_priority < $best_priority) {
                                    $should_select = true;
                                }
                            }
                            if ($should_select) {
                                $lowest_total_fee = $total_fee;
                                $best_service = $service;
                            }
                        }
                        if ($best_service) {
                            $shipping_fee = $lowest_total_fee;
                            $provider_name = 'SUPERAI (' . ($best_service['carrier_name'] ?? 'Unknown') . ')';
                            // Tạo provider_code với format SUPERAI-carrier_id-carrier_name
                            $carrier_id = $best_service['carrier_id'] ?? 0;
                            $carrier_name = $best_service['carrier_name'] ?? 'Unknown';
                            $provider_code_superai = 'SUPERAI-' . $carrier_id . '-' . $carrier_name;
                        } else {
                            $shipping_fee = 0;
                            $provider_name = 'SUPERAI';
                            $provider_code_superai = 'SUPERAI';
                        }
                    } else {
                        // API lỗi - không tính phí ship
                        $shipping_fee = 0;
                        $provider_name = 'SUPERAI';
                        $provider_code_superai = 'SUPERAI';
                    }
                } catch (Exception $e) {
                    // Exception - không tính phí ship
                    $shipping_fee = 0;
                    $provider_name = 'SUPERAI';
                    $provider_code_superai = 'SUPERAI';
                }
                break;
        }
        // Sử dụng provider_code_superai nếu là SUPERAI, otherwise dùng $provider
        $final_provider_code = (strtoupper($provider) === 'SUPERAI' && isset($provider_code_superai))
            ? $provider_code_superai
            : $provider;
        return [
            'fee' => $shipping_fee,
            'provider' => $provider_name,
            'provider_code' => $final_provider_code
        ];
    }

    // Hàm tìm provider tốt nhất giống checkout.php
    function getBestShippingProvider($shipping_providers, $sender_province, $sender_district, $receiver_province, $receiver_district, $sender_ward, $receiver_ward, $weight, $amount, $class_ghtk, $class_superai, $class_best, $class_spx)
    {
        $best_provider = null;
        $lowest_fee = PHP_INT_MAX;
        $all_providers_data = [];
        // Tính phí cho tất cả providers
        foreach ($shipping_providers as $provider) {
            $shipping_data = calculateShippingFee(
                $provider,
                $sender_province,
                $sender_district,
                $receiver_province,
                $receiver_district,
                $sender_ward,
                $receiver_ward,
                $weight,
                $amount,
                $class_ghtk,
                $class_superai,
                $class_best,
                $class_spx
            );
            $all_providers_data[] = $shipping_data;
            // Chỉ chọn provider có phí > 0 và thấp nhất
            if ($shipping_data['fee'] > 0 && $shipping_data['fee'] < $lowest_fee) {
                $lowest_fee = $shipping_data['fee'];
                $best_provider = $shipping_data;
            }
        }
        // Nếu không có provider nào trả về phí > 0, thử fallback GHTK
        if (!$best_provider || $lowest_fee === PHP_INT_MAX) {
            $ghtk_fallback = calculateShippingFee(
                'GHTK',
                $sender_province,
                $sender_district,
                $receiver_province,
                $receiver_district,
                $sender_ward,
                $receiver_ward,
                $weight,
                $amount,
                $class_ghtk,
                $class_superai,
                $class_best,
                $class_spx
            );
            if ($ghtk_fallback['fee'] > 0) {
                $best_provider = $ghtk_fallback;
            }
        }
        $result = $best_provider ?: [
            'fee' => 0,
            'provider' => 'Không có',
            'provider_code' => ''
        ];
        return $result;
    }

    // Khởi tạo mảng debug
    $debug = [
        'mode' => '',
        'item_weights' => [],
        'shop_freeship_details' => [],
        'freeship_excluded' => []
    ];

    // Load class files: ƯU TIÊN include trực tiếp từ cùng thư mục với API
    $class_ghtk = null;
    $class_superai = null;
    $class_best = null;
    $class_spx = null;
    $candidate_paths = [
        __DIR__ . '/class_ghtk.php' => 'class_ghtk',
        __DIR__ . '/class_superai.php' => 'class_superai',
        __DIR__ . '/class_best.php' => 'class_best',
        __DIR__ . '/class_spx.php' => 'class_spx',
        '/home/socdo.vn/public_html/includes/class_ghtk.php' => 'class_ghtk',
        '/home/socdo.vn/public_html/includes/class_superai.php' => 'class_superai',
        '/home/socdo.vn/public_html/includes/class_best.php' => 'class_best',
        '/home/socdo.vn/public_html/includes/class_spx.php' => 'class_spx',
    ];
    foreach ($candidate_paths as $path => $className) {
        if (!class_exists($className) && file_exists($path)) {
            // dùng include thay vì loader để tránh phụ thuộc môi trường
            include_once $path;
            $debug['paths_checked'][] = ['path' => $path, 'exists' => 1, 'class' => $className, 'class_exists' => class_exists($className) ? 1 : 0, 'how' => 'include_once'];
        } else {
            $debug['paths_checked'][] = ['path' => $path, 'exists' => file_exists($path) ? 1 : 0, 'class' => $className, 'class_exists' => class_exists($className) ? 1 : 0, 'how' => 'skip'];
        }
    }
    // Sau khi include thủ công, nếu vẫn chưa có class, thử qua loader nếu có
    if ((!class_exists('class_ghtk') || !class_exists('class_superai') || !class_exists('class_best') || !class_exists('class_spx')) && isset($tlca_do)) {
        try {
            if (!class_exists('class_ghtk')) {
                $class_ghtk = $tlca_do->load('class_ghtk');
                $debug['loader_used_ghtk'] = true;
            }
        } catch (Throwable $e) {
            $debug['loader_err_ghtk'] = $e->getMessage();
        }
        try {
            if (!class_exists('class_superai')) {
                $class_superai = $tlca_do->load('class_superai');
                $debug['loader_used_superai'] = true;
            }
        } catch (Throwable $e) {
            $debug['loader_err_superai'] = $e->getMessage();
        }
        try {
            if (!class_exists('class_best')) {
                $class_best = $tlca_do->load('class_best');
                $debug['loader_used_best'] = true;
            }
        } catch (Throwable $e) {
            $debug['loader_err_best'] = $e->getMessage();
        }
        try {
            if (!class_exists('class_spx')) {
                $class_spx = $tlca_do->load('class_spx');
                $debug['loader_used_spx'] = true;
            }
        } catch (Throwable $e) {
            $debug['loader_err_spx'] = $e->getMessage();
        }
    }
    // Instantiate if classes are available
    if (!$class_ghtk && class_exists('class_ghtk')) {
        $class_ghtk = new class_ghtk();
    }
    if (!$class_superai && class_exists('class_superai')) {
        $class_superai = new class_superai();
    }
    if (!$class_best && class_exists('class_best')) {
        $class_best = new class_best();
    }
    if (!$class_spx && class_exists('class_spx')) {
        $class_spx = new class_spx();
    }
    $debug['class_status']['class_ghtk'] = $class_ghtk ? true : false;
    $debug['class_status']['class_superai'] = $class_superai ? true : false;
    $debug['class_status']['class_best'] = $class_best ? true : false;
    $debug['class_status']['class_spx'] = $class_spx ? true : false;

    if (!$class_ghtk || !$class_superai) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Thiếu file class vận chuyển. Hãy tải lên class_ghtk.php và class_superai.php vào thư mục: /home/themes/socdo/action/process",
            "hint" => __DIR__
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $method = $_SERVER['REQUEST_METHOD'];
    // Accept both GET (query) and POST (JSON)
    $params = [];
    if ($method === 'POST') {
        $raw = file_get_contents('php://input');
        $decodedBody = json_decode($raw, true);
        if (is_array($decodedBody)) $params = $decodedBody;
    }
    if ($method === 'GET') {
        $params = $_GET;
    }

    // Input params (mode 1: explicit address + totals)
    $sender_province   = trim($params['sender_province'] ?? '');
    $sender_district   = trim($params['sender_district'] ?? '');
    $sender_ward       = trim($params['sender_ward'] ?? '');
    $receiver_province = trim($params['receiver_province'] ?? '');
    $receiver_district = trim($params['receiver_district'] ?? '');
    $receiver_ward     = trim($params['receiver_ward'] ?? '');
    $weight            = intval($params['weight'] ?? 0); // gram
    $value             = intval($params['value'] ?? 0);  // VND
    $length            = floatval($params['length'] ?? 0); // cm (reserved)
    $width             = floatval($params['width'] ?? 0);  // cm (reserved)
    $height            = floatval($params['height'] ?? 0); // cm (reserved)

    // Input params (mode 2: user_id + items -> server tự tính tổng + địa chỉ mặc định)
    $user_id = intval($params['user_id'] ?? 0);
    $items = $params['items'] ?? [];
    if (!empty($items)) {
        $debug['mode'] = 'user_id+items';
        $debug['items_input'] = $items; // Log input items
        // Tính tổng từ DB sanpham
        $total_weight = 0; // gram
        $total_value = 0;  // VND
        $debug['item_weights'] = [];
        foreach ($items as $it) {
            $pid = intval($it['product_id'] ?? 0);
            $qty = max(1, intval($it['quantity'] ?? 1));
            if ($pid <= 0) continue;
            if (isset($conn) && $conn) {
                $q = mysqli_query($conn, "SELECT gia_moi, can_nang_tinhship, shop FROM sanpham WHERE id='$pid' LIMIT 1");
                $debug['query_executed'] = "SELECT gia_moi, can_nang_tinhship, shop FROM sanpham WHERE id='$pid' LIMIT 1";
                if (!$q) {
                    $debug['query_error'] = mysqli_error($conn);
                }
                if ($q && mysqli_num_rows($q) > 0) {
                    $r = mysqli_fetch_assoc($q);
                    $price = intval($r['gia_moi'] ?? 0);
                    $shopOfItem = intval($r['shop'] ?? 0);

                    // can_nang_tinhship trong DB là INT (gram), không có đơn vị
                    $w_gram_per_item = intval($r['can_nang_tinhship'] ?? 0);

                    // Nếu không có hoặc = 0, dùng mặc định 500g
                    if ($w_gram_per_item <= 0) {
                        $w_gram_per_item = 500;
                    }

                    // Giới hạn an toàn: 30g - 100000g (0.03kg - 100kg) - tăng giới hạn cho sản phẩm lớn
                    if ($w_gram_per_item < 30) $w_gram_per_item = 30;
                    if ($w_gram_per_item > 100000) $w_gram_per_item = 100000;
                    $line_value = $price * $qty;
                    $line_weight = $w_gram_per_item * $qty;
                    $total_value += $line_value;
                    $total_weight += $line_weight;
                    $debug['item_weights'][] = [
                        'product_id' => $pid,
                        'qty' => $qty,
                        'w_gram_per_item' => $w_gram_per_item,
                        'price' => $price,
                        'line_value' => $line_value,
                        'line_weight' => $line_weight,
                        'shop' => $shopOfItem
                    ];
                } else {
                    $debug['db_error'] = isset($conn) ? mysqli_error($conn) : 'no conn';
                }
            } else {
                $debug['db_error'] = 'no mysqli $conn available to read sanpham';
            }
        }
        if ($total_weight > 0) $weight = $total_weight;
        if ($total_value  > 0) $value  = $total_value;
        $debug['totals'] = ['weight' => $weight, 'value' => $value];
        // Debug chi tiết cân nặng từng sản phẩm
        $debug['weight_breakdown'] = [
            'total_items' => count($items),
            'total_weight_grams' => $weight,
            'total_weight_kg' => round($weight / 1000, 3),
            'items_detail' => $debug['item_weights'] ?? []
        ];

        // Lấy địa chỉ mặc định của user làm receiver nếu chưa truyền vào
        if ($user_id > 0 && (empty($receiver_province) || empty($receiver_district))) {
            if (isset($conn) && $conn) {
                $rs = mysqli_query($conn, "SELECT ten_tinh, ten_huyen, ten_xa FROM dia_chi WHERE user_id='$user_id' AND active='1' LIMIT 1");
                if ($rs && mysqli_num_rows($rs) > 0) {
                    $addr = mysqli_fetch_assoc($rs);
                    $receiver_province = $addr['ten_tinh'] ?? $receiver_province;
                    $receiver_district = $addr['ten_huyen'] ?? $receiver_district;
                    $receiver_ward     = $addr['ten_xa'] ?? $receiver_ward;
                } else {
                    $debug['db_error'] = isset($conn) ? mysqli_error($conn) : 'no conn';
                }
            } else {
                $debug['db_error'] = 'no mysqli $conn available to read dia_chi';
            }
        }
        // Lấy vị trí kho từ shop (giống checkout.php)
        if (empty($sender_province) || empty($sender_district)) {
            // Lấy shop đầu tiên từ items để xác định vị trí kho
            $first_shop = null;
            foreach (($debug['item_weights'] ?? []) as $item) {
                $first_shop = intval($item['shop'] ?? 0);
                if ($first_shop > 0) break;
            }
            
            if ($first_shop > 0 && isset($conn) && $conn) {
                // Lấy vị trí kho từ transport table
                $warehouse_query = "SELECT t.province, t.district, 
                                          tm.tieu_de as province_name, 
                                          hm.tieu_de as district_name
                                   FROM transport t
                                   LEFT JOIN tinh_moi tm ON t.province = tm.id
                                   LEFT JOIN huyen_moi hm ON t.district = hm.id
                                   WHERE t.user_id = '$first_shop' AND t.is_default = 1
                                   LIMIT 1";
                
                $warehouse_result = mysqli_query($conn, $warehouse_query);
                if ($warehouse_result && mysqli_num_rows($warehouse_result) > 0) {
                    $warehouse_data = mysqli_fetch_assoc($warehouse_result);
                    $sender_province = $warehouse_data['province_name'] ?? 'Thành phố Hà Nội';
                    $sender_district = $warehouse_data['district_name'] ?? 'Nam Từ Liêm';
                    
                    error_log("🚢 WAREHOUSE LOCATION: Shop $first_shop -> $sender_province, $sender_district");
                    error_log("🚢 WAREHOUSE QUERY: $warehouse_query");
                    error_log("🚢 WAREHOUSE DATA: " . json_encode($warehouse_data));
                } else {
                    // Fallback nếu không tìm thấy kho
                    $sender_province = 'Thành phố Hà Nội';
                    $sender_district = 'Nam Từ Liêm';
                    error_log("🚢 WAREHOUSE FALLBACK: Shop $first_shop -> Hà Nội, Nam Từ Liêm");
                    error_log("🚢 WAREHOUSE QUERY FAILED: $warehouse_query");
                    error_log("🚢 WAREHOUSE ERROR: " . mysqli_error($conn));
                }
            } else {
                // Fallback nếu không có shop
                $sender_province = 'Thành phố Hà Nội';
                $sender_district = 'Nam Từ Liêm';
                error_log("🚢 WAREHOUSE FALLBACK: No shop found -> Hà Nội, Nam Từ Liêm");
            }
        }
    }

    // Basic validations
    if (empty($sender_province) || empty($sender_district) || empty($receiver_province) || empty($receiver_district)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Thiếu địa chỉ gửi/nhận (province, district)", "debug" => $debug], JSON_UNESCAPED_UNICODE);
        exit;
    }
    if ($weight <= 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Thiếu hoặc sai trọng lượng (weight, gram)", "debug" => $debug], JSON_UNESCAPED_UNICODE);
        exit;
    }

    // Freeship: chuẩn bị loại trừ trọng lượng và hỗ trợ tiền ship theo cấu hình transport
    $exclude_weight = 0; // loại trừ trọng lượng (gram) cho item được freeship theo shop=1 hoặc per-product
    $exclude_value  = 0; // loại trừ giá trị (VND)
    $ship_fixed_support = 0; // giảm cố định theo mode 0
    $ship_percent_support = 0; // giảm theo % theo mode 2 (cộng dồn, tối đa 100)
    $debug['shop_freeship_details'] = [];
    $product_freeship_info = []; // Thông tin freeship cho từng sản phẩm

    error_log('🚢 DEBUG: items=' . json_encode($items) . ', has_conn=' . (isset($conn) && $conn ? 'YES' : 'NO'));

    if (!empty($items) && isset($conn) && $conn) {
        error_log('🚢 FREESHIP LOGIC START - Processing ' . count($items) . ' items');

        // Gom theo shop và subtotal
        $shop_totals = [];
        $shop_items = [];
        error_log('🚢 item_weights count: ' . count($debug['item_weights'] ?? []));
        foreach (($debug['item_weights'] ?? []) as $row) {
            $shop = intval($row['shop'] ?? 0);
            $shop_totals[$shop] = ($shop_totals[$shop] ?? 0) + intval($row['line_value'] ?? 0);
            $shop_items[$shop][] = ['sp_id' => intval($row['product_id'] ?? 0), 'line_weight' => intval($row['line_weight'] ?? 0), 'line_value' => intval($row['line_value'] ?? 0)];
        }

        error_log('🚢 Found ' . count($shop_totals) . ' shops: ' . json_encode(array_keys($shop_totals)));
        foreach ($shop_totals as $sid => $total) {
            error_log("🚢 Shop $sid: total = $total VND");
        }
        foreach ($shop_totals as $shopId => $subtotal) {
            // Check ALL transport records for this shop (not just LIMIT 1)
            $tq = mysqli_query($conn, "SELECT free_ship_all, free_ship_min_order, free_ship_discount, fee_ship_products FROM transport WHERE user_id='$shopId'");

            error_log("🚢 Checking shop $shopId for freeship config...");

            if ($tq && mysqli_num_rows($tq) > 0) {
                $debug['shop_freeship_details'][$shopId] = [
                    'mode' => 0,
                    'subtotal' => $subtotal,
                    'min_order' => 0,
                    'discount' => 0,
                    'applied' => false
                ];
                
                // Process ALL records for this shop
                while ($t = mysqli_fetch_assoc($tq)) {
                    $mode = intval($t['free_ship_all'] ?? 0);
                    $minOrder = intval($t['free_ship_min_order'] ?? 0);
                    $discount = floatval($t['free_ship_discount'] ?? 0);
                    $feeShipProducts = $t['fee_ship_products'] ?? '';

                    error_log("🚢 Shop $shopId record: mode=$mode, minOrder=$minOrder, discount=$discount, fee_ship_products=" . (empty($feeShipProducts) ? 'EMPTY' : 'HAS_DATA'));

                    // Update debug with the first (primary) record
                    if (!$debug['shop_freeship_details'][$shopId]['applied']) {
                        $debug['shop_freeship_details'][$shopId]['mode'] = $mode;
                        $debug['shop_freeship_details'][$shopId]['min_order'] = $minOrder;
                        $debug['shop_freeship_details'][$shopId]['discount'] = $discount;
                    }

                    // Check fee_ship_products FIRST (highest priority)
                    if (!empty($feeShipProducts)) {
                        $arr = json_decode($feeShipProducts, true);
                        if (is_array($arr)) {
                            if (!isset($debug['shop_freeship_details'][$shopId]['products'])) {
                                $debug['shop_freeship_details'][$shopId]['products'] = [];
                            }
                            error_log("🚢 Shop $shopId: MODE $mode - Checking fee_ship_products, found " . count($arr) . " product configs");
                            foreach ($arr as $cfg) {
                                $spId = intval($cfg['sp_id'] ?? 0);
                                $stype = ($cfg['ship_type'] ?? 'vnd'); // 'vnd' | 'percent'
                                $val = floatval($cfg['ship_support'] ?? 0);
                                
                                foreach (($shop_items[$shopId] ?? []) as $si) {
                                    if ($si['sp_id'] == $spId && $val > 0) {
                                        if ($stype === 'percent') {
                                            $ship_percent_support += $val;
                                            $debug['shop_freeship_details'][$shopId]['products'][$spId] = ['type' => 'percent', 'value' => $val];
                                            error_log("🚢 ✅ Shop $shopId: PRODUCT-SPECIFIC - Product $spId - Percent discount = $val%");
                                            
                                            // Lưu thông tin freeship cho sản phẩm
                                            $product_freeship_info[$spId] = [
                                                'freeship_type' => 'percent',
                                                'freeship_label' => 'Giảm ' . intval($val) . '% ship',
                                                'freeship_amount' => $val,
                                                'shop_id' => $shopId
                                            ];
                                        } else {
                                            $ship_fixed_support += intval($val);
                                            $debug['shop_freeship_details'][$shopId]['products'][$spId] = ['type' => 'fixed', 'value' => $val];
                                            error_log("🚢 ✅ Shop $shopId: PRODUCT-SPECIFIC - Product $spId - Fixed discount = " . intval($val) . " VND");
                                            
                                            // Lưu thông tin freeship cho sản phẩm
                                            $product_freeship_info[$spId] = [
                                                'freeship_type' => 'fixed',
                                                'freeship_label' => 'Hỗ trợ ship ' . number_format($val) . '₫',
                                                'freeship_amount' => intval($val),
                                                'shop_id' => $shopId
                                            ];
                                        }
                                        // Loại trừ weight/value cho sản phẩm này
                                        $exclude_weight += $si['line_weight']; 
                                        $exclude_value += $si['line_value'];
                                        $debug['shop_freeship_details'][$shopId]['applied'] = true;
                                        $debug['shop_freeship_details'][$shopId]['type'] = 'per_product';
                                    }
                                }
                            }
                        }
                    }
                    
                    // Then check mode-based freeship (only if no product-specific freeship applied)
                    if (!$debug['shop_freeship_details'][$shopId]['applied']) {
                        if ($mode === 1) {
                            // Miễn toàn bộ ship cho shop này → loại trừ trọng lượng/value shop này
                            $excluded_w = 0;
                            $excluded_v = 0;
                            foreach (($shop_items[$shopId] ?? []) as $si) {
                                $exclude_weight += $si['line_weight'];
                                $exclude_value += $si['line_value'];
                                $excluded_w += $si['line_weight'];
                                $excluded_v += $si['line_value'];
                            }
                            $debug['shop_freeship_details'][$shopId]['applied'] = true;
                            $debug['shop_freeship_details'][$shopId]['type'] = 'full_exclusion';
                            $debug['shop_freeship_details'][$shopId]['excluded_weight'] = $excluded_w;
                            $debug['shop_freeship_details'][$shopId]['excluded_value'] = $excluded_v;
                            error_log("🚢 ✅ Shop $shopId: MODE 1 - Freeship 100% - Excluded weight=$excluded_w, value=$excluded_v");
                        } else if ($mode === 0) {
                            // Giảm cố định
                            if ($subtotal >= $minOrder && $discount > 0) {
                                $ship_fixed_support += intval($discount);
                                $debug['shop_freeship_details'][$shopId]['applied'] = true;
                                $debug['shop_freeship_details'][$shopId]['type'] = 'fixed_discount';
                                $debug['shop_freeship_details'][$shopId]['applied_amount'] = intval($discount);
                                error_log("🚢 ✅ Shop $shopId: MODE 0 - Fixed discount = " . intval($discount) . " VND");
                            } else {
                                error_log("🚢 ❌ Shop $shopId: MODE 0 - NOT APPLIED (subtotal=$subtotal < minOrder=$minOrder OR discount=$discount <= 0)");
                            }
                        } else if ($mode === 2) {
                            // Giảm theo %
                            if ($subtotal >= $minOrder && $discount > 0) {
                                $ship_percent_support += $discount;
                                $debug['shop_freeship_details'][$shopId]['applied'] = true;
                                $debug['shop_freeship_details'][$shopId]['type'] = 'percent_discount';
                                $debug['shop_freeship_details'][$shopId]['applied_percent'] = $discount;
                                error_log("🚢 ✅ Shop $shopId: MODE 2 - Percent discount = $discount%");
                            } else {
                                error_log("🚢 ❌ Shop $shopId: MODE 2 - NOT APPLIED (subtotal=$subtotal < minOrder=$minOrder OR discount=$discount <= 0)");
                            }
                        } else {
                            error_log("🚢 ❌ Shop $shopId: No freeship config OR mode not recognized (mode=$mode)");
                        }
                    }
                }
            } else {
                error_log("🚢 ❌ Shop $shopId: No transport record found in database");
            }
        }

        error_log("🚢 FREESHIP SUMMARY: exclude_weight=$exclude_weight, exclude_value=$exclude_value, ship_fixed_support=$ship_fixed_support, ship_percent_support=$ship_percent_support");
    }

    $weight_to_quote = max(30, $weight - $exclude_weight);
    $value_to_quote  = max(0, $value  - $exclude_value);

    error_log("🚢 WEIGHT CALCULATION: total_weight=$weight - exclude_weight=$exclude_weight = weight_to_quote=$weight_to_quote");
    error_log("🚢 VALUE CALCULATION: total_value=$value - exclude_value=$exclude_value = value_to_quote=$value_to_quote");

    $debug['freeship_excluded'] = [
        'weight' => $exclude_weight,
        'value' => $exclude_value,
        'weight_to_quote' => $weight_to_quote,
        'value_to_quote' => $value_to_quote,
        'ship_fixed_support' => $ship_fixed_support,
        'ship_percent_support' => $ship_percent_support
    ];

    // Tính phí ship từ TẤT CẢ các kho (giống website checkout.php)
    $total_shipping_fee = 0;
    $warehouse_shipping_details = [];
    $quotes = [];
    $best_overall = null;
    $best_fee = PHP_INT_MAX;

    // Danh sách providers để test (giống checkout.php)
    // BEST tạm comment vì chưa hoạt động - sẽ dùng sau vài tháng
    $shipping_providers = ['SUPERAI', 'GHTK', 'SPX']; // 'BEST' tạm comment
    
    // Gom theo shop để tính phí ship từng kho
    $shop_weights = [];
    $shop_values = [];
    foreach (($debug['item_weights'] ?? []) as $item) {
        $shop = intval($item['shop'] ?? 0);
        $shop_weights[$shop] = ($shop_weights[$shop] ?? 0) + intval($item['line_weight'] ?? 0);
        $shop_values[$shop] = ($shop_values[$shop] ?? 0) + intval($item['line_value'] ?? 0);
    }
    
    error_log("🚢 MULTI-WAREHOUSE SHIPPING: Found " . count($shop_weights) . " warehouses");
    
    // Tính phí ship từng kho
    foreach ($shop_weights as $shop_id => $shop_weight) {
        $shop_value = $shop_values[$shop_id] ?? 0;
        
        error_log("🚢 PROCESSING SHOP $shop_id: weight=$shop_weight g, value=$shop_value VND");
        
        // Lấy vị trí kho của shop này
        $warehouse_query = "SELECT t.province, t.district, 
                                  tm.tieu_de as province_name, 
                                  hm.tieu_de as district_name
                           FROM transport t
                           LEFT JOIN tinh_moi tm ON t.province = tm.id
                           LEFT JOIN huyen_moi hm ON t.district = hm.id
                           WHERE t.user_id = '$shop_id' AND t.is_default = 1
                           LIMIT 1";
        
        error_log("🚢 WAREHOUSE QUERY for shop $shop_id: $warehouse_query");
        
        $warehouse_result = mysqli_query($conn, $warehouse_query);
        if (!$warehouse_result) {
            error_log("🚢 ❌ WAREHOUSE QUERY FAILED for shop $shop_id: " . mysqli_error($conn));
        } else {
            error_log("🚢 WAREHOUSE QUERY RESULT for shop $shop_id: " . mysqli_num_rows($warehouse_result) . " rows");
        }
        
        if ($warehouse_result && mysqli_num_rows($warehouse_result) > 0) {
            $warehouse_data = mysqli_fetch_assoc($warehouse_result);
            $shop_sender_province = $warehouse_data['province_name'] ?? 'Thành phố Hà Nội';
            $shop_sender_district = $warehouse_data['district_name'] ?? 'Nam Từ Liêm';
            
            error_log("🚢 ✅ WAREHOUSE FOUND for shop $shop_id: $shop_sender_province, $shop_sender_district");
            
            // Tính phí ship từ kho này
            $shop_best_fee = PHP_INT_MAX;
            $shop_best_provider = null;
            
            foreach ($shipping_providers as $provider) {
                $shipping_data = calculateShippingFee(
                    $provider,
                    $shop_sender_province,
                    $shop_sender_district,
                    $receiver_province,
                    $receiver_district,
                    $sender_ward,
                    $receiver_ward,
                    $shop_weight,
                    $shop_value,
                    $class_ghtk,
                    $class_superai,
                    $class_best,
                    $class_spx
                );
                
                error_log("🚢 PROVIDER TEST for shop $shop_id: $provider -> fee=" . ($shipping_data['fee'] ?? 0) . ", provider_name=" . ($shipping_data['provider'] ?? 'N/A'));
                
                if ($shipping_data['fee'] > 0 && $shipping_data['fee'] < $shop_best_fee) {
                    $shop_best_fee = $shipping_data['fee'];
                    $shop_best_provider = $shipping_data;
                }
            }
            
            if ($shop_best_provider) {
                $total_shipping_fee += $shop_best_fee;
                $warehouse_shipping_details[] = [
                    'shop_id' => $shop_id,
                    'warehouse_location' => "$shop_sender_province, $shop_sender_district",
                    'weight' => $shop_weight,
                    'value' => $shop_value,
                    'shipping_fee' => $shop_best_fee,
                    'provider' => $shop_best_provider['provider'],
                    'provider_code' => $shop_best_provider['provider_code']
                ];
                
                error_log("🚢 ✅ WAREHOUSE $shop_id: $shop_best_fee VND via {$shop_best_provider['provider']}");
            } else {
                error_log("🚢 ❌ WAREHOUSE $shop_id: No provider found with fee > 0 (all providers returned fee = 0)");
            }
        } else {
            error_log("🚢 ❌ WAREHOUSE NOT FOUND for shop $shop_id: No record in transport table with user_id=$shop_id AND is_default=1");
            // Fallback: Sử dụng địa chỉ mặc định nếu không tìm thấy warehouse
            $shop_sender_province = $sender_province ?? 'Thành phố Hà Nội';
            $shop_sender_district = $sender_district ?? 'Nam Từ Liêm';
            
            error_log("🚢 FALLBACK: Using default sender address for shop $shop_id: $shop_sender_province, $shop_sender_district");
            
            // Tính phí ship với địa chỉ fallback
            $shop_best_fee = PHP_INT_MAX;
            $shop_best_provider = null;
            
            foreach ($shipping_providers as $provider) {
                $shipping_data = calculateShippingFee(
                    $provider,
                    $shop_sender_province,
                    $shop_sender_district,
                    $receiver_province,
                    $receiver_district,
                    $sender_ward,
                    $receiver_ward,
                    $shop_weight,
                    $shop_value,
                    $class_ghtk,
                    $class_superai,
                    $class_best,
                    $class_spx
                );
                
                error_log("🚢 FALLBACK PROVIDER TEST for shop $shop_id: $provider -> fee=" . ($shipping_data['fee'] ?? 0));
                
                if ($shipping_data['fee'] > 0 && $shipping_data['fee'] < $shop_best_fee) {
                    $shop_best_fee = $shipping_data['fee'];
                    $shop_best_provider = $shipping_data;
                }
            }
            
            if ($shop_best_provider) {
                $total_shipping_fee += $shop_best_fee;
                $warehouse_shipping_details[] = [
                    'shop_id' => $shop_id,
                    'warehouse_location' => "$shop_sender_province, $shop_sender_district (fallback)",
                    'weight' => $shop_weight,
                    'value' => $shop_value,
                    'shipping_fee' => $shop_best_fee,
                    'provider' => $shop_best_provider['provider'],
                    'provider_code' => $shop_best_provider['provider_code']
                ];
                
                error_log("🚢 ✅ FALLBACK SUCCESS for shop $shop_id: $shop_best_fee VND via {$shop_best_provider['provider']}");
            } else {
                error_log("🚢 ❌ FALLBACK FAILED for shop $shop_id: No provider found with fee > 0");
            }
        }
    }
    
    // Tạo quotes tổng hợp với tên provider chính xác
    if ($total_shipping_fee > 0) {
        // Tạo provider name từ các warehouse details
        $provider_names = [];
        $provider_codes = [];
        foreach ($warehouse_shipping_details as $warehouse) {
            $provider_names[] = $warehouse['provider'];
            $provider_codes[] = $warehouse['provider_code'];
        }
        
        // Loại bỏ duplicate và tạo tên provider
        $unique_providers = array_unique($provider_names);
        $unique_codes = array_unique($provider_codes);
        
        if (count($unique_providers) == 1) {
            // Cùng 1 provider cho tất cả kho
            $provider_name = $unique_providers[0];
            $provider_code = $unique_codes[0];
        } else {
            // Nhiều provider khác nhau
            $provider_name = implode(' + ', $unique_providers);
            $provider_code = implode('+', $unique_codes);
        }
        
        $best_overall = [
            'provider' => $provider_name,
            'carrier_name' => $provider_name,
            'carrier_id' => 0,
            'fee' => $total_shipping_fee,
            'provider_code' => $provider_code,
            'raw' => ['fee' => $total_shipping_fee, 'provider' => $provider_name],
            'warehouse_details' => $warehouse_shipping_details
        ];
        
        $quotes[] = $best_overall;
        $best_fee = $total_shipping_fee;
        
        error_log("🚢 TOTAL SHIPPING FEE: $total_shipping_fee VND via $provider_name from " . count($warehouse_shipping_details) . " warehouses");
    }
    
    // Debug log
    $debug['shipping_providers_tested'] = $shipping_providers;
    $debug['quotes_generated'] = count($quotes);
    $debug['best_fee_found'] = $best_fee;

    // Sort quotes asc by fee
    usort($quotes, function ($a, $b) {
        return ($a['fee'] <=> $b['fee']);
    });

    $best_simple = $best_overall ? [
        'fee' => $best_overall['fee'] ?? 0,
        'provider' => $best_overall['provider'] ?? '',
        // ETA: tính toán dựa trên khoảng cách giống checkout.php
        'eta_text' => ((stripos($sender_province, $receiver_province) !== false)
            ? ('Dự kiến từ ' . date('d/m', strtotime('+1 days')) . ' - ' . date('d/m', strtotime('+2 days')))
            : ('Dự kiến từ ' . date('d/m', strtotime('+2 days')) . ' - ' . date('d/m', strtotime('+4 days')))),
    ] : ['fee' => 0, 'provider' => '', 'eta_text' => ''];

    // Sau khi có best_overall, áp hỗ trợ freeship
    $fee_before_support = 0;
    $total_support = 0;
    if ($best_overall) {
        $fee_before_support = intval($best_overall['fee'] ?? 0);

        // Nếu đã loại trừ 100% weight/value (MODE 1 hoặc MODE 3 full), fee = 0
        // Nhưng trong MODE 3, chúng ta muốn áp dụng hỗ trợ ship cố định thay vì freeship 100%
        if ($exclude_weight > 0 && $exclude_weight >= $weight && $ship_fixed_support == 0) {
            $final_fee = 0;
            $total_support = $fee_before_support;
            error_log("🚢 FREESHIP 100% APPLIED - Fee reduced from $fee_before_support to 0");
        } else {
            // Áp dụng fixed support và percent support
            $support_fee = $ship_fixed_support;
            if ($ship_percent_support > 0) {
                // Tính hỗ trợ ship theo giá trị đơn hàng (giống website)
                $support_fee += intval(round($value_to_quote * ($ship_percent_support / 100.0)));
            }
            $total_support = $support_fee;
            // Không giới hạn hỗ trợ ship - có thể vượt quá phí ship gốc
            $final_fee = max(0, $fee_before_support - $support_fee);

            error_log("🚢 PARTIAL FREESHIP APPLIED:");
            error_log("🚢   fee_before_support = $fee_before_support VND");
            error_log("🚢   ship_fixed_support = $ship_fixed_support VND");
            error_log("🚢   ship_percent_support = $ship_percent_support%");
            error_log("🚢   support_fee = $support_fee VND");
            error_log("🚢   total_support = $total_support VND");
            error_log("🚢   FINAL FEE = $final_fee VND");
        }

        // Trả về phí ship gốc và hỗ trợ ship riêng biệt (giống website)
        $best_overall['fee'] = $fee_before_support; // Phí ship gốc
        $best_overall['ship_support'] = $total_support; // Hỗ trợ ship (không giới hạn)
        $best_simple['fee'] = $fee_before_support; // Phí ship gốc
        $best_simple['ship_support'] = $total_support; // Hỗ trợ ship (không giới hạn)

        // Update all quotes - trả về phí ship gốc và hỗ trợ ship riêng biệt
        foreach ($quotes as &$q) {
            $q['ship_support'] = $total_support; // Thêm hỗ trợ ship vào mỗi quote
            // Giữ nguyên phí ship gốc, không trừ hỗ trợ ship
        }

        $debug['final_fee_calculation'] = [
            'fee_before_support' => $fee_before_support,
            'exclude_weight' => $exclude_weight,
            'total_weight' => $weight,
            'freeship_100_applied' => ($exclude_weight > 0 && $exclude_weight >= $weight),
            'ship_fixed_support' => $ship_fixed_support,
            'ship_percent_support' => $ship_percent_support,
            'total_support' => $total_support,
            'final_fee' => $final_fee
        ];
    }

    $response = [
        'success' => true,
        'message' => 'Lấy báo giá vận chuyển thành công',
        'data' => [
            'input' => [
                'sender_province' => $sender_province,
                'sender_district' => $sender_district,
                'sender_ward' => $sender_ward,
                'receiver_province' => $receiver_province,
                'receiver_district' => $receiver_district,
                'receiver_ward' => $receiver_ward,
                'weight' => $weight,
                'value' => $value,
                'length' => $length,
                'width' => $width,
                'height' => $height
            ],
            'quotes' => $quotes,
            'best' => $best_overall ?: ['provider' => '', 'carrier_name' => '', 'fee' => 0],
            'best_simple' => $best_simple,
            'freeship_info' => [
                'product_freeship' => $product_freeship_info,
                'total_fixed_support' => $ship_fixed_support,
                'total_percent_support' => $ship_percent_support,
                'excluded_weight' => $exclude_weight,
                'excluded_value' => $exclude_value
            ],
            'warehouse_shipping' => [
                'total_fee' => $total_shipping_fee,
                'warehouse_count' => count($warehouse_shipping_details),
                'warehouse_details' => $warehouse_shipping_details
            ],
            'debug' => $debug,
        ]
    ];


    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
} catch (Throwable $e) {
    // Trả 500 với thông tin lỗi rõ ràng để debug thay vì 401
    http_response_code(500);
    echo json_encode(array(
        "success" => false,
        "message" => "Lỗi xử lý shipping_quote",
        "error" => $e->getMessage()
    ), JSON_UNESCAPED_UNICODE);
}
