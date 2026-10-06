import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shipments_provider.dart';

/// Modal dialog for Sender manual Delivery Code verification.
class VerifyDeliveryCodeDialog extends ConsumerStatefulWidget {
  const VerifyDeliveryCodeDialog({
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
      builder: (_) => VerifyDeliveryCodeDialog(shipment: shipment),
    );
  }

  @override
  ConsumerState<VerifyDeliveryCodeDialog> createState() =>
      _VerifyDeliveryCodeDialogState();
}

class _VerifyDeliveryCodeDialogState
    extends ConsumerState<VerifyDeliveryCodeDialog> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the Delivery Code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(shipmentServiceProvider);
      final isValid =
          await service.verifySenderDeliveryCode(widget.shipment.id, code);

      if (mounted) {
        setState(() => _isVerifying = false);
        if (isValid) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery Code verified successfully!'),
              backgroundColor: CereloColors.success,
            ),
          );
          ref.invalidate(shipmentDetailProvider(widget.shipment.id));
        } else {
          setState(() {
            _errorMessage = "That Delivery Code doesn't match this shipment.";
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Verification failed. Please check the code and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: CereloSpacing.pagePadding,
        right: CereloSpacing.pagePadding,
        top: CereloSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Verify Delivery Code',
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
            'Enter the 8-character Delivery Code provided on your parcel tag or by Cerelo personnel.',
            style: TextStyle(
              fontSize: 13,
              color: CereloColors.textSecondary,
              height: 1.35,
            ),
          ),

          const SizedBox(height: CereloSpacing.lg),

          CereloTextField(
            label: 'Delivery Code',
            hintText: 'e.g. CRL-8F2K-9P3N',
            controller: _codeController,
          ),

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

          CereloButton(
            label: 'Verify Code',
            isLoading: _isVerifying,
            onPressed: _verifyCode,
          ),

          const SizedBox(height: CereloSpacing.xl),
        ],
      ),
    );
  }
}
