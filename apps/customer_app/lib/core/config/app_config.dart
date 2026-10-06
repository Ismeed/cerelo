/// Application-level configuration for the Customer App.
///
/// Values are sourced exclusively from compile-time --dart-define flags.
/// This ensures secrets are NOT stored in the source repository.
///
/// SECURITY:
/// - Only values safe for client exposure are included here.
/// - The Supabase secret / service role key must NEVER appear in this file or app.
/// - supabasePublishableKey is a public key safe for client use (protected by RLS).
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.environment,
    required this.sentryDsn,
    required this.trackingBaseUrl,
  });

  final String supabaseUrl;

  /// Public Supabase publishable key (sb_publishable_...) — safe for client use.
  /// Row Level Security enforces data access on the database side.
  final String supabasePublishableKey;

  final String environment;
  final String sentryDsn;
  final String trackingBaseUrl;

  bool get isProduction => environment == 'production';
  bool get isDevelopment => environment == 'development';
  bool get isStaging => environment == 'staging';

  /// Reads configuration from compile-time --dart-define flags.
  /// Fails loudly if required variables are missing.
  factory AppConfig.fromEnvironment() {
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    const publishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: '',
    );

    const environment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const sentryDsn = String.fromEnvironment(
      'SENTRY_DSN',
      defaultValue: '',
    );
    const rawTrackingBaseUrl = String.fromEnvironment(
      'TRACKING_BASE_URL',
      defaultValue: '',
    );

    // Environment validation — fail fast with actionable messages.
    if (supabaseUrl.isEmpty) {
      throw Exception(
        'Missing required config: SUPABASE_URL\n'
        'Pass via: flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co',
      );
    }
    if (publishableKey.isEmpty) {
      throw Exception(
        'Missing required config: SUPABASE_PUBLISHABLE_KEY\n'
        'Pass via: flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key',
      );
    }
    if (publishableKey.startsWith('sb_secret_') || publishableKey.startsWith('service_role')) {
      throw Exception(
        'SECURITY VIOLATION: SUPABASE_PUBLISHABLE_KEY cannot be a secret key or service role key.',
      );
    }

    // A tracking link must point at the website backed by the SAME database as
    // this build. Both arms of this used to return cerelonet.com, so a staging
    // build emitted production tracking links — and because cerelonet.com reads
    // the production database, every such code resolved to "not found". Rather
    // than silently inherit production's host, a non-production build must name
    // its own (Vercel preview URLs are per-deployment, so there is nothing
    // stable to default to).
    final String effectiveTrackingBaseUrl;
    if (rawTrackingBaseUrl.isNotEmpty) {
      effectiveTrackingBaseUrl = rawTrackingBaseUrl;
    } else if (environment == 'production') {
      effectiveTrackingBaseUrl = 'https://cerelonet.com';
    } else {
      throw Exception(
        'Missing required config: TRACKING_BASE_URL. '
        'A non-production build (APP_ENV=$environment) must pass the tracking '
        'site that reads the same database as SUPABASE_URL, for example: '
        '--dart-define=TRACKING_BASE_URL=https://your-preview.vercel.app . '
        'Falling back to https://cerelonet.com would generate codes that site '
        'can never resolve, because it queries the production database.',
      );
    }

    return AppConfig(
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: publishableKey,
      environment: environment,
      sentryDsn: sentryDsn,
      trackingBaseUrl: effectiveTrackingBaseUrl,
    );
  }
}
