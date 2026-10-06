import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryQuoteDto', () {
    test('deserializes from JSON correctly', () {
      final json = {
        'corridor_id': 'corridor-kan-kat',
        'size_tier_id': 'tier-medium',
        'size_tier_code': 'MEDIUM',
        'size_tier_name': 'Medium Package',
        'size_tier_description': 'Up to 10kg',
        'quoted_price_amount': 350000,
        'currency': 'NGN',
      };

      final dto = DeliveryQuoteDto.fromJson(json);
      expect(dto.corridorId, equals('corridor-kan-kat'));
      expect(dto.sizeTierCode, equals('MEDIUM'));
      expect(dto.quotedPrice.kobo, equals(350000));
      expect(dto.quotedPrice.formatted, equals('₦3,500'));
    });

    test('toJson serializes correctly', () {
      final dto = DeliveryQuoteDto(
        corridorId: 'corridor-1',
        sizeTierId: 'tier-1',
        sizeTierCode: 'LARGE',
        sizeTierName: 'Large Package',
        sizeTierDescription: 'Up to 25kg',
        quotedPrice: Money.fromNaira(6000),
      );

      final json = dto.toJson();
      expect(json['corridor_id'], equals('corridor-1'));
      expect(json['size_tier_code'], equals('LARGE'));
      expect(json['quoted_price_amount'], equals(600000));
    });
  });

  group('CreateShipmentRequestInput Validation', () {
    test('valid input passes validation without exception', () {
      final input = CreateShipmentRequestInput(
        originCity: 'Kano',
        destinationCity: 'Katsina',
        senderPickupAddress: 'Plot 12 Kwari Textile Market, Kano',
        receiverName: 'Fatima Bello',
        receiverPhone: '+2348012345678',
        receiverDeliveryAddress: '45 Kofar Kaura Layout, Katsina',
        parcelSize: ParcelSize.medium,
        categoryDescription: 'Textiles',
        paymentMode: PaymentMode.senderPays,
      );

      expect(() => input.validate(), returnsNormally);
    });

    test('rejects same origin and destination (intracity attempt)', () {
      final input = CreateShipmentRequestInput(
        originCity: 'Kano',
        destinationCity: 'Kano',
        senderPickupAddress: 'Address 1',
        receiverName: 'Receiver',
        receiverPhone: '+2348012345678',
        receiverDeliveryAddress: 'Address 2',
        parcelSize: ParcelSize.medium,
        categoryDescription: 'Goods',
        paymentMode: PaymentMode.senderPays,
      );

      expect(
        () => input.validate(),
        throwsA(
          isA<CereloApiError>().having(
            (e) => e.message,
            'message',
            contains('intercity only'),
          ),
        ),
      );
    });

    test('rejects invalid receiver phone number', () {
      final input = CreateShipmentRequestInput(
        originCity: 'Kano',
        destinationCity: 'Katsina',
        senderPickupAddress: 'Address 1',
        receiverName: 'Receiver',
        receiverPhone: '12345',
        receiverDeliveryAddress: 'Address 2',
        parcelSize: ParcelSize.medium,
        categoryDescription: 'Goods',
        paymentMode: PaymentMode.senderPays,
      );

      expect(
        () => input.validate(),
        throwsA(
          isA<CereloApiError>().having(
            (e) => e.message,
            'message',
            contains('valid Nigerian mobile phone number'),
          ),
        ),
      );
    });
  });
}
