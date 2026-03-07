#!/bin/bash

# Coopvest Africa - SHA Fingerprint Setup Script
# Run this script to generate SHA fingerprints and update configuration

set -e

echo "========================================"
echo "Coopvest Africa - SHA Fingerprint Setup"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for keytool
if ! command_exists keytool; then
    echo -e "${RED}Error: keytool not found.${NC}"
    echo "Please install JDK and add it to your PATH."
    echo "On macOS: brew install openjdk"
    echo "On Ubuntu/Debian: sudo apt-get install openjdk-17-jdk"
    exit 1
fi

# Generate debug keystore if it doesn't exist
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"
if [ ! -f "$DEBUG_KEYSTORE" ]; then
    echo -e "${YELLOW}Generating debug keystore...${NC}"
    mkdir -p "$HOME/.android"
    keytool -genkeypair -v \
        -keystore "$DEBUG_KEYSTORE" \
        -alias androiddebugkey \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass android \
        -keypass android \
        -dname "CN=Android Debug,O=Android,C=US" \
        -deststoretype pkcs12
    echo -e "${GREEN}Debug keystore created successfully!${NC}"
fi

# Generate SHA-1 fingerprint
echo ""
echo "Generating SHA-1 fingerprints..."
echo "========================================"

# Debug SHA-1
echo ""
echo -e "${YELLOW}DEBUG SHA-1 Fingerprint:${NC}"
DEBUG_SHA1=$(keytool -list -v \
    -keystore "$DEBUG_KEYSTORE" \
    -alias androiddebugkey \
    -storepass android \
    -keypass android 2>/dev/null | grep "SHA1:" | head -1)

if [ -n "$DEBUG_SHA1" ]; then
    echo "$DEBUG_SHA1"
    DEBUG_HASH=$(echo "$DEBUG_SHA1" | sed 's/SHA1: //')
else
    echo -e "${RED}Could not generate debug SHA-1${NC}"
fi

# Release keystore path
echo ""
echo "========================================"
echo -e "${YELLOW}RELEASE SHA-1 Fingerprint:${NC}"
echo "Please enter the path to your release keystore:"
read -r RELEASE_KEYSTORE

if [ -z "$RELEASE_KEYSTORE" ]; then
    echo -e "${YELLOW}Skipping release fingerprint generation.${NC}"
    echo "You can generate it later using:"
    echo "keytool -list -v -keystore /path/to/your-keystore.jks -alias your-alias"
else
    if [ ! -f "$RELEASE_KEYSTORE" ]; then
        echo -e "${RED}Error: Keystore file not found: $RELEASE_KEYSTORE${NC}"
    else
        echo "Enter keystore password:"
        read -rs RELEASE_STORE_PASSWORD
        echo ""
        echo "Enter key alias:"
        read -r RELEASE_KEY_ALIAS
        echo ""
        echo "Enter key password:"
        read -rs RELEASE_KEY_PASSWORD
        echo ""

        RELEASE_SHA1=$(keytool -list -v \
            -keystore "$RELEASE_KEYSTORE" \
            -alias "$RELEASE_KEY_ALIAS" \
            -storepass "$RELEASE_STORE_PASSWORD" \
            -keypass "$RELEASE_KEY_PASSWORD" 2>/dev/null | grep "SHA1:" | head -1)

        if [ -n "$RELEASE_SHA1" ]; then
            echo "$RELEASE_SHA1"
            RELEASE_HASH=$(echo "$RELEASE_SHA1" | sed 's/SHA1: //')
        else
            echo -e "${RED}Could not generate release SHA-1${NC}"
        fi
    fi
fi

# Generate Google services JSON update
echo ""
echo "========================================"
echo -e "${GREEN}Update google-services.json with:${NC}"
echo ""
echo "Add the following to oauth_client array:"
echo '{
  "client_id": "1040576298736.apps.googleusercontent.com",
  "client_type": 1,
  "android_info": {
    "package_name": "com.coopvestafrica.app",
    "certificate_hash": "'$DEBUG_HASH'"
  }
}'
if [ -n "$RELEASE_HASH" ]; then
echo '
,{
  "client_id": "1040576298736.apps.googleusercontent.com",
  "client_type": 1,
  "android_info": {
    "package_name": "com.coopvestafrica.app",
    "certificate_hash": "'$RELEASE_HASH'"
  }
}'
fi

echo ""
echo "========================================"
echo -e "${GREEN}Next Steps:${NC}"
echo ""
echo "1. Go to Firebase Console: https://console.firebase.google.com/"
echo "2. Select project: coopvest-africa-46a86"
echo "3. Go to Project Settings > Your apps > Android app"
echo "4. Add SHA certificate fingerprints"
echo "5. Download new google-services.json"
echo "6. Replace: android/app/google-services.json"
echo ""

echo "========================================"
echo -e "${GREEN}Setup complete!${NC}"
echo ""
