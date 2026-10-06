import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/features/account/dialogs/help_support_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HelpSupportDialog', () {
    testWidgets('renders official support email and operations hotline', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CereloTheme.light,
          home: const Scaffold(
            body: HelpSupportDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Support Email'), findsOneWidget);
      expect(find.text('support@cerelonet.com'), findsOneWidget);
      expect(find.text('Operations Hotline'), findsOneWidget);
      expect(find.text('+2349023107077'), findsOneWidget);
      expect(find.text('Monday – Saturday: 7:00 AM – 7:00 PM'), findsOneWidget);
      expect(find.text('Frequently Asked Questions'), findsOneWidget);
    });
  });
}
