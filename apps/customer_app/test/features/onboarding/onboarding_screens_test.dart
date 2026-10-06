import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/features/account/screens/account_screen.dart';
import 'package:customer_app/features/auth/providers/auth_provider.dart';
import 'package:customer_app/features/onboarding/screens/account_type_screen.dart';
import 'package:customer_app/features/onboarding/screens/business_name_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_notifier_test.dart';

void main() {
  Widget createTestWidget({
    required Widget child,
    required CustomerAuthNotifier notifier,
  }) {
    return ProviderScope(
      overrides: [
        customerAuthProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: child,
      ),
    );
  }

  group('AccountTypeScreen', () {
    testWidgets('renders Individual and Business options', (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'user@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const AccountTypeScreen(),
          notifier: notifier,
        ),
      );

      expect(find.text('How will you use Cerelo?'), findsOneWidget);
      expect(find.text('Individual'), findsOneWidget);
      expect(find.text('Business / Merchant'), findsOneWidget);
      expect(find.text('Complete Setup'), findsOneWidget);
    });

    testWidgets('switching to Business changes button to Continue',
        (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'user@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const AccountTypeScreen(),
          notifier: notifier,
        ),
      );

      // Tap on Business card
      await tester.tap(find.text('Business / Merchant'));
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('BusinessNameScreen', () {
    testWidgets('validates empty business name', (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'user@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const BusinessNameScreen(),
          notifier: notifier,
        ),
      );

      expect(
        find.text('What is your business or shop name?'),
        findsOneWidget,
      );

      // Tap Complete Setup without entering a name
      await tester.tap(find.text('Complete Setup'));
      await tester.pump();

      expect(
        find.text('Please enter your business or shop name.'),
        findsOneWidget,
      );
    });
  });

  group('AccountScreen', () {
    testWidgets('displays customer name, email, and account type',
        (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'fatima@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: CustomerProfileDto(
          id: 'user-1',
          email: 'fatima@cerelo.com',
          fullName: 'Fatima Bello',
          accountType: AccountType.business,
          businessName: 'Bello Traders Ltd',
          onboardingCompletedAt: DateTime.now(),
        ),
      );
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await notifier.retryProfileResolution();

      await tester.pumpWidget(
        createTestWidget(
          child: const AccountScreen(),
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fatima Bello'), findsOneWidget);
      expect(find.text('fatima@cerelo.com'), findsOneWidget);
      expect(find.text('Business Account'), findsOneWidget);
      expect(find.text('Bello Traders Ltd'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
