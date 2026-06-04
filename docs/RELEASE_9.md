# Release 9 — Closed testing (TestFlight / Play)

**App version:** `1.1.0+9` (`pubspec.yaml`)  
**Track:** Prod package + Firebase (`dot-clash-72cc6`), `BETA_ADS=true` (test ads)  
**Prior release docs:** [archive/RELEASE_6.md](archive/RELEASE_6.md), [archive/RELEASE_7.md](archive/RELEASE_7.md) (retired)

---

## Already live (R6–R8 baseline — do not re-test from scratch)

| Area | Status |
|------|--------|
| Shop cosmetics (8 themes / avatars / initials) | Shipped R6 |
| Server-side economy + IAP verification | Shipped R7 |
| Remove Ads via `verifyRemoveAdsPurchase` | Working on TestFlight (PEM normalize + sandbox fallback deployed) |
| Campaign exit crashes / coach tour cleanup | Shipped **+8** |
| Shop IAP error snackbar + Android purchase sheet retry | Shipped **+8** |

**IAP / ops reference:** `SETUP.md` §4b (Apple secrets, Play API access).

---

## Release 9 scope

### Tester feedback

| # | Report | Platform | Status | Notes / fix |
|---|--------|----------|--------|-------------|
| 1 | Try Again shows final board state | iOS/Android | **Fixed** | `exitToReplayLevel` replaces play route; lives check before replay |
| 2 | Lives sheet frozen after coin purchase | iOS/Android | **Fixed** | `LivesRefillSheet` watches `livesSnapshotProvider` |
| 3 | Snackbar more prominent / bordered | iOS/Android | **Fixed** | `snackBarTheme` + `AppSnackBar` helper |
| 4 | Timer/game continues when app minimized | iOS/Android | **Fixed** | Lifecycle pauses timer/AI; foreground **resumes** countdown (not full reset) |
| 5 | Riposte popup repeats without new chain | iOS/Android | **Fixed** | `lastAiSegmentBoxCount` instead of `aiMaxChainBoxes` |
| — | Duplicate `GlobalKey` on campaign exit (coach tour) | iOS/Android | **Fixed** | Scoped match keys + release before `router.go` |

### Done (R9)

- All five tester items above (build **+9**)
- Build number **+9** for closed-testing upload
- Release docs: R6/R7 archived

---

## Build & upload

```bash
cd "/path/to/Dot_Clash"
# Bump version in pubspec.yaml before each store upload (currently 1.1.0+9)

bash scripts/build_closed_testing.sh          # both
bash scripts/build_closed_testing.sh android
bash scripts/build_closed_testing.sh ios
```

| Platform | Artifact |
|----------|----------|
| Android | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |
| iOS | `build/ios/ipa/*.ipa` |

**Pre-upload checklist**

- [ ] `pubspec.yaml` build number incremented
- [ ] Prod functions deployed if backend changed: `firebase deploy --only functions -P dot-clash-72cc6`
- [ ] Smoke: campaign loss → Try Again (fresh board); lives sheet updates on buy; minimize app (timer pauses); riposte only after 3+ chain
- [ ] Crashlytics: filter **1.1.0 (9)** after rollout

---

## Crashlytics watch (prod)

After **+9** is in testers’ hands, confirm these drop vs **1.1.0 (7)**:

- `ref` after disposed — `game_screen.dart` `runSave`
- `permission-denied` — should fall as old builds age out (R7+ client uses callables on prod)

Firebase Console → Crashlytics → filter version **1.1.0 (9)**.

---

## Store notes (draft)

- Try Again restarts the level from a clean board (when you have lives)
- Lives refill sheet stays in sync when you buy a life
- Match timer pauses when you leave the app
- Riposte offer only after a real rival combo
- Clearer in-game messages (bordered snackbars)
- Remove Ads purchase fix for TestFlight testers
- Stability when leaving campaign

---

## Security / architecture

Ongoing hardening notes: [`SECURITY_FIX_PLAN.md`](SECURITY_FIX_PLAN.md)  
Release 7 security plan: [`.cursor/plans/release_7_security_133b2307.plan.md`](../.cursor/plans/release_7_security_133b2307.plan.md)
