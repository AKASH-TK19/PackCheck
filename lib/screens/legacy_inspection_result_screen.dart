import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/compliance_rule.dart';
import '../models/product_category.dart';
import '../services/compliance_engine.dart';
import '../services/ocr_service.dart';
import '../services/readability_service.dart';
import '../services/report_service.dart';
import 'officer_verification_screen.dart';

// Retained for backward compatibility. The active result screen is defined in
// `screens/inspection_result_screen.dart` (class InspectionResultScreen).
class LegacyInspectionResultScreen
    extends StatelessWidget {
  final XFile image;
  final String extractedText;
  final List<OcrLine> ocrLines;
  final String? barcode;
  final String? barcodeNote;
  final ProductCategoryInfo category;

  const LegacyInspectionResultScreen({
    super.key,
    required this.image,
    required this.extractedText,
    this.ocrLines = const [],
    this.barcode,
    this.barcodeNote,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final analysis =
        ComplianceEngine.analyzeFull(
      extractedText,
      category: category,
    );

    final product =
        analysis.product;

    final results =
        analysis.results;

    final readability = ReadabilityService.analyze(
      extractedText,
      lines: ocrLines,
    );

    final passed =
        results.where(
          (r) => r.detected,
        ).length;

    final score =
        ((passed / results.length) *
                100)
            .round();

    final violations =
        results.where(
          (r) =>
              !r.detected &&
              !r.rule.conditional,
        ).toList();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Inspection Result'),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(18),
              decoration:
                  BoxDecoration(
                color: Colors.indigo,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'LEGAL METROLOGY INSPECTION',
                    style: TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Automated Preliminary Assessment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Officer verification required before final record',
                    style: TextStyle(
                      color:
                          Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Evidence Photograph',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              height: 240,
              width: double.infinity,
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              clipBehavior:
                  Clip.antiAlias,
              child: kIsWeb
                  ? Image.network(
                      image.path,
                      fit:
                          BoxFit.contain,
                    )
                  : Image.file(
                      File(image.path),
                      fit:
                          BoxFit.contain,
                    ),
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(24),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Automated Screening',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$score%',
                    style:
                        const TextStyle(
                      fontSize: 52,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.indigo,
                    ),
                  ),
                  Text(
                    violations.isEmpty
                        ? 'NO CONFIGURED VIOLATIONS DETECTED'
                        : '${violations.length} POTENTIAL VIOLATION(S)',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          violations.isEmpty
                              ? Colors.green
                              : Colors.red,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (category.isAdvisoryOnly) ...[
              _advisoryBanner(category),
              const SizedBox(height: 12),
            ],

            if (_categoryMismatchHint(extractedText, category) != null) ...[
              _mismatchBanner(_categoryMismatchHint(extractedText, category)!),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 25),

            const Text(
              'Extracted Product Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _buildField(
              'Product Category',
              category.label,
              category.icon,
            ),

            _buildField(
              'Product',
              product.productName,
              Icons.inventory_2_outlined,
            ),

            _buildField(
              'Barcode / QR Product ID',
              barcode ?? barcodeNote ?? 'Not scanned',
              Icons.qr_code_2_outlined,
            ),

            _buildField(
              'Maximum Retail Price',
              product.mrp,
              Icons.currency_rupee,
            ),

            _buildField(
              'Unit Sale Price',
              product.unitSalePrice,
              Icons.price_change_outlined,
            ),

            _buildField(
              'Net Quantity',
              product.netQuantity,
              Icons.scale_outlined,
            ),

            _buildField(
              'Manufacturer / Packer',
              product.manufacturer,
              Icons.factory_outlined,
            ),

            _buildField(
              'Country of Origin',
              product.countryOfOrigin,
              Icons.public,
            ),

            _buildField(
              'Manufacture / Packing Date',
              product.manufactureDate,
              Icons.calendar_month_outlined,
            ),

            _buildField(
              'Best Before / Use By',
              product.expiryDate,
              Icons.event_available_outlined,
            ),

            _buildField(
              'Consumer Care',
              product.consumerCare,
              Icons.support_agent_outlined,
            ),

            const SizedBox(height: 10),

            ExpansionTile(
              tilePadding:
                  EdgeInsets.zero,
              title: const Text(
                'Raw OCR Evidence',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black87,
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child:
                      SelectableText(
                    extractedText.isEmpty
                        ? 'No text detected.'
                        : extractedText,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Rule Validation',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...results.map(
              (result) =>
                  _ruleCard(result),
            ),

            const SizedBox(height: 25),

            const Text(
              'Potential Violations',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (violations.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.green
                          .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color:
                          Colors.green,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No configured declaration violations detected.',
                      ),
                    ),
                  ],
                ),
              )
            else
              ...violations.map(
                (result) =>
                    _violationCard(result),
              ),

            const SizedBox(height: 25),

            const Text(
              'Font & Readability Check',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Assessment of placement, legibility and the prominence of '
              'mandatory declarations. Advisory only.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 12),

            _readabilityBlock(readability),

            const SizedBox(height: 25),

            // OFFICER VERIFICATION BUTTON
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OfficerVerificationScreen(
                        image: image,
                        initialProduct:
                            product,
                        results: results,
                        extractedText:
                            extractedText,
                        barcode: barcode,
                        barcodeNote: barcodeNote,
                        category: category,

                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.verified_user_outlined,
                ),
                label: const Text(
                  'OFFICER VERIFICATION',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ReportService.generateReport(
                            product: product,
                            results: results,
                            extractedText: extractedText,
                            imagePath: image.path,
                            barcode: barcode,
                            barcodeNote: barcodeNote,
                            category: category.label,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('PDF export failed: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('EXPORT PDF'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ReportService.generateEditableCsv(
                            product: product,
                            results: results,
                            extractedText: extractedText,
                            imagePath: image.path,
                            barcode: barcode,
                            barcodeNote: barcodeNote,
                            category: category.label,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('CSV export failed: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('EXPORT CSV'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'Automated screening is advisory. Final determination requires authorised officer verification.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    String value,
    IconData icon,
  ) {
    final missing =
        value == 'Not detected' ||
        value == 'Unknown Product';

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: missing
              ? Colors.orange
                  .withValues(alpha: .25)
              : Colors.grey
                  .withValues(alpha: .12),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: missing
                ? Colors.orange
                : Colors.indigo,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color: missing
                        ? Colors.orange
                            .shade800
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            missing
                ? Icons
                    .warning_amber_rounded
                : Icons.check_circle,
            size: 20,
            color: missing
                ? Colors.orange
                : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _ruleCard(
    ComplianceResult result,
  ) {
    final Color color;

    if (result.detected) {
      color = Colors.green;
    } else if (result.rule.conditional) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            result.detected
                ? Icons.check_circle
                : result.rule.conditional
                    ? Icons.help_outline
                    : Icons.cancel,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  result.rule.declaration,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  result.evidence,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _violationCard(
    ComplianceResult result,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            Colors.red.withValues(alpha: .06),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color:
              Colors.red.withValues(alpha: .2),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  result.rule.declaration,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 6),
                Text(result.evidence),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readabilityBlock(
    ReadabilityAnalysis readability,
  ) {
    final Color sectionColor;

    if (readability.concernCount > 0) {
      sectionColor = Colors.orange;
    } else {
      sectionColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: sectionColor
              .withValues(alpha: .25),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                readability.concernCount > 0
                    ? Icons.manage_search
                    : Icons.spellcheck,
                color: sectionColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  readability.concernCount > 0
                      ? '${readability.concernCount} item(s) '
                          'need verification'
                      : 'Overall readable and well placed',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (readability
              .placementFindings
              .isNotEmpty) ...[
            const Text(
              'Placement',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...readability
                .placementFindings
                .map(_readabilityFindingCard),
            const SizedBox(height: 10),
          ],

          if (readability
              .readabilityFindings
              .isNotEmpty) ...[
            const Text(
              'Readability',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...readability
                .readabilityFindings
                .map(_readabilityFindingCard),
            const SizedBox(height: 10),
          ],

          if (readability
              .fontSizeFindings
              .isNotEmpty) ...[
            const Text(
              'Font Size',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...readability
                .fontSizeFindings
                .map(_readabilityFindingCard),
          ],
        ],
      ),
    );
  }

  Widget _readabilityFindingCard(
    ReadabilityFinding finding,
  ) {
    final Color color;

    switch (finding.status) {
      case 'PASS':
        color = Colors.green;
        break;
      case 'POTENTIAL VIOLATION':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 6),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            color.withValues(alpha: .05),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: color
              .withValues(alpha: .18),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                finding.concern
                    ? Icons.info_outline
                    : Icons.check_circle_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.title,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                finding.status,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            finding.explanation,
            style: TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Shown when a non-food category is selected. The packaged-food / Legal
  // Metrology rules are not claimed to apply, so the result is advisory only
  // and never label the product as food-compliant.
  Widget _advisoryBanner(
    ProductCategoryInfo category,
  ) {
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
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Category-specific compliance rules are not currently available. "
                  'Results are advisory and require officer verification.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This product is not labelled as food-compliant. Only '
                  'rules applicable to this category are evaluated.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A possible mismatch between the selected category and the contents the
  // vision/OCR engine actually read. This is a hint only — the officer decides.
  String? _categoryMismatchHint(
    String text,
    ProductCategoryInfo category,
  ) {
    if (text.trim().isEmpty) return null;

    final lower = text.toLowerCase();

    if (category.isFood) {
      // Selected as food but the OCR mentions non-food / common household or
      // cosmetic terms.
      final nonFood = RegExp(
        r'\b(?:cosmetic|shampoo|soap|detergent|cleanser|lotion|paint|'
        r'toothpaste|deodorant|perfume|sanitizer|laundry|talc|cream)\b',
        caseSensitive: false,
      );

      if (nonFood.hasMatch(lower)) {
        return 'The selected category is Food/Legal Metrology, but the label '
            'mentions terms that are typically non-food '
            '(cosmetic/household). Please verify the product type.';
      }
    } else {
      // Selected as non-food but the OCR clearly reads packaged-food
      // declarations (best-before, FSSAI, ingredients, net quantity, MRP).
      final food = RegExp(
        r'\b(?:fssai|ingredients?|nutritional|best\s+before|use\s+by|'
        r'net\s+(?:quantity|wt|weight)|maximum\s+retail\s+price|'
        r'allergen|energy|protein|serving\s+size)\b',
        caseSensitive: false,
      );

      if (food.hasMatch(lower)) {
        return 'The selected category is non-food, but the label shows '
            'packaged-food declarations (e.g. best-before, FSSAI, '
            'ingredients, MRP). This may be a category mismatch.';
      }
    }

    return null;
  }

  Widget _mismatchBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.red.withValues(alpha: .4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Possible Category Mismatch',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black87,
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
