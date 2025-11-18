<?php
header("Access-Control-Allow-Methods: GET");
header('Content-Type: application/json; charset=utf-8');
require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
    $config_path = '../../../../../includes/config.php';
}
require_once $config_path;
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Cấu hình thông tin JWT (tùy chọn cho GET)
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

$method = $_SERVER['REQUEST_METHOD'];

try {
    if ($method === 'GET') {
        // Lấy thống kê đánh giá sản phẩm
        $product_id = isset($_GET['product_id']) ? intval($_GET['product_id']) : 0;
        $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : 0;
        
        if ($product_id <= 0) {
            http_response_code(400);
            echo json_encode(array("success" => false, "message" => "Thiếu product_id"));
            exit;
        }
        
        // Nếu không có shop_id, lấy từ sản phẩm
        if ($shop_id <= 0) {
            $product_query = "SELECT shop FROM sanpham WHERE id = $product_id LIMIT 1";
            $product_result = mysqli_query($conn, $product_query);
            if ($product_result && mysqli_num_rows($product_result) > 0) {
                $product_row = mysqli_fetch_assoc($product_result);
                $shop_id = intval($product_row['shop']);
            }
        }
        
        // Lấy thống kê từ product_rating_stats
        $stats_query = "SELECT * FROM product_rating_stats WHERE product_id = $product_id AND shop_id = $shop_id LIMIT 1";
        $stats_result = mysqli_query($conn, $stats_query);
        
        if (!$stats_result) {
            http_response_code(500);
            echo json_encode(array(
                "success" => false,
                "message" => "Lỗi truy vấn: " . mysqli_error($conn)
            ));
            exit;
        }
        
        if (mysqli_num_rows($stats_result) > 0) {
            $stats = mysqli_fetch_assoc($stats_result);
            
            // Tính phần trăm cho mỗi mức đánh giá
            $total_reviews = intval($stats['total_reviews']);
            $rating_5 = intval($stats['rating_5']);
            $rating_4 = intval($stats['rating_4']);
            $rating_3 = intval($stats['rating_3']);
            $rating_2 = intval($stats['rating_2']);
            $rating_1 = intval($stats['rating_1']);
            
            $percent_5 = $total_reviews > 0 ? round(($rating_5 / $total_reviews) * 100, 1) : 0;
            $percent_4 = $total_reviews > 0 ? round(($rating_4 / $total_reviews) * 100, 1) : 0;
            $percent_3 = $total_reviews > 0 ? round(($rating_3 / $total_reviews) * 100, 1) : 0;
            $percent_2 = $total_reviews > 0 ? round(($rating_2 / $total_reviews) * 100, 1) : 0;
            $percent_1 = $total_reviews > 0 ? round(($rating_1 / $total_reviews) * 100, 1) : 0;
            
            http_response_code(200);
            echo json_encode(array(
                "success" => true,
                "message" => "Lấy thống kê đánh giá thành công",
                "data" => array(
                    "product_id" => intval($stats['product_id']),
                    "shop_id" => intval($stats['shop_id']),
                    "total_reviews" => $total_reviews,
                    "average_rating" => floatval($stats['average_rating']),
                    "rating_breakdown" => array(
                        "5" => array(
                            "count" => $rating_5,
                            "percent" => $percent_5
                        ),
                        "4" => array(
                            "count" => $rating_4,
                            "percent" => $percent_4
                        ),
                        "3" => array(
                            "count" => $rating_3,
                            "percent" => $percent_3
                        ),
                        "2" => array(
                            "count" => $rating_2,
                            "percent" => $percent_2
                        ),
                        "1" => array(
                            "count" => $rating_1,
                            "percent" => $percent_1
                        )
                    )
                )
            ));
        } else {
            // Không có thống kê, trả về mặc định
            http_response_code(200);
            echo json_encode(array(
                "success" => true,
                "message" => "Lấy thống kê đánh giá thành công",
                "data" => array(
                    "product_id" => $product_id,
                    "shop_id" => $shop_id,
                    "total_reviews" => 0,
                    "average_rating" => 0.0,
                    "rating_breakdown" => array(
                        "5" => array("count" => 0, "percent" => 0),
                        "4" => array("count" => 0, "percent" => 0),
                        "3" => array("count" => 0, "percent" => 0),
                        "2" => array("count" => 0, "percent" => 0),
                        "1" => array("count" => 0, "percent" => 0)
                    )
                )
            ));
        }
        
    } else {
        http_response_code(405);
        echo json_encode(array("success" => false, "message" => "Chỉ hỗ trợ phương thức GET"));
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(array(
        "success" => false,
        "message" => "Lỗi hệ thống",
        "error" => $e->getMessage()
    ));
}
?>

