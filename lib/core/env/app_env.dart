/// Environment-level configuration: ad unit IDs, feature flags, etc.
///
/// Build with `--dart-define=FLAVOR=dev` (default) or `--dart-define=FLAVOR=prod`.
/// Closed testing on prod: add `--dart-define=BETA_ADS=true` (see SETUP.md).
/// The [flavor] constant is resolved at compile time so tree-shaking applies.
abstract final class AppEnv {
  // ── Flavor ────────────────────────────────────────────────────────────────
  static const String flavor =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  static const bool isDev = flavor == 'dev';
  static const bool isProd = flavor == 'prod';

  /// Google test ad units on prod store builds (Play/TestFlight closed testing).
  /// Omit for public launch builds. Pair with [scripts/build_closed_testing.sh].
  static const bool betaAds =
      bool.fromEnvironment('BETA_ADS', defaultValue: false);

  /// Optional fixed App Check debug token for simulators/CI (`--dart-define=APP_CHECK_DEBUG_TOKEN=...`).
  /// Register the same value under Firebase Console → App Check → Manage debug tokens.
  static const String appCheckDebugToken =
      String.fromEnvironment('APP_CHECK_DEBUG_TOKEN', defaultValue: '');

  /// Web OAuth client (`oauth_client` with `client_type: 3` in
  /// `google-services.json`). Used as `serverClientId` on Android/iOS so
  /// Firebase Auth receives an ID token.
  static String get googleSignInServerClientId =>
      isProd
          ? '727354434155-11to1o8qau9ndkt3s8chlsdbps2l1p4v.apps.googleusercontent.com'
          : '218032510167-go3gn9lr2uatb8jv5bveupjdabcpqi03.apps.googleusercontent.com';

  // ── AdMob (Google test IDs in dev, your publisher in prod) ────────────────
  // Test IDs: https://developers.google.com/admob/android/test-ads
  static const String _testAdmobAppIdAndroid =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _testAdmobAppIdIos =
      'ca-app-pub-3940256099942544~1458002511';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  // Prod publisher 6626056478655263 — only used when FLAVOR=prod.
  static const String _prodAdmobAppIdAndroid =
      'ca-app-pub-6626056478655263~7661116755';
  static const String _prodAdmobAppIdIos =
      'ca-app-pub-6626056478655263~8406844911';
  static const String _prodInterstitialAndroid =
      'ca-app-pub-6626056478655263/4499389496';
  static const String _prodInterstitialIos =
      'ca-app-pub-6626056478655263/4357816470';
  static const String _prodRewardedAndroid =
      'ca-app-pub-6626056478655263/5092313642';
  static const String _prodRewardedIos =
      'ca-app-pub-6626056478655263/5882651131';

  static bool get _useTestAds => isDev || betaAds;

  static String get admobAppIdAndroid =>
      _useTestAds ? _testAdmobAppIdAndroid : _prodAdmobAppIdAndroid;

  static String get admobAppIdIos =>
      _useTestAds ? _testAdmobAppIdIos : _prodAdmobAppIdIos;

  static String get interstitialAdUnitAndroid =>
      _useTestAds ? _testInterstitialAndroid : _prodInterstitialAndroid;

  static String get interstitialAdUnitIos =>
      _useTestAds ? _testInterstitialIos : _prodInterstitialIos;

  static String get rewardedAdUnitAndroid =>
      _useTestAds ? _testRewardedAndroid : _prodRewardedAndroid;

  static String get rewardedAdUnitIos =>
      _useTestAds ? _testRewardedIos : _prodRewardedIos;

  /// True when using Google's sample ad units (dev flavor or [betaAds]).
  static bool get usesTestAdUnits => _useTestAds;

  // ── Privacy / ads policy (must match docs/_data/legal.yml) ───────────────
  static const String _legalSiteBase = 'https://vividmemories-games.github.io';

  static const String privacyPolicyUrl = '$_legalSiteBase/privacy-policy/';
  static const String termsUrl = '$_legalSiteBase/terms-and-conditions/';
  static const String contactInfoUrl = '$_legalSiteBase/contact/';
  static const String deleteDataInfoUrl = '$_legalSiteBase/delete-data/';
  static const String privacyChoicesUrl = '$_legalSiteBase/privacy-choices/';

  /// Support inbox for mailto: contact (must match legal site contact_email).
  static const String contactEmail = 'vividmemoriesgames@gmail.com';

  /// When false, use non-personalized AdMob requests (no iOS ATT for ads).
  static const bool personalizedAds = false;

  // ── IAP product IDs ────────────────────────────────────────────────────────
  // These must match exactly what you create in App Store Connect / Play Console.
  static const String iapRemoveAds = 'dot_clash_remove_ads';
  static const String iapCosmeticPack = 'dot_clash_cosmetic_pack_1';

  // ── Feature flags (local defaults; override via Remote Config) ────────────
  static const int defaultBoardSize = 5; // 5×5 dots → 4×4 boxes
  static const int turnTimerSeconds = 30;
  static const int adFrequencyMatches = 3; // show interstitial every N matches
}
