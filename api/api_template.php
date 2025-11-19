<?php
/**
 * API Template với Cache
 * Sử dụng template này cho tất cả API khác
 */

header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;
require_once './cache_helper.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get parameters
    $param1 = isset($_GET['param1']) ? trim($_GET['param1']) : '';
    $param2 = isset($_GET['param2']) ? intval($_GET['param2']) : 0;
    $limit = isset($_GET['limit']) ? max(1, min(2000, intval($_GET['limit']))) : 150;
    
    // Tạo cache key
    $cache_key = $cache->createKey('api_name', [
        'param1' => $param1,
        'param2' => $param2,
        'limit' => $limit
    ]);
    
    // Lấy dữ liệu từ cache hoặc database
    $response = $cache->getOrSet($cache_key, function() use ($param1, $param2, $limit, $conn) {
        // Query database
        $query = "SELECT * FROM table_name WHERE condition = '$param1' LIMIT $limit";
        $result = mysqli_query($conn, $query);
        
        if (!$result) {
            return [
                'success' => false,
                'message' => 'Lỗi truy vấn database: ' . mysqli_error($conn)
            ];
        }
        
        $data = [];
        while ($row = mysqli_fetch_assoc($result)) {
            $data[] = $row;
        }
        
        return [
            'success' => true,
            'message' => 'Lấy dữ liệu thành công',
            'data' => [
                'items' => $data,
                'total' => count($data)
            ]
        ];
    }, 300); // Cache 5 phút
    
    // Set HTTP status
    if ($response['success']) {
        http_response_code(200);
    } else {
        http_response_code(500);
    }
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} else {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Chỉ hỗ trợ phương thức GET'
    ]);
}
?>
