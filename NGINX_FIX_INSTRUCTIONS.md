# Hướng dẫn sửa Nginx config cho Socket.IO

## 🔍 Vấn đề hiện tại:
- **HTTPS config** (`/etc/nginx/config-https/chat.socdo.vn-https.conf`) **THIẾU** location cho Socket.IO
- App Flutter connect qua HTTPS nhưng Nginx không proxy đến Node.js
- HTTP config có proxy nhưng không dùng được vì app dùng HTTPS

## ✅ Giải pháp:
Thêm location cho Socket.IO vào **HTTPS config**

---

## 📝 Các bước thực hiện:

### 1. **Backup config hiện tại:**
```bash
cp /etc/nginx/config-https/chat.socdo.vn-https.conf /root/chat.socdo.vn-https.conf.backup
```

### 2. **Mở file HTTPS config:**
```bash
nano /etc/nginx/config-https/chat.socdo.vn-https.conf
```

### 3. **Tìm dòng `location / {`** (khoảng dòng 253-254)

### 4. **Thêm đoạn code này TRƯỚC `location / {`:**

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

### 5. **Kết quả sẽ giống như sau:**

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

### 6. **Test config:**
```bash
nginx -t
```

### 7. **Reload Nginx:**
```bash
systemctl reload nginx
```

### 8. **Test kết nối:**
```bash
curl -I https://chat.socdo.vn/socket.io/
```

---

## 🚀 Hoặc dùng script tự động:

```bash
# Upload file fix_nginx_socketio.sh lên server
chmod +x fix_nginx_socketio.sh
./fix_nginx_socketio.sh
```

---

## ✅ Sau khi sửa xong:

1. **Flutter app KHÔNG CẦN SỬA** - đã đúng rồi
2. **Test từ Flutter app:**
   - Mở app
   - Vào màn hình chat
   - Kiểm tra log xem có connect được không

---

## 📋 Checklist:

- [ ] Backup config cũ
- [ ] Thêm location `/socket.io/` vào HTTPS config
- [ ] Test Nginx config (`nginx -t`)
- [ ] Reload Nginx (`systemctl reload nginx`)
- [ ] Test từ server (`curl -I https://chat.socdo.vn/socket.io/`)
- [ ] Test từ Flutter app

