import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aletheia_dev/core/config/app_config.dart';
import 'package:aletheia_dev/core/services/supabase_client.dart';
import 'package:aletheia_dev/core/theme/app_theme.dart';
import 'package:aletheia_dev/features/auth/login_page.dart';
import 'package:aletheia_dev/features/auth/splash_page.dart';
import 'package:aletheia_dev/features/home/home_shell.dart';

class AletheiaApp extends StatelessWidget {
  const AletheiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _AppRoot(),
    );
  }
}

/// Shows the splash screen briefly, then hands over to [AuthGate].
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final Timer _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _ready
            ? const AuthGate(key: ValueKey('auth'))
            : const SplashPage(key: ValueKey('splash')),
      ),
    );
  }
}

/// Shows the login page when signed out, and the app when signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? supabase.auth.currentSession;
        return session == null ? const LoginPage() : const HomeShell();
      },
    );
  }
}
