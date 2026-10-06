import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/features/auth/providers/auth_provider.dart';
import 'package:customer_app/features/shipments/providers/shipments_provider.dart';
import 'package:customer_app/features/shipments/screens/shipment_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_notifier_test.dart';

void main() {
  Widget createTestWidget({
    required CustomerAuthNotifier notifier,
    ShipmentDto? shipment,
  }) {
    return ProviderScope(
      overrides: [
        customerAuthProvider.overrideWith((ref) => notifier),
        shipmentDetailProvider('shipment-101').overrideWith((ref) => shipment),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: const ShipmentDetailsScreen(shipmentId: 'shipment-101'),
      ),
    );
  }

  group('ShipmentDetailsScreen', () {
    testWidgets('renders route, delivery code, timeline, and payment responsibility',
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

      final shipment = ShipmentDto(
        id: 'shipment-101',
        deliveryCode: 'CRL-8F2K-9P3N',
        status: ShipmentStatus.inTransit,
        originCity: 'Kano',
        destinationCity: 'Katsina',
        senderCustomerId: 'user-1',
        senderNameSnapshot: 'Aminu Kano',
        senderPhoneSnapshot: '+2348011111111',
        senderPickupAddressSnapshot: '12 Kwari Market, Kano',
        receiverNameSnapshot: 'Fatima Katsina',
        receiverPhoneSnapshot: '+2348022222222',
        receiverDeliveryAddressSnapshot: '45 Kofar Kaura, Katsina',
        declaredSize: ParcelSize.large,
        categoryDescription: 'Textile Bundles',
        paymentMode: PaymentMode.senderPays,
        quotedPrice: Money.fromNaira(6000),
        finalPrice: Money.fromNaira(6000),
        senderPaymentStatus: PaymentStatus.collected,
        receiverPaymentStatus: PaymentStatus.notRequired,
        createdAt: DateTime.parse('2026-08-17T09:00:00Z'),
      );

      await tester.pumpWidget(
        createTestWidget(
          notifier: notifier,
          shipment: shipment,
        ),
      );
      await tester.pumpAndSettle();

      // Header summary
      expect(find.text('Kano'), findsWidgets);
      expect(find.text('Katsina'), findsWidgets);
      expect(find.text('CRL-8F2K-9P3N'), findsOneWidget);
      expect(find.text('SENT'), findsOneWidget);
      expect(find.text('In Transit'), findsWidgets);

      // Timeline section
      expect(find.text('Delivery Progress'), findsOneWidget);
      expect(find.text('Shipment Requested'), findsOneWidget);
      expect(find.text('In Transit on Corridor'), findsOneWidget);
      expect(find.text('Out for Doorstep Delivery'), findsOneWidget);

      // Parcel details section
      expect(find.text('Parcel & Addresses'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      expect(find.text('Textile Bundles'), findsOneWidget);
      expect(find.text('12 Kwari Market, Kano'), findsOneWidget);

      // Payment section
      expect(find.text('Payment Responsibility'), findsOneWidget);
      expect(find.text('Sender Pays'), findsOneWidget);
      expect(find.text('₦6,000'), findsWidgets);
    });

    testWidgets('shows safe not found state when shipment does not exist',
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
          shipment: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shipment Not Found'), findsOneWidget);
      expect(find.text('Back to Shipments'), findsOneWidget);
    });
  });
}
