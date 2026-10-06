import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../batches/providers/batch_provider.dart';
import '../../batches/widgets/batch_receive_sheet.dart';
import '../providers/delivery_provider.dart';

/// Screen managing destination Batch arrival confirmation and parcel-by-parcel reconciliation.
/// Supports Parcel QR scanning (primary) and Delivery Code manual lookup (fallback).
class ReconciliationScreen extends ConsumerStatefulWidget {
  const ReconciliationScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<ReconciliationScreen> createState() =>
      _ReconciliationScreenState();
}

class _ReconciliationScreenState extends ConsumerState<ReconciliationScreen> {
  final _codeController = TextEditingController();
  final Map<String, String> _dispositions = {};
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _markParcelDisposition(String parcelId, String disposition, {String? notes}) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(personnelDeliveryServiceProvider);
      await service.reconcileBatchParcel(
        batchId: widget.batchId,
        parcelId: parcelId,
        disposition: disposition,
        notes: notes,
      );

      setState(() {
        _dispositions[parcelId] = disposition;
        _isProcessing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showScanParcelModal(List<ReadyForBatchParcelDto> parcels) {
    final scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: CereloColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(CereloSpacing.radiusLg)),
        ),
        padding: EdgeInsets.only(
          top: CereloSpacing.md,
          left: CereloSpacing.pagePadding,
          right: CereloSpacing.pagePadding,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + CereloSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  'Scan Parcel QR to Reconcile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CereloColors.navy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Align the physical Parcel QR sticker inside the frame.',
              style: TextStyle(fontSize: 12, color: CereloColors.textSecondary),
            ),
            const SizedBox(height: CereloSpacing.md),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              ),
              clipBehavior: Clip.antiAlias,
              child: MobileScanner(
                controller: scannerController,
                onDetect: (capture) async {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final val = barcodes.first.rawValue;
                    if (val != null && val.trim().isNotEmpty) {
                      Navigator.of(ctx).pop();
                      await _handleScannedTokenOrCode(val.trim(), parcels);
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: CereloSpacing.md),
            OutlinedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showManualCodeDialog(parcels);
              },
              child: const Text('Enter Delivery Code Manually Instead'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleScannedTokenOrCode(String rawQuery, List<ReadyForBatchParcelDto> parcels) async {
    final cleaned = rawQuery.trim();

    // Check if matches parcel_qr_token or deliveryCode in manifest
    final match = parcels.where((p) =>
        p.parcelQrToken.toLowerCase() == cleaned.toLowerCase() ||
        p.deliveryCode.toUpperCase() == cleaned.toUpperCase()
    ).firstOrNull;

    if (match != null) {
      await _markParcelDisposition(match.parcelId, 'PRESENT');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Matched ${match.deliveryCode} as PRESENT!'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned code "$cleaned" was not found in this Batch Manifest!'),
            backgroundColor: CereloColors.error,
          ),
        );
      }
    }
  }

  void _showManualCodeDialog(List<ReadyForBatchParcelDto> parcels) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reconcile by Delivery Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the Delivery Code of the physical parcel to verify arrival.',
              style: TextStyle(fontSize: 12, color: CereloColors.textSecondary),
            ),
            const SizedBox(height: CereloSpacing.md),
            CereloTextField(
              label: 'Delivery Code',
              hintText: 'e.g. CRL-8F2K-9P3N',
              controller: _codeController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = _codeController.text.trim();
              if (code.isEmpty) return;

              final match = parcels
                  .where((p) => p.deliveryCode.toUpperCase() == code.toUpperCase())
                  .firstOrNull;
              Navigator.of(ctx).pop();

              if (match != null) {
                await _markParcelDisposition(match.parcelId, 'PRESENT');
                _codeController.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Matched ${match.deliveryCode} as PRESENT!'),
                      backgroundColor: CereloColors.success,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delivery Code "$code" is not in this manifest!'),
                      backgroundColor: CereloColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Match as Present'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeReconciliation() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelDeliveryServiceProvider);
      await service.completeBatchReconciliation(widget.batchId);

      ref.invalidate(batchManifestProvider(widget.batchId));
      ref.invalidate(readyForDeliveryQueueProvider);
      ref.invalidate(batchesListProvider(null));

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconciliation completed! Parcels released to Deliveries queue.'),
            backgroundColor: CereloColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e is CereloApiError
              ? e.message
              : 'Could not complete reconciliation.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifestAsync = ref.watch(batchManifestProvider(widget.batchId));

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Destination Manifest & Reconciliation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: manifestAsync.when(
          loading: () => const Center(
            child: CereloLoading(message: 'Loading destination manifest...'),
          ),
          error: (_, __) => const Center(
            child: Padding(
              padding: EdgeInsets.all(CereloSpacing.md),
              child: Text(
                'Could not load manifest. Please check your connection.',
                style: TextStyle(fontSize: 13, color: CereloColors.textSecondary),
              ),
            ),
          ),
          data: (manifest) {
            if (manifest == null) {
              return const Center(child: Text('Batch not found.'));
            }

            final isInTransit = manifest.status == BatchStatus.onboarded;
            final isReceived = manifest.status == BatchStatus.destinationReceived ||
                manifest.status == BatchStatus.reconciling;
            final isReconciled = manifest.status == BatchStatus.reconciled;

            final totalExpected = manifest.parcels.length;
            final checkedCount = _dispositions.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(CereloSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: CereloSpacing.md),
                      padding: const EdgeInsets.all(CereloSpacing.md),
                      decoration: BoxDecoration(
                        color: CereloColors.errorLight,
                        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CereloColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Header Summary Card
                  Container(
                    padding: const EdgeInsets.all(CereloSpacing.md),
                    decoration: BoxDecoration(
                      color: CereloColors.white,
                      borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                      border: Border.all(color: CereloColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              manifest.routeDisplay,
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
                                color: isReconciled
                                    ? CereloColors.success.withOpacity(0.12)
                                    : (isReceived
                                        ? CereloColors.orange.withOpacity(0.12)
                                        : CereloColors.info.withOpacity(0.12)),
                                borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                              ),
                              child: Text(
                                manifest.status.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isReconciled
                                      ? CereloColors.success
                                      : (isReceived
                                          ? CereloColors.orangeDark
                                          : CereloColors.info),
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
                              'Batch Reference:',
                              style: TextStyle(
                                fontSize: 12,
                                color: CereloColors.textSecondary,
                              ),
                            ),
                            Text(
                              manifest.batchReference,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: CereloColors.navy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Expected Manifest Items:',
                              style: TextStyle(
                                fontSize: 12,
                                color: CereloColors.textSecondary,
                              ),
                            ),
                            Text(
                              '$totalExpected Parcels',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: CereloColors.navy,
                              ),
                            ),
                          ],
                        ),
                        if (manifest.driverName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Middle-Mile Transport:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CereloColors.textSecondary,
                                ),
                              ),
                              Text(
                                '${manifest.driverName} (${manifest.vehiclePlateNumber ?? "Commercial"})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CereloColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: CereloSpacing.md),

                  // STEP 1: If In Transit, prompt Physical Batch Verification
                  if (isInTransit) ...[
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.lg),
                      decoration: BoxDecoration(
                        color: CereloColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 40, color: CereloColors.orange),
                          const SizedBox(height: CereloSpacing.sm),
                          const Text(
                            'Physical Verification Required',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: CereloColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Physical Batch QR or Batch Code required to verify arrival and unlock manifest reconciliation.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: CereloColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: CereloSpacing.md),
                          CereloButton(
                            label: 'Scan Batch QR / Enter Code',
                            variant: CereloButtonVariant.primary,
                            leadingIcon: Icons.qr_code_scanner_rounded,
                            onPressed: () => BatchReceiveSheet.show(context),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // STEP 2: Reconciliation Workspace
                  if (isReceived || isReconciled) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reconciliation ($checkedCount of $totalExpected Reconciled)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: CereloColors.navy,
                          ),
                        ),
                        if (!isReconciled)
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _showScanParcelModal(manifest.parcels),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                                label: const Text('Scan QR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CereloColors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: () => _showManualCodeDialog(manifest.parcels),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Code', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: manifest.parcels.length,
                      itemBuilder: (ctx, i) {
                        final p = manifest.parcels[i];
                        final disp = _dispositions[p.parcelId];
                        final isPresent = disp == 'PRESENT';
                        final isMissing = disp == 'MISSING';
                        final isChecked = disp != null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: CereloColors.white,
                            borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                            border: Border.all(
                              color: isPresent
                                  ? CereloColors.success
                                  : (isMissing ? CereloColors.error : CereloColors.border),
                              width: isChecked ? 1.5 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isPresent
                                  ? Icons.check_circle_rounded
                                  : (isMissing
                                      ? Icons.cancel_rounded
                                      : Icons.inventory_2_outlined),
                              color: isPresent
                                  ? CereloColors.success
                                  : (isMissing
                                      ? CereloColors.error
                                      : CereloColors.navy),
                            ),
                            title: Text(
                              p.deliveryCode,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                            subtitle: Text(
                              '${p.confirmedSizeName} • ${p.categoryDescription}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: !isReconciled
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.check_circle_rounded,
                                          color: isPresent
                                              ? CereloColors.success
                                              : CereloColors.border,
                                          size: 26,
                                        ),
                                        tooltip: 'Match as Present',
                                        onPressed: () => _markParcelDisposition(
                                            p.parcelId, 'PRESENT'),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.cancel_rounded,
                                          color: isMissing
                                              ? CereloColors.error
                                              : CereloColors.border,
                                          size: 26,
                                        ),
                                        tooltip: 'Mark Missing',
                                        onPressed: () => _markParcelDisposition(
                                            p.parcelId, 'MISSING'),
                                      ),
                                    ],
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: CereloColors.success.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PRESENT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: CereloColors.success,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: CereloSpacing.lg),

                    if (!isReconciled)
                      CereloButton(
                        label: 'Complete Reconciliation ($checkedCount/$totalExpected)',
                        variant: CereloButtonVariant.primary,
                        isLoading: _isProcessing,
                        onPressed: checkedCount >= totalExpected
                            ? _completeReconciliation
                            : null,
                      ),
                  ],

                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
