import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/shipments_provider.dart';
import '../widgets/shipment_card.dart';

/// Customer Shipments History & Status Screen.
///
/// Supports:
/// - Distinguishing Sent vs Received shipments in the same account
/// - Search by Delivery Code or counterpart name
/// - Status filtering (All, In Transit, Delivered)
/// - Pull-to-refresh with offline resilience
class ShipmentsScreen extends ConsumerStatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  ConsumerState<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends ConsumerState<ShipmentsScreen> {
  final _searchController = TextEditingController();

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(customerAuthProvider);
    final currentUserId = authState.user?.id;

    final isOffline = ref.watch(isOfflineProvider);
    final lastSyncedAt = ref.watch(shipmentsLastSyncedAtProvider);

    final filterState = ref.watch(shipmentsFilterProvider);
    final filterNotifier = ref.read(shipmentsFilterProvider.notifier);
    final shipmentsAsync = ref.watch(customerShipmentsProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('My Shipments'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Subtle Offline / Synced Banner
            if (isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: CereloSpacing.md,
                  vertical: 6,
                ),
                color: CereloColors.navy.withOpacity(0.08),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 14,
                      color: CereloColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lastSyncedAt != null
                          ? 'Offline · Showing last update (${_formatTime(lastSyncedAt)})'
                          : 'Offline · Showing saved information',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Search & Filter Header
            Container(
              color: CereloColors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: CereloSpacing.pagePadding,
                vertical: CereloSpacing.sm,
              ),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => filterNotifier.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Search Delivery Code or Name...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: CereloColors.textTertiary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: CereloColors.textTertiary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                filterNotifier.setSearchQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: CereloSpacing.md,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: CereloColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: CereloSpacing.sm),

                  // Relationship Segment Filter (All | Sent | Received)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: CereloColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(CereloSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        _FilterTab(
                          label: 'All',
                          isSelected: filterState.relationship == 'all',
                          onTap: () => filterNotifier.setRelationship('all'),
                        ),
                        _FilterTab(
                          label: 'Parcels Sent',
                          isSelected: filterState.relationship == 'sent',
                          onTap: () => filterNotifier.setRelationship('sent'),
                        ),
                        _FilterTab(
                          label: 'Parcels Received',
                          isSelected: filterState.relationship == 'received',
                          onTap: () =>
                              filterNotifier.setRelationship('received'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: CereloSpacing.xs),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusChip(
                          label: 'All Statuses',
                          isSelected: filterState.status == 'all',
                          onTap: () => filterNotifier.setStatus('all'),
                        ),
                        const SizedBox(width: CereloSpacing.xs),
                        _StatusChip(
                          label: 'In Transit',
                          isSelected: filterState.status == 'active',
                          onTap: () => filterNotifier.setStatus('active'),
                        ),
                        const SizedBox(width: CereloSpacing.xs),
                        _StatusChip(
                          label: 'Delivered',
                          isSelected: filterState.status == 'delivered',
                          onTap: () => filterNotifier.setStatus('delivered'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Shipment List Content
            Expanded(
              child: RefreshIndicator(
                color: CereloColors.orange,
                onRefresh: () async {
                  ref.invalidate(customerShipmentsProvider);
                },
                child: shipmentsAsync.when(
                  loading: () => const Center(
                    child: CereloLoading(message: 'Loading shipments...'),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(CereloSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: CereloColors.error,
                            size: 40,
                          ),
                          const SizedBox(height: CereloSpacing.md),
                          const Text(
                            'Failed to load shipments',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CereloColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please check your internet connection and try again.',
                            style: TextStyle(
                              fontSize: 13,
                              color: CereloColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: CereloSpacing.lg),
                          CereloButton(
                            label: 'Retry',
                            variant: CereloButtonVariant.primary,
                            isFullWidth: false,
                            onPressed: () =>
                                ref.invalidate(customerShipmentsProvider),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (shipments) {
                    if (shipments.isEmpty) {
                      return _buildEmptyState(context, filterState);
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(CereloSpacing.pagePadding),
                      itemCount: shipments.length,
                      itemBuilder: (context, index) {
                        final shipment = shipments[index];
                        return ShipmentCard(
                          shipment: shipment,
                          currentUserId: currentUserId,
                          onTap: () {
                            context.push('/shipments/${shipment.id}');
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ShipmentsFilterState filter,
  ) {
    if (filter.searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CereloSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: CereloColors.textTertiary,
              ),
              const SizedBox(height: CereloSpacing.md),
              Text(
                'No shipments matching "${filter.searchQuery}"',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CereloColors.navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Check the spelling or try searching by Delivery Code.',
                style: TextStyle(
                  fontSize: 13,
                  color: CereloColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CereloSpacing.lg),
              CereloButton(
                label: 'Clear Search',
                variant: CereloButtonVariant.outlined,
                isFullWidth: false,
                onPressed: () {
                  _searchController.clear();
                  ref.read(shipmentsFilterProvider.notifier).setSearchQuery('');
                },
              ),
            ],
          ),
        ),
      );
    }

    if (filter.relationship == 'sent') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CereloSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.outbox_rounded,
                size: 48,
                color: CereloColors.textTertiary,
              ),
              const SizedBox(height: CereloSpacing.md),
              const Text(
                'No parcels sent yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CereloColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Send your first package between Kano and Katsina with doorstep delivery.',
                style: TextStyle(
                  fontSize: 13,
                  color: CereloColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CereloSpacing.lg),
              CereloButton(
                label: 'Send a Package',
                isFullWidth: false,
                onPressed: () => context.push(AppRoutes.sendPackage),
              ),
            ],
          ),
        ),
      );
    }

    if (filter.relationship == 'received') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(CereloSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.move_to_inbox_rounded,
                size: 48,
                color: CereloColors.textTertiary,
              ),
              SizedBox(height: CereloSpacing.md),
              Text(
                'No parcels received yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CereloColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'When someone sends a package to your phone number, it will automatically appear here.',
                style: TextStyle(
                  fontSize: 13,
                  color: CereloColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Default "All" empty state
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CereloSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: CereloColors.textTertiary,
            ),
            const SizedBox(height: CereloSpacing.md),
            const Text(
              'No shipments yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your sent and incoming deliveries on the Kano ↔ Katsina corridor will be tracked here.',
              style: TextStyle(
                fontSize: 13,
                color: CereloColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CereloSpacing.lg),
            CereloButton(
              label: 'Send a Package',
              isFullWidth: false,
              onPressed: () => context.push(AppRoutes.sendPackage),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? CereloColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color:
                  isSelected ? CereloColors.navy : CereloColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CereloSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? CereloColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
          border: Border.all(
            color: isSelected ? CereloColors.navy : CereloColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : CereloColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
