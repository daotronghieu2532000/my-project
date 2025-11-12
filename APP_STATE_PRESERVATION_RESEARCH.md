# Nghiên Cứu: App State Preservation - Cách Các App Hiện Đại Xử Lý

## 📚 Tổng Quan

Các app lớn như Shopee, Lazada, Tiki sử dụng nhiều kỹ thuật để đảm bảo trải nghiệm người dùng mượt mà khi chuyển đổi giữa các app.

## 🎯 Các Kỹ Thuật Hiện Đại

### 1. **IndexedStack thay vì Navigator cho Bottom Navigation**

**Vấn đề hiện tại:**
- Sử dụng `Navigator` cho bottom tabs → Mỗi lần switch tab sẽ dispose và rebuild
- Mất state khi chuyển tab

**Giải pháp hiện đại:**
```dart
// Sử dụng IndexedStack để giữ tất cả tabs alive
IndexedStack(
  index: _currentIndex,
  children: [
    HomeScreen(key: PageStorageKey('home')),
    CategoryScreen(key: PageStorageKey('category')),
    AffiliateScreen(key: PageStorageKey('affiliate')),
  ],
)
```

**Lợi ích:**
- ✅ Giữ tất cả tabs trong memory
- ✅ Không dispose khi switch tab
- ✅ Giữ nguyên scroll position và state
- ✅ Sử dụng `PageStorageKey` để lưu scroll position tự động

### 2. **AutomaticKeepAliveClientMixin cho StatefulWidget**

**Cách sử dụng:**
```dart
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // Giữ widget alive
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // QUAN TRỌNG: Phải gọi super.build()
    return Scaffold(...);
  }
}
```

**Lợi ích:**
- ✅ Widget không bị dispose khi scroll ra khỏi viewport
- ✅ Giữ nguyên state và scroll position
- ✅ Hoạt động tốt với ListView, GridView

### 3. **PageStorage cho Scroll Position**

**Cách sử dụng:**
```dart
ListView(
  key: PageStorageKey('home_scroll'),
  controller: _scrollController,
  children: [...],
)
```

**Lợi ích:**
- ✅ Flutter tự động lưu và restore scroll position
- ✅ Không cần code thủ công
- ✅ Hoạt động với tất cả scrollable widgets

### 4. **GlobalKey cho Navigation Stack**

**Vấn đề:**
- Khi app bị kill và restart, navigation stack bị mất
- Không thể restore các màn hình con (ProductDetail, Cart, etc.)

**Giải pháp:**
```dart
// Lưu navigation state vào SharedPreferences
class NavigationStateManager {
  static Future<void> saveNavigationStack(List<String> routes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('navigation_stack', routes);
  }
  
  static Future<List<String>> getNavigationStack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('navigation_stack') ?? [];
  }
}

// Restore khi app restart
Future<void> restoreNavigation() async {
  final routes = await NavigationStateManager.getNavigationStack();
  if (routes.isNotEmpty) {
    for (final route in routes) {
      navigator.pushNamed(route);
    }
  }
}
```

### 5. **State Management với Provider/Riverpod**

**Cách các app lớn làm:**
- Sử dụng state management để lưu trữ state toàn cục
- State không bị mất khi widget dispose
- Dễ dàng restore state khi app restart

**Ví dụ với Provider:**
```dart
class AppStateProvider extends ChangeNotifier {
  int currentTab = 0;
  Map<int, double> scrollPositions = {};
  
  void saveScrollPosition(int tab, double position) {
    scrollPositions[tab] = position;
    notifyListeners();
  }
  
  Future<void> persistToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scroll_positions', jsonEncode(scrollPositions));
  }
}
```

### 6. **Android: Don't Kill App Process**

**Cấu hình AndroidManifest.xml:**
```xml
<application
    android:name="${applicationName}"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
```

**Lợi ích:**
- `singleTop`: Không tạo Activity mới nếu đã có
- `configChanges`: Không restart khi config thay đổi
- Giữ app process alive lâu hơn

### 7. **iOS: Background Modes**

**Info.plist:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

## 🔍 Phân Tích Cách Shopee/Lazada Làm

### **Quan sát thực tế:**

1. **Bottom Navigation:**
   - Sử dụng `IndexedStack` → Tabs không bị dispose
   - Scroll position được giữ nguyên
   - State được preserve

2. **Navigation Stack:**
   - Khi vào Product Detail → Lưu route vào history
   - Khi quay lại → Restore từ history
   - Sử dụng deep linking để restore

3. **Memory Management:**
   - Chỉ load data khi cần (lazy loading)
   - Cache data trong memory
   - Clear cache khi memory thấp

4. **App Lifecycle:**
   - Lưu state khi pause
   - Restore state khi resume
   - Timeout: ~5-10 phút

## 💡 Giải Pháp Đề Xuất Cho App Của Bạn

### **Phase 1: Quick Wins (Dễ implement, hiệu quả cao)**

1. ✅ **Sử dụng IndexedStack cho RootShell**
   - Thay đổi nhỏ, hiệu quả lớn
   - Giữ tất cả tabs alive

2. ✅ **Thêm AutomaticKeepAliveClientMixin cho các Screen**
   - HomeScreen, CategoryScreen, AffiliateScreen
   - Giữ state khi switch tab

3. ✅ **Sử dụng PageStorageKey cho scroll position**
   - Flutter tự động handle
   - Không cần code thủ công

### **Phase 2: Advanced (Cần thời gian implement)**

4. **Lưu Navigation Stack**
   - Track routes khi navigate
   - Restore khi app restart
   - Deep linking support

5. **State Management**
   - Migrate sang Provider/Riverpod
   - Centralized state
   - Easy to persist

6. **Smart Cache Management**
   - Cache data trong memory
   - Persist critical data
   - Clear when needed

## 📊 So Sánh Các Giải Pháp

| Giải Pháp | Độ Khó | Hiệu Quả | Thời Gian |
|-----------|--------|----------|-----------|
| IndexedStack | ⭐ Dễ | ⭐⭐⭐⭐⭐ | 30 phút |
| AutomaticKeepAliveClientMixin | ⭐⭐ Trung bình | ⭐⭐⭐⭐ | 1 giờ |
| PageStorageKey | ⭐ Dễ | ⭐⭐⭐⭐ | 15 phút |
| Navigation Stack Preservation | ⭐⭐⭐⭐ Khó | ⭐⭐⭐⭐⭐ | 4-6 giờ |
| State Management Migration | ⭐⭐⭐⭐⭐ Rất khó | ⭐⭐⭐⭐⭐ | 1-2 ngày |

## 🎯 Khuyến Nghị

**Bắt đầu với Phase 1:**
1. Thay đổi RootShell sang IndexedStack
2. Thêm AutomaticKeepAliveClientMixin cho các Screen
3. Sử dụng PageStorageKey cho scroll position

**Kết quả mong đợi:**
- ✅ Tabs không bị reload khi switch
- ✅ Scroll position được giữ nguyên
- ✅ State được preserve
- ✅ Trải nghiệm mượt mà như Shopee/Lazada

**Sau đó mới làm Phase 2** nếu cần navigation stack preservation.

## 📚 Tài Liệu Tham Khảo

- [Flutter IndexedStack Documentation](https://api.flutter.dev/flutter/widgets/IndexedStack-class.html)
- [AutomaticKeepAliveClientMixin](https://api.flutter.dev/flutter/widgets/AutomaticKeepAliveClientMixin-mixin.html)
- [PageStorage Documentation](https://api.flutter.dev/flutter/widgets/PageStorage-class.html)
- [Flutter App Lifecycle](https://docs.flutter.dev/development/ui/interactive#handling-gestures)

## 🔄 Next Steps

1. ✅ Nghiên cứu hoàn tất
2. ⏳ Implement Phase 1 (IndexedStack + AutomaticKeepAliveClientMixin)
3. ⏳ Test và đánh giá
4. ⏳ Quyết định có làm Phase 2 không
