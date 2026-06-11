# Challenge a Friend (R14) — Session Summary

**Date:** 2026-06-08 through 2026-06-11  
**Branch:** `one-to-one-challange`  
**Firebase project (dev):** `dot-clash-dev`  
**Canonical plan:** `.cursor/plans/challenge_a_friend.plan.md` (or `challenge_a_friend.plan.md` in Cursor plans)

---

## What this session covered

- **Phase 1 (backend)** — Cloud Functions, rules, indexes, scheduler
- **Phase 2 (Flutter module)** — lobby, join, share, entry on Home
- **Phase 3** — playable live 6×6 board via `GameScreen` + human `submitChallengeMove`
- **Phase 3.8+** — `recordChallengeMatch`, Profile challenge history, post-game fixes
- **Two-device QA** on iOS Simulator + Android Emulator (`dot-clash-dev`)

---

## Phase 1 — Backend ✅ Complete

### Implemented

| Area | Details |
|------|---------|
| **Dart serialization** | `disabledCells` added to `GameState.toJson` / `fromJson`; test in `test/game/game_state_serialization_test.dart` |
| **`functions/src/game_rules.ts`** | TypeScript port of `GameRules` + `GameState` (parity with `test/game/rules_test.dart`) |
| **`functions/src/challenge.ts`** | `createChallenge`, `joinChallenge`, `submitChallengeMove`, `abandonChallenge`, `recordChallengeMatch`; shared `commitChallengeMoveInTransaction` |
| **`functions/src/challenge_scheduler.ts`** | `processChallengeTimeouts` (every 1 min) — server turn timeout with transactional idempotency |
| **`functions/src/notifications.ts`** | `registerFcmToken`, FCM invite helper for `createChallenge({ targetUid })` |
| **`functions/src/index.ts`** | Exports all new callables + scheduler |
| **`firestore.rules`** | `challenges/{code}` — read for host/guest only; writes denied (functions only); `matches` allows optional `challengeCode` |
| **`firestore.indexes.json`** | Composite indexes for scheduler queries (`status` + `turnStartedAt`, `status` + `expiresAt`) |
| **`functions/.eslintrc.js`** | Added so `npm run lint` works |

### Deployed

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-dev
```

Later deploy (Phase 3.8+):

```bash
firebase deploy --only functions,firestore:rules -P dot-clash-dev
```

### Verification

- **Postman + Auth emulator:** create → join → host/guest moves → out-of-turn rejected → `abandonChallenge`
- **Sample doc:** `challenges/A502CK` (emulator) — fields validated (6×6, `disabledCells: []`, `version`, `winnerUid` on abandon)
- **Functions verify:** `cd functions && npm run build && npm run lint`

### Git

- Commit `81b9589` — phase 1 functions
- Follow-up commit — `firestore.rules`, `firestore.indexes.json`, `game_state.dart`, serialization test
- **Note:** Run `git add` from **repo root**, not `functions/` (pathspec errors otherwise)

---

## Phase 2 — Flutter module ✅ Complete

### Implemented

**Module:** `lib/features/challenge/`

| Layer | Files |
|-------|--------|
| Domain | `challenge_room.dart`, `challenge_status.dart`, `challenge_exceptions.dart` |
| Data | `challenge_repository.dart` — callables + Firestore `challenges/{code}` stream |
| Providers | `challenge_providers.dart` — `challengeRoomProvider`, etc. |
| UI | `challenge_lobby_screen.dart`, `join_challenge_sheet.dart`, `challenge_share_sheet.dart`, `challenge_entry_section.dart` |

**Router (`app_router.dart`):**

- `/challenge/lobby/:code` — waiting room, auto-join for guest, navigate when `active`
- `/challenge/play/:code` — live match (Phase 3 wires `GameScreen`)
- Auth redirect preserves `?next=/challenge/lobby/CODE` after sign-in

**Home:** `ChallengeEntrySection` below `HomeActionRow` — **Create** / **Join**

**Tests:** `test/challenge/challenge_room_test.dart`

### Manual QA (steps 2.7 & 2.8) ✅

- **iOS Simulator** (Apple Sign-In) + **Android Emulator** (Google Sign-In), dev flavor + App Check debug tokens
- Host **CREATE** → guest **JOIN** by code → both reach **active**
- Firestore doc confirmed on **dot-clash-dev** (e.g. `challenges/COX4TV`)

---

## Phase 3 — Playable match ✅ Complete

**Goal:** Live 6×6 match with human moves (not scheduler-only).

| Step | Status | Details |
|------|--------|---------|
| 3.1 | ✅ | `GameMode.challenge` + `GameConfig.challenge(code, myPlayerId, opponentDisplayName)` |
| 3.2 | ✅ | `ChallengeGameNotifier` + `challengeTurnTimerProvider` — Firestore sync, `submitChallengeMove`, server `turnStartedAt` timer |
| 3.3 | ✅ | `challenge_game_bindings.dart` — settlement on room `finished` / `abandoned` (not `gameProvider` listener) |
| 3.4 | ✅ | `GameScreen` uses `challengeGameProvider` when `mode == challenge` |
| 3.5 | ✅ | Guest = server `B`; `myPlayerId` gates board interaction |
| 3.6 | ✅ | No client-side timeout moves; server `turnStartedAt` drives timer |
| 3.7 | ✅ | Abandon on leave; undo/restart disabled in challenge |
| 3.8 | ✅ | `ScoreStrip` turn pills perspective-aware via `localPlayerId` (host/guest see correct YOUR TURN / WAITING / THEIR TURN) |
| 3.14 | ✅ | R11–R13 regression — campaign Next level, leave dialog, quick match unchanged |
| 3.15 | N/A | Rematch CTA moved to Phase 5.0 |

**Key files:**

| Layer | Files |
|-------|--------|
| Domain | `game_state.dart` (`GameMode.challenge`, `GameConfig.challenge`) |
| Providers | `challenge_game_provider.dart`, `challenge_providers.dart` |
| UI | `challenge_play_screen.dart` → `GameScreen` + `ChallengeGameBindings` |
| Integration | `game_screen.dart` — uses `challengeGameProvider` when `mode == challenge` |

**Manual QA (two devices):**

- iOS (host, Apple) + Android (guest, Google), dev flavor + per-platform App Check debug tokens
- Create → Join → full match with many `submitChallengeMove` successes (e.g. `challenges/CLJF9D`)
- Board sync, turn timer, game completion on server (`status: finished`)

---

## Phase 3.8+ — Settlement & Profile ✅ Complete

| Step | Status | Details |
|------|--------|---------|
| `recordChallengeMatch` | ✅ | Callable in `functions/src/challenge.ts` — idempotent via `settledUids.{uid}`; stats + `profiles/{uid}/matches` in one transaction |
| Firestore rules | ✅ | `validMatchCreate` allows optional `challengeCode` on match docs |
| Result dialog | ✅ | `ChallengeGameBindings` — root navigator dialog on terminal room status |
| Profile UI | ✅ | `ProfileChallengeHistorySection` — **FRIEND CHALLENGES** on Profile tab (`challengeRecentMatchesProvider`) |

**Client settlement path:** `challenge_game_bindings` → `ProfileRepository.recordChallengeMatch(code)` → callable; local fallback `settleMatch` + `matches` write if callable unavailable.

---

## Post-game bug fixes (2026-06-11)

### “Room not ready” after match end

**Cause:** `ChallengePlayScreen` only mounted `GameScreen` when `room.isActive`. Server sets `status: finished` → UI replaced board with “Room not ready” before result dialog.

**Fix:** `ChallengeRoom.hasPlayableBoard` (`active` | `finished` | `abandoned` + `gameState`); `_playSessionLocked` latch in `ChallengePlayScreen`.

### `ChallengeTurnTimerNotifier` dispose crash

**Cause:** Double dispose + room listener firing after unmount.

**Fix:** Remove redundant `ref.onDispose(notifier.dispose)`; guard `sync`/`_recalc` with `mounted`; `ref.onDispose(notifier.stop)` only.

### Turn pills identical on both devices

**Cause:** `ScoreStrip` assumed left column = you (vs-AI layout). Challenge keeps server A left / B right, so guest saw wrong YOUR TURN / THEIR TURN labels.

**Fix:** `ScoreStrip.localPlayerId` + `GameScreen` passes `_myPlayerId` in challenge; pills derived per column player id.

---

## Key concepts

### Who updates `challenges/{code}`?

**Only Cloud Functions** write challenge documents. The Flutter app **streams** and **calls** functions.

| Event | Source |
|-------|--------|
| Room created | `createChallenge` |
| Guest joins | `joinChallenge` |
| Line drawn | `submitChallengeMove` |
| Turn timeout (~30s) | `processChallengeTimeouts` (random legal move) |
| Match ends (stats) | `recordChallengeMatch` (per player, idempotent) |
| Leave | `abandonChallenge` |

Host = player `A`, guest = player `B` on server. Each client uses `GameConfig.myPlayerId` for “your turn” and scoreboard labels.

### Profile / match history

- **Stats** (wins, games played, coins, rating): `recordChallengeMatch` or fallback `settleMatch`
- **History list**: `profiles/{uid}/matches` with `modeLabel: 'Challenge'`; shown under Profile → **FRIEND CHALLENGES**
- `recentMatchesProvider` exists on Home data layer; Profile filters `modeLabel == 'Challenge'`

### Firebase Functions shell vs Postman

- `firebase functions:shell` + Gen 2 `onCall` → **400 "Request body is missing data"** — shell does not send `{ "data": ... }` correctly.
- **Use instead:** Postman/curl to emulator (`http://127.0.0.1:5001/dot-clash-dev/us-central1/<callable>`) with body `{ "data": { ... } }` and `Authorization: Bearer <idToken>`.
- Do **not** run shell and `firebase emulators:start` at the same time (port conflict).

### Switch dev vs prod for CLI

```bash
firebase use dev   # dot-clash-dev
firebase use prod  # dot-clash-72cc6 (default in .firebaserc)
```

### Postman "Profile not found"

`createChallenge` reads `profiles/{uid}` where `uid` = Bearer token's user id.

- Collection must be **`profiles`**, not `users`
- Document **ID** must equal Auth `uid` (not auto-ID with uid in a field)
- Use `localId` from Auth emulator sign-up response

### Android emulator logs

Verbose terminal output (MESA, WebView, UMP consent) is **normal** on emulator. Test on the **emulator screen**; watch terminal only for `[Callable]` errors or Flutter red screens.

---

## Troubleshooting reference

| Issue | Fix |
|-------|-----|
| Shell on prod | `firebase use dev` before `npm run shell` |
| `pathspec 'firestore.rules' did not match` | `cd` to repo root before `git add` |
| Callable 400 in shell | Use Postman with `{ "data": {} }` |
| Challenge doc changes with no taps | Server scheduler (`processChallengeTimeouts`) |
| App Check on Android/iOS | Register separate debug tokens per platform in Console |
| `Unable to resolve host firestore.googleapis.com` (Android) | Emulator DNS/network — cold boot AVD, test Chrome → google.com |
| `flutter emulators --launch` but no device | `emulator -avd Pixel_10_Pro_XL` + `xcrun simctl boot <iphone-udid>` |
| Flutter picker `[1]` vs `[2]` | `[1]` = Android, `[2]` = iOS — use `-d emulator-5554` / `-d <ios-udid>` |
| “Room not ready” after win | Fixed — hot restart both apps after pulling latest |
| `recordChallengeMatch` fails | Deploy functions to `dot-clash-dev`; watch for `[Callable] recordChallengeMatch succeeded` |

---

## Run dev on two devices

```bash
# Kill + restart Android (cold boot example)
adb -s emulator-5554 emu kill
emulator -avd Pixel_10_Pro_XL -no-snapshot-load

# iOS
xcrun simctl boot A9B9913E-CBAA-4BDA-AD17-0168A01DBA42
open -a Simulator

# iOS (host)
flutter run -d A9B9913E-CBAA-4BDA-AD17-0168A01DBA42 \
  --flavor dev --dart-define=FLAVOR=dev \
  --dart-define=APP_CHECK_DEBUG_TOKEN=<ios-token>

# Android (guest)
flutter run -d emulator-5554 \
  --flavor dev --dart-define=FLAVOR=dev \
  --dart-define=APP_CHECK_DEBUG_TOKEN=<android-token>
```

Register both tokens in [Firebase Console → dot-clash-dev → App Check](https://console.firebase.google.com/project/dot-clash-dev/appcheck/apps).

---

## Phase status at a glance

| Phase | Status |
|-------|--------|
| **1 — Backend** | ✅ Done |
| **2 — Flutter module** (lobby, join, share, home entry) | ✅ Done |
| **3 — Playable match** (3.1–3.14; 3.15 N/A → Phase 5.0) | ✅ Done |
| **3.8+ — Settlement & Profile** | ✅ Done |

## What's next (pending)

| Priority | Item | Notes |
|----------|------|-------|
| Polish | Rematch CTA on result dialog (Phase 5.0) | One-tap `createChallenge` with same opponent |
| Polish | Share win card | Nostalgia hook — “Remember this game from class?” |
| Retention | Revenge invite from Profile history row | Tap past challenge → pre-filled invite |
| Backend | `dailyMissions` in `recordChallengeMatch` | Parity with campaign `settleMatch` |
| Backend | Challenge-specific daily mission | e.g. “Win 1 friend challenge” |
| Launch | Prod deploy | `firebase deploy` challenge stack to `dot-clash-72cc6` |

---

## Useful commands (quick reference)

```bash
# Verify
cd functions && npm run build && npm run lint
flutter test test/game/game_state_serialization_test.dart test/challenge/challenge_room_test.dart

# Deploy dev backend
firebase use dev
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-dev

# Emulators (Postman testing)
firebase emulators:start --only functions,firestore,auth

# List / launch emulators
flutter emulators
flutter emulators --launch <id>
```

---

*Updated 2026-06-11 — Phase 3 (3.1–3.8) + 3.8+ complete; turn-pill fix verified on two devices.*
