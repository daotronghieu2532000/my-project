#!/bin/bash

# Script sửa Nginx config để thêm location /socket.io/
# File: /etc/nginx/config-https/chat.socdo.vn-https.conf

CONFIG_FILE="/etc/nginx/config-https/chat.socdo.vn-https.conf"
BACKUP_FILE="/root/chat.socdo.vn-https.conf.backup.$(date +%Y%m%d_%H%M%S)"

echo "=========================================="
echo "SỬA NGINX CONFIG CHO SOCKET.IO"
echo "=========================================="
echo ""

# Kiểm tra file tồn tại
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ File không tồn tại: $CONFIG_FILE"
    exit 1
fi

echo "✅ File tồn tại: $CONFIG_FILE"
echo ""

# Backup file
echo "1. Tạo backup..."
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ Backup đã lưu: $BACKUP_FILE"
echo ""

# Kiểm tra đã có location /socket.io/ chưa
if grep -q "location /socket.io/" "$CONFIG_FILE"; then
    echo "⚠️  Đã có location /socket.io/ rồi!"
    echo "   Bạn có muốn ghi đè? (y/n)"
    read -r answer
    if [ "$answer" != "y" ]; then
        echo "❌ Hủy bỏ"
        exit 0
    fi
fi

# Tạo file tạm với location /socket.io/
TEMP_FILE=$(mktemp)

# Đọc file và thêm location /socket.io/ TRƯỚC location / {
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
' "$CONFIG_FILE" > "$TEMP_FILE"

# Kiểm tra xem đã thêm chưa
if ! grep -q "location /socket.io/" "$TEMP_FILE"; then
    echo "❌ Lỗi: Không thể thêm location cho Socket.IO"
    rm "$TEMP_FILE"
    exit 1
fi

# Thay thế file
mv "$TEMP_FILE" "$CONFIG_FILE"
echo "✅ Đã thêm location /socket.io/ vào config"
echo ""

# Test Nginx config
echo "2. Test Nginx config..."
if nginx -t; then
    echo "✅ Nginx config hợp lệ"
    echo ""
    echo "3. Reload Nginx..."
    if systemctl reload nginx; then
        echo "✅ Nginx đã được reload"
    else
        echo "❌ Lỗi khi reload Nginx"
        echo "   Khôi phục backup từ: $BACKUP_FILE"
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        exit 1
    fi
else
    echo "❌ Nginx config không hợp lệ!"
    echo "   Khôi phục backup từ: $BACKUP_FILE"
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

echo ""
echo "=========================================="
echo "HOÀN TẤT!"
echo "=========================================="
echo ""
echo "✅ Đã thêm location /socket.io/ vào HTTPS config"
echo "✅ Nginx đã được reload"
echo ""
echo "📝 Kiểm tra config:"
echo "   grep -A 15 'location /socket.io/' $CONFIG_FILE"
echo ""
echo "🧪 Test kết nối:"
echo "   curl -I https://chat.socdo.vn/socket.io/"
echo ""

