import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../delivery/providers/delivery_provider.dart';
import '../../delivery/screens/reconciliation_screen.dart';
import '../providers/batch_provider.dart';

/// Modal bottom sheet for receiving an incoming Batch at destination hub.
/// Supports Batch QR scanning and manual Batch Reference fallback.
class BatchReceiveSheet extends ConsumerStatefulWidget {
  const BatchReceiveSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BatchReceiveSheet(),
    );
  }

  @override
  ConsumerState<BatchReceiveSheet> createState() => _BatchReceiveSheetState();
}

class _BatchReceiveSheetState extends ConsumerState<BatchReceiveSheet> {
  final _refController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isManualMode = false;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _scannedIdentifier;
  Map<String, dynamic>? _resolvedBatchData;

  @override
  void dispose() {
    _refController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _resolveBatch(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final batchService = ref.read(personnelBatchServiceProvider);
      final data = await batchService.resolveInboundBatchForReceipt(cleaned);

      if (data == null || data['is_valid'] == false) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'No Batch found matching "$cleaned".';
        });
        return;
      }

      setState(() {
        _isProcessing = false;
        _scannedIdentifier = cleaned;
        _resolvedBatchData = data;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e is CereloApiError ? e.message : 'Failed to resolve Batch.';
      });
    }
  }

  Future<void> _confirmBatchArrival() async {
    if (_resolvedBatchData == null || _scannedIdentifier == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final batchId = _resolvedBatchData!['batch_id'] as String;
      final deliveryService = ref.read(personnelDeliveryServiceProvider);
      
      await deliveryService.receiveDestinationBatch(
        batchIdentifier: _scannedIdentifier!,
        batchId: batchId,
      );

      ref.invalidate(batchesListProvider(null));
      ref.invalidate(batchManifestProvider(batchId));

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReconciliationScreen(batchId: batchId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              e is CereloApiError ? e.message : 'Could not receive batch at destination.';
        });
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Receive Inbound Batch',
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

          const SizedBox(height: 2),
          const Text(
            'Scan the physical Batch container label QR or enter the Batch Reference upon vehicle arrival.',
            style: TextStyle(fontSize: 12, color: CereloColors.textSecondary),
          ),
          const SizedBox(height: CereloSpacing.md),

          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: CereloSpacing.sm),
              padding: const EdgeInsets.all(CereloSpacing.sm),
              decoration: BoxDecoration(
                color: CereloColors.errorLight,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: CereloColors.error, fontWeight: FontWeight.w600),
              ),
            ),

          if (_resolvedBatchData == null) ...[
            // Mode toggle
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _isManualMode = false),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Scan QR'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: !_isManualMode ? CereloColors.navy.withOpacity(0.08) : null,
                      side: BorderSide(
                        color: !_isManualMode ? CereloColors.navy : CereloColors.border,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _isManualMode = true),
                    icon: const Icon(Icons.keyboard_rounded, size: 18),
                    label: const Text('Enter Code'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _isManualMode ? CereloColors.navy.withOpacity(0.08) : null,
                      side: BorderSide(
                        color: _isManualMode ? CereloColors.navy : CereloColors.border,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CereloSpacing.md),

            if (!_isManualMode)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                ),
                clipBehavior: Clip.antiAlias,
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && !_isProcessing) {
                      final val = barcodes.first.rawValue;
                      if (val != null && val.trim().isNotEmpty) {
                        _resolveBatch(val.trim());
                      }
                    }
                  },
                ),
              )
            else ...[
              CereloTextField(
                label: 'Batch Reference / QR Token',
                hintText: 'e.g. BAT-E3TQ-HXE2 or BQR-...',
                controller: _refController,
              ),
              const SizedBox(height: CereloSpacing.sm),
              CereloButton(
                label: 'Lookup Batch',
                variant: CereloButtonVariant.secondary,
                isLoading: _isProcessing,
                onPressed: () => _resolveBatch(_refController.text),
              ),
            ],
          ] else ...[
            // Batch Preview Details (Revealed ONLY after successful physical resolution)
            Container(
              padding: const EdgeInsets.all(CereloSpacing.md),
              decoration: BoxDecoration(
                color: CereloColors.surfaceVariant,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                border: Border.all(color: CereloColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_resolvedBatchData!['origin_city']} → ${_resolvedBatchData!['destination_city']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: CereloColors.navy,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CereloColors.info.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                        ),
                        child: Text(
                          (_resolvedBatchData!['current_batch_state'] as String? ?? 'ONBOARDED').toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: CereloColors.info),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CereloSpacing.xs),
                  Text(
                    'Reference: ${_resolvedBatchData!['batch_reference']}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: CereloColors.navy,
                    ),
                  ),
                  const Divider(height: 16),
                  Text(
                    'Expected Manifest Parcels: ${_resolvedBatchData!['manifest_parcel_count']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CereloColors.textPrimary),
                  ),
                  if (_resolvedBatchData!['driver_name'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Driver: ${_resolvedBatchData!['driver_name']} (${_resolvedBatchData!['vehicle_plate_number'] ?? "Commercial"})',
                      style: const TextStyle(fontSize: 11, color: CereloColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: CereloSpacing.md),

            CereloButton(
              label: 'Confirm Batch Received at Hub',
              variant: CereloButtonVariant.primary,
              isLoading: _isProcessing,
              leadingIcon: Icons.storefront_rounded,
              onPressed: _confirmBatchArrival,
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() {
                _resolvedBatchData = null;
                _scannedIdentifier = null;
              }),
              child: const Text('Scan Different Batch'),
            ),
          ],
        ],
      ),
    );
  }
}
