import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/account/screens/personnel_account_screen.dart';
import '../../features/auth/screens/personnel_login_screen.dart';
import '../../features/auth/screens/personnel_restricted_screen.dart';
import '../../features/batches/screens/batch_detail_screen.dart';
import '../../features/batches/screens/batches_screen.dart';
import '../../features/delivery/screens/delivery_queue_screen.dart';
import '../../features/delivery/screens/reconciliation_screen.dart';
import '../../features/home/screens/personnel_home_screen.dart';
import '../../features/parcels/screens/parcels_screen.dart';
import '../../features/pickup/screens/pickup_screen.dart';
import '../../features/scanner/screens/personnel_scanner_screen.dart';
import '../../features/shared/widgets/personnel_shell.dart';

abstract final class PersonnelRoutes {
  static const login = '/login';
  static const restricted = '/restricted';
  static const home = '/home';
  static const dashboard = '/home';
  static const pickup = '/pickup';
  static const parcels = '/parcels';
  static const batches = '/batches';
  static const batchDetail = '/batches/:id';
  static const reconciliation = '/reconciliation/:id';
  static const deliveries = '/deliveries';
  static const account = '/account';
  static const scan = '/scan';
}

final personnelRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(personnelAuthServiceProvider);

  return GoRouter(
    initialLocation: PersonnelRoutes.home,
    redirect: (context, state) {
      final user = authService.currentUser;
      final isGoingToLogin = state.matchedLocation == PersonnelRoutes.login;

      // UX guard — server-side authorization is authoritative.
      if (user == null && !isGoingToLogin) return PersonnelRoutes.login;

      if (user != null && isGoingToLogin) {
        return PersonnelRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: PersonnelRoutes.login,
        builder: (_, __) => const PersonnelLoginScreen(),
      ),
      GoRoute(
        path: PersonnelRoutes.restricted,
        builder: (_, __) => const PersonnelRestrictedScreen(),
      ),
      // Standalone Detail Routes (Push Navigation)
      GoRoute(
        path: PersonnelRoutes.pickup,
        builder: (_, __) => const PickupScreen(),
      ),
      GoRoute(
        path: PersonnelRoutes.parcels,
        builder: (_, __) => const ParcelsScreen(),
      ),
      GoRoute(
        path: PersonnelRoutes.batches,
        builder: (_, __) => const BatchesScreen(),
      ),
      GoRoute(
        path: PersonnelRoutes.deliveries,
        builder: (_, __) => const DeliveryQueueScreen(),
      ),
      GoRoute(
        path: PersonnelRoutes.batchDetail,
        builder: (_, state) {
          final batchId = state.pathParameters['id'] ?? '';
          return BatchDetailScreen(batchId: batchId);
        },
      ),
      GoRoute(
        path: PersonnelRoutes.reconciliation,
        builder: (_, state) {
          final batchId = state.pathParameters['id'] ?? '';
          return ReconciliationScreen(batchId: batchId);
        },
      ),
      // Simplified 3-Tab Shell Route (Home | Scan | Account)
      ShellRoute(
        builder: (context, state, child) => PersonnelShell(child: child),
        routes: [
          GoRoute(
            path: PersonnelRoutes.home,
            builder: (_, __) => const PersonnelHomeScreen(),
          ),
          GoRoute(
            path: PersonnelRoutes.scan,
            builder: (_, __) => const PersonnelScannerScreen(),
          ),
          GoRoute(
            path: PersonnelRoutes.account,
            builder: (_, __) => const PersonnelAccountScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Provider for [AuthService] scoped to the Personnel app.
final personnelAuthServiceProvider =
    Provider<AuthService>((ref) => AuthService());

