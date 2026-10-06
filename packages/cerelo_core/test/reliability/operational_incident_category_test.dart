import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OperationalIncidentCategory', () {
    test('converts to and from DB codes accurately', () {
      const cat = OperationalIncidentCategory.senderUnavailable;
      expect(cat.toDbCode(), equals('SENDER_UNAVAILABLE'));
      expect(
        OperationalIncidentCategory.fromDbCode('SENDER_UNAVAILABLE'),
        equals(OperationalIncidentCategory.senderUnavailable),
      );
    });

    test('maps all categories to customer-safe copy without raw error codes', () {
      for (final cat in OperationalIncidentCategory.values) {
        final msg = cat.toCustomerSafeMessage();
        expect(msg, isNotEmpty);
        expect(msg.contains('_'), isFalse);
      }
    });
  });
}
