<?php
header("Access-Control-Allow-Methods: POST, OPTIONS");
require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
	http_response_code(200);
	exit;
}

$key = "Socdo123@2025";
$issuer = "api.socdo.vn";

$headers = function_exists('apache_request_headers') ? apache_request_headers() : [];
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';
$jwt = null;
if ($authHeader && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
	$jwt = $matches[1];
}

$user_id = isset($_POST['user_id']) ? intval($_POST['user_id']) : (isset($_GET['user_id']) ? intval($_GET['user_id']) : 0);

try {
	if (!$user_id && $jwt) {
		$decoded = JWT::decode($jwt, new Key($key, 'HS256'));
		if (!isset($decoded->iss) || $decoded->iss !== $issuer) {
			http_response_code(401);
			echo json_encode(["success" => false, "message" => "Issuer không hợp lệ"]);
			exit;
		}
		$user_id = isset($decoded->user_id) ? intval($decoded->user_id) : 0;
	}
	if ($user_id <= 0) {
		http_response_code(401);
		echo json_encode(["success" => false, "message" => "Thông tin người dùng không hợp lệ"]);
		exit;
	}

	if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
		http_response_code(405);
		echo json_encode(["success" => false, "message" => "Chỉ hỗ trợ phương thức POST"]);
		exit;
	}

	$order_id = intval($_POST['order_id'] ?? 0);
	$ma_don = addslashes(trim($_POST['ma_don'] ?? ''));
	$reason = addslashes(trim($_POST['reason'] ?? ''));

	if (!$order_id && !$ma_don) {
		http_response_code(400);
		echo json_encode(["success" => false, "message" => "Thiếu order_id hoặc ma_don"]);
		exit;
	}

	$where = $order_id ? "id='$order_id'" : "ma_don='$ma_don'";
	$check = mysqli_query($conn, "SELECT id,ma_don,shop_id,ho_ten,dien_thoai,status FROM donhang WHERE $where AND user_id='$user_id' LIMIT 1");
	if (!$check || mysqli_num_rows($check) == 0) {
		http_response_code(404);
		echo json_encode(["success" => false, "message" => "Không tìm thấy đơn hàng"]);
		exit;
	}
	$ord = mysqli_fetch_assoc($check);

	// Chỉ cho phép yêu cầu hủy khi trạng thái hiện tại là 0 hoặc 1
	if (!in_array(intval($ord['status']), [0,1])) {
		http_response_code(400);
		echo json_encode(["success" => false, "message" => "Đơn không thể yêu cầu hủy ở trạng thái hiện tại"]);
		exit;
	}

	$hientai = time();
	$upd = mysqli_query($conn, "UPDATE donhang SET status='3', ghi_chu=CONCAT(IFNULL(ghi_chu,''),'\nYêu cầu hủy: $reason'), date_update='$hientai' WHERE id='{$ord['id']}'");
	if (!$upd) {
		http_response_code(500);
		echo json_encode(["success" => false, "message" => "Không thể cập nhật trạng thái", "error" => mysqli_error($conn)]);
		exit;
	}

	// Gửi notification tới shop nếu có shop_id
	$shop_id = intval($ord['shop_id'] ?? 0);
	if ($shop_id > 0) {
		$noidung_notification = "Yêu cầu hủy đơn hàng: #" . $ord['ma_don'] . ( $reason ? " - Lý do: $reason" : "" );
		mysqli_query($conn, "INSERT INTO notification (user_id, sp_id, noi_dung, doc, bo_phan, admin, date_post) VALUES ('$shop_id','0','$noidung_notification','','donhang','0','$hientai')");
	}

	echo json_encode(["success" => true, "message" => "Đã gửi yêu cầu hủy đơn", "data" => ["ma_don" => $ord['ma_don'], "status" => 3, "date_update" => $hientai]]);

} catch (Exception $e) {
	http_response_code(401);
	echo json_encode(["success" => false, "message" => "Token không hợp lệ", "error" => $e->getMessage()]);
}
?>
