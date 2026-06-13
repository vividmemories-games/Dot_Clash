# Dot Clash — Build history & closed-testing tracker

**Naming:** Features ship by **build number** (`+N` in `pubspec.yaml`), e.g. build 19 — not "Release N". Always read `pubspec.yaml` before stating the current target.

**Active build target:** `1.4.1+19` in `pubspec.yaml` (bump `+N` before each store upload)  
**Track:** Prod package + Firebase (`dot-clash-72cc6`), `BETA_ADS=true` (test ads)  
**IAP / ops:** `SETUP.md` §4b · **Security:** `SETUP.md` App Check + [`firestore.rules`](../firestore.rules)

---

## Build & upload (current)

```bash
cd "/path/to/Dot_Clash"
# Bump version in pubspec.yaml before each store upload

bash scripts/build_closed_testing.sh          # both
bash scripts/build_closed_testing.sh android
bash scripts/build_closed_testing.sh ios
```

| Platform | Artifact |
|----------|----------|
| Android | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |
| iOS | `build/ios/ipa/*.ipa` |

**Pre-upload checklist (build 19 — Challenge a Friend ship candidate)**

- [ ] `pubspec.yaml` build number incremented (`1.4.1+19`)
- [ ] Challenge: create → join → full 6×6 match → rematch / revenge push
- [ ] Challenge: HTTPS link + FCM tap → lobby → play
- [ ] Challenge hub: rivalries list, rematch, view all history (not on Profile)
- [ ] Mid-match **Home** / **MORE → Exit** / system back → confirm dialog; **Stay** keeps board
- [ ] Campaign abandon → **Leave** exits without consuming a life; fresh level (no moves) → no dialog
- [ ] Quick match / vs AI: generic “Leave match?” copy
- [ ] Build 12 smoke: campaign Next level, turn budgets, shop UX (see build 12 checklist below)
- [ ] Prod functions + indexes if backend changed: `firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-72cc6`
- [ ] Crashlytics: filter current version after rollout

---

## Build 19 — Challenge a Friend (ship candidate)

**Version:** `1.4.1+19`

### Shipped / in this build

| Item | Notes |
|------|--------|
| Everything in build 18 | Live Challenge, App Links, FCM, H2H, scheduler hardening |
| Codex / settlement fixes | Outcome from `room.winnerUid`; reconnect settlement; history-only economy |
| Challenge hub rivalries | Rivalries moved off Profile → `ChallengeHomeScreen` |
| Push guardrails | Recent-rival check + 60s throttle on invite push |
| Client turn-timeout backup | `ChallengeGameNotifier.onTurnTimedOut` |
| Analytics | `challenge_started`, `challenge_finished` |

**Key modules:** `lib/features/challenge/`, `challenge_game_bindings.dart`, `challenge_home_screen.dart`, `functions/src/challenge.ts`

### Regression checklist

Same as build 18, plus:

| Scenario | Expected |
|----------|----------|
| Challenge hub → rival rematch | Creates room; no Profile rivalries section |
| Reconnect to finished room | Settlement runs; result dialog or history updated |

### Store notes (build 19 — Play / TestFlight)

**Short** (TestFlight “What to Test” / Play release notes)

> **Challenge a Friend** — play live Dots & Boxes online with a friend. Share a link or 6-digit code, battle on a 6×6 board, and keep the rivalry going with rematch and head-to-head stats on the Challenge hub.  
> Turn timer keeps matches moving. Leave confirmation so you don’t accidentally quit mid-game.  
> Remember this game from class? Grab a friend and settle the score.

**Bullets**

- **Challenge a Friend** — create or join a live online match (6×6 board, 30s turns)
- Share an invite **link or code**; open from notification or link to jump straight in
- **Rematch** recent rivals from the Challenge hub; track your **series (W–L–T)**
- Smoother match finish and reconnect handling
- Android: in-app invite snackbar when the app is open
- Campaign & Quick Match unchanged — please smoke-test those too

**Tester focus** (optional “What to Test” add-on)

- Host **Create** → guest **Join** → full match → **Rematch**
- Tap a shared HTTPS link (or notification) while logged in
- Challenge hub → rival row → rematch
- Mid-match **Home** / back → confirm dialog → **Stay** keeps the board

**Do not promise in store copy**

- No lives/coins/XP in Challenge mode
- Push invites only for **recent rivals** (first challenge to someone new may not push)
- No friend list or public matchmaking

### Backend deploy (required)

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-72cc6
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-dev
```

---

## Build 18 — Challenge a Friend (QA builds 15–18)

**Version:** `1.4.0+18` (QA also on builds 15–17)

### Shipped

| Item | Notes |
|------|--------|
| Live 1v1 Challenge | 6×6 board, server-validated moves, 30s turn timer |
| Create / Join / Share | Home play grid → Challenge hub; 6-digit code + HTTPS link |
| App Links + FCM | `vividmemories-games.github.io/join/{CODE}`; invite push for recent rivals |
| Head-to-head | Series on result, rematch/revenge, rivals on Challenge hub, challenge history |
| FCM foreground (Android) | In-app snackbar + JOIN when app is open |
| Client turn-timeout backup | Random legal move via same `submitChallengeMove` callable |
| Server scheduler | Turn timeouts, waiting-room expiry, 24h stale-match auto-abandon |
| Analytics | `challenge_started`, `challenge_finished` |

**Key modules:** `lib/features/challenge/`, `functions/src/challenge.ts`, `challenge_scheduler.ts`, `notifications.ts`

### Regression checklist

| Scenario | Expected |
|----------|----------|
| Host CREATE → guest JOIN | Both reach active board; turns alternate |
| Finish match | One result dialog each; series updates; history row |
| Rematch / REVENGE | Push or foreground snackbar on guest device |
| Leave mid-match (in-app) | Opponent wins; leaver sees loss |
| Campaign Next level | Unchanged (build 12) |
| Quick match leave dialog | Unchanged (build 13) |

### Store notes (draft)

- **Challenge a Friend** — invite rivals with a link or code and play live Dots & Boxes online
- Rematch, revenge, and head-to-head stats on the Challenge hub

### Backend deploy

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-72cc6
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-dev
```

---

## Build 13 — Leave match confirmation

**Version:** `1.3.0+13`

### Shipped

| Item | Notes |
|------|--------|
| Leave match confirmation | Home, MORE → Exit, and system back ask before leaving mid-game |
| Campaign copy | Level progress lost; life **not** consumed on abandon |
| No dialog when safe | Fresh board (no moves) or finished game exits immediately |

**Key file:** `lib/features/game/presentation/game_screen.dart` (`_shouldConfirmLeave`, `_requestLeaveGame`, `PopScope`)

### Regression checklist

| Scenario | Expected |
|----------|----------|
| Campaign mid-match → Home | Dialog → Stay keeps board; Leave → home, life unchanged |
| Campaign mid-match → MORE → Exit | Same dialog |
| Android/iOS back gesture mid-match | Same dialog |
| Fresh level (0 moves) → Home | No dialog |
| Game over → result → Home | No leave dialog (direct exit) |
| Quick match mid-game → Exit | Generic “Leave match?” copy |

### Store notes (draft)

- Confirm before leaving a match so progress isn’t lost by accident
- Campaign: abandoning a level doesn’t use a life

---

## Build 12 — Campaign polish, turn budgets, shop UX

**Version:** `1.3.0+12`

### Fixes

| Item | Status | Notes |
|------|--------|-------|
| Next level stuck on finished board | **Fixed** | Per-level `ValueKey` in `app_router.dart` |
| Flash of completed level on Next level / Try again | **Fixed** | Root-nav victory overlay; `campaignPlayReadyProvider`; config sync before render |
| Duplicate victory overlay | **Fixed** | `_campaignResultPushed` guard |
| Interstitials during FTUE | **Fixed** | Skip on `w1_l01`–`w1_l04`; every 3 matches elsewhere |
| Turn limits too tight (e.g. Greedy Counter) | **Fixed** | Grid/setup-based `TurnBudgetCalculator`; ~24 turns on 5×5 boards |
| Shop purchases feel slow (4–6 s) | **Fixed** | Optimistic profile emit + instant snackbar/haptic + coin pulse |
| Daily claim no visible feedback | **Fixed** | CLAIMED + cooldown copy; brief shows “Win within N turns” |
| Double-tap shop purchases | **Fixed** | `shopPurchaseInFlightProvider` disables buy buttons while awaiting server |

**Key files:** `campaign_play_navigation.dart`, `campaign_level_complete_screen.dart`, `game_screen.dart`, `campaign_play_ready_provider.dart`, `app_router.dart`, `turn_budget_calculator.dart`, `firestore_profile_repository.dart`, `shop_screen.dart`

### Regression checklist

| Scenario | Expected |
|----------|----------|
| Beat w1_l02 → Next level | l03 loads fresh; no finished-board flash |
| Beat w1_l03 → Next level | FTUE + Hold grant; no overlay stuck |
| Lose → Try again (has lives) | Fresh board (`?r=` replay key) |
| Lose → Try again (0 lives) | Lives gate (build 10) |
| Win → Campaign map | No coach-tour GlobalKey crash |
| w2_l09 Greedy Counter | Turn budget ~24; 5 turns at 0–0 still fair |
| Shop → buy boost | Snackbar + coin pulse immediately; button disabled until server ok |
| Shop → claim daily | Instant feedback; button → CLAIMED + cooldown |
| Shop → double-tap buy | Second tap ignored while in-flight |
| Watch ad · retry | `exitToReplayLevel` |

### Store notes (draft)

- Campaign Next level and Try again load the correct board without flashing the finished level
- Mid-campaign turn limits are more realistic on larger boards
- Shop purchases and daily rewards feel instant — coins update right away
- No full-screen ads on the first four tutorial levels

### Dev-only (not in store notes)

- Long-press **Claim Daily** card → `devResetDailyClaim` (deployed on `dot-clash-dev` only)
- CLI reset: `node functions/scripts/reset_daily_claim.cjs [uid] dot-clash-dev`

---

## Build 11 — Bootstrap, Hold, tab swipes

**Version:** `1.2.2+11`

| # | Report | Status | Fix |
|---|--------|--------|-----|
| 1 | Hold power-up sometimes does nothing | **Fixed** | Apply before consume; rollback + snackbar |
| 2 | Swipe between main tabs | **Fixed** | `_TabSwipeLayer` on app shell |
| 3 | Shop → Profile swipe blocked | **Fixed** | `ShopOuterSwipeBridge` (Themes edge) |
| 4 | Dummy home flash on launch | **Fixed** | Profile bootstrap gate |
| 5 | Stale `Dot Clash v1.0.0` in Settings | **Fixed** | Footer removed |
| — | About shows package name | **Fixed** | Provider name: `VividMemories-Games` |

---

## Build 10 — Tester hotfixes + About

**Version:** `1.2.1+10`

| # | Report | Status | Fix |
|---|--------|--------|-----|
| 1 | Try Again shows final board | **Fixed** | `exitToReplayLevel` replaces play route |
| 2 | Lives sheet frozen after coin purchase | **Fixed** | `LivesRefillSheet` watches lives provider |
| 3 | Snackbar not prominent | **Fixed** | `AppSnackBar` + theme |
| 4 | Timer continues when app minimized | **Fixed** | Lifecycle pause/resume |
| 5 | Riposte popup repeats | **Fixed** | `lastAiSegmentBoxCount` |
| — | Duplicate GlobalKey on campaign exit | **Fixed** | Scoped coach-tour keys + release before `router.go` |

Also: About screen.

---

## Build 7 — Security + IAP verification

**Versions:** `1.1.0+7` / `+8`

### Shipped

- Firestore rules whitelist (dev + prod)
- `verifyRemoveAdsPurchase` Cloud Function + client integration
- Economy callables; `completeCampaignLevel` rewards from server catalog
- Shop avatar grid overflow fix (small iPhones)
- IAP PEM normalize + TestFlight sandbox fallback
- Campaign exit `ref` after disposed fix (+8)

### Prod IAP secrets

| Secret | Purpose |
|--------|---------|
| `APPLE_IAP_KEY_ID` | App Store Connect API key |
| `APPLE_IAP_ISSUER_ID` | Issuer ID |
| `APPLE_IAP_PRIVATE_KEY` | `.p8` contents (PEM) |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Play Developer API JSON |

See `SETUP.md` §4b for full IAP setup.

---

## Build 6 — Closed testing baseline

**Version:** `1.0.x`

Initial closed-testing builds: campaign worlds 1–2, shop, lives, daily puzzle, quick match vs AI, Remove Ads IAP.

---

## Archive note

Individual release files (`RELEASE_9.md`, `RELEASE_12.md`, `docs/archive/RELEASE_*.md`) were merged into this document. Use this file as the single source of truth for **build** history and upload checklists. Section titles use **build N** matching `+N` in `pubspec.yaml`.
