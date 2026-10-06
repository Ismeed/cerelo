import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../dialogs/cancel_delivery_dialog.dart';
import '../dialogs/share_shipment_dialog.dart';
import '../dialogs/verify_delivery_code_dialog.dart';
import '../providers/shipments_provider.dart';
import '../widgets/shipment_timeline.dart';

/// Customer Shipment Details Screen.
///
/// Adapts dynamically based on the viewer's relationship (Sender vs. Linked Receiver):
/// - Sender: Pickup address, Receiver details, Delivery Code (when available), Share action.
/// - Linked Receiver: Delivery address, Sender name, Receiver payment responsibility.
class ShipmentDetailsScreen extends ConsumerWidget {
  const ShipmentDetailsScreen({
    super.key,
    required this.shipmentId,
  });

  final String shipmentId;

  void _copyDeliveryCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery Code copied to clipboard.'),
        backgroundColor: CereloColors.navy,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showCancelRequestDialog(
    BuildContext context,
    WidgetRef ref,
    ShipmentDto shipment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancel this request?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'This shipment has not yet been confirmed by CERELO. Cancelling it will stop the pickup/delivery request.',
            style: TextStyle(fontSize: 13, color: CereloColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Request'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Cancel Request',
                style: TextStyle(
                  color: CereloColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        final service = ref.read(shipmentServiceProvider);
        final success = await service.cancelShipment(
          shipmentId: shipment.id,
          reason: 'Sender cancelled before pickup',
        );
        if (context.mounted) {
          if (success) {
            ref.invalidate(shipmentDetailProvider(shipment.id));
            ref.invalidate(customerActiveShipmentsProvider);
            ref.invalidate(customerShipmentsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shipment request cancelled successfully.'),
                backgroundColor: CereloColors.navy,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not cancel request. Please try again.'),
                backgroundColor: CereloColors.error,
              ),
            );
          }
        }
      } on CereloApiError catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: CereloColors.error,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel: $e'),
              backgroundColor: CereloColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCancelDeliveryDialog(
    BuildContext context,
    ShipmentDto shipment,
  ) async {
    final result = await CancelDeliveryDialog.show(context, shipment);
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Delivery cancelled. Our team will arrange package return.',
          ),
          backgroundColor: CereloColors.navy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(customerAuthProvider);
    final currentUserId = authState.user?.id;

    final shipmentAsync = ref.watch(shipmentDetailProvider(shipmentId));
    final shipmentService = ref.read(shipmentServiceProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Shipment Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: CereloColors.orange,
          onRefresh: () async {
            ref.invalidate(shipmentDetailProvider(shipmentId));
          },
          child: shipmentAsync.when(
            loading: () => const Center(
              child: CereloLoading(message: 'Loading shipment details...'),
            ),
            error: (err, _) => _buildErrorState(context, ref),
            data: (shipment) {
              if (shipment == null) {
                return _buildNotFoundState(context);
              }

              final isSender = shipment.isSender(currentUserId);
              final relationshipLabel = shipment.relationshipBadge(currentUserId);
              final counterpart = shipment.counterpartLabel(currentUserId);
              final timelineEvents = shipmentService.getShipmentTimeline(shipment);
              final hasDeliveryCode = shipment.deliveryCode != null &&
                  shipment.deliveryCode!.isNotEmpty;
              final isOffline = ref.watch(isOfflineProvider);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(CereloSpacing.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isOffline) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CereloSpacing.md,
                          vertical: 8,
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
                              'Offline · Showing last synced details',
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

                    // Card 1: Route & Status Summary
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.lg),
                      decoration: BoxDecoration(
                        color: CereloColors.white,
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusLg),
                        border: Border.all(color: CereloColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                shipment.originCity,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: CereloColors.navy,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: CereloColors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                shipment.destinationCity,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: CereloColors.navy,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSender
                                      ? CereloColors.navy.withOpacity(0.08)
                                      : CereloColors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(
                                    CereloSpacing.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  relationshipLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isSender
                                        ? CereloColors.navy
                                        : CereloColors.orangeDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: CereloSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                counterpart,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CereloColors.textPrimary,
                                ),
                              ),
                              CereloStatusBadge(status: shipment.status),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: CereloSpacing.md),

                    // Card 2: Delivery Code & Share Area
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.md),
                      decoration: BoxDecoration(
                        color: CereloColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusMd),
                        border: Border.all(color: CereloColors.border),
                      ),
                      child: hasDeliveryCode
                          ? Row(
                              children: [
                                const Icon(
                                  Icons.qr_code_rounded,
                                  color: CereloColors.navy,
                                  size: 24,
                                ),
                                const SizedBox(width: CereloSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Delivery Code',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: CereloColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        shipment.deliveryCode!,
                                        style: CereloTextStyles.deliveryCode
                                            .copyWith(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 20),
                                  color: CereloColors.navy,
                                  tooltip: 'Copy Code',
                                  onPressed: () => _copyDeliveryCode(
                                    context,
                                    shipment.deliveryCode!,
                                  ),
                                ),
                                if (isSender)
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded,
                                        size: 20),
                                    color: CereloColors.orangeDark,
                                    tooltip: 'Share Tracking Link',
                                    onPressed: () =>
                                        ShareShipmentDialog.show(
                                            context, shipment),
                                  ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: CereloColors.navy,
                                  size: 22,
                                ),
                                const SizedBox(width: CereloSpacing.sm),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Delivery Code Pending',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: CereloColors.navy,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Code will be generated once personnel confirms the package at pickup.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: CereloColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSender)
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded,
                                        size: 20),
                                    color: CereloColors.orangeDark,
                                    tooltip: 'Share Tracking Link',
                                    onPressed: () =>
                                        ShareShipmentDialog.show(
                                            context, shipment),
                                  ),
                              ],
                            ),
                    ),

                    if (isSender && hasDeliveryCode) ...[
                      const SizedBox(height: CereloSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              VerifyDeliveryCodeDialog.show(context, shipment),
                          icon: const Icon(Icons.verified_outlined, size: 16),
                          label: const Text(
                            'Verify Code',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: CereloSpacing.lg),

                    // Section: Status Progress Timeline
                    const Text(
                      'Delivery Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.navy,
                      ),
                    ),
                    const SizedBox(height: CereloSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.lg),
                      decoration: BoxDecoration(
                        color: CereloColors.white,
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusMd),
                        border: Border.all(color: CereloColors.border),
                      ),
                      child: ShipmentTimeline(events: timelineEvents),
                    ),

                    const SizedBox(height: CereloSpacing.lg),

                    // Section: Parcel Details & Addresses (Privacy-Safe)
                    const Text(
                      'Parcel & Addresses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.navy,
                      ),
                    ),
                    const SizedBox(height: CereloSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.md),
                      decoration: BoxDecoration(
                        color: CereloColors.white,
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusMd),
                        border: Border.all(color: CereloColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailRow(
                            label: 'Size Tier',
                            value: shipment.declaredSize.displayLabel,
                          ),
                          const Divider(),
                          _DetailRow(
                            label: 'Category',
                            value: shipment.categoryDescription,
                          ),
                          if (isSender) ...[
                            const Divider(),
                            _DetailRow(
                              label: 'Pickup Address',
                              value: shipment.senderPickupAddressSnapshot
                                      .isNotEmpty
                                  ? shipment.senderPickupAddressSnapshot
                                  : '${shipment.originCity} (Address on file)',
                            ),
                          ],
                          const Divider(),
                          _DetailRow(
                            label: 'Delivery Address',
                            value: shipment.receiverDeliveryAddressSnapshot
                                    .isNotEmpty
                                ? shipment.receiverDeliveryAddressSnapshot
                                : '${shipment.destinationCity} (Doorstep delivery)',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: CereloSpacing.lg),

                    // Section: Payment Responsibility
                    const Text(
                      'Payment Responsibility',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.navy,
                      ),
                    ),
                    if (shipment.quotedPrice.kobo != shipment.finalPrice.kobo) ...[
                      const SizedBox(height: CereloSpacing.xs),
                      Container(
                        padding: const EdgeInsets.all(CereloSpacing.md),
                        decoration: BoxDecoration(
                          color: CereloColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(CereloSpacing.radiusMd),
                          border: Border.all(color: CereloColors.orangeLight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: CereloColors.orangeDark, size: 20),
                            const SizedBox(width: CereloSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fare updated after parcel inspection',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: CereloColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Original quote: ${shipment.quotedPrice.formatted}  •  Final agreed fare: ${shipment.finalPrice.formatted}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: CereloColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: CereloSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.md),
                      decoration: BoxDecoration(
                        color: CereloColors.white,
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusMd),
                        border: Border.all(color: CereloColors.border),
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            label: 'Payment Mode',
                            value: shipment.paymentMode.displayLabel,
                          ),
                          const Divider(),
                          _DetailRow(
                            label: 'Total Fee',
                            value: shipment.finalPrice.formatted,
                            valueStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: CereloColors.navy,
                            ),
                          ),
                          const Divider(),
                          _DetailRow(
                            label: isSender ? 'Your Payment' : 'Receiver Share',
                            value: isSender
                                ? (shipment.paymentMode ==
                                        PaymentMode.receiverPays
                                    ? '₦0 (Receiver Pays)'
                                    : shipment.paymentMode ==
                                            PaymentMode.splitPayment
                                        ? Money.fromKobo(shipment.finalPrice.kobo ~/ 2).formatted
                                        : shipment.finalPrice.formatted)
                                : (shipment.paymentMode ==
                                        PaymentMode.senderPays
                                    ? '₦0 (Paid by Sender)'
                                    : shipment.paymentMode ==
                                            PaymentMode.splitPayment
                                        ? Money.fromKobo(shipment.finalPrice.kobo - (shipment.finalPrice.kobo ~/ 2)).formatted
                                        : shipment.finalPrice.formatted),
                          ),
                        ],
                      ),
                    ),
                    if (!isSender && shipment.status == ShipmentStatus.delivered) ...[
                      const SizedBox(height: CereloSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(CereloSpacing.md),
                        decoration: BoxDecoration(
                          color: CereloColors.success.withOpacity(0.08),
                          borderRadius:
                              BorderRadius.circular(CereloSpacing.radiusMd),
                          border: Border.all(
                              color: CereloColors.success.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: CereloColors.success, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Delivery Acknowledgment',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: CereloColors.navy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Have you received this package in good condition?',
                              style: TextStyle(
                                fontSize: 12,
                                color: CereloColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: CereloSpacing.md),
                            CereloButton(
                              label: 'Confirm Received',
                              variant: CereloButtonVariant.primary,
                              onPressed: () async {
                                final success = await ref
                                    .read(shipmentServiceProvider)
                                    .confirmReceiverReceipt(shipment.id);
                                if (success && context.mounted) {
                                  ref.invalidate(
                                      shipmentDetailProvider(shipment.id));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Thank you! Delivery receipt confirmed.'),
                                      backgroundColor: CereloColors.success,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Section: Cancelled Informational Banner
                    if (shipment.isCancelled) ...[
                      const SizedBox(height: CereloSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(CereloSpacing.md),
                        decoration: BoxDecoration(
                          color: CereloColors.errorLight,
                          borderRadius:
                              BorderRadius.circular(CereloSpacing.radiusMd),
                          border: Border.all(color: CereloColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.cancel_outlined,
                              color: CereloColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: CereloSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Shipment Cancelled',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: CereloColors.error,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    shipment.cancellationReason != null &&
                                            shipment.cancellationReason!.isNotEmpty
                                        ? 'Reason: ${shipment.cancellationReason}'
                                        : 'This shipment has been cancelled by customer request.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CereloColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Section: Shipment Actions (Customer Cancellation)
                    if (isSender &&
                        (shipment.canCancelRequest || shipment.canCancelDelivery)) ...[
                      const SizedBox(height: CereloSpacing.lg),
                      const Text(
                        'Shipment Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CereloColors.navy,
                        ),
                      ),
                      const SizedBox(height: CereloSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(CereloSpacing.md),
                        decoration: BoxDecoration(
                          color: CereloColors.white,
                          borderRadius:
                              BorderRadius.circular(CereloSpacing.radiusMd),
                          border: Border.all(color: CereloColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (shipment.canCancelRequest) ...[
                              const Text(
                                'Need to cancel this pickup request before CERELO personnel arrives?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CereloColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: CereloSpacing.sm),
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 18,
                                  color: CereloColors.error,
                                ),
                                label: const Text(
                                  'Cancel Request',
                                  style: TextStyle(
                                    color: CereloColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: CereloColors.error),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        CereloSpacing.radiusMd),
                                  ),
                                ),
                                onPressed: () =>
                                    _showCancelRequestDialog(context, ref, shipment),
                              ),
                            ] else if (shipment.canCancelDelivery) ...[
                              const Text(
                                'Parcel has been collected by CERELO but has not departed on corridor transit. You can cancel before transit begins.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CereloColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: CereloSpacing.sm),
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 18,
                                  color: CereloColors.error,
                                ),
                                label: const Text(
                                  'Cancel Delivery',
                                  style: TextStyle(
                                    color: CereloColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: CereloColors.error),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        CereloSpacing.radiusMd),
                                  ),
                                ),
                                onPressed: () =>
                                    _showCancelDeliveryDialog(context, shipment),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: CereloSpacing.xl),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CereloSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: CereloColors.error,
              size: 44,
            ),
            const SizedBox(height: CereloSpacing.md),
            const Text(
              'Could not load shipment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'This shipment is unavailable or you do not have permission to view it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CereloColors.textSecondary,
              ),
            ),
            const SizedBox(height: CereloSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CereloButton(
                  label: 'Retry',
                  variant: CereloButtonVariant.primary,
                  isFullWidth: false,
                  onPressed: () => ref.invalidate(shipmentDetailProvider(shipmentId)),
                ),
                const SizedBox(width: CereloSpacing.sm),
                CereloButton(
                  label: 'Back to Shipments',
                  variant: CereloButtonVariant.outlined,
                  isFullWidth: false,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CereloSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: CereloColors.textTertiary,
              size: 48,
            ),
            const SizedBox(height: CereloSpacing.md),
            const Text(
              'Shipment Not Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'This shipment does not exist or you do not have access to view it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CereloColors.textSecondary,
              ),
            ),
            const SizedBox(height: CereloSpacing.lg),
            CereloButton(
              label: 'Back to Shipments',
              isFullWidth: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: CereloColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CereloColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
