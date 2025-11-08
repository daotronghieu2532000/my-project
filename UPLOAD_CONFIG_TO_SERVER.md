# Hướng dẫn upload file config đã sửa lên server

## ✅ File đã được sửa:
- **File:** `chat.socdo.vn-https.conf`
- **Thay đổi:** Đã thêm location `/socket.io/` TRƯỚC `location / {`

---

## 📝 Cách 1: Upload file lên server (Nhanh nhất)

### Bước 1: Upload file lên server
```bash
# Từ máy local (Windows PowerShell hoặc Git Bash)
scp -P 2222 chat.socdo.vn-https.conf root@167.179.110.50:/root/chat.socdo.vn-https.conf.new
```

### Bước 2: SSH vào server
```bash
ssh -p 2222 root@167.179.110.50
```

### Bước 3: Backup file cũ
```bash
cp /etc/nginx/config-https/chat.socdo.vn-https.conf /root/chat.socdo.vn-https.conf.backup
```

### Bước 4: Copy file mới vào vị trí
```bash
cp /root/chat.socdo.vn-https.conf.new /etc/nginx/config-https/chat.socdo.vn-https.conf
```

### Bước 5: Test config
```bash
nginx -t
```

### Bước 6: Reload Nginx
```bash
systemctl reload nginx
```

### Bước 7: Test kết nối
```bash
curl -I https://chat.socdo.vn/socket.io/
```

---

## 📝 Cách 2: Copy-paste nội dung (Nếu không có scp)

### Bước 1: SSH vào server
```bash
ssh -p 2222 root@167.179.110.50
```

### Bước 2: Backup file cũ
```bash
cp /etc/nginx/config-https/chat.socdo.vn-https.conf /root/chat.socdo.vn-https.conf.backup
```

### Bước 3: Mở file để sửa
```bash
nano /etc/nginx/config-https/chat.socdo.vn-https.conf
```

### Bước 4: Copy nội dung từ file `chat.socdo.vn-https.conf` (đã sửa) và paste vào

### Bước 5: Lưu file
- `Ctrl + O` (lưu)
- `Enter` (xác nhận)
- `Ctrl + X` (thoát)

### Bước 6: Test config
```bash
nginx -t
```

### Bước 7: Reload Nginx
```bash
systemctl reload nginx
```

### Bước 8: Test kết nối
```bash
curl -I https://chat.socdo.vn/socket.io/
```

---

## 📋 Checklist:

- [ ] Backup file config cũ
- [ ] Upload/copy file config mới lên server
- [ ] Test Nginx config (`nginx -t`)
- [ ] Reload Nginx (`systemctl reload nginx`)
- [ ] Test kết nối (`curl -I https://chat.socdo.vn/socket.io/`)
- [ ] Test từ Flutter app

---

## ✅ Sau khi upload xong:

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
- **Phải backup** trước khi thay thế
- **Test config** trước khi reload Nginx
- **Flutter app KHÔNG CẦN SỬA** - đã đúng rồi

