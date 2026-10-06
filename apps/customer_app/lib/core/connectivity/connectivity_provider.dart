import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current network connectivity state.
///
/// Returns true when no network interface is available.
/// UI should read this to show offline banners and adjust refresh behaviour.
///
/// Uses connectivity_plus which is already a declared dependency.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  // Map connectivity results to isOffline bool
  return connectivity.onConnectivityChanged.map(
    (results) => results.every((r) => r == ConnectivityResult.none),
  );
});

/// Convenience provider: true if the device is currently offline.
final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  // Default to false (online) while status is loading — avoids false offline banners
  return connectivity.maybeWhen(
    data: (offline) => offline,
    orElse: () => false,
  );
});
