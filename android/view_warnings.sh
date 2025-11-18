#!/bin/bash
# Script để xem chi tiết Java compilation warnings

echo "🔍 Xem chi tiết Java Compilation Warnings..."
echo ""

cd "$(dirname "$0")"

echo "📋 1. Xem tất cả warnings (deprecated + unchecked):"
./gradlew app:compileDebugJavaWithJavac --warning-mode all 2>&1 | grep -A 5 -B 5 "deprecated\|unchecked\|Note:"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 2. Xem chi tiết DEPRECATED warnings:"
./gradlew app:compileDebugJavaWithJavac -Xlint:deprecation 2>&1 | grep -A 10 "deprecated"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 3. Xem chi tiết UNCHECKED warnings:"
./gradlew app:compileDebugJavaWithJavac -Xlint:unchecked 2>&1 | grep -A 10 "unchecked"

echo ""
echo "✅ Hoàn thành!"

