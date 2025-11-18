<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Lấy danh sách ngân hàng
    $banks_query = "SELECT id, name, code, logo FROM banks WHERE status = 1 ORDER BY name ASC";
    $banks_result = mysqli_query($conn, $banks_query);
    
    if (!$banks_result) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Lỗi truy vấn database: " . mysqli_error($conn)
        ]);
        exit;
    }
    
    $banks = array();
    
    while ($bank = mysqli_fetch_assoc($banks_result)) {
        $bank_data = array();
        $bank_data['id'] = intval($bank['id']);
        $bank_data['name'] = $bank['name'];
        $bank_data['code'] = $bank['code'];
        $bank_data['logo'] = $bank['logo'] ? 'https://' . $_SERVER['HTTP_HOST'] . '/' . $bank['logo'] : '';
        
        $banks[] = $bank_data;
    }
    
    $response = [
        "success" => true,
        "message" => "Lấy danh sách ngân hàng thành công",
        "data" => [
            "banks" => $banks,
            "total_banks" => count($banks)
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
?>
