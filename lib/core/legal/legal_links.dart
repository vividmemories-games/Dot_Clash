import 'package:url_launcher/url_launcher.dart';

import '../env/app_env.dart';

/// Opens legal / info URLs from [AppEnv] in the system browser.
abstract final class LegalLinks {
  static Future<bool> openPrivacyPolicy() =>
      _open(AppEnv.privacyPolicyUrl);

  static Future<bool> openTerms() => _open(AppEnv.termsUrl);

  static Future<bool> openContactInfo() => _open(AppEnv.contactInfoUrl);

  static Future<bool> openDeleteDataInfo() => _open(AppEnv.deleteDataInfoUrl);

  static Future<bool> openPrivacyChoices() => _open(AppEnv.privacyChoicesUrl);

  static Future<bool> _open(String url) async {
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
