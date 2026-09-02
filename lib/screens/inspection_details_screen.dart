import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product_category.dart';
import '../services/compliance_engine.dart';
import '../services/report_service.dart';

class InspectionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> inspection;

  const InspectionDetailsScreen({
    super.key,
    required this.inspection,
  });

  String _value(String key, String fallback) {
    final value = inspection[key];
    if (value == null) return fallback;

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final local = parsed.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  Future<void> _generateReport(BuildContext context) async {
    final extractedText = _value(
      'extractedText',
      'No extracted inspection data available.',
    );

    final barcode = _extractBarcode(extractedText);
    final barcodeNote = barcode.isEmpty
        ? 'No barcode/QR detected'
        : null;

    final categoryInfo =
        ProductCategory.byLabel(_value('productCategory', ''));
    final categoryLabel = categoryInfo?.label ?? _value('productCategory', '');

    try {
      final analysis = ComplianceEngine.analyzeFull(
        extractedText,
        category: categoryInfo,
      );

      await ReportService.generateReport(
        product: analysis.product,
        results: analysis.results,
        extractedText: extractedText,
        imagePath: _value('imagePath', ''),
        barcode: barcode,
        barcodeNote: barcodeNote,
        category: categoryLabel,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inspection PDF report generated.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate report: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _value('productName', 'Unknown Product');
    final score = _value('score', '0');
    final violations = _value('violationCount', '0');
    final date = _value('inspectionDate', 'Date not recorded');
    final officerId = _value('officerId', 'Not recorded');
    final location = _value('location', 'Not recorded');
    final verified = _value('verified', 'false');
    final remarks = _value('officerRemarks', 'None');
    final category = _value('productCategory', 'Not selected');
    final barcode = _extractBarcode(
      _value(
        'extractedText',
        '',
      ),
    );
    final imagePath = _value('imagePath', '');
    final extractedText = _value(
      'extractedText',
      'No extracted inspection data available.',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INSPECTION RECORD',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inspection date: ${_formatDate(date)}',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _infoCard(
              'Inspection Summary',
              [
                _detailRow(
                  'Score',
                  '$score%',
                  Icons.analytics_outlined,
                ),
                _detailRow(
                  'Potential Violations',
                  violations,
                  Icons.warning_amber_rounded,
                ),
                _detailRow(
                  'Verification',
                  verified.toLowerCase() == 'true'
                      ? 'OFFICER VERIFIED'
                      : 'NOT VERIFIED',
                  Icons.verified_user_outlined,
                ),
                _detailRow(
                  'Officer ID',
                  officerId,
                  Icons.badge_outlined,
                ),
                _detailRow(
                  'Location',
                  location,
                  Icons.location_on_outlined,
                ),
                _detailRow(
                  'Barcode / QR',
                  barcode,
                  Icons.qr_code_2_outlined,
                ),
                _detailRow(
                  'Product Category',
                  category,
                  Icons.category_outlined,
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'Inspection Evidence',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            if (imagePath.isNotEmpty && File(imagePath).existsSync())
              Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Evidence image is not available at the saved location.',
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            _infoCard(
              'Officer Remarks',
              [
                Text(
                  remarks,
                  style: const TextStyle(
                    height: 1.45,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              'Saved Inspection Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                extractedText,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _generateReport(context),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text(
                  'GENERATE / DOWNLOAD PDF REPORT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('BACK TO HISTORY'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractBarcode(String extractedText) {
    final lines = extractedText.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.toUpperCase().startsWith('BARCODE / QR PRODUCT ID:')) {
        final value = trimmed.substring(
          'BARCODE / QR PRODUCT ID:'.length,
        ).trim();

        if (value.isNotEmpty) return value;
      }

      if (trimmed.toUpperCase().startsWith('BARCODE:')) {
        final value = trimmed.substring('BARCODE:'.length).trim();

        if (value.isNotEmpty) return value;
      }
    }

    return 'Not recorded';
  }

  Widget _infoCard(
    String title,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: Colors.indigo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}