import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:customer_app/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal dialog for sharing a canonical tracking link with the Receiver.
class ShareShipmentDialog extends StatelessWidget {
  const ShareShipmentDialog({
    super.key,
    required this.shipment,
  });

  final ShipmentDto shipment;

  static void show(BuildContext context, ShipmentDto shipment) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (_) => ShareShipmentDialog(shipment: shipment),
    );
  }

  void _copyLink(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracking link copied to clipboard.'),
        backgroundColor: CereloColors.navy,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyShareMessage(BuildContext context, String url) {
    final message =
        'A Cerelo package is being delivered to you on the ${shipment.originCity} ↔ ${shipment.destinationCity} corridor.\nView delivery status: $url';
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share message copied for WhatsApp/SMS.'),
        backgroundColor: CereloColors.navy,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingBaseUrl = AppConfig.fromEnvironment().trackingBaseUrl;
    final hasDeliveryCode = shipment.deliveryCode != null &&
        shipment.deliveryCode!.isNotEmpty;
    final canonicalUrl = hasDeliveryCode
        ? '$trackingBaseUrl/track/${shipment.deliveryCode}'
        : '';

    return Padding(
      padding: const EdgeInsets.all(CereloSpacing.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Share Delivery with Receiver',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: CereloColors.navy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: CereloSpacing.xs),

          const Text(
            'The receiver can open this secure link to view verified status updates from origin to doorstep.',
            style: TextStyle(
              fontSize: 13,
              color: CereloColors.textSecondary,
              height: 1.35,
            ),
          ),

          const SizedBox(height: CereloSpacing.lg),

          if (!hasDeliveryCode)
            Container(
              padding: const EdgeInsets.all(CereloSpacing.md),
              decoration: BoxDecoration(
                color: CereloColors.surfaceVariant,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                border: Border.all(color: CereloColors.border),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: CereloColors.navy,
                    size: 22,
                  ),
                  SizedBox(width: CereloSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          'Tracking link will be generated once personnel confirms the package at pickup.',
                          style: TextStyle(
                            fontSize: 11,
                            color: CereloColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Share URL Display Card
            Container(
              padding: const EdgeInsets.all(CereloSpacing.md),
              decoration: BoxDecoration(
                color: CereloColors.surfaceVariant,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                border: Border.all(color: CereloColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    color: CereloColors.navy,
                    size: 22,
                  ),
                  const SizedBox(width: CereloSpacing.sm),
                  Expanded(
                    child: Text(
                      canonicalUrl,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.navy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: 'Copy Link',
                    onPressed: () => _copyLink(context, canonicalUrl),
                  ),
                ],
              ),
            ),

            const SizedBox(height: CereloSpacing.md),

            // Share Actions
            CereloButton(
              label: 'Copy Message for WhatsApp / SMS',
              variant: CereloButtonVariant.primary,
              leadingIcon: Icons.chat_outlined,
              onPressed: () => _copyShareMessage(context, canonicalUrl),
            ),

            const SizedBox(height: CereloSpacing.sm),

            CereloButton(
              label: 'Copy Link Only',
              variant: CereloButtonVariant.outlined,
              leadingIcon: Icons.link_rounded,
              onPressed: () => _copyLink(context, canonicalUrl),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
