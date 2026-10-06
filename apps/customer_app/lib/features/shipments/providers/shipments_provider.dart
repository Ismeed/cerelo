import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/local/customer_local_db.dart';
import '../../auth/providers/auth_provider.dart';

/// Provider for [ShipmentService].
final shipmentServiceProvider =
    Provider<ShipmentService>((ref) => ShipmentService());

/// Provider tracking the last time shipments were successfully synced from network.
final shipmentsLastSyncedAtProvider = StateProvider<DateTime?>((ref) => null);

/// Filter state for the Shipments screen.
class ShipmentsFilterState {
  const ShipmentsFilterState({
    this.relationship = 'all',
    this.status = 'all',
    this.searchQuery = '',
  });

  /// 'all' | 'sent' | 'received'
  final String relationship;

  /// 'all' | 'active' | 'delivered'
  final String status;

  /// Text query for delivery code or counterpart name
  final String searchQuery;

  ShipmentsFilterState copyWith({
    String? relationship,
    String? status,
    String? searchQuery,
  }) {
    return ShipmentsFilterState(
      relationship: relationship ?? this.relationship,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Notifier for managing shipment list filter state.
class ShipmentsFilterNotifier extends StateNotifier<ShipmentsFilterState> {
  ShipmentsFilterNotifier() : super(const ShipmentsFilterState());

  void setRelationship(String relationship) {
    state = state.copyWith(relationship: relationship);
  }

  void setStatus(String status) {
    state = state.copyWith(status: status);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearFilters() {
    state = const ShipmentsFilterState();
  }
}

final shipmentsFilterProvider =
    StateNotifierProvider<ShipmentsFilterNotifier, ShipmentsFilterState>(
  (ref) => ShipmentsFilterNotifier(),
);

/// Provider for the filtered list of customer shipments.
///
/// LOCAL-FIRST: Attempts to fetch fresh data from Supabase and cache it in SQLite.
/// If the device is offline or the network request fails, falls back seamlessly
/// to the locally cached SQLite shipment records.
final customerShipmentsProvider =
    FutureProvider.autoDispose<List<ShipmentDto>>((ref) async {
  final service = ref.watch(shipmentServiceProvider);
  final filter = ref.watch(shipmentsFilterProvider);
  final authState = ref.watch(customerAuthProvider);
  final userId = authState.user?.id;
  final localDb = CustomerLocalDb.instance;

  if (userId == null) return [];

  // 1. Instant SQLite read (frame 0)
  final cached = await localDb.loadShipments(userId);
  if (cached.cachedAt != null) {
    ref.read(shipmentsLastSyncedAtProvider.notifier).state = cached.cachedAt;
  }
  final cachedParsed = cached.shipments.isNotEmpty
      ? cached.shipments.map((json) => ShipmentDto.fromJson(json)).toList()
      : <ShipmentDto>[];

  try {
    // 2. Fast network fetch with 3s timeout
    final liveShipments = await service.getCustomerShipments().timeout(
      const Duration(seconds: 3),
    );

    final now = DateTime.now();
    await localDb.saveShipments(
      userId: userId,
      shipments: liveShipments.map((s) => s.toJson()).toList(),
    );
    ref.read(shipmentsLastSyncedAtProvider.notifier).state = now;

    return _applyFilter(liveShipments, filter, userId);
  } catch (e) {
    // 3. Network or timeout error: return cached records immediately
    if (cachedParsed.isNotEmpty) {
      return _applyFilter(cachedParsed, filter, userId);
    }
    return [];
  }
});

List<ShipmentDto> _applyFilter(
  List<ShipmentDto> list,
  ShipmentsFilterState filter,
  String userId,
) {
  var result = list;

  if (filter.relationship == 'sent') {
    result = result.where((s) => s.senderCustomerId == userId).toList();
  } else if (filter.relationship == 'received') {
    result = result.where((s) => s.receiverCustomerId == userId).toList();
  }

  if (filter.status == 'active') {
    result = result.where((s) => s.status.isActive).toList();
  } else if (filter.status == 'delivered') {
    result = result.where((s) => s.status == ShipmentStatus.delivered).toList();
  }

  if (filter.searchQuery.trim().isNotEmpty) {
    final q = filter.searchQuery.trim().toLowerCase();
    result = result.where((s) {
      final codeMatch = s.deliveryCode?.toLowerCase().contains(q) ?? false;
      final counterpartMatch = s.counterpartName(userId).toLowerCase().contains(q);
      final routeMatch = s.routeDisplay.toLowerCase().contains(q);
      return codeMatch || counterpartMatch || routeMatch;
    }).toList();
  }

  return result;
}

/// Provider for Home screen active shipments summary.
final customerActiveShipmentsProvider =
    FutureProvider.autoDispose<List<ShipmentDto>>((ref) async {
  final shipments = await ref.watch(customerShipmentsProvider.future);
  return shipments.where((s) => s.status.isActive).toList();
});

/// Provider for Home screen recent completed shipments summary.
final customerRecentShipmentsProvider =
    FutureProvider.autoDispose<List<ShipmentDto>>((ref) async {
  final shipments = await ref.watch(customerShipmentsProvider.future);
  return shipments.where((s) => !s.status.isActive).take(3).toList();
});

/// Family provider for fetching a single shipment detail by ID.
///
/// LOCAL-FIRST: Attempts to fetch latest from server. If offline or network fails,
/// resolves from locally cached shipments in SQLite.
final shipmentDetailProvider =
    FutureProvider.autoDispose.family<ShipmentDto?, String>((ref, id) async {
  final service = ref.watch(shipmentServiceProvider);
  final authState = ref.watch(customerAuthProvider);
  final isOffline = ref.watch(isOfflineProvider);
  final userId = authState.user?.id;
  final localDb = CustomerLocalDb.instance;

  if (isOffline && userId != null) {
    final cached = await localDb.loadShipments(userId);
    final match = cached.shipments.where((j) => j['id'] == id || j['delivery_code'] == id).firstOrNull;
    if (match != null) {
      return ShipmentDto.fromJson(match);
    }
  }

  try {
    final detail = await service.getShipmentDetail(id);
    if (detail != null) return detail;
  } catch (_) {
    // Network failed, fall through to cache
  }

  if (userId != null) {
    final cached = await localDb.loadShipments(userId);
    final match = cached.shipments.where((j) => j['id'] == id || j['delivery_code'] == id).firstOrNull;
    if (match != null) {
      return ShipmentDto.fromJson(match);
    }
  }

  return null;
});

