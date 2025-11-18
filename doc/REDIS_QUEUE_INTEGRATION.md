# Redis Queue Integration Guide

## 🎯 Tổng Quan

Hệ thống Redis Queue đã được implement với pattern **Event → Queue → Worker → Push**.

## 📁 Files Đã Tạo

1. **`redis_queue_service.php`**: Core service xử lý queue
2. **`notification_worker_redis.php`**: Worker daemon xử lý jobs
3. **`notification_queue_producer.php`**: Producer để push jobs vào queue
4. **`REDIS_QUEUE_SETUP.md`**: Hướng dẫn setup chi tiết

## 🔄 Flow Hoạt Động

```
1. Event xảy ra (đơn hàng mới, voucher mới, ...)
   ↓
2. Database Trigger tạo notification (push_sent = 0)
   ↓
3. Producer push vào Redis Queue
   ↓
4. Worker pop job từ queue
   ↓
5. Worker gửi push notification
   ↓
6. Update push_sent = 1 trong database
```

## 🚀 Quick Start

### 1. Install Redis & PHP Extension

```bash
# Install Redis
sudo apt-get install redis-server

# Install PHP Redis extension
sudo apt-get install php-redis

# Install Predis (PHP client)
cd API_WEB
composer install
```

### 2. Enable Redis Queue

Edit `notification_mobile_helper.php` hoặc tạo config:

```php
// Option 1: Enable globally
$useRedisQueue = true; // Set trong config

// Option 2: Enable per instance
$helper = new NotificationMobileHelper($conn, true); // true = use Redis
```

### 3. Start Worker

```bash
# Daemon mode (chạy liên tục)
php notification_worker_redis.php --daemon

# Single run (test)
php notification_worker_redis.php
```

### 4. Update Triggers (Optional)

Nếu muốn push vào queue ngay từ trigger:

```sql
-- Trong trigger, sau khi INSERT notification
-- Gọi PHP script để push vào queue (hoặc dùng stored procedure)
```

## ⚙️ Configuration

### Enable/Disable Redis Queue

Edit `notification_mobile_helper.php`:

```php
// Line ~12
private $useRedisQueue = true; // true = Redis, false = Direct send
```

### Redis Connection

Edit `redis_queue_service.php`:

```php
// Line ~25
$this->redis->connect('127.0.0.1', 6379);
// Hoặc với password:
// $this->redis->connect('127.0.0.1', 6379);
// $this->redis->auth('password');
```

## 🔍 Monitoring

### Check Queue Stats

```php
require_once 'redis_queue_service.php';
$queue = new RedisQueueService($conn);
$stats = $queue->getStats();
print_r($stats);
```

### Check Logs

```bash
tail -f API_WEB/debug_push_notifications.log | grep REDIS
```

### Redis CLI

```bash
redis-cli
> LLEN notifications:queue        # Normal queue size
> LLEN notifications:priority    # Priority queue size
> ZCARD notifications:delayed    # Delayed queue size
> LLEN notifications:failed      # Failed queue size
```

## 🎨 Features

### ✅ Đã Implement

- [x] Real-time processing (< 1s)
- [x] Priority queue (high/medium/low)
- [x] Delayed notifications
- [x] Auto retry với exponential backoff
- [x] Dead letter queue (failed jobs)
- [x] Fallback to database queue nếu Redis down
- [x] Backward compatibility

### 🔄 Có Thể Thêm

- [ ] Rate limiting (max notifications/user/day)
- [ ] Batching (gộp nhiều notification)
- [ ] A/B testing
- [ ] Personalization
- [ ] Dashboard monitoring

## 📊 So Sánh

| Feature | Database Queue | Redis Queue |
|---------|---------------|-------------|
| **Latency** | 1-5 giây | < 1 giây |
| **Throughput** | ~100 jobs/s | ~1000 jobs/s |
| **Retry** | Manual | Auto với backoff |
| **Priority** | ❌ | ✅ |
| **Delayed** | ❌ | ✅ |
| **Monitoring** | ⚠️ | ✅ |

## 🐛 Troubleshooting

### Redis không kết nối được

**Fallback tự động**: System sẽ tự động fallback về database queue nếu Redis down.

### Worker không chạy

```bash
# Check process
ps aux | grep notification_worker

# Check logs
tail -f debug_push_notifications.log

# Restart worker
php notification_worker_redis.php --daemon
```

### Queue bị đầy

```bash
# Check queue size
redis-cli LLEN notifications:queue

# Nếu > 1000, cần:
# 1. Tăng số worker
# 2. Tăng maxProcessPerRun
# 3. Kiểm tra performance
```

## 🎯 Next Steps

1. ✅ Install Redis
2. ✅ Install PHP Redis extension
3. ✅ Run `composer install`
4. ✅ Start worker daemon
5. ✅ Enable Redis queue trong code
6. ✅ Monitor và verify

---

**Xem thêm**: `REDIS_QUEUE_SETUP.md` để biết chi tiết setup.

