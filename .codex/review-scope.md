# Codex Review Scope Guide

Use Codex only for bigger changes.

## Run Codex review when any of these are true
- More than 5 files changed.
- Auth/Firebase/Firestore rules changed.
- IAP/AdMob/UMP/ATT changed.
- Build/signing/flavors changed.
- Game engine/scoring/progression changed.
- Persistence/save-game logic changed.
- Before TestFlight upload.
- Before Play Console AAB upload.
- Before merging a large Cursor-generated change.

## Do not run Codex review for
- Simple text changes.
- Small spacing/layout changes.
- One-off asset/icon replacements.
- Comments-only edits.
- Minor README changes.

## Workflow rule
Cursor builds. Codex reviews once. You approve. Cursor fixes selected items.
