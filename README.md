# Dot Clash

Nostalgia-powered Dots and Boxes — Flutter mobile game with Firebase, AdMob, and in-app purchases.

Full setup (Firebase, flavors, signing, store checklist): **[SETUP.md](SETUP.md)**  
System architecture (local vs Challenge, Firebase map): **[docs/architecture.md](docs/architecture.md)**  
Active closed-testing release tracker: **[docs/RELEASES.md](docs/RELEASES.md)**  
**Public launch runbook:** **[docs/LAUNCH.md](docs/LAUNCH.md)**  
New Mac / laptop migration (keys, keystore, `.p8` map): **[MIGRATION_RUNBOOK.md](MIGRATION_RUNBOOK.md)**

---

## Quick run

Requires [FVM](https://fvm.app) — pinned SDK **3.44.2** in `.fvmrc`:

```bash
dart pub global activate fvm && fvm install

# Daily development (Google test ads, dev Firebase)
fvm flutter run --flavor dev --dart-define=FLAVOR=dev
```

---

## Closed testing builds (Play / TestFlight)

Use **prod** package name, Firebase, and IAP — but **Google test ads** so real-world beta testers don’t trigger invalid AdMob traffic.

**Before each upload:** bump the build number in [`pubspec.yaml`](pubspec.yaml) (current: `1.5.0+23` — the number after `+` must increase every store upload).

Scripts live at the **project root** in `scripts/` (not `android/scripts/`):

```bash
cd "/path/to/Dot_Clash"

# Android AAB → upload to Play Console closed testing
bash scripts/build_closed_testing.sh android

# iOS IPA → upload to TestFlight
bash scripts/build_closed_testing.sh ios

# Both platforms
bash scripts/build_closed_testing.sh
```

**Output**

| Platform | Artifact |
|----------|----------|
| Android | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |
| iOS | `build/ios/ipa/*.ipa` |

**Verify on device:** ads should show a **“Test Ad”** label.

Run this for **every new closed-testing upload**. Do **not** use `BETA_ADS` for public launch.

### Manual equivalent (if the script fails)

```bash
bash scripts/set_beta_ads_native.sh on   # iOS native AdMob ID; skip concern for Android-only

flutter build appbundle \
  --flavor prod \
  --dart-define=FLAVOR=prod \
  --dart-define=BETA_ADS=true \
  --release \
  --android-project-arg=betaAds=true

flutter build ipa \
  --flavor prod \
  --dart-define=FLAVOR=prod \
  --dart-define=BETA_ADS=true \
  --release

bash scripts/set_beta_ads_native.sh off
```

### Local prod + test ads

```bash
bash scripts/set_beta_ads_native.sh on
flutter run --flavor prod --dart-define=FLAVOR=prod --dart-define=BETA_ADS=true --android-project-arg=betaAds=true
bash scripts/set_beta_ads_native.sh off
```

---

## Public launch builds (real ads)

No `BETA_ADS`. Use after AdMob store linking and production release:

```bash
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
flutter build ipa --flavor prod --dart-define=FLAVOR=prod --release
```

---

## Build flavors

| Build | Dart defines | Ads |
|-------|--------------|-----|
| **dev** | `FLAVOR=dev` | Google test units |
| **prod (launch)** | `FLAVOR=prod` | Production AdMob units |
| **prod (closed testing)** | `FLAVOR=prod` + `BETA_ADS=true` | Google test units |

Details and AdMob IDs: [`lib/core/env/app_env.dart`](lib/core/env/app_env.dart)

---

## Current closed testing — build 23 (`1.5.0+23`)

**Gate 3a — ad-flow QA** on prod Firebase with **Google test ads** (`BETA_ADS=true`). Validates rewarded/interstitial integration on real devices before public launch prod ads ([LAUNCH.md](docs/LAUNCH.md) Gate 3b).

| Feature | Notes |
|---------|--------|
| **Rewarded ads polish** | Coin cooldown UI, life-ad disable when full/capped, clearer snackbars |
| **Reward grant reliability** | Earn signal wait + grant only after server success |
| **Challenge presets** | Classic / Blitz / Fortress (from build 20) |
| **Closed testing track** | Play + TestFlight · same as builds 15–20 |

Session notes and QA history: **[docs/summary.md](docs/summary.md)**  
Full build history, checklists, and **store release notes**: **[docs/RELEASES.md](docs/RELEASES.md)**

### Pre-upload smoke (build 23)

- [ ] Logs show `testUnits=true` on device; ads labeled **Test Ad**
- [ ] Shop coin ad → grant; life ad; campaign retry ad (see LAUNCH Gate 3a matrix)
- [ ] Interstitial not on w1_l01–w1_l04
- [ ] Challenge preset smoke: Classic create → join → match (build 20 regression)
- [ ] Prod backend if changed: `firebase deploy --only functions,firestore:rules,firestore:indexes -P dot-clash-72cc6`

---

## Earlier builds (archive)

<details>
<summary>Build 13 — leave match confirmation (<code>1.3.0+13</code>)</summary>

| Item | Notes |
|------|--------|
| **Leave match confirmation** | Home, MORE → Exit, and system back ask before leaving mid-game |
| Campaign copy | Level progress lost; life **not** consumed on abandon |

</details>
