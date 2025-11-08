#!/bin/bash

echo "=========================================="
echo "KIỂM TRA CUSTOM CONFIG FILES"
echo "=========================================="
echo ""

echo "1. Kiểm tra file .conf trong public_html:"
echo "----------------------------------------"
ls -la /home/chat.socdo.vn/public_html/*.conf 2>/dev/null || echo "Không có file .conf"
echo ""

echo "2. Nội dung các file .conf (nếu có):"
echo "----------------------------------------"
for file in /home/chat.socdo.vn/public_html/*.conf; do
    if [ -f "$file" ]; then
        echo "File: $file"
        cat "$file"
        echo ""
    fi
done

echo "3. Kiểm tra xem location / có đang proxy không:"
echo "----------------------------------------"
nginx -T 2>/dev/null | grep -A 20 "server_name chat.socdo.vn" | grep -A 10 "location /" | head -20

