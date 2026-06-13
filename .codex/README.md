# Dot Clash Codex Review Workflow Pack

Drop these files into your Dot Clash Flutter repo to use Codex CLI as a controlled one-shot reviewer for bigger Cursor changes.

## Files

```text
.codex/review-dot-clash.md       # Codex reviewer instructions
.codex/cursor-fix-prompt.md      # Prompt to paste into Cursor after review
.codex/review-scope.md           # When to run/skip reviews
scripts/codex_review.sh          # One-shot read-only Codex review
scripts/dotclash_checks.sh       # Flutter sanity checks
scripts/codex_review_install.sh  # Optional Codex CLI installer
_docs/codex-workflow.md          # Workflow guide
```

Note: The guide is stored as `docs/codex-workflow.md` when installed.

## Install into your repo

Copy this folder's contents into the root of your Dot Clash repo, then run:

```bash
chmod +x scripts/*.sh
```

## First-time Codex setup

```bash
./scripts/codex_review_install.sh
codex login
```

## Run checks

```bash
./scripts/dotclash_checks.sh
```

## Review current diff

```bash
./scripts/codex_review.sh
```

## Review staged diff only

```bash
git add path/to/files
./scripts/codex_review.sh --staged
```

## Review branch against main

```bash
./scripts/codex_review.sh --base main
```

## Review output

Reviews are saved here:

```text
.codex/reviews/codex-review-YYYYMMDD-HHMMSS.md
```

Paste selected findings into Cursor together with:

```text
.codex/cursor-fix-prompt.md
```
