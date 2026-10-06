import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/personnel_router.dart';

/// Screen displayed immediately after successful Confirm Parcel custody transfer.
class ParcelConfirmedSuccessScreen extends StatelessWidget {
  const ParcelConfirmedSuccessScreen({
    super.key,
    required this.result,
    required this.task,
  });

  final ConfirmParcelResultDto result;
  final PickupTaskDto task;

  void _copyDeliveryCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.deliveryCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery Code copied to clipboard.'),
        backgroundColor: CereloColors.navy,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CereloColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CereloSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Success Icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: CereloColors.success.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.verified_rounded,
                      color: CereloColors.success,
                      size: 48,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: CereloSpacing.lg),

              const Text(
                'Parcel Confirmed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: CereloColors.navy,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Physical custody has been accepted into Cerelo operations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: CereloColors.textSecondary,
                ),
              ),

              const SizedBox(height: CereloSpacing.xl),

              // Delivery Code Highlight Card
              Container(
                padding: const EdgeInsets.all(CereloSpacing.lg),
                decoration: BoxDecoration(
                  color: CereloColors.navy,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
                ),
                child: Column(
                  children: [
                    const Text(
                      'DELIVERY CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: CereloSpacing.sm),
                    Text(
                      result.deliveryCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 3.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: CereloSpacing.sm),
                    GestureDetector(
                      onTap: () => _copyDeliveryCode(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CereloSpacing.md,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(CereloSpacing.radiusFull),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Copy Code for Sender',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.md),

              // Operational Next Steps Card
              Container(
                padding: const EdgeInsets.all(CereloSpacing.md),
                decoration: BoxDecoration(
                  color: CereloColors.white,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                  border: Border.all(color: CereloColors.border),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Verified Size',
                      value: result.confirmedSizeName,
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Route',
                      value: task.routeDisplay,
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Final Fee',
                      value: result.finalPrice.formatted,
                      valueStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CereloColors.navy,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.md),

              // Next Instruction
              Container(
                padding: const EdgeInsets.all(CereloSpacing.md),
                decoration: BoxDecoration(
                  color: CereloColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      color: CereloColors.navy,
                      size: 22,
                    ),
                    SizedBox(width: CereloSpacing.sm),
                    Expanded(
                      child: Text(
                        'Next Step: Transport parcel to origin Cerelo hub for manifest sorting.',
                        style: TextStyle(
                          fontSize: 12,
                          color: CereloColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Primary Action: Back to Tasks
              CereloButton(
                label: 'Back to Pickup Tasks',
                variant: CereloButtonVariant.primary,
                onPressed: () {
                  context.go(PersonnelRoutes.pickup);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CereloColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
        ),
      ],
    );
  }
}
