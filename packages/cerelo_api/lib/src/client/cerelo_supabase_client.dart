import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes and provides access to the Supabase client.
///
/// SECURITY:
/// - Only the public publishable/anon key is used here. It is safe for client use.
/// - The Supabase SERVICE ROLE KEY / SECRET KEY must NEVER appear in this package or any client code.
/// - Row Level Security (RLS) enforces data access on the database side.
/// - All state-changing operations must go through Edge Function RPCs.
///
/// Usage:
///   await CereloSupabaseClient.initialize(
///     supabaseUrl: config.supabaseUrl,
///     supabasePublishableKey: config.supabasePublishableKey,
///   );
class CereloSupabaseClient {
  CereloSupabaseClient._();

  static SupabaseClient? _mockClient;

  /// Sets a mock client for testing.
  // ignore: use_setters_to_change_properties
  static void setMockClient(SupabaseClient client) {
    _mockClient = client;
  }

  static SupabaseClient get instance {
    if (_mockClient != null) return _mockClient!;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return SupabaseClient(
        'https://mock.supabase.co',
        'mock-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
    }
  }

  /// Initializes the Supabase client. Call this once at app startup.
  ///
  /// The [supabaseUrl] and [supabasePublishableKey] values are read from
  /// app-level configuration (never hard-coded in source).
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabasePublishableKey,
  }) async {
    assert(supabaseUrl.isNotEmpty, 'Supabase URL must not be empty');
    assert(
      supabasePublishableKey.isNotEmpty,
      'Supabase publishable key must not be empty. Ensure SUPABASE_PUBLISHABLE_KEY is provided.',
    );
    assert(
      !supabasePublishableKey.startsWith('service_role') &&
          !supabasePublishableKey.startsWith('sb_secret_'),
      // SECURITY: Service role / secret keys must never appear in client code.
      'SECURITY VIOLATION: Supabase secret key detected in client app.',
    );

    if (supabasePublishableKey.startsWith('service_role') ||
        supabasePublishableKey.startsWith('sb_secret_')) {
      throw StateError(
        'SECURITY VIOLATION: Supabase secret key detected in client app.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
      debug: kDebugMode,
    );
  }

  /// Returns the currently authenticated user session, or null if unauthenticated.
  static Session? get currentSession => instance.auth.currentSession;

  /// Returns the currently authenticated user, or null if unauthenticated.
  static User? get currentUser => instance.auth.currentUser;

  /// Whether a user is currently authenticated.
  static bool get isAuthenticated => currentUser != null;
}
