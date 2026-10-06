import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';
import '../theme/cerelo_spacing.dart';
import '../theme/cerelo_text_styles.dart';

/// Displays a Cerelo shipment status as a colored badge.
class CereloStatusBadge extends StatelessWidget {
  const CereloStatusBadge({super.key, required this.status});

  final ShipmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = _statusColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CereloSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
      ),
      child: Text(
        status.displayLabel,
        style: CereloTextStyles.labelMd.copyWith(color: textColor),
      ),
    );
  }

  (Color, Color) _statusColors(ShipmentStatus status) {
    return switch (status) {
      ShipmentStatus.requested => (CereloColors.infoLight, CereloColors.info),
      ShipmentStatus.parcelConfirmed => (CereloColors.infoLight, CereloColors.info),
      ShipmentStatus.atOriginHub => (CereloColors.warningLight, CereloColors.warning),
      ShipmentStatus.inTransit => (CereloColors.warningLight, CereloColors.warning),
      ShipmentStatus.arrivedDestination => (CereloColors.warningLight, CereloColors.warning),
      ShipmentStatus.outForDelivery => (CereloColors.warningLight, CereloColors.orangeDark),
      ShipmentStatus.delivered => (CereloColors.successLight, CereloColors.success),
      ShipmentStatus.deliveryFailed => (CereloColors.errorLight, CereloColors.error),
      ShipmentStatus.cancelled => (CereloColors.surfaceVariant, CereloColors.textTertiary),
    };
  }
}
