import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shipments/providers/shipments_provider.dart';
import '../../shipments/widgets/shipment_card.dart';
import '../widgets/corridor_badge.dart';
import '../widgets/send_package_card.dart';

/// Customer Home Screen — the primary landing surface of the Cerelo App.
///
/// Minimal, fast, and actionable:
/// 1. Greeting & Corridor Context
/// 2. Primary "Send a Package" CTA
/// 3. Active Shipments Overview
/// 4. Recent Shipments / Honest Empty States
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greetingText(String fullName) {
    final hour = DateTime.now().hour;
    String period;
    if (hour < 12) {
      period = 'Good morning';
    } else if (hour < 17) {
      period = 'Good afternoon';
    } else {
      period = 'Good evening';
    }

    final firstName = fullName.trim().split(' ').first;
    if (firstName.isNotEmpty && firstName != 'Customer') {
      return '$period, $firstName';
    }
    return 'Welcome to Cerelo';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(customerAuthProvider);
    final profile = authState.profile;
    final fullName = profile?.fullName ?? 'Customer';
    final currentUserId = authState.user?.id;
    final isOffline = ref.watch(isOfflineProvider);

    final activeShipmentsAsync = ref.watch(customerActiveShipmentsProvider);
    final recentShipmentsAsync = ref.watch(customerRecentShipmentsProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: CereloColors.orange,
          onRefresh: () async {
            ref.invalidate(customerShipmentsProvider);
            ref.invalidate(customerActiveShipmentsProvider);
            ref.invalidate(customerRecentShipmentsProvider);
            await ref.read(customerAuthProvider.notifier).retryProfileResolution();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: CereloSpacing.pagePadding,
              vertical: CereloSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOffline) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CereloSpacing.md,
                      vertical: 6,
                    ),
                    margin: const EdgeInsets.only(bottom: CereloSpacing.md),
                    decoration: BoxDecoration(
                      color: CereloColors.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 14,
                          color: CereloColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Offline · Showing saved information',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CereloColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Header Row: Greeting & Brand Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingText(fullName),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: CereloColors.navy,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Kano ↔ Katsina Logistics',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: CereloColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.account),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: CereloColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: CereloSpacing.md),

                // Corridor Badge
                const CorridorBadge(),

                const SizedBox(height: CereloSpacing.lg),

                // Dominant Send a Package CTA
                SendPackageCtaCard(
                  onTap: () {
                    context.push(AppRoutes.sendPackage);
                  },
                ),

                const SizedBox(height: 32),

                // Section 1: Active Shipments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Shipments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.navy,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.shipments),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CereloColors.orangeDark,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: CereloSpacing.sm),

                activeShipmentsAsync.when(
                  loading: () => const CereloLoading(message: 'Loading shipments...'),
                  error: (err, _) => Container(
                    padding: const EdgeInsets.all(CereloSpacing.md),
                    decoration: BoxDecoration(
                      color: CereloColors.white,
                      borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                      border: Border.all(color: CereloColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: CereloColors.textTertiary, size: 20),
                        const SizedBox(width: CereloSpacing.sm),
                        const Expanded(
                          child: Text(
                            'Could not refresh active shipments.',
                            style: TextStyle(fontSize: 13, color: CereloColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(customerActiveShipmentsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (activeList) {
                    if (activeList.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(CereloSpacing.lg),
                        decoration: BoxDecoration(
                          color: CereloColors.white,
                          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                          border: Border.all(color: CereloColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CereloColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                              ),
                              child: const Icon(
                                Icons.inbox_outlined,
                                color: CereloColors.textTertiary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: CereloSpacing.md),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No active shipments in transit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: CereloColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'New packages will show live status here.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CereloColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: activeList.map((s) {
                        return ShipmentCard(
                          shipment: s,
                          currentUserId: currentUserId,
                          isCompact: true,
                          onTap: () {
                            context.push('/shipments/${s.id}');
                          },
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Section 2: Recent Shipments (only if present)
                recentShipmentsAsync.maybeWhen(
                  data: (recentList) {
                    if (recentList.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Deliveries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CereloColors.navy,
                          ),
                        ),
                        const SizedBox(height: CereloSpacing.sm),
                        ...recentList.map((s) {
                          return ShipmentCard(
                            shipment: s,
                            currentUserId: currentUserId,
                            isCompact: true,
                            onTap: () {
                              context.push('/shipments/${s.id}');
                            },
                          );
                        }),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
