#!/usr/bin/env bash
# Creates android/upload-keystore.jks (gitignored). Run once, then copy key.properties.example → key.properties.
set -euo pipefail
cd "$(dirname "$0")/.."
KEYSTORE="upload-keystore.jks"
if [[ -f "$KEYSTORE" ]]; then
  echo "Keystore already exists: android/$KEYSTORE"
  exit 1
fi
echo "Creating upload keystore (alias: upload). You will be prompted for passwords — save them securely."
keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Dot Clash, OU=Mobile, O=Vivid Memories"
echo ""
echo "Next: cp android/key.properties.example android/key.properties"
echo "      Edit android/key.properties with your store/key passwords."
