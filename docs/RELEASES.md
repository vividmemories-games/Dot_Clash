# Dot Clash — Release history & closed-testing tracker

**Active build target:** `1.3.0+13` in `pubspec.yaml` (bump before each store upload)  
**Track:** Prod package + Firebase (`dot-clash-72cc6`), `BETA_ADS=true` (test ads)  
**IAP / ops:** `SETUP.md` §4b · **Mac migration:** `MIGRATION_RUNBOOK.md` · **Security:** `SECURITY_FIX_PLAN.md`

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

**Pre-upload checklist (Release 13+)**

- [ ] `pubspec.yaml` build number incremented (`1.3.0+13`)
- [ ] Mid-match **Home** / **MORE → Exit** / system back → confirm dialog; **Stay** keeps board
- [ ] Campaign abandon → **Leave** exits without consuming a life; fresh level (no moves) → no dialog
- [ ] Quick match / vs AI: generic “Leave match?” copy
- [ ] R12 smoke: campaign Next level, turn budgets, shop UX (see Release 12 checklist below)
- [ ] Prod functions if backend changed: `firebase deploy --only functions -P dot-clash-72cc6`
- [ ] Crashlytics: filter current version after rollout

---

## Release 13 — Leave match confirmation

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

## Release 12 — Campaign polish, turn budgets, shop UX

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
| Lose → Try again (0 lives) | Lives gate (R9) |
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

## Release 11 — Bootstrap, Hold, tab swipes

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

## Release 9 — Tester hotfixes + About

**Version:** `1.2.1+10`

| # | Report | Status | Fix |
|---|--------|--------|-----|
| 1 | Try Again shows final board | **Fixed** | `exitToReplayLevel` replaces play route |
| 2 | Lives sheet frozen after coin purchase | **Fixed** | `LivesRefillSheet` watches lives provider |
| 3 | Snackbar not prominent | **Fixed** | `AppSnackBar` + theme |
| 4 | Timer continues when app minimized | **Fixed** | Lifecycle pause/resume |
| 5 | Riposte popup repeats | **Fixed** | `lastAiSegmentBoxCount` |
| — | Duplicate GlobalKey on campaign exit | **Fixed** | Scoped coach-tour keys + release before `router.go` |

Also: About screen, Mac migration runbook (`MIGRATION_RUNBOOK.md`).

---

## Release 7 — Security + IAP verification

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

## Release 6 — Closed testing baseline

**Version:** `1.0.x`

Initial closed-testing builds: campaign worlds 1–2, shop, lives, daily puzzle, quick match vs AI, Remove Ads IAP.

---

## Archive note

Individual release files (`RELEASE_9.md`, `RELEASE_12.md`, `docs/archive/RELEASE_*.md`) were merged into this document. Use this file as the single source of truth for release history and upload checklists.
