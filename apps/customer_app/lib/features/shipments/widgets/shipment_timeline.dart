import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';

/// Vertical status timeline component for Customer Shipment Details.
///
/// Communicates clear progress along the 6 customer milestones without
/// exposing internal logistics complexities (no Batch numbers, no vehicle details).
class ShipmentTimeline extends StatelessWidget {
  const ShipmentTimeline({
    super.key,
    required this.events,
  });

  final List<ShipmentTimelineEventDto> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineItem(
            event: events[i],
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
  });

  final ShipmentTimelineEventDto event;
  final bool isLast;

  String? _formatTimestamp(DateTime? dt) {
    if (dt == null) return null;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dt.month - 1];
    return '$hour:$minute $ampm · $month ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final timestampStr = _formatTimestamp(event.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Indicator & Connecting Line
          Column(
            children: [
              // Circle Node
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event.isCompleted
                      ? CereloColors.success
                      : (event.isCurrent
                          ? CereloColors.orange
                          : CereloColors.surfaceVariant),
                  border: Border.all(
                    color: event.isCurrent
                        ? CereloColors.orange
                        : (event.isCompleted
                            ? CereloColors.success
                            : CereloColors.border),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: event.isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : (event.isCurrent
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            )
                          : null),
                ),
              ),

              // Connecting Line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: event.isCompleted
                        ? CereloColors.success.withOpacity(0.4)
                        : CereloColors.border,
                  ),
                ),
            ],
          ),

          const SizedBox(width: CereloSpacing.md),

          // Right: Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : CereloSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: event.isCurrent
                              ? FontWeight.w800
                              : (event.isCompleted
                                  ? FontWeight.w700
                                  : FontWeight.w500),
                          color: event.isCurrent
                              ? CereloColors.navy
                              : (event.isCompleted
                                  ? CereloColors.textPrimary
                                  : CereloColors.textTertiary),
                        ),
                      ),
                      if (timestampStr != null && (event.isCompleted || event.isCurrent))
                        Text(
                          timestampStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: event.isCurrent
                                ? CereloColors.orangeDark
                                : CereloColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: event.isCompleted || event.isCurrent
                          ? CereloColors.textSecondary
                          : CereloColors.textTertiary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
