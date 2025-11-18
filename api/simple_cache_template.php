<?php
/**
 * Template đơn giản cho Memcached Cache
 * 
 * Cách sử dụng:
 * 1. Copy đoạn code này vào đầu file API
 * 2. Thay đổi $cache_key và logic database
 * 3. Thay đổi thời gian cache (300 = 5 phút)
 */

header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';

// Khởi tạo Memcached
$memcached = new Memcached();
$memcached->addServer('127.0.0.1', 11211);

// Include config database
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get parameters
    $param1 = isset($_GET['param1']) ? trim($_GET['param1']) : 'default';
    $param2 = isset($_GET['param2']) ? intval($_GET['param2']) : 0;
    
    // Cache pattern - THAY ĐỔI TÊN KEY NÀY
    $cache_key = 'your_api_name_' . $param1 . '_' . $param2;
    $data = $memcached->get($cache_key);
    if ($data === false) {
        // Load từ database - THAY ĐỔI LOGIC NÀY
        $data = load_your_data($param1, $param2, $conn);
        $memcached->set($cache_key, $data, 300); // Cache 5 phút - THAY ĐỔI THỜI GIAN NÀY
    }
    
    // Return response
    echo json_encode($data);
    
} else {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Chỉ hỗ trợ phương thức GET'
    ]);
}

// Function load data từ database - THAY ĐỔI FUNCTION NÀY
function load_your_data($param1, $param2, $conn) {
    // Your database logic here
    $query = "SELECT * FROM your_table WHERE condition = '$param1' LIMIT $param2";
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
        'data' => $data
    ];
}
?>
