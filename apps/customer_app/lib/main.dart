import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load and validate environment configuration.
  // App will show a clear error if required config is missing.
  final config = AppConfig.fromEnvironment();

  // Initialize Supabase with app-config values.
  // SECURITY: Only the public publishable key is used here.
  await CereloSupabaseClient.initialize(
    supabaseUrl: config.supabaseUrl,
    supabasePublishableKey: config.supabasePublishableKey,
  );

  // Sentry crash reporting — only initialized when DSN is provided.
  // Staging/production supply SENTRY_DSN via --dart-define; dev omits it.
  if (config.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = config.sentryDsn;
        options.environment = config.environment;
        options.tracesSampleRate = config.isProduction ? 0.2 : 1.0;
        // SECURITY: Never send PII in breadcrumbs.
        options.sendDefaultPii = false;
      },
      appRunner: () => _runApp(config),
    );
  } else {
    _runApp(config);
  }
}

void _runApp(AppConfig config) {
  runApp(
    ProviderScope(
      child: CereloCustomerApp(config: config),
    ),
  );
}
