import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/features/delivery/providers/delivery_provider.dart';
import 'package:personnel_app/features/delivery/screens/delivery_detail_screen.dart';

class FakePersonnelDeliveryService extends PersonnelDeliveryService {
  bool wasStartFinalDeliveryCalled = false;
  bool wasPaymentRecorded = false;
  bool wasMarkDeliveredCalled = false;
  bool wasSenderCallRecorded = false;

  @override
  Future<bool> startFinalDelivery(String shipmentId) async {
    wasStartFinalDeliveryCalled = true;
    return true;
  }

  @override
  Future<bool> recordReceiverPayment({
    required String shipmentId,
    required Money amount,
    String method = 'CASH',
    String? idempotencyKey,
  }) async {
    wasPaymentRecorded = true;
    return true;
  }

  @override
  Future<bool> markDelivered({
    required String shipmentId,
    String? idempotencyKey,
  }) async {
    wasMarkDeliveredCalled = true;
    return true;
  }

  @override
  Future<bool> recordSenderCompletionCall({
    required String shipmentId,
    required String outcome,
    String? notes,
  }) async {
    wasSenderCallRecorded = true;
    return true;
  }
}

void main() {
  final sampleDeliveryTask = DeliveryTaskDto(
    shipmentId: 'shipment-101',
    parcelId: 'parcel-101',
    deliveryCode: 'CRL-8F2K-9P3N',
    parcelQrToken: 'PQR-7K9A-3M2P-9Q4W',
    status: ShipmentStatus.arrivedDestination,
    originCity: 'Kano',
    destinationCity: 'Katsina',
    senderName: 'Malam Bello',
    senderPhone: '+2348011111111',
    receiverName: 'Hajiya Fatima',
    receiverPhone: '+2348022222222',
    receiverDeliveryAddress: '14 IBB Way, Katsina',
    confirmedSizeCode: 'MEDIUM',
    confirmedSizeName: 'Medium Package',
    categoryDescription: 'Ankara Fabric',
    paymentMode: PaymentMode.receiverPays,
    finalPrice: Money.fromNaira(3500),
    receiverPaymentStatus: PaymentStatus.pending,
    receiverDueAmount: Money.fromNaira(3500),
    createdAt: DateTime.now(),
  );

  Widget createTestWidget({required FakePersonnelDeliveryService service}) {
    return ProviderScope(
      overrides: [
        personnelDeliveryServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: DeliveryDetailScreen(task: sampleDeliveryTask),
      ),
    );
  }

  group('DeliveryDetailScreen Workflow', () {
    testWidgets('executes Start Delivery -> Record Payment -> Mark Delivered -> Sender Call',
        (tester) async {
      final fakeService = FakePersonnelDeliveryService();

      await tester.pumpWidget(createTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Hajiya Fatima'), findsOneWidget);
      expect(find.text('14 IBB Way, Katsina'), findsOneWidget);
      expect(find.text('Step 1: Start Final Delivery'), findsOneWidget);

      // 1. Start Final Delivery
      await tester.tap(find.text('Start Doorstep Delivery'));
      await tester.pumpAndSettle();

      expect(fakeService.wasStartFinalDeliveryCalled, isTrue);
      expect(find.text('Step 2: Receiver Payment'), findsOneWidget);
      expect(find.text('Record ₦3,500 Cash Collected'), findsOneWidget);

      // 2. Record Payment
      await tester.tap(find.text('Record ₦3,500 Cash Collected'));
      await tester.pumpAndSettle();

      expect(find.text('Record Physical Cash Payment'), findsOneWidget);
      await tester.tap(find.text('Confirm ₦3,500 Cash Collected'));
      await tester.pumpAndSettle();

      expect(fakeService.wasPaymentRecorded, isTrue);
      expect(find.text('COLLECTED'), findsOneWidget);

      // 3. Mark Delivered
      expect(find.text('Confirm Handover & Mark Delivered'), findsOneWidget);
      await tester.tap(find.text('Confirm Handover & Mark Delivered'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Handover & Delivery'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark Delivered'));
      await tester.pumpAndSettle();

      expect(fakeService.wasMarkDeliveredCalled, isTrue);
      expect(find.text('Parcel Successfully Delivered!'), findsOneWidget);
      expect(find.text('MANDATORY DOORSTEP SOP:'), findsOneWidget);

      // 4. Record Sender Call
      expect(find.text('Reached & Confirmed'), findsOneWidget);
      await tester.tap(find.text('Reached & Confirmed'));
      await tester.pumpAndSettle();

      expect(fakeService.wasSenderCallRecorded, isTrue);
      expect(find.text('Doorstep sender confirmation call recorded.'), findsOneWidget);
    });
  });
}
