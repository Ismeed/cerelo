import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shipments_provider.dart';

/// Modal dialog for cancelling an in-custody shipment (Cancel Delivery).
///
/// Prompts the customer for a controlled cancellation reason and explains
/// the return/release process since CERELO already physically holds the parcel.
class CancelDeliveryDialog extends ConsumerStatefulWidget {
  const CancelDeliveryDialog({
    super.key,
    required this.shipment,
  });

  final ShipmentDto shipment;

  static Future<bool?> show(BuildContext context, ShipmentDto shipment) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (_) => CancelDeliveryDialog(shipment: shipment),
    );
  }

  @override
  ConsumerState<CancelDeliveryDialog> createState() =>
      _CancelDeliveryDialogState();
}

class _CancelDeliveryDialogState extends ConsumerState<CancelDeliveryDialog> {
  static const _reasons = [
    'No longer needed',
    'Incorrect shipment details',
    'Receiver unavailable',
    'Sender changed mind',
    'Other',
  ];

  String _selectedReason = _reasons.first;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitCancellation() async {
    if (_isSubmitting) return;

    if (_selectedReason == 'Other' &&
        _detailsController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please provide a brief explanation for "Other".';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(shipmentServiceProvider);
      final success = await service.cancelShipment(
        shipmentId: widget.shipment.id,
        reason: _selectedReason,
        reasonDetails: _selectedReason == 'Other'
            ? _detailsController.text.trim()
            : null,
      );

      if (mounted) {
        if (success) {
          ref.invalidate(shipmentDetailProvider(widget.shipment.id));
          ref.invalidate(customerActiveShipmentsProvider);
          ref.invalidate(customerShipmentsProvider);
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = 'Could not cancel delivery. Please try again.';
          });
        }
      }
    } on CereloApiError catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to cancel: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: CereloSpacing.pagePadding,
        right: CereloSpacing.pagePadding,
        top: CereloSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + CereloSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cancel this delivery?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CereloColors.navy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: CereloSpacing.sm),
            Container(
              padding: const EdgeInsets.all(CereloSpacing.md),
              decoration: BoxDecoration(
                color: CereloColors.surfaceVariant,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                border: Border.all(color: CereloColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: CereloColors.navy,
                    size: 20,
                  ),
                  SizedBox(width: CereloSpacing.sm),
                  Expanded(
                    child: Text(
                      'CERELO has already received this parcel. You can cancel before it begins intercity transit. Our team will arrange the appropriate return/release process.',
                      style: TextStyle(
                        fontSize: 12,
                        color: CereloColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CereloSpacing.md),
            const Text(
              'Reason for cancellation',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
            ),
            const SizedBox(height: CereloSpacing.xs),
            ..._reasons.map((reason) {
              return RadioListTile<String>(
                title: Text(
                  reason,
                  style: const TextStyle(fontSize: 14, color: CereloColors.textPrimary),
                ),
                value: reason,
                groupValue: _selectedReason,
                activeColor: CereloColors.orange,
                contentPadding: EdgeInsets.zero,
                dense: true,
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() {
                            _selectedReason = val;
                            _errorMessage = null;
                          });
                        }
                      },
              );
            }),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: CereloSpacing.xs),
              CereloTextField(
                label: 'Explain reason',
                controller: _detailsController,
                maxLines: 2,
                hintText: 'Provide brief details...',
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: CereloSpacing.sm),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: CereloColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: CereloSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: CereloColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                      ),
                    ),
                    child: const Text(
                      'Keep Delivery',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: CereloColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: CereloSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitCancellation,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: CereloColors.error,
                      foregroundColor: CereloColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(CereloColors.white),
                            ),
                          )
                        : const Text(
                            'Cancel Delivery',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
