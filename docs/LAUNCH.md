# Dot Clash — Public launch runbook

**Target:** go live **week of 2026-06-16** (adjust dates as needed)  
**Current closed-testing upload:** build **23** (`1.5.0+23`) — `BETA_ADS=true`, Gate 3 ad-flow QA on real devices  
**Public launch (prod ads):** build **`1.5.0+24`** or higher `+N` — **after** public Play / App Store listing + AdMob store link + app review  
**Never reuse a build number** already uploaded to a store (Gate 0/1 QA **build 21** `1.4.3+21`; prior closed testing **build 20** `1.4.2+20`).

**Related docs:** [RELEASES.md](RELEASES.md) · [SETUP.md](../SETUP.md) · [DECISIONS.md](DECISIONS.md) · [architecture.md](architecture.md) · [flutter_firebase_store_release_checklist.md](flutter_firebase_store_release_checklist.md)

---

## Launch definition

| Track | Firebase | Ads | When |
|-------|----------|-----|------|
| **Closed testing** (done / ongoing) | `dot-clash-72cc6` | `BETA_ADS=true` (test units) | Builds 15–20; **23** = Gate 3 ad-flow QA |
| **Public launch** (this runbook) | `dot-clash-72cc6` | **No `BETA_ADS`** — production AdMob | Build **24+** (after AdMob app review) |

**Do not publish public production with `BETA_ADS`.** See [DECISIONS.md](DECISIONS.md) R-2, R-3.

---

## Success criteria (all must pass before 100% rollout)

- [ ] `flutter analyze --no-fatal-infos` and `flutter test` pass on `main`
- [ ] `cd functions && npm run build && npm run lint` pass
- [ ] Prod backend deployed: functions + rules + indexes on `dot-clash-72cc6`
- [ ] `processChallengeTimeouts` scheduler runs without recurring HTTP 500 (Cloud Logging)
- [ ] Two-device Challenge matrix passed on **launch build** (iOS + Android)
- [ ] Gate 3a: rewarded/interstitial **flow** verified on real devices (`BETA_ADS=true`, “Test Ad” label)
- [ ] Gate 3b: **prod** ad units verified on both platforms (after public store listing + AdMob review)
- [ ] Crashlytics forced-crash test on launch build (symbols uploaded)
- [ ] Store listings live: privacy URL, delete-data URL, contact URL, screenshots, age rating
- [ ] Account deletion tested on throwaway account (Settings → Delete my account)
- [ ] Staged rollout started (Android ≤ 20% first day; iOS phased release or manual monitoring)

---

## Week-at-a-glance

Use this as a default schedule; shift days if review times differ.

| Day | Focus | Owner action |
|-----|--------|--------------|
| **Mon** | Sign off build 20 closed testing + fix P0/P1 only | Complete QA matrix below; check Crashlytics for 20 |
| **Tue** | Backend + scheduler verification | Deploy prod if any backend delta; confirm scheduler logs clean |
| **Wed** | Gate 3a closed testing (`1.5.0+23`) + ad-flow QA on real devices | `BETA_ADS=true`; rewarded polish + grant matrix on 2 phones |
| **Post-listing** | Gate 3b prod ads + launch build (`1.5.0+24+`) | No `BETA_ADS`; after AdMob “Add store” + app review |
| **Thu** | Store submission | Upload AAB + IPA; submit for review; staged rollout config |
| **Fri** | Publish (if approved) + monitor | Start 5–20% Android; iOS release; watch Crashlytics 24h |
| **Sat–Sun** | Soak + ramp | Increase rollout if crash-free ≥ 99%; respond to reviews |

---

## Gate 0 — Code & CI (Mon morning) ✅

Signed off **2026-06-23**.

Run from repo root:

```bash
flutter clean && flutter pub get
flutter analyze --no-fatal-infos
flutter test
cd functions && npm run build && npm run lint
```

Optional but recommended before launch:

```bash
dart run tool/validate_levels.dart
dart format --set-exit-if-changed .
```

- [x] All commands exit 0
- [x] No uncommitted hotfixes needed for launch (or cherry-pick only P0/P1)
- [x] `pubspec.yaml` version bumped for launch (`1.4.3+21`; build `+21` exceeds closed-testing `+20`)
- [x] GitHub Actions green on latest `main` commit

---

## Gate 1 — Closed testing sign-off (Mon–Tue) ✅

Complete on **build 21** (`1.4.3+21`). Manual QA signed off **2026-06-23**.

### Challenge a Friend (two devices, prod Firebase)

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| C1 | Host **Create** → guest **Join** by code | Both reach active 6×6 board; turns alternate | [x] |
| C2 | Play full match to completion | One result dialog each; `challenge_finished` analytics | [x] |
| C3 | **Rematch** from result or Challenge hub rival row | New room; both enter play | [x] |
| C4 | Share **HTTPS link** (`vividmemories-games.github.io/join/{CODE}`) | Guest opens lobby while signed in | [x] |
| C5 | **FCM tap** (background) | Opens lobby → play when room active | [x] |
| C6 | **FCM / snackbar** (Android foreground) | In-app invite → JOIN works | [x] |
| C7 | Reconnect after match **finished** | `recordChallengeMatch` idempotent; history updated | [x] |
| C8 | Leave mid-match (Home / back / MORE → Exit) | Confirm dialog; **Stay** keeps board; leave → opponent wins | [x] |
| C9 | Turn timer (~30s) | Turn advances (server or client backup) | [x] |
| C10 | Challenge hub **Rivalries** + **View all history** | On Challenge hub, not Profile | [x] |

### Campaign & Quick Match (single device each platform)

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| R1 | Campaign beat level → **Next level** | Fresh board; no flash of finished level | [x] |
| R2 | Campaign mid-match → Leave | Life **not** consumed | [x] |
| R3 | Fresh level (0 moves) → Home | No leave dialog | [x] |
| R4 | Quick match mid-game leave | Generic “Leave match?” copy | [x] |
| R5 | Shop buy boost | Optimistic coins; button disabled in-flight | [x] |
| R6 | Daily claim | Feedback + cooldown state | [x] |

### Auth, compliance, monetization

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| A1 | Google Sign-In (Android) | Profile loads | [x] |
| A2 | Apple Sign-In (iOS) | Profile loads | [x] |
| A3 | Guest → later link account | No data loss on expected paths | [x] |
| A4 | Settings → **Contact us** | Mail app opens (`vividmemoriesgames@gmail.com`) | [x] |
| A5 | Settings → **Delete my account** (throwaway) | Auth + profile removed | [x] |
| A6 | Remove Ads IAP (sandbox/TestFlight) | Receipt verified; ads suppressed | [x] |

**Exit Gate 1:** zero **Fail** on C1–C8 and R1–R4. C9/C10 and A-items strongly recommended. **Passed 2026-06-23** — all C/R/A scenarios pass.

---

## Gate 2 — Backend & Firebase (Tue) ✅

Signed off **2026-06-23**.

### Deploy (only if backend changed since last prod deploy)

```bash
cd functions && npm run build && npm run lint
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-72cc6
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-dev
```

- [x] Deploy succeeded with no errors
- [x] `dot-clash-dev` kept in sync (R-4)

### Scheduler health (critical for Challenge)

Cloud Logging filter:

```text
resource.labels.service_name="processchallengetimeouts"
severity>=ERROR
```

- [x] No recurring HTTP 500 in last 24h after deploy
- [x] At least one successful scheduled run logged in last 2h

**If scheduler still fails:** client turn-timeout backup limits user impact, but waiting-room expiry and 24h stale abandon may lag — treat as **release blocker** until fixed or explicitly accepted with monitoring.

### App Check (prod)

- [x] [App Check → Apps](https://console.firebase.google.com/project/dot-clash-72cc6/appcheck/apps) — iOS + Android registered (Play Integrity, App Attest)
- [x] TestFlight / Play **release** build completes campaign level (callable succeeds — not `UNAUTHENTICATED`)
- [x] No spike in callable `UNAUTHENTICATED` after launch build upload

### Firestore rules sanity

- [x] Clients **cannot write** `challenges/{code}` (reads only for host/guest)
- [x] Economy fields on `profiles/{uid}` not client-writable

---

## Gate 3 — Ads & launch build

AdMob **account** may be approved while each app still shows **Requires review** until it is linked to a **public** store listing. Prod units on real devices can return `No ad to show` until then — that is expected. Use **Gate 3a** (beta ads) for integration QA now; **Gate 3b** (prod ads) after public listing + AdMob app review.

---

### Gate 3a — Closed testing ad-flow QA (build 23) — **in progress**

**Target:** **`1.5.0+23`** (build **23** — exceeds Gate 0/1 QA **+21** and closed-testing **+20**).

**Track:** prod Firebase + IAP, **`BETA_ADS=true`** (Google test units). Ads must show **“Test Ad”** label.

#### Version bump

In `pubspec.yaml`:

```yaml
version: 1.5.0+23   # increment +N for every store upload
```

- [x] Version name `1.5.0` (Challenge launch marketing version)
- [x] Build number `+23` higher than QA build 21 and prior closed-testing uploads

#### Build commands — closed testing (test ads)

```bash
cd "/path/to/Dot_Clash"
flutter clean && flutter pub get

bash scripts/build_closed_testing.sh          # both platforms
bash scripts/build_closed_testing.sh android
bash scripts/build_closed_testing.sh ios
```

Script runs `set_beta_ads_native.sh on` for iOS, passes `--dart-define=BETA_ADS=true`, and cleans up on exit.

**Local real-device debug (same ad config):**

```bash
bash scripts/set_beta_ads_native.sh on
fvm flutter run --flavor prod \
  --dart-define=FLAVOR=prod \
  --dart-define=BETA_ADS=true \
  --android-project-arg=betaAds=true
bash scripts/set_beta_ads_native.sh off
```

| Platform | Artifact |
|----------|----------|
| Android | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |
| iOS | `build/ios/ipa/*.ipa` |

Upload to Play **closed testing** / **TestFlight**; install on **≥2 real devices** (1 iOS + 1 Android).

#### Log sanity (device console)

Filter for:

```text
[AdConsent] canRequestAds=true
testUnits=true
[AdMobAdService] onUserEarnedReward
[AdReward]
[Callable] claimRewardedAd
```

Must **not** see prod-only `No ad to show` on test units. If `testUnits=false`, the build was not compiled with `BETA_ADS=true` (or iOS native override missing).

#### Ad-flow verification matrix (real devices, test ads)

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| G3a-1 | Shop → **Watch ad for coins** (first watch) | “Test Ad” opens; +35 coins; `[Callable] claimRewardedAd succeeded` | [ ] |
| G3a-2 | Shop → coin ad again within **30 min** | Button disabled / cooldown copy; or watch → grant rejected (`cooldown`) | [ ] |
| G3a-3 | Shop / lives sheet → **life ad** at &lt;5 lives | “Test Ad” opens; life granted; daily counter only on success | [ ] |
| G3a-4 | Life ad at **5 lives** | Button disabled (“Lives full” / greyed) | [ ] |
| G3a-5 | **3 life ads** in one UTC day | 4th disabled; cap message | [ ] |
| G3a-6 | Campaign loss → **Watch ad · retry** | Ad opens; life refunded; replay works | [ ] |
| G3a-7 | Dismiss ad early (no full watch) | No grant; clear snackbar; daily counters unchanged | [ ] |
| G3a-8 | Post-match **interstitial** | **Not** on w1_l01–w1_l04; shows on later matches | [ ] |
| G3a-9 | **UMP** consent | `canRequestAds=true` after flow (EEA test if possible) | [ ] |
| G3a-10 | **Remove Ads** IAP (sandbox) | Purchase succeeds; interstitials suppressed | [ ] |

**Exit Gate 3a:** zero **Fail** on G3a-1, G3a-3, G3a-6, G3a-8. G3a-2/4/5/7/9/10 strongly recommended.

Re-run abbreviated Challenge smoke on build 23: **C1, C4, R1, A4, A5**.

#### Crashlytics (build 23)

- [ ] Normal sessions appear in Crashlytics with version filter `1.5.0+23`
- [ ] dSYM / mapping uploaded with TestFlight / Play upload

**Prerequisites done (AdMob publisher):**

- [x] Payment profile complete
- [x] Account approved
- [x] app-ads.txt verified (`vividmemories-games.github.io`)

**Still blocking prod ads (Gate 3b):**

- [ ] Public Google Play listing (internal/closed-only is **not** searchable in AdMob “Add store”)
- [ ] AdMob **Add store** linked per platform
- [ ] App **Requires review** badge cleared

---

### Gate 3b — Prod ads launch build — **blocked until store listing**

**Target:** **`1.5.0+24`** (or next unused `+N`) — **no `BETA_ADS`**.

Run only after:

1. Production track on **Google Play** (staged rollout OK)
2. **App Store** listing path for iOS
3. AdMob **Add store** succeeds (allow **24–48h** after going public)
4. AdMob app review passes (no **Requires review**)

#### Build commands — public launch (real ads)

```bash
cd "/path/to/Dot_Clash"
flutter clean && flutter pub get

bash scripts/set_beta_ads_native.sh off   # ensure iOS prod AdMob app ID

flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
flutter build ipa --flavor prod --dart-define=FLAVOR=prod --release
```

**Do not** run `scripts/build_closed_testing.sh` for public launch.

#### Prod-ad verification (both platforms)

- [ ] Ads show **without** “Test Ad” label
- [ ] No sustained `No ad to show` on rewarded load (check `[AdMobAdService] Rewarded failed`)
- [ ] UMP consent flow works (EEA test if possible)
- [ ] Interstitial does not show on FTUE levels w1_l01–w1_l04
- [ ] Rewarded grants (life / coins / retry) after full watch
- [ ] Remove Ads IAP still works with production ad units

On a **debug/dev** build only (never ship forced crash):

```dart
// FirebaseCrashlytics.instance.crash();
```

---

## Gate 4 — Store consoles (Wed–Thu)

### Both platforms

- [ ] App icon 1024×1024 (no alpha on iOS)
- [ ] Screenshots updated — nostalgia + online Challenge + campaign (ASO: dots and boxes, classic school game)
- [ ] Short + long description matches shipped features (see store copy below)
- [ ] Privacy policy: `https://vividmemories-games.github.io/privacy-policy/`
- [ ] Delete data: `https://vividmemories-games.github.io/delete-data/`
- [ ] Contact: `https://vividmemories-games.github.io/contact/`
- [ ] Legal site published from [vividmemories-games.github.io](https://github.com/vividmemories-games/vividmemories-games.github.io) repo

### Google Play

- [ ] Data safety form: analytics, ads, crash reporting declared
- [ ] Content rating questionnaire current
- [ ] AdMob app linked to production package
- [ ] **Staged rollout** enabled — start **5–20%**, not 100%
- [ ] Pre-launch report reviewed (internal track first if needed)

### Apple App Store Connect

- [ ] Privacy nutrition labels match data collection
- [ ] Sign in with Apple present (required — Google sign-in offered)
- [ ] Push Notifications capability + `aps-environment` production
- [ ] App Review notes: test account or steps to reach Challenge (if needed)
- [ ] **Phased release** or manual release after approval

### Deep links / App Links

- [ ] `assetlinks.json` (Android) — SHA-256 fingerprints current for release keystore
- [ ] `apple-app-site-association` (iOS) — paths include `/join/*`
- [ ] Live test: tap `https://vividmemories-games.github.io/join/TESTCODE` on device with app installed

---

## Gate 5 — Publish & rollout (Fri+)

### Android staged rollout

1. Promote launch AAB to **Production** with staged rollout **5%** (or 20% if closed testing was very clean).
2. Monitor **24 hours** minimum before increasing percentage.

| Checkpoint | Threshold | Action |
|------------|-----------|--------|
| Crash-free users | ≥ 99% | OK to increase rollout |
| ANR rate | No spike vs baseline | Investigate before ramp |
| Callable errors | No sustained `submitChallengeMove` failures | Roll back if user-facing |
| Reviews | 1-star cluster on Challenge | Pause ramp; triage |

Rollout ramp suggestion: **5% → 20% → 50% → 100%** (wait 24–48h between steps).

### iOS

- Release when approved; prefer **phased release over 7 days** if available.
- Monitor App Store Connect crashes + Firebase Crashlytics in parallel.

### Post-launch monitoring (first 7 days)

Watch daily:

| Signal | Where |
|--------|--------|
| Crashes / ANRs | Firebase Crashlytics, Play Vitals, App Store Connect |
| Challenge funnel | Analytics: `challenge_started`, `challenge_finished` |
| Callable failures | Cloud Logging — `submitChallengeMove`, `recordChallengeMatch`, `createChallenge` |
| Scheduler | `processChallengeTimeouts` errors |
| App Check denials | Callable logs with `UNAUTHENTICATED` |
| Ad fill / policy | AdMob console |

- [ ] Crashlytics alert email configured
- [ ] Version filter set to launch build (`1.5.0+24` or current prod-ad build)
- [ ] Rollback decision owner assigned (you)

---

## Rollback plan

| Platform | Fast mitigation |
|----------|-----------------|
| **Android** | Halt staged rollout; promote previous stable AAB to 100% |
| **iOS** | Remove from sale or expedite fix build; cannot “roll back” binary — prepare hotfix build |
| **Firebase** | Avoid breaking rule/callable deploys during rollout; keep previous function revision notes |
| **Challenge outage** | Communicate via store “What’s New” only after fix — no server-side kill switch today |

Prepare before launch:

- [ ] Note last known-good store build numbers (Android + iOS)
- [ ] Hotfix branch ready from `main` tag
- [ ] Backend deploy rollback procedure documented if a bad functions deploy ships

---

## Store release notes (launch)

Use or adapt from [RELEASES.md](RELEASES.md) build 20 section.

**Short (What’s New)**

> **Challenge a Friend** — play live Dots & Boxes online with a friend. Share a link or 6-digit code, battle on a 6×6 board, and keep the rivalry going with rematch and head-to-head stats on the Challenge hub.  
> Remember this game from class? Grab a friend and settle the score.

**Bullets**

- **Challenge a Friend** — live online 6×6 matches with 30-second turns
- Invite by **link or code**; jump in from notifications
- **Rematch** rivals and track your **series (W–L–T)** on the Challenge hub
- Campaign, daily puzzle, and quick match — classic notebook nostalgia, polished for mobile

**Do not promise**

- Coins, XP, or lives from Challenge matches
- Push to brand-new rivals (recent-rival gate)
- Public matchmaking or in-app friend lists

---

## Support cheat sheet (known behavior)

| User report | Response |
|-------------|----------|
| “No push when I challenged a new friend” | By design — push only for **recent rivals**; share link/code instead |
| “Challenge didn’t give coins” | By design — Challenge is history/H2H only (v1) |
| “Turn didn’t advance after 30s” | Server timeout + client backup; ask for app version + approximate time |
| “Link opened browser, not app” | Check App Links / reinstall; verify signed-in state |
| “Campaign used a life when I left” | Should not — confirm steps; file bug if reproducible on latest build |

---

## Command cheat sheet

```bash
# Local verification
flutter analyze --no-fatal-infos && flutter test
cd functions && npm run build && npm run lint

# Closed testing (NOT for public launch)
bash scripts/build_closed_testing.sh

# Public launch builds
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
flutter build ipa --flavor prod --dart-define=FLAVOR=prod --release

# Prod backend deploy (explicit approval)
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-72cc6

# Challenge-focused tests
flutter test test/challenge/ test/deep_links/challenge_link_parser_test.dart test/game/rules_test.dart
```

---

## Launch day checklist (printable)

**Morning of publish**

- [ ] Confirm store review **Approved** (both platforms)
- [ ] Confirm launch build number matches uploaded binary
- [ ] Backend prod deploy matches client (no pending functions diff)
- [ ] Scheduler logs clean (last 2h)
- [ ] Crashlytics dashboard open; version filter set
- [ ] Rollback: previous build number written down

**Publish**

- [ ] Android: start staged rollout (≤ 20%)
- [ ] iOS: release with phased rollout if available
- [ ] Verify production listing URLs load on mobile

**First 4 hours**

- [ ] Install from store (or production track) — not sideload — and run C1 + real ad check
- [ ] No P0 Crashlytics issues
- [ ] Spot-check Play / App Store reviews

**First 24 hours**

- [ ] Crash-free ≥ 99% → OK to ramp Android rollout
- [ ] Log any Challenge-specific support tickets
- [ ] Record launch build in [RELEASES.md](RELEASES.md)

---

## After launch

- [ ] Add launch `+N` section to [RELEASES.md](RELEASES.md) with store notes and any hotfixes
- [ ] Update [README.md](../README.md) “Current closed testing” → public launch version when Gate 3b ships
- [ ] Archive closed-testing checklist items that are now signed off
- [ ] Optional polish backlog: `/profile/challenge-history` → `/challenge/history`; Challenge daily missions

---

*Created 2026-06-13 for public launch week. Updated 2026-06-23: Gate 3 split (3a build 23 beta ads / 3b prod ads post-listing). Adjust dates and build numbers as the ship date moves.*
