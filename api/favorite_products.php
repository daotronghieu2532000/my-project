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
        $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
        
        // Validate parameters
        if ($user_id <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Thiếu user_id"
            ]);
            exit;
        }
        
        $get_all = isset($_GET['all']) && $_GET['all'] == '1';
        
        if ($limit > 1000) $limit = 1000;
        if ($limit < 1) $limit = 50;
        if ($page < 1) $page = 1;
        
        // Override limit nếu get_all = true
        if ($get_all) {
            $limit = 999999;
            $page = 1;
        }
        
        $start = ($page - 1) * $limit;
        
        // Đếm tổng số sản phẩm yêu thích
        $count_query = "SELECT COUNT(DISTINCT s.id) as total 
                       FROM yeu_thich_san_pham y
                       JOIN sanpham s ON y.product_id = s.id
                       WHERE y.user_id = '$user_id'";
        $count_result = mysqli_query($conn, $count_query);
        $total_favorites = mysqli_fetch_assoc($count_result)['total'];
        
        // Lấy danh sách sản phẩm yêu thích - theo logic hàm list_sanpham_yeuthich
        // LEFT JOIN với product_rating_stats để lấy rating và reviews (tối ưu hơn)
        // Nếu không có trong product_rating_stats, tính từ product_comments
        $sql = "SELECT DISTINCT
                s.id, s.tieu_de, s.link, s.gia_cu, s.gia_moi, s.gia_ctv, s.minh_hoa, s.shop, s.ma_sanpham,
                s.thuong_hieu, s.kho, s.ban, s.view, s.box_banchay, s.box_noibat, s.box_flash, 
                s.date_post, s.noi_bat, s.cat, s.kho_id,
                COALESCE(prs.total_reviews, 0) AS total_reviews,
                COALESCE(prs.total_reviews, 0) AS reviews_count,
                COALESCE(prs.average_rating, 0.0) AS avg_rating,
                COALESCE(prs.average_rating, 0.0) AS rating,
                y.id as favorite_id,
                t.ten_kho as warehouse_name, tm.tieu_de as province_name
                FROM yeu_thich_san_pham y
                JOIN sanpham s ON y.product_id = s.id
                LEFT JOIN phanloai_sanpham p ON s.id = p.sp_id
                LEFT JOIN transport t ON s.kho_id = t.id AND t.user_id = s.shop
                LEFT JOIN tinh_moi tm ON t.province = tm.id
                LEFT JOIN product_rating_stats prs ON prs.product_id = s.id AND prs.shop_id = s.shop
                WHERE y.user_id = '$user_id'
                ORDER BY y.id DESC
                LIMIT $start, $limit";
        
        $result = mysqli_query($conn, $sql);
        
        if (!$result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
            ]);
            exit;
        }
        
        $products = array();
        $checked_ids = array();
        $current_time = time();
        
        // Dùng dữ liệu thật từ database - không cần tính sold từ đơn hàng
        while ($r_sp = mysqli_fetch_assoc($result)) {
            $id_sp = $r_sp['id'];
            
            // Tránh trùng lặp
            if (in_array($id_sp, $checked_ids)) continue;
            $checked_ids[] = $id_sp;
            
            // Xử lý giá từ bảng phanloai_sanpham nếu có
            $sql_pl = "SELECT MIN(gia_moi) AS gia_moi_min, MAX(gia_cu) AS gia_cu_max, MIN(gia_ctv) AS gia_ctv_min FROM phanloai_sanpham WHERE sp_id = '$id_sp'";
            $res_pl = mysqli_query($conn, $sql_pl);
            $row_pl = mysqli_fetch_assoc($res_pl);
            
            if ($row_pl && $row_pl['gia_moi_min'] !== null && $row_pl['gia_moi_min'] > 0) {
                $gia_moi_main = (int) $row_pl['gia_moi_min'];
                $gia_cu_main = (int) $row_pl['gia_cu_max'];
                $gia_ctv_main = (int) $row_pl['gia_ctv_min'];
            } else {
                $gia_cu_main = (int) preg_replace('/[^0-9]/', '', $r_sp['gia_cu']);
                $gia_moi_main = (int) preg_replace('/[^0-9]/', '', $r_sp['gia_moi']);
                $gia_ctv_main = (int) preg_replace('/[^0-9]/', '', $r_sp['gia_ctv']);
            }
            
            // Check flash sale và lấy giá - giống product_detail.php
            $is_flash_sale = false;
            $flash_check = mysqli_query($conn, "SELECT * FROM deal WHERE loai = 'flash_sale' AND status = 2 AND '$current_time' BETWEEN date_start AND date_end LIMIT 50");
            
            if ($flash_check && mysqli_num_rows($flash_check) > 0) {
                while ($flash_deal = mysqli_fetch_assoc($flash_check)) {
                    $is_in_flash_sale = false;
                    
                    // Check main_product
                    if (!empty($flash_deal['main_product'])) {
                        $main_product_ids = explode(',', $flash_deal['main_product']);
                        $main_product_ids_int = array_map('intval', $main_product_ids);
                        if (in_array(intval($id_sp), $main_product_ids_int)) {
                            $is_in_flash_sale = true;
                        }
                    }
                    
                    // Check sub_product (JSON)
                    if (!$is_in_flash_sale && !empty($flash_deal['sub_product'])) {
                        $sub_json = json_decode($flash_deal['sub_product'], true);
                        if (json_last_error() === JSON_ERROR_NONE && is_array($sub_json)) {
                            $product_id_str = (string)$id_sp;
                            $product_id_int = intval($id_sp);
                            if (isset($sub_json[$product_id_str]) || isset($sub_json[$product_id_int])) {
                                $is_in_flash_sale = true;
                            }
                        }
                    }
                    
                    // Check sub_id
                    if (!$is_in_flash_sale && !empty($flash_deal['sub_id'])) {
                        $sub_ids = explode(',', $flash_deal['sub_id']);
                        $sub_ids_int = array_map('intval', $sub_ids);
                        if (in_array(intval($id_sp), $sub_ids_int)) {
                            $is_in_flash_sale = true;
                        }
                    }
                    
                    if ($is_in_flash_sale) {
                        $flash_price = null;
                        $flash_old_price = null;
                        
                        if (!empty($flash_deal['sub_product'])) {
                            $sub_json = json_decode($flash_deal['sub_product'], true);
                            if (json_last_error() === JSON_ERROR_NONE && is_array($sub_json)) {
                                $product_id_str = (string)$id_sp;
                                $product_id_int = intval($id_sp);
                                
                                $product_variants = null;
                                if (isset($sub_json[$product_id_str])) {
                                    $product_variants = $sub_json[$product_id_str];
                                } elseif (isset($sub_json[$product_id_int])) {
                                    $product_variants = $sub_json[$product_id_int];
                                }
                                
                                if (!empty($product_variants) && is_array($product_variants)) {
                                    $first_variant = reset($product_variants);
                                    $flash_price = isset($first_variant['gia']) ? intval($first_variant['gia']) : null;
                                    $flash_old_price = isset($first_variant['gia_cu']) ? intval($first_variant['gia_cu']) : null;
                                }
                            }
                        }
                        
                        if ($flash_price === null) {
                            $flash_price = $gia_moi_main;
                            $flash_old_price = $gia_cu_main;
                        }
                        
                        $gia_moi_main = $flash_price;
                        $gia_cu_main = $flash_old_price;
                        $is_flash_sale = true;
                        break;
                    }
                }
            }
            
            // Tính phần trăm giảm giá
            $giam = ($gia_cu_main > $gia_moi_main && $gia_cu_main > 0) ? 
                   ceil((($gia_cu_main - $gia_moi_main) / $gia_cu_main) * 100) : 0;
            
            // Update giá vào $r_sp
            $r_sp['gia_moi'] = $gia_moi_main;
            $r_sp['gia_cu'] = $gia_cu_main;
            
            // Add is_flash_sale to row
            $r_sp['is_flash_sale'] = $is_flash_sale ? 1 : 0;
            
            // Format giá tiền
            $r_sp['gia_cu_formatted'] = number_format($gia_cu_main);
            $r_sp['gia_moi_formatted'] = number_format($gia_moi_main);
            $r_sp['gia_ctv_formatted'] = number_format($gia_ctv_main);
            $r_sp['discount_percent'] = $giam;
            $r_sp['date_post_formatted'] = date('d/m/Y H:i:s', $r_sp['date_post']);
            
            // Xử lý hình ảnh
            $original_image = $r_sp['minh_hoa'];
            $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/sanpham_anh_340x340/', $original_image);
            
            if (!empty($thumb_image) && file_exists($thumb_image)) {
                $r_sp['image_url'] = 'https://socdo.vn/' . $thumb_image;
            } elseif (!empty($original_image) && file_exists($original_image)) {
                $r_sp['image_url'] = 'https://socdo.vn/' . $original_image;
            } else {
                $r_sp['image_url'] = 'https://socdo.vn/images/no-images.jpg';
            }
            
            // Tạo URL sản phẩm
            $r_sp['product_url'] = 'https://socdo.vn/san-pham/' . $r_sp['id'] . '/' . $r_sp['link'] . '.html';
            
            // Logic voucher chi tiết
            $deal_shop = $r_sp['shop'];
            $voucher_icon = '';
            
            // Check voucher sản phẩm cụ thể
            $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('$id_sp', sanpham) AND shop = '$deal_shop' AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
            if (mysqli_num_rows($check_coupon) > 0) {
                $voucher_icon = 'Voucher';
            } else {
                // Check voucher shop
                $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                if (mysqli_num_rows($check_coupon_all) > 0) {
                    $voucher_icon = 'Voucher';
                }
            }
            
            // Logic freeship chi tiết với 4 mode - Sử dụng query riêng như product_suggest.php
            $freeship_icon = '';
            $freeship_query = "SELECT free_ship_all, free_ship_discount, free_ship_min_order, fee_ship_products FROM transport WHERE user_id = '$deal_shop' AND (free_ship_all > 0 OR free_ship_discount > 0) LIMIT 1";
            $freeship_result = mysqli_query($conn, $freeship_query);
            $freeship_label = '';
            
            if ($freeship_result && mysqli_num_rows($freeship_result) > 0) {
                $freeship_data = mysqli_fetch_assoc($freeship_result);
                $mode = intval($freeship_data['free_ship_all'] ?? 0);
                $discount = intval($freeship_data['free_ship_discount'] ?? 0);
                $minOrder = intval($freeship_data['free_ship_min_order'] ?? 0);
                
                // Lấy giá sản phẩm để kiểm tra điều kiện min_order
                $base_price = $gia_moi_main;
                
                // Mode 0: Giảm cố định (VD: -15,000đ) - Cần kiểm tra điều kiện min_order
                if ($mode === 0 && $discount > 0 && $base_price >= $minOrder) {
                    $freeship_label = 'Giảm ' . number_format($discount) . 'đ ship';
                }
                // Mode 1: Freeship toàn bộ (100%)
                elseif ($mode === 1) {
                    $freeship_label = 'Freeship 100%';
                }
                // Mode 2: Giảm theo % (VD: -50%) - Cần kiểm tra điều kiện min_order
                elseif ($mode === 2 && $discount > 0 && $base_price >= $minOrder) {
                    $freeship_label = 'Giảm ' . intval($discount) . '% ship';
                }
                // Mode 3: Ưu đãi ship theo sản phẩm cụ thể - cần kiểm tra fee_ship_products
                elseif ($mode === 3) {
                    $fee_ship_products = $freeship_data['fee_ship_products'] ?? '';
                    $ship_discount_amount = 0;
                    
                    if (!empty($fee_ship_products)) {
                        $fee_ship_products_array = json_decode($fee_ship_products, true);
                        if (is_array($fee_ship_products_array)) {
                            foreach ($fee_ship_products_array as $ship_item) {
                                if (isset($ship_item['sp_id']) && $ship_item['sp_id'] == $id_sp) {
                                    // Lấy số tiền hỗ trợ ship cụ thể
                                    if (isset($ship_item['ship_support'])) {
                                        $ship_discount_amount = intval($ship_item['ship_support']);
                                    }
                                    break;
                                }
                            }
                        }
                    }
                    
                    // Hiển thị số tiền hỗ trợ ship cụ thể
                    if ($ship_discount_amount > 0) {
                        $freeship_label = 'Hỗ trợ ship ' . number_format($ship_discount_amount) . '₫';
                    }
                }
                
                $freeship_icon = $freeship_label ?: '';
            }
            
            // Logic chính hãng - Luôn hiển thị như product_suggest.php
            $chinhhang_icon = 'Chính hãng';
            
            // Warehouse info
            $warehouse_name = $r_sp['warehouse_name'] ?? '';
            $province_name = $r_sp['province_name'] ?? '';
            
            // Thêm badges - Giống với product_suggest.php
            $badges = array();
            if ($r_sp['box_banchay'] == 1) $badges[] = 'Bán chạy';
            if ($r_sp['box_noibat'] == 1) $badges[] = 'Nổi bật';
            // Ưu tiên check is_flash_sale
            if (isset($r_sp['is_flash_sale']) && $r_sp['is_flash_sale'] == 1) {
                $badges[] = 'Flash sale';
            } elseif (isset($r_sp['box_flash']) && $r_sp['box_flash'] == 1) {
                $badges[] = 'Flash sale';
            }
            if ($giam > 0) $badges[] = "-$giam%";
            if (!empty($voucher_icon)) $badges[] = $voucher_icon;
            if (!empty($freeship_icon)) $badges[] = $freeship_icon;
            $badges[] = 'Chính hãng';
            
            $r_sp['badges'] = $badges;
            $r_sp['voucher_icon'] = $voucher_icon;
            $r_sp['freeship_icon'] = $freeship_icon;
            $r_sp['chinhhang_icon'] = 'Chính hãng';
            $r_sp['warehouse_name'] = $warehouse_name;
            $r_sp['province_name'] = $province_name;
            
            // Label sale
            if ($giam > 0) {
                $r_sp['label_sale'] = '<div class="label_product"><div class="label_wrapper">-' . $giam . '%</div></div>';
            } else {
                $r_sp['label_sale'] = '';
            }
            
            // Rating và reviews từ product_rating_stats (đã JOIN ở trên)
            // Đảm bảo trả về đúng kiểu dữ liệu (num thay vì string)
            $r_sp['avg_rating'] = floatval($r_sp['avg_rating'] ?? 0.0);
            $r_sp['rating'] = floatval($r_sp['rating'] ?? $r_sp['avg_rating'] ?? 0.0);
            $r_sp['total_reviews'] = intval($r_sp['total_reviews'] ?? 0);
            $r_sp['reviews_count'] = intval($r_sp['reviews_count'] ?? $r_sp['total_reviews'] ?? 0);
            
            // Lấy số lượng đã bán từ cột ban trong bảng sanpham (dữ liệu thật)
            $r_sp['sold_count'] = intval($r_sp['ban'] ?? 0);
            
            // Star HTML
            $avg_rating = $r_sp['avg_rating'];
            $star_html = '';
            for ($i = 1; $i <= 5; $i++) {
                if ($i <= floor($avg_rating)) {
                    $star_html .= '<i class="fa fa-star" style="color: #ffc107"></i>';
                } elseif ($i - $avg_rating < 1) {
                    $star_html .= '<i class="fa fa-star-half-o" style="color: #ffc107"></i>';
                } else {
                    $star_html .= '<i class="fa fa-star-o" style="color: #ffc107"></i>';
                }
            }
            $r_sp['star_html'] = $star_html;
            
            $products[] = $r_sp;
        }
        
        // Tính toán thông tin phân trang
        $total_pages = ceil($total_favorites / $limit);
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách sản phẩm yêu thích thành công",
            "data" => [
                "products" => $products,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_favorites" => $total_favorites,
                    "limit" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                ],
                "user_id" => $user_id
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

