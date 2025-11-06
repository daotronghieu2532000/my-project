# Tài liệu: Refactor Bố Cục Sản Phẩm - Từ Trái-Phải Sang Trên-Dưới (2 Cột)

## 📋 Tổng Quan

Tài liệu này mô tả chi tiết logic và cách triển khai việc refactor bố cục hiển thị sản phẩm từ layout **trái-phải** (horizontal) sang layout **trên-dưới** (vertical) với **2 cột** trong Flutter, áp dụng cho các màn hình:
- Gợi ý cho bạn (Home)
- Tìm kiếm sản phẩm
- Danh mục sản phẩm
- Sản phẩm shop
- Sản phẩm freeship
- Gợi ý trong giỏ hàng

---

## 🎯 Mục Tiêu

1. **Thay đổi bố cục card**: Từ `Row` (ảnh trái, thông tin phải) → `Column` (ảnh trên, thông tin dưới)
2. **Hiển thị 2 cột**: Thay vì 1 sản phẩm/màn hình → 2 sản phẩm/màn hình ngang
3. **Cuộn dọc**: Thay vì cuộn ngang → cuộn dọc với infinite scroll
4. **Tối ưu hiển thị**: Badges chỉ icon, bỏ giá cũ, tự co giãn theo nội dung

---

## 🏗️ Kiến Trúc Tổng Quan

### 1. Cấu Trúc Widget Hierarchy

```
Screen (StatefulWidget)
└── Column
    ├── Header (số kết quả, filter button)
    ├── Filter Panel (optional)
    └── Expanded
        └── SingleChildScrollView / ListView
            └── Wrap (2 cột)
                └── SizedBox (width = cardWidth)
                    └── ProductCard (Column layout)
                        ├── Image Container (top)
                        └── Info Container (bottom)
```

### 2. Flow Dữ Liệu

```
API Service
  ↓
CachedApiService (cache layer)
  ↓
Screen State (_products list)
  ↓
_buildProductsGrid() / Wrap
  ↓
ProductCard (mỗi item)
```

---

## 📐 Logic Tính Toán Kích Thước

### 1. Tính Width Cho Card (2 Cột)

```dart
final screenWidth = MediaQuery.of(context).size.width;
// Công thức: (screenWidth - padding left/right - spacing giữa 2 cột) / 2
// Padding: 4px mỗi bên = 8px
// Spacing: 8px giữa 2 cột
final cardWidth = (screenWidth - 16) / 2; // 16 = 8 (padding) + 8 (spacing)
```

**Giải thích:**
- `screenWidth`: Chiều rộng màn hình thiết bị
- `- 16`: Trừ đi padding (8px mỗi bên) và spacing (8px giữa 2 cột)
- `/ 2`: Chia đôi để có 2 cột bằng nhau

**Ví dụ:**
- Màn hình 360px: `cardWidth = (360 - 16) / 2 = 172px`
- Màn hình 414px: `cardWidth = (414 - 16) / 2 = 199px`

### 2. Tính Height Cho Ảnh (Square Aspect Ratio)

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final imageWidth = constraints.maxWidth; // Width thực tế từ parent
    return Container(
      width: double.infinity,
      height: imageWidth * 1.0, // Ảnh vuông: height = width
    );
  },
)
```

**Giải thích:**
- `LayoutBuilder`: Lấy constraints từ parent widget
- `constraints.maxWidth`: Width thực tế mà parent cung cấp (cardWidth)
- `height = width * 1.0`: Tạo ảnh vuông (aspect ratio 1:1)

**Tại sao dùng LayoutBuilder?**
- Đảm bảo ảnh luôn vuông dù cardWidth thay đổi theo màn hình
- Responsive với mọi kích thước màn hình

---

## 🎨 Cấu Trúc Product Card

### 1. Layout Cũ (Trái-Phải)

```dart
Container
└── InkWell
    └── Stack
        ├── Padding
        │   └── Row  // ❌ Layout cũ
        │       ├── Container (Ảnh - 150x150 cố định)
        │       └── Expanded (Thông tin)
        └── Positioned (Cart icon)
```

**Vấn đề:**
- Ảnh cố định 150x150px → không responsive
- 1 sản phẩm/màn hình → không tối ưu không gian
- ListView dọc → scroll dài

### 2. Layout Mới (Trên-Dưới)

```dart
Container
└── InkWell
    └── Column  // ✅ Layout mới
        ├── LayoutBuilder
        │   └── Container (Ảnh - width: 100%, height: width)
        │       └── Stack
        │           ├── Image
        │           ├── Positioned (Flash sale icon)
        │           ├── Positioned (Discount badge)
        │           └── Positioned (Cart icon)
        └── Padding
            └── Column (Thông tin)
                ├── Text (Tên)
                ├── Row (Giá + Badges icon)
                ├── Row (Rating + Sold)
                └── ProductLocationBadge
```

**Ưu điểm:**
- Ảnh responsive: `width: 100%`, `height: width` → luôn vuông
- 2 cột → hiển thị nhiều sản phẩm hơn
- Tự co giãn theo nội dung → không overflow

---

## 🔧 Chi Tiết Implementation

### 1. Wrap Widget (2 Cột Grid)

```dart
Widget _buildProductsGrid() {
  final screenWidth = MediaQuery.of(context).size.width;
  final cardWidth = (screenWidth - 16) / 2;

  return Wrap(
    spacing: 8,        // Khoảng cách ngang giữa các card
    runSpacing: 8,    // Khoảng cách dọc giữa các hàng
    children: products.map((product) {
      return SizedBox(
        width: cardWidth,  // Width cố định cho 2 cột
        child: ProductCard(product: product),
      );
    }).toList(),
  );
}
```

**Giải thích:**
- `Wrap`: Widget tự động wrap các children sang hàng mới khi hết chỗ
- `spacing: 8`: Khoảng cách ngang giữa 2 card trong cùng 1 hàng
- `runSpacing: 8`: Khoảng cách dọc giữa các hàng
- `SizedBox(width: cardWidth)`: Giới hạn width để đảm bảo 2 cột bằng nhau

**Tại sao dùng Wrap thay vì GridView?**
- `GridView.builder` với `childAspectRatio` cố định → gây overflow
- `Wrap` cho phép children tự định nghĩa height → không overflow
- Dễ responsive với mọi kích thước màn hình

### 2. Product Card Structure

```dart
Widget build(BuildContext context) {
  return Container(
    // ❌ KHÔNG set width/margin ở đây
    // ✅ Để parent SizedBox quản lý width
    decoration: BoxDecoration(...),
    child: InkWell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,  // ⭐ Quan trọng: tự co giãn
        children: [
          // Image section
          LayoutBuilder(...),
          // Info section
          Padding(...),
        ],
      ),
    ),
  );
}
```

**Điểm quan trọng:**
- `mainAxisSize: MainAxisSize.min`: Column chỉ chiếm không gian cần thiết
- Không set `width` ở Container: Để parent `SizedBox` quản lý
- Không dùng `margin`: `Wrap` đã xử lý spacing

### 3. Image Container với LayoutBuilder

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final imageWidth = constraints.maxWidth;  // Lấy width từ parent
    return Container(
      width: double.infinity,
      height: imageWidth * 1.0,  // Ảnh vuông
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Stack(
        children: [
          // Image
          ClipRRect(...),
          // Badges overlay
          Positioned(...),
        ],
      ),
    );
  },
)
```

**Tại sao dùng LayoutBuilder?**
- `constraints.maxWidth`: Lấy width thực tế từ parent `SizedBox`
- Đảm bảo ảnh luôn vuông dù cardWidth thay đổi
- Responsive với mọi kích thước màn hình

### 4. Info Section (Tự Co Giãn)

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,  // ⭐ Tự co giãn
    children: [
      Text(product.name, maxLines: 2, ...),
      const SizedBox(height: 4),
      // Giá + Badges cùng hàng
      Row(
        children: [
          Flexible(Text(price, ...)),
          Row(badges icons),
        ],
      ),
      const SizedBox(height: 3),
      Row(rating + sold),
      const SizedBox(height: 3),
      ProductLocationBadge(...),
    ],
  ),
)
```

**Tối ưu:**
- `mainAxisSize: MainAxisSize.min`: Column chỉ cao bằng nội dung
- Padding giảm: `fromLTRB(8, 4, 8, 4)` thay vì `all(8)`
- Spacing giảm: `SizedBox(height: 3)` thay vì `4-6`

### 5. Badges Icon Only (Cùng Hàng Với Giá)

```dart
Row(
  children: [
    Flexible(Text(price, ...)),  // Giá
    const SizedBox(width: 4),
    Row(  // Badges chỉ icon
      mainAxisSize: MainAxisSize.min,
      children: [
        if (voucherIcon != null)
          _buildIconOnlyBadge(
            icon: Icons.local_offer,
            color: Colors.orange,
            size: screenWidth < 360 ? 8 : 10,
          ),
        // ... các badges khác
      ],
    ),
  ],
)
```

**Helper Method:**
```dart
Widget _buildIconOnlyBadge({
  required IconData icon,
  required Color color,
  required double size,
}) {
  return Container(
    padding: const EdgeInsets.all(3),  // Nhỏ hơn flash sale
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),  // Nhỏ hơn flash sale
    ),
    child: Icon(icon, size: size, color: Colors.white),
  );
}
```

**Responsive:**
- `screenWidth < 360`: Icon size 8px
- `screenWidth >= 360`: Icon size 10px

---

## 📱 Responsive Design

### 1. Font Sizes

```dart
final screenWidth = MediaQuery.of(context).size.width;

// Tên sản phẩm
fontSize: screenWidth < 360 ? 12 : 14

// Giá
fontSize: screenWidth < 360 ? 14 : 16

// Rating/Sold
fontSize: screenWidth < 360 ? 10 : 11

// Badge location
fontSize: screenWidth < 360 ? 8 : 9
```

### 2. Icon Sizes

```dart
// Star icon
Icon(Icons.star, size: screenWidth < 360 ? 11 : 13)

// Badge icons
size: screenWidth < 360 ? 8 : 10
```

### 3. Spacing

```dart
// Giữa các elements
const SizedBox(height: 3)  // Thay vì 4-6

// Padding info section
const EdgeInsets.fromLTRB(8, 4, 8, 4)  // Thay vì all(8)
```

---

## 🔄 Scroll Behavior

### 1. SingleChildScrollView + Wrap

```dart
Expanded(
  child: SingleChildScrollView(
    controller: _scrollController,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: _buildProductsGrid(),  // Wrap widget
  ),
)
```

**Ưu điểm:**
- Scroll mượt mà
- Infinite scroll dễ implement
- Không bị giới hạn bởi `childAspectRatio`

### 2. Infinite Scroll Logic

```dart
void _onScroll() {
  if (_scrollController.position.pixels >= 
      _scrollController.position.maxScrollExtent - 200) {
    _loadMore();
  }
}
```

**Giải thích:**
- Khi scroll đến 200px trước cuối danh sách → load more
- `maxScrollExtent`: Độ dài tối đa của scrollable content

---

## 🎯 So Sánh: Cũ vs Mới

### Layout Cũ

| Đặc điểm | Giá trị |
|----------|---------|
| Layout | Row (trái-phải) |
| Ảnh size | 150x150px cố định |
| Sản phẩm/màn hình | 1 |
| Scroll | ListView dọc (1 cột) |
| Badges | Text + icon |
| Giá cũ | Hiển thị |
| Height | Cố định 150px |

### Layout Mới

| Đặc điểm | Giá trị |
|----------|---------|
| Layout | Column (trên-dưới) |
| Ảnh size | 100% width, height = width (responsive) |
| Sản phẩm/màn hình | 2 |
| Scroll | Wrap 2 cột (cuộn dọc) |
| Badges | Chỉ icon |
| Giá cũ | Ẩn |
| Height | Tự co giãn theo nội dung |

---

## 🐛 Xử Lý Lỗi Thường Gặp

### 1. Overflow Error

**Nguyên nhân:**
- Dùng `GridView.builder` với `childAspectRatio` cố định
- Height không đủ cho nội dung

**Giải pháp:**
- Dùng `Wrap` thay vì `GridView`
- `mainAxisSize: MainAxisSize.min` cho Column
- `LayoutBuilder` để tính height động

### 2. Ảnh Không Vuông

**Nguyên nhân:**
- Hardcode height cố định
- Không responsive với cardWidth

**Giải pháp:**
- Dùng `LayoutBuilder` để lấy width từ parent
- `height = width * 1.0` để tạo ảnh vuông

### 3. Spacing Không Đều

**Nguyên nhân:**
- Dùng `margin` trong card khi đã có `Wrap` spacing

**Giải pháp:**
- Bỏ `margin` trong card
- Dùng `Wrap` spacing và runSpacing

---

## 📊 Performance Considerations

### 1. Image Loading

```dart
Image.network(
  product.image,
  width: double.infinity,
  height: double.infinity,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
)
```

**Tối ưu:**
- `BoxFit.cover`: Ảnh fill container, crop nếu cần
- `errorBuilder`: Hiển thị placeholder khi lỗi
- Nên dùng `CachedNetworkImage` cho production

### 2. List Rendering

**Wrap vs GridView:**
- `Wrap`: Render tất cả items cùng lúc → OK với < 50 items
- `GridView.builder`: Lazy loading → Tốt hơn với > 100 items

**Khuyến nghị:**
- < 50 items: Dùng `Wrap` (đơn giản, không overflow)
- > 100 items: Cân nhắc `GridView.builder` với `childAspectRatio` động

---

## 🔍 Code Examples

### Example 1: Product Grid Screen

```dart
class ProductGridScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        _buildHeader(),
        // Filter panel
        if (_showFilters) _buildFilterPanel(),
        // Products grid
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: _buildProductsGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 16) / 2;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _products.map((product) {
        return SizedBox(
          width: cardWidth,
          child: ProductCard(product: product),
        );
      }).toList(),
    );
  }
}
```

### Example 2: Product Card

```dart
class ProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      decoration: BoxDecoration(...),
      child: InkWell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            LayoutBuilder(
              builder: (context, constraints) {
                final imageWidth = constraints.maxWidth;
                return Container(
                  width: double.infinity,
                  height: imageWidth * 1.0,
                  child: Stack(...),
                );
              },
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, ...),
                  Row(price + badges),
                  Row(rating + sold),
                  ProductLocationBadge(...),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## ✅ Checklist Implementation

Khi refactor một screen mới, đảm bảo:

- [ ] Thay `ListView.builder` → `SingleChildScrollView` + `Wrap`
- [ ] Tính `cardWidth = (screenWidth - 16) / 2`
- [ ] Wrap `SizedBox(width: cardWidth)` cho mỗi card
- [ ] Card dùng `Column` với `mainAxisSize: MainAxisSize.min`
- [ ] Ảnh dùng `LayoutBuilder` với `height = width * 1.0`
- [ ] Bỏ `margin` trong card (dùng Wrap spacing)
- [ ] Badges chỉ icon, cùng hàng với giá
- [ ] Bỏ hiển thị giá cũ
- [ ] Responsive font/icon sizes
- [ ] Giảm padding/spacing để compact hơn

---

## 📚 Tài Liệu Tham Khảo

- [Flutter LayoutBuilder](https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html)
- [Flutter Wrap Widget](https://api.flutter.dev/flutter/widgets/Wrap-class.html)
- [Flutter Responsive Design](https://docs.flutter.dev/development/ui/layout/responsive)

---

## 🎉 Kết Luận

Refactor này đạt được:
- ✅ Bố cục hiện đại, dễ nhìn hơn
- ✅ Hiển thị nhiều sản phẩm hơn (2 cột)
- ✅ Responsive với mọi màn hình
- ✅ Không overflow, tự co giãn
- ✅ Performance tốt
- ✅ Code dễ maintain

**Lưu ý:** Pattern này có thể áp dụng cho bất kỳ danh sách sản phẩm nào trong app.

