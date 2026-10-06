import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';

/// Screen displayed immediately after successful server confirmation of a Shipment Request.
///
/// Truthfully communicates:
/// - Request received in "Requested" status.
/// - Next step: Personnel will attend pickup and verify parcel.
/// - No custody transfer has occurred yet.
class SendPackageSuccessScreen extends StatelessWidget {
  const SendPackageSuccessScreen({
    super.key,
    required this.shipment,
  });

  final ShipmentDto shipment;

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

              // Success Icon & Badge
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
                      Icons.check_circle_rounded,
                      color: CereloColors.success,
                      size: 48,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: CereloSpacing.lg),

              const Text(
                'Delivery Request Received!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: CereloColors.navy,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: CereloSpacing.xs),

              const Text(
                'Cerelo field personnel will attend your pickup location to inspect and collect the package.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: CereloColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: CereloSpacing.xl),

              // Shipment Summary Card
              Container(
                padding: const EdgeInsets.all(CereloSpacing.lg),
                decoration: BoxDecoration(
                  color: CereloColors.white,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delivery Code',
                          style: TextStyle(
                            fontSize: 12,
                            color: CereloColors.textSecondary,
                          ),
                        ),
                        if (shipment.deliveryCode != null &&
                            shipment.deliveryCode!.isNotEmpty)
                          Text(
                            shipment.deliveryCode!,
                            style: CereloTextStyles.deliveryCode.copyWith(
                              fontSize: 15,
                            ),
                          )
                        else
                          const Text(
                            'Generated at Pickup',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: CereloColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Route',
                          style: TextStyle(
                            fontSize: 12,
                            color: CereloColors.textSecondary,
                          ),
                        ),
                        Text(
                          shipment.routeDisplay,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CereloColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Initial Status',
                          style: TextStyle(
                            fontSize: 12,
                            color: CereloColors.textSecondary,
                          ),
                        ),
                        CereloStatusBadge(status: shipment.status),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delivery Fee',
                          style: TextStyle(
                            fontSize: 12,
                            color: CereloColors.textSecondary,
                          ),
                        ),
                        Text(
                          shipment.finalPrice.formatted,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: CereloColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.md),

              // Operational notice
              Container(
                padding: const EdgeInsets.all(CereloSpacing.md),
                decoration: BoxDecoration(
                  color: CereloColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: CereloColors.navy,
                    ),
                    SizedBox(width: CereloSpacing.sm),
                    Expanded(
                      child: Text(
                        'Physical cash payment will be recorded during pickup.',
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

              // Primary: View Shipment
              CereloButton(
                label: 'View Shipment',
                variant: CereloButtonVariant.primary,
                onPressed: () {
                  context.go('/shipments/${shipment.id}');
                },
              ),

              const SizedBox(height: CereloSpacing.sm),

              // Secondary: Back to Home
              CereloButton(
                label: 'Back to Home',
                variant: CereloButtonVariant.outlined,
                onPressed: () {
                  context.go(AppRoutes.home);
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
