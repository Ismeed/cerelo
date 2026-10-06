import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/features/auth/providers/auth_provider.dart';
import 'package:customer_app/features/shipments/providers/shipments_provider.dart';
import 'package:customer_app/features/shipments/screens/shared_shipment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_notifier_test.dart';

class FakeSharingShipmentService extends ShipmentService {
  FakeSharingShipmentService({
    this.sharedShipmentToReturn,
    this.linkResult = true,
  });

  final SharedShipmentDto? sharedShipmentToReturn;
  final bool linkResult;
  bool wasLinkCalled = false;

  @override
  Future<SharedShipmentDto?> resolveShareToken(String token) async {
    return sharedShipmentToReturn ??
        SharedShipmentDto(
          shipmentId: 'shipment-123',
          originCity: 'Kano',
          destinationCity: 'Katsina',
          status: ShipmentStatus.requested,
          senderDisplayName: 'Ismail',
          receiverNameSnapshot: 'Fatima Bello',
          receiverPhoneMasked: '+234 801 ***5678',
          receiverDeliveryAddress: '45 Kofar Kaura Layout, Katsina',
          categoryDescription: 'Ankara fabrics',
          paymentMode: PaymentMode.senderPays,
          receiverExpectedAmount: Money.zero,
          alreadyLinked: false,
          isIntendedReceiver: true,
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<bool> linkAuthenticatedReceiver(String token) async {
    wasLinkCalled = true;
    return linkResult;
  }
}

void main() {
  Widget createTestWidget({
    required CustomerAuthNotifier authNotifier,
    required FakeSharingShipmentService shipmentService,
    required String token,
  }) {
    return ProviderScope(
      overrides: [
        customerAuthProvider.overrideWith((ref) => authNotifier),
        shipmentServiceProvider.overrideWithValue(shipmentService),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: SharedShipmentScreen(token: token),
      ),
    );
  }

  group('SharedShipmentScreen', () {
    testWidgets('renders privacy-safe details and sign-in button when unauthenticated', (tester) async {
      final fakeAuth = FakeAuthService(initialUser: null);
      final fakeCustomer = FakeCustomerService(profileToReturn: null);
      final authNotifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );

      final fakeShipments = FakeSharingShipmentService();

      await tester.pumpWidget(
        createTestWidget(
          authNotifier: authNotifier,
          shipmentService: fakeShipments,
          token: 'valid-test-token',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared Delivery'), findsOneWidget);
      expect(find.text('Kano'), findsOneWidget);
      expect(find.text('Katsina'), findsOneWidget);
      expect(find.text('From: Ismail'), findsOneWidget);
      expect(find.text('To: Fatima Bello (+234 801 ***5678)'), findsOneWidget);
      expect(find.text('Paid by Sender'), findsOneWidget);
      expect(find.text('Sign In to Claim Delivery'), findsOneWidget);
    });

    testWidgets('allows authenticated receiver to claim delivery', (tester) async {
      final fakeAuth = FakeAuthService(
        initialUser: const CereloUser(
          id: 'receiver-user-1',
          email: 'fatima@cerelo.com',
          role: ActorRole.customer,
          phoneNumber: '+2348012345678',
        ),
      );
      final fakeCustomer = FakeCustomerService(
        profileToReturn: CustomerProfileDto(
          id: 'receiver-user-1',
          fullName: 'Fatima Bello',
          accountType: AccountType.individual,
          onboardingCompletedAt: DateTime.now(),
        ),
      );
      final authNotifier = CustomerAuthNotifier(
        authService: fakeAuth,
        customerService: fakeCustomer,
      );
      await authNotifier.retryProfileResolution();

      final fakeShipments = FakeSharingShipmentService();

      await tester.pumpWidget(
        createTestWidget(
          authNotifier: authNotifier,
          shipmentService: fakeShipments,
          token: 'valid-test-token',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add to My Received Deliveries'), findsOneWidget);

      await tester.tap(find.text('Add to My Received Deliveries'));
      await tester.pump();

      expect(fakeShipments.wasLinkCalled, isTrue);
    });
  });
}
