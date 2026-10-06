import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';

/// Reusable Customer Shipment Card.
///
/// Used on both Home (active/recent sections) and the Shipments list screen.
/// Displays sanitized customer-facing information:
/// - Route (e.g. Kano → Katsina)
/// - Delivery Code (e.g. CRL-8F2K-9P3N)
/// - Relationship badge (SENT / RECEIVED)
/// - Customer status badge
/// - Counterpart name (To: Receiver / From: Sender)
/// - Date & Price
class ShipmentCard extends StatelessWidget {
  const ShipmentCard({
    super.key,
    required this.shipment,
    required this.currentUserId,
    required this.onTap,
    this.isCompact = false,
  });

  final ShipmentDto shipment;
  final String? currentUserId;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isSender = shipment.isSender(currentUserId);
    final relationshipLabel = shipment.relationshipBadge(currentUserId);
    final counterpart = shipment.counterpartLabel(currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.white,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(CereloSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Route & Status Badge
                Row(
                  children: [
                    // Route with directional indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shipment.originCity,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CereloColors.navy,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: CereloColors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          shipment.destinationCity,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CereloColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Relationship Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSender
                            ? CereloColors.navy.withOpacity(0.08)
                            : CereloColors.orange.withOpacity(0.12),
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusSm),
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
                    const SizedBox(width: CereloSpacing.xs),
                    // Status Badge
                    CereloStatusBadge(status: shipment.status),
                  ],
                ),

                const SizedBox(height: CereloSpacing.sm),

                // Middle Row: Delivery Code & Counterpart
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (shipment.deliveryCode != null &&
                        shipment.deliveryCode!.isNotEmpty)
                      Text(
                        shipment.deliveryCode!,
                        style: CereloTextStyles.deliveryCode.copyWith(
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      )
                    else
                      const Text(
                        'Code Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CereloColors.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    Text(
                      counterpart,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                if (!isCompact) ...[
                  const SizedBox(height: CereloSpacing.sm),
                  const Divider(height: 1),
                  const SizedBox(height: CereloSpacing.sm),

                  // Bottom Row: Date & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        shipment.formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CereloColors.textTertiary,
                        ),
                      ),
                      Text(
                        shipment.finalPrice.formatted,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CereloColors.navy,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
