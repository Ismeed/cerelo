import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/delivery_provider.dart';

/// Operational workspace for a single final-mile doorstep delivery task.
class DeliveryDetailScreen extends ConsumerStatefulWidget {
  const DeliveryDetailScreen({super.key, required this.task});

  final DeliveryTaskDto task;

  @override
  ConsumerState<DeliveryDetailScreen> createState() =>
      _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends ConsumerState<DeliveryDetailScreen> {
  late bool _isOutForDelivery;
  late bool _isPaymentCollected;
  bool _isDelivered = false;
  bool _isSenderCallRecorded = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isOutForDelivery = widget.task.status == ShipmentStatus.outForDelivery;
    _isPaymentCollected = !widget.task.requiresReceiverPayment ||
        widget.task.receiverPaymentStatus == PaymentStatus.collected;
  }

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

  Future<void> _startFinalDelivery() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelDeliveryServiceProvider);
      await service.startFinalDelivery(widget.task.shipmentId);

      ref.invalidate(readyForDeliveryQueueProvider);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isOutForDelivery = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Final delivery started. Shipment is Out for Delivery.'),
            backgroundColor: CereloColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              e is CereloApiError ? e.message : 'Could not start delivery.';
        });
      }
    }
  }

  void _showPaymentConfirmModal(Money amount) {
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
                'Confirm that you have physically collected ${amount.formatted} cash payment from the Receiver.',
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
                  await _recordPayment(amount, method: 'CASH');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _recordPayment(Money amount, {required String method}) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelDeliveryServiceProvider);
      await service.recordReceiverPayment(
        shipmentId: widget.task.shipmentId,
        amount: amount,
        method: method,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isPaymentCollected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receiver cash payment recorded successfully.'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              e is CereloApiError ? e.message : 'Could not record payment.';
        });
      }
    }
  }

  Future<void> _markDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Handover & Delivery'),
        content: Text(
          'Confirm that you have physically handed over the parcel to ${widget.task.receiverName}.\n\nThis will mark the shipment as DELIVERED in Cerelo records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CereloColors.navy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Delivered'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelDeliveryServiceProvider);
      await service.markDelivered(shipmentId: widget.task.shipmentId);

      ref.invalidate(readyForDeliveryQueueProvider);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isDelivered = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Parcel marked DELIVERED! Please call Sender from doorstep.'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              e is CereloApiError ? e.message : 'Could not mark delivered.';
        });
      }
    }
  }

  Future<void> _recordSenderCall(String outcome) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelDeliveryServiceProvider);
      await service.recordSenderCompletionCall(
        shipmentId: widget.task.shipmentId,
        outcome: outcome,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSenderCallRecorded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sender completion call recorded.'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Could not record sender call outcome.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: Text('Deliver: ${task.receiverName}'),
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
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: CereloSpacing.md),
                  padding: const EdgeInsets.all(CereloSpacing.md),
                  decoration: BoxDecoration(
                    color: CereloColors.errorLight,
                    borderRadius:
                        BorderRadius.circular(CereloSpacing.radiusMd),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CereloColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Section 1: Receiver & Destination Address
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            task.receiverName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: CereloColors.navy,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _makePhoneCall(task.receiverPhone),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: Text(task.receiverPhone),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.receiverDeliveryAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.textPrimary,
                      ),
                    ),
                    if (task.landmark != null && task.landmark!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Landmark: ${task.landmark}',
                        style: const TextStyle(
                            fontSize: 12, color: CereloColors.textSecondary),
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
                            color: CereloColors.textSecondary),
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Size: ${task.confirmedSizeName}',
                          style: const TextStyle(
                              fontSize: 12, color: CereloColors.textSecondary),
                        ),
                        Text(
                          'Code: ${task.deliveryCode}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.md),

              // STEP 1: Going for Delivery
              if (!_isOutForDelivery && !_isDelivered) ...[
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
                      const Text(
                        'Step 1: Start Final Delivery',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: CereloColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to claim parcel and begin doorstep delivery run.',
                        style: TextStyle(
                            fontSize: 11, color: CereloColors.textSecondary),
                      ),
                      const SizedBox(height: CereloSpacing.md),
                      CereloButton(
                        label: 'Start Doorstep Delivery',
                        variant: CereloButtonVariant.primary,
                        isLoading: _isProcessing,
                        leadingIcon: Icons.two_wheeler_rounded,
                        onPressed: _startFinalDelivery,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CereloSpacing.md),
              ],

              // STEP 2: Physical Receiver Payment
              if (_isOutForDelivery && !_isDelivered) ...[
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Step 2: Receiver Payment',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: CereloColors.navy,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isPaymentCollected
                                  ? CereloColors.success.withOpacity(0.12)
                                  : CereloColors.orange.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(CereloSpacing.radiusSm),
                            ),
                            child: Text(
                              _isPaymentCollected ? 'COLLECTED' : 'CASH DUE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _isPaymentCollected
                                    ? CereloColors.success
                                    : CereloColors.orangeDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.requiresReceiverPayment
                            ? 'Amount to collect from Receiver: ${task.receiverDueAmount.formatted} Cash'
                            : 'No payment due (Sender paid full fee at pickup).',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: task.requiresReceiverPayment
                              ? CereloColors.orangeDark
                              : CereloColors.success,
                        ),
                      ),
                      if (task.requiresReceiverPayment &&
                          !_isPaymentCollected) ...[
                        const SizedBox(height: CereloSpacing.md),
                        CereloButton(
                          label:
                              'Record ${task.receiverDueAmount.formatted} Cash Collected',
                          variant: CereloButtonVariant.primary,
                          leadingIcon: Icons.payments_rounded,
                          onPressed: () =>
                              _showPaymentConfirmModal(task.receiverDueAmount),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: CereloSpacing.md),

                // STEP 3: Physical Handover & Mark Delivered
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
                      const Text(
                        'Step 3: Physical Handover',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: CereloColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Physically hand the parcel to the recipient before confirming delivery.',
                        style: TextStyle(
                            fontSize: 11, color: CereloColors.textSecondary),
                      ),
                      const SizedBox(height: CereloSpacing.md),
                      CereloButton(
                        label: 'Confirm Handover & Mark Delivered',
                        variant: CereloButtonVariant.primary,
                        isLoading: _isProcessing,
                        leadingIcon: Icons.verified_rounded,
                        onPressed:
                            _isPaymentCollected ? _markDelivered : null,
                      ),
                    ],
                  ),
                ),
              ],

              // STEP 4: Mandatory Sender Completion Call (LOCKED SOP)
              if (_isDelivered) ...[
                Container(
                  padding: const EdgeInsets.all(CereloSpacing.md),
                  decoration: BoxDecoration(
                    color: CereloColors.success.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(CereloSpacing.radiusMd),
                    border:
                        Border.all(color: CereloColors.success.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: CereloColors.success, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Parcel Successfully Delivered!',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: CereloColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CereloSpacing.md),
                      const Text(
                        'MANDATORY DOORSTEP SOP:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: CereloColors.navy,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Call Sender (${task.senderName}: ${task.senderPhone}) immediately from Receiver\'s doorstep to confirm successful delivery.',
                        style: const TextStyle(
                            fontSize: 12, color: CereloColors.textSecondary),
                      ),
                      const SizedBox(height: CereloSpacing.md),
                      if (!_isSenderCallRecorded) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _makePhoneCall(task.senderPhone),
                                icon: const Icon(Icons.phone_rounded, size: 16),
                                label: Text(task.senderPhone),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CereloSpacing.sm),
                        const Text(
                          'Record Call Outcome:',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    _recordSenderCall('REACHED_AND_CONFIRMED'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CereloColors.success,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Reached & Confirmed'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _recordSenderCall('NO_ANSWER'),
                                child: const Text('No Answer'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(CereloSpacing.sm),
                          decoration: BoxDecoration(
                            color: CereloColors.white,
                            borderRadius:
                                BorderRadius.circular(CereloSpacing.radiusSm),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.done_all_rounded,
                                  color: CereloColors.success, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Doorstep sender confirmation call recorded.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CereloColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
