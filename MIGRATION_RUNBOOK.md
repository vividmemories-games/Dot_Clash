# Dot Clash — Mac migration runbook

One-page checklist for moving development to a new Mac **before** losing access to the old machine.  
Secrets are **gitignored** — Git alone will not restore them.

**Related:** [SETUP.md](SETUP.md) (signing, IAP, flavors, App Check) · Key rotation notes in §3 below

---

## 1 · Back up now (encrypted, two locations)

Copy into a folder, then encrypt (`zip -er`, 1Password, or encrypted disk image). Store copy #1 in cloud, copy #2 on USB.

| File | Purpose |
|------|---------|
| `android/upload-keystore.jks` | **Upload key** — required for every Play AAB. Cannot be re-downloaded. |
| `android/key.properties` | Keystore passwords + alias (`upload`). |
| `ios/Security Key/AuthKey_J4424H3MSQ.p8` | App Store Connect API key (IAP server verification). |
| `ios/Security Key/AuthKey_AR2XHZG3V2.p8` | Apple Developer auth key (Sign in with Apple / services). **Rotate** — see §3. |
| `functions/.env.dot-clash-72cc6` | `APPLE_IAP_*` env vars for prod function deploys. |
| `prod_firebase_private_key/dot-clash-72cc6-firebase-adminsdk-*.json` | Firebase Admin SDK (prod scripts). |
| `dot-clash-dev-firebase-adminsdk-*.json` (project root) | Firebase Admin SDK (dev scripts). |

Also in password manager: all `key.properties` passwords, Apple/Google/Firebase account 2FA recovery codes.

**Do not commit** any of the above. Never paste `.p8` or private keys into Slack, email, or Git.

---

## 2 · Which `.p8` is which (verify in Apple consoles)

Apple issues **two different** `.p8` key types. Filenames follow `AuthKey_<KEY_ID>.p8`.

| Local file | Key ID | Where it was created | Used for | Env / config |
|------------|--------|----------------------|----------|--------------|
| `AuthKey_J4424H3MSQ.p8` | `J4424H3MSQ` | **[App Store Connect](https://appstoreconnect.apple.com) → Users and Access → Integrations → App Store Connect API** | Server-side **IAP receipt verification** (`verifyRemoveAdsPurchase`) | `functions/.env.dot-clash-72cc6`: `APPLE_IAP_KEY_ID=J4424H3MSQ`, `APPLE_IAP_ISSUER_ID=881e0cf8-9202-4756-b7be-9f8e12c97778` |
| `AuthKey_AR2XHZG3V2.p8` | `AR2XHZG3V2` | **[Apple Developer](https://developer.apple.com/account/resources/authkeys/list) → Certificates, Identifiers & Profiles → Keys** | **Sign in with Apple** (and other Developer services: APNs, DeviceCheck). **Not** for IAP env vars. | Xcode capability + Firebase Auth (Apple provider). **Not** `APPLE_IAP_PRIVATE_KEY`. |

### How to verify each key matches the file on disk

**App Store Connect API key (`J4424H3MSQ`)**

1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**.
2. Confirm a team key with **Key ID** `J4424H3MSQ` exists (name e.g. “Dot Clash IAP Server”).
3. Copy **Issuer ID** from the top of that page — must match `881e0cf8-9202-4756-b7be-9f8e12c97778` in `functions/.env.dot-clash-72cc6`.
4. Apple **never** re-offers the `.p8` download. If the file is missing, **Generate API Key** (new Key ID), update `.env`, redeploy functions.

**Apple Developer auth key (`AR2XHZG3V2`)**

1. [developer.apple.com → Keys](https://developer.apple.com/account/resources/authkeys/list).
2. Find key **AR2XHZG3V2** — enabled services should include **Sign in with Apple**.
3. This key is **separate** from App Store Connect API keys (different portal, different Key ID namespace).

**Quick rule:** If `APPLE_IAP_KEY_ID` in `.env` equals the suffix in the filename → that `.p8` is the IAP key. The other `.p8` is the Developer auth key.

---

## 3 · Security: rotate compromised Developer key (recommended during migration)

`AR2XHZG3V2` was previously committed to Git (see §3 key rotation). During migration:

1. Apple Developer → Keys → **Revoke** `AR2XHZG3V2`.
2. Create a **new** key (Sign in with Apple enabled) → download `.p8` once → save as `ios/Security Key/AuthKey_<NEW_ID>.p8`.
3. Update Firebase Console → Authentication → Sign-in method → Apple (if a Services ID / key is referenced).
4. Delete the old file from backups after the new key works.
5. Keep `J4424H3MSQ` unless you also rotate IAP (separate flow in App Store Connect).

---

## 4 · Verify Play App Signing (Google Play)

You need **both**: Google’s **app signing key** (Google-held) and your **upload key** (`upload-keystore.jks`).

1. [Play Console](https://play.google.com/console) → **Dot Clash** → **Setup** → **App signing** (or **Release** → **Setup** → **App integrity**).
2. Confirm **Play App Signing** is **ON**.
3. Under **Upload key certificate**, note the **SHA-1** fingerprint.
4. On your Mac, compare with the keystore:

   ```bash
   keytool -list -v -keystore android/upload-keystore.jks -alias upload
   ```

   Enter the `storePassword` from `key.properties`. The **SHA-1** must match Play Console’s upload key certificate.

5. If they match → back up `upload-keystore.jks` + `key.properties` and you’re set.
6. If Play App Signing is ON but you **lose** the upload keystore → Play Console → **Request upload key reset** (support process; avoid if possible).

**Release build sanity check (optional, on old Mac before wipe):**

```bash
bash scripts/build_closed_testing.sh android
# Expect signed AAB: build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

---

## 5 · Push Git, then wipe old Mac

```bash
git status          # commit/push anything unpushed
git push origin main
```

Code, rules, `google-services.json`, and function **source** are in the repo. Only §1 secrets are not.

---

## 6 · New Mac setup

| Step | Action |
|------|--------|
| 1 | Install Flutter 3.24+, Xcode, Android Studio, Node 22+, `firebase-tools`, `flutterfire_cli` |
| 2 | `git clone <repo>` into your projects folder |
| 3 | Restore §1 files to the **same paths** relative to repo root |
| 4 | `flutter pub get` · `cd functions && npm install` |
| 5 | `firebase login` · `firebase use prod` (alias for `dot-clash-72cc6`) |
| 6 | Open `ios/Runner.xcworkspace` → Xcode → Settings → Accounts → Apple ID → team **828ZXTU698** (automatic signing) |
| 7 | Smoke builds: `bash scripts/build_closed_testing.sh android` and `… ios` |
| 8 | Optional deploy check: `firebase deploy --only functions -P dot-clash-72cc6` (only if you changed functions) |

`android/local.properties` is machine-specific — Android Studio / Flutter recreates it. Do not copy from old Mac.

---

## 7 · If the old Mac is already gone

| Lost item | Recovery |
|-----------|----------|
| `upload-keystore.jks` | Play Console upload key reset |
| `AuthKey_J4424H3MSQ.p8` | New App Store Connect API key → update `functions/.env.dot-clash-72cc6` → redeploy functions |
| `AuthKey_AR2XHZG3V2.p8` | New Apple Developer key → reconfigure Sign in with Apple / Firebase |
| `functions/.env.*` | Rebuild from GCP Cloud Run env vars (Firebase project `dot-clash-72cc6`) or password manager |
| Firebase Admin JSON | Firebase Console → Project settings → Service accounts → Generate new private key |
| Source code | Git remote |

**Hardest loss:** upload keystore. Back it up first.

---

*Last updated: 2026-06-04 · Dot Clash prod `dot-clash-72cc6` · Xcode team `828ZXTU698`*
