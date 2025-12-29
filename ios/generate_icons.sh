#!/bin/bash

# Script để generate icon iOS từ icon Android
# Sử dụng: ./generate_icons.sh

set -e

# Đường dẫn
ANDROID_ICON="../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
IOS_ICON_DIR="Runner/Assets.xcassets/AppIcon.appiconset"

# Kiểm tra icon Android có tồn tại không
if [ ! -f "$ANDROID_ICON" ]; then
    echo "❌ Không tìm thấy icon Android: $ANDROID_ICON"
    exit 1
fi

echo "📱 Đang generate icon iOS từ icon Android..."

# Kiểm tra sips (macOS built-in tool)
if ! command -v sips &> /dev/null; then
    echo "❌ Không tìm thấy 'sips'. Vui lòng cài đặt ImageMagick hoặc sử dụng macOS."
    exit 1
fi

# Tạo thư mục tạm
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy icon Android vào thư mục tạm
cp "$ANDROID_ICON" "$TEMP_DIR/source.png"

# Generate các kích thước icon iOS
echo "🔄 Đang tạo các kích thước icon..."

# iPhone icons
sips -z 40 40 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-20x20@2x.png" > /dev/null 2>&1
sips -z 60 60 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-20x20@3x.png" > /dev/null 2>&1
sips -z 29 29 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-29x29@1x.png" > /dev/null 2>&1
sips -z 58 58 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-29x29@2x.png" > /dev/null 2>&1
sips -z 87 87 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-29x29@3x.png" > /dev/null 2>&1
sips -z 80 80 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-40x40@2x.png" > /dev/null 2>&1
sips -z 120 120 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-40x40@3x.png" > /dev/null 2>&1
sips -z 120 120 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-60x60@2x.png" > /dev/null 2>&1
sips -z 180 180 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-60x60@3x.png" > /dev/null 2>&1

# iPad icons
sips -z 20 20 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-20x20@1x.png" > /dev/null 2>&1
sips -z 40 40 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-20x20@2x-ipad.png" > /dev/null 2>&1
sips -z 76 76 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-76x76@1x.png" > /dev/null 2>&1
sips -z 152 152 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-76x76@2x.png" > /dev/null 2>&1
sips -z 167 167 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-83.5x83.5@2x.png" > /dev/null 2>&1

# App Store icon (1024x1024)
sips -z 1024 1024 "$TEMP_DIR/source.png" --out "$TEMP_DIR/Icon-App-1024x1024@1x.png" > /dev/null 2>&1

# Copy các icon vào thư mục iOS
echo "📦 Đang copy icon vào thư mục iOS..."

cp "$TEMP_DIR/Icon-App-20x20@2x.png" "$IOS_ICON_DIR/Icon-App-20x20@2x.png"
cp "$TEMP_DIR/Icon-App-20x20@3x.png" "$IOS_ICON_DIR/Icon-App-20x20@3x.png"
cp "$TEMP_DIR/Icon-App-29x29@1x.png" "$IOS_ICON_DIR/Icon-App-29x29@1x.png"
cp "$TEMP_DIR/Icon-App-29x29@2x.png" "$IOS_ICON_DIR/Icon-App-29x29@2x.png"
cp "$TEMP_DIR/Icon-App-29x29@3x.png" "$IOS_ICON_DIR/Icon-App-29x29@3x.png"
cp "$TEMP_DIR/Icon-App-40x40@2x.png" "$IOS_ICON_DIR/Icon-App-40x40@2x.png"
cp "$TEMP_DIR/Icon-App-40x40@3x.png" "$IOS_ICON_DIR/Icon-App-40x40@3x.png"
cp "$TEMP_DIR/Icon-App-60x60@2x.png" "$IOS_ICON_DIR/Icon-App-60x60@2x.png"
cp "$TEMP_DIR/Icon-App-60x60@3x.png" "$IOS_ICON_DIR/Icon-App-60x60@3x.png"
cp "$TEMP_DIR/Icon-App-20x20@1x.png" "$IOS_ICON_DIR/Icon-App-20x20@1x.png"
cp "$TEMP_DIR/Icon-App-76x76@1x.png" "$IOS_ICON_DIR/Icon-App-76x76@1x.png"
cp "$TEMP_DIR/Icon-App-76x76@2x.png" "$IOS_ICON_DIR/Icon-App-76x76@2x.png"
cp "$TEMP_DIR/Icon-App-83.5x83.5@2x.png" "$IOS_ICON_DIR/Icon-App-83.5x83.5@2x.png"
cp "$TEMP_DIR/Icon-App-1024x1024@1x.png" "$IOS_ICON_DIR/Icon-App-1024x1024@1x.png"

echo "✅ Đã generate xong tất cả icon iOS!"
echo "📝 Lưu ý: Bạn cần mở Xcode và refresh Assets.xcassets để thấy icon mới"

