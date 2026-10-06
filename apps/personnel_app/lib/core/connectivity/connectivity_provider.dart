import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides current network connectivity state in the Personnel App.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  return connectivity.onConnectivityChanged.map(
    (results) => results.every((r) => r == ConnectivityResult.none),
  );
});

/// Convenience provider: true if device is currently offline.
final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.maybeWhen(
    data: (offline) => offline,
    orElse: () => false,
  );
});
