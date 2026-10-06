import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';

/// Pill badge communicating the active launch corridor (Kano ↔ Katsina).
class CorridorBadge extends StatelessWidget {
  const CorridorBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CereloSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: CereloColors.surfaceVariant,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
        border: Border.all(color: CereloColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.route_rounded,
            size: 16,
            color: CereloColors.navy,
          ),
          SizedBox(width: 6),
          Text(
            'Kano ↔ Katsina',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CereloColors.navy,
            ),
          ),
          SizedBox(width: 6),
          Text(
            '· Intercity Delivery',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CereloColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
