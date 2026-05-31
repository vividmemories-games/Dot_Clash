import 'package:flutter/services.dart';

/// Respects the in-app haptics toggle; configure from game/settings context.
class AppHaptics {
  AppHaptics._();

  static bool _enabled = true;

  static void configure({required bool enabled}) {
    _enabled = enabled;
  }

  static void lightImpact() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    if (_enabled) HapticFeedback.selectionClick();
  }
}
