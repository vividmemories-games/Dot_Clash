#!/usr/bin/env bash
# Copies the correct GoogleService-Info.plist into the app bundle for the
# active flavor.  This script is called from an Xcode "Run Script" Build Phase
# (see SETUP.md § "iOS — GoogleService-Info.plist copy script").
#
# FLUTTER_FLAVOR is set by the Debug-dev / Release-dev xcconfig files.
# When the variable is absent the script defaults to "prod".
set -euo pipefail

FLAVOR="${FLUTTER_FLAVOR:-prod}"
SRC="${SRCROOT}/config/${FLAVOR}/GoogleService-Info.plist"
DEST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"

if [ ! -f "$SRC" ]; then
  echo "error: GoogleService-Info.plist not found for flavor '${FLAVOR}' at ${SRC}"
  exit 1
fi

cp "$SRC" "$DEST"
echo "Copied ${SRC} → ${DEST}"

"$(dirname "$0")/inject_app_check_debug_token.sh"
