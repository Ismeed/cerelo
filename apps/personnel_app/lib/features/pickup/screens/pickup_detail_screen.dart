import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/pickup_provider.dart';
import 'parcel_confirmed_success_screen.dart';

/// Operational workspace for a single pickup task.
class PickupDetailScreen extends ConsumerStatefulWidget {
  const PickupDetailScreen({super.key, required this.task});

  final PickupTaskDto task;

  @override
  ConsumerState<PickupDetailScreen> createState() => _PickupDetailScreenState();
}

class _PickupDetailScreenState extends ConsumerState<PickupDetailScreen> {
  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone dialer for $phone'),
            backgroundColor: CereloColors.error,
          ),
        );
      }
    }
  }

  void _showReceiverVerificationModal() {
    final notifier = ref.read(activePickupProvider(widget.task).notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(CereloSpacing.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Record Receiver Verification Outcome',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CereloColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Confirm the result of your phone call with the receiver.',
                style: TextStyle(
                  fontSize: 12,
                  color: CereloColors.textSecondary,
                ),
              ),
              const SizedBox(height: CereloSpacing.md),
              _OutcomeTile(
                title: 'Receiver Verified & Ready',
                subtitle:
                    'Receiver answered, aware, and confirmed delivery address.',
                icon: Icons.check_circle_outline_rounded,
                color: CereloColors.success,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await notifier.recordReceiverVerification(outcome: 'VERIFIED');
                },
              ),
              _OutcomeTile(
                title: 'No Answer / Unreachable',
                subtitle: 'Receiver did not answer after multiple rings.',
                icon: Icons.phone_missed_rounded,
                color: CereloColors.warning,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await notifier.recordReceiverVerification(
                      outcome: 'NO_ANSWER');
                },
              ),
              _OutcomeTile(
                title: 'Invalid / Wrong Number',
                subtitle: 'Number is disconnected or wrong person answered.',
                icon: Icons.phone_disabled_rounded,
                color: CereloColors.error,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await notifier.recordReceiverVerification(
                      outcome: 'INVALID_NUMBER');
                },
              ),
              _OutcomeTile(
                title: 'Receiver Unaware / Disputes Parcel',
                subtitle: 'Person does not recognize sender or expect delivery.',
                icon: Icons.cancel_outlined,
                color: CereloColors.error,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await notifier.recordReceiverVerification(
                      outcome: 'UNAWARE_OR_DISPUTED');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentConfirmModal(Money amount) {
    final notifier = ref.read(activePickupProvider(widget.task).notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(CereloSpacing.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Record Physical Cash Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: CereloColors.navy,
                ),
              ),
              const SizedBox(height: CereloSpacing.sm),
              Text(
                'Confirm that you have physically collected ${amount.formatted} cash payment from the Sender.',
                style: const TextStyle(
                  fontSize: 13,
                  color: CereloColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: CereloSpacing.lg),
              CereloButton(
                label: 'Confirm ${amount.formatted} Cash Collected',
                variant: CereloButtonVariant.primary,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await notifier.recordSenderPayment(method: 'CASH');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showAdjustFareModal(Money currentPrice) {
    final notifier = ref.read(activePickupProvider(widget.task).notifier);
    final fareController =
        TextEditingController(text: currentPrice.naira.toString());
    final reasonController = TextEditingController();
    var senderAgreed = true;
    String? localError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: CereloSpacing.pagePadding,
                right: CereloSpacing.pagePadding,
                top: CereloSpacing.pagePadding,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    CereloSpacing.pagePadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Adjust Final Agreed Fare',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CereloColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Independently agree upon final price with Sender after parcel inspection.',
                    style: TextStyle(
                      fontSize: 12,
                      color: CereloColors.textSecondary,
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: CereloSpacing.sm),
                    Text(
                      localError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CereloColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: CereloSpacing.md),
                  TextField(
                    controller: fareController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Final Agreed Fare (₦)',
                      prefixText: '₦ ',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusMd),
                      ),
                    ),
                  ),
                  const SizedBox(height: CereloSpacing.sm),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Operational Reason (Mandatory)',
                      hintText: 'e.g. Special fragile packaging / agreed discount',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusMd),
                      ),
                    ),
                  ),
                  const SizedBox(height: CereloSpacing.sm),
                  CheckboxListTile(
                    value: senderAgreed,
                    onChanged: (val) {
                      setModalState(() {
                        senderAgreed = val ?? false;
                      });
                    },
                    title: const Text(
                      'I confirm this fare was explicitly agreed with the Sender.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.navy,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: CereloSpacing.md),
                  CereloButton(
                    label: 'Save Adjusted Fare',
                    variant: CereloButtonVariant.primary,
                    onPressed: () async {
                      final amountNaira =
                          int.tryParse(fareController.text.trim());
                      if (amountNaira == null || amountNaira <= 0) {
                        setModalState(() {
                          localError =
                              'Please enter a valid positive fare in Naira.';
                        });
                        return;
                      }
                      if (reasonController.text.trim().isEmpty) {
                        setModalState(() {
                          localError =
                              'Please provide an operational reason for the adjustment.';
                        });
                        return;
                      }
                      if (!senderAgreed) {
                        setModalState(() {
                          localError =
                              'You must confirm that the fare was agreed with the Sender.';
                        });
                        return;
                      }

                      Navigator.of(ctx).pop();
                      await notifier.adjustFare(
                        newFare: Money.fromNaira(amountNaira),
                        reason: reasonController.text.trim(),
                        senderAgreed: true,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showExceptionModal() {
    final notifier = ref.read(activePickupProvider(widget.task).notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(CereloSpacing.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Report Pickup Exception',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: CereloColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the operational reason preventing parcel pickup.',
                style: TextStyle(
                  fontSize: 12,
                  color: CereloColors.textSecondary,
                ),
              ),
              const SizedBox(height: CereloSpacing.md),
              _OutcomeTile(
                title: 'Sender Unavailable at Address',
                subtitle: 'Sender not present and unreachable by phone.',
                icon: Icons.person_off_outlined,
                color: CereloColors.warning,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await notifier.recordException(
                    reason: 'SENDER_UNAVAILABLE',
                  );
                  if (success && mounted) Navigator.of(context).pop();
                },
              ),
              _OutcomeTile(
                title: 'Prohibited / Unacceptable Items',
                subtitle:
                    'Parcel violates Cerelo safety policy or packaging guidelines.',
                icon: Icons.block_rounded,
                color: CereloColors.error,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await notifier.recordException(
                    reason: 'UNACCEPTABLE_PARCEL',
                  );
                  if (success && mounted) Navigator.of(context).pop();
                },
              ),
              _OutcomeTile(
                title: 'Sender Rejected Price Correction',
                subtitle:
                    'Sender refused adjusted fee for verified parcel size.',
                icon: Icons.price_change_rounded,
                color: CereloColors.error,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await notifier.recordException(
                    reason: 'PRICE_REJECTED',
                  );
                  if (success && mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickupState = ref.watch(activePickupProvider(widget.task));
    final notifier = ref.read(activePickupProvider(widget.task).notifier);
    final task = pickupState.task;

    final requiresSenderPayment = task.paymentMode != PaymentMode.receiverPays;
    final senderDueAmount = task.paymentMode == PaymentMode.splitPayment
        ? Money.fromKobo(task.finalPrice.kobo ~/ 2)
        : task.finalPrice;

    final isClaimed = pickupState.isClaimed;

    final canConfirm = isClaimed &&
        pickupState.isReceiverVerified &&
        (!requiresSenderPayment || pickupState.isPaymentCollected) &&
        !pickupState.isSubmitting;

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: Text('Pickup: ${task.originCity} → ${task.destinationCity}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CereloSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error banner if any
              if (pickupState.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: CereloSpacing.md),
                  padding: const EdgeInsets.all(CereloSpacing.md),
                  decoration: BoxDecoration(
                    color: CereloColors.errorLight,
                    borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: CereloColors.error, size: 20),
                      const SizedBox(width: CereloSpacing.sm),
                      Expanded(
                        child: Text(
                          pickupState.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CereloColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Unclaimed Warning & Accept Button
              if (!isClaimed) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: CereloSpacing.md),
                  padding: const EdgeInsets.all(CereloSpacing.md),
                  decoration: BoxDecoration(
                    color: CereloColors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                    border: Border.all(color: CereloColors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: CereloColors.orangeDark, size: 20),
                          SizedBox(width: CereloSpacing.sm),
                          Text(
                            'Task Unassigned in Hub Queue',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: CereloColors.orangeDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You must accept this pickup task before you can inspect the parcel or record payments.',
                        style: TextStyle(
                          fontSize: 12,
                          color: CereloColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CereloSpacing.md),
                      CereloButton(
                        label: 'Accept Pickup Task',
                        variant: CereloButtonVariant.primary,
                        isLoading: pickupState.isSubmitting,
                        leadingIcon: Icons.check_circle_rounded,
                        onPressed: () => notifier.acceptPickup(),
                      ),
                    ],
                  ),
                ),
              ],

              // Section 1: Sender & Pickup Location
              _SectionCard(
                title: 'Sender & Pickup Location',
                icon: Icons.location_on_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            task.senderName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: CereloColors.navy,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _makePhoneCall(task.senderPhone),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: Text(task.senderPhone),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CereloSpacing.xs),
                    Text(
                      task.senderPickupAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CereloColors.textPrimary,
                      ),
                    ),
                    if (task.landmark != null && task.landmark!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Landmark: ${task.landmark}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CereloColors.textSecondary,
                        ),
                      ),
                    ],
                    if (task.deliveryInstructions != null &&
                        task.deliveryInstructions!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Instructions: ${task.deliveryInstructions}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: CereloColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.md),

              // Section 2: Mandatory Receiver Phone Verification
              _SectionCard(
                title: 'Step 1: Receiver Verification Call',
                icon: Icons.phone_in_talk_outlined,
                badge: pickupState.isReceiverVerified
                    ? const _StatusPill(
                        label: 'VERIFIED',
                        color: CereloColors.success,
                        icon: Icons.check_circle_rounded,
                      )
                    : const _StatusPill(
                        label: 'MANDATORY',
                        color: CereloColors.warning,
                        icon: Icons.error_outline_rounded,
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receiver: ${task.receiverName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: CereloColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Destination: ${task.receiverDeliveryAddress}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CereloColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => _makePhoneCall(task.receiverPhone),
                          icon: const Icon(Icons.phone_forwarded_rounded,
                              size: 18),
                          tooltip: 'Call Receiver Now',
                        ),
                      ],
                    ),
                    const SizedBox(height: CereloSpacing.md),
                    CereloButton(
                      label: pickupState.isReceiverVerified
                          ? 'Verification Recorded (Verified)'
                          : 'Record Receiver Call Outcome',
                      variant: pickupState.isReceiverVerified
                          ? CereloButtonVariant.outlined
                          : CereloButtonVariant.primary,
                      leadingIcon: Icons.playlist_add_check_rounded,
                      onPressed: isClaimed
                          ? _showReceiverVerificationModal
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.md),

              // Section 3: Physical Inspection & Parcel Size
              _SectionCard(
                title: 'Step 2: Inspect & Verify Parcel Size',
                icon: Icons.scale_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contents: ${task.categoryDescription}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sender Estimate: ${task.declaredSizeName} (${task.quotedPrice.formatted})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CereloColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CereloSpacing.sm),
                    const Text(
                      'Select verified size tier:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SizeChoiceChip(
                          label: 'Small',
                          isSelected:
                              pickupState.verifiedSize == ParcelSize.small,
                          onSelected: isClaimed
                              ? () =>
                                  notifier.updateParcelSize(ParcelSize.small)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _SizeChoiceChip(
                          label: 'Medium',
                          isSelected:
                              pickupState.verifiedSize == ParcelSize.medium,
                          onSelected: isClaimed
                              ? () =>
                                  notifier.updateParcelSize(ParcelSize.medium)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _SizeChoiceChip(
                          label: 'Large',
                          isSelected:
                              pickupState.verifiedSize == ParcelSize.large,
                          onSelected: isClaimed
                              ? () =>
                                  notifier.updateParcelSize(ParcelSize.large)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.md),

              // Section 4: Physical Payment Collection
              _SectionCard(
                title: 'Step 3: Physical Cash Payment',
                icon: Icons.payments_outlined,
                badge: (!requiresSenderPayment || pickupState.isPaymentCollected)
                    ? const _StatusPill(
                        label: 'SATISFIED',
                        color: CereloColors.success,
                        icon: Icons.check_circle_rounded,
                      )
                    : const _StatusPill(
                        label: 'PENDING',
                        color: CereloColors.orange,
                        icon: Icons.schedule_rounded,
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mode: ${task.paymentMode.displayLabel}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CereloColors.navy,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total: ${task.finalPrice.formatted}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: CereloColors.navy,
                              ),
                            ),
                            if (task.quotedPrice.kobo != task.finalPrice.kobo)
                              Text(
                                'Quote: ${task.quotedPrice.formatted}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CereloColors.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: CereloSpacing.xs),
                    Text(
                      requiresSenderPayment
                          ? (task.paymentMode == PaymentMode.splitPayment
                              ? 'Collect from Sender now: ${senderDueAmount.formatted} Cash (50% Split — Receiver pays ${Money.fromKobo(task.finalPrice.kobo - senderDueAmount.kobo).formatted} at delivery)'
                              : 'Collect from Sender now: ${senderDueAmount.formatted} Cash (Full Fare)')
                          : 'Receiver pays full ${task.finalPrice.formatted} at delivery (₦0 from sender).',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: requiresSenderPayment
                            ? CereloColors.orangeDark
                            : CereloColors.success,
                      ),
                    ),
                    if (!pickupState.isPaymentCollected) ...[
                      const SizedBox(height: CereloSpacing.sm),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Adjust Final Agreed Fare'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CereloColors.navy,
                          side: const BorderSide(color: CereloColors.border),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onPressed: isClaimed
                            ? () => _showAdjustFareModal(task.finalPrice)
                            : null,
                      ),
                    ],
                    if (requiresSenderPayment &&
                        !pickupState.isPaymentCollected) ...[
                      const SizedBox(height: CereloSpacing.md),
                      CereloButton(
                        label:
                            'Record ${senderDueAmount.formatted} Cash Collected',
                        variant: CereloButtonVariant.primary,
                        leadingIcon: Icons.payments_rounded,
                        onPressed: isClaimed
                            ? () =>
                                _showPaymentConfirmModal(senderDueAmount)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.xl),

              // Primary Action: Confirm Parcel
              CereloButton(
                label: 'Confirm Parcel & Accept Custody',
                variant: CereloButtonVariant.primary,
                isLoading: pickupState.isSubmitting,
                onPressed: canConfirm
                    ? () async {
                        final success = await notifier.confirmParcel();
                        final updatedResult =
                            ref.read(activePickupProvider(widget.task)).confirmedResult;
                        if (success &&
                            updatedResult != null &&
                            context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => ParcelConfirmedSuccessScreen(
                                result: updatedResult,
                                task: task,
                              ),
                            ),
                          );
                        }
                      }
                    : null,
              ),

              const SizedBox(height: CereloSpacing.md),

              if (isClaimed)
                Center(
                  child: TextButton.icon(
                    onPressed: _showExceptionModal,
                    icon: const Icon(
                      Icons.report_problem_outlined,
                      size: 16,
                      color: CereloColors.textTertiary,
                    ),
                    label: const Text(
                      'Report Exception / Cannot Complete Pickup',
                      style: TextStyle(
                        fontSize: 12,
                        color: CereloColors.textSecondary,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.badge,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.white,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: CereloColors.navy),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: CereloColors.navy,
                    ),
                  ),
                ],
              ),
              if (badge != null) badge!,
            ],
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CereloSpacing.sm),
      decoration: BoxDecoration(
        color: CereloColors.surfaceVariant,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: CereloColors.navy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: CereloColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SizeChoiceChip extends StatelessWidget {
  const _SizeChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? CereloColors.navy
                : CereloColors.surfaceVariant,
            borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
            border: Border.all(
              color: isSelected ? CereloColors.navy : CereloColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? CereloColors.white : CereloColors.navy,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}
