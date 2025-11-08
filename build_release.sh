#!/bin/bash
# Script build AAB cho Google Play Store
# Chạy script này để build file AAB cần thiết cho việc publish lên Play Store

echo "========================================"
echo "BUILD APP BUNDLE (AAB) CHO PLAY STORE"
echo "========================================"
echo ""

# Kiểm tra keystore.properties
if [ ! -f "android/keystore.properties" ]; then
    echo "[LỖI] File android/keystore.properties không tồn tại!"
    echo ""
    echo "Hãy làm theo các bước sau:"
    echo "1. Copy file android/keystore.properties.example thành android/keystore.properties"
    echo "2. Điền thông tin keystore vào file keystore.properties"
    echo "3. Chạy lại script này"
    echo ""
    exit 1
fi

# Kiểm tra keystore file
KEYSTORE_FILE="android/app/upload-keystore.jks"
if [ ! -f "$KEYSTORE_FILE" ]; then
    echo "[LỖI] File keystore không tồn tại: $KEYSTORE_FILE"
    echo ""
    echo "Hãy tạo keystore trước:"
    echo "1. Chạy: android/create_keystore.sh"
    echo "2. Sau đó chạy lại script này"
    echo ""
    exit 1
fi

echo "[OK] Đã tìm thấy keystore.properties"
echo "[OK] Đã tìm thấy keystore file"
echo ""

# Clean build trước
echo "Đang clean build cũ..."
flutter clean
echo ""

# Get dependencies
echo "Đang lấy dependencies..."
flutter pub get
echo ""

# Build AAB
echo "========================================"
echo "Đang build App Bundle (AAB)..."
echo "========================================"
echo ""

flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "BUILD THÀNH CÔNG!"
    echo "========================================"
    echo ""
    echo "File AAB đã được tạo tại:"
    echo "build/app/outputs/bundle/release/app-release.aab"
    echo ""
    echo "BƯỚC TIẾP THEO:"
    echo "1. Đăng nhập Google Play Console: https://play.google.com/console"
    echo "2. Tạo app mới (nếu chưa có)"
    echo "3. Vào Production > Create new release"
    echo "4. Upload file app-release.aab"
    echo "5. Điền release notes và publish"
    echo ""
    echo "Xem hướng dẫn chi tiết trong file: HUONG_DAN_PUBLISH_PLAY_STORE.md"
    echo ""
else
    echo ""
    echo "========================================"
    echo "BUILD THẤT BẠI!"
    echo "========================================"
    echo "Vui lòng kiểm tra lỗi ở trên và thử lại."
    echo ""
    exit 1
fi

