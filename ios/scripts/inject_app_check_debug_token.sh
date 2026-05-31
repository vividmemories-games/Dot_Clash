#!/usr/bin/env bash
# Injects APP_CHECK_DEBUG_TOKEN from Flutter DART_DEFINES into the built app Info.plist
# so AppDelegate can set FIRAAppCheckDebugToken before Firebase App Check initializes.
set -euo pipefail

TOKEN=""
IFS=',' read -ra DEFINES <<< "${DART_DEFINES:-}"
for define in "${DEFINES[@]}"; do
  decoded="$(printf '%s' "$define" | base64 --decode 2>/dev/null || true)"
  if [[ "$decoded" == APP_CHECK_DEBUG_TOKEN=* ]]; then
    TOKEN="${decoded#APP_CHECK_DEBUG_TOKEN=}"
    break
  fi
done

if [[ -z "$TOKEN" ]]; then
  exit 0
fi

APP_PLIST="${BUILT_PRODUCTS_DIR:-}/${PRODUCT_NAME:-Runner}.app/Info.plist"
if [[ ! -f "$APP_PLIST" ]]; then
  echo "warning: App Check debug token not injected — Info.plist missing at ${APP_PLIST}"
  exit 0
fi

/usr/libexec/PlistBuddy -c "Delete :FIRAAppCheckDebugToken" "$APP_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :FIRAAppCheckDebugToken string ${TOKEN}" "$APP_PLIST"
echo "Injected FIRAAppCheckDebugToken into ${APP_PLIST}"
