import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';

/// A tappable field that looks like a text input but opens a picker
/// (date, location, ...). Shows [placeholder] while [text] is null.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.icon,
    required this.onTap,
    this.text,
    this.placeholder,
    this.onClear,
  });

  final IconData icon;
  final String? text;
  final String? placeholder;
  final VoidCallback onTap;

  /// When set, a clear (x) button is shown.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;
    final hasText = text != null && text!.isNotEmpty;

    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    hasText ? text! : (placeholder ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle?.copyWith(
                      color: hasText
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
