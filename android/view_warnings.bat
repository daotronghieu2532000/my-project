@echo off
REM Script để xem chi tiết Java compilation warnings (Windows)

echo 🔍 Xem chi tiết Java Compilation Warnings...
echo.

cd /d "%~dp0"

echo 📋 1. Xem tất cả warnings (deprecated + unchecked):
call gradlew.bat app:compileDebugJavaWithJavac --warning-mode all 2>&1 | findstr /C:"deprecated" /C:"unchecked" /C:"Note:"

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

echo 📋 2. Xem chi tiết DEPRECATED warnings:
call gradlew.bat app:compileDebugJavaWithJavac -Xlint:deprecation 2>&1 | findstr /C:"deprecated"

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

echo 📋 3. Xem chi tiết UNCHECKED warnings:
call gradlew.bat app:compileDebugJavaWithJavac -Xlint:unchecked 2>&1 | findstr /C:"unchecked"

echo.
echo ✅ Hoàn thành!
pause

