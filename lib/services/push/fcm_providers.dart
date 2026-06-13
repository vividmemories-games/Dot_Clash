import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fcm_service.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService();
  ref.onDispose(service.dispose);
  return service;
});
