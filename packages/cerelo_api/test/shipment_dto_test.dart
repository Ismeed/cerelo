import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShipmentDto', () {
    test('deserializes and computes counterpart and relationship correctly', () {
      final json = {
        'id': 'shipment-101',
        'delivery_code': 'CRL-8F2K-9P3N',
        'current_status': 'IN_TRANSIT',
        'origin_city': 'Kano',
        'destination_city': 'Katsina',
        'sender_customer_id': 'sender-1',
        'receiver_customer_id': 'receiver-2',
        'sender_name_snapshot': 'Aminu Kano',
        'sender_phone_snapshot': '+2348011111111',
        'sender_pickup_address_snapshot': '12 Kwari Market Road, Kano',
        'receiver_name_snapshot': 'Fatima Katsina',
        'receiver_phone_snapshot': '+2348022222222',
        'receiver_delivery_address_snapshot': '45 Kofar Kaura, Katsina',
        'declared_size': 'MEDIUM',
        'category_description': 'Bale of Ankara fabrics',
        'payment_mode': 'SENDER_PAYS',
        'quoted_price_amount': 300000,
        'final_price_amount': 300000,
        'sender_payment_status': 'COLLECTED',
        'receiver_payment_status': 'NOT_REQUIRED',
        'created_at': '2026-08-17T10:00:00Z',
      };

      final dto = ShipmentDto.fromJson(json);

      expect(dto.id, equals('shipment-101'));
      expect(dto.deliveryCode, equals('CRL-8F2K-9P3N'));
      expect(dto.status, equals(ShipmentStatus.inTransit));
      expect(dto.routeDisplay, equals('Kano → Katsina'));
      expect(dto.finalPrice.formatted, equals('₦3,000'));

      // From Sender perspective:
      expect(dto.isSender('sender-1'), isTrue);
      expect(dto.isReceiver('sender-1'), isFalse);
      expect(dto.relationshipBadge('sender-1'), equals('SENT'));
      expect(dto.counterpartName('sender-1'), equals('Fatima Katsina'));
      expect(dto.counterpartLabel('sender-1'), equals('To: Fatima Katsina'));

      // From Receiver perspective:
      expect(dto.isSender('receiver-2'), isFalse);
      expect(dto.isReceiver('receiver-2'), isTrue);
      expect(dto.relationshipBadge('receiver-2'), equals('RECEIVED'));
      expect(dto.counterpartName('receiver-2'), equals('Aminu Kano'));
      expect(dto.counterpartLabel('receiver-2'), equals('From: Aminu Kano'));
    });

    test('toJson serializes correctly', () {
      final dto = ShipmentDto(
        id: 'shipment-102',
        deliveryCode: 'CRL-1234-5678',
        status: ShipmentStatus.requested,
        originCity: 'Katsina',
        destinationCity: 'Kano',
        senderCustomerId: 'sender-1',
        senderNameSnapshot: 'Sender Name',
        senderPhoneSnapshot: '+2348000000000',
        senderPickupAddressSnapshot: 'Pickup Address',
        receiverNameSnapshot: 'Receiver Name',
        receiverPhoneSnapshot: '+2348011111111',
        receiverDeliveryAddressSnapshot: 'Delivery Address',
        paymentMode: PaymentMode.splitPayment,
        quotedPrice: Money.fromNaira(3000),
        finalPrice: Money.fromNaira(3000),
        createdAt: DateTime.parse('2026-08-17T12:00:00Z'),
      );

      final json = dto.toJson();
      expect(json['id'], equals('shipment-102'));
      expect(json['delivery_code'], equals('CRL-1234-5678'));
      expect(json['current_status'], equals('REQUESTED'));
      expect(json['payment_mode'], equals('SPLITPAYMENT'));
      expect(json['quoted_price_amount'], equals(300000));
    });
  });

  group('ShipmentService Timeline Generation', () {
    test('generates 6 customer milestones with correct current and completed flags', () {
      final service = ShipmentService();

      final inTransitShipment = ShipmentDto(
        id: 'shipment-103',
        deliveryCode: 'CRL-9999-8888',
        status: ShipmentStatus.inTransit,
        originCity: 'Kano',
        destinationCity: 'Katsina',
        senderCustomerId: 'sender-1',
        senderNameSnapshot: 'Sender',
        senderPhoneSnapshot: '+2348000000000',
        senderPickupAddressSnapshot: 'Pickup',
        receiverNameSnapshot: 'Receiver',
        receiverPhoneSnapshot: '+2348011111111',
        receiverDeliveryAddressSnapshot: 'Delivery',
        paymentMode: PaymentMode.senderPays,
        quotedPrice: Money.fromNaira(3000),
        finalPrice: Money.fromNaira(3000),
        createdAt: DateTime.parse('2026-08-17T08:00:00Z'),
      );

      final timeline = service.getShipmentTimeline(inTransitShipment);

      expect(timeline.length, equals(6));

      // 0: Requested -> Completed
      expect(timeline[0].status, equals(ShipmentStatus.requested));
      expect(timeline[0].isCompleted, isTrue);
      expect(timeline[0].isCurrent, isFalse);

      // 1: Parcel Confirmed -> Completed
      expect(timeline[1].status, equals(ShipmentStatus.parcelConfirmed));
      expect(timeline[1].isCompleted, isTrue);
      expect(timeline[1].isCurrent, isFalse);

      // 2: In Transit -> Current
      expect(timeline[2].status, equals(ShipmentStatus.inTransit));
      expect(timeline[2].isCompleted, isFalse);
      expect(timeline[2].isCurrent, isTrue);

      // 3: Arrived Destination -> Future (not completed, not current)
      expect(timeline[3].status, equals(ShipmentStatus.arrivedDestination));
      expect(timeline[3].isCompleted, isFalse);
      expect(timeline[3].isCurrent, isFalse);
    });
  });
}
