import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/features/batches/providers/batch_provider.dart';
import 'package:personnel_app/features/batches/screens/batches_screen.dart';

class FakeBatchesService extends PersonnelBatchService {
  FakeBatchesService({this.batches = const []});

  final List<BatchSummaryDto> batches;

  @override
  Future<List<BatchSummaryDto>> getBatches({BatchStatus? status}) async {
    if (status == null) return batches;
    return batches.where((b) => b.status == status).toList();
  }
}

void main() {
  final sampleBatch = BatchSummaryDto(
    id: 'batch-screen-1',
    batchReference: 'BAT-8F2K-9P3N',
    status: BatchStatus.draft,
    corridorCode: 'KAN-KAT',
    originCity: 'Kano',
    destinationCity: 'Katsina',
    manifestParcelCount: 4,
    createdAt: DateTime.now(),
  );

  Widget createTestWidget({required FakeBatchesService service}) {
    return ProviderScope(
      overrides: [
        personnelBatchServiceProvider.overrideWithValue(service),
        // batchesListProvider short-circuits to [] when no Supabase user is
        // signed in (always true in a widget test), so the service override
        // alone never reaches the screen. Override the list it actually reads.
        batchesListProvider.overrideWith(
          (ref, status) => service.getBatches(status: status),
        ),
      ],
      child: MaterialApp(
        theme: CereloTheme.light,
        home: const BatchesScreen(),
      ),
    );
  }

  group('BatchesScreen', () {
    testWidgets('renders batches list and status filter chips', (tester) async {
      final fakeService = FakeBatchesService(batches: [sampleBatch]);

      await tester.pumpWidget(createTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Batches & Middle-Mile'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Incoming'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Ready to Depart'), findsOneWidget);
      expect(find.text('Outbound'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Create Batch'), findsOneWidget);
      expect(find.text('Receive Batch'), findsOneWidget);
      expect(find.text('Reference: BAT-8F2K-9P3N'), findsOneWidget);
      expect(find.text('4 Parcels in Manifest'), findsOneWidget);
    });
  });
}
