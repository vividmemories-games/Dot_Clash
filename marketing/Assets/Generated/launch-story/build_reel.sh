#!/usr/bin/env bash
# Builds the 7-panel launch story Reel (9:16, 1080x1920).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/build_reel.py"
