import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication service for Cerelo apps.
///
/// Wraps Supabase Auth flows for Google OAuth and email authentication.
///
/// SECURITY:
/// - Session tokens are managed by the Supabase SDK using OS-backed secure storage.
/// - Role is derived from server-issued JWT claims (app_metadata), never from client input.
/// - Auth state changes are propagated via the [authStateChanges] stream.
class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? CereloSupabaseClient.instance;

  final SupabaseClient _client;

  /// Stream of authentication state changes.
  /// UI listens to this to respond to login/logout/session-refresh events.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// The currently authenticated Cerelo user, or null if unauthenticated.
  CereloUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return CereloUser.fromSupabaseUser(user);
  }

  /// Returns the raw Supabase user ID if authenticated.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Returns the raw Supabase user email if available.
  String? get currentUserEmail => _client.auth.currentUser?.email;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Signs in with Google OAuth 2.0.
  ///
  /// Redirects through the native Google sign-in flow.
  /// On success, Supabase Auth updates the session and [authStateChanges] emits a new event.
  ///
  /// [redirectTo] must be provided by the caller using the correct app deep-link scheme
  /// (e.g. `com.cerelo.customer://login-callback/` for the Customer app).
  /// No default is applied here to prevent cross-app deep-link leakage.
  Future<void> signInWithGoogle({String? redirectTo}) async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (e is AuthException) {
        throw CereloApiError(
          code: CereloErrorCode.unauthenticated,
          message: e.message,
        );
      }
      rethrow;
    }
  }

  /// Signs in with email and password.
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: _mapAuthErrorMessage(e.message),
      );
    }
  }

  /// Signs up with email and password (Customer registration).
  ///
  /// [fullName] is passed into `data` so the database trigger can automatically
  /// seed the customer profile `full_name`.
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: fullName != null && fullName.trim().isNotEmpty
            ? {'full_name': fullName.trim()}
            : null,
      );
    } on AuthException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.validationError,
        message: _mapAuthErrorMessage(e.message),
      );
    }
  }

  /// Requests a numeric Email OTP for passwordless authentication.
  ///
  /// [shouldCreateUser] controls whether unregistered emails create accounts.
  /// [fullName] is passed into `data` so the database trigger can automatically
  /// seed the customer profile `full_name` upon first registration.
  ///
  /// [redirectTo] should only be supplied for magic-link flows. For code-based
  /// OTP (6-digit code entry), omit this parameter — no redirect URL is needed
  /// and setting one causes the Supabase OTP email to embed a deep-link that
  /// may open the wrong app on the device.
  Future<void> signInWithOtp({
    required String email,
    bool shouldCreateUser = true,
    String? fullName,
    String? redirectTo,
  }) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        shouldCreateUser: shouldCreateUser,
        data: fullName != null && fullName.trim().isNotEmpty
            ? {'full_name': fullName.trim()}
            : null,
        emailRedirectTo: redirectTo, // null = no redirect link in OTP email
      );
    } on AuthException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.validationError,
        message: _mapAuthErrorMessage(e.message),
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Could not send verification code. Please try again.',
      );
    }
  }

  /// Verifies a 6-digit numeric Email OTP and creates an authenticated session.
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    OtpType type = OtpType.email,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: type,
      );
      return response;
    } on AuthException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: _mapAuthErrorMessage(e.message),
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Verification failed. Please try again.',
      );
    }
  }

  /// Signs the current user out, clearing session storage.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      // In case of network failure during signOut, ensure local session is cleared
      if (e is AuthException) {
        throw CereloApiError(
          code: CereloErrorCode.internalError,
          message: e.message,
        );
      }
      rethrow;
    }
  }

  /// Refreshes the current session token.
  Future<void> refreshSession() async {
    await _client.auth.refreshSession();
  }

  static String _mapAuthErrorMessage(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('token has expired') ||
        lower.contains('otp expired') ||
        lower.contains('token is expired')) {
      return 'Verification code has expired. Please request a new code.';
    }
    if (lower.contains('invalid token') ||
        lower.contains('invalid otp') ||
        lower.contains('token is invalid') ||
        lower.contains('token is wrong') ||
        lower.contains('incorrect code')) {
      return 'Invalid verification code. Please check and enter the 6-digit code again.';
    }
    if (lower.contains('rate limit') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a minute before requesting another code.';
    }
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already exists')) {
      return 'An account with this email already exists. Please sign in.';
    }
    if (lower.contains('password') && lower.contains('least')) {
      return 'Password must be at least 6 characters.';
    }
    if (lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    return rawMessage;
  }
}
