import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/personnel_router.dart';

/// Personnel app navigation shell.
///
/// Operational tabs: Dashboard | Pickup | Batches | Delivery
///
/// PRODUCT RULE (LOCKED): Do NOT add Wallet, Marketplace, Live Map, or GPS
/// tracking tabs. See docs/CERELO_V1_REQUIREMENTS_FREEZE.md.
class PersonnelShell extends StatelessWidget {
  const PersonnelShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    (
      path: PersonnelRoutes.dashboard,
      label: 'Dashboard',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded
    ),
    (
      path: PersonnelRoutes.pickup,
      label: 'Pickup',
      icon: Icons.handshake_outlined,
      activeIcon: Icons.handshake_rounded
    ),
    (
      path: PersonnelRoutes.batches,
      label: 'Batches',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded
    ),
    (
      path: PersonnelRoutes.deliveries,
      label: 'Delivery',
      icon: Icons.delivery_dining_outlined,
      activeIcon: Icons.delivery_dining_rounded
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => t.path == location);
    final activeIndex = currentIndex < 0 ? 0 : currentIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeIndex,
        backgroundColor: CereloColors.white,
        indicatorColor: CereloColors.navy.withAlpha(20),
        onDestinationSelected: (index) => context.go(_tabs[index].path),
        destinations: _tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon, color: CereloColors.textTertiary),
                selectedIcon: Icon(tab.activeIcon, color: CereloColors.navy),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
