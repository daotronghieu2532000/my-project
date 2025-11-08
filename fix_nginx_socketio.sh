#!/bin/bash

# Script sửa Nginx config để hỗ trợ Socket.IO qua HTTPS
# Chạy trên server với quyền root

echo "=========================================="
echo "SỬA NGINX CONFIG CHO SOCKET.IO"
echo "=========================================="
echo ""

NGINX_HTTPS_CONFIG="/etc/nginx/config-https/chat.socdo.vn-https.conf"
NGINX_HTTP_CONFIG="/etc/nginx/conf.d/chat.socdo.vn.conf"
BACKUP_DIR="/root/nginx_backup_$(date +%Y%m%d_%H%M%S)"

# Tạo backup
echo "1. Tạo backup config..."
mkdir -p "$BACKUP_DIR"
cp "$NGINX_HTTPS_CONFIG" "$BACKUP_DIR/chat.socdo.vn-https.conf.backup"
cp "$NGINX_HTTP_CONFIG" "$BACKUP_DIR/chat.socdo.vn.conf.backup"
echo "✅ Backup đã lưu tại: $BACKUP_DIR"
echo ""

# Kiểm tra file tồn tại
if [ ! -f "$NGINX_HTTPS_CONFIG" ]; then
    echo "❌ Không tìm thấy file: $NGINX_HTTPS_CONFIG"
    exit 1
fi

echo "2. Kiểm tra config hiện tại..."
if grep -q "location.*socket\.io" "$NGINX_HTTPS_CONFIG"; then
    echo "⚠️  Đã có location cho socket.io trong HTTPS config"
    echo "   Bạn có muốn ghi đè? (y/n)"
    read -r answer
    if [ "$answer" != "y" ]; then
        echo "❌ Hủy bỏ"
        exit 0
    fi
fi
echo ""

# Tạo file config mới
echo "3. Tạo config mới cho Socket.IO..."

# Tìm dòng "location / {" trong HTTPS config
# Thêm location cho Socket.IO TRƯỚC location / {

TEMP_FILE=$(mktemp)

# Đọc file và thêm location cho Socket.IO
awk '
    /^[[:space:]]*location[[:space:]]+\/[[:space:]]*\{/ {
        # In location cho Socket.IO trước location /
        print "        # Socket.IO WebSocket proxy"
        print "        location /socket.io/ {"
        print "            proxy_pass http://127.0.0.1:3000;"
        print "            proxy_http_version 1.1;"
        print "            proxy_set_header Upgrade $http_upgrade;"
        print "            proxy_set_header Connection \"upgrade\";"
        print "            proxy_set_header Host $host;"
        print "            proxy_set_header X-Real-IP $remote_addr;"
        print "            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
        print "            proxy_set_header X-Forwarded-Proto $scheme;"
        print "            proxy_read_timeout 60s;"
        print "            proxy_send_timeout 60s;"
        print "            proxy_connect_timeout 60s;"
        print "        }"
        print ""
    }
    { print }
' "$NGINX_HTTPS_CONFIG" > "$TEMP_FILE"

# Kiểm tra xem đã thêm chưa
if ! grep -q "location /socket.io/" "$TEMP_FILE"; then
    echo "❌ Lỗi: Không thể thêm location cho Socket.IO"
    rm "$TEMP_FILE"
    exit 1
fi

# Backup và thay thế file
mv "$TEMP_FILE" "$NGINX_HTTPS_CONFIG"
echo "✅ Đã thêm location cho Socket.IO vào HTTPS config"
echo ""

# Test Nginx config
echo "4. Test Nginx config..."
if nginx -t; then
    echo "✅ Nginx config hợp lệ"
    echo ""
    echo "5. Reload Nginx..."
    if systemctl reload nginx; then
        echo "✅ Nginx đã được reload"
    else
        echo "❌ Lỗi khi reload Nginx"
        echo "   Khôi phục backup từ: $BACKUP_DIR"
        exit 1
    fi
else
    echo "❌ Nginx config không hợp lệ!"
    echo "   Khôi phục backup từ: $BACKUP_DIR"
    cp "$BACKUP_DIR/chat.socdo.vn-https.conf.backup" "$NGINX_HTTPS_CONFIG"
    exit 1
fi

echo ""
echo "=========================================="
echo "HOÀN TẤT!"
echo "=========================================="
echo ""
echo "✅ Đã thêm location cho Socket.IO vào HTTPS config"
echo "✅ Nginx đã được reload"
echo ""
echo "📝 Kiểm tra config:"
echo "   cat $NGINX_HTTPS_CONFIG | grep -A 15 'location /socket.io/'"
echo ""
echo "🧪 Test kết nối:"
echo "   curl -I https://chat.socdo.vn/socket.io/"
echo ""

