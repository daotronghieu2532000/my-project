#!/bin/bash

echo "=========================================="
echo "TÌM FILE NGINX CONFIG CHO CHAT.SOCDO.VN"
echo "=========================================="
echo ""

echo "1. Kiểm tra file HTTPS config:"
echo "----------------------------------------"
if [ -f "/etc/nginx/config-https/chat.socdo.vn-https.conf" ]; then
    echo "✅ File tồn tại: /etc/nginx/config-https/chat.socdo.vn-https.conf"
    echo ""
    echo "📝 Nội dung file (50 dòng đầu):"
    head -n 50 /etc/nginx/config-https/chat.socdo.vn-https.conf
else
    echo "❌ File KHÔNG tồn tại: /etc/nginx/config-https/chat.socdo.vn-https.conf"
fi
echo ""

echo "2. Kiểm tra file HTTP config:"
echo "----------------------------------------"
if [ -f "/etc/nginx/conf.d/chat.socdo.vn.conf" ]; then
    echo "✅ File tồn tại: /etc/nginx/conf.d/chat.socdo.vn.conf"
    echo ""
    echo "📝 Nội dung file (50 dòng đầu):"
    head -n 50 /etc/nginx/conf.d/chat.socdo.vn.conf
else
    echo "❌ File KHÔNG tồn tại: /etc/nginx/conf.d/chat.socdo.vn.conf"
fi
echo ""

echo "3. Tìm tất cả file config liên quan đến chat.socdo.vn:"
echo "----------------------------------------"
find /etc/nginx -name "*chat.socdo.vn*" -type f 2>/dev/null
echo ""

echo "4. Kiểm tra thư mục config-https:"
echo "----------------------------------------"
if [ -d "/etc/nginx/config-https" ]; then
    echo "✅ Thư mục tồn tại: /etc/nginx/config-https"
    echo "📁 Danh sách file trong thư mục:"
    ls -la /etc/nginx/config-https/ | head -20
else
    echo "❌ Thư mục KHÔNG tồn tại: /etc/nginx/config-https"
fi
echo ""

echo "5. Kiểm tra thư mục conf.d:"
echo "----------------------------------------"
if [ -d "/etc/nginx/conf.d" ]; then
    echo "✅ Thư mục tồn tại: /etc/nginx/conf.d"
    echo "📁 Danh sách file trong thư mục:"
    ls -la /etc/nginx/conf.d/ | grep -i chat | head -10
else
    echo "❌ Thư mục KHÔNG tồn tại: /etc/nginx/conf.d"
fi
echo ""

echo "6. Kiểm tra Nginx config chính:"
echo "----------------------------------------"
if [ -f "/etc/nginx/nginx.conf" ]; then
    echo "✅ File nginx.conf tồn tại"
    echo "📝 Kiểm tra include config-https:"
    grep -i "config-https\|conf.d" /etc/nginx/nginx.conf | head -10
else
    echo "❌ File nginx.conf KHÔNG tồn tại"
fi
echo ""

echo "=========================================="
echo "HOÀN TẤT KIỂM TRA"
echo "=========================================="

