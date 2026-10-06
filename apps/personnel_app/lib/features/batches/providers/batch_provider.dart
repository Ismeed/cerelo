import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local/personnel_local_db.dart';

/// Provider for [PersonnelBatchService].
final personnelBatchServiceProvider = Provider<PersonnelBatchService>((ref) {
  return PersonnelBatchService();
});

/// Provider for active corridors between operating hubs.
final activeCorridorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = CereloSupabaseClient.instance;
  try {
    final response = await client
        .from('corridors')
        .select('id, code, origin_hub_id, destination_hub_id')
        .eq('is_active', true);
    return (response as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});


/// Provider for list of batches filtered optionally by lifecycle state.
///
/// LOCAL-FIRST: Caches batch list in SQLite.
/// If offline or network error occurs, seamlessly falls back to cached batches.
final batchesListProvider =
    FutureProvider.family.autoDispose<List<BatchSummaryDto>, BatchStatus?>(
  (ref, status) async {
  final service = ref.watch(personnelBatchServiceProvider);
  final client = CereloSupabaseClient.instance;
  final currentUserId = client.auth.currentUser?.id;
  final localDb = PersonnelLocalDb.instance;

  if (currentUserId == null) return [];

  // 1. Instant SQLite read (frame 0)
  final cached = await localDb.loadBatches(currentUserId);
  final cachedList = cached.batches.isNotEmpty
      ? cached.batches.map((j) => BatchSummaryDto.fromJson(j)).toList()
      : <BatchSummaryDto>[];
  final filteredCached = status != null
      ? cachedList.where((b) => b.status == status).toList()
      : cachedList;

  // 2. Fast network fetch with 3s timeout
  try {
    final liveBatches = await service.getBatches(status: status).timeout(
      const Duration(seconds: 3),
    );
    if (status == null) {
      await localDb.saveBatches(
        userId: currentUserId,
        batches: liveBatches.map((b) => b.toJson()).toList(),
      );
    }
    return liveBatches;
  } catch (e) {
    // 3. If network fails or times out, return cached batches immediately
    return filteredCached;
  }
  },
);

/// Provider for full manifest details of a specific Batch.
final batchManifestProvider =
    FutureProvider.family.autoDispose<BatchManifestDto?, String>(
  (ref, batchId) async {
    final service = ref.watch(personnelBatchServiceProvider);
    return service.getBatchManifest(batchId);
  },
);
