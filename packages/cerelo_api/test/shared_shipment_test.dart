import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedShipmentDto', () {
    test('deserializes privacy-safe shared JSON correctly', () {
      final json = {
        'shipment_id': 'shipment-123',
        'origin_city': 'Kano',
        'destination_city': 'Katsina',
        'current_status': 'IN_TRANSIT',
        'sender_display_name': 'Ismail',
        'receiver_name_snapshot': 'Fatima Bello',
        'receiver_phone_masked': '+234 801 ***5678',
        'receiver_delivery_address': '45 Kofar Kaura Layout, Katsina',
        'category_description': 'Ankara Fabrics',
        'payment_mode': 'RECEIVER_PAYS',
        'receiver_expected_amount': 350000,
        'already_linked': false,
        'is_intended_receiver': true,
        'created_at': '2026-08-17T10:00:00.000Z',
      };

      final dto = SharedShipmentDto.fromJson(json);
      expect(dto.shipmentId, equals('shipment-123'));
      expect(dto.originCity, equals('Kano'));
      expect(dto.destinationCity, equals('Katsina'));
      expect(dto.routeDisplay, equals('Kano → Katsina'));
      expect(dto.status, equals(ShipmentStatus.inTransit));
      expect(dto.senderDisplayName, equals('Ismail'));
      expect(dto.receiverPhoneMasked, equals('+234 801 ***5678'));
      expect(dto.paymentMode, equals(PaymentMode.receiverPays));
      expect(dto.receiverExpectedAmount.formatted, equals('₦3,500'));
      expect(dto.alreadyLinked, isFalse);
      expect(dto.isIntendedReceiver, isTrue);
    });
  });

  group('ShareLinkDto', () {
    test('deserializes share link JSON correctly', () {
      final json = {
        'token': 'a1b2c3d4e5f67890123456789abcdef0',
        'expires_at': '2026-09-17T10:00:00.000Z',
        'share_url': 'https://cerelo.ng/s/a1b2c3d4e5f67890123456789abcdef0',
      };

      final dto = ShareLinkDto.fromJson(json);
      expect(dto.token, equals('a1b2c3d4e5f67890123456789abcdef0'));
      expect(dto.shareUrl, contains('https://cerelo.ng/s/'));
    });
  });
}
