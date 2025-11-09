# 🔧 HƯỚNG DẪN CÀI ĐẶT JDK CHO WINDOWS

## Mục đích
Cài đặt JDK (Java Development Kit) để có thể sử dụng lệnh `keytool` tạo keystore cho Android app.

---

## 📍 BƯỚC 1: CÀI ĐẶT JDK

### 🔹 Bước 1.1: Tìm file JDK đã tải

1. Mở **File Explorer** (nhấn `Windows + E`)
2. Vào thư mục **Downloads** (hoặc thư mục bạn đã lưu file)
3. Tìm file: `jdk-25_windows-x64_bin.exe`

### 🔹 Bước 1.2: Chạy file cài đặt

1. **Double-click** vào file `jdk-25_windows-x64_bin.exe`
2. Nếu Windows hỏi "Do you want to allow this app to make changes?", click **"Yes"**
3. Cửa sổ cài đặt JDK sẽ hiện ra

### 🔹 Bước 1.3: Cài đặt JDK

1. **Welcome screen**: Click **"Next"** (Tiếp theo)

2. **Custom Setup**:
   - Xem đường dẫn cài đặt (thường là `C:\Program Files\Java\jdk-25`)
   - ⚠️ **LƯU LẠI ĐƯỜNG DẪN NÀY** (sẽ cần dùng sau)
   - Click **"Next"**

3. **Progress**: Đợi cài đặt hoàn thành (có thể mất 2-5 phút)

4. **Complete**: Click **"Close"** để hoàn tất

---

## 📍 BƯỚC 2: CẤU HÌNH PATH (QUAN TRỌNG!)

Sau khi cài đặt JDK, bạn cần thêm JDK vào PATH để Windows có thể tìm thấy lệnh `keytool`.

### 🔹 Cách 1: Tự động thêm vào PATH (Khuyến nghị - Dễ nhất)

**Bước 2.1: Mở System Properties**

1. Nhấn phím `Windows + R`
2. Gõ: `sysdm.cpl`
3. Nhấn Enter
4. Cửa sổ **System Properties** sẽ hiện ra

**Bước 2.2: Mở Environment Variables**

1. Trong cửa sổ **System Properties**, click tab **"Advanced"**
2. Click nút **"Environment Variables..."** (ở cuối cửa sổ)
3. Cửa sổ **Environment Variables** sẽ hiện ra

**Bước 2.3: Tìm biến PATH**

1. Trong phần **"System variables"** (phần dưới), tìm và click vào biến **"Path"**
2. Click nút **"Edit..."**

**Bước 2.4: Thêm JDK vào PATH**

1. Click nút **"New"** (Mới)
2. Gõ đường dẫn đến thư mục `bin` của JDK:
   ```
   C:\Program Files\Java\jdk-25\bin
   ```
   ⚠️ **LƯU Ý**: 
   - Nếu bạn cài JDK ở đường dẫn khác, thay `C:\Program Files\Java\jdk-25\bin` bằng đường dẫn thực tế
   - Đường dẫn phải trỏ đến thư mục `bin` (có chứa file `keytool.exe`)
3. Click **"OK"** để lưu
4. Click **"OK"** ở cửa sổ **Environment Variables**
5. Click **"OK"** ở cửa sổ **System Properties**

**Bước 2.5: Đóng và mở lại Command Prompt**

⚠️ **QUAN TRỌNG**: Bạn PHẢI đóng TẤT CẢ cửa sổ Command Prompt/PowerShell và mở lại để PATH có hiệu lực!

1. Đóng TẤT CẢ cửa sổ Command Prompt/PowerShell đang mở
2. Mở Command Prompt mới (nhấn `Windows + R`, gõ `cmd`, nhấn Enter)

---

### 🔹 Cách 2: Kiểm tra đường dẫn JDK (Nếu không chắc)

Nếu bạn không chắc JDK được cài ở đâu, làm theo các bước sau:

**Bước 2.1: Tìm thư mục JDK**

1. Mở **File Explorer**
2. Vào `C:\Program Files\Java\`
3. Tìm thư mục có tên như `jdk-25` hoặc `jdk-25.0.1` (tùy version)
4. Vào trong thư mục đó, tìm thư mục `bin`
5. Trong thư mục `bin`, tìm file `keytool.exe`
6. Nếu tìm thấy → Đây là đường dẫn đúng!

**Ví dụ đường dẫn đúng:**
```
C:\Program Files\Java\jdk-25\bin\keytool.exe
```

**Đường dẫn cần thêm vào PATH:**
```
C:\Program Files\Java\jdk-25\bin
```

---

## 📍 BƯỚC 3: KIỂM TRA CÀI ĐẶT THÀNH CÔNG

Sau khi cấu hình PATH xong, bạn cần kiểm tra xem `keytool` đã hoạt động chưa.

### 🔹 Bước 3.1: Mở Command Prompt mới

⚠️ **QUAN TRỌNG**: Phải mở Command Prompt MỚI (không dùng cửa sổ cũ)!

1. Nhấn `Windows + R`
2. Gõ `cmd`
3. Nhấn Enter

### 🔹 Bước 3.2: Kiểm tra keytool

Trong cửa sổ Command Prompt, gõ:
```bash
keytool -version
```

Nhấn Enter.

**Kết quả mong đợi (Thành công ✅):**
```
keytool version "25" (hoặc version khác)
Java(TM) SE Runtime Environment version 25
Java HotSpot(TM) 64-Bit Server VM version 25
```

**Nếu vẫn báo lỗi (Thất bại ❌):**
```
'keytool' is not recognized as an internal or external command,
operable program or batch file.
```

→ Xem lại Bước 2, đảm bảo:
- Đã thêm đúng đường dẫn vào PATH
- Đã đóng và mở lại Command Prompt
- Đường dẫn trỏ đến thư mục `bin` (có chứa `keytool.exe`)

---

## 📍 BƯỚC 4: CHẠY LẠI SCRIPT TẠO KEYSTORE

Sau khi kiểm tra `keytool` hoạt động, bạn có thể chạy lại script tạo keystore.

### 🔹 Bước 4.1: Mở Command Prompt mới

1. Nhấn `Windows + R`
2. Gõ `cmd`
3. Nhấn Enter

### 🔹 Bước 4.2: Di chuyển vào thư mục dự án

```bash
cd C:\laragon\www\socdo_mobile\android
```

Nhấn Enter.

### 🔹 Bước 4.3: Chạy script tạo keystore

```bash
create_keystore.bat
```

Nhấn Enter. Script sẽ chạy và yêu cầu bạn nhập thông tin.

---

## 🆘 XỬ LÝ LỖI THƯỜNG GẶP

### ❌ Lỗi: "keytool is not recognized" sau khi cài đặt

**Nguyên nhân**: 
- Chưa thêm JDK vào PATH
- Chưa đóng và mở lại Command Prompt
- Đường dẫn PATH sai

**Cách sửa**:
1. Kiểm tra lại Bước 2 (Cấu hình PATH)
2. Đảm bảo đã đóng TẤT CẢ Command Prompt và mở lại
3. Kiểm tra đường dẫn trong PATH có đúng không:
   - Phải trỏ đến thư mục `bin` (ví dụ: `C:\Program Files\Java\jdk-25\bin`)
   - Không phải thư mục gốc JDK (ví dụ: KHÔNG phải `C:\Program Files\Java\jdk-25`)

### ❌ Lỗi: "The system cannot find the path specified"

**Nguyên nhân**: Đường dẫn JDK trong PATH không đúng hoặc JDK chưa được cài đặt

**Cách sửa**:
1. Kiểm tra JDK có được cài đặt không:
   - Mở File Explorer
   - Vào `C:\Program Files\Java\`
   - Xem có thư mục JDK không
2. Nếu không có → Cài đặt lại JDK (Bước 1)
3. Nếu có → Kiểm tra lại đường dẫn trong PATH (Bước 2)

### ❌ Lỗi: "Access is denied" khi cài đặt JDK

**Nguyên nhân**: Không có quyền Administrator

**Cách sửa**:
1. Click chuột phải vào file `jdk-25_windows-x64_bin.exe`
2. Chọn **"Run as administrator"**
3. Làm lại Bước 1

---

## ✅ CHECKLIST

Sau khi hoàn thành, đảm bảo:

- [ ] JDK đã được cài đặt thành công
- [ ] Đã thêm JDK vào PATH
- [ ] Đã đóng và mở lại Command Prompt
- [ ] Lệnh `keytool -version` chạy thành công
- [ ] Script `create_keystore.bat` chạy được

---

## 📚 THÔNG TIN THÊM

- **JDK Version**: 25 (mới nhất)
- **Download**: https://download.oracle.com/java/25/latest/
- **Đường dẫn mặc định**: `C:\Program Files\Java\jdk-25\`
- **File keytool**: `C:\Program Files\Java\jdk-25\bin\keytool.exe`

---

**Sau khi hoàn thành tất cả các bước, quay lại file `QUICK_START_PLAY_STORE.md` để tiếp tục tạo keystore!**

