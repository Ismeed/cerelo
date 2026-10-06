import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Printable Batch QR container label modal dialog and PDF generator.
class BatchLabelSheet extends StatefulWidget {
  const BatchLabelSheet({
    super.key,
    required this.manifest,
  });

  final BatchManifestDto manifest;

  static void show(BuildContext context, BatchManifestDto manifest) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (_) => BatchLabelSheet(manifest: manifest),
    );
  }

  @override
  State<BatchLabelSheet> createState() => _BatchLabelSheetState();
}

class _BatchLabelSheetState extends State<BatchLabelSheet> {
  bool _isGeneratingPdf = false;

  Future<void> _printLabel() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final doc = await _generatePdfDocument();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'cerelo-batch-${widget.manifest.batchReference}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open printer: $e'),
            backgroundColor: CereloColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<pw.Document> _generatePdfDocument() async {
    final doc = pw.Document();
    final m = widget.manifest;

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2.5),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'CERELO BATCH CONTAINER',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'MIDDLE-MILE',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 4),

                pw.Text(
                  '${m.originCity.toUpperCase()} -> ${m.destinationCity.toUpperCase()}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: m.batchQrToken ?? 'CRL-BAT-${m.batchId}',
                    width: 140,
                    height: 140,
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: const pw.BoxDecoration(color: PdfColors.black),
                  child: pw.Text(
                    m.batchReference,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Parcels: ${m.manifestParcelCount}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (m.vehiclePlateNumber != null)
                      pw.Text(
                        'Vehicle: ${m.vehiclePlateNumber}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
                pw.Divider(thickness: 1),

                pw.Text(
                  'Scan Batch QR at destination hub for reconciliation.\nAttach securely to consolidated bundle or transport container.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.manifest;

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
                'Batch Container Label',
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

          const SizedBox(height: CereloSpacing.sm),

          // Label Preview Card
          Container(
            padding: const EdgeInsets.all(CereloSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CERELO BATCH CONTAINER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: Colors.black,
                      child: const Text(
                        'MIDDLE-MILE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.black, thickness: 1.5, height: 12),
                Text(
                  '${m.originCity.toUpperCase()} → ${m.destinationCity.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: CereloSpacing.sm),

                // QR Placeholder Box
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          color: Colors.white,
                          size: 80,
                        ),
                        Text(
                          m.batchQrToken ?? 'BQR-XXXX-XXXX',
                          style: const TextStyle(
                            fontSize: 7,
                            fontFamily: 'monospace',
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CereloSpacing.sm),

                // Batch Reference Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black,
                  child: Text(
                    m.batchReference,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Parcels: ${m.manifestParcelCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Corridor: ${m.corridorCode}',
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.lg),

          // Print Action
          CereloButton(
            label: 'Print / Save Batch Label PDF',
            variant: CereloButtonVariant.primary,
            isLoading: _isGeneratingPdf,
            leadingIcon: Icons.print_rounded,
            onPressed: _printLabel,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
