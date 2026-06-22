# Dot Clash — Public launch runbook

**Target:** go live **week of 2026-06-16** (adjust dates as needed)  
**Current baseline:** build **20** (`1.4.2+20`) in closed testing  
**Launch build:** bump to **`1.5.0+21`** (or higher `+N`) — marketing version bump for Challenge a Friend; **never reuse a build number** already uploaded to a store (closed testing uses **`1.4.2+20`**).

**Related docs:** [RELEASES.md](RELEASES.md) · [SETUP.md](../SETUP.md) · [DECISIONS.md](DECISIONS.md) · [architecture.md](architecture.md) · [flutter_firebase_store_release_checklist.md](flutter_firebase_store_release_checklist.md)

---

## Launch definition

| Track | Firebase | Ads | When |
|-------|----------|-----|------|
| **Closed testing** (done / ongoing) | `dot-clash-72cc6` | `BETA_ADS=true` (test units) | Builds 15–20 |
| **Public launch** (this runbook) | `dot-clash-72cc6` | **No `BETA_ADS`** — production AdMob | Build 21+ |

**Do not publish public production with `BETA_ADS`.** See [DECISIONS.md](DECISIONS.md) R-2, R-3.

---

## Success criteria (all must pass before 100% rollout)

- [ ] `flutter analyze --no-fatal-infos` and `flutter test` pass on `main`
- [ ] `cd functions && npm run build && npm run lint` pass
- [ ] Prod backend deployed: functions + rules + indexes on `dot-clash-72cc6`
- [ ] `processChallengeTimeouts` scheduler runs without recurring HTTP 500 (Cloud Logging)
- [ ] Two-device Challenge matrix passed on **launch build** (iOS + Android)
- [ ] Real-ad prod build verified on both platforms (interstitial, rewarded, UMP consent)
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
| **Wed** | Launch build (`1.5.0+21`) + real-ad device QA | Build without `BETA_ADS`; full smoke on 2 phones |
| **Thu** | Store submission | Upload AAB + IPA; submit for review; staged rollout config |
| **Fri** | Publish (if approved) + monitor | Start 5–20% Android; iOS release; watch Crashlytics 24h |
| **Sat–Sun** | Soak + ramp | Increase rollout if crash-free ≥ 99%; respond to reviews |

---

## Gate 0 — Code & CI (Mon morning)

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

- [ ] All commands exit 0
- [ ] No uncommitted hotfixes needed for launch (or cherry-pick only P0/P1)
- [ ] `pubspec.yaml` version bumped for launch (`1.5.0+21` minimum; must exceed closed-testing `+20`)
- [ ] GitHub Actions green on latest `main` commit

---

## Gate 1 — Closed testing sign-off (Mon–Tue)

Complete on **build 20** (or latest closed-testing build). Mark each **Pass / Fail / N/A** with date + tester initials.

### Challenge a Friend (two devices, prod Firebase)

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| C1 | Host **Create** → guest **Join** by code | Both reach active 6×6 board; turns alternate | [ ] |
| C2 | Play full match to completion | One result dialog each; `challenge_finished` analytics | [ ] |
| C3 | **Rematch** from result or Challenge hub rival row | New room; both enter play | [ ] |
| C4 | Share **HTTPS link** (`vividmemories-games.github.io/join/{CODE}`) | Guest opens lobby while signed in | [ ] |
| C5 | **FCM tap** (background) | Opens lobby → play when room active | [ ] |
| C6 | **FCM / snackbar** (Android foreground) | In-app invite → JOIN works | [ ] |
| C7 | Reconnect after match **finished** | `recordChallengeMatch` idempotent; history updated | [ ] |
| C8 | Leave mid-match (Home / back / MORE → Exit) | Confirm dialog; **Stay** keeps board; leave → opponent wins | [ ] |
| C9 | Turn timer (~30s) | Turn advances (server or client backup) | [ ] |
| C10 | Challenge hub **Rivalries** + **View all history** | On Challenge hub, not Profile | [ ] |

### Campaign & Quick Match (single device each platform)

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| R1 | Campaign beat level → **Next level** | Fresh board; no flash of finished level | [ ] |
| R2 | Campaign mid-match → Leave | Life **not** consumed | [ ] |
| R3 | Fresh level (0 moves) → Home | No leave dialog | [ ] |
| R4 | Quick match mid-game leave | Generic “Leave match?” copy | [ ] |
| R5 | Shop buy boost | Optimistic coins; button disabled in-flight | [ ] |
| R6 | Daily claim | Feedback + cooldown state | [ ] |

### Auth, compliance, monetization

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| A1 | Google Sign-In (Android) | Profile loads | [ ] |
| A2 | Apple Sign-In (iOS) | Profile loads | [ ] |
| A3 | Guest → later link account | No data loss on expected paths | [ ] |
| A4 | Settings → **Contact us** | Mail app opens (`vividmemoriesgames@gmail.com`) | [ ] |
| A5 | Settings → **Delete my account** (throwaway) | Auth + profile removed | [ ] |
| A6 | Remove Ads IAP (sandbox/TestFlight) | Receipt verified; ads suppressed | [ ] |

**Exit Gate 1:** zero **Fail** on C1–C8 and R1–R4. C9/C10 and A-items strongly recommended.

---

## Gate 2 — Backend & Firebase (Tue)

### Deploy (only if backend changed since last prod deploy)

```bash
cd functions && npm run build && npm run lint
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-72cc6
firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-dev
```

- [ ] Deploy succeeded with no errors
- [ ] `dot-clash-dev` kept in sync (R-4)

### Scheduler health (critical for Challenge)

Cloud Logging filter:

```text
resource.labels.service_name="processchallengetimeouts"
severity>=ERROR
```

- [ ] No recurring HTTP 500 in last 24h after deploy
- [ ] At least one successful scheduled run logged in last 2h

**If scheduler still fails:** client turn-timeout backup limits user impact, but waiting-room expiry and 24h stale abandon may lag — treat as **release blocker** until fixed or explicitly accepted with monitoring.

### App Check (prod)

- [ ] [App Check → Apps](https://console.firebase.google.com/project/dot-clash-72cc6/appcheck/apps) — iOS + Android registered (Play Integrity, App Attest)
- [ ] TestFlight / Play **release** build completes campaign level (callable succeeds — not `UNAUTHENTICATED`)
- [ ] No spike in callable `UNAUTHENTICATED` after launch build upload

### Firestore rules sanity

- [ ] Clients **cannot write** `challenges/{code}` (reads only for host/guest)
- [ ] Economy fields on `profiles/{uid}` not client-writable

---

## Gate 3 — Launch build (Wed)

### Version bump

In `pubspec.yaml`:

```yaml
version: 1.5.0+21   # increment +N for every store upload
```

- [ ] Version name reflects user-visible release (1.5.0 recommended for Challenge launch)
- [ ] Build number (`+21`) higher than closed-testing build 20 and any build already in App Store Connect / Play Console

### Build commands — **public launch (real ads)**

**No `BETA_ADS`.** Do not run `scripts/build_closed_testing.sh` for production.

```bash
cd "/path/to/Dot_Clash"
flutter clean && flutter pub get

# Ensure iOS native AdMob ID is production (not beta script)
bash scripts/set_beta_ads_native.sh off

flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
flutter build ipa --flavor prod --dart-define=FLAVOR=prod --release
```

| Platform | Artifact |
|----------|----------|
| Android | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |
| iOS | `build/ios/ipa/*.ipa` (or Xcode Organizer archive) |

### Real-ad verification (both platforms)

- [ ] Ads show **without** “Test Ad” label
- [ ] UMP consent flow works (EEA test if possible)
- [ ] Interstitial does not show on FTUE levels w1_l01–w1_l04
- [ ] Rewarded ad grants expected reward (life / coins path)
- [ ] Remove Ads IAP still works with production ad units disabled

### Crashlytics

On a **debug/dev** build only (never ship this):

```dart
// FirebaseCrashlytics.instance.crash();
```

On launch build: confirm normal sessions appear in Crashlytics with correct version filter.

- [ ] dSYM / mapping files uploaded (iOS automatic via Xcode; Android via Play)

Re-run **abbreviated** smoke on launch build: C1, C4, R1, A4, A5.

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
- [ ] Version filter set to launch build (`1.5.0+21`)
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

- [ ] Add **build 20** (or launch `+N`) section to [RELEASES.md](RELEASES.md) with store notes and any hotfixes
- [ ] Update [README.md](../README.md) “Current closed testing” → public launch version
- [ ] Archive closed-testing checklist items that are now signed off
- [ ] Optional polish backlog: `/profile/challenge-history` → `/challenge/history`; Challenge daily missions

---

*Created 2026-06-13 for public launch week. Current baseline: build 20 closed testing. Adjust dates and build numbers as the ship date moves.*
