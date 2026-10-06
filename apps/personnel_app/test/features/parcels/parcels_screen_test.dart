import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/features/parcels/providers/hub_provider.dart';
import 'package:personnel_app/features/parcels/screens/parcels_screen.dart';

import 'hub_processing_test.dart';

void main() {
  final sampleStagedParcel = ReadyForBatchParcelDto(
    parcelId: 'parcel-staged-1',
    shipmentId: 'shipment-staged-1',
    deliveryCode: 'CRL-8F2K-9P3N',
    parcelQrToken: 'PQR-7K9A-3M2P-9Q4W',
    originCity: 'Kano',
    destinationCity: 'Katsina',
    confirmedSizeCode: 'MEDIUM',
    confirmedSizeName: 'Medium Package',
    categoryDescription: 'Ankara Fabrics',
    createdAt: DateTime.now(),
  );

  Widget createTestWidget({required FakePersonnelHubService service}) {
    return ProviderScope(
      overrides: [
        personnelHubServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: const ParcelsScreen(),
      ),
    );
  }

  group('ParcelsScreen', () {
    testWidgets('renders ready-for-batch staged parcels list', (tester) async {
      final fakeService = FakePersonnelHubService(
        readyParcels: [sampleStagedParcel],
      );

      await tester.pumpWidget(createTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Parcels in Custody'), findsOneWidget);
      expect(find.text('Receive Inbound Parcel'), findsOneWidget);
      expect(find.text('Ready for Batch Consolidation'), findsOneWidget);
      expect(find.text('1 READY'), findsOneWidget);
      expect(find.text('Kano → Katsina'), findsOneWidget);
      expect(find.text('Medium Package'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);
    });
  });
}
