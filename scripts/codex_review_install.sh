#!/usr/bin/env bash
set -euo pipefail

# Optional installer for Codex CLI on macOS/Linux.
# You can also install manually from OpenAI docs.

if command -v codex >/dev/null 2>&1; then
  echo "Codex CLI already installed: $(command -v codex)"
  codex --version || true
  exit 0
fi

echo "Installing Codex CLI..."
curl -fsSL https://chatgpt.com/codex/install.sh | sh

echo ""
echo "Now run:"
echo "  codex login"
echo "or simply:"
echo "  codex"
echo "and sign in when prompted."
