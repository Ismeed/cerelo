import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';
import 'core/config/personnel_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = PersonnelConfig.fromEnvironment();

  // SECURITY: Only the public publishable key is initialized here.
  await CereloSupabaseClient.initialize(
    supabaseUrl: config.supabaseUrl,
    supabasePublishableKey: config.supabasePublishableKey,
  );

  // Sentry — only initialized when DSN is provided.
  if (config.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = config.sentryDsn;
        options.environment = config.environment;
        options.sendDefaultPii = false;
      },
      appRunner: () => _runApp(config),
    );
  } else {
    _runApp(config);
  }
}

void _runApp(PersonnelConfig config) {
  runApp(
    ProviderScope(
      child: CereloPersonnelApp(config: config),
    ),
  );
}

