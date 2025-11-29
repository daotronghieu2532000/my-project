#!/bin/bash
# Script để lấy SHA256 fingerprint từ keystore

echo "🔍 Getting SHA256 Fingerprint from Keystore"
echo ""

# Check if keystore path is provided
if [ -z "$1" ]; then
    echo "📋 Usage:"
    echo "  For debug keystore (Windows):"
    echo "    ./get_sha256_fingerprint.sh debug"
    echo ""
    echo "  For debug keystore (Mac/Linux):"
    echo "    ./get_sha256_fingerprint.sh debug"
    echo ""
    echo "  For release keystore:"
    echo "    ./get_sha256_fingerprint.sh <path-to-keystore> <alias>"
    echo ""
    
    # Try to get debug keystore automatically
    if [ -f ~/.android/debug.keystore ] || [ -f "$USERPROFILE/.android/debug.keystore" ]; then
        echo "🔍 Auto-detecting debug keystore..."
        echo ""
        
        if [ -f ~/.android/debug.keystore ]; then
            KEYSTORE_PATH=~/.android/debug.keystore
        else
            KEYSTORE_PATH="$USERPROFILE/.android/debug.keystore"
        fi
        
        echo "📦 Keystore: $KEYSTORE_PATH"
        echo ""
        
        keytool -list -v -keystore "$KEYSTORE_PATH" -alias androiddebugkey -storepass android -keypass android | grep -A 5 "SHA256"
        
        echo ""
        echo "✅ Copy the SHA256 fingerprint above (without colons)"
    fi
    exit 1
fi

if [ "$1" = "debug" ]; then
    # Debug keystore
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        KEYSTORE_PATH="$USERPROFILE/.android/debug.keystore"
    else
        KEYSTORE_PATH=~/.android/debug.keystore
    fi
    
    if [ ! -f "$KEYSTORE_PATH" ]; then
        echo "❌ Debug keystore not found at: $KEYSTORE_PATH"
        exit 1
    fi
    
    echo "📦 Debug Keystore: $KEYSTORE_PATH"
    echo ""
    
    keytool -list -v -keystore "$KEYSTORE_PATH" -alias androiddebugkey -storepass android -keypass android | grep -A 5 "SHA256"
    
    echo ""
    echo "✅ Copy the SHA256 fingerprint above (without colons)"
else
    # Release keystore
    KEYSTORE_PATH="$1"
    ALIAS="${2:-release}"
    
    if [ ! -f "$KEYSTORE_PATH" ]; then
        echo "❌ Keystore not found at: $KEYSTORE_PATH"
        exit 1
    fi
    
    echo "📦 Release Keystore: $KEYSTORE_PATH"
    echo "🔑 Alias: $ALIAS"
    echo ""
    
    read -sp "Enter keystore password: " STORE_PASS
    echo ""
    read -sp "Enter key password (press Enter if same): " KEY_PASS
    echo ""
    
    if [ -z "$KEY_PASS" ]; then
        KEY_PASS="$STORE_PASS"
    fi
    
    keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$ALIAS" -storepass "$STORE_PASS" -keypass "$KEY_PASS" | grep -A 5 "SHA256"
    
    echo ""
    echo "✅ Copy the SHA256 fingerprint above (without colons)"
fi

