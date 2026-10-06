import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'batch_receive_sheet.dart';

/// Modal bottom sheet displaying limited operational transport-arrival metadata
/// for incoming in-transit batches. Strictly conceals Batch Reference and QR tokens
/// until physical verification.
class InboundTransportDetailSheet extends StatelessWidget {
  const InboundTransportDetailSheet({
    super.key,
    required this.batch,
  });

  final BatchSummaryDto batch;

  static Future<void> show(BuildContext context, {required BatchSummaryDto batch}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InboundTransportDetailSheet(batch: batch),
    );
  }

  Future<void> _callDriver(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer for $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CereloColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(CereloSpacing.radiusLg)),
      ),
      padding: EdgeInsets.only(
        top: CereloSpacing.md,
        left: CereloSpacing.pagePadding,
        right: CereloSpacing.pagePadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + CereloSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CereloColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: CereloSpacing.md),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.routeDisplay,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CereloColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Inbound Corridor Transport',
                    style: TextStyle(fontSize: 12, color: CereloColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CereloColors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                ),
                child: const Text(
                  'INCOMING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: CereloColors.orangeDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: CereloSpacing.md),

          // Operational Details Card (ZERO Batch Reference / Zero QR leaked)
          Container(
            padding: const EdgeInsets.all(CereloSpacing.md),
            decoration: BoxDecoration(
              color: CereloColors.surfaceVariant,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              border: Border.all(color: CereloColors.border),
            ),
            child: Column(
              children: [
                _buildInfoRow('Origin Hub', '${batch.originCity} (${batch.originHubCode ?? "Origin"})'),
                const Divider(height: 14),
                _buildInfoRow('Destination Hub', '${batch.destinationCity} (${batch.destinationHubCode ?? "Destination"})'),
                const Divider(height: 14),
                _buildInfoRow('Current State', 'In Transit on Corridor'),
                const Divider(height: 14),
                _buildInfoRow('Expected Parcels', '${batch.manifestParcelCount} Parcels'),
                if (batch.actualDepartureAt != null) ...[
                  const Divider(height: 14),
                  _buildInfoRow(
                    'Departed At',
                    '${batch.actualDepartureAt!.hour.toString().padLeft(2, "0")}:${batch.actualDepartureAt!.minute.toString().padLeft(2, "0")}',
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.md),

          // Driver & Vehicle Card
          Container(
            padding: const EdgeInsets.all(CereloSpacing.md),
            decoration: BoxDecoration(
              color: CereloColors.white,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              border: Border.all(color: CereloColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_bus_rounded, size: 18, color: CereloColors.orange),
                    SizedBox(width: 6),
                    Text(
                      'Middle-Mile Transport Partner',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CereloSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.driverName ?? 'Commercial Driver',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CereloColors.textPrimary,
                          ),
                        ),
                        if (batch.driverPhone != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            batch.driverPhone!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: CereloColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (batch.driverPhone != null)
                      ElevatedButton.icon(
                        onPressed: () => _callDriver(context, batch.driverPhone!),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                        label: const Text('Call Driver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CereloColors.success,
                          foregroundColor: CereloColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                if (batch.vehiclePlateNumber != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: CereloColors.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                    ),
                    child: Text(
                      'Vehicle Plate: ${batch.vehiclePlateNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: CereloColors.navy,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.lg),

          // Primary Physical Receipt Action
          CereloButton(
            label: 'Receive Batch',
            variant: CereloButtonVariant.primary,
            leadingIcon: Icons.qr_code_scanner_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              BatchReceiveSheet.show(context);
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'Physical Batch QR or Batch Code required to verify and receive parcel manifest.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: CereloColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: CereloColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: CereloColors.navy,
          ),
        ),
      ],
    );
  }
}
