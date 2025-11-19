# Hướng Dẫn Deploy Redis Queue lên Server

## 📍 Thông Tin Server

- **SSH**: `ssh -p 2222 root@167.179.110.50`
- **API Directory**: `/home/api.socdo.vn/public_html/home/themes/socdo/action/process/`
- **Config File**: `/home/api.socdo.vn/public_html/includes/config.php`
- **Vendor**: `/home/api.socdo.vn/public_html/vendor/autoload.php`

---

## 📤 Bước 1: Upload Files lên Server

### Files cần upload:

1. `redis_queue_service.php`
2. `notification_worker_redis.php`
3. `notification_queue_producer.php`
4. `notification_mobile_helper.php` (đã update)
5. `composer.json` (đã update)

### Cách upload:

#### Option 1: SCP (từ Windows PowerShell hoặc Git Bash)

```bash
# Từ thư mục API_WEB trên máy local
scp -P 2222 redis_queue_service.php root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
scp -P 2222 notification_worker_redis.php root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
scp -P 2222 notification_queue_producer.php root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
scp -P 2222 notification_mobile_helper.php root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
scp -P 2222 composer.json root@167.179.110.50:/home/api.socdo.vn/public_html/home/themes/socdo/action/process/
```

#### Option 2: FTP/SFTP Client (FileZilla, WinSCP)

- **Host**: `167.179.110.50`
- **Port**: `2222`
- **Protocol**: SFTP
- **Username**: `root`
- **Remote Directory**: `/home/api.socdo.vn/public_html/home/themes/socdo/action/process/`

Upload các file vào thư mục này.

---

## 🔧 Bước 2: Kết Nối SSH và Cài Đặt

### 1. Kết nối SSH

```bash
ssh -p 2222 root@167.179.110.50
```

### 2. Di chuyển đến thư mục API

```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process
```

### 3. Kiểm tra files đã upload

```bash
ls -la | grep -E "redis|notification_queue|composer.json"
```

Kết quả mong đợi:
```
-rw-r--r-- 1 root root  ... redis_queue_service.php
-rw-r--r-- 1 root root  ... notification_worker_redis.php
-rw-r--r-- 1 root root  ... notification_queue_producer.php
-rw-r--r-- 1 root root  ... composer.json
```

---

## 📦 Bước 3: Install Redis và PHP Extension

### 1. Install Redis Server

```bash
# Kiểm tra Redis đã cài chưa
redis-cli ping

# Nếu chưa có, cài đặt:
yum install redis -y
# Hoặc
apt-get install redis-server -y

# Start Redis
systemctl start redis
systemctl enable redis

# Verify
redis-cli ping
# Kết quả: PONG
```

### 2. Install PHP Redis Extension

```bash
# Kiểm tra PHP version
php -v

# Install PHP Redis extension
yum install php-redis -y
# Hoặc
apt-get install php-redis -y

# Verify
php -m | grep redis
# Kết quả: redis
```

### 3. Install Predis (PHP Client)

```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process

# Kiểm tra composer đã có chưa
composer --version

# Nếu chưa có, cài đặt:
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Install dependencies
composer install

# Hoặc chỉ install predis:
composer require predis/predis
```

---

## ✅ Bước 4: Verify Setup

### 1. Test Redis Connection

```bash
# Test từ command line
redis-cli ping
# Kết quả: PONG

# Test từ PHP
php -r "try { \$r = new Redis(); \$r->connect('127.0.0.1', 6379); echo 'Redis OK: ' . \$r->ping() . PHP_EOL; } catch (Exception \$e) { echo 'Redis Error: ' . \$e->getMessage() . PHP_EOL; }"
# Kết quả: Redis OK: +PONG
```

### 2. Test PHP Files

```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process

# Test syntax
php -l redis_queue_service.php
php -l notification_worker_redis.php
php -l notification_queue_producer.php

# Tất cả phải trả về: No syntax errors detected
```

---

## 🚀 Bước 5: Start Worker

### Option 1: Test Single Run (Khuyến nghị đầu tiên)

```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process
php notification_worker_redis.php
```

Kiểm tra log:
```bash
tail -f debug_push_notifications.log
```

### Option 2: Daemon Mode (Chạy liên tục)

```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process

# Chạy daemon (sẽ chạy liên tục)
php notification_worker_redis.php --daemon
```

**Lưu ý**: Nếu đóng SSH, process sẽ dừng. Cần dùng `nohup` hoặc `screen`:

```bash
# Dùng nohup
nohup php notification_worker_redis.php --daemon > /dev/null 2>&1 &

# Hoặc dùng screen
screen -S notification-worker
php notification_worker_redis.php --daemon
# Nhấn Ctrl+A, sau đó D để detach
```

### Option 3: Systemd Service (Khuyến nghị cho production)

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

## 🔍 Bước 6: Monitor và Verify

### 1. Check Worker đang chạy

```bash
# Check process
ps aux | grep notification_worker

# Check systemd service
systemctl status notification-worker

# Check logs
tail -f /home/api.socdo.vn/public_html/home/themes/socdo/action/process/debug_push_notifications.log | grep REDIS
```

### 2. Check Redis Queue

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

### 3. Test Push Notification

Tạo test notification trong database:

```sql
INSERT INTO notification_mobile (user_id, type, title, content, push_sent, created_at)
VALUES (1, 'test', 'Test Notification', 'This is a test', 0, UNIX_TIMESTAMP());
```

Sau đó push vào queue:

```bash
cd /home/api.socdo.vn/public_html/home/themes/socdo/action/process
php -r "
require_once 'notification_queue_producer.php';
require_once '/home/api.socdo.vn/public_html/includes/config.php';
\$producer = new NotificationQueueProducer(\$conn);
\$producer->pushNotification(LAST_INSERT_ID);
echo 'Notification pushed to queue\n';
"
```

---

## ⚙️ Bước 7: Enable Redis Queue trong Code

### Option 1: Enable Globally

Edit `notification_mobile_helper.php`:

```bash
nano /home/api.socdo.vn/public_html/home/themes/socdo/action/process/notification_mobile_helper.php
```

Tìm dòng:
```php
private $useRedisQueue = false;
```

Đổi thành:
```php
private $useRedisQueue = true;
```

### Option 2: Enable Per Instance (Khuyến nghị)

Giữ `useRedisQueue = false` mặc định, và enable khi cần:

```php
$helper = new NotificationMobileHelper($conn, true); // true = use Redis
```

---

## 📋 Checklist Deploy

- [ ] Upload các file lên server
- [ ] Install Redis server
- [ ] Install PHP Redis extension
- [ ] Install Predis (composer install)
- [ ] Test Redis connection
- [ ] Test PHP syntax
- [ ] Start worker (test mode)
- [ ] Verify worker đang chạy
- [ ] Check logs
- [ ] Enable Redis queue trong code
- [ ] Setup systemd service (optional)
- [ ] Monitor queue stats

---

## 🐛 Troubleshooting

### Redis không kết nối được

```bash
# Check Redis service
systemctl status redis

# Check Redis port
netstat -tuln | grep 6379

# Test connection
redis-cli -h 127.0.0.1 -p 6379 ping
```

### Worker không chạy

```bash
# Check PHP errors
php -l notification_worker_redis.php

# Check config path
ls -la /home/api.socdo.vn/public_html/includes/config.php

# Check logs
tail -50 debug_push_notifications.log
```

### Composer không tìm thấy

```bash
# Install composer globally
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Verify
composer --version
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

# Start worker (daemon)
nohup php notification_worker_redis.php --daemon > /dev/null 2>&1 &

# Check worker process
ps aux | grep notification_worker

# Check logs
tail -f debug_push_notifications.log

# Check Redis
redis-cli ping

# Check queue stats
redis-cli LLEN notifications:queue
```

---

**Lưu ý**: 
- Tất cả commands chạy trên server qua SSH
- Files upload lên `/home/api.socdo.vn/public_html/home/themes/socdo/action/process/`
- Worker chạy như daemon hoặc systemd service

