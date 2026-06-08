# Dot Clash

Nostalgia-powered Dots and Boxes — Flutter mobile game with Firebase, AdMob, and in-app purchases.

Full setup (Firebase, flavors, signing, store checklist): **[SETUP.md](SETUP.md)**  
Active closed-testing release tracker: **[docs/RELEASES.md](docs/RELEASES.md)**  
New Mac / laptop migration (keys, keystore, `.p8` map): **[docs/MIGRATION_RUNBOOK.md](docs/MIGRATION_RUNBOOK.md)**

---

## Quick run

```bash
# Daily development (Google test ads, dev Firebase)
flutter run --flavor dev --dart-define=FLAVOR=dev
```

---

## Closed testing builds (Play / TestFlight)

Use **prod** package name, Firebase, and IAP — but **Google test ads** so real-world beta testers don’t trigger invalid AdMob traffic.

**Before each upload:** bump the build number in [`pubspec.yaml`](pubspec.yaml) (`version: 1.1.0+4` — the number after `+` must increase every store upload).

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

## Release 13 (next upload — `1.3.0+13`)

Ship after **Release 12** (`1.3.0+12`) is in TestFlight / Play closed testing.

### What's in R13

| Item | Notes |
|------|--------|
| **Leave match confirmation** | Home, MORE → Exit, and system back ask before leaving mid-game |
| Campaign copy | Clarifies level progress is lost; life is **not** consumed on abandon |

### Pre-upload smoke (R13)

- [ ] Start campaign level, make a move → tap **Home** → dialog → **Stay** keeps board
- [ ] Same → **Leave** exits without consuming a life
- [ ] Fresh level (no moves) → Home exits with no dialog
- [ ] Android/iOS **back gesture** shows the same dialog mid-match
- [ ] Quick match / vs AI: generic “Leave match?” copy

Full release history and checklists: **[docs/RELEASES.md](docs/RELEASES.md)**
