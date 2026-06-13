# Flutter + Firebase Release Checklist for Google Play (AAB) and Apple App Store

A practical pre-release checklist to reduce rollout issues, crashes, rejected builds, and production incidents.

---

# 1. Build & Environment Validation

## Flutter SDK
- Use a stable Flutter channel.
- Run:

```bash
flutter doctor -v
```

- Ensure:
  - No Android/iOS toolchain errors
  - Xcode installed correctly
  - Android SDK versions aligned
  - CocoaPods working

## Clean Build
Always test from a clean state:

```bash
flutter clean
flutter pub get
```

## Dependency Audit
Check:

```bash
flutter pub outdated
```

Validate:
- No deprecated Firebase SDKs
- No incompatible plugin versions
- No abandoned packages
- iOS and Android minimum SDK compatibility

---

# 2. Static Analysis & Code Quality

## Flutter Analyze
Must pass with zero critical issues:

```bash
flutter analyze
```

Recommended:
- Treat warnings seriously
- Avoid ignored lints unless justified

## Formatting

```bash
dart format .
```

## Optional Strict Linting
Recommended package:

```yaml
dev_dependencies:
  flutter_lints: ^latest
```

Suggested rules:
- avoid_print
- prefer_const_constructors
- use_build_context_synchronously
- unnecessary_null_checks
- cancel_subscriptions

---

# 3. Testing

## Unit Tests

```bash
flutter test
```

Critical areas:
- Authentication
- State management
- Data parsing
- Firebase services
- Payment logic
- Feature flags

## Widget Tests
Validate:
- Navigation
- Forms
- Error states
- Responsive layouts
- Dark mode

## Integration / End-to-End Tests
Recommended:

```bash
flutter test integration_test
```

Validate:
- Login flow
- App startup
- Push notifications
- Offline mode
- Crash recovery
- Firebase sync
- Deep links
- Purchases/subscriptions

---

# 4. Firebase Checks

## Firebase Initialization
Validate:
- Correct Firebase project
- Correct bundle IDs/package names
- Separate dev/staging/prod environments

Verify:
- `google-services.json`
- `GoogleService-Info.plist`
- Firebase app IDs

## Crashlytics
Before release:
- Ensure crashes are reporting
- Upload symbols correctly
- Test a forced crash

Test:

```dart
FirebaseCrashlytics.instance.crash();
```

Confirm crash appears in Firebase console.

## Analytics
Validate:
- Events firing correctly
- No duplicate events
- User properties correct
- Consent handling implemented

## Firebase Security Rules
Review:
- Firestore rules
- Realtime DB rules
- Storage rules

Check:
- No open production rules
- No test mode left enabled

## Firebase App Check
Recommended for production:
- Android: Play Integrity
- iOS: DeviceCheck/App Attest

## Cloud Functions
Validate:
- Production environment variables
- Memory/timeouts appropriate
- No debug logs leaking secrets

---

# 5. Android-Specific Checks (Google Play)

## Release Build
Build release AAB:

```bash
flutter build appbundle --release
```

## Versioning
In `pubspec.yaml`:

```yaml
version: 1.2.3+45
```

Ensure:
- Version name increments
- Version code increments

## Signing
Validate:
- Release keystore available
- Keystore backup secured
- Play App Signing enabled

Check:
- `key.properties`
- `build.gradle`

## Proguard / R8
If minification enabled:
- Ensure Firebase rules included
- Ensure reflection-based packages work
- Validate obfuscation does not break app

## Android Permissions Review
Remove unused permissions.

Common problems:
- READ_PHONE_STATE
- QUERY_ALL_PACKAGES
- Background location
- Exact alarm permissions

## Android SDK Targets
Recommended:
- targetSdkVersion = latest supported
- compileSdkVersion = latest stable

## Deep Links / App Links
Validate:
- Intent filters
- SHA fingerprints
- Asset links JSON

## Push Notifications
Validate:
- FCM token generation
- Foreground handling
- Background handling
- Notification tap navigation

## Play Console Pre-Launch Report
Use internal testing before production.

Fix:
- ANRs
- Startup crashes
- UI rendering issues
- Accessibility warnings

---

# 6. iOS-Specific Checks (Apple App Store)

## Release Build

```bash
flutter build ipa --release
```

## CocoaPods

```bash
cd ios
pod install
pod update
```

## Bundle Versioning
Validate:
- CFBundleShortVersionString
- CFBundleVersion

## Certificates & Provisioning
Check:
- Distribution certificate valid
- Provisioning profiles active
- Automatic signing configured correctly

## App Transport Security (ATS)
Ensure:
- HTTPS usage
- No unnecessary ATS exceptions

## Push Notifications
Validate:
- APNs configured
- APNs key uploaded to Firebase
- Notification permissions handled correctly

## iOS Permissions Strings
Review all:
- Camera
- Photos
- Location
- Notifications
- Bluetooth
- Microphone

Ensure human-readable explanations.

## Apple Review Compliance
Check:
- Sign in with Apple (required if other social logins exist)
- Subscription restoration
- Privacy nutrition labels
- Account deletion option (required if account creation exists)

## Archive Validation
In Xcode:
- Product → Archive
- Validate before upload

---

# 7. Performance & Stability

## Startup Performance
Measure:
- Cold start time
- Splash screen duration
- Firebase initialization delays

## Memory Leaks
Check:
- Stream subscriptions cancelled
- Controllers disposed
- Animations cleaned up

## Image Optimization
Validate:
- Compressed assets
- WebP where appropriate
- No oversized images

## Network Resilience
Test:
- Slow internet
- Offline mode
- Retry behavior
- API timeout handling

## Background Behavior
Validate:
- App resume
- Session restoration
- Notification handling
- Lifecycle state handling

---

# 8. Security Checks

## Secrets Management
Never commit:
- API keys
- Service accounts
- Private certificates
- Production secrets

Use:
- CI/CD secrets
- Environment configs
- Firebase Remote Config where appropriate

## SSL & API Security
Validate:
- HTTPS only
- Secure token storage
- Refresh token logic

## Local Storage
Sensitive data should use:
- flutter_secure_storage
- Keychain (iOS)
- EncryptedSharedPreferences (Android)

---

# 9. CI/CD Recommended Pipeline

Recommended automated pipeline:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
flutter build ipa --release
```

Recommended tools:
- GitHub Actions
- Codemagic
- Bitrise
- Fastlane

Recommended automation:
- Automatic version bumping
- Automatic Firebase symbol upload
- Store deployment automation
- Slack/Teams notifications

---

# 10. Release Rollout Strategy

## Internal Testing First
Use:
- Google Play Internal Testing
- TestFlight Internal Testing

## Staged Rollout
Recommended:
- 5%
- 10%
- 25%
- 50%
- 100%

Monitor after each increase:
- Crash-free users
- ANRs
- Login failures
- API errors
- Payment failures
- Firebase crashes

## Monitoring During Rollout
Watch:
- Firebase Crashlytics
- Firebase Performance
- Play Console vitals
- App Store Connect crashes

---

# 11. Production Readiness Checklist

Before pressing Publish:

- All tests passing
- No critical analyzer warnings
- Crashlytics verified
- Firebase rules reviewed
- Version numbers updated
- Release notes prepared
- API endpoints production-ready
- Feature flags verified
- Push notifications tested
- Deep links tested
- Subscription flows tested
- Offline mode tested
- Store screenshots updated
- Privacy policy URL working
- Account deletion flow working
- Rollback plan prepared

---

# 12. Most Common Flutter + Firebase Release Failures

## Android
- Missing SHA-1/SHA-256
- Firebase config mismatch
- R8/Proguard breaking plugins
- Incorrect keystore
- Background isolate crashes
- Notification click navigation issues

## iOS
- Missing privacy descriptions
- APNs not configured correctly
- CocoaPods version conflicts
- Apple Sign-In missing
- Invalid provisioning profile
- Missing dSYM upload

## Cross Platform
- Debug-only code leaking to release
- Environment variables incorrect
- Unhandled async exceptions
- Network timeout crashes
- Firestore rules too restrictive/open

---

# 13. Recommended Commands Before Every Release

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
flutter build ipa --release
```

Optional:

```bash
dart fix --apply
```

---

# 14. Recommended Production Tooling

## Monitoring
- Firebase Crashlytics
- Firebase Performance Monitoring
- Sentry (optional)

## Release Automation
- Fastlane
- Codemagic
- GitHub Actions

## Feature Rollouts
- Firebase Remote Config
- Firebase A/B Testing

---

# 15. Best Practice Architecture Recommendations

Recommended:
- Separate environments:
  - dev
  - staging
  - production

- Use feature flags
- Avoid hardcoded URLs
- Keep Firebase projects isolated per environment
- Enable rollback capability
- Use semantic versioning

---

# Final Recommendation

Minimum safe release gate:

```bash
flutter analyze && flutter test
```

If possible, also require:
- Integration tests
- Internal beta validation
- Crashlytics verification
- Staged rollout

For Flutter + Firebase apps, most production incidents usually come from:
1. Incorrect Firebase environment configuration
2. Push notification misconfiguration
3. Async lifecycle crashes
4. Platform permission issues
5. Release-only obfuscation/minification problems

