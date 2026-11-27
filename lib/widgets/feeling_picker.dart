import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';

/// Preset feelings shown in the entry form's emoji picker.
const List<({String emoji, String label})> kFeelingOptions = [
  (emoji: '😊', label: 'Happy'),
  (emoji: '🥰', label: 'Loved'),
  (emoji: '😌', label: 'Peaceful'),
  (emoji: '🎉', label: 'Excited'),
  (emoji: '😂', label: 'Fun'),
  (emoji: '🥹', label: 'Nostalgic'),
  (emoji: '🤔', label: 'Thoughtful'),
  (emoji: '😴', label: 'Tired'),
  (emoji: '😢', label: 'Sad'),
  (emoji: '😤', label: 'Frustrated'),
];

/// Returns `"😊 Happy"` for known emojis, or the raw [feeling] otherwise.
String formatFeeling(String feeling) {
  for (final option in kFeelingOptions) {
    if (option.emoji == feeling) return '${option.emoji} ${option.label}';
  }
  return feeling;
}

/// Emoji chip selector for picking how a memory felt.
class FeelingPicker extends StatelessWidget {
  const FeelingPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final option in kFeelingOptions)
          _FeelingChip(
            emoji: option.emoji,
            label: option.label,
            selected: value == option.emoji,
            textTheme: textTheme,
            onTap: () => onChanged(value == option.emoji ? null : option.emoji),
          ),
      ],
    );
  }
}

class _FeelingChip extends StatelessWidget {
  const _FeelingChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.textTheme,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlAll,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.xlAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
