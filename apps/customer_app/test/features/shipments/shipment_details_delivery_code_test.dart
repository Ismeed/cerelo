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

class FakeDetailsShipmentService extends ShipmentService {
  FakeDetailsShipmentService({this.shipmentToReturn});

  final ShipmentDto? shipmentToReturn;

  @override
  Future<ShipmentDto?> getShipmentDetail(String shipmentId) async {
    return shipmentToReturn ??
        ShipmentDto(
          id: shipmentId,
          deliveryCode: '',
          status: ShipmentStatus.requested,
          originCity: 'Kano',
          destinationCity: 'Katsina',
          senderCustomerId: 'sender-user-1',
          senderNameSnapshot: 'Ismail Danbatta',
          senderPhoneSnapshot: '+2348011111111',
          senderPickupAddressSnapshot: 'Shop 12 Kwari Market, Kano',
          receiverNameSnapshot: 'Fatima Bello',
          receiverPhoneSnapshot: '+2348022222222',
          receiverDeliveryAddressSnapshot: '45 Kofar Kaura, Katsina',
          declaredSize: ParcelSize.medium,
          categoryDescription: 'Fabrics',
          paymentMode: PaymentMode.senderPays,
          quotedPrice: Money.fromNaira(3500),
          finalPrice: Money.fromNaira(3500),
          createdAt: DateTime.now(),
        );
  }

  @override
  List<ShipmentTimelineEventDto> getShipmentTimeline(ShipmentDto shipment) {
    return [
      ShipmentTimelineEventDto(
        status: ShipmentStatus.requested,
        title: 'Shipment Requested',
        description: 'Pickup request created.',
        timestamp: shipment.createdAt,
        isCompleted: true,
        isCurrent: true,
      ),
      ShipmentTimelineEventDto(
        status: ShipmentStatus.parcelConfirmed,
        title: 'Parcel Confirmed',
        description: 'Personnel inspected parcel.',
        timestamp: null,
        isCompleted: false,
        isCurrent: false,
      ),
    ];
  }
}

void main() {
  Widget createTestWidget({
    required CustomerAuthNotifier authNotifier,
    required FakeDetailsShipmentService shipmentService,
    required String shipmentId,
  }) {
    return ProviderScope(
      overrides: [
        customerAuthProvider.overrideWith((ref) => authNotifier),
        shipmentServiceProvider.overrideWithValue(shipmentService),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: ShipmentDetailsScreen(shipmentId: shipmentId),
      ),
    );
  }

  group('ShipmentDetailsScreen Delivery Code & Sharing', () {
    testWidgets('shows Delivery Code Pending when shipment is in REQUESTED state', (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'sender-user-1',
          email: 'ismail@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: CustomerProfileDto(
          id: 'sender-user-1',
          fullName: 'Ismail Danbatta',
          accountType: AccountType.individual,
          onboardingCompletedAt: DateTime.now(),
        ),
      );
      final authNotifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );
      await authNotifier.retryProfileResolution();

      final fakeShipments = FakeDetailsShipmentService(
        shipmentToReturn: ShipmentDto(
          id: 'shipment-req-1',
          deliveryCode: '',
          status: ShipmentStatus.requested,
          originCity: 'Kano',
          destinationCity: 'Katsina',
          senderCustomerId: 'sender-user-1',
          senderNameSnapshot: 'Ismail Danbatta',
          senderPhoneSnapshot: '+2348011111111',
          senderPickupAddressSnapshot: 'Shop 12 Kwari Market, Kano',
          receiverNameSnapshot: 'Fatima Bello',
          receiverPhoneSnapshot: '+2348022222222',
          receiverDeliveryAddressSnapshot: '45 Kofar Kaura, Katsina',
          declaredSize: ParcelSize.medium,
          categoryDescription: 'Fabrics',
          paymentMode: PaymentMode.senderPays,
          quotedPrice: Money.fromNaira(3500),
          finalPrice: Money.fromNaira(3500),
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          authNotifier: authNotifier,
          shipmentService: fakeShipments,
          shipmentId: 'shipment-req-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivery Code Pending'), findsOneWidget);
      expect(find.text('Code will be generated once personnel confirms the package at pickup.'), findsOneWidget);
      expect(find.text('CRL-8F2K-9P3N'), findsNothing);
      expect(find.byTooltip('Share Tracking Link'), findsOneWidget);
    });

    testWidgets('shows Delivery Code CRL-8F2K-9P3N when shipment is confirmed', (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'sender-user-1',
          email: 'ismail@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: null,
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: CustomerProfileDto(
          id: 'sender-user-1',
          fullName: 'Ismail Danbatta',
          accountType: AccountType.individual,
          onboardingCompletedAt: DateTime.now(),
        ),
      );
      final authNotifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );
      await authNotifier.retryProfileResolution();

      final fakeShipments = FakeDetailsShipmentService(
        shipmentToReturn: ShipmentDto(
          id: 'shipment-conf-1',
          deliveryCode: 'CRL-8F2K-9P3N',
          status: ShipmentStatus.parcelConfirmed,
          originCity: 'Kano',
          destinationCity: 'Katsina',
          senderCustomerId: 'sender-user-1',
          senderNameSnapshot: 'Ismail Danbatta',
          senderPhoneSnapshot: '+2348011111111',
          senderPickupAddressSnapshot: 'Shop 12 Kwari Market, Kano',
          receiverNameSnapshot: 'Fatima Bello',
          receiverPhoneSnapshot: '+2348022222222',
          receiverDeliveryAddressSnapshot: '45 Kofar Kaura, Katsina',
          declaredSize: ParcelSize.medium,
          categoryDescription: 'Fabrics',
          paymentMode: PaymentMode.senderPays,
          quotedPrice: Money.fromNaira(3500),
          finalPrice: Money.fromNaira(3500),
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          authNotifier: authNotifier,
          shipmentService: fakeShipments,
          shipmentId: 'shipment-conf-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CRL-8F2K-9P3N'), findsOneWidget);
      expect(find.byTooltip('Copy Code'), findsOneWidget);
      expect(find.byTooltip('Share Tracking Link'), findsOneWidget);
      expect(find.text('Verify Code'), findsOneWidget);
    });
  });
}
