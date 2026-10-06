import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResolvedParcelDto', () {
    test('deserializes JSON correctly', () {
      final json = {
        'parcel_id': 'parcel-101',
        'shipment_id': 'shipment-101',
        'delivery_code': 'CRL-8F2K-9P3N',
        'parcel_qr_token': 'PQR-7K9A-3M2P-9Q4W',
        'current_parcel_state': 'IN_CERELO_CUSTODY',
        'current_status': 'PARCEL_CONFIRMED',
        'origin_city': 'Kano',
        'destination_city': 'Katsina',
        'sender_name': 'Ismail Danbatta',
        'receiver_name': 'Fatima Bello',
        'confirmed_size_code': 'MEDIUM',
        'confirmed_size_name': 'Medium Package',
        'category_description': 'Ankara Fabrics',
        'final_price_amount': 350000,
        'payment_mode': 'SENDER_PAYS',
        'is_hub_received': false,
        'is_ready_for_batch': false,
      };

      final dto = ResolvedParcelDto.fromJson(json);
      expect(dto.parcelId, equals('parcel-101'));
      expect(dto.deliveryCode, equals('CRL-8F2K-9P3N'));
      expect(dto.parcelQrToken, equals('PQR-7K9A-3M2P-9Q4W'));
      expect(dto.currentParcelState, equals(ParcelState.inCereloCustody));
      expect(dto.currentStatus, equals(ShipmentStatus.parcelConfirmed));
      expect(dto.confirmedSizeName, equals('Medium Package'));
      expect(dto.finalPrice.formatted, equals('₦3,500'));
      expect(dto.isHubReceived, isFalse);
    });
  });

  group('ReadyForBatchParcelDto', () {
    test('deserializes JSON correctly', () {
      final json = {
        'parcel_id': 'parcel-102',
        'shipment_id': 'shipment-102',
        'delivery_code': 'CRL-2B4C-6D8E',
        'parcel_qr_token': 'PQR-2B4C-6D8E-1122',
        'origin_city': 'Kano',
        'destination_city': 'Katsina',
        'confirmed_size_code': 'LARGE',
        'confirmed_size_name': 'Large Package',
        'category_description': 'Shoe Boxes',
        'created_at': '2026-08-17T10:00:00.000Z',
      };

      final dto = ReadyForBatchParcelDto.fromJson(json);
      expect(dto.parcelId, equals('parcel-102'));
      expect(dto.deliveryCode, equals('CRL-2B4C-6D8E'));
      expect(dto.routeDisplay, equals('Kano → Katsina'));
      expect(dto.confirmedSizeName, equals('Large Package'));
    });
  });
}
