import 'package:flutter/material.dart';

import '../../core/theme/dot_clash_visuals.dart';

/// Floating snackbars with a visible border (Release 9 UX).
abstract final class AppSnackBar {
  static void show(BuildContext context, String message) {
    final v = context.dc;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: v.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: v.surfaceElevated,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: v.playerA.withValues(alpha: 0.85), width: 2),
          ),
        ),
      );
  }
}
