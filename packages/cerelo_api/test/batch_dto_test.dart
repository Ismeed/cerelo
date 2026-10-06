import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BatchSummaryDto', () {
    test('deserializes JSON correctly', () {
      final json = {
        'id': 'batch-101',
        'batch_reference': 'BAT-8F2K-9P3N',
        'batch_qr_token': 'BQR-7K9A-3M2P-9Q4W',
        'current_batch_state': 'DRAFT',
        'corridor_code': 'KAN-KAT',
        'origin_city': 'Kano',
        'destination_city': 'Katsina',
        'manifest_parcel_count': 6,
        'created_at': '2026-08-17T11:00:00.000Z',
      };

      final dto = BatchSummaryDto.fromJson(json);
      expect(dto.id, equals('batch-101'));
      expect(dto.batchReference, equals('BAT-8F2K-9P3N'));
      expect(dto.status, equals(BatchStatus.draft));
      expect(dto.originCity, equals('Kano'));
      expect(dto.destinationCity, equals('Katsina'));
      expect(dto.routeDisplay, equals('Kano → Katsina'));
      expect(dto.manifestParcelCount, equals(6));
    });
  });

  group('BatchManifestDto', () {
    test('deserializes manifest JSON correctly', () {
      final json = {
        'batch_id': 'batch-101',
        'batch_reference': 'BAT-8F2K-9P3N',
        'batch_qr_token': 'BQR-7K9A-3M2P-9Q4W',
        'current_batch_state': 'CONFIRMED',
        'corridor_code': 'KAN-KAT',
        'origin_city': 'Kano',
        'destination_city': 'Katsina',
        'manifest_parcel_count': 1,
        'driver_name': 'Malam Aminu',
        'driver_phone': '+2348031234567',
        'vehicle_plate_number': 'KMC-456-XA',
        'agreed_cost_amount': 700000,
        'confirmed_at': '2026-08-17T12:00:00.000Z',
        'parcels': [
          {
            'parcel_id': 'parcel-101',
            'shipment_id': 'shipment-101',
            'delivery_code': 'CRL-8F2K-9P3N',
            'parcel_qr_token': 'PQR-7K9A-3M2P-9Q4W',
            'origin_city': 'Kano',
            'destination_city': 'Katsina',
            'confirmed_size_code': 'MEDIUM',
            'confirmed_size_name': 'Medium Package',
            'category_description': 'Ankara Fabrics',
            'created_at': '2026-08-17T10:00:00.000Z',
          }
        ],
      };

      final dto = BatchManifestDto.fromJson(json);
      expect(dto.batchId, equals('batch-101'));
      expect(dto.status, equals(BatchStatus.confirmed));
      expect(dto.driverName, equals('Malam Aminu'));
      expect(dto.agreedCost.formatted, equals('₦7,000'));
      expect(dto.parcels.length, equals(1));
      expect(dto.parcels.first.deliveryCode, equals('CRL-8F2K-9P3N'));
    });
  });
}
