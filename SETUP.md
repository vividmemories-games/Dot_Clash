# Dot Clash — Setup Guide

## Prerequisites

| Tool | Min version |
|---|---|
| Flutter | 3.24+ |
| Dart | 3.4+ |
| Firebase CLI | 13+ |
| FlutterFire CLI | 1.0+ |
| Node.js | 22+ (Cloud Functions runtime) |

---

## 1 · Create the Flutter project scaffold

Run this **once** from inside the `Dot_Clash/` folder to generate the platform directories (`android/`, `ios/`, etc.). The Dart source code in `lib/` already exists and won't be overwritten.

```bash
flutter create . --project-name dot_clash --org com.yourcompany
flutter pub get
```

> **Tip:** Change `com.yourcompany` to your real reverse-domain bundle ID.

---

## 2 · Set up Firebase

### 2a — Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com) → **Add project**.
2. Enable **Google Analytics** when prompted.
3. Add **Android** and **iOS** apps to the project using the bundle ID you chose above.

### 2b — Configure the Flutter app

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This overwrites `lib/firebase_options.dart` with real credentials.

### 2c — Enable Firebase services

In the Firebase console, enable:
- **Authentication** → Anonymous sign-in (optional guest play)
- **Authentication** → **Google** sign-in (support email + OAuth consent in GCP as needed)
- **Firestore** → create in production mode (rules are already in `firestore.rules`)
- **Cloud Messaging** (FCM)
- **Crashlytics**
- **Analytics**

### 2d — Deploy Firestore rules, indexes, and Cloud Functions

```bash
# From the project root
firebase deploy --only firestore:rules,firestore:indexes

# From the functions/ directory
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

### 2e — Campaign MVP (first production deploy)

**Callable functions** (client must use these for rewards; Firestore rules block direct writes to campaign fields):

| Function | Purpose |
|----------|---------|
| `completeCampaignLevel` | Stars, coins, XP, lives on campaign win/loss |
| `completeDailyPuzzle` | Daily puzzle completion + streak |
| `claimDailyMission` | Claim daily mission coin rewards |
| `deleteUserData` | In-app account deletion (Auth + Firestore profile/matches) |

**Contact support:** In-app **Settings → Contact us** opens the device mail app via `mailto:` (`AppEnv.contactEmail`). No Cloud Function or Trigger Email extension required.

**Pre-launch compliance checklist:**

1. Deploy functions + Firestore rules: `firebase deploy --only functions,firestore:rules`
2. Set `AppEnv.contactEmail` to your real support address before release
3. Test **Settings → Contact us** (opens Mail/Gmail) and **Delete my account** on a throwaway guest account
4. Publish Jekyll site from **`vividmemories-games.github.io`** repo (GitHub Pages) — verify URLs match `lib/core/env/app_env.dart`
5. **AdMob → Privacy & messaging:** publish UMP form; set privacy policy URL; enable **Privacy options** entry point
6. **App Store / Play Console:** privacy policy URL, delete-data URL (`/delete-data/`), contact URL (`/contact/`)

**Seed campaign content to Firestore** (optional; app also loads bundled `assets/campaign/`):

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
npx ts-node scripts/seed_campaign.ts
```

**Validate bundled levels before release:**

```bash
dart run tool/validate_levels.dart
```

**Test routes:** `/campaign`, `/campaign/play/w1_l01`, `/daily-puzzle`

### 2f — App Check (required for Cloud Functions)

The app activates App Check after Firebase init (`lib/services/firebase/app_check_service.dart`):

| Build | Providers |
|-------|-----------|
| `FLAVOR=dev` or debug | Android / Apple **debug** |
| `FLAVOR=prod` release | **Play Integrity** + **App Attest** (Device Check fallback) |

**One-time console setup (per Firebase project: `dot-clash-dev` and `dot-clash-72cc6`):**

1. [App Check → Apps](https://console.firebase.google.com/project/dot-clash-dev/appcheck/apps) (use `dot-clash-72cc6` for prod).
2. For **each** iOS and Android app: **Register** → choose the **Debug** provider (required for simulators; do this *before* adding tokens).
3. **Manage debug tokens → Add** (see below).
4. **APIs tab (Firestore, Auth, etc.):** you can set **Monitoring** or **Enforced** per product there. That list does **not** include a Monitor/Enforce toggle for **Cloud Functions** — only a “View docs” link. That is expected.
5. **Cloud Functions** are **gen-2** callables in `us-central1` with `invoker: 'public'` (required for mobile clients). App Check is enforced in code on **prod** only (`enforceAppCheck` when `GCLOUD_PROJECT=dot-clash-72cc6`). There is no separate console toggle for Functions on the APIs tab.
6. **Prod release:** no debug token — use Play Integrity / App Attest; register those providers instead of Debug.

**Recommended dev flow (fixed token — easiest on iOS Simulator):**

```bash
uuidgen   # copy the UUID
```

1. In Firebase Console → App Check → your **iOS dev** app (`com.vividmemories.dotclash.dev`) → **Manage debug tokens** → paste the UUID → Save.
2. Run:

```bash
flutter run --flavor dev --dart-define=FLAVOR=dev \
  --dart-define=APP_CHECK_DEBUG_TOKEN=PASTE-UUID-HERE
```

Fully stop and restart the app after adding a token (hot reload is not enough).

**iOS Simulator note:** Device Check does not work on simulators. The build copies your
`APP_CHECK_DEBUG_TOKEN` into the app `Info.plist` (`ios/scripts/inject_app_check_debug_token.sh`)
and `AppDelegate` sets `FIRAAppCheckDebugToken` before Firebase starts. If you see
`DeviceCheckProvider is not supported`, run a **full rebuild** (not hot restart) with
`--dart-define=APP_CHECK_DEBUG_TOKEN=...` after registering the token in the console.

**If you see `403` / `App attestation failed` on `exchangeDebugToken`:**

- The Flutter code is fine; Firebase has not allowlisted this simulator’s debug token yet.
- Confirm the **Debug** provider is registered for app id `1:218032510167:ios:fb46cd859a0b04fc41cc92` (dev iOS).
- Add the token under **Manage debug tokens** for that same app (not only the Android app).
- To read the auto-generated token from Xcode: run the app, open **View → Debug Area → Activate Console**, filter for `Firebase App Check Debug Token`.

Until the token is registered, Cloud Functions with App Check enforcement may return `UNAUTHENTICATED`; campaign progress still saves via the Firestore fallback.

**Callable `UNAUTHENTICATED` but `authUid` is set in logs:** the client is signed in; the function rejected the HTTP request (almost always **App Check** on Cloud Functions, not missing login). Fix:

1. Register the debug token for the **iOS dev** app (`fb46cd859a0b04fc41cc92`).
2. Redeploy **dev** functions (gen-2; delete old gen-1 callables if deploy complains about upgrade):

```bash
firebase use dev
firebase functions:delete completeCampaignLevel completeDailyPuzzle claimDailyMission --region us-central1 --force
firebase deploy --only functions
```

3. Full restart the app with `--dart-define=APP_CHECK_DEBUG_TOKEN=...`.

**Still `UNAUTHENTICATED` with `appCheckToken=true`?** There is no App Check “Functions → Monitor” control in the console. Check: (a) debug token registered for iOS dev app `1:218032510167:ios:fb46cd859a0b04fc41cc92`, (b) latest dev functions deployed, (c) terminal shows `idTokenAud` matching `dot-clash-dev`. If the message were `Sign in first.`, the handler ran but `context.auth` was missing — a different issue.

---

## 3 · AdMob setup

The app always uses **AdMob** (no mock ad dialogs). Ad unit IDs are selected by build flavor in [`lib/core/env/app_env.dart`](lib/core/env/app_env.dart):

| Flavor | Dart defines | Ad units | Native app ID |
|--------|--------------|----------|----------------|
| **dev** | `FLAVOR=dev` | Google **test** units (publisher `3940256099942544`) | `android/app/src/dev/AndroidManifest.xml`, iOS `*-dev.xcconfig` |
| **prod** | `FLAVOR=prod` | Your **production** units (publisher `6626056478655263`) | `android/app/src/main/AndroidManifest.xml`, iOS `*-prod.xcconfig` |
| **prod + closed testing** | `FLAVOR=prod` + `BETA_ADS=true` | Google **test** units (same as dev) | Use [`scripts/build_closed_testing.sh`](scripts/build_closed_testing.sh) |

1. Create an AdMob account at [admob.google.com](https://admob.google.com).
2. Create **Android + iOS** apps for package/bundle `com.vividmemories.dotclash` (prod only — do not create AdMob apps for `.dev`).
3. Create **Interstitial** and **Rewarded** units per platform; prod IDs live in `app_env.dart` (`_prod*` constants).
4. **Run dev with test ads:**
   ```bash
   flutter run --flavor dev --dart-define=FLAVOR=dev
   ```
   You should see Google **“Test Ad”** labels. Never use prod flavor for day-to-day dev unless you intend real impressions.
5. **Closed testing (Play / TestFlight) with real-world testers** — prod package/Firebase/IAP, but **test ads** (AdMob-policy safe):
   ```bash
   bash scripts/build_closed_testing.sh          # Android AAB + iOS IPA
   bash scripts/build_closed_testing.sh android  # AAB only
   bash scripts/build_closed_testing.sh ios      # IPA only
   ```
   **Do not** pass `BETA_ADS=true` on public launch builds.

   Local prod+beta run (iOS needs native override first):
   ```bash
   bash scripts/set_beta_ads_native.sh on
   flutter run --flavor prod --dart-define=FLAVOR=prod --dart-define=BETA_ADS=true --android-project-arg=betaAds=true
   bash scripts/set_beta_ads_native.sh off   # when done
   ```
6. **UMP (EEA consent):** Publish a GDPR message in AdMob → **Privacy & messaging** with your [Privacy Policy](https://vividmemories-games.github.io/privacy-policy/) URL. Consent runs in `AdConsentService` before `MobileAds.initialize()`. Simulator testing: `--dart-define=UMP_DEBUG_GEOGRAPHY=eea` (optional `UMP_TEST_DEVICE_IDS` from log output on a real device).

**Rewarded ads (dev + prod, same code):** `AdMobAdService` returns success only after AdMob `onUserEarnedReward` (waits up to 8s after dismiss on iOS). `AdRewardRouter` then grants by placement (shop +35 coins, retry +1 life, etc.) — ignore test-ad “10 coins” in logs.

---

## 4 · In-App Purchases

### 4a — Store products (one-time)

**Android (Google Play)**

1. Open [Google Play Console](https://play.google.com/console) → select **Dot Clash** (prod package `com.vividmemories.dotclash`).
2. **Test and release** → upload at least one signed **AAB** to **Internal testing** (required before IAP goes live).
3. **Monetize** → **Products** → **In-app products** → **Create product**.
4. Product ID: `dot_clash_remove_ads` · Type: **One-time** (non-consumable) · set price (e.g. Norway tier for beta testers).

**iOS (App Store Connect)**

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **Dot Clash**.
2. **Monetization** (or **Features**) → **In-App Purchases** → **+** → **Non-Consumable**.
3. Reference name: e.g. `Remove Ads` · Product ID: `dot_clash_remove_ads` · set pricing (per territory, e.g. Norway).
4. In Xcode: **Runner** target → **Signing & Capabilities** → **+ Capability** → **In-App Purchase** (if not already present).

Product IDs must match `AppEnv.iapRemoveAds` in `lib/core/env/app_env.dart`.

---

### 4b — Server-side IAP verification (Release 7)

After Firestore rules lock `removeAds` to the server, purchases must go through the callable **`verifyRemoveAdsPurchase`**. That function calls **Apple** and **Google** to confirm the receipt before writing `removeAds: true`.

| Platform | What you configure | Used by |
|----------|-------------------|---------|
| **iOS** | App Store Connect **API** key + Firebase env vars | App Store Server API |
| **Android** | Play Console **API access** for the Cloud Functions service account | Google Play Developer API |

**Not** the same as the Apple **Developer** Auth Key in `ios/Security Key/` (Sign in with Apple). IAP uses a separate key from **App Store Connect → Integrations**.

**Dev vs prod**

| Project | `GCLOUD_PROJECT` | If secrets / Play API missing |
|---------|------------------|-------------------------------|
| `dot-clash-dev` | dev | Verification **skipped** (logs a warning) |
| `dot-clash-72cc6` | prod | Verification **required** — Remove Ads fails without setup |

---

#### iOS — App Store Connect API key (click-by-click)

1. Go to [App Store Connect](https://appstoreconnect.apple.com).
2. Top navigation: **Users and Access** (not the per-app screen).
3. Open the **Integrations** tab.
4. Left sidebar: **App Store Connect API**.
5. Under **Team Keys**, click **+** (Generate API Key) or **Generate API Key**.
6. Name: e.g. `Dot Clash IAP Server` · Access: **Admin** or **App Manager** (must be allowed to use In-App Purchase / transaction APIs for your team).
7. Click **Generate** → **Download** the `.p8` file **once** (Apple will not offer it again).
8. On the same **Integrations → App Store Connect API** page, copy:
   - **Issuer ID** (top of the page, UUID)
   - **Key ID** (column for the key you just created, 10 characters)

Keep the `.p8` local only (same rules as `ios/Security Key/` — never commit).

---

#### iOS — Set secrets on prod Cloud Functions

The function reads `process.env.APPLE_IAP_*` in `functions/src/iap.ts`. Configure them for project **`dot-clash-72cc6`** only (prod).

**Option A — env file at deploy (recommended)**

1. Create `functions/.env.dot-clash-72cc6` (gitignored; do not commit):

   ```bash
   APPLE_IAP_KEY_ID=ABCD123456
   APPLE_IAP_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   APPLE_IAP_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIGT...\n-----END PRIVATE KEY-----"
   APPLE_IAP_BUNDLE_ID=com.vividmemories.dotclash
   ```

   Use `\n` for line breaks inside the private key string, or paste the full `.p8` body on one line with `\n` between lines.

2. Deploy functions to prod:

   ```bash
   firebase use prod
   firebase deploy --only functions
   ```

**Option B — Google Cloud Console (per service)**

1. [Google Cloud Console](https://console.cloud.google.com) → project **`dot-clash-72cc6`**.
2. **Cloud Run** → open service **`verifyremoveadspurchase`** (name may be lowercase).
3. **Edit & deploy new revision** → **Variables & secrets** → add `APPLE_IAP_KEY_ID`, `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_PRIVATE_KEY`, optional `APPLE_IAP_BUNDLE_ID`.
4. Repeat for other callables only if you did not use Option A (Option A applies env to all functions in that deploy).

**Sandbox vs production Apple API**

- TestFlight / sandbox purchases: function uses `api.storekit-sandbox.itunes.apple.com` when not on prod project — on **prod** project it uses production API. TestFlight builds against **prod** Firebase still hit production Apple API for verification (correct for closed testing on prod backend).

---

#### Android — Play Console API access (click-by-click)

Cloud Functions use the project’s **default compute service account** and Application Default Credentials (`googleapis` Android Publisher scope). No extra JSON key file in the repo.

1. **Find the service account email**
   - [Firebase Console](https://console.firebase.google.com) → project **`dot-clash-72cc6`** → ⚙️ **Project settings** → **General** → note **Project number** (e.g. `727354434155`).
   - Service account email is usually:  
     `{PROJECT_NUMBER}-compute@developer.gserviceaccount.com`  
     Example: `727354434155-compute@developer.gserviceaccount.com`
   - Confirm in [Google Cloud Console](https://console.cloud.google.com) → **IAM & Admin** → **IAM** (same project).

2. **Link Play Console to the Google Cloud project**
   - [Play Console](https://play.google.com/console) → **Dot Clash**.
   - **Setup** (gear / left nav) → **API access**.
   - If you see **Link** / **Choose a project to link**: select Google Cloud project **`dot-clash-72cc6`** (same as Firebase prod) → confirm.

3. **Grant the service account access**
   - On **API access**, under **Service accounts**, find `{PROJECT_NUMBER}-compute@developer.gserviceaccount.com` (or click **View in Google Cloud Console** and return).
   - Click **Grant access** (or **Manage Play Console permissions**).
   - Enable at least:
     - **View app information** (read-only)
     - **View financial data, orders, and cancellation survey responses** (needed for `purchases.products.get`)
   - **Invite user** / **Apply** / **Save** (wording varies).

4. Wait a few minutes for permissions to propagate.

**Android package names** allowed by the server: `com.vividmemories.dotclash` (prod) and `com.vividmemories.dotclash.dev` (dev flavor).

---

#### Verify Remove Ads end-to-end

1. Ship a **Release 7+** app build (client calls `verifyRemoveAdsPurchase`, not direct Firestore).
2. Prod Firebase + secrets above configured.
3. Purchase or restore Remove Ads on device.
4. Check [Firebase Functions logs](https://console.firebase.google.com/project/dot-clash-72cc6/functions/logs) for `verifyRemoveAdsPurchase` — success, not `IAP verification not configured` or `Play verification failed`.
5. In Firestore, profile should show `removeAds: true` (client cannot set this via rules).

**Norway / USD price on device:** localized price comes from the store (`ProductDetails.price`). Confirm product pricing in App Store Connect / Play Console and that the tester’s Apple ID region matches (see `docs/RELEASES.md`).

---

### 4c — Apple Developer auth keys (`.p8`) — Sign in with Apple only

**Never commit** `.p8`, `.pem`, or anything under `ios/Security Key/`. They are gitignored.

These are **Auth Keys** from [developer.apple.com](https://developer.apple.com/account/resources/authkeys/list) (Account → **Certificates, Identifiers & Profiles** → **Keys**) — **not** the App Store Connect API key in §4b.

If a key was ever pushed to GitHub, treat it as **compromised**:

1. [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list) → select the key (e.g. `AR2XHZG3V2`) → **Revoke**.
2. Create a **new** key; download the `.p8` once (Apple does not show it again).
3. Store locally, e.g. `ios/Security Key/AuthKey_<KEY_ID>.p8` (folder stays on your machine only), or in CI as an encrypted secret.
4. After rotating, purge the old key from git history and force-push (one-time):  
   `git filter-repo --path "ios/Security Key" --invert-paths` (or ask a maintainer to run the history rewrite).

Used for **Sign in with Apple**, APNs, DeviceCheck, etc. **Do not** reuse this file for `APPLE_IAP_PRIVATE_KEY` unless Apple issued it as an App Store Connect API key (they are different key types).

---

## 5 · Assets placeholder

Create the asset directories so `pubspec.yaml` doesn't error:

```bash
mkdir -p assets/images assets/icons
touch assets/images/.gitkeep assets/icons/.gitkeep
```

Add your app icon, splash screen, and any game assets here. Use `flutter_launcher_icons` and `flutter_native_splash` packages (add them separately) to generate platform icons.

---

## 6 · Running tests

```bash
flutter test test/game/rules_test.dart
```

---

## 7 · Dev / Prod environments

This project uses two Firebase projects and Flutter build flavors so the **artifact itself** decides which backend to connect to — no manual edits between dev and prod.

### 7a — Overview

| Flavor | Bundle ID (iOS) | Application ID (Android) | Firebase project |
|--------|-----------------|----------------------------|------------------|
| `dev`  | `com.vividmemories.dotclash.dev` | `com.vividmemories.dotclash.dev` | `dot-clash-dev` |
| `prod` | `com.vividmemories.dotclash` | `com.vividmemories.dotclash` | `dot-clash-72cc6` |

Dev and prod are **different apps** on device (side‑by‑side installs). Each flavor uses its own `google-services.json` / copied plist and `--dart-define=FLAVOR=…` so Dart [`firebase_options`](lib/firebase_options.dart) matches.

### 7b — Create the dev Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com) → **Add project** → name it (e.g. `dot-clash-dev`).
2. Inside the new project, add apps:
   - **Android** app: package **`com.vividmemories.dotclash.dev`** → download `google-services.json` → `android/app/src/dev/google-services.json`.
   - **iOS** app: bundle **`com.vividmemories.dotclash.dev`** → download `GoogleService-Info.plist` → `ios/config/dev/GoogleService-Info.plist`.
   - **Web** app — useful for Chrome dev testing.
3. Enable the same services you have in prod: **Anonymous Auth**, **Firestore**, **Crashlytics**, **Analytics**.
4. `.firebaserc` alias **`dev`** should point at this project ID.

### 7c — Regenerate Dart Firebase options for dev

```bash
flutterfire configure \
  --project=<dev-project-id> \
  --out=lib/firebase_options_dev.dart \
  --platforms=android,ios,web
```

This overwrites `lib/firebase_options_dev.dart` with real values.  The prod file (`lib/firebase_options_prod.dart`) stays untouched.  The dispatcher in `lib/firebase_options.dart` automatically picks the right file based on `--dart-define=FLAVOR=dev|prod`.

### 7d — Running the app

```bash
# Android — dev (`com.vividmemories.dotclash.dev`, Firebase dot-clash-dev)
flutter run --flavor dev --dart-define=FLAVOR=dev

# Android — prod
flutter run --flavor prod --dart-define=FLAVOR=prod

# iOS — dev
flutter run --flavor dev --dart-define=FLAVOR=dev

# iOS — prod
flutter run --flavor prod --dart-define=FLAVOR=prod

# Chrome (web) — dev
flutter run -d chrome --dart-define=FLAVOR=dev

# Chrome (web) — prod
flutter run -d chrome --dart-define=FLAVOR=prod
```

> **Tip for IDEs**: Create VS Code launch configurations or Android Studio run configurations that include the `--flavor` and `--dart-define` flags so you don't type them every time (see `launch.json` example below).

#### VS Code launch.json example

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "dev (Android/iOS)",
      "request": "launch",
      "type": "dart",
      "args": ["--flavor", "dev", "--dart-define=FLAVOR=dev"]
    },
    {
      "name": "prod (Android/iOS)",
      "request": "launch",
      "type": "dart",
      "args": ["--flavor", "prod", "--dart-define=FLAVOR=prod"]
    },
    {
      "name": "Dot Clash (prod + beta ads)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--flavor", "prod",
        "--dart-define=FLAVOR=prod",
        "--dart-define=BETA_ADS=true",
        "--android-project-arg=betaAds=true"
      ]
    }
  ]
}
```

### 7e — iOS: GoogleService-Info.plist copy script

The `ios/scripts/copy_google_services.sh` script copies the right plist into the app bundle at build time. Add it as an Xcode **Run Script Build Phase** on the **Runner** target:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **Runner** target → **Build Phases** → `+` → **New Run Script Phase**.
3. Move this phase **after** **Copy Bundle Resources** (so the flavor plist overwrites the default `Runner/GoogleService-Info.plist` copied from the project).
4. Script body:

```sh
"${SRCROOT}/scripts/copy_google_services.sh"
```

5. Uncheck **Based on dependency analysis** so it always runs.

### 7f — Deploying Cloud Functions

```bash
# Deploy to dev (never auto-deploys to prod from a dev branch)
firebase use dev
firebase deploy --only functions,firestore:rules,firestore:indexes

# Deploy to prod (use only from the main branch or via CI)
firebase use prod
firebase deploy --only functions,firestore:rules,firestore:indexes
```

**Gen-1 → Gen-2 migration:** Firebase cannot upgrade an existing function from 1st Gen to 2nd Gen in place. If deploy fails with `Upgrading from 1st Gen to 2nd Gen is not yet supported`, delete the old v1 callables first, then redeploy:

```bash
firebase use prod   # or dev
firebase functions:list
firebase functions:delete completeCampaignLevel completeDailyPuzzle claimDailyMission --region us-central1 --force
firebase deploy --only functions
```

There is brief downtime for campaign/daily rewards between delete and successful redeploy.

### 7g — Dev data: matching production data

Firebase Authentication identities are **not portable** across projects — each project has its own Auth store with distinct UIDs.  "Same data as prod" means the same **schema** and **realistic documents**, not the same Firebase accounts.

**Option A: Firestore export/import** (recommended for a realistic dev dataset)

```bash
# Export from prod
gcloud firestore export gs://<prod-bucket>/backup --project=dot-clash-72cc6

# Import into dev
gcloud firestore import gs://<prod-bucket>/backup --project=<dev-project-id>
```

Users are re-created in dev using the same sign-in method (anonymous, Google, Apple); their UID will differ but the documents under their new UID inherit the prod schema.

**Option B: Seed scripts** — maintain a `scripts/seed_dev.ts` that writes representative Firestore documents (streaks, levels, match history) using the Firebase Admin SDK.  Run it once after creating the dev project:

```bash
cd scripts
npx ts-node seed_dev.ts
```

### 7h — CI/CD branch mapping

| Branch / trigger | Flavor | Firebase target |
|-----------------|--------|-----------------|
| `develop`, PRs | `dev`  | `dot-clash-dev` |
| `main`, release tags | `prod` | `dot-clash-72cc6` |

Example GitHub Actions step for Android:

```yaml
- name: Build Android (dev)
  if: github.ref != 'refs/heads/main'
  run: flutter build apk --flavor dev --dart-define=FLAVOR=dev

- name: Build Android (prod)
  if: github.ref == 'refs/heads/main'
  run: flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
```

---

## 8 · Release builds

### Android signing (required before Play upload)

Create the upload keystore once (`android/upload-keystore.jks` and `android/key.properties` are gitignored — copy from `android/key.properties.example`):

```bash
bash android/scripts/create_upload_keystore.sh
cp android/key.properties.example android/key.properties
# Edit android/key.properties with your passwords
```

Release AABs use that upload key when `android/key.properties` exists; otherwise Gradle falls back to debug signing with a warning.

**New Mac?** Back up the keystore and passwords first — see [docs/MIGRATION_RUNBOOK.md](../docs/MIGRATION_RUNBOOK.md).

### Android
```bash
# Prod release AAB (upload to Play Store — public launch, real ads)
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
# Output: build/app/outputs/bundle/prodRelease/app-prod-release.aab

# Closed testing AAB (test ads — safe for beta testers)
bash scripts/build_closed_testing.sh android
```

### iOS
```bash
# Prod release IPA (upload to App Store — public launch, real ads)
flutter build ipa --flavor prod --dart-define=FLAVOR=prod --release
# Open Xcode Organizer and submit

# Closed testing IPA (test ads)
bash scripts/build_closed_testing.sh ios
```

---

## 9 · Store checklist

- [ ] App icon (1024×1024 PNG, no alpha)
- [ ] Screenshots (6.5" iPhone, 12.9" iPad, various Android sizes)
- [ ] Privacy Policy URL (required for ads + analytics)
- [ ] App Store age rating: 4+ (no user-generated content)
- [ ] `NSUserTrackingUsageDescription` in `Info.plist` (ATT prompt for iOS 14+)
- [ ] `AndroidManifest.xml` AdMob App ID
- [ ] Play Store content rating questionnaire
- [ ] Data safety section on Play Store (declare analytics, ads, crash reporting)
- [ ] GDPR consent (UMP via `AdConsentService`) if distributing in EEA

---

## Architecture overview

**Full diagrams (control + data flow):** see [`docs/architecture.md`](docs/architecture.md). In Cursor, open the interactive Canvas `dot-clash-architecture` beside chat for tabbed graphs and clickable nodes.

```
lib/
├── main.dart                  Firebase init + ProviderScope
├── app.dart                   MaterialApp.router
├── firebase_options.dart      Generated by flutterfire configure
├── core/
│   ├── env/app_env.dart       Ad unit IDs, feature flags
│   ├── router/app_router.dart GoRouter definition
│   └── theme/                 AppColors, AppTextStyles, AppTheme
├── shared/
│   ├── layout/                AppSpacing, ResponsiveLayout
│   └── widgets/               NeonCard, NeonButton, NeonIconButton, NeonTag, ...
├── features/
│   ├── auth/                  Anonymous sign-in
│   ├── home/                  Main menu + mode picker
│   ├── game/
│   │   ├── domain/            GameState model + GameRules engine (pure Dart)
│   │   ├── providers/         GameNotifier, TurnTimerNotifier
│   │   └── presentation/      GameScreen + board widgets
│   ├── ai/                    AiPlayer (easy / medium / hard)
│   ├── shop/                  IAP shop screen
│   └── settings/              Settings screen + SharedPreferences
└── services/
    ├── ads/ad_service.dart    AdMob interstitial + rewarded
    ├── iap/iap_service.dart   In-app purchases
    └── analytics/             Firebase Analytics + Crashlytics

firestore.rules                Security rules
firestore.indexes.json         Composite indexes
```
