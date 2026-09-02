import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/compliance_rule.dart';
import '../models/officer_session.dart';
import '../models/product_category.dart';
import '../services/compliance_engine.dart';
import '../services/database_service.dart';
import '../services/report_service.dart';

class OfficerVerificationScreen extends StatefulWidget {
  final XFile image;
  final ExtractedProductData initialProduct;
  final List<ComplianceResult> results;
  final String extractedText;
  final String? barcode;
  final String? barcodeNote;
  final ProductCategoryInfo category;

  const OfficerVerificationScreen({
    super.key,
    required this.image,
    required this.initialProduct,
    required this.results,
    required this.extractedText,
    this.barcode,
    this.barcodeNote,
    required this.category,
  });

  @override
  State<OfficerVerificationScreen> createState() =>
      _OfficerVerificationScreenState();
}

class _OfficerVerificationScreenState
    extends State<OfficerVerificationScreen> {
  late TextEditingController productController;
  late TextEditingController mrpController;
  late TextEditingController unitSalePriceController;
  late TextEditingController quantityController;
  late TextEditingController manufacturerController;
  late TextEditingController originController;
  late TextEditingController manufactureDateController;
  late TextEditingController expiryController;
  late TextEditingController consumerCareController;
  late TextEditingController officerIdController;
  late TextEditingController locationController;
  late TextEditingController remarksController;

  late final String inspectionId;
  late final DateTime inspectionTime;

  bool confirmed = false;

  @override
  void initState() {
    super.initState();

    inspectionTime = DateTime.now();
    inspectionId =
        'LM-${inspectionTime.year}'
        '${inspectionTime.month.toString().padLeft(2, '0')}'
        '${inspectionTime.day.toString().padLeft(2, '0')}-'
        '${inspectionTime.hour.toString().padLeft(2, '0')}'
        '${inspectionTime.minute.toString().padLeft(2, '0')}'
        '${inspectionTime.second.toString().padLeft(2, '0')}';

    productController =
        TextEditingController(text: widget.initialProduct.productName);
    mrpController =
        TextEditingController(text: widget.initialProduct.mrp);
    unitSalePriceController =
        TextEditingController(text: widget.initialProduct.unitSalePrice);
    quantityController =
        TextEditingController(text: widget.initialProduct.netQuantity);
    manufacturerController =
        TextEditingController(text: widget.initialProduct.manufacturer);
    originController =
        TextEditingController(text: widget.initialProduct.countryOfOrigin);
    manufactureDateController =
        TextEditingController(text: widget.initialProduct.manufactureDate);
    expiryController =
        TextEditingController(text: widget.initialProduct.expiryDate);
    consumerCareController =
        TextEditingController(text: widget.initialProduct.consumerCare);

    officerIdController = TextEditingController(
      text: OfficerSession.officerId ?? '',
    );
    locationController = TextEditingController();
    remarksController = TextEditingController();
  }

  @override
  void dispose() {
    productController.dispose();
    mrpController.dispose();
    unitSalePriceController.dispose();
    quantityController.dispose();
    manufacturerController.dispose();
    originController.dispose();
    manufactureDateController.dispose();
    expiryController.dispose();
    consumerCareController.dispose();
    officerIdController.dispose();
    locationController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> saveVerifiedInspection() async {
    if (!confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm officer verification first.')),
      );
      return;
    }
    if (officerIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Officer ID before verification.')),
      );
      return;
    }
    if (locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter inspection location.')),
      );
      return;
    }

    final violations = widget.results.where(
      (r) => !r.detected && !r.rule.conditional,
    ).length;
    final passed = widget.results.where((r) => r.detected).length;
    final score = widget.results.isEmpty
        ? 0
        : ((passed / widget.results.length) * 100).round();

    String evidenceHash;
    try {
      final bytes = await File(widget.image.path).readAsBytes();
      evidenceHash = sha256.convert(bytes).toString();
    } catch (_) {
      evidenceHash = '';
    }

        // Check the actual image fingerprint before saving.
    if (evidenceHash.isNotEmpty) {
      final duplicate = await DatabaseService().isDuplicateInspection(
        imagePath: widget.image.path,
        extractedText: widget.extractedText,
        evidenceKey: evidenceHash,
      );

      if (duplicate) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 52,
            ),
            title: const Text('Duplicate Inspection'),
            content: const Text(
              'This evidence appears to have already been submitted. ' 
              'The inspection was not saved again.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    final auditRecord = '''
AUDIT METADATA
Inspection ID: $inspectionId
Officer ID: ${officerIdController.text.trim()}
Product Category: ${widget.category.label}
Inspection Location: ${locationController.text.trim()}
Inspection Date/Time: ${inspectionTime.toIso8601String()}
Barcode / QR Product ID: ${widget.barcode ?? widget.barcodeNote ?? 'Not scanned'}
Verification Status: OFFICER VERIFIED
Evidence SHA-256: ${evidenceHash.isEmpty ? 'Unavailable' : evidenceHash}
Officer Remarks: ${remarksController.text.trim().isEmpty ? 'None' : remarksController.text.trim()}
''';

    await DatabaseService().saveInspection(
      productName: productController.text.trim().isEmpty
          ? 'Unknown Product'
          : productController.text.trim(),
      inspectionDate: inspectionTime.toIso8601String(),
      extractedText: '${widget.extractedText}\n\n$auditRecord',
      score: score,
      violationCount: violations,
      imagePath: widget.image.path,
      evidenceKey: evidenceHash.isEmpty ? null : evidenceHash,
      officerId: officerIdController.text.trim(),
      location: locationController.text.trim(),
      officerRemarks: remarksController.text.trim(),
      productCategory: widget.category.label,
      verified: true,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified, color: Colors.green, size: 50),
        title: const Text('Inspection Verified'),
        content: Text(
          'Inspection $inspectionId has been saved.\n\n'
          'Officer: ${officerIdController.text.trim()}\n'
          'Location: ${locationController.text.trim()}\n'
          'Evidence fingerprint: ${evidenceHash.isEmpty ? 'Unavailable' : 'SHA-256 recorded'}',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Verification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    child: Icon(Icons.verified_user_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Officer Verification',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Review and confirm extracted evidence',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          inspectionId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Inspection Metadata',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            _metadataCard(
              Icons.badge_outlined,
              'Inspection ID',
              inspectionId,
            ),
            _metadataCard(
              Icons.schedule_outlined,
              'Inspection Date / Time',
              inspectionTime.toLocal().toString(),
            ),
            _metadataCard(
              Icons.qr_code_2_outlined,
              'Barcode / QR Product ID',
              widget.barcode ?? widget.barcodeNote ?? 'Not scanned',
            ),
            _editField(
              'Officer ID',
              officerIdController,
              Icons.badge,
            ),
            _editField(
              'Inspection Location',
              locationController,
              Icons.location_on_outlined,
            ),
            _editField(
              'Officer Remarks (Optional)',
              remarksController,
              Icons.notes_outlined,
            ),

            const SizedBox(height: 12),

            const Text(
              'Verify Extracted Information',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'OCR results can contain errors. Correct any field before confirming the inspection.',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 18),

            _categoryReadOnlyCard(widget.category),

            const SizedBox(height: 14),

            if (widget.category.isAdvisoryOnly) ...[
              _verificationAdvisoryBanner(widget.category),
              const SizedBox(height: 14),
            ],

            _editField(
              'Product Name',
              productController,
              Icons.inventory_2_outlined,
            ),
            _editField(
              'Maximum Retail Price',
              mrpController,
              Icons.currency_rupee,
            ),
            _editField(
              'Unit Sale Price',
              unitSalePriceController,
              Icons.price_change_outlined,
            ),
            _editField(
              'Net Quantity',
              quantityController,
              Icons.scale_outlined,
            ),
            _editField(
              'Manufacturer / Packer',
              manufacturerController,
              Icons.factory_outlined,
            ),
            _editField(
              'Country of Origin',
              originController,
              Icons.public,
            ),
            _editField(
              'Manufacture / Packing Date',
              manufactureDateController,
              Icons.calendar_month_outlined,
            ),
            _editField(
              'Best Before / Use By',
              expiryController,
              Icons.event_available_outlined,
            ),
            _editField(
              'Consumer Care',
              consumerCareController,
              Icons.support_agent_outlined,
            ),

            const SizedBox(height: 15),

            const Text(
              'Automated Findings',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            ...widget.results.map(
              (result) => _verificationFinding(result),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: confirmed
                      ? Colors.green
                      : Colors.grey.shade300,
                ),
              ),
              child: CheckboxListTile(
                value: confirmed,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    confirmed = value ?? false;
                  });
                },
                title: const Text(
                  'I have reviewed the extracted information and automated findings.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'The final inspection record will be stored as officer-verified.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                onPressed: saveVerifiedInspection,
                icon: const Icon(Icons.verified_outlined),
                label: const Text(
                  'CONFIRM & SAVE INSPECTION',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final verifiedProduct = ExtractedProductData(
                    productName: productController.text.trim().isEmpty
                        ? 'Unknown Product'
                        : productController.text.trim(),
                    mrp: mrpController.text.trim(),
                    unitSalePrice: unitSalePriceController.text.trim(),
                    netQuantity: quantityController.text.trim(),
                    manufacturer: manufacturerController.text.trim(),
                    countryOfOrigin: originController.text.trim(),
                    manufactureDate:
                        manufactureDateController.text.trim(),
                    expiryDate: expiryController.text.trim(),
                    consumerCare: consumerCareController.text.trim(),
                  );

                  try {
                    await ReportService.generateReport(
                      product: verifiedProduct,
                      results: widget.results,
                      extractedText:
                          '${widget.extractedText}\n\n'
                          'AUDIT METADATA\n'
                          'Inspection ID: $inspectionId\n'
                          'Officer ID: ${officerIdController.text.trim().isEmpty ? 'Not entered' : officerIdController.text.trim()}\n'
                          'Product Category: ${widget.category.label}\n'
                          'Inspection Location: ${locationController.text.trim().isEmpty ? 'Not entered' : locationController.text.trim()}\n'
                          'Inspection Date/Time: ${inspectionTime.toIso8601String()}\n'
                          'Barcode / QR Product ID: ${widget.barcode ?? widget.barcodeNote ?? 'Not scanned'}\n'
                          'Verification Status: ${confirmed ? 'OFFICER VERIFIED' : 'PENDING OFFICER VERIFICATION'}\n'
                          'Officer Remarks: ${remarksController.text.trim().isEmpty ? 'None' : remarksController.text.trim()}',
                      imagePath: widget.image.path,
                      barcode: widget.barcode,
                      barcodeNote: widget.barcodeNote,
                      category: widget.category.label,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not generate report: $e'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text(
                  'GENERATE PDF REPORT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('BACK TO RESULTS'),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Automated screening is advisory. Final determination requires authorised officer verification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metadataCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _categoryReadOnlyCard(ProductCategoryInfo category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: category.color),
      ),
      child: Row(
        children: [
          Icon(category.icon, color: category.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Category',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationAdvisoryBanner(ProductCategoryInfo category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.orange.withValues(alpha: .4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category.label} — Advisory Only',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Category-specific compliance rules are not currently available. "
                  'Results are advisory and require officer verification. '
                  'This product is not labelled as food-compliant.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationFinding(ComplianceResult result) {
    final Color color;

    if (result.detected) {
      color = Colors.green;
    } else if (result.rule.conditional) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.detected
                ? Icons.check_circle
                : result.rule.conditional
                    ? Icons.help_outline
                    : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.rule.declaration,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  result.status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.evidence,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
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