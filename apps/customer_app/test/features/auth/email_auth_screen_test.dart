import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/features/auth/providers/auth_provider.dart';
import 'package:customer_app/features/auth/screens/email_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_notifier_test.dart';

void main() {
  Widget createTestWidget({
    required CustomerAuthNotifier notifier,
  }) {
    return ProviderScope(
      overrides: [
        customerAuthProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: const EmailAuthScreen(),
      ),
    );
  }

  group('EmailAuthScreen Widget Tests', () {
    testWidgets('renders step 1 (Email Address input) initially',
        (tester) async {
      final fakeAuth = FakeAuthService();
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Email'), findsNWidgets(2));
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('validates required email on step 1', (tester) async {
      final fakeAuth = FakeAuthService();
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.pumpAndSettle();

      // Tap Continue with empty email
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address.'), findsOneWidget);
    });

    testWidgets(
        'requesting OTP transitions to step 2 (OTP verification) with masked email',
        (tester) async {
      final fakeAuth = FakeAuthService();
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.pumpAndSettle();

      // Enter email
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Email Address'),
        'ismeed13@gmail.com',
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Should now be on Step 2 (Verify Code)
      expect(find.text('Verify Code'), findsOneWidget);
      expect(find.textContaining('is***3@gmail.com'), findsOneWidget);
      expect(find.text('6-Digit Code'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);
    });

    testWidgets('validates OTP field for 6 digits', (tester) async {
      final fakeAuth = FakeAuthService();
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Email Address'),
        'ismeed13@gmail.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Enter 3 digits only
      await tester.enterText(
        find.widgetWithText(CereloTextField, '6-Digit Code'),
        '123',
      );
      await tester.tap(find.widgetWithText(CereloButton, 'Verify & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Code must be 6 to 8 digits.'), findsOneWidget);
    });

    testWidgets('changing email returns to Step 1', (tester) async {
      final fakeAuth = FakeAuthService();
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Email Address'),
        'ismeed13@gmail.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Code'), findsOneWidget);

      // Tap change email
      await tester.tap(find.text('Use a different email address'));
      await tester.pumpAndSettle();

      // Should be back on Step 1
      expect(find.text('Continue with Email'), findsNWidgets(2));
      expect(find.text('Email Address'), findsOneWidget);
    });
  });
}
