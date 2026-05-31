import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/env/app_env.dart';

/// Google UMP (User Messaging Platform) — gather consent before ad requests.
///
/// Configure messages in AdMob → Privacy & messaging. Privacy policy URL must
/// match [AppEnv.privacyPolicyUrl].
class AdConsentService {
  AdConsentService._();

  static final AdConsentService instance = AdConsentService._();

  bool _consentFlowCompleted = false;

  /// Whether ad requests should use non-personalized ads only (product policy).
  bool get requestNonPersonalizedAds => !AppEnv.personalizedAds;

  /// Builds an [AdRequest] aligned with consent and [AppEnv.personalizedAds].
  AdRequest adRequest() => AdRequest(
        nonPersonalizedAds: requestNonPersonalizedAds ? true : null,
      );

  /// Request updated consent info, show the form if required, then allow ads init.
  Future<void> gatherConsentIfNeeded() async {
    if (_consentFlowCompleted) return;

    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: false,
      consentDebugSettings: _debugSettings,
    );

    await _requestConsentInfoUpdate(params);
    await _loadAndShowConsentFormIfRequired();
    _consentFlowCompleted = true;
    final canRequest = await ConsentInformation.instance.canRequestAds();
    debugPrint('[AdConsent] flow complete canRequestAds=$canRequest');
  }

  /// Whether the SDK allows ad requests (after UMP or cached consent).
  Future<bool> canRequestAds() =>
      ConsentInformation.instance.canRequestAds();

  /// True when AdMob requires an in-app privacy options entry point.
  Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// Presents the privacy options form (settings / legal screen).
  Future<void> showPrivacyOptions() async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Resets consent state — debug only.
  @visibleForTesting
  Future<void> resetForTesting() async {
    if (!kDebugMode) return;
    await ConsentInformation.instance.reset();
    _consentFlowCompleted = false;
  }

  ConsentDebugSettings? get _debugSettings {
    if (!kDebugMode) return null;

    const geography = String.fromEnvironment('UMP_DEBUG_GEOGRAPHY');
    if (geography.isEmpty) return null;

    final debugGeography = switch (geography.toLowerCase()) {
      'eea' => DebugGeography.debugGeographyEea,
      'not_eea' || 'not-eea' => DebugGeography.debugGeographyOther,
      _ => null,
    };
    if (debugGeography == null) return null;

    const testIds = String.fromEnvironment('UMP_TEST_DEVICE_IDS');
    final identifiers =
        testIds.isEmpty ? null : testIds.split(',').map((s) => s.trim()).toList();

    return ConsentDebugSettings(
      debugGeography: debugGeography,
      testIdentifiers: identifiers,
    );
  }

  Future<void> _requestConsentInfoUpdate(ConsentRequestParameters params) {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        debugPrint(
          '[AdConsent] requestConsentInfoUpdate: '
          '${error.errorCode} ${error.message}',
        );
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  Future<void> _loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        debugPrint(
          '[AdConsent] loadAndShowConsentFormIfRequired: '
          '${error.errorCode} ${error.message}',
        );
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }
}
