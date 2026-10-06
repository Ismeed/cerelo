import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/features/pickup/providers/pickup_provider.dart';
import 'package:personnel_app/features/pickup/screens/pickup_detail_screen.dart';

import 'pickup_provider_test.dart';

void main() {
  final sampleTask = PickupTaskDto(
    id: 'task-flow-1',
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
    categoryDescription: 'Ankara Fabrics',
    paymentMode: PaymentMode.senderPays,
    quotedPrice: Money.fromNaira(3500),
    finalPrice: Money.fromNaira(3500),
    createdAt: DateTime.now(),
  );

  Widget createTestWidget({required FakePersonnelPickupService service}) {
    return ProviderScope(
      overrides: [
        personnelPickupServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: PickupDetailScreen(task: sampleTask),
      ),
    );
  }

  group('PickupDetailScreen Operational Flow', () {
    testWidgets(
        'completes receiver verification, cash collection, and parcel confirmation',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeService = FakePersonnelPickupService();

      await tester.pumpWidget(createTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Pickup: Kano → Katsina'), findsOneWidget);
      expect(find.text('Sender: Ismail Danbatta'), findsNothing); // Inside card
      expect(find.text('Ismail Danbatta'), findsOneWidget);
      expect(find.text('Receiver: Fatima Bello'), findsOneWidget);

      // Confirm Parcel button is initially disabled (canConfirm = false)
      final confirmBtn = tester.widget<CereloButton>(
        find.widgetWithText(CereloButton, 'Confirm Parcel & Accept Custody'),
      );
      expect(confirmBtn.onPressed, isNull);

      // ─── CLAIM STEP: Accept Pickup Task ───
      expect(find.text('Task Unassigned in Hub Queue'), findsOneWidget);
      expect(find.text('Accept Pickup Task'), findsOneWidget);
      await tester.tap(find.text('Accept Pickup Task'));
      await tester.pumpAndSettle();

      // ─── STEP 1: Receiver Verification Call ───
      await tester.tap(find.text('Record Receiver Call Outcome'));
      await tester.pumpAndSettle();

      expect(find.text('Record Receiver Verification Outcome'), findsOneWidget);
      expect(find.text('Receiver Verified & Ready'), findsOneWidget);

      await tester.tap(find.text('Receiver Verified & Ready'));
      await tester.pumpAndSettle();

      expect(find.text('VERIFIED'), findsOneWidget);

      // ─── STEP 2: Parcel Size Selection ───
      // Chips carry the size only. The fare is whatever the server returns for
      // that size, asserted below through the ₦6,000 cash-collection step.
      expect(find.text('Large'), findsOneWidget);
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();

      // ─── STEP 3: Record Physical Cash Payment ───
      expect(find.text('Record ₦6,000 Cash Collected'), findsOneWidget);
      await tester.tap(find.text('Record ₦6,000 Cash Collected'));
      await tester.pumpAndSettle();

      expect(find.text('Record Physical Cash Payment'), findsOneWidget);
      expect(find.text('Confirm ₦6,000 Cash Collected'), findsOneWidget);

      await tester.tap(find.text('Confirm ₦6,000 Cash Collected'));
      await tester.pumpAndSettle();

      expect(find.text('SATISFIED'), findsOneWidget);

      // ─── STEP 4: Confirm Parcel & Accept Custody ───
      final activeConfirmBtn = tester.widget<CereloButton>(
        find.widgetWithText(CereloButton, 'Confirm Parcel & Accept Custody'),
      );
      expect(activeConfirmBtn.onPressed, isNotNull);

      await tester.tap(find.text('Confirm Parcel & Accept Custody'));
      await tester.pumpAndSettle();

      // ─── SUCCESS SCREEN ───
      expect(find.text('Parcel Confirmed!'), findsOneWidget);
      expect(find.text('CRL-8F2K-9P3N'), findsOneWidget);
      expect(find.text('Copy Code for Sender'), findsOneWidget);
      expect(find.text('Back to Pickup Tasks'), findsOneWidget);
    });
  });
}
