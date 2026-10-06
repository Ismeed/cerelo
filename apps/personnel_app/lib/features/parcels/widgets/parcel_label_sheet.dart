import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Supported physical label printer paper formats.
enum LabelFormat {
  standardThermal('Standard 4" x 6"', 'Thermal Barcode Printer (100x150mm)'),
  compact('Compact 4" x 4"', 'Square Parcel Label (100x100mm)'),
  a4Single('Standard A4', 'Office Laser/Inkjet Printer');

  const LabelFormat(this.title, this.description);
  final String title;
  final String description;
}

/// Printable parcel label modal dialog and PDF generator.
///
/// Ensures:
/// - High-contrast black-and-white layout.
/// - Prominent Parcel QR code and Delivery Code.
/// - Route and verified size tier.
/// - Zero customer PII (no personal phone numbers or street addresses).
class ParcelLabelSheet extends StatefulWidget {
  const ParcelLabelSheet({
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
      builder: (_) => ParcelLabelSheet(parcel: parcel),
    );
  }

  @override
  State<ParcelLabelSheet> createState() => _ParcelLabelSheetState();
}

class _ParcelLabelSheetState extends State<ParcelLabelSheet> {
  LabelFormat _selectedFormat = LabelFormat.standardThermal;
  bool _isGeneratingPdf = false;

  Future<void> _printLabel() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final doc = await _generatePdfDocument();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'cerelo-parcel-${widget.parcel.deliveryCode}.pdf',
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

    final pageFormat = switch (_selectedFormat) {
      LabelFormat.standardThermal => const PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm),
      LabelFormat.compact => const PdfPageFormat(100 * PdfPageFormat.mm, 100 * PdfPageFormat.mm),
      LabelFormat.a4Single => PdfPageFormat.a4,
    };

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header: Brand & Route
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'CERELO V1 LOGISTICS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'INTERCITY',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 4),

                // Prominent Route
                pw.Text(
                  '${widget.parcel.originCity.toUpperCase()} -> ${widget.parcel.destinationCity.toUpperCase()}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                // High-Contrast QR Code
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: widget.parcel.parcelQrToken.isNotEmpty
                        ? widget.parcel.parcelQrToken
                        : 'CRL-PQR-${widget.parcel.parcelId}',
                    width: 140,
                    height: 140,
                  ),
                ),
                pw.SizedBox(height: 8),

                // Delivery Code
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.black,
                  ),
                  child: pw.Text(
                    widget.parcel.deliveryCode,
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

                // Verified Size & Category
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Size: ${widget.parcel.confirmedSizeName}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Type: ${widget.parcel.categoryDescription}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1),

                // Operational Notice (Zero PII)
                pw.Text(
                  'Scan with Cerelo Personnel App at origin/destination hubs.\nDo not cover barcode label.',
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
    final p = widget.parcel;

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
                'Parcel Identity Label',
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

          // Label Preview Card (High-Contrast Monochrome)
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
                      'CERELO V1 LOGISTICS',
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
                        'INTERCITY',
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
                  '${p.originCity.toUpperCase()} → ${p.destinationCity.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: CereloSpacing.sm),

                // QR Placeholder / Preview Box
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
                          p.parcelQrToken.isNotEmpty
                              ? p.parcelQrToken
                              : 'PQR-XXXX-XXXX',
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

                // Delivery Code Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black,
                  child: Text(
                    p.deliveryCode,
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
                      'Size: ${p.confirmedSizeName}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Contents: ${p.categoryDescription}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.md),

          // Label Format Selector
          const Text(
            'Select Printer Label Format:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CereloColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: LabelFormat.values.map((f) {
              final isSelected = _selectedFormat == f;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFormat = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CereloColors.navy
                          : CereloColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(CereloSpacing.radiusSm),
                    ),
                    child: Text(
                      f.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isSelected ? Colors.white : CereloColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: CereloSpacing.lg),

          // Print Action
          CereloButton(
            label: 'Print / Save PDF Label',
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
