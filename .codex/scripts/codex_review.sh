#!/usr/bin/env bash
set -euo pipefail

# One-shot read-only Codex review for Dot Clash.
# Default scope: unstaged + staged working-tree diff.
# Usage:
#   ./scripts/codex_review.sh
#   ./scripts/codex_review.sh --base main
#   ./scripts/codex_review.sh --staged

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${ROOT}" ]]; then
  echo "ERROR: Run this from inside a Git repository."
  exit 1
fi

cd "$ROOT"

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI not found. Install it first:"
  echo "  curl -fsSL https://chatgpt.com/codex/install.sh | sh"
  exit 1
fi

SCOPE="working-tree"
BASE_BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE_BRANCH="${2:-}"
      if [[ -z "$BASE_BRANCH" ]]; then
        echo "ERROR: --base requires a branch name, for example: --base main"
        exit 1
      fi
      SCOPE="branch:${BASE_BRANCH}"
      shift 2
      ;;
    --staged)
      SCOPE="staged"
      shift
      ;;
    -h|--help)
      echo "Usage: ./scripts/codex_review.sh [--base main] [--staged]"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1"
      echo "Usage: ./scripts/codex_review.sh [--base main] [--staged]"
      exit 1
      ;;
  esac
done

mkdir -p .codex/reviews .codex/tmp
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUT_FILE=".codex/reviews/codex-review-${TIMESTAMP}.md"
PROMPT_FILE=".codex/tmp/codex-review-prompt-${TIMESTAMP}.md"

if [[ "$SCOPE" == "working-tree" ]]; then
  if git diff --quiet && git diff --cached --quiet; then
    echo "No staged or unstaged changes found. Nothing to review."
    exit 0
  fi
  DIFF_COMMANDS=$(cat <<'CMDS'
- `git diff --stat`
- `git diff --cached --stat`
- `git diff`
- `git diff --cached`
CMDS
)
elif [[ "$SCOPE" == "staged" ]]; then
  if git diff --cached --quiet; then
    echo "No staged changes found. Nothing to review."
    exit 0
  fi
  DIFF_COMMANDS=$(cat <<'CMDS'
- `git diff --cached --stat`
- `git diff --cached`
CMDS
)
else
  if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
    echo "ERROR: Base branch/ref not found: $BASE_BRANCH"
    exit 1
  fi
  if git diff --quiet "$BASE_BRANCH"...HEAD; then
    echo "No diff found against $BASE_BRANCH. Nothing to review."
    exit 0
  fi
  DIFF_COMMANDS="- \`git diff --stat ${BASE_BRANCH}...HEAD\`
- \`git diff ${BASE_BRANCH}...HEAD\`"
fi

cat > "$PROMPT_FILE" <<EOF_PROMPT
$(cat .codex/review-dot-clash.md)

## Requested review scope
Scope: ${SCOPE}

Review only this scope. Do not review unrelated files except when directly needed to understand the diff.

## Commands you may run to inspect the diff
${DIFF_COMMANDS}

## Extra hard instruction
This is a review-only run. Do not modify files. Do not create patches. Do not start a loop. Provide final review only.
EOF_PROMPT

echo "Running one-shot Codex review..."
echo "Scope: ${SCOPE}"
echo "Output: ${OUT_FILE}"

codex exec \
  --cd "$ROOT" \
  --sandbox read-only \
  --ask-for-approval never \
  --output-last-message "$OUT_FILE" \
  - < "$PROMPT_FILE"

echo ""
echo "Codex review saved to: ${OUT_FILE}"
