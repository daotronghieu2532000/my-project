#!/bin/bash

# Script nhanh để thêm Socket.IO location vào Nginx HTTPS config

CONFIG_FILE="/etc/nginx/config-https/chat.socdo.vn-https.conf"
BACKUP_FILE="/root/chat.socdo.vn-https.conf.backup.$(date +%Y%m%d_%H%M%S)"

# Backup
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ Backup đã lưu: $BACKUP_FILE"

# Kiểm tra đã có chưa
if grep -q "location /socket.io/" "$CONFIG_FILE"; then
    echo "⚠️  Đã có location /socket.io/ rồi!"
    exit 0
fi

# Tìm dòng "location / {" và thêm location cho Socket.IO trước đó
sed -i '/^[[:space:]]*location[[:space:]]+\/[[:space:]]*{/i\
        # Socket.IO WebSocket proxy\
        location /socket.io/ {\
            proxy_pass http://127.0.0.1:3000;\
            proxy_http_version 1.1;\
            proxy_set_header Upgrade $http_upgrade;\
            proxy_set_header Connection "upgrade";\
            proxy_set_header Host $host;\
            proxy_set_header X-Real-IP $remote_addr;\
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
            proxy_set_header X-Forwarded-Proto $scheme;\
            proxy_read_timeout 60s;\
            proxy_send_timeout 60s;\
            proxy_connect_timeout 60s;\
        }\
' "$CONFIG_FILE"

# Test và reload
if nginx -t; then
    systemctl reload nginx
    echo "✅ Đã thêm location /socket.io/ và reload Nginx"
    echo ""
    echo "🧪 Test: curl -I https://chat.socdo.vn/socket.io/"
else
    echo "❌ Config không hợp lệ! Khôi phục backup..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

