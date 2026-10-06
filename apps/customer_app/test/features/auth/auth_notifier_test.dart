import 'dart:async';
import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:customer_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake AuthService for unit testing.
class FakeAuthService implements AuthService {
  FakeAuthService({
    this.initialUser,
  });

  CereloUser? initialUser;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  CereloUser? get currentUser => initialUser;

  @override
  String? get currentUserId => initialUser?.id;

  @override
  String? get currentUserEmail => initialUser?.email;

  @override
  bool get isAuthenticated => initialUser != null;

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {
    initialUser = const CereloUser(
      id: 'google-user-1',
      email: 'google@test.com',
      role: ActorRole.customer,
      phoneNumber: null,
    );
  }

  @override
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    initialUser = CereloUser(
      id: 'email-user-1',
      email: email,
      role: ActorRole.customer,
      phoneNumber: null,
    );
    return AuthResponse(
      user: User(
        id: 'email-user-1',
        appMetadata: {'role': 'customer'},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-08-17T00:00:00Z',
        email: email,
      ),
    );
  }

  @override
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    initialUser = CereloUser(
      id: 'new-email-user',
      email: email,
      role: ActorRole.customer,
      phoneNumber: null,
    );
    return AuthResponse(
      user: User(
        id: 'new-email-user',
        appMetadata: {'role': 'customer'},
        userMetadata: fullName != null ? {'full_name': fullName} : {},
        aud: 'authenticated',
        createdAt: '2026-08-17T00:00:00Z',
        email: email,
      ),
    );
  }

  @override
  Future<void> signInWithOtp({
    required String email,
    bool shouldCreateUser = true,
    String? fullName,
    String? redirectTo,
  }) async {
    // Simulates successful OTP dispatch
  }

  @override
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    OtpType type = OtpType.email,
  }) async {
    if (token == '000000') {
      throw const CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: 'Invalid verification code. Please check and enter the 6-digit code again.',
      );
    }
    initialUser = CereloUser(
      id: 'otp-user-1',
      email: email,
      role: ActorRole.customer,
      phoneNumber: null,
    );
    return AuthResponse(
      user: User(
        id: 'otp-user-1',
        appMetadata: {'role': 'customer'},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-08-17T00:00:00Z',
        email: email,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    initialUser = null;
  }

  @override
  Future<void> refreshSession() async {}
}

/// Fake CustomerService for unit testing.
class FakeCustomerService implements CustomerService {
  FakeCustomerService({
    this.profileToReturn,
    this.shouldThrow = false,
  });

  CustomerProfileDto? profileToReturn;
  bool shouldThrow;

  @override
  Future<CustomerProfileDto> getCurrentProfile() async {
    if (shouldThrow) {
      throw const CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Network error.',
      );
    }
    return profileToReturn ??
        const CustomerProfileDto(
          id: 'test-user',
          fullName: 'Test Customer',
          accountType: AccountType.individual,
          onboardingCompletedAt: null,
        );
  }

  @override
  Future<CustomerProfileDto> completeOnboarding({
    required AccountType accountType,
    String? businessName,
    String? fullName,
  }) async {
    if (accountType == AccountType.business &&
        (businessName == null || businessName.trim().isEmpty)) {
      throw const CereloApiError(
        code: CereloErrorCode.validationError,
        message: 'Business name is required.',
      );
    }

    final updated = (profileToReturn ??
            const CustomerProfileDto(
              id: 'test-user',
              fullName: 'Test Customer',
              accountType: AccountType.individual,
            ))
        .copyWith(
      accountType: accountType,
      businessName: businessName,
      fullName: fullName,
      onboardingCompletedAt: DateTime.now(),
    );
    profileToReturn = updated;
    return updated;
  }

  @override
  Future<CustomerProfileDto> updateProfile({
    String? fullName,
    String? businessName,
  }) async {
    final updated = (profileToReturn ??
            const CustomerProfileDto(
              id: 'test-user',
              fullName: 'Test Customer',
              accountType: AccountType.individual,
            ))
        .copyWith(
      fullName: fullName,
      businessName: businessName,
    );
    profileToReturn = updated;
    return updated;
  }
}

void main() {
  group('CustomerAuthNotifier', () {
    test('initial unauthenticated state when no session exists', () {
      final fakeAuth = FakeAuthService(initialUser: null);
      final fakeCustomer = FakeCustomerService();

      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      expect(notifier.state.status, equals(CustomerAuthStatus.unauthenticated));
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.profile, isNull);
    });

    test(
        'sets authenticatedIncomplete when user exists but onboarding is not completed',
        () async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'user1@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: const CustomerProfileDto(
          id: 'user-1',
          fullName: 'New User',
          accountType: AccountType.individual,
          onboardingCompletedAt: null, // Incomplete!
        ),
      );

      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      // Allow microtask to resolve
      await Future<void>.delayed(Duration.zero);

      expect(
        notifier.state.status,
        equals(CustomerAuthStatus.authenticatedIncomplete),
      );
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.isOnboardingComplete, isFalse);
      expect(notifier.state.profile?.fullName, equals('New User'));
    });

    test(
        'sets authenticatedComplete when user exists and onboarding is completed',
        () async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-2',
          email: 'user2@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: CustomerProfileDto(
          id: 'user-2',
          fullName: 'Returning Customer',
          accountType: AccountType.individual,
          onboardingCompletedAt: DateTime.parse('2026-08-17T00:00:00Z'),
        ),
      );

      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await Future<void>.delayed(Duration.zero);

      expect(
        notifier.state.status,
        equals(CustomerAuthStatus.authenticatedComplete),
      );
      expect(notifier.state.isOnboardingComplete, isTrue);
    });

    test('completing onboarding with Individual updates state to complete',
        () async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-3',
          email: 'user3@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: const CustomerProfileDto(
          id: 'user-3',
          fullName: 'Individual User',
          accountType: AccountType.individual,
          onboardingCompletedAt: null,
        ),
      );

      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await Future<void>.delayed(Duration.zero);
      expect(
        notifier.state.status,
        equals(CustomerAuthStatus.authenticatedIncomplete),
      );

      await notifier.completeOnboarding(
        accountType: AccountType.individual,
      );

      expect(
        notifier.state.status,
        equals(CustomerAuthStatus.authenticatedComplete),
      );
      expect(notifier.state.profile?.accountType, equals(AccountType.individual));
      expect(notifier.state.profile?.isOnboardingComplete, isTrue);
    });

    test(
        'completing onboarding with Business saves business name and completes',
        () async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-4',
          email: 'trader@kwari.ng',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: const CustomerProfileDto(
          id: 'user-4',
          fullName: 'Kwari Trader',
          accountType: AccountType.individual,
          onboardingCompletedAt: null,
        ),
      );

      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await Future<void>.delayed(Duration.zero);

      await notifier.completeOnboarding(
        accountType: AccountType.business,
        businessName: 'Kwari Fabrics Shop 12',
      );

      expect(
        notifier.state.status,
        equals(CustomerAuthStatus.authenticatedComplete),
      );
      expect(notifier.state.profile?.accountType, equals(AccountType.business));
      expect(
        notifier.state.profile?.businessName,
        equals('Kwari Fabrics Shop 12'),
      );
      expect(notifier.state.profile?.isBusiness, isTrue);
    });

    test('signOut clears state and returns to unauthenticated', () async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-5',
          email: 'user5@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: CustomerProfileDto(
          id: 'user-5',
          fullName: 'User 5',
          accountType: AccountType.individual,
          onboardingCompletedAt: DateTime.now(),
        ),
      );

      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await Future<void>.delayed(Duration.zero);
      expect(
        notifier.state.status,
        equals(CustomerAuthStatus.authenticatedComplete),
      );

      await notifier.signOut();

      expect(notifier.state.status, equals(CustomerAuthStatus.unauthenticated));
      expect(notifier.state.profile, isNull);
      expect(fakeAuth.isAuthenticated, isFalse);
    });

    test('handles error loading profile and recovers on retry', () async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-6',
          email: 'user6@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(shouldThrow: true);

      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, equals(CustomerAuthStatus.error));
      expect(notifier.state.errorMessage, contains('Network error'));

      // Fix error and retry
      fakeCustomer.shouldThrow = false;
      fakeCustomer.profileToReturn = CustomerProfileDto(
        id: 'user-6',
        fullName: 'User 6 Recovered',
        accountType: AccountType.individual,
        onboardingCompletedAt: DateTime.now(),
      );

      await notifier.retryProfileResolution();

      expect(
        notifier.state.status,
        equals(CustomerAuthStatus.authenticatedComplete),
      );
      expect(notifier.state.profile?.fullName, equals('User 6 Recovered'));
    });

    group('Email OTP Flow', () {
      test('requestEmailOtp dispatches OTP and updates pending state', () async {
        final fakeAuth = FakeAuthService();
        final fakeCustomer = FakeCustomerService();

        final notifier = CustomerAuthNotifier(
          authService: fakeAuth,
          customerService: fakeCustomer,
        );

        expect(notifier.state.isOtpSent, isFalse);
        expect(notifier.state.pendingEmail, isNull);

        await notifier.requestEmailOtp(
          email: 'test@cerelo.com',
          fullName: 'Test Sender',
        );

        expect(notifier.state.isOtpSent, isTrue);
        expect(notifier.state.pendingEmail, equals('test@cerelo.com'));
        expect(notifier.state.pendingFullName, equals('Test Sender'));
        expect(notifier.state.errorMessage, isNull);
      });

      test('verifyEmailOtp transitions to authenticatedIncomplete for new customer', () async {
        final fakeAuth = FakeAuthService();
        final fakeCustomer = FakeCustomerService(
          profileToReturn: const CustomerProfileDto(
            id: 'otp-user-1',
            fullName: 'New Customer',
            accountType: AccountType.individual,
            onboardingCompletedAt: null, // Incomplete onboarding
          ),
        );

        final notifier = CustomerAuthNotifier(
          authService: fakeAuth,
          customerService: fakeCustomer,
        );

        await notifier.requestEmailOtp(
          email: 'newcustomer@cerelo.com',
          fullName: 'New Customer',
        );

        await notifier.verifyEmailOtp(token: '123456');

        expect(
          notifier.state.status,
          equals(CustomerAuthStatus.authenticatedIncomplete),
        );
        expect(notifier.state.isAuthenticated, isTrue);
        expect(notifier.state.isOnboardingComplete, isFalse);
        expect(notifier.state.profile?.fullName, equals('New Customer'));
      });

      test('verifyEmailOtp transitions to authenticatedComplete for existing customer', () async {
        final fakeAuth = FakeAuthService();
        final fakeCustomer = FakeCustomerService(
          profileToReturn: CustomerProfileDto(
            id: 'otp-user-1',
            fullName: 'Existing Customer',
            accountType: AccountType.business,
            businessName: 'Kano Textiles Ltd',
            onboardingCompletedAt: DateTime.parse('2026-08-17T00:00:00Z'),
          ),
        );

        final notifier = CustomerAuthNotifier(
          authService: fakeAuth,
          customerService: fakeCustomer,
        );

        await notifier.requestEmailOtp(
          email: 'existing@cerelo.com',
        );

        await notifier.verifyEmailOtp(token: '654321');

        expect(
          notifier.state.status,
          equals(CustomerAuthStatus.authenticatedComplete),
        );
        expect(notifier.state.isOnboardingComplete, isTrue);
        expect(notifier.state.profile?.isBusiness, isTrue);
      });

      test('verifyEmailOtp with invalid token surfaces error message', () async {
        final fakeAuth = FakeAuthService();
        final fakeCustomer = FakeCustomerService();

        final notifier = CustomerAuthNotifier(
          authService: fakeAuth,
          customerService: fakeCustomer,
        );

        await notifier.requestEmailOtp(
          email: 'test@cerelo.com',
        );

        try {
          await notifier.verifyEmailOtp(token: '000000');
        } catch (_) {}

        expect(notifier.state.errorMessage, contains('Invalid verification code'));
        expect(notifier.state.isAuthenticated, isFalse);
      });

      test('resendEmailOtp re-requests OTP for pending email', () async {
        final fakeAuth = FakeAuthService();
        final fakeCustomer = FakeCustomerService();

        final notifier = CustomerAuthNotifier(
          authService: fakeAuth,
          customerService: fakeCustomer,
        );

        await notifier.requestEmailOtp(
          email: 'resend@cerelo.com',
          fullName: 'Resend User',
        );

        await notifier.resendEmailOtp();

        expect(notifier.state.isOtpSent, isTrue);
        expect(notifier.state.pendingEmail, equals('resend@cerelo.com'));
      });

      test('resetEmailOtp clears pending state allowing email change', () async {
        final fakeAuth = FakeAuthService();
        final fakeCustomer = FakeCustomerService();

        final notifier = CustomerAuthNotifier(
          authService: fakeAuth,
          customerService: fakeCustomer,
        );

        await notifier.requestEmailOtp(
          email: 'change@cerelo.com',
          fullName: 'Change User',
        );

        expect(notifier.state.isOtpSent, isTrue);

        notifier.resetEmailOtp();

        expect(notifier.state.isOtpSent, isFalse);
        expect(notifier.state.pendingEmail, isNull);
        expect(notifier.state.pendingFullName, isNull);
      });
    });
  });
}
