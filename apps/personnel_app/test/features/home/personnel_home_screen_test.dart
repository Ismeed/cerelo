import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personnel_app/core/connectivity/connectivity_provider.dart';
import 'package:personnel_app/features/auth/providers/personnel_profile_provider.dart';
import 'package:personnel_app/features/batches/providers/batch_provider.dart';
import 'package:personnel_app/features/delivery/providers/delivery_provider.dart';
import 'package:personnel_app/features/home/screens/personnel_home_screen.dart';
import 'package:personnel_app/features/parcels/providers/hub_provider.dart';
import 'package:personnel_app/features/pickup/providers/pickup_provider.dart';

const _kanHub = 'hub-kan-01';
const _katHub = 'hub-kat-01';

BatchSummaryDto _batch({
  required String id,
  required BatchStatus status,
  required String origin,
  required String destination,
  required String originCity,
  required String destinationCity,
  int parcels = 1,
}) =>
    BatchSummaryDto(
      id: id,
      status: status,
      corridorCode: 'KAN-KAT',
      originCity: originCity,
      destinationCity: destinationCity,
      originHubId: origin,
      destinationHubId: destination,
      manifestParcelCount: parcels,
      createdAt: DateTime(2026, 9, 27),
    );

Widget _home({
  required List<BatchSummaryDto> batches,
  Future<List<ReadyForBatchParcelDto>> Function()? parcels,
}) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWithValue(false),
      personnelProfileProvider.overrideWith(
        (ref) async => const PersonnelProfileDto(
          isAuthorized: true,
          isActive: true,
          fullName: 'Test Kano Staff',
          operatingHubId: _kanHub,
          hubCode: 'KAN-HUB-01',
          hubName: 'Kano Central Hub',
        ),
      ),
      pickupQueueProvider.overrideWith((ref) async => const <PickupTaskDto>[]),
      readyForDeliveryQueueProvider
          .overrideWith((ref) async => const <DeliveryTaskDto>[]),
      batchesListProvider.overrideWith((ref, status) async => batches),
      readyForBatchParcelsProvider.overrideWith(
        (ref) => parcels != null ? parcels() : Future.value(const []),
      ),
    ],
    child: MaterialApp(
      theme: CereloTheme.light,
      home: const PersonnelHomeScreen(),
    ),
  );
}

void main() {
  group('PersonnelHomeScreen — trip direction', () {
    testWidgets(
        'origin staff never see their own departed batch as an incoming trip',
        (tester) async {
      await tester.pumpWidget(_home(batches: [
        // Departed FROM Kano: outbound for this staffer, not incoming.
        _batch(
          id: 'out-1',
          status: BatchStatus.onboarded,
          origin: _kanHub,
          destination: _katHub,
          originCity: 'Kano',
          destinationCity: 'Katsina',
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Receive Trip'), findsNothing);
      expect(find.text('Kano → Katsina'), findsNothing);
      expect(
        find.text('No vehicles en route to your hub — trips appear here once they depart.'),
        findsOneWidget,
      );
    });

    testWidgets('a trip bound for this hub is offered for physical receipt',
        (tester) async {
      await tester.pumpWidget(_home(batches: [
        _batch(
          id: 'in-1',
          status: BatchStatus.onboarded,
          origin: _katHub,
          destination: _kanHub,
          originCity: 'Katsina',
          destinationCity: 'Kano',
          parcels: 2,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Katsina → Kano'), findsOneWidget);
      expect(find.text('2 Parcels en route'), findsOneWidget);
      expect(find.text('Receive Trip'), findsOneWidget);
    });

    testWidgets('an already-received trip asks for checking, not receiving again',
        (tester) async {
      await tester.pumpWidget(_home(batches: [
        _batch(
          id: 'in-2',
          status: BatchStatus.destinationReceived,
          origin: _katHub,
          destination: _kanHub,
          originCity: 'Katsina',
          destinationCity: 'Kano',
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('1 Parcel to check'), findsOneWidget);
      expect(find.text('Check Parcels'), findsOneWidget);
      expect(find.text('Receive Trip'), findsNothing);
    });
  });

  group('PersonnelHomeScreen — hub operations entry points', () {
    testWidgets('parcel staging and outbound batches are always reachable',
        (tester) async {
      await tester.pumpWidget(_home(batches: const []));
      await tester.pumpAndSettle();

      expect(find.text('Hub Operations'), findsOneWidget);
      expect(find.text('Parcels in custody'), findsOneWidget);
      expect(find.text('Outbound batches'), findsOneWidget);
    });

    testWidgets('outbound count includes only this hub’s undeparted batches',
        (tester) async {
      await tester.pumpWidget(_home(batches: [
        _batch(id: 'd1', status: BatchStatus.draft, origin: _kanHub,
            destination: _katHub, originCity: 'Kano', destinationCity: 'Katsina'),
        _batch(id: 'c1', status: BatchStatus.confirmed, origin: _kanHub,
            destination: _katHub, originCity: 'Kano', destinationCity: 'Katsina'),
        // Already departed: no longer pending origin work.
        _batch(id: 'o1', status: BatchStatus.onboarded, origin: _kanHub,
            destination: _katHub, originCity: 'Kano', destinationCity: 'Katsina'),
        // Another hub's draft: not this staffer's work.
        _batch(id: 'd2', status: BatchStatus.draft, origin: _katHub,
            destination: _kanHub, originCity: 'Katsina', destinationCity: 'Kano'),
      ]));
      await tester.pumpAndSettle();

      final outboundRow = find.ancestor(
        of: find.text('Outbound batches'),
        matching: find.byType(CereloCard),
      );
      expect(
        find.descendant(of: outboundRow, matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('a failed parcel count reads as an error, never as zero',
        (tester) async {
      await tester.pumpWidget(_home(
        batches: const [],
        parcels: () => Future.error(Exception('network down')),
      ));
      await tester.pumpAndSettle();

      final parcelsRow = find.ancestor(
        of: find.text('Parcels in custody'),
        matching: find.byType(CereloCard),
      );
      expect(
        find.descendant(of: parcelsRow, matching: find.text("Couldn't load")),
        findsOneWidget,
      );
      expect(
        find.descendant(of: parcelsRow, matching: find.text('0')),
        findsNothing,
      );
    });
  });
}
