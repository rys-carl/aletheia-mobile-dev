import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/services/supabase_client.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/widgets/confirm_dialog.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';

/// Who is signed in, and the log out button.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logOut(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You can log back in any time.',
      confirmLabel: 'Log Out',
      icon: Icons.logout,
      destructive: false,
    );
    if (!confirmed || !context.mounted) return;

    final navigator = Navigator.of(context);
    await supabase.auth.signOut();
    // The auth gate swaps to the login page underneath; close this page (and
    // anything else pushed on top) so it is visible.
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final email = supabase.auth.currentUser?.email ?? '';
    final initial = email.isEmpty ? '?' : email[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary,
              child: Text(
                initial,
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              email,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Log Out',
              onPressed: () => _logOut(context),
            ),
          ],
        ),
      ),
    );
  }
}
