import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/features/auth/providers/auth_provider.dart';
import 'package:customer_app/features/home/screens/home_screen.dart';
import 'package:customer_app/features/shipments/providers/shipments_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_notifier_test.dart';

void main() {
  Widget createTestWidget({
    required CustomerAuthNotifier notifier,
    List<ShipmentDto> activeShipments = const [],
    List<ShipmentDto> recentShipments = const [],
  }) {
    return ProviderScope(
      overrides: [
        customerAuthProvider.overrideWith((ref) => notifier),
        customerActiveShipmentsProvider.overrideWith((ref) => activeShipments),
        customerRecentShipmentsProvider.overrideWith((ref) => recentShipments),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen', () {
    testWidgets('renders personalized greeting, corridor badge, and Send CTA',
        (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'ismail@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: CustomerProfileDto(
          id: 'user-1',
          fullName: 'Ismail Danbatta',
          accountType: AccountType.individual,
          onboardingCompletedAt: DateTime.now(),
        ),
      );
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );
      await notifier.retryProfileResolution();

      await tester.pumpWidget(
        createTestWidget(notifier: notifier),
      );
      await tester.pumpAndSettle();

      // Check greeting contains first name
      expect(find.textContaining('Ismail'), findsOneWidget);

      // Check corridor badge
      expect(find.text('Kano ↔ Katsina'), findsOneWidget);
      expect(find.text('· Intercity Delivery'), findsOneWidget);

      // Check Send a Package CTA
      expect(find.text('Send a Package'), findsOneWidget);
      expect(find.text('Start Shipment Request'), findsOneWidget);

      // Check active shipments empty state
      expect(find.text('No active shipments in transit'), findsOneWidget);
    });

    testWidgets('renders active shipment cards when shipments exist',
        (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'user-1',
          email: 'ismail@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: CustomerProfileDto(
          id: 'user-1',
          fullName: 'Ismail Danbatta',
          accountType: AccountType.individual,
          onboardingCompletedAt: DateTime.now(),
        ),
      );
      final notifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );
      await notifier.retryProfileResolution();

      final mockActiveShipment = ShipmentDto(
        id: 'shipment-1',
        deliveryCode: 'CRL-8F2K-9P3N',
        status: ShipmentStatus.inTransit,
        originCity: 'Kano',
        destinationCity: 'Katsina',
        senderCustomerId: 'user-1',
        senderNameSnapshot: 'Ismail Danbatta',
        senderPhoneSnapshot: '+2348011111111',
        senderPickupAddressSnapshot: 'Kano',
        receiverNameSnapshot: 'Fatima Katsina',
        receiverPhoneSnapshot: '+2348022222222',
        receiverDeliveryAddressSnapshot: 'Katsina',
        paymentMode: PaymentMode.senderPays,
        quotedPrice: Money.fromNaira(3000),
        finalPrice: Money.fromNaira(3000),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestWidget(
          notifier: notifier,
          activeShipments: [mockActiveShipment],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CRL-8F2K-9P3N'), findsOneWidget);
      expect(find.text('To: Fatima Katsina'), findsOneWidget);
      expect(find.text('SENT'), findsOneWidget);
      expect(find.text('In Transit'), findsOneWidget);
    });
  });
}
