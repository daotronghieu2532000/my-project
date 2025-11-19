# Phân Tích Hệ Thống Thông Báo Tự Động

## 📋 Tổng Quan

Hệ thống hiện tại sử dụng **Cron Jobs** kết hợp với **Database Queue Processor** để gửi thông báo tự động.

---

## 🔄 Cron là gì?

### Định nghĩa
**Cron** là một tiện ích lập lịch trong Unix/Linux cho phép chạy các script/task tự động theo lịch định kỳ.

### Cách hoạt động
```bash
# Crontab format: phút giờ ngày tháng thứ
# Ví dụ: Chạy mỗi giờ
0 * * * * php /path/to/script.php

# Ví dụ: Chạy mỗi ngày lúc 8:00 AM
0 8 * * * php /path/to/script.php
```

### Ưu điểm
✅ **Đơn giản**: Dễ setup, không cần infrastructure phức tạp  
✅ **Tin cậy**: Đã được sử dụng hàng chục năm, rất ổn định  
✅ **Linh hoạt**: Có thể lập lịch theo nhiều pattern khác nhau  
✅ **Không tốn tài nguyên**: Chỉ chạy khi đến giờ, không chạy liên tục  

### Nhược điểm
❌ **Không real-time**: Chỉ chạy theo lịch, không phản ứng ngay lập tức  
❌ **Khó scale**: Mỗi server cần setup cron riêng  
❌ **Khó monitor**: Khó theo dõi trạng thái và lỗi  
❌ **Không có retry tự động**: Nếu lỗi, phải đợi lần chạy tiếp theo  
❌ **Race condition**: Nếu nhiều instance chạy cùng lúc có thể duplicate  

---

## 🏗️ Kiến Trúc Hiện Tại

### 1. **Cron Jobs** (Tạo Notification)

#### `notification_cron_voucher_expiring.php`
- **Tần suất**: Mỗi giờ (`0 * * * *`)
- **Chức năng**: Tìm voucher sắp hết hạn (< 24h) và tạo notification cho tất cả user
- **Logic**:
  ```php
  // Query voucher sắp hết hạn
  SELECT * FROM coupon 
  WHERE expired > NOW() AND expired <= NOW() + 24h
  
  // Tạo notification cho TẤT CẢ user có device_token
  INSERT INTO notification_mobile (user_id, type, title, content, push_sent=0)
  SELECT user_id FROM user_info WHERE ctv=0 AND active=1
  ```

#### `notification_cron_affiliate_daily.php`
- **Tần suất**: Mỗi ngày (`0 8 * * *`)
- **Chức năng**: Tìm sản phẩm affiliate hot và tạo notification
- **Logic**:
  - Tìm sản phẩm có hoa hồng cao nhất
  - Tìm sản phẩm bán chạy nhất (24h qua)
  - Tạo notification cho tất cả user có device_token

### 2. **Database Triggers** (Tạo Notification Real-time)

#### Các trigger trong `TRIGGERS_NOTIFICATION_COMPLETE.sql`:
- `tr_donhang_insert`: Đơn hàng mới → notification
- `tr_donhang_status_update`: Thay đổi trạng thái → notification
- `tr_lichsu_chitieu_insert`: Nạp/rút tiền → notification
- `tr_coupon_insert`: Voucher mới → notification
- `tr_sanpham_aff_insert`: Affiliate product mới → notification

**Ưu điểm**: Phản ứng ngay lập tức khi có event xảy ra

### 3. **Queue Processor** (Gửi Push Notification)

#### `notification_queue_processor_db.php`
- **Chế độ**: Daemon (chạy liên tục) hoặc Single run
- **Tần suất check**: Mỗi 1 giây
- **Logic**:
  ```php
  // Query notification chưa gửi push
  SELECT * FROM notification_mobile 
  WHERE push_sent = 0 
  AND created_at >= last_check_time
  
  // Gửi push và update push_sent = 1
  ```

**Ưu điểm**: 
- Event-driven: Chỉ check notification mới
- Tránh duplicate: Dùng pessimistic lock (UPDATE ... WHERE push_sent=0)

---

## 📊 So Sánh: Cron vs Queue vs Event-Driven

| Tiêu chí | Cron | Database Queue | Message Queue (RabbitMQ/Kafka) |
|---------|------|----------------|-------------------------------|
| **Real-time** | ❌ Chậm (theo lịch) | ✅ Nhanh (1-5s) | ✅ Rất nhanh (<1s) |
| **Scalability** | ❌ Khó scale | ⚠️ Vừa phải | ✅ Dễ scale |
| **Reliability** | ⚠️ Phụ thuộc server | ✅ Tốt (DB persistent) | ✅ Rất tốt |
| **Complexity** | ✅ Đơn giản | ⚠️ Trung bình | ❌ Phức tạp |
| **Cost** | ✅ Rẻ | ✅ Rẻ | ⚠️ Cần infrastructure |
| **Monitoring** | ❌ Khó | ⚠️ Vừa phải | ✅ Tốt (có dashboard) |

---

## 🏢 Cách Shopee và Các App Lớn Làm

### 1. **Shopee / Lazada / Tiki**

#### Kiến trúc:
```
Event → Message Queue (Kafka/RabbitMQ) → Worker Pool → Push Service
```

#### Đặc điểm:
- ✅ **Message Queue**: Dùng Kafka hoặc RabbitMQ để decouple
- ✅ **Worker Pool**: Nhiều worker xử lý song song
- ✅ **Rate Limiting**: Giới hạn số notification/user/ngày
- ✅ **A/B Testing**: Test nội dung notification
- ✅ **Personalization**: Gửi notification dựa trên behavior
- ✅ **Scheduling**: Hỗ trợ delay notification (ví dụ: gửi sau 2 giờ)

#### Ví dụ flow:
```
User đặt hàng 
  → Event: order.created
  → Kafka Topic: notifications
  → Worker: Parse event, tạo notification
  → Worker: Check user preferences
  → Worker: Gửi push notification
```

### 2. **Facebook / Instagram**

- ✅ **Real-time Event System**: Dùng Apache Kafka
- ✅ **Machine Learning**: Dự đoán notification nào user sẽ click
- ✅ **Batching**: Gộp nhiều notification thành 1 push
- ✅ **Priority Queue**: Ưu tiên notification quan trọng

### 3. **Amazon**

- ✅ **SQS (Simple Queue Service)**: Queue service của AWS
- ✅ **Lambda Functions**: Serverless processing
- ✅ **SNS (Simple Notification Service)**: Push service
- ✅ **CloudWatch**: Monitoring và alerting

---

## 🚀 Đề Xuất Cải Tiến

### Option 1: **Cải thiện Database Queue (Recommended cho hiện tại)**

#### Ưu điểm:
- ✅ Không cần thêm infrastructure
- ✅ Dễ implement
- ✅ Tận dụng code hiện có

#### Cải tiến:
1. **Thêm Priority Queue**:
   ```sql
   SELECT * FROM notification_mobile 
   WHERE push_sent = 0 
   ORDER BY priority DESC, created_at ASC
   ```

2. **Thêm Rate Limiting**:
   ```sql
   -- Chỉ gửi tối đa 5 notification/user/ngày
   SELECT COUNT(*) FROM notification_mobile 
   WHERE user_id = ? AND created_at >= TODAY()
   ```

3. **Thêm Retry Logic**:
   ```sql
   ALTER TABLE notification_mobile 
   ADD COLUMN retry_count INT DEFAULT 0,
   ADD COLUMN last_retry_at INT DEFAULT NULL;
   ```

4. **Thêm Batching**:
   - Gộp nhiều notification cùng user thành 1 push
   - Giảm số lượng push, tăng engagement

### Option 2: **Message Queue (RabbitMQ/Redis Queue)**

#### Setup:
```php
// Producer (khi có event)
$channel->queue_declare('notifications', false, true, false, false);
$channel->basic_publish($msg, '', 'notifications');

// Consumer (worker)
$channel->basic_consume('notifications', '', false, false, false, false, $callback);
```

#### Ưu điểm:
- ✅ Real-time hơn
- ✅ Dễ scale (thêm worker)
- ✅ Có retry tự động
- ✅ Monitoring tốt hơn

#### Nhược điểm:
- ❌ Cần setup RabbitMQ/Redis
- ❌ Phức tạp hơn
- ❌ Cần quản lý queue

### Option 3: **Hybrid: Cron + Queue**

#### Kiến trúc:
```
Cron (scheduled) → Database Queue → Queue Processor → Push
Event (real-time) → Message Queue → Worker → Push
```

#### Khi nào dùng gì:
- **Cron**: Notification theo lịch (voucher expiring, daily affiliate)
- **Queue**: Notification real-time (order status, deposit/withdrawal)

---

## 📈 Metrics và Monitoring

### Metrics cần theo dõi:
1. **Notification Creation Rate**: Số notification tạo/giờ
2. **Push Success Rate**: Tỷ lệ push thành công
3. **Delivery Time**: Thời gian từ tạo đến gửi
4. **Click Rate**: Tỷ lệ user click notification
5. **Queue Size**: Số notification pending

### Monitoring Tools:
- **Grafana + Prometheus**: Real-time dashboard
- **ELK Stack**: Log analysis
- **CloudWatch**: AWS monitoring
- **Custom Dashboard**: PHP + MySQL

---

## 🎯 Kết Luận và Khuyến Nghị

### Cho hệ thống hiện tại (quy mô vừa):
✅ **Giữ Database Queue Processor** (đã tốt)  
✅ **Cải thiện Cron Jobs**: Thêm error handling, logging  
✅ **Thêm Rate Limiting**: Tránh spam user  
✅ **Thêm Monitoring**: Dashboard đơn giản  

### Khi scale lên (100k+ users):
🔄 **Chuyển sang Message Queue** (RabbitMQ/Redis)  
🔄 **Thêm Worker Pool**: Xử lý song song  
🔄 **Thêm Personalization**: ML-based notification  
🔄 **Thêm A/B Testing**: Test nội dung  

### Best Practices:
1. ✅ **Idempotency**: Đảm bảo không duplicate notification
2. ✅ **Retry Logic**: Retry khi lỗi (với exponential backoff)
3. ✅ **Rate Limiting**: Giới hạn số notification/user
4. ✅ **Monitoring**: Theo dõi metrics và alerting
5. ✅ **Testing**: Test với staging data trước khi deploy

---

## 📚 Tài Liệu Tham Khảo

- [Shopee Engineering Blog](https://engineering.shopee.com/)
- [Facebook Notification System](https://engineering.fb.com/)
- [RabbitMQ Best Practices](https://www.rabbitmq.com/best-practices.html)
- [Kafka Use Cases](https://kafka.apache.org/uses)

---

**Tác giả**: AI Assistant  
**Ngày tạo**: 2025-01-08  
**Phiên bản**: 1.0

