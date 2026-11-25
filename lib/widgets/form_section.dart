import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_dimens.dart';

/// A bold label sitting above a form control, like in the mockups.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
