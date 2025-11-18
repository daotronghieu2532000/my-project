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
        $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 650;
        $category_id = isset($_GET['category_id']) ? intval($_GET['category_id']) : 0;
        $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : 0;
        $sort = isset($_GET['sort']) ? trim($_GET['sort']) : 'time-desc'; // time-desc, time-asc, price-asc, price-desc
        $min_price = isset($_GET['min_price']) ? intval($_GET['min_price']) : 0;
        $max_price = isset($_GET['max_price']) ? intval($_GET['max_price']) : 0;
        
        // Validate parameters
        if ($page < 1) $page = 1;
        if ($limit < 1 || $limit > 1000) $limit = 60;
        
        $offset = ($page - 1) * $limit;
        
        // Xây dựng WHERE clause
        // Logic: - Sản phẩm không có biến thể: chỉ cần kho chính > 0
        //        - Sản phẩm có biến thể: chỉ cần ít nhất 1 biến thể có kho > 0
        $where_conditions = array(
            "sanpham.status = 1", 
            "sanpham.active = 0",
            "sanpham.kho >= 0",
            "((NOT EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id) AND sanpham.kho > 0) OR EXISTS (SELECT 1 FROM phanloai_sanpham pl WHERE pl.sp_id = sanpham.id AND pl.kho_sanpham_socdo > 0))"
        );
        
        // Điều kiện ship 0đ - Logic từ transport table
        $where_conditions[] = "EXISTS (
            SELECT 1 FROM transport t 
            WHERE t.user_id = sanpham.shop 
            AND (t.free_ship_all = 1 OR t.free_ship_discount > 0)
        )";
        
        // Lọc theo danh mục
        if ($category_id > 0) {
            $where_conditions[] = "FIND_IN_SET('$category_id', sanpham.cat) > 0";
        }
        
        // Lọc theo shop
        if ($shop_id > 0) {
            $where_conditions[] = "sanpham.shop = '$shop_id'";
        }
        
        // Lọc theo giá
        if ($min_price > 0) {
            $where_conditions[] = "sanpham.gia_moi >= '$min_price'";
        }
        if ($max_price > 0) {
            $where_conditions[] = "sanpham.gia_moi <= '$max_price'";
        }
        
        $where_clause = "WHERE " . implode(" AND ", $where_conditions);
        
        // Đếm tổng số sản phẩm
        $count_query = "SELECT COUNT(*) as total FROM sanpham $where_clause";
        $count_result = mysqli_query($conn, $count_query);
        $total_records = 0;
        if ($count_result) {
            $count_row = mysqli_fetch_assoc($count_result);
            $total_records = $count_row['total'];
        }
        
        $total_pages = ceil($total_records / $limit);
        
        // Xử lý sắp xếp
        $allowed_sorts = ['time-desc', 'time-asc', 'price-asc', 'price-desc'];
        $sort = in_array($sort, $allowed_sorts) ? $sort : 'time-desc';
        
        switch ($sort) {
            case 'time-desc':
                $order_by = "ORDER BY sanpham.id DESC";
                break;
            case 'time-asc':
                $order_by = "ORDER BY sanpham.id ASC";
                break;
            case 'price-asc':
                $order_by = "ORDER BY sanpham.gia_moi ASC";
                break;
            case 'price-desc':
                $order_by = "ORDER BY sanpham.gia_moi DESC";
                break;
            default:
                $order_by = "ORDER BY sanpham.id DESC";
        }
        
        // Lấy danh sách sản phẩm với thông tin shop (sử dụng subquery để lấy transport đầu tiên)
        // JOIN với product_rating_stats để lấy rating và reviews
        // Nếu không có trong product_rating_stats, tính từ product_comments
            $products_query = "
            SELECT 
                sanpham.*,
                th.tieu_de as brand_name,
                th.anh_thuong_hieu as brand_logo,
                t.free_ship_all,
                t.free_ship_discount,
                t.free_ship_min_order,
                t.fee_ship_products,
                t.ten_kho AS warehouse_name,
                tm.tieu_de AS province_name,
                u.name as shop_name,
                u.avatar as shop_avatar,
                COALESCE(prs.total_reviews, 0) AS total_reviews,
                COALESCE(prs.total_reviews, 0) AS reviews_count,
                COALESCE(prs.average_rating, 0.0) AS avg_rating,
                COALESCE(prs.average_rating, 0.0) AS rating
            FROM sanpham
            LEFT JOIN thuong_hieu th ON th.id = sanpham.thuong_hieu
            LEFT JOIN (
                SELECT 
                    t1.user_id, 
                    t1.free_ship_all, 
                    t1.free_ship_discount, 
                    t1.free_ship_min_order, 
                    t1.fee_ship_products, 
                    t1.ten_kho, 
                    t1.province,
                    -- Ưu tiên fee_ship_products (Mode 3) trước, sau đó là mode cao nhất
                    CASE 
                        WHEN t1.fee_ship_products IS NOT NULL AND t1.fee_ship_products != '' THEN 3
                        ELSE t1.free_ship_all 
                    END as priority_mode,
                    CASE 
                        WHEN t1.fee_ship_products IS NOT NULL AND t1.fee_ship_products != '' THEN t1.fee_ship_products
                        ELSE NULL 
                    END as priority_fee_ship_products
                FROM transport t1
                WHERE (t1.free_ship_all IN (0,1,2,3) OR t1.free_ship_discount > 0 OR t1.fee_ship_products IS NOT NULL)
                AND t1.id = (
                    SELECT t2.id 
                    FROM transport t2 
                    WHERE t2.user_id = t1.user_id 
                    AND (t2.free_ship_all IN (0,1,2,3) OR t2.free_ship_discount > 0 OR t2.fee_ship_products IS NOT NULL)
                    ORDER BY 
                        -- Ưu tiên fee_ship_products trước
                        CASE WHEN t2.fee_ship_products IS NOT NULL AND t2.fee_ship_products != '' THEN 0 ELSE 1 END,
                        -- Sau đó ưu tiên mode cao nhất
                        t2.free_ship_all DESC,
                        -- Cuối cùng là ID nhỏ nhất
                        t2.id ASC
                    LIMIT 1
                )
            ) t ON t.user_id = sanpham.shop
            LEFT JOIN tinh_moi tm ON t.province = tm.id
            LEFT JOIN user_info u ON u.user_id = sanpham.shop
            LEFT JOIN product_rating_stats prs ON prs.product_id = sanpham.id AND prs.shop_id = sanpham.shop
            $where_clause 
            GROUP BY sanpham.id
            $order_by 
            LIMIT $offset, $limit
        ";
        
        $products_result = mysqli_query($conn, $products_query);
        
        if (!$products_result) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Lỗi truy vấn database"
            ]);
            exit;
        }
        
        $products = array();
        
        // Dùng dữ liệu thật từ database - không cần tính sold từ đơn hàng
        while ($product = mysqli_fetch_assoc($products_result)) {
            // Format dữ liệu sản phẩm
            $product_data = array();
            $product_data['id'] = intval($product['id']);
            $product_data['name'] = $product['tieu_de'];
            $product_data['slug'] = $product['link'];
            $product_data['price'] = intval($product['gia_moi']);
            $product_data['old_price'] = intval($product['gia_cu']);
            $product_data['discount_percent'] = 0;
            
            // Tính % giảm giá
            if ($product['gia_cu'] > 0 && $product['gia_moi'] < $product['gia_cu']) {
                $product_data['discount_percent'] = round((($product['gia_cu'] - $product['gia_moi']) / $product['gia_cu']) * 100);
            }
            
            $product_data['shop_id'] = intval($product['shop']);
            $product_data['category_ids'] = explode(',', $product['cat']);
            $product_data['category_ids'] = array_filter(array_map('intval', $product_data['category_ids']));
            $product_data['brand_id'] = intval($product['thuong_hieu']);
            $product_data['brand_name'] = $product['brand_name'] ?: '';
            $product_data['brand_logo'] = $product['brand_logo'] ? getImageUrlWithCDN($product['brand_logo']) : '';
            
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
            
            // Tạo URL sản phẩm
            $product_data['product_url'] = 'https://socdo.vn/san-pham/' . $product_data['id'] . '/' . $product_data['slug'] . '.html';
            
            // Thông tin ship 0đ - Chi tiết theo 4 mode
            $shipping_info = array();
            $shipping_info['has_free_shipping'] = true;
            
            // Sử dụng priority_mode và priority_fee_ship_products từ query
            $mode = intval($product['priority_mode'] ?? $product['free_ship_all'] ?? 0);
            $discount = intval($product['free_ship_discount'] ?? 0);
            $minOrder = intval($product['free_ship_min_order'] ?? 0);
            $feeShipProducts = $product['priority_fee_ship_products'] ?? $product['fee_ship_products'] ?? '';
            
            $shipping_info['free_ship_mode'] = $mode;
            $shipping_info['free_ship_discount_value'] = $discount;
            $shipping_info['min_order_value'] = $minOrder;
            $shipping_info['free_ship_type'] = 'unknown';
            $shipping_info['free_ship_label'] = '';
            $shipping_info['free_ship_details'] = '';
            $shipping_info['free_ship_badge_color'] = '#4CAF50'; // Green default
            
            // Lấy giá sản phẩm để kiểm tra điều kiện min_order
            $base_price = $product_data['price'];
            
            // Mode 1: Freeship toàn bộ (100%)
            if ($mode === 1) {
                $shipping_info['free_ship_type'] = 'full';
                $shipping_info['free_ship_label'] = 'Freeship 100%';
                $shipping_info['free_ship_badge_color'] = '#FF5722'; // Red-Orange
                if ($minOrder > 0) {
                    $shipping_info['free_ship_details'] = 'Miễn phí ship 100% cho đơn từ ' . number_format($minOrder) . 'đ';
                } else {
                    $shipping_info['free_ship_details'] = 'Miễn phí ship 100% - Không điều kiện';
                }
            }
            // Mode 0: Giảm cố định (VD: -15,000đ) - Cần kiểm tra điều kiện min_order
            elseif ($mode === 0 && $discount > 0) {
                if ($base_price >= $minOrder) {
                    $shipping_info['free_ship_type'] = 'fixed';
                    $shipping_info['free_ship_label'] = 'Giảm ' . number_format($discount) . 'đ';
                    $shipping_info['free_ship_badge_color'] = '#2196F3'; // Blue
                    if ($minOrder > 0) {
                        $shipping_info['free_ship_details'] = 'Giảm ' . number_format($discount) . 'đ phí ship cho đơn từ ' . number_format($minOrder) . 'đ';
                    } else {
                        $shipping_info['free_ship_details'] = 'Giảm ' . number_format($discount) . 'đ phí ship';
                    }
                } else {
                    // Có discount nhưng chưa đủ điều kiện min_order
                    $shipping_info['free_ship_type'] = 'conditional';
                    $shipping_info['free_ship_label'] = 'Giảm ' . number_format($discount) . 'đ';
                    $shipping_info['free_ship_badge_color'] = '#FF9800'; // Orange
                    $shipping_info['free_ship_details'] = 'Giảm ' . number_format($discount) . 'đ phí ship cho đơn từ ' . number_format($minOrder) . 'đ';
                }
            }
            // Mode 2: Giảm theo % (VD: -50%) - Cần kiểm tra điều kiện min_order
            elseif ($mode === 2 && $discount > 0) {
                if ($base_price >= $minOrder) {
                    $shipping_info['free_ship_type'] = 'percent';
                    $shipping_info['free_ship_label'] = 'Giảm ' . intval($discount) . '% ship';
                    $shipping_info['free_ship_badge_color'] = '#9C27B0'; // Purple
                    if ($minOrder > 0) {
                        $shipping_info['free_ship_details'] = 'Giảm ' . intval($discount) . '% phí ship cho đơn từ ' . number_format($minOrder) . 'đ';
                    } else {
                        $shipping_info['free_ship_details'] = 'Giảm ' . intval($discount) . '% phí ship';
                    }
                } else {
                    // Có discount nhưng chưa đủ điều kiện min_order
                    $shipping_info['free_ship_type'] = 'conditional';
                    $shipping_info['free_ship_label'] = 'Giảm ' . intval($discount) . '% ship';
                    $shipping_info['free_ship_badge_color'] = '#FF9800'; // Orange
                    $shipping_info['free_ship_details'] = 'Giảm ' . intval($discount) . '% phí ship cho đơn từ ' . number_format($minOrder) . 'đ';
                }
            }
            // Mode 3: Ưu đãi ship theo sản phẩm cụ thể - cần kiểm tra fee_ship_products
            elseif ($mode === 3) {
                $shipping_info['free_ship_type'] = 'per_product';
                $shipping_info['free_ship_badge_color'] = '#FF9800'; // Orange
                
                // Parse fee_ship_products để xem sản phẩm này có trong danh sách không
                $feeShipProductsArray = json_decode($feeShipProducts ?? '[]', true);
                $productId = intval($product['id']);
                $hasSupport = false;
                $supportDetail = '';
                $ship_discount_amount = 0;
                
                if (is_array($feeShipProductsArray)) {
                    foreach ($feeShipProductsArray as $cfg) {
                        if (intval($cfg['sp_id'] ?? 0) === $productId) {
                            $hasSupport = true;
                            $stype = $cfg['ship_type'] ?? 'vnd';
                            $val = floatval($cfg['ship_support'] ?? 0);
                            $ship_discount_amount = intval($val);
                            
                            if ($stype === 'percent') {
                                $supportDetail = 'Giảm ' . intval($val) . '% phí ship';
                                $shipping_info['free_ship_label'] = 'Giảm ' . intval($val) . '% ship';
                            } else {
                                $supportDetail = 'Hỗ trợ ship ' . number_format($val) . '₫';
                                $shipping_info['free_ship_label'] = 'Hỗ trợ ship ' . number_format($val) . '₫';
                            }
                            break;
                        }
                    }
                }
                
                // Chỉ hiển thị nếu có hỗ trợ ship cụ thể
                if ($hasSupport && $ship_discount_amount > 0) {
                    $shipping_info['free_ship_details'] = $supportDetail;
                } else {
                    $shipping_info['free_ship_label'] = '';
                    $shipping_info['free_ship_details'] = '';
                }
            }
            // Mode 0 với discount = 0: Freeship cơ bản
            elseif ($mode === 0 && $discount == 0) {
                $shipping_info['free_ship_type'] = 'basic';
                $shipping_info['free_ship_label'] = 'Freeship';
                $shipping_info['free_ship_badge_color'] = '#4CAF50'; // Green
                $shipping_info['free_ship_details'] = 'Miễn phí vận chuyển';
            }
            
            // Thông tin shop
            $shipping_info['shop_name'] = $product['shop_name'] ?? '';
            $shipping_info['shop_avatar'] = !empty($product['shop_avatar']) ? getImageUrlWithCDN($product['shop_avatar']) : '';
            
            $product_data['shipping_info'] = $shipping_info;
            
            // Xử lý voucher và freeship icons (giống product_suggest.php)
            $deal_shop = $product['shop'];
            $voucher_icon = '';
            $freeship_icon = '';
            $chinhhang_icon = '';
            
            $current_time = time();
            
            // Check voucher - Logic chuẩn với hệ thống
            // Kiểm tra voucher cho sản phẩm cụ thể
            $check_coupon = mysqli_query($conn, "SELECT id FROM coupon WHERE FIND_IN_SET('$product_data[id]', sanpham) AND shop = '$deal_shop' AND kieu = 'sanpham' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
            if (mysqli_num_rows($check_coupon) > 0) {
                $voucher_icon = 'Voucher';
            } else {
                // Kiểm tra voucher toàn shop
                $check_coupon_all = mysqli_query($conn, "SELECT id FROM coupon WHERE shop = '$deal_shop' AND kieu = 'all' AND status = '2' AND '$current_time' BETWEEN start AND expired LIMIT 1");
                if (mysqli_num_rows($check_coupon_all) > 0) {
                    $voucher_icon = 'Voucher';
                }
            }
            
            // Freeship icon từ shipping_info
            $freeship_icon = $shipping_info['free_ship_label'];
            
            // Chính hãng (giả định tất cả sản phẩm freeship đều chính hãng)
            $chinhhang_icon = 'Chính hãng';
            
            $product_data['voucher_icon'] = $voucher_icon;
            $product_data['freeship_icon'] = $freeship_icon;
            $product_data['chinhhang_icon'] = $chinhhang_icon;
            
            // Thông tin kho
            $product_data['warehouse_name'] = $product['warehouse_name'] ?? '';
            $product_data['province_name'] = $product['province_name'] ?? '';
            
            // Tags/Badges
            $badges = array();
            if ($product_data['discount_percent'] > 0) {
                $badges[] = 'Giảm ' . $product_data['discount_percent'] . '%';
            }
            // Không thêm "Freeship" vào badges vì đã có freeship_icon riêng
            $product_data['badges'] = $badges;
            
            // Thông tin bổ sung
            $product_data['is_authentic'] = 0; // Không có trường chinhhang trong DB thực tế
            $product_data['is_featured'] = intval($product['box_noibat']);
            $product_data['is_trending'] = 0; // Không có trường xu_huong trong DB thực tế
            $product_data['is_flash_sale'] = intval($product['box_flash']);
            $product_data['created_at'] = intval($product['date_post']);
            $product_data['updated_at'] = intval($product['date_post']); // Không có trường date_update trong DB thực tế
            
            // Format giá
            $product_data['price_formatted'] = number_format($product_data['price'], 0, ',', '.') . ' ₫';
            $product_data['old_price_formatted'] = $product_data['old_price'] > 0 ? number_format($product_data['old_price'], 0, ',', '.') . ' ₫' : '';
            
            // Rating và reviews từ product_rating_stats hoặc product_comments (đã JOIN ở trên)
            // Đảm bảo trả về đúng kiểu dữ liệu (num thay vì string)
            $product_data['rating'] = floatval($product['rating'] ?? $product['avg_rating'] ?? 0.0);
            $product_data['total_reviews'] = intval($product['total_reviews'] ?? 0);
            $product_data['reviews_count'] = intval($product['reviews_count'] ?? $product['total_reviews'] ?? 0);
            
            // Lấy số lượng đã bán từ cột ban trong bảng sanpham (dữ liệu thật)
            $product_data['sold'] = intval($product['ban'] ?? 0);
            $product_data['sold_count'] = $product_data['sold'];
            
            $products[] = $product_data;
        }
        
        $response = [
            "success" => true,
            "message" => "Lấy danh sách sản phẩm ship 0đ thành công",
            "data" => [
                "products" => $products,
                "pagination" => [
                    "current_page" => $page,
                    "total_pages" => $total_pages,
                    "total_records" => $total_records,
                    "per_page" => $limit,
                    "has_next" => $page < $total_pages,
                    "has_prev" => $page > 1
                ],
                "filters" => [
                    "category_id" => $category_id,
                    "shop_id" => $shop_id,
                    "sort" => $sort,
                    "min_price" => $min_price,
                    "max_price" => $max_price
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
 