# Quick Start: Deploy Redis Queue lên Server

## 📍 Thông Tin Quan Trọng

- **Server Path**: `/home/api.socdo.vn/public_html/home/themes/socdo/action/process/`
- **SSH**: `ssh -p 2222 root@167.179.110.50`

---

## 🚀 Các Bước Thực Hiện

### Bước 1: Upload Files lên Server

**Files cần upload** (từ thư mục `API_WEB/`):
- `redis_queue_service.php`
- `notification_worker_redis.php`
- `notification_queue_producer.php`
- `notification_mobile_helper.php` (đã update)
- `composer.json` (đã update)

**Cách upload** (chọn 1 trong 2):

#### Option A: SCP (từ PowerShell/Git Bash)
```bash
cd C:\laragon\www\socdo_mobile\API_WEB

scp -P 2222 redis_queue_service.php root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
scp -P 2222 notification_worker_redis.php root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
scp -P 2222 notification_queue_producer.php root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
scp -P 2222 notification_mobile_helper.php root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
scp -P 2222 composer.json root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
```

#### Option B: FTP/SFTP (FileZilla, WinSCP)
- Host: `167.179.110.50`
- Port: `2222`
- Protocol: SFTP
- Username: `root`
- Remote Directory: `/home/api.socdo.vn/public_html/home/themes/socdo/action/process/`

---

### Bước 2: Kết Nối SSH và Cài Đặt

#### 1. Kết nối SSH
```bash
ssh -p 2222 root@167.179.110.50
```

#### 2. Di chuyển đến thư mục API
```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process
```

#### 3. Kiểm tra files đã upload
```bash
ls -la | grep -E "redis|notification_queue|composer.json"
```

#### 4. Install Redis Server
```bash
# Kiểm tra Redis đã cài chưa
redis-cli ping

# Nếu chưa có (kết quả: command not found), cài đặt:
yum install redis -y
# Hoặc nếu là Ubuntu/Debian:
# apt-get install redis-server -y

# Start Redis
systemctl start redis
systemctl enable redis

# Verify
redis-cli ping
# Kết quả mong đợi: PONG
```

#### 5. Install PHP Redis Extension
```bash
# Kiểm tra PHP version
php -v

# Install PHP Redis extension
yum install php-redis -y
# Hoặc
# apt-get install php-redis -y

# Verify
php -m | grep redis
# Kết quả mong đợi: redis
```

#### 6. Install Predis (PHP Client - Fallback)
```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process

# Kiểm tra composer
composer --version

# Nếu chưa có composer, cài đặt:
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Install dependencies
composer install
# Hoặc chỉ install predis:
# composer require predis/predis
```

---

### Bước 3: Test Setup

#### 1. Test Redis Connection
```bash
# Test từ command line
redis-cli ping
# Kết quả: PONG

# Test từ PHP
php -r "try { \$r = new Redis(); \$r->connect('127.0.0.1', 6379); echo 'Redis OK: ' . \$r->ping() . PHP_EOL; } catch (Exception \$e) { echo 'Redis Error: ' . \$e->getMessage() . PHP_EOL; }"
# Kết quả mong đợi: Redis OK: +PONG
```

#### 2. Test PHP Files Syntax
```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process

php -l redis_queue_service.php
php -l notification_worker_redis.php
php -l notification_queue_producer.php

# Tất cả phải trả về: No syntax errors detected
```

---

### Bước 4: Start Worker

#### Test Single Run (Khuyến nghị đầu tiên)
```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process
php notification_worker_redis.php
```

Kiểm tra log:
```bash
tail -f debug_push_notifications.log
```

#### Daemon Mode (Chạy liên tục)
```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process

# Dùng nohup để chạy background
nohup php notification_worker_redis.php --daemon > /dev/null 2>&1 &

# Hoặc dùng screen (khuyến nghị)
screen -S notification-worker
php notification_worker_redis.php --daemon
# Nhấn Ctrl+A, sau đó D để detach (giữ process chạy khi đóng SSH)
```

#### Systemd Service (Production - Khuyến nghị)

Tạo file service:
```bash
nano /etc/systemd/system/notification-worker.service
```

Nội dung:
```ini
[Unit]
Description=Notification Worker (Redis Queue)
After=network.target redis.service

[Service]
Type=simple
User=root
WorkingDirectory=/home/api.socdo.vn/public_html/home/themes/socdo/action/process
ExecStart=/usr/bin/php /home/api.socdo.vn/public_html/home/themes/socdo/action/process/notification_worker_redis.php --daemon
Restart=always
RestartSec=10
StandardOutput=append:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/worker.log
StandardError=append:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/worker_error.log

[Install]
WantedBy=multi-user.target
```

Enable và start:
```bash
systemctl daemon-reload
systemctl enable notification-worker
systemctl start notification-worker
systemctl status notification-worker
```

---

### Bước 5: Enable Redis Queue

Edit `notification_mobile_helper.php`:
```bash
nano /home/api.socdo.vn/public_html/home/themes/socdo/action/process/notification_mobile_helper.php
```

Tìm dòng (khoảng line 12):
```php
private $useRedisQueue = false;
```

Đổi thành:
```php
private $useRedisQueue = true;
```

Lưu và thoát (Ctrl+X, Y, Enter)

---

### Bước 6: Verify và Monitor

#### Check Worker đang chạy
```bash
# Check process
ps aux | grep notification_worker

# Check systemd service
systemctl status notification-worker

# Check logs
tail -f /home/api.socdo.vn/public_html/home/themes/socdo/action/process/debug_push_notifications.log | grep REDIS
```

#### Check Redis Queue
```bash
redis-cli

# Check queue sizes
> LLEN notifications:queue
> LLEN notifications:priority
> ZCARD notifications:delayed
> LLEN notifications:failed

# Exit
> exit
```

---

## 📋 Checklist

- [ ] Upload 5 files lên server
- [ ] Install Redis server
- [ ] Install PHP Redis extension
- [ ] Install Predis (composer install)
- [ ] Test Redis connection
- [ ] Test PHP syntax
- [ ] Start worker (test mode)
- [ ] Verify worker đang chạy
- [ ] Enable Redis queue trong code
- [ ] Setup systemd service (optional)
- [ ] Monitor logs

---

## 🐛 Troubleshooting

### Redis không kết nối
```bash
systemctl status redis
redis-cli ping
```

### Worker không chạy
```bash
php -l notification_worker_redis.php
tail -50 debug_push_notifications.log
```

### Composer không tìm thấy
```bash
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
```

---

## 📞 Commands Quick Reference

```bash
# SSH vào server
ssh -p 2222 root@167.179.110.50

# Di chuyển đến thư mục API
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process

# Start worker (test)
php notification_worker_redis.php

# Start worker (daemon với nohup)
nohup php notification_worker_redis.php --daemon > /dev/null 2>&1 &

# Check worker process
ps aux | grep notification_worker

# Check logs
tail -f debug_push_notifications.log

# Check Redis
redis-cli ping
redis-cli LLEN notifications:queue
```

---

**Lưu ý**: 
- ✅ Files upload lên: `/home/api.socdo.vn/public_html/home/themes/socdo/action/process/`
- ✅ Commands chạy trên server qua SSH
- ✅ Worker chạy như daemon hoặc systemd service

