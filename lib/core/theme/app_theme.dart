import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';

/// Builds the app's [ThemeData] from the tokens in `app_colors.dart` and
/// `app_dimens.dart`. This is where typography and the look of every
/// built-in widget (buttons, inputs, dialogs, ...) is defined once.
abstract final class AppTheme {
  /// Font family name. Must match the `family:` entry under `fonts:` in
  /// pubspec.yaml. To change the app's font, swap the files in
  /// assets/fonts/, update pubspec.yaml, and change this name.
  static const fontFamily = 'Lato';

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.primaryDark,
      onSecondary: AppColors.onPrimary,
      error: AppColors.danger,
      onError: AppColors.onDanger,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    // Typography: passing fontFamily here applies the bundled font to every
    // text style in the app.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );
    final textTheme = base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: const TextStyle(color: AppColors.textHint),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: TextStyle(color: AppColors.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        space: 1,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
