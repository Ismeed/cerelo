import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/core/router/app_router.dart';
import 'package:customer_app/features/auth/providers/auth_provider.dart';
import 'package:customer_app/features/send_package/screens/send_package_screen.dart';
import 'package:customer_app/features/send_package/screens/send_package_success_screen.dart';
import 'package:customer_app/features/shipments/providers/shipments_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier_test.dart';

// ---------------------------------------------------------------------------
// Fake ShipmentService shared with provider tests
// ---------------------------------------------------------------------------

class FakeShipmentService extends ShipmentService {
  FakeShipmentService({this.shipmentToReturn});

  final ShipmentDto? shipmentToReturn;
  CreateShipmentRequestInput? lastSubmittedInput;

  @override
  Future<DeliveryQuoteDto> getDeliveryQuote({
    required String originCity,
    required String destinationCity,
    required ParcelSize sizeTier,
  }) async {
    final kobo = switch (sizeTier) {
      ParcelSize.small => 200000,
      ParcelSize.medium => 350000,
      ParcelSize.large => 600000,
    };
    return DeliveryQuoteDto(
      corridorId: 'corridor-kan-kat',
      sizeTierId: 'tier-${sizeTier.name}',
      sizeTierCode: sizeTier.name.toUpperCase(),
      sizeTierName: sizeTier.displayLabel,
      sizeTierDescription: 'Up to 10kg',
      quotedPrice: Money.fromKobo(kobo),
    );
  }

  @override
  Future<ShipmentDto> createShipmentRequest(
    CreateShipmentRequestInput input,
  ) async {
    lastSubmittedInput = input;
    return shipmentToReturn ??
        ShipmentDto(
          id: 'shipment-new-1',
          deliveryCode: 'CRL-8F2K-9P3N',
          status: ShipmentStatus.requested,
          originCity: input.originCity,
          destinationCity: input.destinationCity,
          senderCustomerId: 'user-1',
          senderNameSnapshot: 'Ismail Danbatta',
          senderPhoneSnapshot: '+2348011111111',
          senderPickupAddressSnapshot: input.senderPickupAddress,
          receiverNameSnapshot: input.receiverName,
          receiverPhoneSnapshot: input.receiverPhone,
          receiverDeliveryAddressSnapshot: input.receiverDeliveryAddress,
          declaredSize: input.parcelSize,
          categoryDescription: input.categoryDescription,
          paymentMode: input.paymentMode,
          quotedPrice: Money.fromNaira(3500),
          finalPrice: Money.fromNaira(3500),
          createdAt: DateTime.now(),
        );
  }
}

// ---------------------------------------------------------------------------
// Test widget builder — uses GoRouter so pushReplacement works correctly
// ---------------------------------------------------------------------------

Widget createTestWidget({
  required CustomerAuthNotifier authNotifier,
  required FakeShipmentService shipmentService,
}) {
  // Build a minimal GoRouter that starts on /send-package and also defines
  // the /send-package/success route needed after successful submission.
  final router = GoRouter(
    initialLocation: AppRoutes.sendPackage,
    routes: [
      GoRoute(
        path: AppRoutes.sendPackage,
        builder: (_, __) => const SendPackageScreen(),
      ),
      GoRoute(
        path: AppRoutes.sendPackageSuccess,
        builder: (context, state) {
          final shipment = state.extra as ShipmentDto?;
          return shipment != null
              ? SendPackageSuccessScreen(shipment: shipment)
              : const SizedBox.shrink();
        },
      ),
      // Stub home route so context.go(AppRoutes.home) doesn't crash in tests.
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const Scaffold(body: Text('Home')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      customerAuthProvider.overrideWith((ref) => authNotifier),
      shipmentServiceProvider.overrideWithValue(shipmentService),
    ],
    child: MaterialApp.router(
      theme: CereloTheme.light,
      routerConfig: router,
    ),
  );
}

// ---------------------------------------------------------------------------
// Shared auth helpers
// ---------------------------------------------------------------------------

Future<CustomerAuthNotifier> makeAuthenticatedNotifier() async {
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
  return notifier;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SendPackageScreen Multi-Step Flow', () {
    testWidgets(
        'completes 5-step wizard and submits request with server confirmation',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authNotifier = await makeAuthenticatedNotifier();
      final fakeShipments = FakeShipmentService();

      await tester.pumpWidget(
        createTestWidget(
          authNotifier: authNotifier,
          shipmentService: fakeShipments,
        ),
      );
      await tester.pumpAndSettle();

      // ─── STEP 1: Route & Pickup ───
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Route & Pickup'), findsWidgets);
      expect(find.text('Kano'), findsOneWidget);
      expect(find.text('Katsina'), findsOneWidget);

      // Enter pickup address
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Street Address / Shop / Plaza'),
        'Shop 12 Kwari Textile Market, Fagge, Kano',
      );
      await tester.pump();

      // Tap continue
      await tester.tap(find.text('Continue to Receiver Details'));
      await tester.pumpAndSettle();

      // ─── STEP 2: Receiver Details ───
      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text('Receiver Details'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Receiver Full Name'),
        'Fatima Bello',
      );
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Receiver Phone Number'),
        '08012345678',
      );
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Delivery Address in Katsina'),
        'No. 45 Kofar Kaura Layout, Katsina',
      );
      await tester.pump();

      // Tap continue
      await tester.tap(find.text('Continue to Parcel Details'));
      await tester.pumpAndSettle();

      // ─── STEP 3: Parcel & Size ───
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Parcel & Size'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(CereloTextField, 'What are you sending?'),
        'Ankara fabric bundles',
      );
      await tester.pump();

      // Select Medium Package
      await tester.tap(find.text('Medium Package'));
      await tester.pump();

      // Tap continue
      await tester.tap(find.text('Continue to Payment Selection'));
      await tester.pumpAndSettle();

      // ─── STEP 4: Payment Responsibility ───
      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.text('Payment Responsibility'), findsWidgets);
      expect(find.text('Sender Pays (100%)'), findsOneWidget);
      expect(find.text('Receiver Pays (100%)'), findsOneWidget);
      expect(find.text('Split Payment'), findsOneWidget);

      // Tap continue with default (Sender Pays)
      await tester.tap(find.text('Continue to Review Request'));
      await tester.pumpAndSettle();

      // ─── STEP 5: Review & Request ───
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(find.text('Review & Request'), findsWidgets);

      // Verify review content
      expect(find.text('Kano → Katsina'), findsOneWidget);
      expect(find.text('Shop 12 Kwari Textile Market, Fagge, Kano'), findsOneWidget);
      expect(find.text('Fatima Bello (08012345678)'), findsOneWidget);
      expect(find.text('No. 45 Kofar Kaura Layout, Katsina'), findsOneWidget);
      expect(find.text('Ankara fabric bundles'), findsOneWidget);
      expect(find.text('Medium'), findsWidgets);
      expect(find.text('Sender Pays'), findsWidgets);
      expect(find.text('₦3,500'), findsWidgets);

      // Tap Request Delivery
      await tester.tap(find.text('Request Delivery'));
      await tester.pumpAndSettle();

      // ─── SUCCESS SCREEN ───
      expect(find.text('Delivery Request Received!'), findsOneWidget);
      expect(find.text('CRL-8F2K-9P3N'), findsOneWidget);
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('View Shipment'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);

      // Verify the idempotency key was passed to backend
      expect(fakeShipments.lastSubmittedInput, isNotNull);
      expect(fakeShipments.lastSubmittedInput!.idempotencyKey, isNotNull);
      expect(fakeShipments.lastSubmittedInput!.idempotencyKey!.length, equals(36));
      expect(fakeShipments.lastSubmittedInput!.originCity, equals('Kano'));
      expect(fakeShipments.lastSubmittedInput!.destinationCity, equals('Katsina'));
      expect(fakeShipments.lastSubmittedInput!.receiverName, equals('Fatima Bello'));
      expect(fakeShipments.lastSubmittedInput!.paymentMode, equals(PaymentMode.senderPays));
    });
  });

  group('SendPackageScreen — Back navigation', () {
    testWidgets('step decrements on AppBar back tap at steps 1-4',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authNotifier = await makeAuthenticatedNotifier();
      final fakeShipments = FakeShipmentService();

      await tester.pumpWidget(
        createTestWidget(
          authNotifier: authNotifier,
          shipmentService: fakeShipments,
        ),
      );
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Street Address / Shop / Plaza'),
        '12 Kwari Market',
      );
      await tester.tap(find.text('Continue to Receiver Details'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 5'), findsOneWidget);

      // Advance to Step 3
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Receiver Full Name'),
        'Fatima Bello',
      );
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Receiver Phone Number'),
        '08012345678',
      );
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Delivery Address in Katsina'),
        'No. 45 Kofar Kaura',
      );
      await tester.tap(find.text('Continue to Parcel Details'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 5'), findsOneWidget);

      // Press AppBar back → Step 2
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 5'), findsOneWidget);

      // Press AppBar back → Step 1
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 5'), findsOneWidget);
    });

    testWidgets('AppBar back at step 0 navigates to Home (not trapped)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authNotifier = await makeAuthenticatedNotifier();
      final fakeShipments = FakeShipmentService();

      await tester.pumpWidget(
        createTestWidget(
          authNotifier: authNotifier,
          shipmentService: fakeShipments,
        ),
      );
      await tester.pumpAndSettle();

      // We are at step 1; tap AppBar back — should navigate to Home stub
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Home stub renders 'Home' text
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('abandoning wizard at step 0 creates zero shipments',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authNotifier = await makeAuthenticatedNotifier();
      final fakeShipments = FakeShipmentService();

      await tester.pumpWidget(
        createTestWidget(
          authNotifier: authNotifier,
          shipmentService: fakeShipments,
        ),
      );
      await tester.pumpAndSettle();

      // Tap AppBar back at step 0 to abandon wizard
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // No createShipmentRequest call was made
      expect(fakeShipments.lastSubmittedInput, isNull);
    });

    testWidgets('submit button disabled during submission prevents double-tap',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authNotifier = await makeAuthenticatedNotifier();
      // Use slow service that introduces delay so we can observe in-flight state
      final slowService = _SlowShipmentServiceForWidget();

      final router = GoRouter(
        initialLocation: AppRoutes.sendPackage,
        routes: [
          GoRoute(
            path: AppRoutes.sendPackage,
            builder: (_, __) => const SendPackageScreen(),
          ),
          GoRoute(
            path: AppRoutes.sendPackageSuccess,
            builder: (context, state) {
              final shipment = state.extra as ShipmentDto?;
              return shipment != null
                  ? SendPackageSuccessScreen(shipment: shipment)
                  : const SizedBox.shrink();
            },
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const Scaffold(body: Text('Home')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerAuthProvider.overrideWith((ref) => authNotifier),
            shipmentServiceProvider.overrideWithValue(slowService),
          ],
          child: MaterialApp.router(
            theme: CereloTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to step 5 (Review & Request)
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Street Address / Shop / Plaza'),
        '12 Kwari Market',
      );
      await tester.tap(find.text('Continue to Receiver Details'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Receiver Full Name'),
        'Fatima',
      );
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Receiver Phone Number'),
        '08012345678',
      );
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'Delivery Address in Katsina'),
        'No. 45 Kofar Kaura',
      );
      await tester.tap(find.text('Continue to Parcel Details'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(CereloTextField, 'What are you sending?'),
        'Fabric bundles',
      );
      await tester.pump();
      await tester.tap(find.text('Continue to Payment Selection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to Review Request'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 5'), findsOneWidget);

      // Tap submit once — starts in-flight
      await tester.tap(find.text('Request Delivery'));
      await tester.pump(); // let the tap register but NOT await the future

      // Button should now show loading state
      expect(find.text('Creating shipment...'), findsOneWidget);

      // Tap submit again — should be a no-op (disabled)
      await tester.tap(find.text('Creating shipment...'));
      await tester.pump();

      // Let submission complete
      await tester.pumpAndSettle();

      // Exactly one call was made
      expect(slowService.callCount, equals(1));
    });
  });
}

/// Slow fake for widget tests — adds delay to allow observing loading state.
class _SlowShipmentServiceForWidget extends ShipmentService {
  int callCount = 0;

  @override
  Future<DeliveryQuoteDto> getDeliveryQuote({
    required String originCity,
    required String destinationCity,
    required ParcelSize sizeTier,
  }) async =>
      DeliveryQuoteDto(
        corridorId: 'corridor-kan-kat',
        sizeTierId: 'tier-medium',
        sizeTierCode: 'MEDIUM',
        sizeTierName: 'Medium Package',
        sizeTierDescription: 'Up to 10kg',
        quotedPrice: Money.fromNaira(3500),
      );

  @override
  Future<ShipmentDto> createShipmentRequest(
    CreateShipmentRequestInput input,
  ) async {
    callCount++;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return ShipmentDto(
      id: 'shipment-slow-1',
      deliveryCode: 'CRL-SLOW-001',
      status: ShipmentStatus.requested,
      originCity: input.originCity,
      destinationCity: input.destinationCity,
      senderCustomerId: 'user-1',
      senderNameSnapshot: 'Ismail Danbatta',
      senderPhoneSnapshot: '+2348011111111',
      senderPickupAddressSnapshot: input.senderPickupAddress,
      receiverNameSnapshot: input.receiverName,
      receiverPhoneSnapshot: input.receiverPhone,
      receiverDeliveryAddressSnapshot: input.receiverDeliveryAddress,
      declaredSize: input.parcelSize,
      categoryDescription: input.categoryDescription,
      paymentMode: input.paymentMode,
      quotedPrice: Money.fromNaira(3500),
      finalPrice: Money.fromNaira(3500),
      createdAt: DateTime.now(),
    );
  }
}
