import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aletheia_dev/core/config/app_config.dart';
import 'package:aletheia_dev/core/services/supabase_client.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/widgets/form_section.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';

/// Log in, create an account, or ask for a password reset email.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _signUp = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailLooksValid {
    final email = _email.text.trim();
    return email.isNotEmpty && email.contains('@');
  }

  void _toggleMode() {
    setState(() {
      _signUp = !_signUp;
      _error = null;
      _info = null;
    });
  }

  Future<void> _submit() async {
    if (!_emailLooksValid) {
      setState(() {
        _error = 'Enter a valid email address.';
        _info = null;
      });
      return;
    }
    final password = _password.text;
    if (password.isEmpty || (_signUp && password.length < 6)) {
      setState(() {
        _error = _signUp
            ? 'Password must be at least 6 characters.'
            : 'Enter your password.';
        _info = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final email = _email.text.trim();
      if (_signUp) {
        final response =
            await supabase.auth.signUp(email: email, password: password);
        // With email confirmation turned on there is no session yet.
        if (response.session == null && mounted) {
          setState(() {
            _signUp = false;
            _info = 'Check your email to confirm your account, then log in.';
          });
        }
      } else {
        await supabase.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (!_emailLooksValid) {
      setState(() {
        _error = 'Enter your email above first, then tap "Forgot password?".';
        _info = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await supabase.auth.resetPasswordForEmail(_email.text.trim());
      if (mounted) {
        setState(() => _info = 'Password reset email sent. Check your inbox.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    _signUp ? 'Create Account' : 'Log In',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FormSection(
                    label: 'Email Address',
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Enter email address',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FormSection(
                    label: 'Password',
                    child: TextField(
                      controller: _password,
                      obscureText: _hidePassword,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Enter password',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_signUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    )
                  else
                    const SizedBox(height: AppSpacing.sm),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_info != null) ...[
                    Text(
                      _info!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: _signUp ? 'Create Account' : 'Log In',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _signUp
                            ? 'Already have an account?'
                            : "Don't have an account?",
                        style: textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _loading ? null : _toggleMode,
                        child: Text(_signUp ? 'Log In' : 'Create Account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
