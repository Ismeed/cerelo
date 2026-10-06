import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationEventType', () {
    test('provides privacy-safe customer milestone templates without sensitive PII', () {
      expect(
        NotificationEventType.parcelConfirmed.getSafeMessage(),
        equals('Your package has been confirmed by Cerelo.'),
      );

      expect(
        NotificationEventType.inTransit.getSafeMessage(destinationCity: 'Katsina'),
        equals('Your package is now in transit to Katsina.'),
      );

      expect(
        NotificationEventType.arrivedDestination.getSafeMessage(destinationCity: 'Kano'),
        equals('Your package has arrived in Kano.'),
      );

      expect(
        NotificationEventType.outForDelivery.getSafeMessage(),
        equals('Your package is out for delivery.'),
      );

      expect(
        NotificationEventType.delivered.getSafeMessage(),
        equals('Your package has been delivered.'),
      );
    });
  });
}
