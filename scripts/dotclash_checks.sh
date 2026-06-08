#!/usr/bin/env bash
set -euo pipefail

# Local sanity checks before/after Codex review.
# Run from anywhere inside the repo:
#   ./scripts/dotclash_checks.sh

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${ROOT}" ]]; then
  echo "ERROR: Run this from inside a Git repository."
  exit 1
fi

cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter not found in PATH."
  exit 1
fi

echo "== Flutter version =="
flutter --version

echo ""
echo "== Pub get =="
flutter pub get

echo ""
echo "== Dart format check =="
dart format --set-exit-if-changed .

echo ""
echo "== Flutter analyze =="
echo "(Fails only on errors; warnings and info are still printed for future cleanup.)"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo ""
echo "== Flutter tests =="
flutter test

echo ""
echo "All local checks passed."
