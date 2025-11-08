#!/bin/bash

echo "=========================================="
echo "KIỂM TRA TRẠNG THÁI SERVER SOCKET.IO"
echo "=========================================="
echo ""

echo "1. KIỂM TRA PM2 PROCESSES:"
echo "----------------------------------------"
pm2 list
echo ""

echo "2. KIỂM TRA PORT 3000:"
echo "----------------------------------------"
lsof -i :3000 | head -20
echo ""

echo "3. KIỂM TRA TẤT CẢ NODE PROCESSES:"
echo "----------------------------------------"
ps aux | grep node | grep -v grep
echo ""

echo "4. KIỂM TRA TẤT CẢ PORT ĐANG LISTEN:"
echo "----------------------------------------"
netstat -tulpn | grep LISTEN | grep -E "(3000|3001|3002|3003|4000|5000|8000)" | head -20
echo ""

echo "5. KIỂM TRA NGINX CONFIG - HTTP:"
echo "----------------------------------------"
echo "File: /etc/nginx/conf.d/chat.socdo.vn.conf"
grep -A 5 "proxy_pass\|location.*socket" /etc/nginx/conf.d/chat.socdo.vn.conf | head -30
echo ""

echo "6. KIỂM TRA NGINX CONFIG - HTTPS:"
echo "----------------------------------------"
if [ -f "/etc/nginx/config-https/chat.socdo.vn-https.conf" ]; then
    echo "File: /etc/nginx/config-https/chat.socdo.vn-https.conf"
    grep -A 5 "proxy_pass\|location.*socket" /etc/nginx/config-https/chat.socdo.vn-https.conf | head -30
else
    echo "File HTTPS config không tồn tại!"
fi
echo ""

echo "7. KIỂM TRA NGINX ERROR LOGS (30 dòng cuối):"
echo "----------------------------------------"
tail -n 30 /home/chat.socdo.vn/logs/error.log 2>/dev/null || echo "Không tìm thấy error log"
echo ""

echo "8. KIỂM TRA NGINX ACCESS LOGS (10 dòng cuối):"
echo "----------------------------------------"
tail -n 10 /home/chat.socdo.vn/logs/access.log 2>/dev/null || echo "Không tìm thấy access log"
echo ""

echo "9. KIỂM TRA THỂ MỤC CHAT.SOCDO.VN:"
echo "----------------------------------------"
ls -la /home/chat.socdo.vn/public_html/ | head -20
echo ""

echo "10. KIỂM TRA FILE INDEX.JS (nếu có):"
echo "----------------------------------------"
if [ -f "/home/chat.socdo.vn/public_html/index.js" ]; then
    echo "File tồn tại. Kiểm tra port trong file:"
    grep -i "port\|listen\|3000" /home/chat.socdo.vn/public_html/index.js | head -10
else
    echo "File index.js không tồn tại tại /home/chat.socdo.vn/public_html/"
fi
echo ""

echo "11. TEST KẾT NỐI HTTP:"
echo "----------------------------------------"
curl -I http://chat.socdo.vn 2>&1 | head -10
echo ""

echo "12. TEST KẾT NỐI HTTPS:"
echo "----------------------------------------"
curl -I https://chat.socdo.vn 2>&1 | head -10
echo ""

echo "13. TEST SOCKET.IO ENDPOINT:"
echo "----------------------------------------"
curl -I https://chat.socdo.vn/socket.io/ 2>&1 | head -10
echo ""

echo "14. KIỂM TRA NGINX STATUS:"
echo "----------------------------------------"
systemctl status nginx --no-pager | head -20
echo ""

echo "15. KIỂM TRA FIREWALL (nếu có):"
echo "----------------------------------------"
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --list-ports 2>/dev/null | head -10
elif command -v iptables &> /dev/null; then
    iptables -L -n | grep -E "(3000|443|80)" | head -10
else
    echo "Không tìm thấy firewall command"
fi
echo ""

echo "=========================================="
echo "HOÀN TẤT KIỂM TRA"
echo "=========================================="

