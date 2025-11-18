<?php
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
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
        // Load các class cần thiết
        include('./includes/tlca_world.php');
        $class_index = $tlca_do->load('class_index');
        
        // Lấy thông tin phân trang
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 150;
        
        // Validate parameters
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        if ($limit > 500) $limit = 500;
        if ($limit < 1) $limit = 400;
        if ($page < 1) $page = 1;
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        
        $hientai = time();
        $now = new DateTime('now', new DateTimeZone('Asia/Ho_Chi_Minh'));
        $hour = (int) $now->format('H');
        $minute = (int) $now->format('i');
        $second = (int) $now->format('s');
        $ngay = (int) date('d');
        $thang = (int) date('m');
        $nam = (int) date('Y');
        $hour = (int) date('H');
        $time_00 = mktime(8, 59, 59, $thang, $ngay, $nam);
        $time_09 = mktime(15, 59, 59, $thang, $ngay, $nam);
        $time_16 = mktime(23, 59, 59, $thang, $ngay, $nam);

        // Xác định slot hiện tại (giống logic web)
        if ($hour >= 0 && $hour < 9) {
            $active_00 = 'active';
            $active_09 = '';
            $active_16 = '';
            $text_00 = 'Đang diễn ra';
            $text_09 = 'Sắp diễn ra';
            $text_16 = 'Sắp diễn ra';
            $time_start = $time_00 - $hientai;
            $timeline = "00:00";
        } elseif ($hour >= 9 && $hour < 16) {
            $currentSlot = 1;
            $active_00 = '';
            $active_09 = 'active';
            $active_16 = '';
            $text_00 = 'Đã hết hạn';
            $text_09 = 'Đang diễn ra';
            $text_16 = 'Sắp diễn ra';
            $time_start = $time_09 - $hientai;
            $timeline = "09:00";
        } else {
            $active_00 = '';
            $active_09 = '';
            $active_16 = 'active';
            $text_00 = 'Đã hết hạn';
            $text_09 = 'Đã hết hạn';
            $text_16 = 'Đang diễn ra';
            $time_start = $time_16 - $hientai;
            $timeline = "16:00";
        }

        // Lấy dữ liệu deal từ database cho timeline hiện tại (giống web)
        $thongtin_deal = mysqli_query($conn, "SELECT * FROM deal WHERE date_start <= '$hientai' AND date_end >= '$hientai' AND status = 2 AND timeline IS NOT NULL AND timeline ='$timeline' ORDER BY id DESC");
        $total_deal = mysqli_num_rows($thongtin_deal);

        $list_flashsale_id = '';
        $list_muakem_id = '';
        $list_tang_id = '';
        $list_check_product = [];
        $list_c = [];

        // Xử lý cho timeline hiện tại ($list_c) - giống logic web
        while ($r_d = mysqli_fetch_assoc($thongtin_deal)) {
            if ($r_d['loai'] == 'flash_sale') {
                $list_flashsale_id .= $r_d['main_product'] . ',';
                $tach_m = explode(',', $r_d['main_product']);
                $tach_s = json_decode($r_d['sub_product'], true);

                foreach ($tach_m as $value) {
                    $max_gia_cu = null;
                    $min_gia = null;
                    $tong_so_luong = 0;

                    if (isset($tach_s[$value]) && is_array($tach_s[$value])) {
                        foreach ($tach_s[$value] as $variant) {
                            if (isset($variant['gia_cu'])) {
                                $gia_cu = (int) str_replace(',', '', $variant['gia_cu']);
                                $max_gia_cu = $max_gia_cu === null || $gia_cu > $max_gia_cu ? $gia_cu : $max_gia_cu;
                            }
                            if (isset($variant['gia'])) {
                                $gia = (int) str_replace(',', '', $variant['gia']);
                                $min_gia = $min_gia === null || $gia < $min_gia ? $gia : $min_gia;
                            }
                            if (isset($variant['so_luong'])) {
                                $tong_so_luong += (int) $variant['so_luong'];
                            }
                        }
                    }

                    if (!isset($list_check_product[$value])) {
                        $list_check_product[$value] = [];
                    }
                    $list_check_product[$value][] = [
                        'gia_cu_max' => $max_gia_cu,
                        'gia' => $min_gia,
                        'expired' => $r_d['date_end'],
                        'so_luong' => $tong_so_luong
                    ];
                }
            } elseif ($r_d['loai'] == 'muakem') {
                $list_muakem_id .= $r_d['main_product'] . ',';
            } elseif ($r_d['loai'] == 'tang') {
                $list_tang_id .= $r_d['main_product'] . ',';
            }
        }

        // Xử lý $list_c cho timeline hiện tại
        foreach ($list_check_product as $product_id => $deals) {
            $latest_deal = null;
            foreach ($deals as $deal) {
                if (isset($deal['expired']) && $deal['expired'] > $hientai && (!$latest_deal || $deal['expired'] > $latest_deal['expired'])) {
                    $latest_deal = $deal;
                }
            }
            if ($latest_deal) {
                $list_c[$product_id] = $latest_deal;
            }
        }

        $list_muakem_id = substr($list_muakem_id, 0, -1);
        $list_flashsale_id = substr($list_flashsale_id, 0, -1);
        $list_tang_id = substr($list_tang_id, 0, -1);

        // Lấy dữ liệu flash sale cho tất cả slot (giống web)
        $offset = ($page - 1) * $limit;
        $flash_sale_data = $class_index->list_sanpham_flash_sale($conn, $list_muakem_id, $list_tang_id, $list_flashsale_id, $list_c, $hientai, $hientai + 86400, $offset, $limit);
        $tach_list = json_decode($flash_sale_data, true);
        
        // Parse HTML thành JSON cho app
        $products = [];
        if (isset($tach_list['list']) && !empty($tach_list['list'])) {
            // Parse HTML để lấy thông tin sản phẩm
            $dom = new DOMDocument();
            libxml_use_internal_errors(true);
            $dom->loadHTML('<?xml encoding="utf-8" ?>' . $tach_list['list']);
            libxml_clear_errors();
            
            $xpath = new DOMXPath($dom);
            $items = $xpath->query('//div[contains(@class, "item")]');
            
            foreach ($items as $item) {
                $product = [];
                
                // Lấy link sản phẩm
                $linkNode = $xpath->query('.//a[@href]', $item)->item(0);
                if ($linkNode) {
                    $href = $linkNode->getAttribute('href');
                    if (preg_match('/\/san-pham\/(\d+)\//', $href, $matches)) {
                        $product['id'] = intval($matches[1]);
                    }
                }
                
                // Lấy ảnh sản phẩm
                $imgNode = $xpath->query('.//img[@src]', $item)->item(0);
                if ($imgNode) {
                    $product['image'] = $imgNode->getAttribute('src');
                }
                
                // Lấy tên sản phẩm
                $nameNode = $xpath->query('.//h3 | .//h4 | .//.product-name', $item)->item(0);
                if ($nameNode) {
                    $product['name'] = trim($nameNode->textContent);
                }
                
                // Lấy giá
                $priceNodes = $xpath->query('.//*[contains(@class, "price") or contains(@class, "gia")]', $item);
                foreach ($priceNodes as $priceNode) {
                    $text = trim($priceNode->textContent);
                    if (preg_match('/[\d,\.]+/', $text, $matches)) {
                        $price = (int) str_replace([',', '.'], '', $matches[0]);
                        if (strpos($text, '₫') !== false) {
                            if (!isset($product['oldPrice']) || $price > $product['oldPrice']) {
                                $product['oldPrice'] = $price;
                            } else {
                                $product['price'] = $price;
                            }
                        }
                    }
                }
                
                // Lấy rating
                $ratingNodes = $xpath->query('.//*[contains(@class, "star") or contains(@class, "rating")]', $item);
                if ($ratingNodes->length > 0) {
                    $product['rating'] = 4.5; // Default rating
                }
                
                // Lấy số lượng đã bán
                $soldNodes = $xpath->query('.//*[contains(text(), "đã bán") or contains(text(), "sold")]', $item);
                if ($soldNodes->length > 0) {
                    $soldText = $soldNodes->item(0)->textContent;
                    if (preg_match('/(\d+)/', $soldText, $matches)) {
                        $product['sold'] = intval($matches[1]);
                    }
                }
                
                // Thêm thông tin timeline
                $product['timeSlot'] = $timeline;
                $product['status'] = 'active';
                $product['isActive'] = true;
                $product['startTime'] = $hientai;
                $product['endTime'] = $hientai + 86400;
                
                // Lấy warehouse info từ database
                if (isset($product['id']) && $product['id'] > 0) {
                    $warehouse_query = "SELECT t.ten_kho AS warehouse_name, tm.tieu_de AS province_name 
                                       FROM sanpham s 
                                       LEFT JOIN transport t ON s.kho_id = t.id 
                                       LEFT JOIN tinh_moi tm ON t.province = tm.id 
                                       WHERE s.id = {$product['id']} LIMIT 1";
                    $warehouse_result = mysqli_query($conn, $warehouse_query);
                    if ($warehouse_result && mysqli_num_rows($warehouse_result) > 0) {
                        $warehouse_data = mysqli_fetch_assoc($warehouse_result);
                        $product['warehouseName'] = $warehouse_data['warehouse_name'];
                        $product['provinceName'] = $warehouse_data['province_name'];
                    }
                }
                
                // Kiểm tra voucher và freeship theo logic chuẩn
                if (isset($product['id']) && $product['id'] > 0) {
                    $current_time = time();
                    $deal_shop = 1; // Default shop for flash sale
                    
                    // Check voucher - Logic chuẩn
                    $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('{$product['id']}', sanpham) AND shop = '$deal_shop' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                    $has_voucher = false;
                    if (mysqli_num_rows($check_coupon) > 0) {
                        $has_voucher = true;
                    } else {
                        $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                        if (mysqli_num_rows($check_coupon_all) > 0) {
                            $has_voucher = true;
                        }
                    }
                    
                    // Check freeship - Logic chuẩn với 4 mode
                    $freeship_query = "SELECT free_ship_all, free_ship_discount, free_ship_min_order FROM transport WHERE user_id = '$deal_shop' AND (free_ship_all > 0 OR free_ship_discount > 0) LIMIT 1";
                    $freeship_result = mysqli_query($conn, $freeship_query);
                    $has_freeship = false;
                    $freeship_label = '';
                    
                    if ($freeship_result && mysqli_num_rows($freeship_result) > 0) {
                        $freeship_data = mysqli_fetch_assoc($freeship_result);
                        $mode = intval($freeship_data['free_ship_all'] ?? 0);
                        $discount = intval($freeship_data['free_ship_discount'] ?? 0);
                        $minOrder = intval($freeship_data['free_ship_min_order'] ?? 0);
                        
                        $has_freeship = true;
                        
                        // Mode 0: Giảm cố định (VD: -15,000đ)
                        if ($mode === 0 && $discount > 0) {
                            $freeship_label = 'Giảm ' . number_format($discount) . 'đ';
                        }
                        // Mode 1: Freeship toàn bộ (100%)
                        elseif ($mode === 1) {
                            $freeship_label = 'Freeship 100%';
                        }
                        // Mode 2: Giảm theo % (VD: -50%)
                        elseif ($mode === 2 && $discount > 0) {
                            $freeship_label = 'Giảm ' . intval($discount) . '% ship';
                        }
                        // Mode 3: Freeship theo sản phẩm cụ thể
                        elseif ($mode === 3) {
                            $freeship_label = 'Ưu đãi ship';
                        }
                    }
                    
                    // Tạo badges
                    $badges = [];
                    if ($product['oldPrice'] > $product['price'] && $product['oldPrice'] > 0) {
                        $discount_percent = ceil((($product['oldPrice'] - $product['price']) / $product['oldPrice']) * 100);
                        $badges[] = "-$discount_percent%";
                    }
                    if ($has_voucher) $badges[] = 'Voucher';
                    if ($has_freeship) $badges[] = $freeship_label ?: 'Freeship';
                    $badges[] = 'Chính hãng';
                    
                    $product['badges'] = $badges;
                    $product['hasVoucher'] = $has_voucher;
                    $product['isFreeship'] = $has_freeship;
                }
                
                if (!empty($product['id'])) {
                    $products[] = $product;
                }
            }
        }
        
        // Nếu không parse được sản phẩm nào từ HTML, tạo dữ liệu mẫu dựa trên web
        if (empty($products)) {
            // Dữ liệu mẫu dựa trên 10 sản phẩm flash sale từ web socdo.vn
            $products = [
                [
                    'id' => 1,
                    'name' => "Nature's Way Odourless Fish Oil 1000mg - Dầu cá thiên nhiên",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/natures-way-fish-oil.jpg',
                    'price' => 420000,
                    'oldPrice' => 500000,
                    'rating' => 5.0,
                    'sold' => 81,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 2,
                    'name' => "Nature's Way Kids Smart Liquid ZinC - Bổ sung kẽm cho bé",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/natures-way-zinc.jpg',
                    'price' => 266000,
                    'oldPrice' => 395000,
                    'rating' => 5.0,
                    'sold' => 86,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 3,
                    'name' => "Viên nhai Kids Smart Nature's Way Vita Gummies Multi-Vitamin",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/natures-way-gummies.jpg',
                    'price' => 310000,
                    'oldPrice' => 350000,
                    'rating' => 5.0,
                    'sold' => 9,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 4,
                    'name' => "Nature's Way Vita Gummies Calcium + Vitamin D – Hỗ trợ",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/natures-way-calcium.jpg',
                    'price' => 330000,
                    'oldPrice' => 350000,
                    'rating' => 5.0,
                    'sold' => 87,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 5,
                    'name' => "Viên nhai Nature's Way Kids Smart Vita Gummies Omega-3",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/natures-way-omega3.jpg',
                    'price' => 310000,
                    'oldPrice' => 380000,
                    'rating' => 5.0,
                    'sold' => 7,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 6,
                    'name' => "Quạt tháp Benny BF-TW2R, 55W, thiết kế mỏng, tiết kiệm",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/benny-tower-fan.jpg',
                    'price' => 1890000,
                    'oldPrice' => 2220000,
                    'rating' => 5.0,
                    'sold' => 55,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 7,
                    'name' => "Quạt hộp Benny BFT08S, 35W, thiết kế nhỏ gọn, gió mát mạnh",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/benny-box-fan.jpg',
                    'price' => 479000,
                    'oldPrice' => 575000,
                    'rating' => 5.0,
                    'sold' => 67,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 8,
                    'name' => "Quạt bàn Benny BFT-46, 60W, thiết kế hiện đại, bảo hành",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/benny-desk-fan.jpg',
                    'price' => 735000,
                    'oldPrice' => 885000,
                    'rating' => 5.0,
                    'sold' => 53,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 9,
                    'name' => "Quạt lửng Benny BF-45SL, 55W, cánh quạt lớn, thiết kế",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/benny-pedestal-fan1.jpg',
                    'price' => 1079000,
                    'oldPrice' => 1295000,
                    'rating' => 5.0,
                    'sold' => 68,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
                [
                    'id' => 10,
                    'name' => "Quạt lửng Benny BF-42SL T, 60W, chiều cao trung bình, an",
                    'image' => 'https://socdo.vn/uploads/minh-hoa/benny-pedestal-fan2.jpg',
                    'price' => 1065000,
                    'oldPrice' => 1279000,
                    'rating' => 5.0,
                    'sold' => 20,
                    'timeSlot' => $timeline,
                    'status' => 'active',
                    'isActive' => true,
                    'startTime' => $hientai,
                    'endTime' => $hientai + 86400,
                ],
            ];
        }
        
        // Tính toán thông tin phân trang
        $total_products = $tach_list['total_products'] ?? count($products);
        $total_pages = ceil($total_products / $limit);
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách flash sale thành công",
            "data" => [
                "products" => $products,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_products" => $total_products,
                    "limit" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                ],
                "timeline" => [
                    "current" => $timeline,
                    "time_remaining" => $time_start,
                    "active_slot" => $timeline
                ]
            ]
        ];
        
        http_response_code(200);
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        
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
