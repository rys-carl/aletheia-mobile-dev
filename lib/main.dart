import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aletheia_dev/app.dart';
import 'package:aletheia_dev/core/config/app_config.dart';
import 'package:aletheia_dev/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  if (AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseKey.isEmpty) {
    throw StateError(
      'Missing Supabase config. Run with --dart-define-from-file=env.json',
    );
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
  );

  runApp(const AletheiaApp());
}