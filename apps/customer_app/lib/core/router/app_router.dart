import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/account/screens/account_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/email_auth_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/onboarding/screens/account_type_screen.dart';
import '../../features/onboarding/screens/business_name_screen.dart';
import '../../features/send_package/screens/send_package_screen.dart';
import '../../features/send_package/screens/send_package_success_screen.dart';
import '../../features/shipments/screens/shared_shipment_screen.dart';
import '../../features/shipments/screens/shipment_details_screen.dart';
import '../../features/shipments/screens/shipments_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../shell/main_shell.dart';

/// Customer app route paths.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const emailAuth = '/login/email';
  static const onboarding = '/onboarding';
  static const onboardingBusinessName = '/onboarding/business-name';
  static const home = '/home';
  static const shipments = '/shipments';
  static const shipmentDetails = '/shipments/:id';
  static const sharedShipment = '/s/:token';
  static const track = '/track/:code';
  static const trackBase = '/track';
  static const account = '/account';
  static const sendPackage = '/send-package';
  static const sendPackageSuccess = '/send-package/success';
}

/// Provider for the [GoRouter] instance.
///
/// Reacts to changes in [customerAuthProvider] to route deterministically between:
/// - Splash / Startup
/// - Authentication (Login / Email)
/// - Onboarding (Account Type / Business Name)
/// - Main App (Home / Shipments / Account)
/// - Secondary Flows (Send Package / Shipment Details / Shared Link)
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(customerAuthProvider);
      final status = authState.status;
      final location = state.matchedLocation;

      final isSplash = location == AppRoutes.splash;
      final isAuthRoute =
          location == AppRoutes.login || location == AppRoutes.emailAuth;
      final isOnboardingRoute = location == AppRoutes.onboarding ||
          location == AppRoutes.onboardingBusinessName;
      final isSharedRoute =
          location.startsWith('/s/') || location.startsWith('/track');

      // 1. Allow shared tracking link resolution without auth redirection
      if (isSharedRoute) {
        return null;
      }

      // 2. Initial startup / session resolving
      if (status == CustomerAuthStatus.initial ||
          (status == CustomerAuthStatus.loading && !authState.isAuthenticated)) {
        if (!isSplash) return AppRoutes.splash;
        return null;
      }

      // 3. Unauthenticated -> force login entry
      if (status == CustomerAuthStatus.unauthenticated) {
        if (!isAuthRoute) return AppRoutes.login;
        return null;
      }

      // 4. Authenticated but onboarding incomplete -> force onboarding flow
      if (status == CustomerAuthStatus.authenticatedIncomplete) {
        if (!isOnboardingRoute) return AppRoutes.onboarding;
        return null;
      }

      // 5. Authenticated & onboarding complete -> land on Home
      if (status == CustomerAuthStatus.authenticatedComplete) {
        if (isSplash || isAuthRoute || isOnboardingRoute) {
          return AppRoutes.home;
        }
        return null;
      }

      // 6. Error during profile load -> stay on splash to allow retry
      if (status == CustomerAuthStatus.error) {
        if (!isSplash && !isAuthRoute) return AppRoutes.splash;
        return null;
      }

      return null;
    },
    routes: [
      // Splash / Session Resolution
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      // Auth Entry
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailAuth,
        builder: (_, __) => const EmailAuthScreen(),
      ),

      // Onboarding Flow
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const AccountTypeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingBusinessName,
        builder: (context, state) {
          final fullName = state.extra as String?;
          return BusinessNameScreen(fullName: fullName);
        },
      ),

      // Secondary Flow: Send a Package (Entry from Home CTA)
      GoRoute(
        path: AppRoutes.sendPackage,
        builder: (_, __) => const SendPackageScreen(),
      ),

      // Secondary Flow: Send a Package — Success confirmation screen.
      // ShipmentDto is passed via state.extra after a successful server submission.
      GoRoute(
        path: AppRoutes.sendPackageSuccess,
        builder: (context, state) {
          final shipment = state.extra as ShipmentDto?;
          if (shipment == null) {
            // Guard: should not be reached without data — redirect to Home.
            return const SizedBox.shrink();
          }
          return SendPackageSuccessScreen(shipment: shipment);
        },
      ),

      // Secondary Flow: Shared Tracking Link (Public / Restricted)
      GoRoute(
        path: AppRoutes.sharedShipment,
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return SharedShipmentScreen(token: token);
        },
      ),

      // Secondary Flow: Public Delivery Code Tracking Link
      GoRoute(
        path: AppRoutes.track,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return SharedShipmentScreen(token: code);
        },
      ),
      GoRoute(
        path: AppRoutes.trackBase,
        builder: (context, state) {
          final code = state.uri.queryParameters['code'] ??
              state.uri.queryParameters['token'] ??
              '';
          return SharedShipmentScreen(token: code);
        },
      ),

      // Secondary Flow: Shipment Details
      GoRoute(
        path: AppRoutes.shipmentDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ShipmentDetailsScreen(shipmentId: id);
        },
      ),

      // Authenticated App Shell (Home, Shipments, Account)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.shipments,
            builder: (_, __) => const ShipmentsScreen(),
          ),
          GoRoute(
            path: AppRoutes.account,
            builder: (_, __) => const AccountScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Listenable adapter that triggers GoRouter redirect when CustomerAuthState changes.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<CustomerAuthState>(customerAuthProvider, (_, __) {
      notifyListeners();
    });
  }
}
