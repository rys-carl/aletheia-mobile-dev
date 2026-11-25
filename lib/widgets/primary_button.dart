import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';

/// Full-width filled button with a built-in loading state.
/// While [loading] the button keeps its look but ignores taps.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Red styling for actions like delete.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handler =
        onPressed == null ? null : (loading ? () {} : onPressed);

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: destructive
            ? FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.onDanger,
              )
            : null,
        onPressed: handler,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}
