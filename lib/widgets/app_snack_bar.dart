import 'dart:async';

import 'package:flutter/material.dart';

/// Shows a short message at the bottom of the screen, with an optional action
/// button (e.g. "Undo" or "Retry").
/// Check `mounted` before calling this after an `await`.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
  // Ensure the snackbar always dismisses after [duration], even if the
  // platform reports accessibleNavigation=true.
  Timer(duration, controller.close);
}
