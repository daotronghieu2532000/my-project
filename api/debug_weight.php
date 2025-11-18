<?php
// Script debug cân nặng sản phẩm
header("Access-Control-Allow-Methods: GET, POST");
header("Content-Type: application/json; charset=utf-8");

// Database connection
$conn = mysqli_connect("localhost", "socdo", "Viettel@123", "socdo");
if (!$conn) {
    echo json_encode(['success' => false, 'message' => 'Database connection failed: ' . mysqli_connect_error()]);
    exit;
}
mysqli_set_charset($conn, "utf8mb4");

$method = $_SERVER['REQUEST_METHOD'];
$params = [];
if ($method === 'POST') {
    $raw = file_get_contents('php://input');
    $decodedBody = json_decode($raw, true);
    if (is_array($decodedBody)) $params = $decodedBody;
}
if ($method === 'GET') {
    $params = $_GET;
}

$user_id = intval($params['user_id'] ?? 0);
$items = $params['items'] ?? [];

if (empty($items)) {
    echo json_encode(['success' => false, 'message' => 'Thiếu items']);
    exit;
}

$debug = [
    'mode' => 'debug_weight',
    'items_input' => $items,
    'item_weights' => [],
    'weight_summary' => []
];

$total_weight = 0;
$total_value = 0;

foreach ($items as $it) {
    $pid = intval($it['product_id'] ?? 0);
    $qty = max(1, intval($it['quantity'] ?? 1));
    if ($pid <= 0) continue;
    
    $q = mysqli_query($conn, "SELECT gia_moi, can_nang_tinhship, shop, tieu_de FROM sanpham WHERE id='$pid' LIMIT 1");
    if ($q && mysqli_num_rows($q) > 0) {
        $r = mysqli_fetch_assoc($q);
        $price = intval($r['gia_moi'] ?? 0);
        $shopOfItem = intval($r['shop'] ?? 0);
        $product_name = $r['tieu_de'] ?? 'Unknown';
        
        // Cân nặng từ DB
        $w_gram_per_item_raw = intval($r['can_nang_tinhship'] ?? 0);
        $w_gram_per_item = $w_gram_per_item_raw;
        
        // Nếu không có hoặc = 0, dùng mặc định 500g
        if ($w_gram_per_item <= 0) {
            $w_gram_per_item = 500;
        }
        
        // Giới hạn an toàn: 30g - 5000g
        if ($w_gram_per_item < 30) $w_gram_per_item = 30;
        if ($w_gram_per_item > 5000) $w_gram_per_item = 5000;
        
        $line_value = $price * $qty;
        $line_weight = $w_gram_per_item * $qty;
        $total_value += $line_value;
        $total_weight += $line_weight;
        
        $debug['item_weights'][] = [
            'product_id' => $pid,
            'product_name' => $product_name,
            'qty' => $qty,
            'w_gram_per_item_raw' => $w_gram_per_item_raw,
            'w_gram_per_item' => $w_gram_per_item,
            'w_kg_per_item' => round($w_gram_per_item / 1000, 3),
            'price' => $price,
            'line_value' => $line_value,
            'line_weight' => $line_weight,
            'line_weight_kg' => round($line_weight / 1000, 3),
            'shop' => $shopOfItem,
            'weight_source' => $w_gram_per_item_raw > 0 ? 'database' : 'default_500g'
        ];
    }
}

$debug['weight_summary'] = [
    'total_items' => count($items),
    'total_weight_grams' => $total_weight,
    'total_weight_kg' => round($total_weight / 1000, 3),
    'total_value_vnd' => $total_value,
    'items_with_db_weight' => count(array_filter($debug['item_weights'], function($item) { return $item['weight_source'] === 'database'; })),
    'items_with_default_weight' => count(array_filter($debug['item_weights'], function($item) { return $item['weight_source'] === 'default_500g'; })),
    'avg_weight_per_item_grams' => count($debug['item_weights']) > 0 ? round($total_weight / count($debug['item_weights']), 2) : 0,
    'avg_weight_per_item_kg' => count($debug['item_weights']) > 0 ? round($total_weight / count($debug['item_weights']) / 1000, 3) : 0
];

echo json_encode([
    'success' => true,
    'message' => 'Debug cân nặng sản phẩm',
    'data' => $debug
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
?>
