# Challenge a Friend — Session Summary

**Date:** 2026-06-08 through 2026-06-13  
**Branch:** `one-to-one-challange`  
**Firebase projects:** `dot-clash-dev` (dev flavor) · `dot-clash-72cc6` (prod / closed testing)  
**Current build:** `1.4.1+19` (see `pubspec.yaml`)  
**Canonical plan:** `.cursor/plans/challenge_a_friend.plan.md`

---

## What this session covered

- **Phase 1 (backend)** — Cloud Functions, rules, indexes, scheduler
- **Phase 2 (Flutter module)** — lobby, join, share, entry on Home
- **Phase 3** — playable live 6×6 board via `GameScreen` + human `submitChallengeMove`
- **Phase 3.8+** — `recordChallengeMatch`, settlement dialog, Challenge hub rivalries + history
- **Phase 4** — App Links + FCM (agent + manual gates on prod)
- **Post–Phase 4 gameplay fixes** — optimistic moves, zero-move abandon
- **Phase 5** — H2H UI (Rematch, series, recent rivals, share win)
- **FCM latency fixes** — foreground Android snackbar, high-priority push, notification channel
- **Prod two-device QA** — builds `+15` through `+17` on real iPhone + Android (`dot-clash-72cc6`)
- **Build prep (2026-06-13)** — plan gap fixes, Codex review fixes, analyze compile fixes, rivalries UX moved to Challenge hub

---

## Phase 1 — Backend ✅ Complete

### Implemented

| Area | Details |
|------|---------|
| **Dart serialization** | `disabledCells` added to `GameState.toJson` / `fromJson`; test in `test/game/game_state_serialization_test.dart` |
| **`functions/src/game_rules.ts`** | TypeScript port of `GameRules` + `GameState` (parity with `test/game/rules_test.dart`) |
| **`functions/src/challenge.ts`** | `createChallenge`, `joinChallenge`, `submitChallengeMove`, `abandonChallenge`, `recordChallengeMatch`; shared `commitChallengeMoveInTransaction` |
| **`functions/src/challenge_scheduler.ts`** | `processChallengeTimeouts` (every 1 min) — turn timeout, waiting-room expiry, 24h stale active abandon |
| **`functions/src/notifications.ts`** | `registerFcmToken`, FCM invite helper for `createChallenge({ targetUid })` |
| **`functions/src/index.ts`** | Exports all new callables + scheduler |
| **`firestore.rules`** | `challenges/{code}` — read for host/guest only; writes denied (functions only); `matches` allows optional `challengeCode` |
| **`firestore.indexes.json`** | Composite indexes for scheduler (`status` + `turnStartedAt`, `status` + `expiresAt`, `status` + `lastActivityAt`) |
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
| UI | `challenge_lobby_screen.dart`, `join_challenge_sheet.dart`, `challenge_share_sheet.dart`, `challenge_home_screen.dart` |

**Router (`app_router.dart`):**

- `/challenge/lobby/:code` — waiting room, auto-join for guest, navigate when `active`
- `/challenge/play/:code` — live match (Phase 3 wires `GameScreen`)
- Auth redirect preserves `?next=/challenge/lobby/CODE` after sign-in

**Home:** Play Modes grid → **Challenge a Friend** tile opens `/challenge` (`ChallengeHomeScreen`)

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
| 3.14 | ✅ | Builds 11–13 regression — campaign Next level, leave dialog, quick match unchanged |
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

## Phase 3.8+ — Settlement & match history ✅ Complete

| Step | Status | Details |
|------|--------|---------|
| `recordChallengeMatch` | ✅ | Callable in `functions/src/challenge.ts` — idempotent via `settledUids.{uid}`; writes `profiles/{uid}/matches` only (no coins/XP/rating/lives) |
| Firestore rules | ✅ | `validMatchCreate` allows optional `challengeCode` on match docs |
| Result dialog | ✅ | `ChallengeGameBindings` — root navigator dialog on terminal room status |
| Match history UI | ✅ | `ChallengeHomeScreen` rivalries + `ChallengeHistoryScreen` (Rivals / History tabs) |

**Client settlement path:** `challenge_game_bindings` → `ProfileRepository.recordChallengeMatch(code)` → callable; dev-only local fallback `settleMatch` if callable unavailable (`AppEnv.isDev`).

**Outcome authority:** `challenge_match_result.dart` — win/loss/tie from server `room.winnerUid`, not local board state.

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
| Turn timeout (~30s) | `processChallengeTimeouts` (random legal move); client backup via `ChallengeGameNotifier.onTurnTimedOut` |
| Stale active match (24h) | `processChallengeTimeouts` → `abandoned` |
| Match ends (stats) | `recordChallengeMatch` (per player, idempotent) |
| Leave | `abandonChallenge` |

Host = player `A`, guest = player `B` on server. Each client uses `GameConfig.myPlayerId` for “your turn” and scoreboard labels.

### Profile / match history

- **Stats** (wins, games played, coins, rating): campaign / quick match only — Challenge settlement is **history-only** via `recordChallengeMatch`
- **History list**: `profiles/{uid}/matches` with `modeLabel: 'Challenge'`
- **UI**: Challenge hub (`ChallengeHomeScreen`) — up to 5 recent rivals + rematch; full list on `ChallengeHistoryScreen` (`/profile/challenge-history`)
- Profile tab no longer shows rivalries — identity, economy, campaign progress, aggregate stats only
- `challengeRecentMatchesProvider` / `challengeRivalsProvider` power Challenge hub + history screens

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
| Android revenge push “missing” | Often **foreground** — fixed in build 18 (snackbar + JOIN). Background: check `FCM challenge invite sent` in logs |
| `processChallengeTimeouts` scheduler 500 | Separate from FCM — check Cloud Logging for `processchallengetimeouts` errors |

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
| **3.8+ — Settlement & match history** | ✅ Done |
| **4 — App Links + FCM** | ✅ Done (2026-06-11) |
| **5 — H2H UI** (agent steps) | ✅ Done (2026-06-11) |
| **5.4–5.5 manual QA** | ⏳ Retest on build 19 after FCM + settlement + Challenge hub UX |
| **6 — QA + ship build 19** | ⏳ Pending deploy + device matrix |

## Phase 4 — App Links + FCM ✅ (2026-06-11)

| Step | Status | Details |
|------|--------|---------|
| 4.1 | ✅ | `app_links` in `pubspec.yaml` |
| 4.2 | ✅ | Android intent-filters: HTTPS `/join` + `dotclash://join` (`autoVerify` on HTTPS) |
| 4.3 | ✅ | iOS `CFBundleURLTypes` (`dotclash`), Associated Domains, `UIBackgroundModes` remote-notification |
| 4.4 | ✅ | `ChallengeIngressListener` → `/challenge/lobby/:code` (HTTPS, custom scheme, cold start) |
| 4.5 | ✅ | `FcmService` — permission, `registerFcmToken` on login, tap → lobby |
| 4.6 | ✅ | Home Play Modes → Challenge tile → `/challenge` |
| 4.7 | ✅ | Draft GitHub Pages files in `docs/github-pages/` |

**Key files:** `lib/core/deep_links/challenge_link_parser.dart`, `lib/services/deep_links/challenge_ingress_listener.dart`, `lib/services/push/fcm_service.dart`, `lib/app.dart`, `lib/main.dart`

### Manual gates (verified 2026-06-11)

| Step | Status | Action |
|------|--------|--------|
| 4.8 | ✅ | Prod SHA-256 in `assetlinks.json` |
| 4.9 | ✅ | GitHub Pages published → **vividmemories-games.github.io**; `curl` verified |
| 4.10 | ✅ | Xcode Push Notifications + `aps-environment` = `production` |
| 4.11 | ✅ | Real device: HTTPS link tap → challenge lobby |
| 4.12 | ✅ | Real device: FCM tap (background + killed) → lobby; APNs key in Firebase Console (`dot-clash-72cc6`) |

## Phase 5 — H2H UI ✅ Agent complete (2026-06-11)

| Step | Status | Details |
|------|--------|---------|
| 5.0 | ✅ | Rematch CTA on result dialog → `createChallenge(targetUid)` |
| 5.1 | ✅ | `head_to_head_stats.dart` — aggregate W–L–T by `opponentUid` |
| 5.2 | ✅ | Result dialog series line (`Series: 2–1–0`) |
| 5.3 | ✅ | `ChallengeHomeScreen` — **Recent rivals** (up to 5) + rematch |
| 5.6 | ✅ | Share win card (clipboard); rematch from result dialog + Challenge hub rival rows |
| Backend | ✅ | `recordChallengeMatch` writes `opponentUid`; rules allow optional field |
| 5.4–5.5 | ⏳ | Manual push/H2H QA — see device matrix below |

**Key files:** `head_to_head_stats.dart`, `challenge_game_bindings.dart`, `challenge_home_screen.dart`, `challenge_history_screen.dart`, `challenge_match_result.dart`, `challenge_win_share.dart`, `functions/src/notifications.ts`, `functions/src/challenge.ts`

**Deploy for H2H on new matches:**

```bash
firebase deploy --only functions,firestore:rules -P dot-clash-72cc6
firebase deploy --only functions,firestore:rules -P dot-clash-dev
```

---

## Post–Phase 4 gameplay fixes ✅ (2026-06-11)

Prod device QA (`+15`) found two issues; fixed in client without backend deploy:

| Issue | Root cause | Fix |
|-------|------------|-----|
| **Move lag** | `ChallengeGameNotifier.makeMove` awaited server before updating board | Optimistic `GameRules.applyMove`; rollback on `ChallengeException`; Firestore reconciles |
| **Zero-move leave** | Leave/abandon only when `moveHistory.isNotEmpty` | Confirm + `abandonChallenge` when `room.isActive` (in-app leave only) |

**Files:** `challenge_game_provider.dart`, `game_screen.dart`, `test/challenge/challenge_game_notifier_test.dart`

**Prod QA result (build `+17`):** all gameplay-fix scenarios **passed** on real iPhone + Android.

**Out of scope:** force-quit without Leave; lobby host leave; server disconnect heartbeat.

---

## Prod device QA matrix (2026-06-13, build `+17`)

Two physical devices, `dot-clash-72cc6`, Google (Android) + Apple (iPhone).

| # | Scenario | Result |
|---|----------|--------|
| 1 | Optimistic moves (slow network) | ✅ Works well |
| 2 | Zero-move leave → opponent wins | ✅ Works well |
| 3 | Finish match / settlement / series | ✅ Works well |
| 4 | Rematch + push | ⚠️ Android→iPhone ✅; iPhone→Android **delayed** (not broken) |
| 5 | Home recent rivals + push | ⚠️ Same as 4 |
| 6 | Challenge hub rematch + push | ⚠️ Same as 4 (was Profile REVENGE — moved to Challenge hub) |
| 7 | Share win (clipboard) | ✅ Works well |
| 8 | Series after 3 matches vs same friend | ✅ Works well |

### FCM diagnosis (items 4–6)

Initial report looked like missing Android push. Investigation showed:

| Check | Finding |
|-------|---------|
| `fcmToken` on Android profile | ✅ Present |
| Android notification permission | ✅ Allowed |
| `createChallenge` logs | HTTP 200 — no FCM error (push is best-effort, separate from callable response) |
| Android eventually received notification | ✅ Setup OK — issue is **latency / foreground visibility** |

**Root cause:** Android does not show tray notifications while app is **foreground** without `onMessage` handling. iOS shows banners in foreground via `setForegroundNotificationPresentationOptions`. Normal-priority FCM can also be batched on Android (Doze/OEM).

**Not related:** `processChallengeTimeouts` scheduler HTTP 500 (separate backend issue — see below).

---

## FCM invite latency fixes (2026-06-13, build 18)

| Fix | Layer | Details |
|-----|-------|---------|
| Foreground Android | **App** | `FirebaseMessaging.onMessage` → gold snackbar + **JOIN** → lobby |
| High priority | **Functions** | `android.priority: high`, `apns-priority: 10` |
| Notification channel | **App** | `MainActivity` creates `dot_clash_challenges`; manifest `default_notification_channel_id` |
| Server observability | **Functions** | Logs: `FCM challenge invite sent` / `skipped` / `failed` |

**Files:** `fcm_service.dart`, `challenge_ingress_listener.dart`, `app_snackbar.dart`, `MainActivity.kt`, `AndroidManifest.xml`, `notifications.ts`

**Deploy functions (both projects):**

```bash
firebase deploy --only functions -P dot-clash-72cc6
firebase deploy --only functions -P dot-clash-dev
```

**Requires app build 18+** for foreground snackbar + Android channel. Functions deploy alone improves background priority/logging only.

### Retest after build 18

| Scenario | Expected |
|----------|----------|
| iPhone Revenge, Android app **open** | Snackbar + JOIN within ~1s |
| iPhone Revenge, Android **backgrounded** | Tray notification within a few seconds |
| Cloud Logs | `FCM challenge invite sent` with `sentAt` on each rematch |
| Items 4–6 full pass | Both directions feel timely |

---

## Build prep — plan gaps & hardening (2026-06-13, build 19)

| Area | Status | Details |
|------|--------|---------|
| Client turn-timeout backup | ✅ | `ChallengeGameNotifier.onTurnTimedOut` submits random legal move when server scheduler lags; wired in `GameScreen` for challenge mode |
| 24h stale auto-abandon | ✅ | `processChallengeTimeouts` abandons active rooms with `lastActivityAt` > 24h; composite index `status` + `lastActivityAt` |
| Analytics | ✅ | `challenge_started`, `challenge_finished` in `AnalyticsService` |
| Firestore rules | ✅ | `validMatchCreate()` uses `hasOnly(...)` allowlist |
| Build docs | ✅ | `docs/RELEASES.md` build 19 section; `pubspec.yaml` → `1.4.1+19` |
| Scheduler robustness | ✅ | Top-level try/catch in `processChallengeTimeouts` (500 mitigation) |

**Tests added:** `challenge_match_result_test.dart`, `challenge_game_notifier_test.dart` (timeout path)

---

## Codex review fixes (2026-06-13)

| Finding | Fix |
|---------|-----|
| Wrong winner from local board | `challenge_match_result.dart` — outcome from `room.winnerUid` |
| Reconnect missed settlement | `ChallengeGameBindings` — post-frame settle if room already terminal on first load (`_checkedInitialTerminal`) |
| `matchSession` leak in challenge | `GameScreen` — `const MatchSession()` + gated listener (challenge vs campaign) |
| Unrestricted rematch push | `createChallenge` — recent-rival gate + 60s throttle (`challenge_push_throttle`) |
| Challenge economy bleed | `recordChallengeMatch` — match history only; no coins/XP/rating/lives |

**Compile fix:** removed invalid `fireImmediately` on `WidgetRef.listen`; `_gameStateFor(room)` returns non-null `GameState` for analytics + result dialog.

---

## Challenge hub UX — rivalries moved from Profile (2026-06-13)

**Before:** Profile tab showed **RIVALRIES** (`ProfileChallengeHistorySection`) — top rival + “View all”.

**After:** Single home for social Challenge context:

| Screen | Content |
|--------|---------|
| **`ChallengeHomeScreen`** (`/challenge`) | Create / Join · **RIVALRIES** (up to 5 `RivalListTile` with rematch) · empty-state card · View all |
| **`ChallengeHistoryScreen`** | Rivals tab + History tab (unchanged) |
| **Profile** | Avatar, rank, economy, campaign progress, stats — no rivalries |

**Rationale:** One obvious rematch path; Profile stays “who am I”; Challenge hub fills previously empty space below Create/Join.

**Files:** `challenge_home_screen.dart`, `challenge_history_widgets.dart` (`ChallengeRivalriesEmptyCard`); removed `profile_challenge_history_section.dart`.

---

## Known issue — `processChallengeTimeouts` scheduler (2026-06-13)

Cloud Scheduler job `firebase-schedule-processChallengeTimeouts-us-central1` returned **HTTP 500** when invoking the function URL. **Unrelated to FCM invite push.**

**Mitigations in build 18+:** top-level try/catch; 24h stale abandon; client-side turn-timeout backup.

**Impact if still failing:** server turn timeouts may lag until client backup fires; waiting-room expiry / stale abandon may not run on schedule.

**Debug:** Cloud Logging → `resource.labels.service_name="processchallengetimeouts"` + `severity>=ERROR`

---

## What's next

| Priority | Item | Notes |
|----------|------|-------|
| **1** | Deploy backend to prod + dev | `functions`, `firestore:rules`, `firestore:indexes` — FCM throttle, economy fix, scheduler, 24h abandon |
| **2** | Build + install **build 19** (`1.4.1+19`) on both phones | Foreground snackbar + channel + settlement + Challenge hub UX |
| **3** | Retest FCM matrix (4–6) | Foreground + background on Android; rematch from Challenge hub |
| **4** | Phase 6 manual QA | Full challenge matrix + builds 11–13 regression → ship build 19 |
| **5** | Verify scheduler after deploy | Confirm `processChallengeTimeouts` no longer 500 |
| Polish | Route rename | `/profile/challenge-history` → `/challenge/history` (optional) |
| Backend | `dailyMissions` for Challenge | Parity with campaign; e.g. “Win 1 friend challenge” |

---

## Useful commands (quick reference)

```bash
# Verify
cd functions && npm run build && npm run lint
flutter test test/game/game_state_serialization_test.dart test/challenge/challenge_room_test.dart test/challenge/challenge_game_notifier_test.dart test/challenge/challenge_match_result_test.dart test/challenge/head_to_head_stats_test.dart test/challenge/challenge_win_share_test.dart test/deep_links/challenge_link_parser_test.dart

# Deploy prod backend (functions + rules)
firebase deploy --only functions,firestore:rules -P dot-clash-72cc6

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

*Updated 2026-06-13 — Build 19 (`1.4.1+19` per pubspec); plan gaps + Codex fixes; rivalries on Challenge hub; analyze clean; 115 tests passing; deploy + device QA pending.*
