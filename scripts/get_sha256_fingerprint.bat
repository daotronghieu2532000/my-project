@echo off
REM Script để lấy SHA256 fingerprint từ keystore (Windows)

echo 🔍 Getting SHA256 Fingerprint from Keystore
echo.

if "%1"=="" (
    echo 📋 Usage:
    echo   For debug keystore:
    echo     get_sha256_fingerprint.bat debug
    echo.
    echo   For release keystore:
    echo     get_sha256_fingerprint.bat ^<path-to-keystore^> ^<alias^>
    echo.
    
    REM Try to get debug keystore automatically
    if exist "%USERPROFILE%\.android\debug.keystore" (
        echo 🔍 Auto-detecting debug keystore...
        echo.
        echo 📦 Keystore: %USERPROFILE%\.android\debug.keystore
        echo.
        
        keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr SHA256
        
        echo.
        echo ✅ Copy the SHA256 fingerprint above (without colons)
    ) else (
        echo ❌ Debug keystore not found at: %USERPROFILE%\.android\debug.keystore
    )
    exit /b 1
)

if "%1"=="debug" (
    REM Debug keystore
    set KEYSTORE_PATH=%USERPROFILE%\.android\debug.keystore
    
    if not exist "%KEYSTORE_PATH%" (
        echo ❌ Debug keystore not found at: %KEYSTORE_PATH%
        exit /b 1
    )
    
    echo 📦 Debug Keystore: %KEYSTORE_PATH%
    echo.
    
    keytool -list -v -keystore "%KEYSTORE_PATH%" -alias androiddebugkey -storepass android -keypass android | findstr SHA256
    
    echo.
    echo ✅ Copy the SHA256 fingerprint above (without colons)
) else (
    REM Release keystore
    set KEYSTORE_PATH=%1
    set ALIAS=%2
    if "%ALIAS%"=="" set ALIAS=release
    
    if not exist "%KEYSTORE_PATH%" (
        echo ❌ Keystore not found at: %KEYSTORE_PATH%
        exit /b 1
    )
    
    echo 📦 Release Keystore: %KEYSTORE_PATH%
    echo 🔑 Alias: %ALIAS%
    echo.
    echo Enter keystore password when prompted
    echo.
    
    keytool -list -v -keystore "%KEYSTORE_PATH%" -alias %ALIAS%
    
    echo.
    echo ✅ Copy the SHA256 fingerprint above (without colons)
)

