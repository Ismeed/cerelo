/// Personnel App configuration.
///
/// SECURITY:
/// - Only the Supabase publishable key is included here (safe for client).
/// - Personnel role is verified server-side from JWT app_metadata.
/// - Never hard-code founder email or Personnel IDs for special access.
class PersonnelConfig {
  const PersonnelConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.environment,
    required this.sentryDsn,
  });

  final String supabaseUrl;

  /// Public Supabase publishable key (sb_publishable_...) — safe for client use.
  final String supabasePublishableKey;

  final String environment;

  /// Sentry DSN — empty string means crash reporting is disabled.
  final String sentryDsn;

  bool get isProduction => environment == 'production';

  factory PersonnelConfig.fromEnvironment() {
    const supabaseUrl =
        String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const publishableKey =
        String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');

    const environment =
        String.fromEnvironment('APP_ENV', defaultValue: 'development');
    const sentryDsn =
        String.fromEnvironment('SENTRY_DSN', defaultValue: '');

    if (supabaseUrl.isEmpty) {
      throw Exception('Missing SUPABASE_URL — pass via --dart-define');
    }
    if (publishableKey.isEmpty) {
      throw Exception('Missing SUPABASE_PUBLISHABLE_KEY — pass via --dart-define');
    }
    if (publishableKey.startsWith('sb_secret_') || publishableKey.startsWith('service_role')) {
      throw Exception(
        'SECURITY VIOLATION: SUPABASE_PUBLISHABLE_KEY cannot be a secret key or service role key.',
      );
    }

    return PersonnelConfig(
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: publishableKey,
      environment: environment,
      sentryDsn: sentryDsn,
    );
  }
}
