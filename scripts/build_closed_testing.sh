#!/usr/bin/env bash
# Prod store builds with Google test ads — safe for Play/TestFlight closed testing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v fvm >/dev/null 2>&1 && [ -f "$ROOT/.fvmrc" ]; then
  FLUTTER=(fvm flutter)
else
  FLUTTER=(flutter)
fi

DART_DEFINES=(--dart-define=FLAVOR=prod --dart-define=BETA_ADS=true)
GRADLE_BETA=(--android-project-arg=betaAds=true)

cleanup() {
  "$ROOT/scripts/set_beta_ads_native.sh" off
}
trap cleanup EXIT

"$ROOT/scripts/set_beta_ads_native.sh" on

TARGET="${1:-all}"

build_android() {
  "${FLUTTER[@]}" build appbundle \
    --flavor prod \
    "${DART_DEFINES[@]}" \
    --release \
    "${GRADLE_BETA[@]}"
  echo "Android AAB: build/app/outputs/bundle/prodRelease/app-prod-release.aab"
}

build_ios() {
  "${FLUTTER[@]}" build ipa --flavor prod "${DART_DEFINES[@]}" --release
  echo "iOS IPA: build/ios/ipa/*.ipa"
}

case "$TARGET" in
  android) build_android ;;
  ios) build_ios ;;
  all)
    build_android
    build_ios
    ;;
  *)
    echo "Usage: $0 [android|ios|all]" >&2
    exit 1
    ;;
esac

echo "Closed-testing build complete (test ads). For public launch, use prod commands without BETA_ADS."
