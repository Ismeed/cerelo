import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for [PersonnelHubService].
final personnelHubServiceProvider = Provider<PersonnelHubService>((ref) {
  return PersonnelHubService();
});

/// Provider for the list of parcels staged at the origin hub ready for batch consolidation.
final readyForBatchParcelsProvider =
    FutureProvider.autoDispose<List<ReadyForBatchParcelDto>>((ref) async {
  final service = ref.watch(personnelHubServiceProvider);
  return service.getReadyForBatchParcels();
});
