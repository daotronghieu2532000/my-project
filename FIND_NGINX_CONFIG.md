# Hướng dẫn tìm file Nginx config trên server

## 🔍 Giải thích:

### File `/etc/nginx/config-https/chat.socdo.vn-https.conf`:
- **KHÔNG nằm** trong `/home/chat.socdo.vn/`
- **Nằm** trong thư mục system của Nginx: `/etc/nginx/config-https/`
- Đây là file cấu hình Nginx, không phải file website

### Cấu trúc thư mục trên server:

```
/etc/nginx/                    ← Thư mục cấu hình Nginx (system)
├── nginx.conf                 ← File config chính
├── config-https/              ← Thư mục config HTTPS
│   └── chat.socdo.vn-https.conf  ← File config HTTPS cho chat.socdo.vn
└── conf.d/                    ← Thư mục config HTTP
    └── chat.socdo.vn.conf     ← File config HTTP cho chat.socdo.vn

/home/chat.socdo.vn/           ← Thư mục website (web files)
├── public_html/               ← Thư mục website
│   ├── index.js               ← Node.js server
│   └── ...
└── logs/                      ← Log files
```

---

## 📝 Cách kiểm tra và tìm file:

### 1. **Kiểm tra file có tồn tại không:**

```bash
# SSH vào server
ssh -p 2222 root@167.179.110.50

# Kiểm tra file HTTPS config
ls -la /etc/nginx/config-https/chat.socdo.vn-https.conf

# Kiểm tra file HTTP config
ls -la /etc/nginx/conf.d/chat.socdo.vn.conf
```

### 2. **Tìm tất cả file config liên quan:**

```bash
find /etc/nginx -name "*chat.socdo.vn*" -type f
```

### 3. **Xem nội dung file:**

```bash
# Xem file HTTPS config
cat /etc/nginx/config-https/chat.socdo.vn-https.conf

# Xem file HTTP config
cat /etc/nginx/conf.d/chat.socdo.vn.conf
```

### 4. **Kiểm tra thư mục config-https:**

```bash
# Xem danh sách file trong thư mục
ls -la /etc/nginx/config-https/

# Kiểm tra thư mục có tồn tại không
test -d /etc/nginx/config-https && echo "Tồn tại" || echo "Không tồn tại"
```

---

## 🚀 Hoặc chạy script tự động:

```bash
# Upload file find_nginx_config.sh lên server
chmod +x find_nginx_config.sh
./find_nginx_config.sh
```

---

## ✅ Sau khi tìm thấy file:

1. **Backup file:**
```bash
cp /etc/nginx/config-https/chat.socdo.vn-https.conf /root/chat.socdo.vn-https.conf.backup
```

2. **Mở file để sửa:**
```bash
nano /etc/nginx/config-https/chat.socdo.vn-https.conf
# Hoặc
vi /etc/nginx/config-https/chat.socdo.vn-https.conf
```

3. **Thêm location `/socket.io/` vào file**

4. **Test và reload:**
```bash
nginx -t
systemctl reload nginx
```

---

## 📋 Lưu ý:

- File này **KHÔNG có** trong folder `chat.socdo.vn` mà bạn tải về
- File này nằm trong thư mục system của Nginx
- Cần quyền **root** để sửa file này
- Phải SSH vào server để sửa

