import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/features/parcels/dialogs/parcel_hub_processing_sheet.dart';
import 'package:personnel_app/features/parcels/providers/hub_provider.dart';

class FakePersonnelHubService extends PersonnelHubService {
  FakePersonnelHubService({
    this.receiveSuccess = true,
    this.readyParcels = const [],
  });

  final bool receiveSuccess;
  final List<ReadyForBatchParcelDto> readyParcels;
  bool wasReceiveCalled = false;

  @override
  Future<bool> receiveParcelAtOriginHub(String parcelId) async {
    wasReceiveCalled = true;
    return receiveSuccess;
  }

  @override
  Future<List<ReadyForBatchParcelDto>> getReadyForBatchParcels() async {
    return readyParcels;
  }
}

void main() {
  final sampleResolvedParcel = ResolvedParcelDto(
    parcelId: 'parcel-test-1',
    shipmentId: 'shipment-test-1',
    deliveryCode: 'CRL-8F2K-9P3N',
    parcelQrToken: 'PQR-7K9A-3M2P-9Q4W',
    currentParcelState: ParcelState.inCereloCustody,
    currentStatus: ShipmentStatus.parcelConfirmed,
    originCity: 'Kano',
    destinationCity: 'Katsina',
    senderName: 'Ismail Danbatta',
    receiverName: 'Fatima Bello',
    confirmedSizeCode: 'MEDIUM',
    confirmedSizeName: 'Medium Package',
    categoryDescription: 'Ankara Fabrics',
    finalPrice: Money.fromNaira(3500),
    paymentMode: PaymentMode.senderPays,
    isHubReceived: false,
    isReadyForBatch: false,
  );

  Widget createTestWidget({required FakePersonnelHubService service}) {
    return ProviderScope(
      overrides: [
        personnelHubServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: Scaffold(
          body: ParcelHubProcessingSheet(parcel: sampleResolvedParcel),
        ),
      ),
    );
  }

  group('ParcelHubProcessingSheet', () {
    testWidgets(
        'displays resolved parcel details and confirms origin hub receipt',
        (tester) async {
      final fakeService = FakePersonnelHubService();

      await tester.pumpWidget(createTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Hub Parcel Processing'), findsOneWidget);
      expect(find.text('Kano → Katsina'), findsOneWidget);
      expect(find.text('CRL-8F2K-9P3N'), findsOneWidget);
      expect(find.text('Medium Package'), findsOneWidget);
      expect(find.text('IN PERSONNEL CUSTODY'), findsOneWidget);
      expect(find.text('Receive at Origin Hub'), findsOneWidget);

      await tester.tap(find.text('Receive at Origin Hub'));
      await tester.pumpAndSettle();

      expect(fakeService.wasReceiveCalled, isTrue);
      expect(find.text('STAGED AT ORIGIN HUB'), findsOneWidget);
    });
  });
}
