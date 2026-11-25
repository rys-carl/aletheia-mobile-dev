import 'package:flutter/material.dart';

/// Single source of truth for every color in the app.
///
/// Change a value here and the whole UI follows. Widgets should read colors
/// from here (or from `Theme.of(context).colorScheme`), never hard-code them.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF2B4D4D);
  static const primaryDark = Color(0xFF1F3A3A);
  static const primarySoft = Color(0xFFDCE7E2);
  static const onPrimary = Color(0xFFF4F4F0);

  // Surfaces
  static const background = Color(0xFFE8E8E4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F1EE);

  // Text
  static const textPrimary = Color(0xFF1B1F1F);
  static const textSecondary = Color(0xFF66706F);
  static const textHint = Color(0xFFA3A9A7);

  // Lines and shadows
  static const border = Color(0xFFD9DCD8);
  static const shadow = Color(0x33000000);

  // Feedback
  static const danger = Color(0xFFC4452A);
  static const onDanger = Colors.white;
}
