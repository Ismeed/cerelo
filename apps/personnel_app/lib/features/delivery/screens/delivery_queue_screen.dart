import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/delivery_provider.dart';
import 'delivery_detail_screen.dart';

/// Screen listing destination final-mile doorstep delivery tasks.
class DeliveryQueueScreen extends ConsumerWidget {
  const DeliveryQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(readyForDeliveryQueueProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Doorstep Deliveries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(readyForDeliveryQueueProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: CereloColors.orange,
          onRefresh: () async {
            ref.invalidate(readyForDeliveryQueueProvider);
          },
          child: queueAsync.when(
            loading: () => const Center(
              child: CereloLoading(message: 'Loading delivery tasks...'),
            ),
            error: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(CereloSpacing.md),
                child: Text(
                  'Could not load delivery tasks. Please check your internet connection.',
                  style: TextStyle(fontSize: 13, color: CereloColors.textSecondary),
                ),
              ),
            ),
            data: (tasks) {
              if (tasks.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(CereloSpacing.xl),
                    child: CereloEmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'No pending deliveries',
                      description:
                          'Reconcile arrived batches at the destination hub to populate final-mile delivery tasks.',
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(CereloSpacing.pagePadding),
                itemCount: tasks.length,
                itemBuilder: (ctx, i) {
                  final task = tasks[i];
                  return _DeliveryTaskCard(
                    task: task,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DeliveryDetailScreen(task: task),
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
    );
  }
}

class _DeliveryTaskCard extends StatelessWidget {
  const _DeliveryTaskCard({required this.task, required this.onTap});

  final DeliveryTaskDto task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOutForDelivery = task.status == ShipmentStatus.outForDelivery;

    return Container(
      margin: const EdgeInsets.only(bottom: CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.white,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(CereloSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task.receiverName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: CereloColors.navy,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOutForDelivery
                          ? CereloColors.info.withOpacity(0.12)
                          : CereloColors.success.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(CereloSpacing.radiusSm),
                    ),
                    child: Text(
                      isOutForDelivery
                          ? 'OUT FOR DELIVERY'
                          : 'READY FOR DELIVERY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isOutForDelivery
                            ? CereloColors.info
                            : CereloColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                task.receiverDeliveryAddress,
                style: const TextStyle(
                  fontSize: 12,
                  color: CereloColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.requiresReceiverPayment
                            ? 'Collect: ${task.receiverDueAmount.formatted}'
                            : 'No payment due (Paid)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: task.requiresReceiverPayment
                              ? CereloColors.orangeDark
                              : CereloColors.success,
                        ),
                      ),
                      Text(
                        'Code: ${task.deliveryCode}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: CereloColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        isOutForDelivery ? 'Deliver' : 'Start Delivery',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOutForDelivery
                              ? CereloColors.orangeDark
                              : CereloColors.navy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 16),
                    ],
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
