import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aletheia_dev/core/config/app_config.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';

/// Brand screen shown for a moment when the app starts.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Text(
            AppConfig.appName,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
          ),
        ),
      ),
    );
  }
}
