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

// ---------------------------------------------------------------------------
// Fake ShipmentService with cancellation tracking
// ---------------------------------------------------------------------------

class FakeCancellationShipmentService extends ShipmentService {
  FakeCancellationShipmentService({
    required this.shipment,
    this.shouldFailWithCutoff = false,
  });

  ShipmentDto shipment;
  final bool shouldFailWithCutoff;

  String? lastCancelledShipmentId;
  String? lastCancellationReason;
  String? lastCancellationReasonDetails;
  int cancelCallCount = 0;

  @override
  Future<ShipmentDto?> getShipmentDetail(String shipmentId) async {
    return shipment;
  }

  @override
  Future<bool> cancelShipment({
    required String shipmentId,
    required String reason,
    String? reasonDetails,
  }) async {
    cancelCallCount++;
    if (shouldFailWithCutoff) {
      throw const CereloApiError(
        code: CereloErrorCode.invalidStateTransition,
        message: 'This shipment is already in transit and can no longer be cancelled.',
      );
    }
    lastCancelledShipmentId = shipmentId;
    lastCancellationReason = reason;
    lastCancellationReasonDetails = reasonDetails;

    // Update in-memory shipment to Cancelled
    shipment = ShipmentDto(
      id: shipment.id,
      deliveryCode: shipment.deliveryCode,
      status: ShipmentStatus.cancelled,
      originCity: shipment.originCity,
      destinationCity: shipment.destinationCity,
      senderCustomerId: shipment.senderCustomerId,
      receiverCustomerId: shipment.receiverCustomerId,
      senderNameSnapshot: shipment.senderNameSnapshot,
      senderPhoneSnapshot: shipment.senderPhoneSnapshot,
      senderPickupAddressSnapshot: shipment.senderPickupAddressSnapshot,
      receiverNameSnapshot: shipment.receiverNameSnapshot,
      receiverPhoneSnapshot: shipment.receiverPhoneSnapshot,
      receiverDeliveryAddressSnapshot: shipment.receiverDeliveryAddressSnapshot,
      declaredSize: shipment.declaredSize,
      categoryDescription: shipment.categoryDescription,
      paymentMode: shipment.paymentMode,
      quotedPrice: shipment.quotedPrice,
      finalPrice: shipment.finalPrice,
      createdAt: shipment.createdAt,
      cancellationReason: reason,
      cancelledAt: DateTime.now(),
    );

    return true;
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

ShipmentDto createShipmentWithStatus(ShipmentStatus status, {String senderId = 'user-1'}) {
  return ShipmentDto(
    id: 'shipment-test-123',
    deliveryCode: 'CRL-TEST-1234',
    status: status,
    originCity: 'Kano',
    destinationCity: 'Katsina',
    senderCustomerId: senderId,
    receiverCustomerId: 'user-receiver',
    senderNameSnapshot: 'Ismail Danbatta',
    senderPhoneSnapshot: '+2348011111111',
    senderPickupAddressSnapshot: 'Kwari Market Kano',
    receiverNameSnapshot: 'Fatima Bello',
    receiverPhoneSnapshot: '+2348022222222',
    receiverDeliveryAddressSnapshot: 'Kofar Kaura Katsina',
    declaredSize: ParcelSize.medium,
    categoryDescription: 'Textile Fabric',
    paymentMode: PaymentMode.senderPays,
    quotedPrice: Money.fromNaira(3500),
    finalPrice: Money.fromNaira(3500),
    createdAt: DateTime.now(),
  );
}

Widget createTestApp({
  required FakeCancellationShipmentService service,
  String currentUserId = 'user-1',
}) {
  final fakeAuth = FakeAuthService(
    initialUser: CereloUser(
      id: currentUserId,
      email: 'ismail@cerelo.com',
      role: ActorRole.customer,
      phoneNumber: null,
    ),
  );
  final fakeCustomer = FakeCustomerService(
    profileToReturn: CustomerProfileDto(
      id: currentUserId,
      fullName: 'Ismail Danbatta',
      accountType: AccountType.individual,
      onboardingCompletedAt: DateTime.now(),
    ),
  );
  final authNotifier = CustomerAuthNotifier(
    authService: fakeAuth,
    customerService: fakeCustomer,
  );

  return ProviderScope(
    overrides: [
      customerAuthProvider.overrideWith((ref) => authNotifier),
      shipmentServiceProvider.overrideWithValue(service),
      shipmentDetailProvider('shipment-test-123').overrideWith((ref) => service.shipment),
    ],
    child: MaterialApp(
      theme: CereloTheme.light,
      home: const ShipmentDetailsScreen(shipmentId: 'shipment-test-123'),
    ),
  );
}

void main() {
  group('Customer Shipment Cancellation — UI & Logic', () {
    testWidgets('1. REQUESTED status shows Cancel Request button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakeCancellationShipmentService(
        shipment: createShipmentWithStatus(ShipmentStatus.requested),
      );

      await tester.pumpWidget(createTestApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Shipment Actions'), findsOneWidget);
      expect(find.text('Cancel Request'), findsOneWidget);
      expect(find.text('Cancel Delivery'), findsNothing);
    });

    testWidgets('2. Cancel Request executes on confirmation dialog approval', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakeCancellationShipmentService(
        shipment: createShipmentWithStatus(ShipmentStatus.requested),
      );

      await tester.pumpWidget(createTestApp(service: service));
      await tester.pumpAndSettle();

      // Tap Cancel Request button
      await tester.tap(find.text('Cancel Request'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Cancel this request?'), findsOneWidget);
      expect(
        find.text(
          'This shipment has not yet been confirmed by CERELO. Cancelling it will stop the pickup/delivery request.',
        ),
        findsOneWidget,
      );

      // Confirm cancellation
      await tester.tap(find.widgetWithText(TextButton, 'Cancel Request'));
      await tester.pumpAndSettle();

      // Service should be invoked
      expect(service.cancelCallCount, equals(1));
      expect(service.lastCancelledShipmentId, equals('shipment-test-123'));
    });

    testWidgets('3. PARCEL_CONFIRMED status shows Cancel Delivery button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakeCancellationShipmentService(
        shipment: createShipmentWithStatus(ShipmentStatus.parcelConfirmed),
      );

      await tester.pumpWidget(createTestApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Shipment Actions'), findsOneWidget);
      expect(find.text('Cancel Delivery'), findsOneWidget);
      expect(find.text('Cancel Request'), findsNothing);
    });

    testWidgets('4. Cancel Delivery opens reason modal and executes with selected reason', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakeCancellationShipmentService(
        shipment: createShipmentWithStatus(ShipmentStatus.parcelConfirmed),
      );

      await tester.pumpWidget(createTestApp(service: service));
      await tester.pumpAndSettle();

      // Tap Cancel Delivery
      await tester.tap(find.text('Cancel Delivery'));
      await tester.pumpAndSettle();

      // Reason modal should appear
      expect(find.text('Cancel this delivery?'), findsOneWidget);
      expect(find.text('No longer needed'), findsOneWidget);
      expect(find.text('Sender changed mind'), findsOneWidget);

      // Select 'Sender changed mind'
      await tester.tap(find.text('Sender changed mind'));
      await tester.pumpAndSettle();

      // Tap Cancel Delivery in modal
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Delivery'));
      await tester.pumpAndSettle();

      expect(service.cancelCallCount, equals(1));
      expect(service.lastCancellationReason, equals('Sender changed mind'));
    });

    testWidgets('5. IN_TRANSIT hard cutoff hides cancellation actions completely', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakeCancellationShipmentService(
        shipment: createShipmentWithStatus(ShipmentStatus.inTransit),
      );

      await tester.pumpWidget(createTestApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Shipment Actions'), findsNothing);
      expect(find.text('Cancel Request'), findsNothing);
      expect(find.text('Cancel Delivery'), findsNothing);
    });

    testWidgets('6. ARRIVED_DESTINATION, OUT_FOR_DELIVERY, DELIVERED hide cancellation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      for (final terminalStatus in [
        ShipmentStatus.arrivedDestination,
        ShipmentStatus.outForDelivery,
        ShipmentStatus.delivered,
      ]) {
        final service = FakeCancellationShipmentService(
          shipment: createShipmentWithStatus(terminalStatus),
        );

        await tester.pumpWidget(createTestApp(service: service));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Request'), findsNothing);
        expect(find.text('Cancel Delivery'), findsNothing);
      }
    });

    testWidgets('7. Server cutoff rejection surfaces error message on stale client attempt', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakeCancellationShipmentService(
        shipment: createShipmentWithStatus(ShipmentStatus.requested),
        shouldFailWithCutoff: true,
      );

      await tester.pumpWidget(createTestApp(service: service));
      await tester.pumpAndSettle();

      // Tap Cancel Request
      await tester.tap(find.text('Cancel Request'));
      await tester.pumpAndSettle();

      // Confirm dialog
      await tester.tap(find.widgetWithText(TextButton, 'Cancel Request'));
      await tester.pumpAndSettle();

      // Error SnackBar should be displayed
      expect(
        find.text('This shipment is already in transit and can no longer be cancelled.'),
        findsOneWidget,
      );
    });

    testWidgets('8. CANCELLED shipment shows Cancelled informational banner without action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakeCancellationShipmentService(
        shipment: createShipmentWithStatus(ShipmentStatus.cancelled),
      );

      await tester.pumpWidget(createTestApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Shipment Cancelled'), findsOneWidget);
      expect(find.text('Cancel Request'), findsNothing);
      expect(find.text('Cancel Delivery'), findsNothing);
    });

    testWidgets('9. Receiver does not see cancellation actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakeCancellationShipmentService(
        shipment: createShipmentWithStatus(ShipmentStatus.requested, senderId: 'user-other'),
      );

      // Logged in as receiver ('user-1')
      await tester.pumpWidget(createTestApp(service: service, currentUserId: 'user-1'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Request'), findsNothing);
      expect(find.text('Cancel Delivery'), findsNothing);
    });
  });
}
