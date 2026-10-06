import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pickup_provider.dart';
import 'pickup_detail_screen.dart';

enum _PickupFilter { all, claimedByMe, available }

/// Screen listing active requested shipments requiring pickup in Personnel's operating hub.
class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({super.key});

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  _PickupFilter _currentFilter = _PickupFilter.all;

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(pickupQueueProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Pickup Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Queue',
            onPressed: () => ref.invalidate(pickupQueueProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CereloSpacing.pagePadding,
                vertical: CereloSpacing.sm,
              ),
              color: CereloColors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Hub Pickups',
                      isSelected: _currentFilter == _PickupFilter.all,
                      onTap: () => setState(() => _currentFilter = _PickupFilter.all),
                    ),
                    const SizedBox(width: CereloSpacing.sm),
                    _FilterChip(
                      label: 'My Active Jobs',
                      isSelected: _currentFilter == _PickupFilter.claimedByMe,
                      onTap: () =>
                          setState(() => _currentFilter = _PickupFilter.claimedByMe),
                    ),
                    const SizedBox(width: CereloSpacing.sm),
                    _FilterChip(
                      label: 'Available to Accept',
                      isSelected: _currentFilter == _PickupFilter.available,
                      onTap: () =>
                          setState(() => _currentFilter = _PickupFilter.available),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: RefreshIndicator(
                color: CereloColors.orange,
                onRefresh: () async {
                  ref.invalidate(pickupQueueProvider);
                },
                child: queueAsync.when(
                  loading: () => const Center(
                    child: CereloLoading(message: 'Loading pickup queue...'),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(CereloSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: CereloColors.error, size: 44),
                          const SizedBox(height: CereloSpacing.md),
                          const Text(
                            'Could not load pickup tasks',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CereloColors.navy,
                            ),
                          ),
                          const Text(
                            'Please check your internet connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: CereloColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: CereloSpacing.lg),
                          CereloButton(
                            label: 'Retry',
                            isFullWidth: false,
                            onPressed: () => ref.invalidate(pickupQueueProvider),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (tasks) {
                    final filteredTasks = tasks.where((t) {
                      if (_currentFilter == _PickupFilter.claimedByMe) {
                        return t.isClaimedByMe;
                      }
                      if (_currentFilter == _PickupFilter.available) {
                        return t.isAvailable;
                      }
                      return true;
                    }).toList();

                    if (filteredTasks.isEmpty) {
                      return Center(
                        child: CereloEmptyState(
                          icon: Icons.assignment_turned_in_outlined,
                          title: _currentFilter == _PickupFilter.claimedByMe
                              ? 'No active jobs claimed'
                              : 'No pickups in queue',
                          description: _currentFilter == _PickupFilter.claimedByMe
                              ? 'Claim an available pickup to start physical collection.'
                              : 'All requested shipments in your hub have been picked up.',
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(CereloSpacing.pagePadding),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return _PickupTaskCard(
                          task: task,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PickupDetailScreen(task: task),
                              ),
                            );
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
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? CereloColors.navy : CereloColors.surfaceVariant,
          borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? CereloColors.white : CereloColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PickupTaskCard extends StatelessWidget {
  const _PickupTaskCard({
    required this.task,
    required this.onTap,
  });

  final PickupTaskDto task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.white,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(
          color: task.isClaimedByMe
              ? CereloColors.navy.withOpacity(0.4)
              : CereloColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(CereloSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Route & Status Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task.routeDisplay,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: CereloColors.navy,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: task.isClaimedByMe
                          ? CereloColors.navy.withOpacity(0.12)
                          : CereloColors.orange.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(CereloSpacing.radiusSm),
                    ),
                    child: Text(
                      task.isClaimedByMe
                          ? 'CLAIMED BY YOU'
                          : 'AVAILABLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: task.isClaimedByMe
                            ? CereloColors.navy
                            : CereloColors.orangeDark,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Sender pickup address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: CereloColors.orange,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.senderPickupAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Sender name & phone
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  'Sender: ${task.senderName} (${task.senderPhone})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CereloColors.textSecondary,
                  ),
                ),
              ),

              const Divider(height: 16),

              // Footer: Size & Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: CereloColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(CereloSpacing.radiusSm),
                    ),
                    child: Text(
                      task.declaredSizeName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    task.finalPrice.formatted,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: CereloColors.orangeDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
