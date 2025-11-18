@echo off
REM Script tạo keystore cho Android app
REM Chạy script này để tạo keystore file cần thiết cho việc publish lên Google Play Store

echo ========================================
echo TẠO KEYSTORE CHO ANDROID APP
echo ========================================
echo.

cd /d %~dp0app

echo Đang tạo keystore file...
echo.
echo LƯU Ý QUAN TRỌNG:
echo - Bạn sẽ được yêu cầu nhập thông tin
echo - Mật khẩu keystore và key phải GIỐNG NHAU (theo yêu cầu của Google Play)
echo - Lưu giữ thông tin này CẨN THẬN - nếu mất sẽ KHÔNG THỂ update app lên Play Store
echo - Keystore file sẽ được tạo tại: android/app/upload-keystore.jks
echo.

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo TẠO KEYSTORE THÀNH CÔNG!
    echo ========================================
    echo.
    echo BƯỚC TIẾP THEO:
    echo 1. Copy file android/keystore.properties.example thành android/keystore.properties
    echo 2. Mở android/keystore.properties và điền thông tin:
    echo    - storePassword: Mật khẩu bạn vừa nhập
    echo    - keyPassword: Mật khẩu bạn vừa nhập (giống storePassword)
    echo    - keyAlias: upload
    echo    - storeFile: app/upload-keystore.jks
    echo 3. Lưu file và chạy: flutter build appbundle
    echo.
) else (
    echo.
    echo ========================================
    echo CÓ LỖI XẢY RA!
    echo ========================================
    echo Vui lòng kiểm tra lại và thử lại.
    echo.
)

pause

