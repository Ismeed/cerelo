import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PickupTaskDto', () {
    test('deserializes JSON correctly', () {
      final json = {
        'id': 'shipment-100',
        'delivery_code': null,
        'current_status': 'REQUESTED',
        'origin_city': 'Kano',
        'destination_city': 'Katsina',
        'sender_name_snapshot': 'Ismail Danbatta',
        'sender_phone_snapshot': '+2348011111111',
        'sender_pickup_address_snapshot': 'Shop 12 Kwari Market, Kano',
        'landmark': 'Near Central Mosque',
        'delivery_instructions': 'Call before arrival',
        'receiver_name_snapshot': 'Fatima Bello',
        'receiver_phone_snapshot': '+2348022222222',
        'receiver_delivery_address_snapshot': '45 Kofar Kaura, Katsina',
        'declared_size_code': 'MEDIUM',
        'declared_size_name': 'Medium Package',
        'category_description': 'Ankara Fabrics',
        'payment_mode': 'SENDER_PAYS',
        'quoted_price_amount': 350000,
        'final_price_amount': 350000,
        'created_at': '2026-08-17T10:00:00.000Z',
      };

      final dto = PickupTaskDto.fromJson(json);
      expect(dto.id, equals('shipment-100'));
      expect(dto.deliveryCode, isNull);
      expect(dto.status, equals(ShipmentStatus.requested));
      expect(dto.originCity, equals('Kano'));
      expect(dto.destinationCity, equals('Katsina'));
      expect(dto.routeDisplay, equals('Kano → Katsina'));
      expect(dto.senderName, equals('Ismail Danbatta'));
      expect(dto.receiverName, equals('Fatima Bello'));
      expect(dto.declaredSize, equals(ParcelSize.medium));
      expect(dto.quotedPrice.formatted, equals('₦3,500'));
      expect(dto.finalPrice.formatted, equals('₦3,500'));
    });
  });

  group('ConfirmParcelResultDto', () {
    test('deserializes confirmed result JSON correctly', () {
      final json = {
        'success': true,
        'shipment_id': 'shipment-100',
        'delivery_code': 'CRL-8F2K-9P3N',
        'status': 'PARCEL_CONFIRMED',
        'confirmed_size_code': 'MEDIUM',
        'confirmed_size_name': 'Medium Package',
        'final_price_amount': 350000,
      };

      final dto = ConfirmParcelResultDto.fromJson(json);
      expect(dto.success, isTrue);
      expect(dto.deliveryCode, equals('CRL-8F2K-9P3N'));
      expect(dto.status, equals(ShipmentStatus.parcelConfirmed));
      expect(dto.finalPrice.formatted, equals('₦3,500'));
    });
  });
}
