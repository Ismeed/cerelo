import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryTaskDto', () {
    test('deserializes JSON correctly', () {
      final json = {
        'shipment_id': 'shipment-101',
        'parcel_id': 'parcel-101',
        'delivery_code': 'CRL-8F2K-9P3N',
        'parcel_qr_token': 'PQR-7K9A-3M2P-9Q4W',
        'current_status': 'ARRIVED_DESTINATION',
        'origin_city': 'Kano',
        'destination_city': 'Katsina',
        'sender_name': 'Malam Bello',
        'sender_phone': '+2348011111111',
        'receiver_name': 'Hajiya Fatima',
        'receiver_phone': '+2348022222222',
        'receiver_delivery_address': '14 IBB Way, Katsina',
        'landmark': 'Near Central Mosque',
        'delivery_instructions': 'Call before reaching',
        'confirmed_size_code': 'MEDIUM',
        'confirmed_size_name': 'Medium Package',
        'category_description': 'Ankara Fabric',
        'payment_mode': 'RECEIVER_PAYS',
        'final_price_amount': 350000,
        'receiver_payment_status': 'PENDING',
        'receiver_due_amount': 350000,
        'created_at': '2026-08-17T10:00:00.000Z',
      };

      final dto = DeliveryTaskDto.fromJson(json);
      expect(dto.shipmentId, equals('shipment-101'));
      expect(dto.deliveryCode, equals('CRL-8F2K-9P3N'));
      expect(dto.status, equals(ShipmentStatus.arrivedDestination));
      expect(dto.receiverName, equals('Hajiya Fatima'));
      expect(dto.receiverDueAmount.formatted, equals('₦3,500'));
      expect(dto.requiresReceiverPayment, isTrue);
      expect(dto.routeDisplay, equals('Kano → Katsina'));
    });
  });
}
