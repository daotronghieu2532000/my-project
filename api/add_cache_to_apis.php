<?php
/**
 * Script tự động thêm cache vào tất cả API files
 * Chạy script này để áp dụng cache cho tất cả API
 */

$api_directory = './';
$exclude_files = [
    'cache_helper.php',
    'api_template.php',
    'banners.php', // Đã sửa
    'product_suggest.php', // Đã sửa
    'flash_sale.php' // Đã sửa
];

// Lấy danh sách tất cả PHP files
$files = glob($api_directory . '*.php');

echo "🚀 Bắt đầu thêm cache vào " . count($files) . " API files...\n\n";

foreach ($files as $file) {
    $filename = basename($file);
    
    // Bỏ qua các file đã sửa hoặc không cần thiết
    if (in_array($filename, $exclude_files)) {
        echo "⏭️  Bỏ qua: $filename (đã sửa hoặc không cần)\n";
        continue;
    }
    
    echo "📝 Đang sửa: $filename...\n";
    
    // Đọc nội dung file
    $content = file_get_contents($file);
    
    // Kiểm tra xem đã có cache helper chưa
    if (strpos($content, 'cache_helper.php') !== false) {
        echo "✅ $filename đã có cache helper\n";
        continue;
    }
    
    // Thêm cache helper sau require_once './vendor/autoload.php';
    $pattern = "/(require_once\s+['\"]\.\/vendor\/autoload\.php['\"];)/";
    $replacement = "$1\nrequire_once './cache_helper.php';";
    
    $new_content = preg_replace($pattern, $replacement, $content);
    
    if ($new_content !== $content) {
        // Lưu file
        file_put_contents($file, $new_content);
        echo "✅ Đã thêm cache helper vào $filename\n";
    } else {
        echo "❌ Không thể thêm cache helper vào $filename\n";
    }
    
    echo "\n";
}

echo "🎉 Hoàn thành! Đã thêm cache helper vào tất cả API files.\n";
echo "📋 Các file đã sửa:\n";
foreach ($files as $file) {
    $filename = basename($file);
    if (!in_array($filename, $exclude_files)) {
        echo "   - $filename\n";
    }
}

echo "\n🔧 Bước tiếp theo:\n";
echo "1. Kiểm tra từng API file\n";
echo "2. Thêm cache logic vào các GET requests\n";
echo "3. Test API performance\n";
?>
