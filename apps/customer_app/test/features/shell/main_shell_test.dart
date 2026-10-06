import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/core/shell/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('MainShell', () {
    testWidgets('renders exactly 3 primary navigation destinations (Home, Shipments, Account)',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (context, state, child) => MainShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const Text('Home Screen Content'),
              ),
              GoRoute(
                path: '/shipments',
                builder: (_, __) => const Text('Shipments Screen Content'),
              ),
              GoRoute(
                path: '/account',
                builder: (_, __) => const Text('Account Screen Content'),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: CereloTheme.light,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      // Check exactly the 3 approved tabs
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Shipments'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);

      // Verify locked exclusions: strictly forbidden primary tabs
      expect(find.text('Wallet'), findsNothing);
      expect(find.text('Tracking'), findsNothing);
      expect(find.text('Courier'), findsNothing);
      expect(find.text('Rewards'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Marketplace'), findsNothing);
    });
  });
}
