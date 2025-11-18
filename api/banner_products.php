<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT
$key = "Socdo123@2025"; // Key bí mật dùng để ký JWT
$issuer = "api.socdo.vn"; // Tên ứng dụng phát hành token

// Helper function để tạo URL ảnh với CDN domain
// Sử dụng CDN: https://socdo.cdn.vccloud.vn/
// Fallback sẽ được xử lý ở phía Flutter app
function getImageUrlWithCDN($image_path) {
    if (empty($image_path)) return '';
    
    // Nếu đã là URL đầy đủ, trả về nguyên
    if (strpos($image_path, 'http://') === 0 || strpos($image_path, 'https://') === 0) {
        return $image_path;
    }
    
    // Loại bỏ dấu / ở đầu nếu có
    $image_path = ltrim($image_path, '/');
    
    // Sử dụng CDN domain cho ảnh
    return 'https://socdo.cdn.vccloud.vn/' . $image_path;
}

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
        $vi_tri_hien_thi = isset($_GET['vi_tri_hien_thi']) ? trim($_GET['vi_tri_hien_thi']) : '';
        
        // Validate vị trí
        $allowed_positions = ['dau_trang', 'giua_trang', 'cuoi_trang'];
        if (!empty($vi_tri_hien_thi) && !in_array($vi_tri_hien_thi, $allowed_positions)) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Vị trí hiển thị không hợp lệ. Chỉ chấp nhận: dau_trang, giua_trang, cuoi_trang"
            ]);
            exit;
        }
        
        $current_time = time();
        
        // Xây dựng WHERE clause
        $where_conditions = array(
            "status = 1", // Chỉ lấy yêu cầu đang hiển thị
            "date_display_end >= '$current_time'", // Chưa hết hạn
            "vi_tri_hien_thi IS NOT NULL"
        );
        
        // Lọc theo vị trí nếu có
        if (!empty($vi_tri_hien_thi)) {
            $where_conditions[] = "vi_tri_hien_thi = '" . mysqli_real_escape_string($conn, $vi_tri_hien_thi) . "'";
        }
        
        $where_clause = "WHERE " . implode(" AND ", $where_conditions);
        
        // Lấy danh sách banner/sản phẩm đang hiển thị
        $query = "SELECT 
                    id,
                    ncc_id,
                    shop_name,
                    banner_path,
                    banner_link,
                    banner_type,
                    banner_width,
                    banner_height,
                    sanpham_ids,
                    vi_tri_hien_thi,
                    date_display_start,
                    date_display_end,
                    so_ngay_hien_thi
                  FROM ncc_yeu_cau_banner_sanpham 
                  $where_clause
                  ORDER BY 
                    CASE vi_tri_hien_thi 
                      WHEN 'dau_trang' THEN 1 
                      WHEN 'giua_trang' THEN 2 
                      WHEN 'cuoi_trang' THEN 3 
                    END ASC,
                    id DESC";
        
        $result = mysqli_query($conn, $query);
        
        if (!$result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
            ]);
            exit;
        }
        
        $banner_products_list = array();
        
        while ($row = mysqli_fetch_assoc($result)) {
            $banner_data = array();
            $banner_data['id'] = intval($row['id']);
            $banner_data['shop_id'] = intval($row['ncc_id']);
            $banner_data['shop_name'] = $row['shop_name'];
            $banner_data['position'] = $row['vi_tri_hien_thi'];
            $banner_data['position_name'] = '';
            
            // Tên vị trí
            switch ($row['vi_tri_hien_thi']) {
                case 'dau_trang':
                    $banner_data['position_name'] = 'Đầu trang';
                    break;
                case 'giua_trang':
                    $banner_data['position_name'] = 'Giữa trang';
                    break;
                case 'cuoi_trang':
                    $banner_data['position_name'] = 'Cuối trang';
                    break;
            }
            
            // Xử lý banner
            if (!empty($row['banner_path'])) {
                $banner_data['banner_url'] = getImageUrlWithCDN($row['banner_path']);
            } else {
                $banner_data['banner_url'] = '';
            }
            
            $banner_data['banner_link'] = $row['banner_link'] ?: '';
            $banner_data['banner_type'] = $row['banner_type']; // banner_doc hoặc banner_ngang
            $banner_data['banner_width'] = intval($row['banner_width']);
            $banner_data['banner_height'] = intval($row['banner_height']);
            
            // Thời gian hiển thị
            $banner_data['display_start'] = intval($row['date_display_start']);
            $banner_data['display_end'] = intval($row['date_display_end']);
            $banner_data['display_days'] = intval($row['so_ngay_hien_thi']);
            
            // Lấy danh sách sản phẩm
            $sanpham_ids = explode(',', $row['sanpham_ids']);
            $sanpham_ids = array_filter(array_map('intval', $sanpham_ids));
            
            $products = array();
            
            if (!empty($sanpham_ids)) {
                $sanpham_ids_str = implode(',', $sanpham_ids);
                
                // Lấy thông tin sản phẩm với check kho đầy đủ
                // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
                //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
                // Với sàn (shop = 0): lấy transport với user_id = 0
                // Với shop thường: lấy transport theo kho_id và user_id = shop
                // LEFT JOIN với product_rating_stats để lấy rating và reviews
                $products_query = "
                    SELECT 
                        sanpham.*,
                        th.tieu_de as brand_name,
                        th.anh_thuong_hieu as brand_logo,
                        COALESCE(t.ten_kho, t_san.ten_kho) AS warehouse_name,
                        COALESCE(tm.tieu_de, tm_san.tieu_de) AS province_name,
                        u.name as shop_name,
                        u.avatar as shop_avatar,
                        COALESCE(prs.total_reviews, 0) AS total_reviews,
                        COALESCE(prs.average_rating, 0.0) AS average_rating
                    FROM sanpham 
                    LEFT JOIN thuong_hieu th ON th.id = sanpham.thuong_hieu
                    LEFT JOIN transport t ON sanpham.kho_id = t.id AND sanpham.shop > 0 AND t.user_id = sanpham.shop
                    LEFT JOIN tinh_moi tm ON t.province = tm.id
                    LEFT JOIN transport t_san ON t_san.user_id = 0 AND sanpham.shop = 0 AND t_san.is_default = 1
                    LEFT JOIN tinh_moi tm_san ON t_san.province = tm_san.id
                    LEFT JOIN user_info u ON u.user_id = sanpham.shop
                    LEFT JOIN product_rating_stats prs ON prs.product_id = sanpham.id AND prs.shop_id = sanpham.shop
                    WHERE sanpham.id IN ($sanpham_ids_str)
                    AND sanpham.status = 1
                    AND sanpham.active = 0
                    AND sanpham.kho >= 0
                    AND ((NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id) AND sanpham.kho > 0) 
                         OR EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id AND pl.kho_sanpham_socdo > 0))
                    ORDER BY FIELD(sanpham.id, $sanpham_ids_str)
                ";
                
                $products_result = mysqli_query($conn, $products_query);
                
                // Không cần tính sold_counts từ đơn hàng nữa, sẽ dùng cột ban từ sanpham
                
                if ($products_result) {
                    while ($product = mysqli_fetch_assoc($products_result)) {
                        // Format dữ liệu sản phẩm (giống products_freeship.php)
                        $product_data = array();
                        $product_data['id'] = intval($product['id']);
                        $product_data['name'] = $product['tieu_de'];
                        $product_data['slug'] = $product['link'];
                        
                        // Xử lý giá từ bảng phanloai_sanpham nếu có (giống product_detail.php)
                        $product_id = intval($product['id']);
                        $sql_pl = "SELECT MIN(gia_moi) AS gia_moi_min, MAX(gia_cu) AS gia_cu_max 
                                   FROM phanloai_sanpham 
                                   WHERE sp_id = '$product_id' AND kho_sanpham_socdo > 0";
                        $res_pl = mysqli_query($conn, $sql_pl);
                        $row_pl = mysqli_fetch_assoc($res_pl);
                        
                        if ($row_pl && $row_pl['gia_moi_min'] !== null && $row_pl['gia_moi_min'] > 0) {
                            $gia_moi_main = (int) $row_pl['gia_moi_min'];
                            $gia_cu_main = (int) $row_pl['gia_cu_max'];
                        } else {
                            $gia_cu_main = (int) preg_replace('/[^0-9]/', '', $product['gia_cu']);
                            $gia_moi_main = (int) preg_replace('/[^0-9]/', '', $product['gia_moi']);
                        }
                        
                        $product_data['price'] = $gia_moi_main;
                        $product_data['old_price'] = $gia_cu_main;
                        $product_data['discount_percent'] = 0;
                        
                        // Tính % giảm giá
                        if ($gia_cu_main > 0 && $gia_moi_main < $gia_cu_main) {
                            $product_data['discount_percent'] = round((($gia_cu_main - $gia_moi_main) / $gia_cu_main) * 100);
                        }
                        
                        $product_data['shop_id'] = intval($product['shop']);
                        $product_data['category_ids'] = explode(',', $product['cat']);
                        $product_data['category_ids'] = array_filter(array_map('intval', $product_data['category_ids']));
                        $product_data['brand_id'] = intval($product['thuong_hieu']);
                        $product_data['brand_name'] = $product['brand_name'] ?: '';
                        // Xử lý brand_logo
                        if (!empty($product['brand_logo'])) {
                            $product_data['brand_logo'] = getImageUrlWithCDN($product['brand_logo']);
                        } else {
                            $product_data['brand_logo'] = '';
                        }
                        
                        // Xử lý hình ảnh
                        if (!empty($product['minh_hoa'])) {
                            $product_data['image'] = getImageUrlWithCDN($product['minh_hoa']);
                            
                            // Tạo thumbnail
                            $thumb_image = str_replace('/uploads/minh-hoa/', '/uploads/thumbs/sanpham_anh_340x340/', $product['minh_hoa']);
                            $product_data['thumb'] = getImageUrlWithCDN($thumb_image);
                        } else {
                            $product_data['image'] = '';
                            $product_data['thumb'] = '';
                        }
                        
                        // Thêm field 'anh' (gallery images) để app có thể sử dụng khi vào chi tiết
                        // Xử lý danh sách ảnh gallery từ cột 'anh'
                        $gallery_images = array();
                        if (!empty($product['anh'])) {
                            $image_list = explode(',', $product['anh']);
                            foreach ($image_list as $img) {
                                $img = trim($img);
                                if (!empty($img)) {
                                    $gallery_images[] = getImageUrlWithCDN($img);
                                }
                            }
                        }
                        // Nếu không có ảnh gallery, sử dụng ảnh chính
                        if (empty($gallery_images) && !empty($product_data['image'])) {
                            $gallery_images[] = $product_data['image'];
                        }
                        $product_data['gallery_images'] = $gallery_images;
                        // Giữ nguyên field 'anh' từ database để app có thể parse
                        $product_data['anh'] = $product['anh'] ?? '';
                        
                        // Tạo URL sản phẩm
                        $product_data['product_url'] = 'https://socdo.vn/san-pham/' . $product_data['id'] . '/' . $product_data['slug'] . '.html';
                        
                        // Thông tin ship 0đ - Logic từ transport table
                        $shipping_info = array();
                        $shipping_info['has_free_shipping'] = false;
                        
                        $deal_shop = $product['shop'];
                        $current_time_check = time();
                        
                        // Check freeship
                        $check_freeship = mysqli_query($conn, "SELECT free_ship_all, free_ship_discount, free_ship_min_order, fee_ship_products FROM transport WHERE user_id = '$deal_shop' AND (free_ship_all > 0 OR free_ship_discount > 0 OR fee_ship_products IS NOT NULL) LIMIT 1");
                        
                        if ($check_freeship && mysqli_num_rows($check_freeship) > 0) {
                            $ship_data = mysqli_fetch_assoc($check_freeship);
                            $mode = intval($ship_data['free_ship_all'] ?? 0);
                            $discount = intval($ship_data['free_ship_discount'] ?? 0);
                            $minOrder = intval($ship_data['free_ship_min_order'] ?? 0);
                            $feeShipProducts = $ship_data['fee_ship_products'] ?? '';
                            
                            $base_price = $product_data['price'];
                            
                            $shipping_info['free_ship_mode'] = $mode;
                            $shipping_info['free_ship_discount_value'] = $discount;
                            $shipping_info['min_order_value'] = $minOrder;
                            $shipping_info['free_ship_type'] = 'unknown';
                            $shipping_info['free_ship_label'] = '';
                            $shipping_info['free_ship_details'] = '';
                            $shipping_info['free_ship_badge_color'] = '#4CAF50';
                            
                            // Mode 1: Freeship toàn bộ (100%)
                            if ($mode === 1) {
                                $shipping_info['has_free_shipping'] = true;
                                $shipping_info['free_ship_type'] = 'full';
                                $shipping_info['free_ship_label'] = 'Freeship 100%';
                                $shipping_info['free_ship_badge_color'] = '#FF5722';
                                if ($minOrder > 0) {
                                    $shipping_info['free_ship_details'] = 'Miễn phí ship 100% cho đơn từ ' . number_format($minOrder) . 'đ';
                                } else {
                                    $shipping_info['free_ship_details'] = 'Miễn phí ship 100% - Không điều kiện';
                                }
                            }
                            // Mode 0: Giảm cố định
                            elseif ($mode === 0 && $discount > 0) {
                                if ($base_price >= $minOrder) {
                                    $shipping_info['has_free_shipping'] = true;
                                    $shipping_info['free_ship_type'] = 'fixed';
                                    $shipping_info['free_ship_label'] = 'Giảm ' . number_format($discount) . 'đ';
                                    $shipping_info['free_ship_badge_color'] = '#2196F3';
                                    if ($minOrder > 0) {
                                        $shipping_info['free_ship_details'] = 'Giảm ' . number_format($discount) . 'đ phí ship cho đơn từ ' . number_format($minOrder) . 'đ';
                                    } else {
                                        $shipping_info['free_ship_details'] = 'Giảm ' . number_format($discount) . 'đ phí ship';
                                    }
                                }
                            }
                            // Mode 2: Giảm theo %
                            elseif ($mode === 2 && $discount > 0) {
                                if ($base_price >= $minOrder) {
                                    $shipping_info['has_free_shipping'] = true;
                                    $shipping_info['free_ship_type'] = 'percent';
                                    $shipping_info['free_ship_label'] = 'Giảm ' . intval($discount) . '% ship';
                                    $shipping_info['free_ship_badge_color'] = '#9C27B0';
                                    if ($minOrder > 0) {
                                        $shipping_info['free_ship_details'] = 'Giảm ' . intval($discount) . '% phí ship cho đơn từ ' . number_format($minOrder) . 'đ';
                                    } else {
                                        $shipping_info['free_ship_details'] = 'Giảm ' . intval($discount) . '% phí ship';
                                    }
                                }
                            }
                            // Mode 3: Ưu đãi ship theo sản phẩm
                            elseif ($mode === 3 && !empty($feeShipProducts)) {
                                $feeShipProductsArray = json_decode($feeShipProducts, true);
                                $productId = intval($product['id']);
                                
                                if (is_array($feeShipProductsArray)) {
                                    foreach ($feeShipProductsArray as $cfg) {
                                        if (intval($cfg['sp_id'] ?? 0) === $productId) {
                                            $stype = $cfg['ship_type'] ?? 'vnd';
                                            $val = floatval($cfg['ship_support'] ?? 0);
                                            
                                            if ($val > 0) {
                                                $shipping_info['has_free_shipping'] = true;
                                                $shipping_info['free_ship_type'] = 'per_product';
                                                $shipping_info['free_ship_badge_color'] = '#FF9800';
                                                
                                                if ($stype === 'percent') {
                                                    $shipping_info['free_ship_label'] = 'Giảm ' . intval($val) . '% ship';
                                                    $shipping_info['free_ship_details'] = 'Giảm ' . intval($val) . '% phí ship';
                                                } else {
                                                    $shipping_info['free_ship_label'] = 'Hỗ trợ ship ' . number_format($val) . '₫';
                                                    $shipping_info['free_ship_details'] = 'Hỗ trợ ship ' . number_format($val) . '₫';
                                                }
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
                            // Mode 0 với discount = 0: Freeship cơ bản
                            elseif ($mode === 0 && $discount == 0) {
                                $shipping_info['has_free_shipping'] = true;
                                $shipping_info['free_ship_type'] = 'basic';
                                $shipping_info['free_ship_label'] = 'Freeship';
                                $shipping_info['free_ship_badge_color'] = '#4CAF50';
                                $shipping_info['free_ship_details'] = 'Miễn phí vận chuyển';
                            }
                            
                            $shipping_info['shop_name'] = $product['shop_name'] ?? '';
                            // Xử lý shop_avatar
                            if (!empty($product['shop_avatar'])) {
                                $shipping_info['shop_avatar'] = getImageUrlWithCDN($product['shop_avatar']);
                            } else {
                                $shipping_info['shop_avatar'] = '';
                            }
                        }
                        
                        $product_data['shipping_info'] = $shipping_info;
                        
                        // Check voucher
                        $voucher_icon = '';
                        $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('{$product['id']}', sanpham) AND shop = '$deal_shop' AND kieu = 'sanpham' AND status = '2' AND '$current_time_check' BETWEEN start AND expired LIMIT 1");
                        if (mysqli_num_rows($check_coupon) > 0) {
                            $voucher_icon = 'Voucher';
                        } else {
                            $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND status = '2' AND '$current_time_check' BETWEEN start AND expired LIMIT 1");
                            if (mysqli_num_rows($check_coupon_all) > 0) {
                                $voucher_icon = 'Voucher';
                            }
                        }
                        
                        $chinhhang_icon = 'Chính hãng';
                        
                        $product_data['voucher_icon'] = $voucher_icon;
                        $product_data['freeship_icon'] = $shipping_info['free_ship_label'] ?? '';
                        $product_data['chinhhang_icon'] = $chinhhang_icon;
                        
                        // Tags/Badges - giống products_same_shop.php
                        $badges = array();
                        if ($product_data['discount_percent'] > 0) {
                            $badges[] = 'Giảm ' . $product_data['discount_percent'] . '%';
                        }
                        if (!empty($voucher_icon)) {
                            $badges[] = $voucher_icon;
                        }
                        if (!empty($shipping_info['free_ship_label'])) {
                            $badges[] = $shipping_info['free_ship_label'];
                        }
                        if ($product['box_flash'] == 1) {
                            $badges[] = 'Flash Sale';
                        }
                        $badges[] = $chinhhang_icon;
                        $product_data['badges'] = $badges;
                        
                        // Thông tin bổ sung
                        $product_data['warehouse_name'] = $product['warehouse_name'] ?? '';
                        
                        // Xử lý province_name - loại bỏ "Tỉnh " và "Thành phố "
                        $province_name = $product['province_name'] ?? '';
                        if (empty($province_name)) {
                            $province_name = 'Thành phố Hà Nội';
                        }
                        $province_name = str_replace(['Tỉnh ', 'Thành phố '], '', $province_name);
                        $product_data['province_name'] = $province_name;
                        
                        $product_data['is_authentic'] = 0;
                        $product_data['is_featured'] = intval($product['box_noibat']);
                        $product_data['is_trending'] = 0;
                        $product_data['is_flash_sale'] = intval($product['box_flash']);
                        $product_data['created_at'] = intval($product['date_post']);
                        $product_data['updated_at'] = intval($product['date_post']);
                        
                        // Lấy rating và reviews từ product_rating_stats (đã JOIN ở trên)
                        $product_data['rating'] = floatval($product['average_rating']);
                        $product_data['reviews_count'] = intval($product['total_reviews']);
                        
                        // Lấy số lượng đã bán từ cột ban trong bảng sanpham (dữ liệu thật)
                        $product_data['sold_count'] = intval($product['ban']);
                        
                        // Format giá
                        $product_data['price_formatted'] = number_format($product_data['price'], 0, ',', '.') . ' ₫';
                        $product_data['old_price_formatted'] = $product_data['old_price'] > 0 ? number_format($product_data['old_price'], 0, ',', '.') . ' ₫' : '';
                        
                        $products[] = $product_data;
                    }
                }
            }
            
            $banner_data['products'] = $products;
            $banner_data['product_count'] = count($products);
            
            $banner_products_list[] = $banner_data;
        }
        
        // Nếu không có vi_tri_hien_thi, trả về theo cấu trúc 3 vị trí
        if (empty($vi_tri_hien_thi)) {
            $response_data = array(
                'dau_trang' => null,
                'giua_trang' => null,
                'cuoi_trang' => null
            );
            
            foreach ($banner_products_list as $item) {
                if (isset($response_data[$item['position']])) {
                    $response_data[$item['position']] = $item;
                }
            }
            
            $response = [
                "success" => true,
                "message" => "Lấy danh sách banner và sản phẩm thành công",
                "data" => $response_data
            ];
        } else {
            // Nếu có vi_tri_hien_thi, trả về 1 item hoặc null
            $response = [
                "success" => true,
                "message" => "Lấy banner và sản phẩm thành công",
                "data" => !empty($banner_products_list) ? $banner_products_list[0] : null
            ];
        }
        
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

