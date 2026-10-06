import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/features/pickup/providers/pickup_provider.dart';

class FakePersonnelPickupService extends PersonnelPickupService {
  FakePersonnelPickupService({
    this.verificationResult = true,
    this.paymentResult = true,
    this.confirmResult,
  });

  final bool verificationResult;
  final bool paymentResult;
  final ConfirmParcelResultDto? confirmResult;

  @override
  Future<List<PickupTaskDto>> getPickupQueue() async {
    return [
      PickupTaskDto(
        id: 'task-1',
        status: ShipmentStatus.requested,
        originCity: 'Kano',
        destinationCity: 'Katsina',
        senderName: 'Ismail Danbatta',
        senderPhone: '+2348011111111',
        senderPickupAddress: 'Shop 12 Kwari Market, Kano',
        receiverName: 'Fatima Bello',
        receiverPhone: '+2348022222222',
        receiverDeliveryAddress: '45 Kofar Kaura, Katsina',
        declaredSize: ParcelSize.medium,
        declaredSizeName: 'Medium Package',
        categoryDescription: 'Fabrics',
        paymentMode: PaymentMode.senderPays,
        quotedPrice: Money.fromNaira(3500),
        finalPrice: Money.fromNaira(3500),
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<bool> recordReceiverVerification({
    required String shipmentId,
    required String outcome,
    String? notes,
  }) async {
    return outcome == 'VERIFIED' && verificationResult;
  }

  @override
  Future<Money> verifyAndCorrectParcelSize({
    required String shipmentId,
    required ParcelSize sizeTier,
    String? reason,
    bool senderAcknowledged = true,
  }) async {
    return switch (sizeTier) {
      ParcelSize.small => Money.fromNaira(2000),
      ParcelSize.medium => Money.fromNaira(3500),
      ParcelSize.large => Money.fromNaira(6000),
    };
  }

  @override
  Future<bool> recordPhysicalPayment({
    required String shipmentId,
    required String payerParty,
    required Money amount,
    String method = 'CASH',
    String? idempotencyKey,
  }) async {
    return paymentResult;
  }

  @override
  Future<bool> claimPickupTask(String shipmentId) async {
    return true;
  }

  @override
  Future<ConfirmParcelResultDto> confirmParcelPickup({
    required String shipmentId,
    required ParcelSize verifiedSize,
    String? idempotencyKey,
  }) async {
    return confirmResult ??
        ConfirmParcelResultDto(
          success: true,
          shipmentId: shipmentId,
          deliveryCode: 'CRL-8F2K-9P3N',
          status: ShipmentStatus.parcelConfirmed,
          confirmedSizeCode: verifiedSize.name.toUpperCase(),
          confirmedSizeName: verifiedSize.displayLabel,
          finalPrice: Money.fromNaira(3500),
        );
  }
}

void main() {
  final sampleTask = PickupTaskDto(
    id: 'task-1',
    status: ShipmentStatus.requested,
    originCity: 'Kano',
    destinationCity: 'Katsina',
    senderName: 'Ismail Danbatta',
    senderPhone: '+2348011111111',
    senderPickupAddress: 'Shop 12 Kwari Market, Kano',
    receiverName: 'Fatima Bello',
    receiverPhone: '+2348022222222',
    receiverDeliveryAddress: '45 Kofar Kaura, Katsina',
    declaredSize: ParcelSize.medium,
    declaredSizeName: 'Medium Package',
    categoryDescription: 'Fabrics',
    paymentMode: PaymentMode.senderPays,
    quotedPrice: Money.fromNaira(3500),
    finalPrice: Money.fromNaira(3500),
    createdAt: DateTime.now(),
  );

  group('ActivePickupNotifier', () {
    test('initial state preserves declared size and requires payment for Sender Pays', () {
      final fakeService = FakePersonnelPickupService();
      final container = ProviderContainer(
        overrides: [
          personnelPickupServiceProvider.overrideWithValue(fakeService),
        ],
      );

      final state = container.read(activePickupProvider(sampleTask));
      expect(state.verifiedSize, equals(ParcelSize.medium));
      expect(state.isReceiverVerified, isFalse);
      expect(state.isPaymentCollected, isFalse);
    });

    test('recording verified receiver call updates verification state', () async {
      final fakeService = FakePersonnelPickupService();
      final container = ProviderContainer(
        overrides: [
          personnelPickupServiceProvider.overrideWithValue(fakeService),
        ],
      );

      final notifier = container.read(activePickupProvider(sampleTask).notifier);
      final success = await notifier.recordReceiverVerification(outcome: 'VERIFIED');

      expect(success, isTrue);
      final state = container.read(activePickupProvider(sampleTask));
      expect(state.isReceiverVerified, isTrue);
      expect(state.receiverVerificationOutcome, equals('VERIFIED'));
    });

    test('updating parcel size recalculates final price', () async {
      final fakeService = FakePersonnelPickupService();
      final container = ProviderContainer(
        overrides: [
          personnelPickupServiceProvider.overrideWithValue(fakeService),
        ],
      );

      final notifier = container.read(activePickupProvider(sampleTask).notifier);
      await notifier.updateParcelSize(ParcelSize.large, reason: 'Bulky fabric roll');

      final state = container.read(activePickupProvider(sampleTask));
      expect(state.verifiedSize, equals(ParcelSize.large));
      expect(state.task.finalPrice.kobo, equals(600000));
    });

    test('recording physical payment marks payment collected', () async {
      final fakeService = FakePersonnelPickupService();
      final container = ProviderContainer(
        overrides: [
          personnelPickupServiceProvider.overrideWithValue(fakeService),
        ],
      );

      final notifier = container.read(activePickupProvider(sampleTask).notifier);
      final success = await notifier.recordSenderPayment(method: 'CASH');

      expect(success, isTrue);
      final state = container.read(activePickupProvider(sampleTask));
      expect(state.isPaymentCollected, isTrue);
    });

    test('confirming parcel returns confirmed result with Delivery Code', () async {
      final fakeService = FakePersonnelPickupService();
      final container = ProviderContainer(
        overrides: [
          personnelPickupServiceProvider.overrideWithValue(fakeService),
        ],
      );

      final notifier = container.read(activePickupProvider(sampleTask).notifier);
      await notifier.recordReceiverVerification(outcome: 'VERIFIED');
      await notifier.recordSenderPayment(method: 'CASH');

      final success = await notifier.confirmParcel();
      expect(success, isTrue);
      final state = container.read(activePickupProvider(sampleTask));
      expect(state.confirmedResult, isNotNull);
      expect(state.confirmedResult!.deliveryCode, equals('CRL-8F2K-9P3N'));
      expect(state.confirmedResult!.status, equals(ShipmentStatus.parcelConfirmed));
    });
  });
}
