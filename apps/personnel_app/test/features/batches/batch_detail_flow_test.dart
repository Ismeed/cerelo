import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/features/batches/providers/batch_provider.dart';
import 'package:personnel_app/features/batches/screens/batch_detail_screen.dart';

class FakePersonnelBatchService extends PersonnelBatchService {
  FakePersonnelBatchService({
    required this.manifest,
  });

  BatchManifestDto manifest;
  bool wasConfirmCalled = false;
  bool wasOnboardCalled = false;
  bool wasTransportSaved = false;

  @override
  Future<BatchManifestDto?> getBatchManifest(String batchId) async {
    return manifest;
  }

  @override
  Future<String> confirmBatch(String batchId) async {
    wasConfirmCalled = true;
    manifest = BatchManifestDto(
      batchId: manifest.batchId,
      batchReference: manifest.batchReference,
      batchQrToken: 'BQR-7K9A-3M2P-9Q4W',
      status: BatchStatus.confirmed,
      corridorCode: manifest.corridorCode,
      originCity: manifest.originCity,
      destinationCity: manifest.destinationCity,
      manifestParcelCount: manifest.manifestParcelCount,
      driverName: manifest.driverName,
      driverPhone: manifest.driverPhone,
      vehiclePlateNumber: manifest.vehiclePlateNumber,
      agreedCost: manifest.agreedCost,
      confirmedAt: DateTime.now(),
      parcels: manifest.parcels,
    );
    return 'BQR-7K9A-3M2P-9Q4W';
  }

  @override
  Future<bool> setBatchTransport({
    required String batchId,
    required String providerName,
    String? driverName,
    String? driverPhone,
    String? vehiclePlate,
    required Money agreedCost,
  }) async {
    wasTransportSaved = true;
    manifest = BatchManifestDto(
      batchId: manifest.batchId,
      batchReference: manifest.batchReference,
      batchQrToken: manifest.batchQrToken,
      status: manifest.status,
      corridorCode: manifest.corridorCode,
      originCity: manifest.originCity,
      destinationCity: manifest.destinationCity,
      manifestParcelCount: manifest.manifestParcelCount,
      driverName: driverName,
      driverPhone: driverPhone,
      vehiclePlateNumber: vehiclePlate,
      agreedCost: agreedCost,
      confirmedAt: manifest.confirmedAt,
      parcels: manifest.parcels,
    );
    return true;
  }

  @override
  Future<bool> onboardBatch(String batchId) async {
    wasOnboardCalled = true;
    manifest = BatchManifestDto(
      batchId: manifest.batchId,
      batchReference: manifest.batchReference,
      batchQrToken: manifest.batchQrToken,
      status: BatchStatus.onboarded,
      corridorCode: manifest.corridorCode,
      originCity: manifest.originCity,
      destinationCity: manifest.destinationCity,
      manifestParcelCount: manifest.manifestParcelCount,
      driverName: manifest.driverName,
      driverPhone: manifest.driverPhone,
      vehiclePlateNumber: manifest.vehiclePlateNumber,
      agreedCost: manifest.agreedCost,
      confirmedAt: manifest.confirmedAt,
      onboardedAt: DateTime.now(),
      parcels: manifest.parcels,
    );
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
    categoryDescription: 'Ankara Fabrics',
    createdAt: DateTime.now(),
  );

  final sampleDraftManifest = BatchManifestDto(
    batchId: 'batch-test-1',
    batchReference: 'BAT-8F2K-9P3N',
    status: BatchStatus.draft,
    corridorCode: 'KAN-KAT',
    originCity: 'Kano',
    destinationCity: 'Katsina',
    manifestParcelCount: 1,
    agreedCost: Money.fromNaira(7000),
    parcels: [sampleParcel],
  );

  Widget createTestWidget({required FakePersonnelBatchService service}) {
    return ProviderScope(
      overrides: [
        personnelBatchServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: const BatchDetailScreen(batchId: 'batch-test-1'),
      ),
    );
  }

  group('BatchDetailScreen Workflow', () {
    testWidgets('confirms draft batch manifest and displays Batch QR and transport',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeService =
          FakePersonnelBatchService(manifest: sampleDraftManifest);

      await tester.pumpWidget(createTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Kano → Katsina'), findsOneWidget);
      expect(find.text('BAT-8F2K-9P3N'), findsOneWidget);
      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('CRL-8F2K-9P3N'), findsOneWidget);

      // Confirm Batch
      expect(find.text('Confirm Batch & Freeze Manifest'), findsOneWidget);
      await tester.tap(find.text('Confirm Batch & Freeze Manifest'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Batch Manifest?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Batch'));
      await tester.pumpAndSettle();

      expect(fakeService.wasConfirmCalled, isTrue);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('Batch Container Label'), findsOneWidget);
      expect(find.text('Middle-Mile Transport Arrangement'), findsOneWidget);

      // Onboard Batch
      expect(find.text('Mark Batch Onboarded (Vehicle Departed)'), findsOneWidget);
      await tester.tap(find.text('Mark Batch Onboarded (Vehicle Departed)'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Physical Departure'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark Onboarded'));
      await tester.pumpAndSettle();

      expect(fakeService.wasOnboardCalled, isTrue);
      expect(find.text('ONBOARDED'), findsOneWidget);
      expect(find.text('Batch is In Transit'), findsOneWidget);
    });
  });
}
