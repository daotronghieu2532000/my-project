<?php
header("Access-Control-Allow-Methods: GET");
require_once './vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// JWT config
$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

// Authorization header
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
    $decoded = JWT::decode($jwt, new Key($key, 'HS256'));
    if ($decoded->iss !== $issuer) {
        http_response_code(401);
        echo json_encode(array("message" => "Issuer không hợp lệ"));
        exit;
    }

    $method = $_SERVER['REQUEST_METHOD'];
    if ($method !== 'GET') {
        http_response_code(405);
        echo json_encode(["success" => false, "message" => "Chỉ hỗ trợ phương thức GET"]);
        exit;
    }

    // Input params
    $type = isset($_GET['type']) ? strtolower(trim($_GET['type'])) : 'province'; // province | district | ward
    $tinh = isset($_GET['tinh']) ? intval($_GET['tinh']) : 0;      // province id (for district/ward)
    $huyen = isset($_GET['huyen']) ? intval($_GET['huyen']) : 0;    // district id (for ward)
    $keyword = isset($_GET['keyword']) ? trim($_GET['keyword']) : '';
    $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 500;

    if ($page < 1) $page = 1;
    if ($limit < 1 || $limit > 1000) $limit = 500;
    $offset = ($page - 1) * $limit;

    // Build query by type
    $where = [];
    $orderBy = 'thu_tu ASC, id ASC';
    $table = '';

    if ($type === 'province') {
        $table = 'tinh_moi';
        if ($keyword !== '') {
            $kw = mysqli_real_escape_string($conn, $keyword);
            $where[] = "(tieu_de LIKE '%$kw%' OR link LIKE '%$kw%' OR id_tinh LIKE '%$kw%')";
        }
    } elseif ($type === 'district') {
        $table = 'huyen_moi';
        if ($tinh > 0) {
            $where[] = "tinh = '$tinh'";
        } else {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "Thiếu tham số tinh (province id) cho type=district"]);
            exit;
        }
        if ($keyword !== '') {
            $kw = mysqli_real_escape_string($conn, $keyword);
            $where[] = "(tieu_de LIKE '%$kw%' OR link LIKE '%$kw%' OR id_huyen LIKE '%$kw%')";
        }
    } elseif ($type === 'ward') {
        $table = 'xa_moi';
        if ($huyen > 0) {
            $where[] = "huyen = '$huyen'";
        } else {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "Thiếu tham số huyen (district id) cho type=ward"]);
            exit;
        }
        if ($tinh > 0) {
            $where[] = "tinh = '$tinh'";
        }
        if ($keyword !== '') {
            $kw = mysqli_real_escape_string($conn, $keyword);
            $where[] = "(tieu_de LIKE '%$kw%' OR link LIKE '%$kw%' OR id_xa LIKE '%$kw%')";
        }
    } else {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Giá trị type không hợp lệ. Hỗ trợ: province, district, ward"]);
        exit;
    }

    $whereSql = count($where) ? ('WHERE ' . implode(' AND ', $where)) : '';

    // Count
    $count_query = "SELECT COUNT(*) AS total FROM $table $whereSql";
    $count_res = mysqli_query($conn, $count_query);
    if (!$count_res) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Lỗi truy vấn database: count"]);
        exit;
    }
    $total = (int) mysqli_fetch_assoc($count_res)['total'];
    $total_pages = $limit ? (int) ceil($total / $limit) : 1;

    // List
    $selectFields = '*';
    if ($type === 'province') {
        $selectFields = 'id, id_tinh, tieu_de, link, thu_tu, mien, vung';
    } elseif ($type === 'district') {
        $selectFields = 'id, tinh, id_huyen, tieu_de, link, thu_tu';
    } else { // ward
        $selectFields = 'id, tinh, huyen, id_xa, tieu_de, link, thu_tu';
    }

    $query = "SELECT $selectFields FROM $table $whereSql ORDER BY $orderBy LIMIT $offset, $limit";
    $res = mysqli_query($conn, $query);
    if (!$res) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Lỗi truy vấn database: list"]);
        exit;
    }

    $items = [];
    while ($row = mysqli_fetch_assoc($res)) {
        // Normalize field names for consistency
        if ($type === 'province') {
            $items[] = [
                'id' => (int) $row['id'],
                'code' => (string) $row['id_tinh'],
                'name' => $row['tieu_de'],
                'slug' => $row['link'],
                'region' => $row['mien'] !== null ? $row['mien'] : '',
                'area' => $row['vung'] !== null ? $row['vung'] : '',
                'order' => (int) $row['thu_tu']
            ];
        } elseif ($type === 'district') {
            $items[] = [
                'id' => (int) $row['id'],
                'province_id' => (int) $row['tinh'],
                'code' => (string) $row['id_huyen'],
                'name' => $row['tieu_de'],
                'slug' => $row['link'],
                'order' => (int) $row['thu_tu']
            ];
        } else {
            $items[] = [
                'id' => (int) $row['id'],
                'province_id' => (int) $row['tinh'],
                'district_id' => (int) $row['huyen'],
                'code' => (string) $row['id_xa'],
                'name' => $row['tieu_de'],
                'slug' => $row['link'],
                'order' => (int) $row['thu_tu']
            ];
        }
    }

    $response = [
        'success' => true,
        'message' => 'Lấy danh sách địa phương thành công',
        'data' => [
            'type' => $type,
            'items' => $items,
            'pagination' => [
                'current_page' => $page,
                'total_pages' => $total_pages,
                'total_records' => $total,
                'limit' => $limit,
                'has_next' => $page < $total_pages,
                'has_prev' => $page > 1
            ],
            'filters' => [
                'tinh' => $tinh,
                'huyen' => $huyen,
                'keyword' => $keyword
            ]
        ]
    ];

	
    http_response_code(200);
    echo json_encode($response, JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(array(
        "success" => false,
        "message" => "Token không hợp lệ",
        "error" => $e->getMessage()
    ));
}
?>


