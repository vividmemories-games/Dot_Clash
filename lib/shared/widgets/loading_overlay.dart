import 'package:flutter/material.dart';

import '../../core/theme/dot_clash_visuals.dart';

/// Full-screen translucent overlay with a themed spinner.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.message});

  final String? message;

  /// Wrap a future with a loading overlay automatically.
  static Future<T> show<T>(
    BuildContext context,
    Future<T> future, {
    String? message,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoadingOverlay(message: message),
    );
    try {
      return await future;
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: v.playerA,
                strokeWidth: 3,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  color: v.textSecondary,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
