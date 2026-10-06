import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/personnel_router.dart';

/// Simplified 3-Tab App shell for authorized Cerelo Personnel field staff.
///
/// Navigation:
/// - Tab 0: Home ("Today's Work" — Pickups, Incoming, Deliveries)
/// - Tab 1: Scan (Universal QR & Code Scanner)
/// - Tab 2: Account (Profile, Hub Scope, Logout)
class PersonnelShell extends StatelessWidget {
  const PersonnelShell({super.key, required this.child});

  final Widget child;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(PersonnelRoutes.home) ||
        location.startsWith(PersonnelRoutes.pickup) ||
        location.startsWith(PersonnelRoutes.parcels) ||
        location.startsWith(PersonnelRoutes.batches) ||
        location.startsWith(PersonnelRoutes.deliveries)) {
      return 0;
    }
    if (location.startsWith(PersonnelRoutes.scan)) {
      return 1;
    }
    if (location.startsWith(PersonnelRoutes.account)) {
      return 2;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(PersonnelRoutes.home);
        break;
      case 1:
        context.go(PersonnelRoutes.scan);
        break;
      case 2:
        context.go(PersonnelRoutes.account);
        break;
    }
  }

  // SECURITY: Reads compile-time constant only — safe for client.
  static const _appEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    final scaffold = Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (idx) => _onItemTapped(idx, context),
        indicatorColor: CereloColors.orange.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: CereloColors.orange),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded, color: CereloColors.orange),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: CereloColors.orange),
            label: 'Account',
          ),
        ],
      ),
    );

    if (!kDebugMode) return scaffold;

    final (label, color) = switch (_appEnv) {
      'production' => ('PRODUCTION INTERNAL TEST', Colors.deepOrange.shade700),
      'staging' => ('STAGING', Colors.teal.shade600),
      _ => ('DEV', Colors.purple.shade600),
    };

    return Banner(
      message: label,
      location: BannerLocation.topEnd,
      color: color,
      child: scaffold,
    );
  }
}

