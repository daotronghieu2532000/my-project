<?php
/**
 * API: Create Affiliate Short Link
 * Method: POST
 * URL: /v1/affiliate_create_link
 * Body: {
 *   "user_id": 123,
 *   "sp_id": 456
 * }
 * 
 * Description: Create or get existing affiliate short link for a product
 * 
 * Response: {
 *   "success": true,
 *   "data": {
 *     "short_link": "https://socdo.xyz/x/abc123",
 *     "full_link": "https://socdo.vn/product/...",
 *     "sp_id": 456
 *   }
 * }
 */

require_once './vendor/autoload.php';
$config_path = '/home/api.socdo.vn/public_html/includes/config.php';
if (!file_exists($config_path)) {
	$config_path = '../../../../../includes/config.php';
}
require_once $config_path;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

header('Content-Type: application/json; charset=utf-8');

// Get POST data
$input = json_decode(file_get_contents('php://input'), true);
$user_id = isset($input['user_id']) ? intval($input['user_id']) : 0;
$sp_id = isset($input['sp_id']) ? intval($input['sp_id']) : 0;

if ($user_id <= 0) {
    // Fallback to JWT
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    
    if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        $jwt = $matches[1];
        
        try {
            $key_query = mysqli_query($conn, "SELECT value FROM index_setting WHERE name='key' LIMIT 1");
            $key_row = mysqli_fetch_assoc($key_query);
            $secret_key = $key_row['value'] ?? 'default_secret_key';
            
            $issuer_query = mysqli_query($conn, "SELECT value FROM index_setting WHERE name='issuer' LIMIT 1");
            $issuer_row = mysqli_fetch_assoc($issuer_query);
            $issuer = $issuer_row['value'] ?? 'default_issuer';
            
            $decoded = JWT::decode($jwt, new Key($secret_key, 'HS256'));
            
            if ($decoded->iss === $issuer) {
                $user_id = $decoded->data->user_id ?? 0;
            }
        } catch (Exception $e) {
            // JWT invalid
        }
    }
}

if ($user_id <= 0 || $sp_id <= 0) {
    echo json_encode([
        'success' => false,
        'message' => 'User ID and Product ID are required'
    ]);
    exit;
}

// Check if user is registered for affiliate
$check_aff = mysqli_query($conn, "SELECT dk_aff FROM user_info WHERE user_id = '$user_id' LIMIT 1");
$aff_info = mysqli_fetch_assoc($check_aff);

if (!$aff_info || $aff_info['dk_aff'] != 1) {
    echo json_encode([
        'success' => false,
        'message' => 'User is not registered for affiliate program'
    ]);
    exit;
}

// Get product info
$product_query = "SELECT id, link, shop FROM sanpham WHERE id = '$sp_id' LIMIT 1";
$product_result = mysqli_query($conn, $product_query);
$product = mysqli_fetch_assoc($product_result);

if (!$product) {
    echo json_encode([
        'success' => false,
        'message' => 'Product not found'
    ]);
    exit;
}

$client_full_link = isset($input['full_link']) ? trim($input['full_link']) : '';

// Build canonical product url
$product_link_canonical = "https://socdo.vn/product/" . $product['link'] . ".html";

// Prefer client-provided long URL (already contains utm_source_shop) if valid
if (!empty($client_full_link)) {
    $full_link = $client_full_link;
} else {
    // Fallback: append utm_source_shop to canonical url
    $sep = (strpos($product_link_canonical, '?') !== false) ? '&' : '?';
    $full_link = $product_link_canonical . $sep . 'utm_source_shop=' . $user_id;
}
$shop_id = $product['shop'];

// Check if link already exists
$check_link = "SELECT rut_gon FROM rut_gon_shop 
               WHERE sp_id = '$sp_id' AND user_id = '$user_id' 
               ORDER BY date_post DESC LIMIT 1";
$check_result = mysqli_query($conn, $check_link);
$existing_link = mysqli_fetch_assoc($check_result);

if ($existing_link && !empty($existing_link['rut_gon'])) {
    // Return existing link
    echo json_encode([
        'success' => true,
        'data' => [
            'short_link' => "https://socdo.xyz/x/" . $existing_link['rut_gon'],
            'full_link' => $full_link,
            'sp_id' => $sp_id
        ]
    ]);
    exit;
}

// Generate new short code
function generateRandomCode($conn) {
    $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    $max_attempts = 10;
    
    for ($i = 0; $i < $max_attempts; $i++) {
        $code = '';
        for ($j = 0; $j < 6; $j++) {
            $code .= $characters[rand(0, strlen($characters) - 1)];
        }
        
        // Check if code already exists
        $check = mysqli_query($conn, "SELECT id FROM rut_gon_shop WHERE rut_gon = '$code' LIMIT 1");
        if (mysqli_num_rows($check) == 0) {
            return $code;
        }
    }
    
    // If all attempts failed, use timestamp
    return substr(md5(time() . rand()), 0, 8);
}

$rut_gon = generateRandomCode($conn);
$hientai = time();

// Insert new link
$safe_full_link = mysqli_real_escape_string($conn, $full_link);
$insert_query = "INSERT INTO rut_gon_shop (sp_id, link, rut_gon, user_id, shop, click, date_post) 
                 VALUES ('$sp_id', '$safe_full_link', '$rut_gon', '$user_id', '$shop_id', '0', '$hientai')";

if (mysqli_query($conn, $insert_query)) {
    echo json_encode([
        'success' => true,
        'data' => [
            'short_link' => "https://socdo.xyz/x/" . $rut_gon,
            'full_link' => $full_link,
            'sp_id' => $sp_id
        ]
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to create short link: ' . mysqli_error($conn)
    ]);
}

