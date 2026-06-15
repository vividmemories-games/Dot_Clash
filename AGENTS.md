# Dot Clash — Agent guide

Read this first. It routes you to code and docs — it does not replace them.

**Product:** Nostalgia-powered Dots and Boxes — Flutter mobile game (iOS/Android) with Firebase, AdMob, and IAP.

**Current build:** read [`pubspec.yaml`](pubspec.yaml). Ship by **build number** (`+N`), not “Release N”. Bump `+N` before every store upload.

**Intended invariants:** [`docs/DECISIONS.md`](docs/DECISIONS.md) · **System map:** [`docs/architecture.md`](docs/architecture.md) · **Doc index:** [`docs/README.md`](docs/README.md)

---

## Quick start

```bash
flutter run --flavor dev --dart-define=FLAVOR=dev

flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

Closed-testing builds: [`README.md`](README.md), [`docs/RELEASES.md`](docs/RELEASES.md). CI: `.github/workflows/dart.yml`.

---

## Repo map

| Path | Purpose |
|------|---------|
| [`lib/main.dart`](lib/main.dart) · [`lib/app.dart`](lib/app.dart) | Bootstrap |
| [`lib/core/router/app_router.dart`](lib/core/router/app_router.dart) | Routes |
| [`lib/features/game/`](lib/features/game/) | Local `GameRules`, `GameNotifier`, board |
| [`lib/features/challenge/`](lib/features/challenge/) | Live 1v1 Challenge |
| [`lib/features/campaign/`](lib/features/campaign/) | Map, levels, turn budgets |
| [`lib/services/backend/`](lib/services/backend/) | Callable wrapper |
| [`functions/src/`](functions/src/) | Challenge authority, economy, scheduler |
| [`test/`](test/) | Dart tests; rules parity with TS |

Game logic belongs in providers, domain, repositories, services, or Functions — **not widgets**. Details: [`docs/DECISIONS.md`](docs/DECISIONS.md) (G-2, G-3).

---

## Two game backends

| Mode | Authority | Sync |
|------|-----------|------|
| Campaign, Quick Match, Local, Daily | Client [`GameRules`](lib/features/game/domain/rules/game_rules.dart) | None |
| Challenge a Friend | Server [`game_rules.ts`](functions/src/game_rules.ts) + callables | Firestore `challenges/{code}` stream |

Do **not** mix Challenge live-sync into `gameProvider` — use `ChallengeGameNotifier` in [`lib/features/challenge/`](lib/features/challenge/).

---

## Challenge invariants

These must hold in every change touching Challenge:

1. **Host = player A, guest = player B** on the server. Clients map “you” via `GameConfig.myPlayerId`.
2. **Clients cannot write `challenges/{code}`** — reads only; all mutations via Cloud Functions (`firestore.rules`).
3. **`recordChallengeMatch` stays idempotent** — safe to call more than once per player per finished room.
4. **Server room outcome wins** — settlement follows Firestore room status (`finished` / `abandoned`, `room.winnerUid`), not optimistic local board state or `gameProvider.isOver`.
5. **Challenge v1 is history-only** — no coins, XP, lives, or rating from Challenge settlement.

See [`docs/DECISIONS.md`](docs/DECISIONS.md) (G-5–G-9, C-1, F-2) and [`docs/architecture.md`](docs/architecture.md) § Challenge.

---

## Environments

| Flavor | Firebase project | Use |
|--------|------------------|-----|
| `dev` | `dot-clash-dev` | Daily dev |
| `prod` | `dot-clash-72cc6` | Closed testing, store |

Closed testing on prod: `--dart-define=BETA_ADS=true` (see [`README.md`](README.md)). Never mix dev/prod config files.

### Deploy and release (reference only)

**Never deploy Firebase, upload store builds, or change external consoles (App Store Connect, Play Console, Firebase Console, Apple Developer) unless the user explicitly requests it.**

When the user *does* request a backend deploy:

```bash
cd functions && npm run build && npm run lint
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-dev   # dev
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-72cc6 # prod — explicit approval only
```

---

## Task routing

| Task | Read first |
|------|------------|
| Challenge (moves, lobby, rematch) | [`docs/architecture.md`](docs/architecture.md), [`lib/features/challenge/`](lib/features/challenge/), [`functions/src/challenge.ts`](functions/src/challenge.ts) |
| Campaign / lives / stars | [`lib/features/campaign/`](lib/features/campaign/), `functions/src/` settlement callables |
| Board / touch / painter | [`board_widget.dart`](lib/features/game/presentation/widgets/board_widget.dart) |
| Auth / profile | [`lib/features/auth/`](lib/features/auth/), [`lib/features/profile/`](lib/features/profile/) |
| Ads / IAP | [`lib/services/ads/`](lib/services/ads/), [`lib/services/iap/`](lib/services/iap/), [`SETUP.md`](SETUP.md) |
| Push / deep links | [`lib/services/push/`](lib/services/push/), [`lib/services/deep_links/`](lib/services/deep_links/) |
| Store upload / regression | [`docs/RELEASES.md`](docs/RELEASES.md), [`docs/LAUNCH.md`](docs/LAUNCH.md), [`README.md`](README.md) |
| Signing / keys / flavors | [`SETUP.md`](SETUP.md) |
| Security (App Check, rules) | [`SETUP.md`](SETUP.md) § App Check, [`firestore.rules`](firestore.rules), [`docs/architecture.md`](docs/architecture.md) |
| Why was it built this way? | [`docs/DECISIONS.md`](docs/DECISIONS.md) |
| Challenge history / QA log | [`docs/summary.md`](docs/summary.md) — archaeology, not sole source of truth |
| Large diff review | [`.codex/README.md`](.codex/README.md), [`docs/codex-workflow.md`](docs/codex-workflow.md) |

---

## Verification before “fixed” or “ship ready”

1. Inspect changed files; say **not inspected** for anything you did not open.
2. Run `flutter analyze` and `flutter test` (Functions `npm run build && npm run lint` if backend touched).
3. Label **MANUAL QA REQUIRED** for two-device Challenge, IAP, ads, push, store uploads.
4. Label **RELEASE BLOCKER** for TestFlight, Play Console, Firebase, auth, IAP, ads, or gameplay blockers.

Upload checklist: [`docs/RELEASES.md`](docs/RELEASES.md).

---

## Cursor IDE only

In Cursor, [`.cursor/rules/`](.cursor/rules/) is auto-loaded (reviewer format, board engine, monetization, etc.). Other agents: use [`docs/DECISIONS.md`](docs/DECISIONS.md) and [`docs/architecture.md`](docs/architecture.md) instead — do not assume Cursor rules apply.

---

## What not to do

- **Do not deploy, upload builds, or edit external consoles** unless explicitly requested.
- **Do not commit secrets** (keystore, `.p8`, service account JSON).
- **Do not edit legal pages here** — [vividmemories-games.github.io](https://github.com/vividmemories-games/vividmemories-games.github.io); sync URLs via [`lib/core/legal/legal_links.dart`](lib/core/legal/legal_links.dart).
- **Do not create git commits or PRs** unless the user explicitly asks.
- **Prefer minimal diffs**; match existing patterns.

### Code vs documentation

- **Code** describes current behavior.
- **[`docs/DECISIONS.md`](docs/DECISIONS.md)** describes intended invariants.
- If they conflict, **report the discrepancy and confirm intent with the user** before changing code or decisions. Do not “fix” docs to match a suspected regression.

---

## Keeping this brain current

Documentation is part of every relevant change:

- Update `AGENTS.md` when workflows, task routing, or safety rules change.
- Update `docs/DECISIONS.md` when an intended invariant changes deliberately.
- Update `docs/architecture.md` when system structure or data flow changes.
- Update `docs/RELEASES.md` for every store build.
- Do not update historical logs to describe new behavior.
- Check documentation accuracy before declaring meaningful work complete.

---

## Doc index

| Doc | When |
|-----|------|
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Intended invariants |
| [`docs/architecture.md`](docs/architecture.md) | Flows, Firebase map |
| [`docs/LAUNCH.md`](docs/LAUNCH.md) | Public launch runbook (gates, QA, rollout) |
| [`docs/RELEASES.md`](docs/RELEASES.md) | Build history, upload checklist |
| [`docs/summary.md`](docs/summary.md) | Challenge implementation log |
| [`docs/flutter_firebase_store_release_checklist.md`](docs/flutter_firebase_store_release_checklist.md) | Store release checklist |
| [`docs/codex-workflow.md`](docs/codex-workflow.md) | Codex one-shot review |
| [`SETUP.md`](SETUP.md) | Firebase, flavors, signing, IAP, App Check |
| [`README.md`](README.md) | Quick run, closed-testing scripts |
