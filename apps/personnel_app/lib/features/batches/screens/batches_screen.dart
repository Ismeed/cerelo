import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/personnel_profile_provider.dart';
import '../../delivery/screens/reconciliation_screen.dart';
import '../providers/batch_provider.dart';
import '../widgets/batch_receive_sheet.dart';
import '../widgets/inbound_transport_detail_sheet.dart';
import 'batch_detail_screen.dart';

enum BatchTabFilter {
  all,
  incoming,
  drafts,
  readyToDepart,
  outbound,
  received,
}

/// Operational Batches & Middle-Mile hub terminal screen.
///
/// Clear directional separation:
/// - Outbound creation and middle-mile departure from current hub.
/// - Inbound batch discovery, arrival confirmation, and destination reconciliation.
class BatchesScreen extends ConsumerStatefulWidget {
  const BatchesScreen({super.key});

  @override
  ConsumerState<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends ConsumerState<BatchesScreen> {
  BatchTabFilter _currentFilter = BatchTabFilter.all;

  void _showCreateBatchModal() {
    final profile = ref.read(personnelProfileProvider).value;
    final corridors = ref.read(activeCorridorsProvider).value ?? [];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (ctx) {
        final userHubId = profile?.operatingHubId;
        final availableCorridors = userHubId != null
            ? corridors.where((c) => c['origin_hub_id'] == userHubId).toList()
            : corridors;

        return Padding(
          padding: const EdgeInsets.all(CereloSpacing.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create New Outbound Batch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: CereloColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile?.hubName != null
                    ? 'Origin Hub: ${profile!.hubName} (${profile.hubCode})'
                    : 'Select intercity corridor for this consolidation movement.',
                style: const TextStyle(
                  fontSize: 12,
                  color: CereloColors.textSecondary,
                ),
              ),
              const SizedBox(height: CereloSpacing.md),
              if (availableCorridors.isEmpty) ...[
                _CorridorTile(
                  title: profile?.hubCode == 'KAT-HUB-01'
                      ? 'Katsina Central Hub → Kano Central Hub'
                      : 'Kano Central Hub → Katsina Central Hub',
                  subtitle: profile?.hubCode == 'KAT-HUB-01'
                      ? 'Corridor KAT-KAN (Outbound)'
                      : 'Corridor KAN-KAT (Outbound)',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final isKatsina = profile?.hubCode == 'KAT-HUB-01';
                    final match = corridors.firstWhere(
                      (c) => isKatsina
                          ? c['code'] == 'KAT-KAN'
                          : c['code'] == 'KAN-KAT',
                      orElse: () => {
                        'origin_hub_id': profile?.operatingHubId ??
                            (isKatsina
                                ? '00000000-0000-0000-0000-000000000012'
                                : '00000000-0000-0000-0000-000000000011'),
                        'destination_hub_id': isKatsina
                            ? '00000000-0000-0000-0000-000000000011'
                            : '00000000-0000-0000-0000-000000000012',
                      },
                    );
                    await _createNewBatch(
                      originHubId: match['origin_hub_id'] as String,
                      destinationHubId: match['destination_hub_id'] as String,
                    );
                  },
                ),
              ] else ...[
                for (final c in availableCorridors)
                  _CorridorTile(
                    title: c['code'] == 'KAN-KAT'
                        ? 'Kano Central Hub → Katsina Central Hub'
                        : 'Katsina Central Hub → Kano Central Hub',
                    subtitle: 'Corridor ${c['code']}',
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _createNewBatch(
                        originHubId: c['origin_hub_id'] as String,
                        destinationHubId: c['destination_hub_id'] as String,
                      );
                    },
                  ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createNewBatch({
    required String originHubId,
    required String destinationHubId,
  }) async {
    try {
      final service = ref.read(personnelBatchServiceProvider);
      final batch = await service.createBatch(
        originHubId: originHubId,
        destinationHubId: destinationHubId,
      );

      ref.invalidate(batchesListProvider(null));

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BatchDetailScreen(batchId: batch.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e is CereloApiError ? e.message : 'Could not create batch.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: CereloColors.error),
        );
      }
    }
  }

  void _showReceiveBatchModal() {
    BatchReceiveSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(personnelProfileProvider).value;
    final batchesAsync = ref.watch(batchesListProvider(null));

    final userHubId = profile?.operatingHubId;

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Batches & Middle-Mile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Batches',
            onPressed: () => ref.invalidate(batchesListProvider(null)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: CereloColors.orange,
          onRefresh: () async {
            ref.invalidate(batchesListProvider(null));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action Buttons Row
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CereloSpacing.pagePadding,
                  CereloSpacing.md,
                  CereloSpacing.pagePadding,
                  CereloSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showCreateBatchModal,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create Batch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CereloColors.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: CereloSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showReceiveBatchModal,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text('Receive Batch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CereloColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: CereloSpacing.pagePadding,
                  vertical: CereloSpacing.xs,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _currentFilter == BatchTabFilter.all,
                      onSelected: () => setState(() => _currentFilter = BatchTabFilter.all),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Incoming',
                      badge: 'INBOUND',
                      isSelected: _currentFilter == BatchTabFilter.incoming,
                      onSelected: () => setState(() => _currentFilter = BatchTabFilter.incoming),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Drafts',
                      isSelected: _currentFilter == BatchTabFilter.drafts,
                      onSelected: () => setState(() => _currentFilter = BatchTabFilter.drafts),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Ready to Depart',
                      isSelected: _currentFilter == BatchTabFilter.readyToDepart,
                      onSelected: () => setState(() => _currentFilter = BatchTabFilter.readyToDepart),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Outbound',
                      isSelected: _currentFilter == BatchTabFilter.outbound,
                      onSelected: () => setState(() => _currentFilter = BatchTabFilter.outbound),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Received',
                      isSelected: _currentFilter == BatchTabFilter.received,
                      onSelected: () => setState(() => _currentFilter = BatchTabFilter.received),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Batches List
              Expanded(
                child: batchesAsync.when(
                  loading: () => const Center(
                    child: CereloLoading(message: 'Loading batches...'),
                  ),
                  error: (_, __) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(CereloSpacing.md),
                      child: Text(
                        'Could not load batches. Please check your internet connection.',
                        style: TextStyle(fontSize: 13, color: CereloColors.textSecondary),
                      ),
                    ),
                  ),
                  data: (allBatches) {
                    // Filter based on selected filter and user hub
                    final filtered = allBatches.where((b) {
                      final isOrigin = userHubId == null || b.originHubId == userHubId;
                      final isDestination = userHubId != null && b.destinationHubId == userHubId;

                      switch (_currentFilter) {
                        case BatchTabFilter.all:
                          return true;
                        case BatchTabFilter.incoming:
                          return isDestination && b.status == BatchStatus.onboarded;
                        case BatchTabFilter.drafts:
                          return isOrigin && b.status == BatchStatus.draft;
                        case BatchTabFilter.readyToDepart:
                          return isOrigin && b.status == BatchStatus.confirmed;
                        case BatchTabFilter.outbound:
                          return isOrigin && b.status == BatchStatus.onboarded;
                        case BatchTabFilter.received:
                          return isDestination &&
                              (b.status == BatchStatus.destinationReceived ||
                                  b.status == BatchStatus.reconciled ||
                                  b.status == BatchStatus.reconciling);
                      }
                    }).toList();

                    if (filtered.isEmpty) {
                      final emptyDesc = switch (_currentFilter) {
                        BatchTabFilter.incoming =>
                          'No incoming batches currently in transit to your hub.',
                        BatchTabFilter.drafts =>
                          'No draft batches currently being prepared at your hub.',
                        BatchTabFilter.readyToDepart =>
                          'No batches confirmed and awaiting middle-mile departure.',
                        BatchTabFilter.outbound =>
                          'No batches currently in transit departing from your hub.',
                        BatchTabFilter.received =>
                          'No batches received at your hub.',
                        BatchTabFilter.all =>
                          'No batches found. Create a new batch or receive an inbound batch.',
                      };

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(CereloSpacing.xl),
                          child: CereloEmptyState(
                            icon: _currentFilter == BatchTabFilter.incoming
                                ? Icons.inbox_rounded
                                : Icons.alt_route_outlined,
                            title: 'No Batches Found',
                            description: emptyDesc,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(CereloSpacing.pagePadding),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final b = filtered[i];
                        final isDestinationPersonnel =
                            userHubId != null && b.destinationHubId == userHubId;
                        final isIncoming = isDestinationPersonnel && b.status == BatchStatus.onboarded;

                        return _BatchCard(
                          batch: b,
                          isIncoming: isIncoming,
                          isDestinationPersonnel: isDestinationPersonnel,
                          onTap: () {
                            if (isIncoming) {
                              InboundTransportDetailSheet.show(context, batch: b);
                            } else if (b.status == BatchStatus.destinationReceived ||
                                b.status == BatchStatus.reconciling ||
                                b.status == BatchStatus.reconciled) {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ReconciliationScreen(batchId: b.id),
                                ),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => BatchDetailScreen(batchId: b.id),
                                ),
                              );
                            }
                          },
                          onReceiveTap: isIncoming
                              ? () => BatchReceiveSheet.show(context)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.onTap,
    this.isIncoming = false,
    this.isDestinationPersonnel = false,
    this.onReceiveTap,
  });

  final BatchSummaryDto batch;
  final VoidCallback onTap;
  final bool isIncoming;
  final bool isDestinationPersonnel;
  final VoidCallback? onReceiveTap;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = batch.status == BatchStatus.confirmed;
    final isOnboarded = batch.status == BatchStatus.onboarded;
    final isReceived = batch.status == BatchStatus.destinationReceived;
    final isReconciled = batch.status == BatchStatus.reconciled;

    return Container(
      margin: const EdgeInsets.only(bottom: CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.white,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(
          color: isIncoming
              ? CereloColors.orange
              : (isReceived ? CereloColors.info : CereloColors.border),
          width: isIncoming ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(CereloSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        batch.originCity,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: CereloColors.navy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 14, color: CereloColors.orange),
                      const SizedBox(width: 4),
                      Text(
                        batch.destinationCity,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: CereloColors.navy,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isIncoming
                          ? CereloColors.orange.withOpacity(0.15)
                          : (isOnboarded
                              ? CereloColors.info.withOpacity(0.12)
                              : (isReconciled
                                  ? CereloColors.success.withOpacity(0.12)
                                  : (isConfirmed
                                      ? CereloColors.success.withOpacity(0.12)
                                      : CereloColors.navy.withOpacity(0.08)))),
                      borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                    ),
                    child: Text(
                      isIncoming
                          ? 'INCOMING'
                          : batch.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isIncoming
                            ? CereloColors.orangeDark
                            : (isOnboarded
                                ? CereloColors.info
                                : (isReconciled || isConfirmed
                                    ? CereloColors.success
                                    : CereloColors.navy)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: CereloSpacing.xs),

              if (isIncoming) ...[
                // Inbound transport details: Zero Batch Reference or QR exposed
                if (batch.driverName != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Driver: ${batch.driverName} (${batch.vehiclePlateNumber ?? "Commercial"})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CereloColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (batch.driverPhone != null)
                        InkWell(
                          onTap: () async {
                            final uri = Uri.parse('tel:${batch.driverPhone}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CereloColors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_rounded, size: 12, color: CereloColors.success),
                                const SizedBox(width: 4),
                                Text(
                                  batch.driverPhone!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: CereloColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ] else if (batch.batchReference != null) ...[
                Text(
                  'Reference: ${batch.batchReference}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: CereloColors.textSecondary,
                  ),
                ),
                if (batch.driverName != null && batch.vehiclePlateNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Transport: ${batch.driverName} (${batch.vehiclePlateNumber})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CereloColors.textSecondary,
                    ),
                  ),
                ],
              ],

              const Divider(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${batch.manifestParcelCount} Parcels in Manifest',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CereloColors.navy,
                    ),
                  ),
                  if (isIncoming && onReceiveTap != null)
                    ElevatedButton.icon(
                      onPressed: onReceiveTap,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 14),
                      label: const Text('Receive Batch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CereloColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                        ),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          isDestinationPersonnel && (isOnboarded || isReceived || isReconciled)
                              ? 'Reconcile'
                              : 'Open Manifest',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CereloColors.navy,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.badge,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? CereloColors.navy : CereloColors.surfaceVariant,
          borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : CereloColors.textPrimary,
              ),
            ),
            if (badge != null && !isSelected) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: CereloColors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: CereloColors.orangeDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CorridorTile extends StatelessWidget {
  const _CorridorTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CereloSpacing.sm),
      decoration: BoxDecoration(
        color: CereloColors.surfaceVariant,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
      ),
      child: ListTile(
        leading: const Icon(Icons.alt_route_rounded, color: CereloColors.navy),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: CereloColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
