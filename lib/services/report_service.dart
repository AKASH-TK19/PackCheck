import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/compliance_rule.dart';
import '../services/compliance_engine.dart';

class ReportService {
  static Future<void> generateReport({
    required ExtractedProductData product,
    required List<ComplianceResult> results,
    required String extractedText,
    required String imagePath,
    String? barcode,
    String? barcodeNote,
  }) async {
    final pdf = pw.Document();

    final passed =
        results.where((r) => r.detected).length;

    final violations = results
        .where(
          (r) =>
              !r.detected &&
              !r.rule.conditional,
        )
        .toList();

    final score = results.isEmpty
        ? 0
        : ((passed / results.length) * 100).round();

    pw.MemoryImage? evidenceImage;

    try {
      final file = File(imagePath);

      if (await file.exists()) {
        evidenceImage =
            pw.MemoryImage(
          await file.readAsBytes(),
        );
      }
    } catch (_) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Container(
            padding:
                const pw.EdgeInsets.only(
              bottom: 12,
            ),
            child: pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment
                      .spaceBetween,
              children: [
                pw.Text(
                  'LEGAL METROLOGY',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight:
                        pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'INSPECTION REPORT',
                  style: pw.TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding:
                const pw.EdgeInsets.only(
              top: 10,
            ),
            child: pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment
                      .spaceBetween,
              children: [
                pw.Text(
                  'LM Inspect',
                  style: const pw.TextStyle(
                    fontSize: 9,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            pw.Text(
              'PACKAGED COMMODITY INSPECTION',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 6),

            pw.Text(
              'Automated screening with officer verification',
              style: const pw.TextStyle(
                fontSize: 12,
              ),
            ),

            pw.SizedBox(height: 20),

            _sectionTitle(
              'INSPECTION DETAILS',
            ),

            _infoTable([
              ['Inspection ID', _inspectionId()],
              [
                'Date / Time',
                DateTime.now()
                    .toLocal()
                    .toString()
              ],
              [
                'Verification Status',
                'OFFICER VERIFIED'
              ],
              [
                'Automated Screening Score',
                '$score%'
              ],
              [
                'Potential Violations',
                '${violations.length}'
              ],
            ]),

            pw.SizedBox(height: 20),

            _sectionTitle(
              'PRODUCT INFORMATION',
            ),

            _infoTable([
              [
                'Product Name',
                product.productName
              ],
              [
                'Barcode / QR Product ID',
                (barcode == null || barcode.isEmpty)
                    ? ((barcodeNote == null || barcodeNote.isEmpty)
                        ? 'Not scanned'
                        : barcodeNote)
                    : barcode
              ],
              [
                'Maximum Retail Price',
                product.mrp
              ],
              [
                'Net Quantity',
                product.netQuantity
              ],
              [
                'Manufacturer / Packer',
                product.manufacturer
              ],
              [
                'Country of Origin',
                product.countryOfOrigin
              ],
              [
                'Manufacture / Packing Date',
                product.manufactureDate
              ],
              [
                'Best Before / Use By',
                product.expiryDate
              ],
              [
                'Consumer Care',
                product.consumerCare
              ],
            ]),

            pw.SizedBox(height: 20),

            if (evidenceImage != null) ...[
              _sectionTitle(
                'EVIDENCE PHOTOGRAPH',
              ),

              pw.Container(
                height: 250,
                width: double.infinity,
                alignment:
                    pw.Alignment.center,
                child: pw.Image(
                  evidenceImage,
                  fit:
                      pw.BoxFit.contain,
                ),
              ),

              pw.SizedBox(height: 20),
            ],

            _sectionTitle(
              'COMPLIANCE FINDINGS',
            ),

            ...results.map(
              (result) =>
                  _findingRow(result),
            ),

            pw.SizedBox(height: 20),

            if (violations.isNotEmpty) ...[
              _sectionTitle(
                'POTENTIAL NON-COMPLIANCES',
              ),

              ...violations.map(
                (result) => pw.Container(
                  margin:
                      const pw.EdgeInsets
                          .only(
                    bottom: 8,
                  ),
                  padding:
                      const pw.EdgeInsets
                          .all(10),
                  decoration:
                      pw.BoxDecoration(
                    border: pw.Border.all(
                      color:
                          PdfColors.red,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment
                            .start,
                    children: [
                      pw.Text(
                        result.rule
                            .declaration,
                        style: pw.TextStyle(
                          fontWeight:
                              pw.FontWeight
                                  .bold,
                        ),
                      ),
                      pw.SizedBox(
                        height: 4,
                      ),
                      pw.Text(
                        result.evidence,
                        style:
                            const pw.TextStyle(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              pw.Container(
                padding:
                    const pw.EdgeInsets
                        .all(12),
                decoration:
                    pw.BoxDecoration(
                  border: pw.Border.all(
                    color:
                        PdfColors.green,
                  ),
                ),
                child: pw.Text(
                  'No configured declaration violations detected during automated screening.',
                  style:
                      const pw.TextStyle(
                    fontSize: 11,
                  ),
                ),
              ),

            pw.SizedBox(height: 20),

            _sectionTitle(
              'RAW OCR EVIDENCE',
            ),

            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.all(
                12,
              ),
              decoration:
                  pw.BoxDecoration(
                border: pw.Border.all(
                  color:
                      PdfColors.grey,
                ),
              ),
              child: pw.Text(
                extractedText.isEmpty
                    ? 'No OCR text detected.'
                    : extractedText,
                style:
                    const pw.TextStyle(
                  fontSize: 11,
                ),
              ),
            ),

            pw.SizedBox(height: 25),

            pw.Container(
              padding:
                  const pw.EdgeInsets.all(
                12,
              ),
              decoration:
                  pw.BoxDecoration(
                color:
                    PdfColors.grey200,
              ),
              child: pw.Text(
                'IMPORTANT: This report contains automated screening results and officer-verified information. It is intended to assist authorised enforcement personnel. Final legal determination and further action shall be undertaken according to applicable law and departmental procedure.',
                style:
                    const pw.TextStyle(
                  fontSize: 10,
                ),
              ),
            ),

            pw.SizedBox(height: 30),

            _sectionTitle('SIGNATURES'),

            pw.SizedBox(height: 70),

            pw.Row(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: _signatureBlock(
                    'Senior Supervisor',
                  ),
                ),
                pw.SizedBox(width: 40),
                pw.Expanded(
                  child: _signatureBlock(
                    'Inspection Officer',
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async {
        return pdf.save();
      },
    );
  }

  /// Exports the inspection as an editable CSV file and opens the share
  /// sheet. This satisfies the "editable format export" requirement of the
  /// problem statement alongside the signed PDF report.
  static Future<void> generateEditableCsv({
    required ExtractedProductData product,
    required List<ComplianceResult> results,
    required String extractedText,
    required String imagePath,
    String? barcode,
    String? barcodeNote,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('LM Inspect - Packaged Commodity Compliance Export');
    buffer.writeln('Exported on,${DateTime.now().toIso8601String()}');
    buffer.writeln('Evidence image,${imagePath.replaceAll(',', ';')}');
    buffer.writeln();

    buffer.writeln('FIELD,VALUE');
    _csvRow(buffer, 'Product Name', product.productName);
    _csvRow(
      buffer,
      'Barcode / QR Product ID',
      (barcode == null || barcode.isEmpty)
          ? ((barcodeNote == null || barcodeNote.isEmpty)
              ? 'Not scanned'
              : barcodeNote)
          : barcode,
    );
    _csvRow(buffer, 'Maximum Retail Price', product.mrp);
    _csvRow(buffer, 'Unit Sale Price', product.unitSalePrice);
    _csvRow(buffer, 'Net Quantity', product.netQuantity);
    _csvRow(buffer, 'Manufacturer / Packer / Importer', product.manufacturer);
    _csvRow(buffer, 'Country of Origin', product.countryOfOrigin);
    _csvRow(buffer, 'Manufacture / Packing Date', product.manufactureDate);
    _csvRow(buffer, 'Best Before / Use By', product.expiryDate);
    _csvRow(buffer, 'Consumer Care', product.consumerCare);
    buffer.writeln();

    buffer.writeln('DECLARATION,STATUS,EXPLANATION');
    for (final result in results) {
      final status = result.detected
          ? 'DETECTED'
          : result.rule.conditional
              ? 'VERIFY'
              : 'POTENTIAL VIOLATION';

      _csvRow(buffer, result.rule.declaration, '$status;${result.evidence}');
    }
    buffer.writeln();

    if (extractedText.trim().isNotEmpty) {
      buffer.writeln('RAW_OCR_TEXT');
      buffer.writeln(_csvQuote(extractedText));
    }

    final fileName =
        'lm_inspect_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${Directory.systemTemp.path}/$fileName');

    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'LM Inspect - Compliance Report',
      text: 'Compliance report for ${product.productName}',
    );
  }

  static void _csvRow(StringBuffer buffer, String label, String value) {
    buffer.writeln('${_csvQuote(label)},${_csvQuote(value)}');
  }

  static String _csvQuote(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  static pw.Widget _sectionTitle(
    String title,
  ) {
    return pw.Container(
      width: double.infinity,
      margin:
          const pw.EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const pw.EdgeInsets.symmetric(
        vertical: 7,
        horizontal: 8,
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight:
              pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _infoTable(
    List<List<String>> rows,
  ) {
    return pw.Table(
      border:
          pw.TableBorder.all(
        color: PdfColors.grey400,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(3),
      },
      children: rows.map(
        (row) {
          return pw.TableRow(
            children: [
              pw.Padding(
                padding:
                    const pw.EdgeInsets
                        .all(7),
                child: pw.Text(
                  row[0],
                  style: pw.TextStyle(
                    fontWeight:
                        pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.Padding(
                padding:
                    const pw.EdgeInsets
                        .all(7),
                child: pw.Text(
                  row[1],
                  style:
                      const pw.TextStyle(
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          );
        },
      ).toList(),
    );
  }

  static pw.Widget _findingRow(
    ComplianceResult result,
  ) {
    final status =
        result.detected
            ? 'DETECTED'
            : result.rule.conditional
                ? 'VERIFY'
                : 'POTENTIAL VIOLATION';

    return pw.Container(
      margin:
          const pw.EdgeInsets.only(
        bottom: 7,
      ),
      padding:
          const pw.EdgeInsets.all(9),
      decoration:
          pw.BoxDecoration(
        border:
            pw.Border.all(
          color: PdfColors.grey400,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment
                    .spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  result.rule.declaration,
                  style: pw.TextStyle(
                    fontWeight:
                        pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.Text(
                status,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            result.evidence,
            style:
                const pw.TextStyle(
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// A signature area with a blank line for the signatory and a designation
  /// label beneath it. It is intentionally left empty so the officer can sign
  /// once the PDF has been printed.
  static pw.Widget _signatureBlock(
    String designation,
  ) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: 40,
          decoration:
              pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColors.grey,
                width: 1,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          designation,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Name / Sign & Date',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  static String _inspectionId() {
    final now = DateTime.now();

    return 'LM-${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }
}