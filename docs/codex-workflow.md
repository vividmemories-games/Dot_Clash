# Dot Clash: Cursor + Codex One-Shot Review Workflow

This workflow keeps Cursor and Codex from recursively calling each other.

## Roles

- **Cursor**: builder/fixer.
- **Codex CLI**: one-time reviewer.
- **You**: approver.

## First-time setup

From the Dot Clash repo root:

```bash
chmod +x scripts/*.sh
./scripts/codex_review_install.sh
codex login
```

You can also start Codex once with:

```bash
codex
```

## Daily workflow

```bash
# 1. Let Cursor make the bigger feature/fix.

# 2. Run local checks.
./scripts/dotclash_checks.sh

# 3. Run one-shot Codex review on current staged + unstaged diff.
./scripts/codex_review.sh

# 4. Open the newest review file.
ls -t .codex/reviews/codex-review-*.md | head -1

# 5. Paste selected findings into Cursor using:
cat .codex/cursor-fix-prompt.md
```

## Review only staged changes

```bash
git add path/to/files
./scripts/codex_review.sh --staged
```

## Review a branch against main

```bash
./scripts/codex_review.sh --base main
```

## Anti-loop rule

Do not let Cursor call Codex automatically.
Do not let Codex apply fixes automatically.

Use this loop only:

```text
Cursor changes code
↓
You run checks
↓
Codex reviews once
↓
You choose findings
↓
Cursor fixes selected findings
↓
You run checks again
↓
Commit
```

## When to run Codex review

Run Codex review when:

- More than 5 files changed.
- Auth/Firebase/Firestore rules changed.
- IAP/AdMob/UMP/ATT changed.
- Build/signing/flavors changed.
- Game engine/scoring/progression changed.
- Persistence/save-game logic changed.
- Before TestFlight upload.
- Before Play Console AAB upload.

Skip it for tiny UI/text/asset changes.
