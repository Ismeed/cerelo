import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

/// Main application shell with bottom navigation.
///
/// Three tabs: Home | Shipments | Account
///
/// PRODUCT RULE (LOCKED): Do NOT add Wallet, Marketplace, Tracking tab,
/// Notifications tab, Rewards tab, or Courier tab.
/// See docs/CERELO_V1_REQUIREMENTS_FREEZE.md for approved navigation structure.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    (path: AppRoutes.home, label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    (path: AppRoutes.shipments, label: 'Shipments', icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping_rounded),
    (path: AppRoutes.account, label: 'Account', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
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
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          context.go(_tabs[index].path);
        },
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
