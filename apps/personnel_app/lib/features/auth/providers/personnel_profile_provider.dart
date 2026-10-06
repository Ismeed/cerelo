import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local/personnel_local_db.dart';
import '../../parcels/providers/hub_provider.dart';

/// Provider for current authenticated Personnel profile and authorization status.
///
/// LOCAL-FIRST: Attempts to fetch fresh profile from server and save to SQLite.
/// If offline or network request fails, loads from locally cached SQLite record.
final personnelProfileProvider =
    FutureProvider.autoDispose<PersonnelProfileDto>((ref) async {
  final hubService = ref.watch(personnelHubServiceProvider);
  final client = CereloSupabaseClient.instance;
  final currentUserId = client.auth.currentUser?.id;
  final localDb = PersonnelLocalDb.instance;

  if (currentUserId == null) {
    return PersonnelProfileDto.unauthorized('UNAUTHENTICATED');
  }

  // 1. Instant SQLite read (frame 0)
  final cached = await localDb.loadProfile(currentUserId);
  final cachedDto = cached != null ? PersonnelProfileDto.fromJson(cached) : null;

  // 2. Fast network fetch with 3s timeout
  try {
    final live = await hubService.getCurrentPersonnelProfile().timeout(
      const Duration(seconds: 3),
    );
    if (live.isAuthorized) {
      await localDb.saveProfile(
        userId: currentUserId,
        profileJson: live.toJson(),
      );
    }
    return live;
  } catch (e) {
    // 3. If network fails or times out, return cached profile immediately
    if (cachedDto != null) {
      return cachedDto;
    }
    rethrow;
  }
});
