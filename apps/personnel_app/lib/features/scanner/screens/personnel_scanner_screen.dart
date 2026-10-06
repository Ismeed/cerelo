import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../parcels/dialogs/parcel_hub_processing_sheet.dart';
import '../../parcels/providers/hub_provider.dart';

/// Reusable QR scanner screen for Personnel hub operations with Delivery Code manual fallback.
class PersonnelScannerScreen extends ConsumerStatefulWidget {
  const PersonnelScannerScreen({super.key});

  @override
  ConsumerState<PersonnelScannerScreen> createState() =>
      _PersonnelScannerScreenState();
}

class _PersonnelScannerScreenState
    extends ConsumerState<PersonnelScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final _codeController = TextEditingController();
  bool _isProcessing = false;
  bool _isManualMode = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelHubServiceProvider);
      final parcel = await service.resolveParcelByQr(rawValue.trim());

      if (mounted) {
        setState(() => _isProcessing = false);
        if (parcel != null) {
          ParcelHubProcessingSheet.show(context, parcel);
        } else {
          setState(() {
            _errorMessage = 'Not a recognised Parcel QR. Receiving a trip? '
                'Use Home → Incoming Trips → Receive Trip and scan the Batch QR there.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to resolve scanned QR. Please try again.';
        });
      }
    }
  }

  Future<void> _handleManualLookup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a Delivery Code.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(personnelHubServiceProvider);
      final parcel = await service.resolveParcelByDeliveryCode(code);

      if (mounted) {
        setState(() => _isProcessing = false);
        if (parcel != null) {
          ParcelHubProcessingSheet.show(context, parcel);
        } else {
          setState(() {
            _errorMessage = 'No parcel found matching Delivery Code: $code';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to lookup Delivery Code.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isManualMode ? 'Enter Delivery Code' : 'Scan Parcel QR'),
        actions: [
          IconButton(
            icon: Icon(
              _isManualMode
                  ? Icons.qr_code_scanner_rounded
                  : Icons.keyboard_rounded,
            ),
            tooltip: _isManualMode ? 'Switch to Scanner' : 'Enter Code Manually',
            onPressed: () {
              setState(() {
                _isManualMode = !_isManualMode;
                _errorMessage = null;
              });
            },
          ),
          if (!_isManualMode)
            IconButton(
              icon: const Icon(Icons.flash_on_rounded),
              onPressed: () => _scannerController.toggleTorch(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(CereloSpacing.md),
                color: CereloColors.errorLight,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: CereloColors.error, size: 20),
                    const SizedBox(width: CereloSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CereloColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _isManualMode
                  ? _buildManualInputView()
                  : _buildScannerCameraView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCameraView() {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleBarcode,
        ),

        // Viewfinder overlay
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: CereloColors.orange, width: 2.5),
            borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
          ),
        ),

        // Helper instruction banner
        Positioned(
          bottom: 32,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
            ),
            child: Text(
              _isProcessing
                  ? 'Resolving Parcel...'
                  : 'Align Parcel QR inside the frame',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInputView() {
    return Container(
      color: CereloColors.surface,
      padding: const EdgeInsets.all(CereloSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: CereloSpacing.lg),
          const Text(
            'Manual Delivery Code Lookup',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CereloColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use this fallback when the physical QR label is missing or damaged.',
            style: TextStyle(
              fontSize: 13,
              color: CereloColors.textSecondary,
            ),
          ),
          const SizedBox(height: CereloSpacing.xl),

          CereloTextField(
            label: 'Delivery Code',
            hintText: 'e.g. CRL-8F2K-9P3N',
            controller: _codeController,
          ),

          const SizedBox(height: CereloSpacing.lg),

          CereloButton(
            label: 'Lookup Parcel',
            isLoading: _isProcessing,
            variant: CereloButtonVariant.primary,
            leadingIcon: Icons.search_rounded,
            onPressed: _handleManualLookup,
          ),
        ],
      ),
    );
  }
}
