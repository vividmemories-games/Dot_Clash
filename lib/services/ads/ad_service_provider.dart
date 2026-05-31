import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_service.dart';
import 'admob_ad_service.dart';

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);

final adServiceProvider = Provider<AdService>((ref) => AdMobAdService());
