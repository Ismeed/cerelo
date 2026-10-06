import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:customer_app/features/send_package/providers/send_package_provider.dart';
import 'package:customer_app/features/shipments/providers/shipments_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'send_package_flow_test.dart';

void main() {
  group('SendPackageNotifier — state management', () {
    test('initial state has default Kano -> Katsina corridor and medium size', () {
      final fakeService = FakeShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(fakeService),
        ],
      );

      final state = container.read(sendPackageProvider);
      expect(state.originCity, equals('Kano'));
      expect(state.destinationCity, equals('Katsina'));
      expect(state.parcelSize, equals(ParcelSize.medium));
      expect(state.paymentMode, equals(PaymentMode.senderPays));
    });

    test('switchCorridorDirection flips origin and destination', () {
      final fakeService = FakeShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(fakeService),
        ],
      );

      final notifier = container.read(sendPackageProvider.notifier);
      notifier.switchCorridorDirection();

      final state = container.read(sendPackageProvider);
      expect(state.originCity, equals('Katsina'));
      expect(state.destinationCity, equals('Kano'));
    });

    test('setting parcel size refreshes quote', () async {
      final fakeService = FakeShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      // Keep the autoDispose provider alive by subscribing during the async test.
      final sub = container.listen(sendPackageProvider, (_, __) {});

      final notifier = container.read(sendPackageProvider.notifier);
      notifier.setParcelDetails(description: 'Test Box', size: ParcelSize.large);

      // Wait for the async refreshQuote() to complete — fake service returns immediately
      // so we just need to flush the microtask queue and allow the Future to settle.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(sendPackageProvider);
      expect(state.parcelSize, equals(ParcelSize.large));
      expect(state.currentQuote?.quotedPrice.kobo, equals(600000));

      sub.close();
    });

    test('setting split payment stores sender amount', () {
      final fakeService = FakeShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(fakeService),
        ],
      );

      final notifier = container.read(sendPackageProvider.notifier);
      notifier.setPaymentDetails(
        mode: PaymentMode.splitPayment,
        senderAmount: Money.fromNaira(1500),
      );

      final state = container.read(sendPackageProvider);
      expect(state.paymentMode, equals(PaymentMode.splitPayment));
      expect(state.senderPaymentAmount?.kobo, equals(150000));
    });
  });

  group('SendPackageNotifier — idempotency key lifecycle', () {
    test('initial draft generates a non-null idempotency key UUID', () {
      final fakeService = FakeShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(sendPackageProvider);
      expect(state.idempotencyKey, isNotNull);
      expect(state.idempotencyKey!.length, equals(36)); // UUID v4 length
    });

    test('idempotency key is preserved across field mutations (for retry)', () {
      final fakeService = FakeShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final initialKey = container.read(sendPackageProvider).idempotencyKey;

      final notifier = container.read(sendPackageProvider.notifier);
      notifier.setPickupDetails(address: '12 Kwari Market');
      notifier.setReceiverDetails(
        name: 'Fatima Bello',
        phone: '08012345678',
        address: 'No. 45 Kofar Kaura',
      );
      notifier.setParcelDetails(description: 'Ankara fabric', size: ParcelSize.small);

      final mutatedKey = container.read(sendPackageProvider).idempotencyKey;
      expect(mutatedKey, equals(initialKey));
    });

    test('reset() generates a NEW idempotency key', () async {
      final fakeService = FakeShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      // Keep the autoDispose provider alive.
      final sub = container.listen(sendPackageProvider, (_, __) {});

      final initialKey = container.read(sendPackageProvider).idempotencyKey;

      container.read(sendPackageProvider.notifier).reset();
      // Allow refreshQuote async to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final resetKey = container.read(sendPackageProvider).idempotencyKey;
      expect(resetKey, isNotNull);
      expect(resetKey, isNot(equals(initialKey)));

      sub.close();
    });

    test('idempotency key is passed to createShipmentRequest input', () async {
      final fakeService = FakeShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(sendPackageProvider, (_, __) {});

      // Capture the initial idempotency key before submission
      await Future<void>.delayed(const Duration(milliseconds: 50)); // settle quote
      final expectedKey = container.read(sendPackageProvider).idempotencyKey;

      final notifier = container.read(sendPackageProvider.notifier);
      notifier.setPickupDetails(address: '12 Kwari Market');
      notifier.setReceiverDetails(
        name: 'Fatima Bello',
        phone: '08012345678',
        address: 'No. 45 Kofar Kaura',
      );
      notifier.setParcelDetails(description: 'Ankara fabric', size: ParcelSize.medium);

      await notifier.submitShipmentRequest();

      expect(fakeService.lastSubmittedInput?.idempotencyKey, equals(expectedKey));

      sub.close();
    });

    test('idempotency key is preserved on submission failure (for retry)', () async {
      // Fake service that always throws on the first call
      final failingService = _FailingShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(failingService),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(sendPackageProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final keyBeforeSubmit = container.read(sendPackageProvider).idempotencyKey;

      final notifier = container.read(sendPackageProvider.notifier);
      notifier.setPickupDetails(address: '12 Kwari Market');
      notifier.setReceiverDetails(
        name: 'Fatima',
        phone: '08012345678',
        address: 'Kofar Kaura',
      );

      await notifier.submitShipmentRequest(); // will fail

      final keyAfterFailure = container.read(sendPackageProvider).idempotencyKey;
      // Key MUST be the same so a retry reuses it
      expect(keyAfterFailure, equals(keyBeforeSubmit));

      sub.close();
    });
  });

  group('SendPackageNotifier — in-flight submission guard', () {
    test('concurrent submitShipmentRequest calls only submit once', () async {
      // Fake service that adds a small delay so the first submission is still
      // in flight when the second fires.
      final slowService = _SlowShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(slowService),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(sendPackageProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(sendPackageProvider.notifier);
      notifier.setPickupDetails(address: '12 Kwari Market');
      notifier.setReceiverDetails(
        name: 'Fatima',
        phone: '08012345678',
        address: 'Kofar Kaura',
      );

      // Fire two submissions concurrently — only the first should proceed.
      final results = await Future.wait([
        notifier.submitShipmentRequest(),
        notifier.submitShipmentRequest(),
      ]);

      // First call returns shipment; second is rejected (returns null).
      expect(slowService.callCount, equals(1));
      expect(results.where((s) => s != null).length, equals(1));
      expect(results.where((s) => s == null).length, equals(1));

      sub.close();
    });

    test('isSubmitting is true during submission and false after', () async {
      final slowService = _SlowShipmentService();
      final container = ProviderContainer(
        overrides: [
          shipmentServiceProvider.overrideWithValue(slowService),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(sendPackageProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(sendPackageProvider.notifier);
      notifier.setPickupDetails(address: '12 Kwari Market');
      notifier.setReceiverDetails(
        name: 'Fatima',
        phone: '08012345678',
        address: 'Kofar Kaura',
      );

      expect(container.read(sendPackageProvider).isSubmitting, isFalse);

      final future = notifier.submitShipmentRequest();
      // isSubmitting becomes true synchronously on the next microtask
      await Future<void>.microtask(() {});
      expect(container.read(sendPackageProvider).isSubmitting, isTrue);

      await future;
      expect(container.read(sendPackageProvider).isSubmitting, isFalse);

      sub.close();
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Fake ShipmentService that always fails with a server error.
class _FailingShipmentService extends ShipmentService {
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
    throw const CereloApiError(
      code: CereloErrorCode.internalError,
      message: 'Simulated server failure',
    );
  }
}

/// Fake ShipmentService that adds a short delay to simulate network latency.
class _SlowShipmentService extends ShipmentService {
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
    await Future<void>.delayed(const Duration(milliseconds: 80));
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
