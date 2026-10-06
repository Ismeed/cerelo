import 'dart:async';
import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/local/customer_local_db.dart';

/// Authentication status for the Customer App.
enum CustomerAuthStatus {
  /// Startup phase: checking for stored session.
  initial,
  /// In-progress async action (signing in, resolving profile).
  loading,
  /// No valid session — show login screen.
  unauthenticated,
  /// Authenticated, but onboarding is incomplete — show onboarding flow.
  authenticatedIncomplete,
  /// Authenticated and onboarding complete — show main app (Home).
  authenticatedComplete,
  /// Profile resolution or network failure.
  error,
}

/// State object representing the customer auth and onboarding state.
@immutable
class CustomerAuthState {
  const CustomerAuthState({
    this.status = CustomerAuthStatus.initial,
    this.user,
    this.profile,
    this.errorMessage,
    this.isActionLoading = false,
    this.pendingEmail,
    this.pendingFullName,
    this.isOtpSent = false,
    this.isOfflineCached = false,
    this.lastSyncedAt,
  });

  final CustomerAuthStatus status;
  final CereloUser? user;
  final CustomerProfileDto? profile;
  final String? errorMessage;
  final bool isActionLoading;
  final String? pendingEmail;
  final String? pendingFullName;
  final bool isOtpSent;

  /// True when profile data was loaded from the local cache (offline mode).
  final bool isOfflineCached;

  /// When the profile was last successfully synced from the server.
  final DateTime? lastSyncedAt;

  bool get isAuthenticated =>
      status == CustomerAuthStatus.authenticatedComplete ||
      status == CustomerAuthStatus.authenticatedIncomplete;

  bool get isOnboardingComplete =>
      status == CustomerAuthStatus.authenticatedComplete &&
      profile?.isOnboardingComplete == true;

  CustomerAuthState copyWith({
    CustomerAuthStatus? status,
    CereloUser? user,
    CustomerProfileDto? profile,
    String? errorMessage,
    bool clearError = false,
    bool? isActionLoading,
    String? pendingEmail,
    String? pendingFullName,
    bool? isOtpSent,
    bool clearPendingEmail = false,
    bool? isOfflineCached,
    DateTime? lastSyncedAt,
  }) {
    return CustomerAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isActionLoading: isActionLoading ?? this.isActionLoading,
      pendingEmail: clearPendingEmail ? null : (pendingEmail ?? this.pendingEmail),
      pendingFullName: clearPendingEmail ? null : (pendingFullName ?? this.pendingFullName),
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isOfflineCached: isOfflineCached ?? this.isOfflineCached,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

/// Provider for [AuthService].
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Provider for [CustomerService].
final customerServiceProvider = Provider<CustomerService>((ref) => CustomerService());

/// Main notifier managing Customer Auth & Onboarding State.
class CustomerAuthNotifier extends StateNotifier<CustomerAuthState> {
  CustomerAuthNotifier({
    required AuthService authService,
    required CustomerService customerService,
  })  : _authService = authService,
        _customerService = customerService,
        super(const CustomerAuthState()) {
    _init();
  }

  final AuthService _authService;
  final CustomerService _customerService;
  final _localDb = CustomerLocalDb.instance;
  StreamSubscription<AuthState>? _authSub;

  void _init() {
    _authSub = _authService.authStateChanges.listen((data) {
      final session = data.session;
      if (session == null) {
        if (data.event == AuthChangeEvent.signedOut ||
            data.event == AuthChangeEvent.userDeleted) {
          state = const CustomerAuthState(status: CustomerAuthStatus.unauthenticated);
        } else if (state.status != CustomerAuthStatus.unauthenticated) {
          state = state.copyWith(status: CustomerAuthStatus.unauthenticated);
        }
      } else {
        final user = _authService.currentUser;
        if (user != null) {
          _resolveProfile(user, fromAuthEvent: true);
        }
      }
    });

    // LOCAL-FIRST STARTUP: enter app immediately with cached data, then sync.
    final user = _authService.currentUser;
    if (user != null) {
      _resolveProfile(user);
    } else {
      state = const CustomerAuthState(status: CustomerAuthStatus.unauthenticated);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Resolves the customer profile with local-first semantics.
  ///
  /// 1. Load cached profile → enter app immediately (unblocks UI).
  /// 2. Fetch live profile from Supabase in background.
  /// 3. Network failure → keep cached state; genuine auth rejection → sign out.
  Future<void> _resolveProfile(CereloUser user, {bool fromAuthEvent = false}) async {
    // Step 1: Serve cached profile immediately (not for auth events which need fresh data).
    if (!fromAuthEvent) {
      final cachedData = await _localDb.loadProfile(user.id);
      if (cachedData != null) {
        final cachedProfile = _profileFromCache(user.id, cachedData);
        if (cachedProfile != null) {
          final cachedAt = cachedData['cached_at'] as String?;
          state = state.copyWith(
            status: cachedProfile.isOnboardingComplete
                ? CustomerAuthStatus.authenticatedComplete
                : CustomerAuthStatus.authenticatedIncomplete,
            user: user,
            profile: cachedProfile,
            isActionLoading: false,
            clearError: true,
            isOfflineCached: true,
            lastSyncedAt: cachedAt != null ? DateTime.tryParse(cachedAt) : null,
          );
        }
      }
    }

    // Step 2: Show loading only if we have no state yet.
    if (!state.isAuthenticated) {
      state = state.copyWith(
        status: CustomerAuthStatus.loading,
        user: user,
        isActionLoading: false,
        clearError: true,
      );
    }

    // Step 3: Fetch live profile.
    try {
      final profile = await _customerService.getCurrentProfile();
      final now = DateTime.now();

      await _localDb.saveProfile(
        userId: user.id,
        profileJson: profile.toJson(),
      );

      state = state.copyWith(
        status: profile.isOnboardingComplete
            ? CustomerAuthStatus.authenticatedComplete
            : CustomerAuthStatus.authenticatedIncomplete,
        user: user,
        profile: profile,
        isActionLoading: false,
        clearError: true,
        isOfflineCached: false,
        lastSyncedAt: now,
      );
    } catch (e) {
      if (_isAuthRejection(e)) {
        await _clearLocalDataForUser(user.id);
        state = const CustomerAuthState(status: CustomerAuthStatus.unauthenticated);
        return;
      }
      // Network failure: stay authenticated with cached data if possible.
      if (!state.isAuthenticated) {
        final cachedData = await _localDb.loadProfile(user.id);
        if (cachedData != null) {
          final cachedProfile = _profileFromCache(user.id, cachedData);
          if (cachedProfile != null) {
            state = state.copyWith(
              status: cachedProfile.isOnboardingComplete
                  ? CustomerAuthStatus.authenticatedComplete
                  : CustomerAuthStatus.authenticatedIncomplete,
              user: user,
              profile: cachedProfile,
              isActionLoading: false,
              clearError: true,
              isOfflineCached: true,
            );
            return;
          }
        }
        state = state.copyWith(
          status: CustomerAuthStatus.error,
          user: user,
          isActionLoading: false,
          errorMessage: 'No internet connection. Please retry when connected.',
        );
      } else {
        state = state.copyWith(isOfflineCached: true);
      }
    }
  }

  bool _isAuthRejection(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      return msg.contains('jwt') ||
          msg.contains('not authenticated') ||
          msg.contains('invalid token') ||
          msg.contains('user not found') ||
          msg.contains('session_not_found');
    }
    return false;
  }

  CustomerProfileDto? _profileFromCache(String userId, Map<String, dynamic> row) {
    try {
      return CustomerProfileDto.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearLocalDataForUser(String userId) async {
    try {
      await _localDb.clearSensitiveData(userId);
    } catch (_) {}
  }

  /// Retries profile resolution (used when profile fetch previously failed).
  Future<void> retryProfileResolution() async {
    final user = _authService.currentUser;
    if (user != null) {
      await _resolveProfile(user, fromAuthEvent: true);
    } else {
      state = const CustomerAuthState(status: CustomerAuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      await _authService.signInWithGoogle(
        redirectTo: 'com.cerelo.customer://login-callback/',
      );
      state = state.copyWith(isActionLoading: false);
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e is CereloApiError ? e.message : 'Google sign-in failed. Please try again.',
      );
    }
  }

  Future<void> requestEmailOtp({required String email, String? fullName}) async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      await _authService.signInWithOtp(email: email, fullName: fullName);
      state = state.copyWith(
        isActionLoading: false,
        pendingEmail: email.trim().toLowerCase(),
        pendingFullName: fullName?.trim(),
        isOtpSent: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e is CereloApiError
            ? e.message
            : 'Could not send verification code. Please try again.',
      );
      rethrow;
    }
  }

  Future<void> verifyEmailOtp({required String token}) async {
    final email = state.pendingEmail;
    if (email == null || email.isEmpty) {
      state = state.copyWith(errorMessage: 'Session expired. Please enter your email again.');
      return;
    }
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      final response = await _authService.verifyOtp(
        email: email,
        token: token,
        type: OtpType.email,
      );
      state = state.copyWith(isActionLoading: false);
      final user = response.user != null
          ? CereloUser.fromSupabaseUser(response.user!)
          : _authService.currentUser;
      if (user != null) {
        await _resolveProfile(user, fromAuthEvent: true);
      }
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e is CereloApiError
            ? e.message
            : 'Verification failed. Please check the code and try again.',
      );
      rethrow;
    }
  }

  Future<void> resendEmailOtp() async {
    final email = state.pendingEmail;
    if (email == null || email.isEmpty) return;
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      await _authService.signInWithOtp(email: email, fullName: state.pendingFullName);
      state = state.copyWith(isActionLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e is CereloApiError
            ? e.message
            : 'Could not resend verification code. Please try again.',
      );
      rethrow;
    }
  }

  void resetEmailOtp() {
    state = state.copyWith(isOtpSent: false, clearPendingEmail: true, clearError: true);
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      final response = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isActionLoading: false);
      final user = response.user != null
          ? CereloUser.fromSupabaseUser(response.user!)
          : _authService.currentUser;
      if (user != null) await _resolveProfile(user, fromAuthEvent: true);
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e is CereloApiError ? e.message : 'Sign-in failed. Please check your credentials.',
      );
      rethrow;
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      final response = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
      );
      state = state.copyWith(isActionLoading: false);
      final user = response.user != null
          ? CereloUser.fromSupabaseUser(response.user!)
          : _authService.currentUser;
      if (user != null) await _resolveProfile(user, fromAuthEvent: true);
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e is CereloApiError ? e.message : 'Account creation failed. Please try again.',
      );
      rethrow;
    }
  }

  Future<void> completeOnboarding({
    required AccountType accountType,
    String? businessName,
    String? fullName,
  }) async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      final updatedProfile = await _customerService.completeOnboarding(
        accountType: accountType,
        businessName: businessName,
        fullName: fullName,
      );
      final user = state.user;
      if (user != null) {
        await _localDb.saveProfile(
          userId: user.id,
          profileJson: updatedProfile.toJson(),
        );
      }
      state = state.copyWith(
        status: CustomerAuthStatus.authenticatedComplete,
        profile: updatedProfile,
        isActionLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e is CereloApiError ? e.message : 'Could not complete onboarding. Please try again.',
      );
      rethrow;
    }
  }

  Future<void> updateProfile({String? fullName, String? businessName}) async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      final updated = await _customerService.updateProfile(
        fullName: fullName,
        businessName: businessName,
      );
      final user = state.user;
      if (user != null) {
        await _localDb.saveProfile(
          userId: user.id,
          profileJson: updated.toJson(),
        );
      }
      state = state.copyWith(profile: updated, isActionLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e is CereloApiError ? e.message : 'Failed to update profile.',
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    final userId = state.user?.id;
    state = state.copyWith(isActionLoading: true);
    try {
      // Clear local cache before signing out.
      if (userId != null) await _clearLocalDataForUser(userId);
      await _authService.signOut();
      state = const CustomerAuthState(status: CustomerAuthStatus.unauthenticated);
    } catch (e) {
      state = const CustomerAuthState(status: CustomerAuthStatus.unauthenticated);
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

/// Main Riverpod provider for Customer Auth State.
final customerAuthProvider =
    StateNotifierProvider<CustomerAuthNotifier, CustomerAuthState>((ref) {
  return CustomerAuthNotifier(
    authService: ref.watch(authServiceProvider),
    customerService: ref.watch(customerServiceProvider),
  );
});
