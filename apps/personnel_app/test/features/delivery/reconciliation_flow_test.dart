import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/features/batches/providers/batch_provider.dart';
import 'package:personnel_app/features/delivery/providers/delivery_provider.dart';
import 'package:personnel_app/features/delivery/screens/reconciliation_screen.dart';

class FakeReconciliationBatchService extends PersonnelBatchService {
  FakeReconciliationBatchService({required this.manifest});
  BatchManifestDto manifest;

  @override
  Future<BatchManifestDto?> getBatchManifest(String batchId) async {
    return manifest;
  }
}

class FakeReconciliationDeliveryService extends PersonnelDeliveryService {
  bool wasArrivalConfirmed = false;
  bool wasReconciled = false;
  bool wasCompleted = false;

  @override
  Future<bool> receiveDestinationBatch({
    required String batchIdentifier,
    String? batchId,
  }) async {
    wasArrivalConfirmed = true;
    return true;
  }

  @override
  Future<bool> reconcileBatchParcel({
    required String batchId,
    required String parcelId,
    required String disposition,
    String? notes,
  }) async {
    wasReconciled = true;
    return true;
  }

  @override
  Future<bool> completeBatchReconciliation(String batchId) async {
    wasCompleted = true;
    return true;
  }
}

void main() {
  final sampleParcel = ReadyForBatchParcelDto(
    parcelId: 'parcel-101',
    shipmentId: 'shipment-101',
    deliveryCode: 'CRL-8F2K-9P3N',
    parcelQrToken: 'PQR-7K9A-3M2P-9Q4W',
    originCity: 'Kano',
    destinationCity: 'Katsina',
    confirmedSizeCode: 'MEDIUM',
    confirmedSizeName: 'Medium Package',
    categoryDescription: 'Ankara Fabric',
    createdAt: DateTime.now(),
  );

  final sampleManifest = BatchManifestDto(
    batchId: 'batch-reconcile-1',
    batchReference: 'BAT-8F2K-9P3N',
    status: BatchStatus.destinationReceived,
    corridorCode: 'KAN-KAT',
    originCity: 'Kano',
    destinationCity: 'Katsina',
    manifestParcelCount: 1,
    agreedCost: const Money.fromNaira(7000),
    parcels: [sampleParcel],
  );

  Widget createTestWidget({
    required FakeReconciliationBatchService batchService,
    required FakeReconciliationDeliveryService deliveryService,
  }) {
    return ProviderScope(
      overrides: [
        personnelBatchServiceProvider.overrideWithValue(batchService),
        personnelDeliveryServiceProvider.overrideWithValue(deliveryService),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: const ReconciliationScreen(batchId: 'batch-reconcile-1'),
      ),
    );
  }

  group('ReconciliationScreen Workflow', () {
    testWidgets('reconciles expected parcel as present and completes reconciliation',
        (tester) async {
      final batchService =
          FakeReconciliationBatchService(manifest: sampleManifest);
      final deliveryService = FakeReconciliationDeliveryService();

      await tester.pumpWidget(createTestWidget(
        batchService: batchService,
        deliveryService: deliveryService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kano → Katsina'), findsOneWidget);
      expect(find.text('BAT-8F2K-9P3N'), findsOneWidget);
      expect(find.text('CRL-8F2K-9P3N'), findsOneWidget);

      // Reconcile item as present
      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      expect(deliveryService.wasReconciled, isTrue);

      // Complete Reconciliation
      expect(find.text('Complete Reconciliation (1/1)'), findsOneWidget);
      await tester.tap(find.text('Complete Reconciliation (1/1)'));
      await tester.pumpAndSettle();

      expect(deliveryService.wasCompleted, isTrue);
    });
  });
}
