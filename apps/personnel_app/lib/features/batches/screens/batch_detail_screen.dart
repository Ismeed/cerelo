import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../parcels/providers/hub_provider.dart';
import '../providers/batch_provider.dart';
import '../widgets/batch_label_sheet.dart';
import '../widgets/batch_receive_sheet.dart';

/// Operational workspace for managing a single Batch lifecycle:
/// parcel grouping, manifest freezing, transport association, intercity onboarding,
/// and destination arrival routing.
class BatchDetailScreen extends ConsumerStatefulWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends ConsumerState<BatchDetailScreen> {
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _plateController = TextEditingController();
  final _costController = TextEditingController(text: '7000');
  final _codeController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _plateController.dispose();
    _costController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showAddParcelModal() {
    final scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    var isManual = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
                    'Add Parcel to Draft Batch',
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
              const SizedBox(height: CereloSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setModalState(() => isManual = false),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('Scan QR'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !isManual ? CereloColors.navy.withOpacity(0.08) : null,
                        side: BorderSide(color: !isManual ? CereloColors.navy : CereloColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setModalState(() => isManual = true),
                      icon: const Icon(Icons.keyboard_rounded, size: 18),
                      label: const Text('Enter Code'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isManual ? CereloColors.navy.withOpacity(0.08) : null,
                        side: BorderSide(color: isManual ? CereloColors.navy : CereloColors.border),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CereloSpacing.md),
              if (!isManual)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    controller: scannerController,
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final val = barcodes.first.rawValue;
                        if (val != null && val.trim().isNotEmpty) {
                          Navigator.of(ctx).pop();
                          _addParcelByQr(val.trim());
                        }
                      }
                    },
                  ),
                )
              else ...[
                CereloTextField(
                  label: 'Delivery Code',
                  hintText: 'e.g. CRL-8F2K-9P3N',
                  controller: _codeController,
                ),
                const SizedBox(height: CereloSpacing.md),
                CereloButton(
                  label: 'Add to Batch',
                  variant: CereloButtonVariant.primary,
                  onPressed: () {
                    final code = _codeController.text.trim();
                    if (code.isNotEmpty) {
                      Navigator.of(ctx).pop();
                      _addParcelByCode(code);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addParcelByQr(String qrToken) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final hubService = ref.read(personnelHubServiceProvider);
      final batchService = ref.read(personnelBatchServiceProvider);

      final parcel = await hubService.resolveParcelByQr(qrToken);
      if (parcel == null) {
        throw const CereloApiError(
          code: CereloErrorCode.notFound,
          message: 'No parcel found matching scanned QR.',
        );
      }

      await batchService.addParcelToBatch(
        batchId: widget.batchId,
        parcelId: parcel.parcelId,
      );

      ref.invalidate(batchManifestProvider(widget.batchId));
      ref.invalidate(batchesListProvider(null));

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcel added to batch manifest.'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e is CereloApiError ? e.message : 'Could not add parcel to batch.';
        });
      }
    }
  }

  Future<void> _addParcelByCode(String deliveryCode) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final hubService = ref.read(personnelHubServiceProvider);
      final batchService = ref.read(personnelBatchServiceProvider);

      final parcel = await hubService.resolveParcelByDeliveryCode(deliveryCode);
      if (parcel == null) {
        throw const CereloApiError(
          code: CereloErrorCode.notFound,
          message: 'No parcel found matching this Delivery Code.',
        );
      }

      await batchService.addParcelToBatch(
        batchId: widget.batchId,
        parcelId: parcel.parcelId,
      );

      _codeController.clear();
      ref.invalidate(batchManifestProvider(widget.batchId));
      ref.invalidate(batchesListProvider(null));

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcel added to batch manifest.'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e is CereloApiError ? e.message : 'Could not add parcel to batch.';
        });
      }
    }
  }

  Future<void> _removeParcel(String parcelId) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(personnelBatchServiceProvider);
      await service.removeParcelFromDraftBatch(
        batchId: widget.batchId,
        parcelId: parcelId,
      );
      ref.invalidate(batchManifestProvider(widget.batchId));
      ref.invalidate(batchesListProvider(null));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteEmptyDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft Batch?'),
        content: const Text(
          'This empty draft batch will be deleted permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Draft'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: CereloColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelBatchServiceProvider);
      await service.deleteDraftBatch(widget.batchId);

      ref.invalidate(batchesListProvider(null));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft batch deleted successfully.'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e is CereloApiError ? e.message : 'Could not delete draft batch.';
        });
      }
    }
  }

  Future<void> _cancelDraftWithParcels(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Draft Batch?'),
        content: Text(
          'Cancel this draft batch and release all $count parcels back to the origin hub ready-for-batching pool?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Draft'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: CereloColors.error, foregroundColor: Colors.white),
            child: const Text('Cancel Draft & Release Parcels'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelBatchServiceProvider);
      await service.cancelDraftBatch(
        batchId: widget.batchId,
        reason: 'Cancelled by personnel in draft workspace',
      );

      ref.invalidate(batchesListProvider(null));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft batch cancelled. Parcels released to origin pool.'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e is CereloApiError ? e.message : 'Could not cancel draft batch.';
        });
      }
    }
  }

  Future<void> _confirmBatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Batch Manifest?'),
        content: const Text(
          'This will freeze the manifest and generate the Batch QR. No further parcels can be added or removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CereloColors.navy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Batch'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelBatchServiceProvider);
      await service.confirmBatch(widget.batchId);

      ref.invalidate(batchManifestProvider(widget.batchId));
      ref.invalidate(batchesListProvider(null));

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch confirmed and manifest frozen!'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e is CereloApiError ? e.message : 'Could not confirm batch.';
        });
      }
    }
  }

  Future<void> _saveTransportDetails() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final costNaira = int.tryParse(_costController.text.trim()) ?? 7000;
      final service = ref.read(personnelBatchServiceProvider);

      await service.setBatchTransport(
        batchId: widget.batchId,
        providerName: 'Kano-Katsina Commercial Transit Line',
        driverName: _driverNameController.text.trim().isNotEmpty
            ? _driverNameController.text.trim()
            : 'Commercial Driver',
        driverPhone: _driverPhoneController.text.trim().isNotEmpty
            ? _driverPhoneController.text.trim()
            : '+2348000000000',
        vehiclePlate: _plateController.text.trim().isNotEmpty
            ? _plateController.text.trim()
            : 'KMC-123-XA',
        agreedCost: Money.fromNaira(costNaira),
      );

      ref.invalidate(batchManifestProvider(widget.batchId));

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transport details updated.'),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to update transport details.';
        });
      }
    }
  }

  Future<void> _onboardBatch(BatchManifestDto m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Physical Departure'),
        content: Text(
          'Confirm that Batch ${m.batchReference} with ${m.manifestParcelCount} parcels has physically departed ${m.originCity} for ${m.destinationCity}.\n\nThis will atomically update all included shipments to In Transit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CereloColors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Onboarded'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelBatchServiceProvider);
      await service.onboardBatch(widget.batchId);

      ref.invalidate(batchManifestProvider(widget.batchId));
      ref.invalidate(batchesListProvider(null));

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Batch Onboarded! Included shipments are now In Transit.',
            ),
            backgroundColor: CereloColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e is CereloApiError ? e.message : 'Could not onboard batch.';
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
        title: const Text('Batch Manifest Workspace'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: manifestAsync.when(
          loading: () => const Center(
            child: CereloLoading(message: 'Loading batch manifest...'),
          ),
          error: (_, __) => const Center(
            child: Padding(
              padding: EdgeInsets.all(CereloSpacing.md),
              child: Text(
                'Could not load batch details. Please check your connection.',
                style: TextStyle(fontSize: 13, color: CereloColors.textSecondary),
              ),
            ),
          ),
          data: (manifest) {
            if (manifest == null) {
              return const Center(child: Text('Batch not found.'));
            }

            final isDraft = manifest.status == BatchStatus.draft;
            final isConfirmed = manifest.status == BatchStatus.confirmed;
            final isOnboarded = manifest.status == BatchStatus.onboarded;

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

                  // Header Card
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
                                color: isOnboarded
                                    ? CereloColors.info.withOpacity(0.12)
                                    : (isConfirmed
                                        ? CereloColors.success.withOpacity(0.12)
                                        : CereloColors.orange.withOpacity(0.12)),
                                borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
                              ),
                              child: Text(
                                manifest.status.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isOnboarded
                                      ? CereloColors.info
                                      : (isConfirmed
                                          ? CereloColors.success
                                          : CereloColors.orangeDark),
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
                              'Parcels Included:',
                              style: TextStyle(
                                fontSize: 12,
                                color: CereloColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${manifest.manifestParcelCount} Parcels',
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

                  const SizedBox(height: CereloSpacing.md),

                  // STAGE 1: DRAFT WORKFLOW (Add / Remove Parcels & Confirm)
                  if (isDraft) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Manifest Items',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: CereloColors.navy,
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _showAddParcelModal,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Parcel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CereloColors.navy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: CereloSpacing.xs),

                    if (manifest.parcels.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(CereloSpacing.lg),
                        decoration: BoxDecoration(
                          color: CereloColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                        ),
                        child: const Center(
                          child: Text(
                            'No parcels added yet.\nScan or add staged parcels to populate the manifest.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: CereloColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: manifest.parcels.length,
                        itemBuilder: (ctx, i) {
                          final p = manifest.parcels[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: const Icon(Icons.inventory_2_outlined, color: CereloColors.navy),
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
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: CereloColors.error, size: 20),
                                tooltip: 'Remove from Draft Batch',
                                onPressed: () => _removeParcel(p.parcelId),
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: CereloSpacing.md),

                    CereloButton(
                      label: 'Confirm Batch & Freeze Manifest',
                      variant: CereloButtonVariant.primary,
                      isLoading: _isProcessing,
                      onPressed: manifest.manifestParcelCount > 0 ? _confirmBatch : null,
                    ),

                    const SizedBox(height: CereloSpacing.sm),

                    // Draft Cancellation / Deletion Options
                    if (manifest.manifestParcelCount == 0)
                      TextButton.icon(
                        onPressed: _isProcessing ? null : _deleteEmptyDraft,
                        icon: const Icon(Icons.delete_outline_rounded, color: CereloColors.error, size: 18),
                        label: const Text(
                          'Delete Empty Draft',
                          style: TextStyle(color: CereloColors.error, fontWeight: FontWeight.w700),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () => _cancelDraftWithParcels(manifest.manifestParcelCount),
                        icon: const Icon(Icons.cancel_outlined, color: CereloColors.error, size: 18),
                        label: Text(
                          'Cancel Draft & Release ${manifest.manifestParcelCount} Parcels',
                          style: const TextStyle(color: CereloColors.error, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],

                  // STAGE 2: CONFIRMED WORKFLOW (Batch QR, Transport & Onboard)
                  if (isConfirmed) ...[
                    // Batch QR Action Card
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.md),
                      decoration: BoxDecoration(
                        color: CereloColors.white,
                        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                        border: Border.all(color: CereloColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 40, color: CereloColors.navy),
                          const SizedBox(width: CereloSpacing.md),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Batch Container Label',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: CereloColors.navy,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Print and attach securely to the middle-mile container/bundle.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CereloColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => BatchLabelSheet.show(context, manifest),
                            child: const Text('Print Label'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: CereloSpacing.md),

                    // Middle-Mile Transport Arrangement
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.md),
                      decoration: BoxDecoration(
                        color: CereloColors.white,
                        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                        border: Border.all(color: CereloColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Middle-Mile Transport Arrangement',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: CereloColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Commercial line carrier info and agreed transit cost.',
                            style: TextStyle(
                              fontSize: 11,
                              color: CereloColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: CereloSpacing.md),
                          CereloTextField(
                            label: 'Driver Name',
                            hintText: 'e.g. Malam Aminu',
                            controller: _driverNameController,
                          ),
                          const SizedBox(height: CereloSpacing.sm),
                          CereloTextField(
                            label: 'Driver Phone',
                            hintText: 'e.g. 08031234567',
                            keyboardType: TextInputType.phone,
                            controller: _driverPhoneController,
                          ),
                          const SizedBox(height: CereloSpacing.sm),
                          CereloTextField(
                            label: 'Vehicle Plate Number',
                            hintText: 'e.g. KMC-456-XA',
                            controller: _plateController,
                          ),
                          const SizedBox(height: CereloSpacing.sm),
                          CereloTextField(
                            label: 'Agreed Transit Cost (₦)',
                            hintText: 'e.g. 7000',
                            keyboardType: TextInputType.number,
                            controller: _costController,
                          ),
                          const SizedBox(height: CereloSpacing.sm),
                          OutlinedButton(
                            onPressed: _saveTransportDetails,
                            child: const Text('Save Transport Details'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: CereloSpacing.xl),

                    CereloButton(
                      label: 'Mark Batch Onboarded (Vehicle Departed)',
                      variant: CereloButtonVariant.primary,
                      isLoading: _isProcessing,
                      leadingIcon: Icons.departure_board_rounded,
                      onPressed: () => _onboardBatch(manifest),
                    ),
                  ],

                  // STAGE 3: ONBOARDED (In Transit)
                  if (isOnboarded) ...[
                    Container(
                      padding: const EdgeInsets.all(CereloSpacing.md),
                      decoration: BoxDecoration(
                        color: CereloColors.info.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                        border: Border.all(color: CereloColors.info.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_bus_rounded, color: CereloColors.info, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Batch is In Transit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: CereloColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Departed origin hub. Destination arrival and parcel-by-parcel reconciliation will be processed upon physical arrival.',
                            style: TextStyle(
                              fontSize: 12,
                              color: CereloColors.navy.withOpacity(0.8),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: CereloSpacing.md),

                    // Destination Action if viewed by destination personnel
                    CereloButton(
                      label: 'Receive Inbound Batch at Hub',
                      variant: CereloButtonVariant.primary,
                      leadingIcon: Icons.qr_code_scanner_rounded,
                      onPressed: () => BatchReceiveSheet.show(context),
                    ),

                    const SizedBox(height: CereloSpacing.md),

                    // Frozen Manifest
                    const Text(
                      'Frozen Departure Manifest',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CereloColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: manifest.parcels.length,
                      itemBuilder: (ctx, i) {
                        final p = manifest.parcels[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2_outlined, color: CereloColors.navy),
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
                          ),
                        );
                      },
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
