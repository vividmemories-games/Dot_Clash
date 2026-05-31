import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env/app_env.dart';

/// Opens the device mail client with a pre-filled support message.
Future<bool> openSupportEmail({
  User? user,
  String? displayName,
}) async {
  final body = StringBuffer()
    ..writeln('Describe your issue:')
    ..writeln()
    ..writeln()
    ..writeln('---')
    ..writeln('App: Dot Clash');

  if (user != null) {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      body.writeln('Display name: $name');
    }
    body.writeln('User ID: ${user.uid}');
    if (user.email != null && user.email!.isNotEmpty) {
      body.writeln('Account email: ${user.email}');
    }
    if (user.isAnonymous) {
      body.writeln('Sign-in: Guest');
    } else {
      final providers = user.providerData.map((p) => p.providerId).toList();
      if (providers.isNotEmpty) {
        body.writeln('Sign-in: ${providers.join(', ')}');
      }
    }
  }

  final subject = Uri.encodeComponent('Dot Clash Support');
  final encodedBody = Uri.encodeComponent(body.toString());
  final uri = Uri.parse(
    'mailto:${AppEnv.contactEmail}?subject=$subject&body=$encodedBody',
  );

  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri);
}
