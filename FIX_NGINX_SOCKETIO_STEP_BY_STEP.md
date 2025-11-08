# Hướng dẫn sửa Nginx config cho Socket.IO - Chi tiết từng bước

## ✅ Đã xác nhận:
- **File tồn tại:** `/etc/nginx/config-https/chat.socdo.vn-https.conf`
- **Vấn đề:** Thiếu location `/socket.io/`
- **Cần sửa:** Thêm location `/socket.io/` TRƯỚC `location / {`

---

## 📝 Cách 1: Sửa thủ công (An toàn nhất)

### Bước 1: Backup file
```bash
cp /etc/nginx/config-https/chat.socdo.vn-https.conf /root/chat.socdo.vn-https.conf.backup
```

### Bước 2: Mở file để sửa
```bash
nano /etc/nginx/config-https/chat.socdo.vn-https.conf
# Hoặc
vi /etc/nginx/config-https/chat.socdo.vn-https.conf
```

### Bước 3: Tìm dòng `location / {` (khoảng dòng 253)

### Bước 4: Thêm đoạn này TRƯỚC `location / {`:

```nginx
        # Socket.IO WebSocket proxy
        location /socket.io/ {
            proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 60s;
            proxy_send_timeout 60s;
            proxy_connect_timeout 60s;
        }
```

### Bước 5: Kết quả sẽ giống như sau:

```nginx
        # Custom configuration
        include /home/chat.socdo.vn/public_html/*.conf;

        # Socket.IO WebSocket proxy
        location /socket.io/ {
            proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 60s;
            proxy_send_timeout 60s;
            proxy_connect_timeout 60s;
        }

        location / {
                try_files $uri $uri/ /index.php?$args;
        }
```

### Bước 6: Lưu file
- **Nano:** `Ctrl + O` (lưu), `Enter` (xác nhận), `Ctrl + X` (thoát)
- **Vi:** `:wq` (lưu và thoát)

### Bước 7: Test config
```bash
nginx -t
```

### Bước 8: Reload Nginx
```bash
systemctl reload nginx
```

### Bước 9: Test kết nối
```bash
curl -I https://chat.socdo.vn/socket.io/
```

---

## 🚀 Cách 2: Dùng script tự động (Nhanh nhất)

### Bước 1: Upload script lên server
```bash
# Copy nội dung file fix_nginx_socketio_final.sh
# Tạo file trên server:
nano /root/fix_nginx_socketio_final.sh
# Paste nội dung script vào
```

### Bước 2: Chạy script
```bash
chmod +x /root/fix_nginx_socketio_final.sh
/root/fix_nginx_socketio_final.sh
```

---

## 📋 Checklist:

- [ ] Backup file config cũ
- [ ] Thêm location `/socket.io/` vào HTTPS config
- [ ] Test Nginx config (`nginx -t`)
- [ ] Reload Nginx (`systemctl reload nginx`)
- [ ] Test kết nối (`curl -I https://chat.socdo.vn/socket.io/`)
- [ ] Test từ Flutter app

---

## ✅ Sau khi sửa xong:

### 1. Kiểm tra config đã được thêm:
```bash
grep -A 15 "location /socket.io/" /etc/nginx/config-https/chat.socdo.vn-https.conf
```

### 2. Test kết nối từ server:
```bash
curl -I https://chat.socdo.vn/socket.io/
# Phải trả về 200 OK hoặc 400 Bad Request (không phải 404)
```

### 3. Test từ Flutter app:
- Mở app
- Vào màn hình chat
- Kiểm tra log xem có connect được không

---

## 🚨 Lưu ý:

- **File đường dẫn:** `/etc/nginx/config-https/chat.socdo.vn-https.conf`
- **Cần quyền root** để sửa
- **Phải backup** trước khi sửa
- **Test config** trước khi reload Nginx
- **Flutter app KHÔNG CẦN SỬA** - đã đúng rồi

