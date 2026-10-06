import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/router/personnel_router.dart';
import '../../auth/providers/personnel_profile_provider.dart';
import '../../batches/providers/batch_provider.dart';
import '../../delivery/providers/delivery_provider.dart';
import '../../parcels/providers/hub_provider.dart';
import '../../pickup/providers/pickup_provider.dart';

/// Personnel Home Screen — "Today's Work".
///
/// Four sections, ordered the way a shift actually runs:
/// 1. Pickups to Collect
/// 2. Hub Operations — origin-side parcel staging and outbound batches
/// 3. Incoming Trips & Arrivals — only batches bound for THIS hub
/// 4. Doorstep Deliveries
///
/// Every section is an entry point into a real workflow screen. Without the
/// Hub Operations section, parcel staging and batch creation had no route in
/// from the three-tab shell, so an origin hub with nothing in transit could
/// not start the middle-mile at all.
///
/// Deliberately uses field language, not system language (no "reconciliation",
/// "RPC" or "transit run"), and keeps a one-tap call on every task, because the
/// operator is usually holding a parcel while using this.
class PersonnelHomeScreen extends ConsumerWidget {
  const PersonnelHomeScreen({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(personnelProfileProvider);
    final isOffline = ref.watch(isOfflineProvider);

    final pickupsAsync = ref.watch(pickupQueueProvider);
    final batchesAsync = ref.watch(batchesListProvider(null));
    final deliveriesAsync = ref.watch(readyForDeliveryQueueProvider);
    final readyParcelsAsync = ref.watch(readyForBatchParcelsProvider);

    // Direction is decided by hub, never by status alone: an ONBOARDED batch is
    // "incoming" only to its destination hub. Until the profile resolves we
    // know no hub, so nothing is classified (rather than everything).
    final myHubId = profileAsync.maybeWhen(
      data: (p) => p.operatingHubId,
      orElse: () => null,
    );
    bool isInboundToMe(BatchSummaryDto b) =>
        myHubId != null &&
        b.destinationHubId == myHubId &&
        (b.status == BatchStatus.onboarded ||
            b.status == BatchStatus.destinationReceived ||
            b.status == BatchStatus.reconciling);
    bool isMyOutboundPending(BatchSummaryDto b) =>
        myHubId != null &&
        b.originHubId == myHubId &&
        (b.status == BatchStatus.draft || b.status == BatchStatus.confirmed);

    final staffName = profileAsync.maybeWhen(
      data: (p) => p.fullName ?? 'Personnel',
      orElse: () => 'Personnel',
    );
    final hubDisplay = profileAsync.maybeWhen(
      data: (p) => p.hubDisplay,
      orElse: () => 'Cerelo Hub',
    );
    final staffRef = profileAsync.maybeWhen(
      data: (p) => p.employeeReference != null && p.employeeReference!.isNotEmpty
          ? ' · ID: ${p.employeeReference}'
          : '',
      orElse: () => '',
    );

    return Scaffold(
      backgroundColor: CereloColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: CereloColors.orange,
          onRefresh: () async {
            ref.invalidate(personnelProfileProvider);
            ref.invalidate(pickupQueueProvider);
            ref.invalidate(batchesListProvider(null));
            ref.invalidate(readyForDeliveryQueueProvider);
            ref.invalidate(readyForBatchParcelsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: CereloSpacing.pagePadding,
              vertical: CereloSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IdentityHeader(
                  staffName: staffName,
                  subtitle: '$hubDisplay$staffRef',
                ),

                if (isOffline) ...[
                  const SizedBox(height: CereloSpacing.md),
                  const _OfflineBanner(),
                ],

                const SizedBox(height: CereloSpacing.lg),

                // ─── Section 1: Pickups to Collect ───────────────────────────
                CereloSectionHeader(
                  title: 'Pickups to Collect',
                  icon: Icons.assignment_outlined,
                  count: pickupsAsync.maybeWhen(data: (l) => l.length, orElse: () => null),
                ),
                pickupsAsync.when(
                  loading: () => const CereloLoading(message: 'Checking pickup queue...'),
                  error: (_, __) => _ErrorRow(
                    message: 'Could not load pickups. Your saved queue is still available.',
                    onRetry: () => ref.invalidate(pickupQueueProvider),
                  ),
                  data: (pickups) {
                    if (pickups.isEmpty) {
                      return const CereloInlineEmpty(
                        message: 'No pending pickups — every request for your hub is up to date.',
                      );
                    }
                    return Column(
                      children: [
                        for (final p in pickups) _pickupCard(context, p),
                      ],
                    );
                  },
                ),

                const SizedBox(height: CereloSpacing.lg),

                // ─── Section 2: Hub Operations (origin side) ─────────────────
                const CereloSectionHeader(
                  title: 'Hub Operations',
                  icon: Icons.warehouse_outlined,
                ),
                _HubOpRow(
                  icon: Icons.inventory_2_outlined,
                  title: 'Parcels in custody',
                  subtitle: 'Stage at hub, print labels, add to a batch',
                  count: readyParcelsAsync.whenData((l) => l.length),
                  onTap: () => context.push(PersonnelRoutes.parcels),
                ),
                const SizedBox(height: CereloSpacing.sm),
                _HubOpRow(
                  icon: Icons.local_shipping_outlined,
                  title: 'Outbound batches',
                  subtitle: 'Create, freeze, assign transport, depart',
                  count: batchesAsync
                      .whenData((l) => l.where(isMyOutboundPending).length),
                  onTap: () => context.push(PersonnelRoutes.batches),
                ),

                const SizedBox(height: CereloSpacing.lg),

                // ─── Section 3: Incoming Trips & Arrivals ────────────────────
                CereloSectionHeader(
                  title: 'Incoming Trips & Arrivals',
                  icon: Icons.local_shipping_outlined,
                  count: batchesAsync.maybeWhen(
                    data: (batches) => batches.where(isInboundToMe).length,
                    orElse: () => null,
                  ),
                ),
                batchesAsync.when(
                  loading: () => const CereloLoading(message: 'Checking arrivals...'),
                  error: (_, __) => _ErrorRow(
                    message: 'Could not load incoming trips.',
                    onRetry: () => ref.invalidate(batchesListProvider(null)),
                  ),
                  data: (batches) {
                    final inbound = batches.where(isInboundToMe).toList();

                    if (inbound.isEmpty) {
                      return const CereloInlineEmpty(
                        icon: Icons.alt_route_rounded,
                        message: 'No vehicles en route to your hub — trips appear here once they depart.',
                      );
                    }
                    return Column(
                      children: [
                        for (final b in inbound) _inboundBatchCard(context, b),
                      ],
                    );
                  },
                ),

                const SizedBox(height: CereloSpacing.lg),

                // ─── Section 4: Doorstep Deliveries ──────────────────────────
                CereloSectionHeader(
                  title: 'Doorstep Deliveries',
                  icon: Icons.two_wheeler_outlined,
                  count: deliveriesAsync.maybeWhen(data: (l) => l.length, orElse: () => null),
                ),
                deliveriesAsync.when(
                  loading: () => const CereloLoading(message: 'Checking deliveries...'),
                  error: (_, __) => _ErrorRow(
                    message: 'Could not load delivery tasks.',
                    onRetry: () => ref.invalidate(readyForDeliveryQueueProvider),
                  ),
                  data: (deliveries) {
                    if (deliveries.isEmpty) {
                      return const CereloInlineEmpty(
                        icon: Icons.task_alt_rounded,
                        message: 'No deliveries queued — parcels ready for final-mile appear here.',
                      );
                    }
                    return Column(
                      children: [
                        for (final d in deliveries) _deliveryCard(context, d),
                      ],
                    );
                  },
                ),

                const SizedBox(height: CereloSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Task cards ────────────────────────────────────────────────────────────

  Widget _pickupCard(BuildContext context, PickupTaskDto task) => _TaskCard(
        title: task.senderName,
        pill: _Pill(
          label: '${task.originCity} → ${task.destinationCity}',
          background: CereloColors.surfaceVariant,
          foreground: CereloColors.navy,
        ),
        metaIcon: Icons.location_on_outlined,
        metaText: task.senderPickupAddress,
        phone: task.senderPhone,
        callLabel: 'Call Sender',
        actionLabel: 'Start Pickup',
        actionColor: CereloColors.navy,
        onAction: () => context.push(PersonnelRoutes.pickup),
        onCall: _makePhoneCall,
      );

  Widget _inboundBatchCard(BuildContext context, BatchSummaryDto batch) {
    final count = batch.manifestParcelCount;
    final driver = batch.driverName ?? 'Partner driver';
    final plate = batch.vehiclePlateNumber ?? 'Vehicle';
    // "1 Parcels" reads as a bug to anyone using this every day.
    final parcelWord = count == 1 ? 'Parcel' : 'Parcels';
    // Still on the road -> physically receive it. Already received -> the
    // remaining work is checking each parcel off, not receiving it again.
    final enRoute = batch.status == BatchStatus.onboarded;

    return _TaskCard(
      title: '${batch.originCity} → ${batch.destinationCity}',
      pill: _Pill(
        label: enRoute ? '$count $parcelWord en route' : '$count $parcelWord to check',
        background: enRoute ? CereloColors.warningLight : CereloColors.surfaceVariant,
        foreground: enRoute ? CereloColors.warning : CereloColors.navy,
      ),
      metaIcon: Icons.person_pin_circle_outlined,
      metaText: '$driver · $plate',
      phone: batch.driverPhone,
      callLabel: 'Call Driver',
      actionLabel: enRoute ? 'Receive Trip' : 'Check Parcels',
      actionColor: CereloColors.orange,
      onAction: () => context.push(PersonnelRoutes.batches),
      onCall: _makePhoneCall,
    );
  }

  Widget _deliveryCard(BuildContext context, DeliveryTaskDto delivery) {
    final dueKobo = delivery.receiverDueAmount.kobo;
    final isCashDue = delivery.receiverPaymentStatus != PaymentStatus.notRequired &&
        delivery.receiverPaymentStatus != PaymentStatus.collected &&
        dueKobo > 0;
    final amount = (dueKobo / 100).toStringAsFixed(0);

    return _TaskCard(
      title: delivery.receiverName,
      pill: _Pill(
        label: isCashDue ? 'Collect ₦$amount' : 'Paid at pickup',
        background: isCashDue ? CereloColors.errorLight : CereloColors.successLight,
        foreground: isCashDue ? CereloColors.error : CereloColors.success,
      ),
      metaIcon: Icons.home_outlined,
      metaText: delivery.receiverDeliveryAddress,
      phone: delivery.receiverPhone,
      callLabel: 'Call Receiver',
      actionLabel: 'Deliver',
      actionColor: CereloColors.navy,
      onAction: () => context.push(PersonnelRoutes.deliveries),
      onCall: _makePhoneCall,
    );
  }
}

// ─── Private building blocks ─────────────────────────────────────────────────

/// Staff identity block. Uses initials rather than an avatar image: personnel
/// records carry no photo, and an empty placeholder circle looked unfinished.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.staffName, required this.subtitle});

  final String staffName;
  final String subtitle;

  String get _initials {
    final parts =
        staffName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: CereloColors.navy,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials,
            style: CereloTextStyles.labelLg.copyWith(color: CereloColors.textOnDark),
          ),
        ),
        const SizedBox(width: CereloSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                staffName,
                style: CereloTextStyles.h2.copyWith(color: CereloColors.navy),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: CereloTextStyles.bodySm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: CereloSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: CereloColors.surfaceVariant,
            borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
          ),
          child: Text(
            'STAFF',
            style: CereloTextStyles.labelSm.copyWith(color: CereloColors.navy),
          ),
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: CereloSpacing.md,
        vertical: CereloSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: CereloColors.warningLight,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: CereloSpacing.iconSm,
            color: CereloColors.warning,
          ),
          const SizedBox(width: CereloSpacing.sm),
          Expanded(
            child: Text(
              'Offline · showing last synced tasks',
              style: CereloTextStyles.labelMd.copyWith(color: CereloColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status chip. Colors come from the palette, never raw Material shades.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: CereloTextStyles.labelSm.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// One unit of work. All three home sections render through this, so a pickup,
/// an arrival and a delivery share the same shape, spacing and touch targets —
/// previously each was hand-built and they drifted apart.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.pill,
    required this.metaIcon,
    required this.metaText,
    required this.phone,
    required this.callLabel,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
    required this.onCall,
  });

  final String title;
  final Widget pill;
  final IconData metaIcon;
  final String metaText;
  final String? phone;
  final String callLabel;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;
  final Future<void> Function(String) onCall;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone != null && phone!.isNotEmpty;

    return CereloCard(
      margin: const EdgeInsets.only(bottom: CereloSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: CereloTextStyles.labelLg.copyWith(
                    color: CereloColors.navy,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CereloSpacing.sm),
              pill,
            ],
          ),
          const SizedBox(height: CereloSpacing.xs),
          Row(
            children: [
              Icon(
                metaIcon,
                size: CereloSpacing.iconSm,
                color: CereloColors.textTertiary,
              ),
              const SizedBox(width: CereloSpacing.xs),
              Expanded(
                child: Text(
                  metaText,
                  style: CereloTextStyles.bodySm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: CereloSpacing.md),
          Row(
            children: [
              if (hasPhone) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.call_rounded, size: CereloSpacing.iconSm),
                    label: Text(
                      callLabel,
                      style: CereloTextStyles.labelMd.copyWith(color: CereloColors.navy),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CereloColors.navy,
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: CereloColors.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () => onCall(phone!),
                  ),
                ),
                const SizedBox(width: CereloSpacing.sm),
              ] else
                const Spacer(),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor: CereloColors.textOnDark,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: CereloTextStyles.labelLg.copyWith(
                      color: CereloColors.textOnDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One tappable entry into an origin-hub workflow screen.
///
/// The count is an [AsyncValue] on purpose: a failed load must read as
/// "couldn't load", never as 0 — zero is a real operational answer.
class _HubOpRow extends StatelessWidget {
  const _HubOpRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AsyncValue<int> count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trailing = count.when(
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Text(
        "Couldn't load",
        style: CereloTextStyles.bodySm.copyWith(color: CereloColors.error),
      ),
      data: (n) => _Pill(
        label: '$n',
        background: CereloColors.surfaceVariant,
        foreground: CereloColors.navy,
      ),
    );

    return CereloCard(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(icon, color: CereloColors.navy, size: CereloSpacing.iconMd),
            const SizedBox(width: CereloSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: CereloTextStyles.labelLg.copyWith(color: CereloColors.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: CereloTextStyles.bodySm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: CereloSpacing.sm),
            trailing,
            const SizedBox(width: CereloSpacing.xs),
            const Icon(Icons.chevron_right_rounded, color: CereloColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.errorLight,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: CereloColors.error,
            size: CereloSpacing.iconMd,
          ),
          const SizedBox(width: CereloSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: CereloTextStyles.bodySm.copyWith(color: CereloColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: CereloColors.error),
            child: Text(
              'Retry',
              style: CereloTextStyles.labelMd.copyWith(color: CereloColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
