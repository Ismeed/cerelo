import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/features/auth/providers/auth_provider.dart';
import 'package:customer_app/features/shipments/providers/shipments_provider.dart';
import 'package:customer_app/features/shipments/screens/shipments_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_notifier_test.dart';

void main() {
  Widget createTestWidget({
    required CustomerAuthNotifier notifier,
    List<ShipmentDto> shipments = const [],
  }) {
    return ProviderScope(
      overrides: [
        customerAuthProvider.overrideWith((ref) => notifier),
        customerShipmentsProvider.overrideWith((ref) => shipments),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: const ShipmentsScreen(),
      ),
    );
  }

  group('ShipmentsScreen', () {
    testWidgets('renders search bar, relationship tabs, and shipment cards',
        (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'user@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      final sentShipment = ShipmentDto(
        id: 'shipment-sent',
        deliveryCode: 'CRL-1111-2222',
        status: ShipmentStatus.parcelConfirmed,
        originCity: 'Kano',
        destinationCity: 'Katsina',
        senderCustomerId: 'user-1',
        senderNameSnapshot: 'My Name',
        senderPhoneSnapshot: '+2348000000000',
        senderPickupAddressSnapshot: 'Kano Pickup',
        receiverNameSnapshot: 'Ibrahim Katsina',
        receiverPhoneSnapshot: '+2348011111111',
        receiverDeliveryAddressSnapshot: 'Katsina Dropoff',
        paymentMode: PaymentMode.senderPays,
        quotedPrice: Money.fromNaira(3000),
        finalPrice: Money.fromNaira(3000),
        createdAt: DateTime.now(),
      );

      final receivedShipment = ShipmentDto(
        id: 'shipment-received',
        deliveryCode: 'CRL-3333-4444',
        status: ShipmentStatus.outForDelivery,
        originCity: 'Katsina',
        destinationCity: 'Kano',
        senderCustomerId: 'other-user',
        receiverCustomerId: 'user-1',
        senderNameSnapshot: 'Kwari Fabrics Supplier',
        senderPhoneSnapshot: '+2348022222222',
        senderPickupAddressSnapshot: 'Katsina Pickup',
        receiverNameSnapshot: 'My Name',
        receiverPhoneSnapshot: '+2348000000000',
        receiverDeliveryAddressSnapshot: 'Kano Dropoff',
        paymentMode: PaymentMode.receiverPays,
        quotedPrice: Money.fromNaira(4500),
        finalPrice: Money.fromNaira(4500),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestWidget(
          notifier: notifier,
          shipments: [sentShipment, receivedShipment],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Shipments'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Parcels Sent'), findsOneWidget);
      expect(find.text('Parcels Received'), findsOneWidget);

      // Verify Sent card displays Receiver counterpart and SENT pill
      expect(find.text('CRL-1111-2222'), findsOneWidget);
      expect(find.text('To: Ibrahim Katsina'), findsOneWidget);
      expect(find.text('SENT'), findsOneWidget);
      expect(find.text('Parcel Confirmed'), findsOneWidget);

      // Verify Received card displays Sender counterpart and RECEIVED pill
      expect(find.text('CRL-3333-4444'), findsOneWidget);
      expect(find.text('From: Kwari Fabrics Supplier'), findsOneWidget);
      expect(find.text('RECEIVED'), findsOneWidget);
      expect(find.text('Out for Delivery'), findsOneWidget);
    });

    testWidgets('shows honest empty state when no shipments exist',
        (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'user@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService();
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      await tester.pumpWidget(
        createTestWidget(
          notifier: notifier,
          shipments: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No shipments yet'), findsOneWidget);
      expect(find.text('Send a Package'), findsOneWidget);
    });
  });
}
