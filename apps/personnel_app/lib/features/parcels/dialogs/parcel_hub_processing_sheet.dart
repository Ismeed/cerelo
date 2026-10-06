import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hub_provider.dart';
import '../widgets/parcel_label_sheet.dart';

/// Modal bottom sheet for origin-hub parcel receiving and label printing.
class ParcelHubProcessingSheet extends ConsumerStatefulWidget {
  const ParcelHubProcessingSheet({
    super.key,
    required this.parcel,
  });

  final ResolvedParcelDto parcel;

  static void show(BuildContext context, ResolvedParcelDto parcel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (_) => ParcelHubProcessingSheet(parcel: parcel),
    );
  }

  @override
  ConsumerState<ParcelHubProcessingSheet> createState() =>
      _ParcelHubProcessingSheetState();
}

class _ParcelHubProcessingSheetState
    extends ConsumerState<ParcelHubProcessingSheet> {
  bool _isReceiving = false;
  late ResolvedParcelDto _currentParcel;

  @override
  void initState() {
    super.initState();
    _currentParcel = widget.parcel;
  }

  Future<void> _receiveAtHub() async {
    setState(() => _isReceiving = true);

    try {
      final service = ref.read(personnelHubServiceProvider);
      final success =
          await service.receiveParcelAtOriginHub(_currentParcel.parcelId);

      if (mounted) {
        setState(() {
          _isReceiving = false;
          if (success) {
            _currentParcel = ResolvedParcelDto(
              parcelId: _currentParcel.parcelId,
              shipmentId: _currentParcel.shipmentId,
              deliveryCode: _currentParcel.deliveryCode,
              parcelQrToken: _currentParcel.parcelQrToken,
              currentParcelState: ParcelState.originHubStaged,
              currentStatus: ShipmentStatus.atOriginHub,
              originCity: _currentParcel.originCity,
              destinationCity: _currentParcel.destinationCity,
              senderName: _currentParcel.senderName,
              receiverName: _currentParcel.receiverName,
              confirmedSizeCode: _currentParcel.confirmedSizeCode,
              confirmedSizeName: _currentParcel.confirmedSizeName,
              categoryDescription: _currentParcel.categoryDescription,
              finalPrice: _currentParcel.finalPrice,
              paymentMode: _currentParcel.paymentMode,
              isHubReceived: true,
              isReadyForBatch: true,
            );
          }
        });

        ref.invalidate(readyForBatchParcelsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Parcel physically received at Origin Hub and ready for Batch.',
            ),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReceiving = false);
        final msg =
            e is CereloApiError ? e.message : 'Could not receive parcel at hub.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: CereloColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _currentParcel;

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
                'Hub Parcel Processing',
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

          // Route & Status Header
          Container(
            padding: const EdgeInsets.all(CereloSpacing.md),
            decoration: BoxDecoration(
              color: CereloColors.surfaceVariant,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              border: Border.all(color: CereloColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.routeDisplay,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: CereloColors.navy,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.isHubReceived
                            ? CereloColors.success.withOpacity(0.12)
                            : CereloColors.orange.withOpacity(0.12),
                        borderRadius:
                            BorderRadius.circular(CereloSpacing.radiusSm),
                      ),
                      child: Text(
                        p.isHubReceived
                            ? 'STAGED AT ORIGIN HUB'
                            : 'IN PERSONNEL CUSTODY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: p.isHubReceived
                              ? CereloColors.success
                              : CereloColors.orangeDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Delivery Code:',
                      style: TextStyle(
                        fontSize: 12,
                        color: CereloColors.textSecondary,
                      ),
                    ),
                    Text(
                      p.deliveryCode,
                      style: CereloTextStyles.deliveryCode.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verified Size:',
                      style: TextStyle(
                        fontSize: 12,
                        color: CereloColors.textSecondary,
                      ),
                    ),
                    Text(
                      p.confirmedSizeName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.lg),

          // Action 1: Receive at Origin Hub
          if (!p.isHubReceived) ...[
            CereloButton(
              label: 'Receive at Origin Hub',
              variant: CereloButtonVariant.primary,
              isLoading: _isReceiving,
              leadingIcon: Icons.storefront_rounded,
              onPressed: _receiveAtHub,
            ),
            const SizedBox(height: CereloSpacing.sm),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(CereloSpacing.md),
              decoration: BoxDecoration(
                color: CereloColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: CereloColors.success,
                    size: 20,
                  ),
                  SizedBox(width: CereloSpacing.sm),
                  Expanded(
                    child: Text(
                      'Parcel is staged and ready for Batch consolidation.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CereloSpacing.sm),
          ],

          // Action 2: Print Label
          CereloButton(
            label: 'Print / View Parcel Label',
            variant: CereloButtonVariant.outlined,
            leadingIcon: Icons.qr_code_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              ParcelLabelSheet.show(context, p);
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
