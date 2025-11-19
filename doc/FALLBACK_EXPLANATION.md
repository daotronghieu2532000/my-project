# 🔄 Giải Thích Chi Tiết: Fallback Shipping Quote

## 📋 Mục Lục
1. [Fallback Hoạt Động Như Thế Nào?](#1-fallback-hoạt-động-như-thế-nào)
2. [Tính Phí Ship Như Thế Nào?](#2-tính-phí-ship-như-thế-nào)
3. [Tính Thời Gian Ước Tính Như Thế Nào?](#3-tính-thời-gian-ước-tính-như-thế-nào)
4. [Có Bấm Nút Đặt Hàng Được Không?](#4-có-bấm-nút-đặt-hàng-được-không)

---

## 1. Fallback Hoạt Động Như Thế Nào?

### **Khi Nào Fallback Được Kích Hoạt?**

```
┌─────────────────────────────────────────┐
│  BƯỚC 1: Gọi API Shipping Quote         │
└─────────────────────────────────────────┘
  ↓
┌─────────────────────────────────────────┐
│  BƯỚC 2: Retry (Tối đa 3 lần)            │
└─────────────────────────────────────────┘
  ↓
  Attempt 1: ❌ Fail
    → Chờ 1 giây
  ↓
  Attempt 2: ❌ Fail  
    → Chờ 2 giây
  ↓
  Attempt 3: ❌ Fail
  ↓
┌─────────────────────────────────────────┐
│  BƯỚC 3: Kích Hoạt Fallback ✅           │
└─────────────────────────────────────────┘
  ↓
Tính toán phí ship ước tính
  ↓
Trả về kết quả với flag is_fallback = true
```

### **Điều Kiện Kích Hoạt Fallback:**

1. ✅ **Tất cả 3 lần retry đều fail**
   - API trả về lỗi (500, 404, etc.)
   - API timeout (không phản hồi sau 15s)
   - Network error

2. ✅ **enableFallback = true** (mặc định là true)

3. ✅ **Có items trong giỏ hàng**

### **Code Thực Tế:**

```dart
// Trong shipping_quote_service.dart

// Sau khi retry 3 lần đều fail
if (enableFallback) {
  print('⚠️ [ShippingQuote] API failed, sử dụng fallback calculation');
  return _calculateFallbackQuote(userId, items, lastError);
}
```

---

## 2. Tính Phí Ship Như Thế Nào?

### **Công Thức Tính Phí Ship Fallback:**

```
BƯỚC 1: Tính tổng giá trị đơn hàng
  totalValue = Σ(price × quantity)
  
  Trong đó:
  - price = giá thực tế từ cart (nếu có)
  - Nếu không có price → ước tính 100k/sản phẩm
  - quantity = số lượng sản phẩm

BƯỚC 2: Áp dụng bảng phí ship
  if (totalValue >= 2,000,000₫) {
    phí ship = 15,000₫
  } else if (totalValue >= 1,000,000₫) {
    phí ship = 20,000₫
  } else if (totalValue >= 500,000₫) {
    phí ship = 25,000₫
  } else {
    phí ship = 30,000₫
  }
```

### **Ví Dụ Cụ Thể:**

#### **Ví Dụ 1: Đơn hàng 300k**
```
Items:
  - Sản phẩm A: 150k × 2 = 300k
  
totalValue = 300,000₫
→ < 500k
→ phí ship = 30,000₫ ✅
```

#### **Ví Dụ 2: Đơn hàng 750k**
```
Items:
  - Sản phẩm B: 250k × 1 = 250k
  - Sản phẩm C: 500k × 1 = 500k
  
totalValue = 750,000₫
→ >= 500k và < 1M
→ phí ship = 25,000₫ ✅
```

#### **Ví Dụ 3: Đơn hàng 1.5M**
```
Items:
  - Sản phẩm D: 1,000k × 1 = 1,000k
  - Sản phẩm E: 500k × 1 = 500k
  
totalValue = 1,500,000₫
→ >= 1M và < 2M
→ phí ship = 20,000₫ ✅
```

#### **Ví Dụ 4: Đơn hàng 3M**
```
Items:
  - Sản phẩm F: 2,000k × 1 = 2,000k
  - Sản phẩm G: 1,000k × 1 = 1,000k
  
totalValue = 3,000,000₫
→ >= 2M
→ phí ship = 15,000₫ ✅
```

### **Code Thực Tế:**

```dart
// Tính tổng giá trị
int totalValue = 0;
for (final item in items) {
  final quantity = (item['quantity'] as int?) ?? 1;
  final price = (item['price'] as int?) ??      // Ưu tiên: giá từ cart
                (item['gia_moi'] as int?) ??    // Hoặc: giá từ API
                100000;                         // Fallback: ước tính 100k
  totalValue += price * quantity;
}

// Áp dụng bảng phí
int fallbackFee = 30000; // Mặc định
if (totalValue >= 2000000) {
  fallbackFee = 15000;
} else if (totalValue >= 1000000) {
  fallbackFee = 20000;
} else if (totalValue >= 500000) {
  fallbackFee = 25000;
}
```

---

## 3. Tính Thời Gian Ước Tính Như Thế Nào?

### **Công Thức Tính ETA:**

```
Ngày hiện tại: 25/01/2025

ETA = "Dự kiến từ {ngày + 2} - {ngày + 4}"

Ví dụ:
  - Ngày bắt đầu: 25/01 + 2 ngày = 27/01
  - Ngày kết thúc: 25/01 + 4 ngày = 29/01
  → ETA = "Dự kiến từ 27/01 - 29/01"
```

### **Code Thực Tế:**

```dart
String _getEstimatedDeliveryDate(int daysFromNow) {
  final date = DateTime.now().add(Duration(days: daysFromNow));
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

// Sử dụng:
final etaText = 'Dự kiến từ ${_getEstimatedDeliveryDate(2)} - ${_getEstimatedDeliveryDate(4)}';
```

### **Ví Dụ Cụ Thể:**

| Ngày Hiện Tại | ETA Fallback |
|---------------|--------------|
| 25/01/2025 | Dự kiến từ 27/01 - 29/01 |
| 28/01/2025 | Dự kiến từ 30/01 - 01/02 |
| 31/01/2025 | Dự kiến từ 02/02 - 04/02 |

**💡 Lưu ý:** 
- ETA fallback là **cố định 2-4 ngày** (không phụ thuộc vào khoảng cách)
- ETA thực tế từ API có thể khác (1-2 ngày nếu cùng tỉnh, 3-5 ngày nếu khác tỉnh)

---

## 4. Có Bấm Nút Đặt Hàng Được Không?

### **✅ CÓ, HOÀN TOÀN ĐƯỢC!**

### **Lý Do:**

1. **Fallback trả về `success: true`**
   ```dart
   final fallbackQuote = {
     'success': true,  // ✅ Đánh dấu thành công
     'fee': fallbackFee,
     'provider': 'Ước tính',
     'eta_text': etaText,
     'is_fallback': true, // ✅ Đánh dấu là fallback
     // ...
   };
   ```

2. **Checkout không kiểm tra `is_fallback`**
   ```dart
   // Trong checkout_screen.dart
   if (shippingQuote != null && shippingQuote['success'] == true) {
     // ✅ Chấp nhận cả fallback và API thật
     originalShipFee = bestOverall['fee'] as int? ?? ship.lastFee;
     // ... tiếp tục xử lý đặt hàng
   }
   ```

3. **Phí ship fallback được sử dụng bình thường**
   ```dart
   final res = await _api.createOrder(
     // ...
     phiShip: originalShipFee,  // ✅ Có thể là phí từ fallback
     shipSupport: shipSupport,
     // ...
   );
   ```

### **Flow Khi Đặt Hàng Với Fallback:**

```
User bấm "ĐẶT HÀNG"
  ↓
_processOrder()
  ↓
Gọi ShippingQuoteService.getShippingQuote()
  ↓
API fail → Fallback được kích hoạt
  ↓
Nhận được fallback quote:
  - success: true ✅
  - fee: 25,000₫ (ví dụ)
  - is_fallback: true
  ↓
Tiếp tục xử lý đặt hàng bình thường:
  - Lấy phí ship từ fallback: 25,000₫
  - Tính tổng tiền: totalGoods + 25,000₫
  - Gọi API create_order với phí ship 25,000₫
  ↓
✅ Đặt hàng thành công!
```

### **UI Hiển Thị:**

Khi đang dùng fallback, UI sẽ hiển thị:

```
Phí vận chuyển: 25,000₫
⚠️ Đang sử dụng phí ship ước tính
Dự kiến: Dự kiến từ 27/01 - 29/01
Đơn vị vận chuyển: Ước tính
```

**User vẫn có thể:**
- ✅ Xem phí ship ước tính
- ✅ Bấm nút "ĐẶT HÀNG"
- ✅ Hoàn tất đơn hàng

### **Code Kiểm Tra:**

```dart
// Trong order_summary_section.dart
if (_isFallback) {
  // Hiển thị cảnh báo nhưng vẫn cho phép checkout
  Padding(
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.orange),
        Text('Đang sử dụng phí ship ước tính'),
      ],
    ),
  ),
}
```

---

## 📊 Tóm Tắt

| Câu Hỏi | Trả Lời |
|---------|---------|
| **Fallback hoạt động khi nào?** | Khi API fail sau 3 lần retry |
| **Tính ship như thế nào?** | Dựa trên giá trị đơn hàng: <500k=30k, 500k-1M=25k, 1M-2M=20k, >2M=15k |
| **Tính ETA như thế nào?** | Cố định: từ ngày hiện tại + 2 đến + 4 ngày |
| **Có đặt hàng được không?** | ✅ **CÓ**, hoàn toàn được! |

---

## 🎯 Kết Luận

**Fallback là một cơ chế an toàn** đảm bảo:
- ✅ User luôn có thể checkout, kể cả khi API fail
- ✅ Phí ship được tính dựa trên giá trị đơn hàng thực tế
- ✅ User được thông báo rõ ràng khi đang dùng phí ship ước tính
- ✅ Đơn hàng vẫn được tạo thành công với phí ship ước tính

**Đây là best practice trong production!** 🚀

