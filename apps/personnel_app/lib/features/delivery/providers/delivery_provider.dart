import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local/personnel_local_db.dart';

/// Provider for [PersonnelDeliveryService].
final personnelDeliveryServiceProvider = Provider<PersonnelDeliveryService>((ref) {
  return PersonnelDeliveryService();
});

/// Provider for the destination ready-for-delivery work queue.
///
/// LOCAL-FIRST: Caches delivery queue in SQLite.
/// If offline or network error occurs, seamlessly falls back to cached deliveries.
final readyForDeliveryQueueProvider =
    FutureProvider.autoDispose<List<DeliveryTaskDto>>((ref) async {
  final service = ref.watch(personnelDeliveryServiceProvider);
  final client = CereloSupabaseClient.instance;
  final currentUserId = client.auth.currentUser?.id;
  final localDb = PersonnelLocalDb.instance;

  if (currentUserId == null) return [];

  // 1. Instant SQLite read (frame 0)
  final cached = await localDb.loadDeliveries(currentUserId);
  final cachedList = cached.deliveries.isNotEmpty
      ? cached.deliveries.map((j) => DeliveryTaskDto.fromJson(j)).toList()
      : <DeliveryTaskDto>[];

  // 2. Fast network fetch with 3s timeout
  try {
    final liveQueue = await service.getReadyForDeliveryQueue().timeout(
      const Duration(seconds: 3),
    );
    await localDb.saveDeliveries(
      userId: currentUserId,
      deliveries: liveQueue.map((d) => d.toJson()).toList(),
    );
    return liveQueue;
  } catch (e) {
    // 3. If network fails or times out, return cached deliveries immediately
    return cachedList;
  }
});
