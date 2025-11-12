# Hướng Dẫn Đọc Debug Logs - App State Preservation

## 📋 Tổng Quan

Các debug logs được thêm vào để theo dõi hoạt động của hệ thống **IndexedStack + AutomaticKeepAliveClientMixin + PageStorageKey**.

## 🔍 Các Loại Logs

### 1. **RootShell Logs**

#### `🚀 [RootShell] initState`
- **Khi nào:** Khi RootShell được khởi tạo
- **Ý nghĩa:** App bắt đầu, tab ban đầu được set
- **Ví dụ:**
  ```
  🚀 [RootShell] initState - Initial tab: 0
  ```

#### `🏗️ [RootShell] build`
- **Khi nào:** Mỗi lần RootShell rebuild
- **Ý nghĩa:** IndexedStack đang hiển thị tab nào, giữ bao nhiêu tabs alive
- **Ví dụ:**
  ```
  🏗️ [RootShell] build - Current tab: 1
     📦 IndexedStack: Showing tab 1, keeping all 3 tabs alive
  ```

#### `🔄 [RootShell] Tab changed`
- **Khi nào:** Khi user switch tab
- **Ý nghĩa:** Tab đang chuyển từ X sang Y, IndexedStack sẽ show tab mới nhưng giữ tất cả tabs alive
- **Ví dụ:**
  ```
  🔄 [RootShell] Tab changed: 0 → 1
     📊 IndexedStack will show tab 1 (all tabs kept alive)
  ```

#### `🗑️ [RootShell] dispose`
- **Khi nào:** Khi RootShell bị dispose (thường là khi app đóng)
- **Ý nghĩa:** App đang đóng hoàn toàn
- **Ví dụ:**
  ```
  🗑️ [RootShell] dispose
  ```

---

### 2. **HomeScreen Logs**

#### `🚀 [HomeScreen] initState`
- **Khi nào:** Khi HomeScreen được khởi tạo lần đầu
- **Ý nghĩa:** Tab "Trang chủ" được tạo, `wantKeepAlive: true` nghĩa là widget sẽ được giữ alive
- **Ví dụ:**
  ```
  🚀 [HomeScreen] initState - wantKeepAlive: true
  ```
- **⚠️ Lưu ý:** Với IndexedStack, initState chỉ được gọi **1 lần** khi app khởi động. Nếu thấy nhiều lần → IndexedStack không hoạt động đúng!

#### `🏗️ [HomeScreen] build`
- **Khi nào:** Mỗi lần HomeScreen rebuild
- **Ý nghĩa:** Widget đang được rebuild, scroll position hiện tại, PageStorageKey đang hoạt động
- **Ví dụ:**
  ```
  🏗️ [HomeScreen] build - Scroll position: 1234.5
     ✅ wantKeepAlive: true (widget will be kept alive)
     📦 PageStorageKey: home_list (Flutter auto-saves scroll position)
  ```

#### `📜 [HomeScreen] Scroll position`
- **Khi nào:** Khi user scroll (mỗi 500px)
- **Ý nghĩa:** Scroll position hiện tại, PageStorage sẽ tự động lưu
- **Ví dụ:**
  ```
  📜 [HomeScreen] Scroll position: 1000.0
     💾 PageStorage will auto-save this position
  ```

#### `🗑️ [HomeScreen] dispose`
- **Khi nào:** Khi HomeScreen bị dispose
- **Ý nghĩa:** ⚠️ **ĐÂY LÀ DẤU HIỆU XẤU!** Với IndexedStack + AutomaticKeepAliveClientMixin, widget **KHÔNG NÊN** bị dispose khi switch tab
- **Ví dụ:**
  ```
  🗑️ [HomeScreen] dispose called!
     ⚠️ This should NOT happen with IndexedStack + AutomaticKeepAliveClientMixin
     📊 Scroll position at dispose: 1234.5
     💡 If you see this, IndexedStack is not working correctly
  ```
- **🔴 Nếu thấy log này khi switch tab:** IndexedStack không hoạt động đúng, cần kiểm tra lại code!

---

### 3. **CategoryScreen & AffiliateScreen Logs**

Tương tự như HomeScreen:
- `🚀 [CategoryScreen] initState` / `🚀 [AffiliateScreen] initState`
- `🏗️ [CategoryScreen] build` / `🏗️ [AffiliateScreen] build`
- `🗑️ [CategoryScreen] dispose` / `🗑️ [AffiliateScreen] dispose`

---

## ✅ Kịch Bản Hoạt Động Đúng

### **Test Case 1: Switch Tab**

1. **Mở app:**
   ```
   🚀 [RootShell] initState - Initial tab: 0
   🚀 [HomeScreen] initState - wantKeepAlive: true
   🏗️ [RootShell] build - Current tab: 0
   🏗️ [HomeScreen] build - Scroll position: 0.0
   ```

2. **Scroll xuống:**
   ```
   📜 [HomeScreen] Scroll position: 500.0
   📜 [HomeScreen] Scroll position: 1000.0
   ```

3. **Switch sang tab "Danh mục":**
   ```
   🔄 [RootShell] Tab changed: 0 → 1
   🚀 [CategoryScreen] initState - wantKeepAlive: true  ← CHỈ GỌI 1 LẦN
   🏗️ [RootShell] build - Current tab: 1
   🏗️ [CategoryScreen] build
   ```
   - **✅ KHÔNG THẤY:** `🗑️ [HomeScreen] dispose` ← Đúng! Widget không bị dispose

4. **Switch lại tab "Trang chủ":**
   ```
   🔄 [RootShell] Tab changed: 1 → 0
   🏗️ [RootShell] build - Current tab: 0
   🏗️ [HomeScreen] build - Scroll position: 1000.0  ← Scroll position được giữ!
   ```
   - **✅ KHÔNG THẤY:** `🚀 [HomeScreen] initState` ← Đúng! Widget không bị recreate
   - **✅ THẤY:** Scroll position vẫn là 1000.0 ← PageStorage đã restore!

---

## ❌ Kịch Bản Hoạt Động Sai

### **Test Case 2: Widget Bị Dispose Khi Switch Tab**

1. **Switch tab:**
   ```
   🔄 [RootShell] Tab changed: 0 → 1
   🗑️ [HomeScreen] dispose called!  ← ❌ SAI! Widget không nên bị dispose
   🚀 [CategoryScreen] initState
   ```

2. **Switch lại:**
   ```
   🔄 [RootShell] Tab changed: 1 → 0
   🚀 [HomeScreen] initState  ← ❌ SAI! Widget bị recreate
   🏗️ [HomeScreen] build - Scroll position: 0.0  ← ❌ SAI! Scroll position bị mất
   ```

**🔴 Nguyên nhân:** IndexedStack không hoạt động đúng, có thể do:
- Widget key không đúng
- AutomaticKeepAliveClientMixin không được implement đúng
- Có code nào đó force dispose widget

---

## 🔍 Cách Debug

### **1. Kiểm tra IndexedStack hoạt động đúng:**

**✅ Đúng:**
- `initState` chỉ được gọi **1 lần** cho mỗi tab khi app khởi động
- `dispose` **KHÔNG** được gọi khi switch tab
- `build` được gọi mỗi lần switch tab (nhưng widget không bị recreate)

**❌ Sai:**
- `initState` được gọi nhiều lần khi switch tab
- `dispose` được gọi khi switch tab
- Scroll position bị mất khi switch tab

### **2. Kiểm tra PageStorage hoạt động đúng:**

**✅ Đúng:**
- Scroll position được giữ nguyên khi switch tab
- Scroll position được restore khi quay lại tab

**❌ Sai:**
- Scroll position bị reset về 0 khi switch tab
- Scroll position không được restore

### **3. Kiểm tra AutomaticKeepAliveClientMixin:**

**✅ Đúng:**
- `wantKeepAlive: true` trong logs
- Widget không bị dispose khi scroll ra khỏi viewport

**❌ Sai:**
- `wantKeepAlive: false` hoặc không thấy log này
- Widget bị dispose khi không visible

---

## 📊 Checklist Debug

Khi test, kiểm tra:

- [ ] `initState` chỉ được gọi **1 lần** cho mỗi tab
- [ ] `dispose` **KHÔNG** được gọi khi switch tab
- [ ] Scroll position được **giữ nguyên** khi switch tab
- [ ] `wantKeepAlive: true` trong tất cả logs
- [ ] `IndexedStack: keeping all X tabs alive` trong RootShell build

---

## 🎯 Kết Luận

**Nếu thấy logs đúng:**
- ✅ IndexedStack hoạt động đúng
- ✅ AutomaticKeepAliveClientMixin hoạt động đúng
- ✅ PageStorage hoạt động đúng
- ✅ App state preservation hoạt động như mong đợi!

**Nếu thấy logs sai:**
- ❌ Cần kiểm tra lại code
- ❌ Có thể có vấn đề với widget keys
- ❌ Có thể có code force dispose widget

---

## 📝 Ghi Chú

- Logs được format với emoji để dễ đọc
- Scroll position logs chỉ hiển thị mỗi 500px để tránh spam
- Tất cả logs đều có prefix `[ComponentName]` để dễ filter
