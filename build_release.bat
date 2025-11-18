@echo off
REM Script build AAB cho Google Play Store
REM Chạy script này để build file AAB cần thiết cho việc publish lên Play Store

echo ========================================
echo BUILD APP BUNDLE (AAB) CHO PLAY STORE
echo ========================================
echo.

REM Kiểm tra keystore.properties
if not exist "android\keystore.properties" (
    echo [LỖI] File android\keystore.properties không tồn tại!
    echo.
    echo Hãy làm theo các bước sau:
    echo 1. Copy file android\keystore.properties.example thành android\keystore.properties
    echo 2. Điền thông tin keystore vào file keystore.properties
    echo 3. Chạy lại script này
    echo.
    pause
    exit /b 1
)

REM Kiểm tra keystore file
set KEYSTORE_FILE=android\app\upload-keystore.jks
if not exist "%KEYSTORE_FILE%" (
    echo [LỖI] File keystore không tồn tại: %KEYSTORE_FILE%
    echo.
    echo Hãy tạo keystore trước:
    echo 1. Chạy: android\create_keystore.bat
    echo 2. Sau đó chạy lại script này
    echo.
    pause
    exit /b 1
)

echo [OK] Đã tìm thấy keystore.properties
echo [OK] Đã tìm thấy keystore file
echo.

REM Hiển thị thông tin version
echo ========================================
echo THÔNG TIN VERSION
echo ========================================
for /f "tokens=2" %%a in ('findstr /r /c:"^version:" pubspec.yaml') do set VERSION=%%a
echo Version hiện tại: %VERSION%
echo.
echo LƯU Ý: Nếu cần thay đổi version, hãy sửa file pubspec.yaml
echo Format: version: X.Y.Z+BUILD_NUMBER
echo   - X.Y.Z là version name (hiển thị cho người dùng)
echo   - BUILD_NUMBER là version code (phải tăng mỗi lần upload)
echo.
pause
echo.

REM Clean build trước
echo Đang clean build cũ...
call flutter clean
echo.

REM Get dependencies
echo Đang lấy dependencies...
call flutter pub get
echo.

REM Build AAB
echo ========================================
echo Đang build App Bundle (AAB)...
echo ========================================
echo.

call flutter build appbundle --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo BUILD THÀNH CÔNG!
    echo ========================================
    echo.
    echo File AAB đã được tạo tại:
    echo build\app\outputs\bundle\release\app-release.aab
    echo.
    echo BƯỚC TIẾP THEO:
    echo 1. Đăng nhập Google Play Console: https://play.google.com/console
    echo 2. Tạo app mới (nếu chưa có)
    echo 3. Vào Production ^> Create new release
    echo 4. Upload file app-release.aab
    echo 5. Điền release notes và publish
    echo.
    echo Xem hướng dẫn chi tiết trong file: HUONG_DAN_PUBLISH_PLAY_STORE.md
    echo.
) else (
    echo.
    echo ========================================
    echo BUILD THẤT BẠI!
    echo ========================================
    echo Vui lòng kiểm tra lỗi ở trên và thử lại.
    echo.
)

pause

