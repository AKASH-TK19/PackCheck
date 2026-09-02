import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../models/compliance_rule.dart';
import '../models/product_category.dart';
import '../services/compliance_engine.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../services/readability_service.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../main.dart' show OfficerVerificationScreen;

/// The PackCheck result screen — the visual centrepiece of the app.
///
/// Presents the compliance score as a prominent gauge, then breaks the real
/// compliance-analysis results into clear, actionable sections: issues found,
/// required-vs-detected checklist, scan evidence, legal requirement and the raw
/// OCR text. Nothing here is fabricated — every number comes from
/// [ComplianceEngine] running over the real OCR output.
class InspectionResultScreen extends StatefulWidget {
  final XFile image;
  final String extractedText;
  final List<OcrLine> ocrLines;
  final String? barcode;
  final String? barcodeNote;
  final ProductCategoryInfo category;

  /// When true (low-quality image continued anyway, or untrustworthy OCR), the
  /// compliance engine shows undetected declarations as "needs verification"
  /// rather than confirmed violations.
  final bool ocrLowConfidence;

  const InspectionResultScreen({
    super.key,
    required this.image,
    required this.extractedText,
    this.ocrLines = const [],
    this.barcode,
    this.barcodeNote,
    required this.category,
    this.ocrLowConfidence = false,
  });

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  String? _expandedRuleId;
  bool _saving = false;

  Future<void> _saveToScans({
    required ExtractedProductData product,
    required int score,
    required int issues,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await DatabaseService().saveInspection(
        productName: product.productName,
        inspectionDate: DateTime.now().toIso8601String(),
        extractedText: widget.extractedText,
        score: score,
        violationCount: issues,
        imagePath: widget.image.path,
        productCategory: widget.category.label,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan saved to Recent Scans.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save scan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = ComplianceEngine.analyzeFull(
      widget.extractedText,
      category: widget.category,
      ocrReliable: !widget.ocrLowConfidence,
    );

    final product = analysis.product;
    final results = analysis.results;
    final passed = ComplianceEngine.passedCount(results);
    final issues = ComplianceEngine.issueCount(results);
    final score = ComplianceEngine.score(results);
    final verdict = ComplianceEngine.verdict(score);
    final readability = ReadabilityService.analyze(
      widget.extractedText,
      lines: widget.ocrLines,
    );

    final issuesList = results.where((r) => !r.isDetected).toList();

    final Color verdictColor;
    switch (verdict) {
      case ComplianceVerdict.compliant:
        verdictColor = PackCheckColors.success;
        break;
      case ComplianceVerdict.needsReview:
        verdictColor = PackCheckColors.warning;
        break;
      case ComplianceVerdict.actionRequired:
        verdictColor = PackCheckColors.danger;
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _brandHeader(),
            const SizedBox(height: 18),
            _scorePanel(
              score: score,
              verdict: verdict,
              verdictColor: verdictColor,
              product: product,
            ),
            const SizedBox(height: 18),
            _statsRow(checks: results.length, passed: passed, issues: issues),
            const SizedBox(height: 24),

            // Issues found.
            const SectionHeader(
              title: 'Issues Found',
              subtitle: 'Tap a check to see what is wrong and how to fix it.',
              icon: Icons.report_problem_outlined,
              color: PackCheckColors.danger,
            ),
            const SizedBox(height: 12),
            if (issuesList.isEmpty)
              _passNote()
            else
              ...issuesList.map(
                (r) => _issueCard(r, verdictColor),
              ),
            const SizedBox(height: 24),

            // Compliance checklist.
            const SectionHeader(
              title: 'Compliance Checklist',
              subtitle: 'Required declaration vs what was detected.',
              icon: Icons.checklist_rtl,
            ),
            const SizedBox(height: 12),
            _checklistCard(results),
            const SizedBox(height: 24),

            // Scan evidence.
            const SectionHeader(
              title: 'Scan Evidence',
              subtitle: 'The package image used for this scan.',
              icon: Icons.camera_alt_outlined,
              color: PackCheckColors.info,
            ),
            const SizedBox(height: 12),
            _evidenceCard(),
            const SizedBox(height: 24),

            // Legal requirement.
            const SectionHeader(
              title: 'Legal Requirement',
              subtitle:
                  'Why the missing or unclear declarations matter. Text is '
                  'advisory — no invented section numbers.',
              icon: Icons.gavel_outlined,
            ),
            const SizedBox(height: 12),
            if (issuesList.isEmpty)
              _legalPassNote()
            else
              ...issuesList.map(
                (r) => _legalRequirementCard(r),
              ),
            const SizedBox(height: 24),

            // Detected text.
            const SectionHeader(
              title: 'Detected Text',
              subtitle: 'Raw OCR output returned by the analysis service.',
              icon: Icons.notes_outlined,
            ),
            const SizedBox(height: 12),
            _ocrTextCard(),

            // Readability/placement advisory.
            const SizedBox(height: 24),
            _readabilityBlock(readability),

            const SizedBox(height: 24),
            _actionButtons(
              product: product,
              results: results,
              score: score,
              issues: issues,
            ),
            const SizedBox(height: 14),
            const Text(
              'AI-assisted verification / risk assessment — not a legal '
              'determination. Flagged issues must be verified by an authorised '
              'officer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------

  Widget _brandHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: PackCheckColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: Colors.white, size: 26),
              SizedBox(width: 10),
              Text(
                'PACKCHECK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(widget.category.icon,
                  size: 18, color: Colors.white.withValues(alpha: .9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.category.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scorePanel({
    required int score,
    required ComplianceVerdict verdict,
    required Color verdictColor,
    required ExtractedProductData product,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'AI-ASSISTED VERIFICATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.grey,
            ),
          ),
          ScoreRing(
            score: score.toDouble(),
            label: verdict.emoji,
            color: verdictColor,
            size: 190,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: verdictColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  verdict.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  verdict.label,
                  style: TextStyle(
                    color: verdictColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Risk-band only. Flagged issues require officer verification.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.productName == 'Unknown Product'
                ? '${widget.category.label} scan'
                : product.productName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PackCheckColors.dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow({
    required int checks,
    required int passed,
    required int issues,
  }) {
    return Row(
      children: [
        _statTile(
          '$checks',
          'Checks Performed',
          Icons.list_alt_outlined,
          PackCheckColors.info,
        ),
        const SizedBox(width: 10),
        _statTile(
          '$passed',
          'Passed',
          Icons.check_circle_outline,
          PackCheckColors.success,
        ),
        const SizedBox(width: 10),
        _statTile(
          '$issues',
          'Issues Found',
          Icons.priority_high,
          PackCheckColors.danger,
        ),
      ],
    );
  }

  Widget _statTile(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PackCheckColors.successTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PackCheckColors.success.withValues(alpha: .3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: PackCheckColors.success),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'All applicable declarations were detected. No issues found.',
              style: TextStyle(
                color: PackCheckColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _issueCard(ComplianceResult result, Color verdictColor) {
    final rule = result.rule;
    final isViolation = result.isViolation;
    final color = isViolation
        ? PackCheckColors.danger
        : PackCheckColors.warning;
    final icon = isViolation
        ? Icons.cancel
        : Icons.help_outline;
    final statusText = isViolation
        ? 'Not detected'
        : 'Needs verification';
    final expanded = _expandedRuleId == rule.id;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                _expandedRuleId = expanded ? null : rule.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.declaration,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: PackCheckColors.dark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _explainBlock(
                    icon: Icons.error_outline,
                    title: 'What is wrong?',
                    body: result.evidence,
                    color: color,
                  ),
                  if (rule.prescribedDeclaration.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _explainBlock(
                      icon: Icons.circle_outlined,
                      title: 'What should be present?',
                      body: rule.prescribedDeclaration,
                      color: PackCheckColors.info,
                    ),
                  ],
                  if (rule.howToFix.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _explainBlock(
                      icon: Icons.build_outlined,
                      title: 'How to Fix',
                      body: rule.howToFix,
                      color: PackCheckColors.accent,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _explainBlock({
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: PackCheckColors.dark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _checklistCard(List<ComplianceResult> results) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: results.map((r) {
          final color = r.isDetected
              ? PackCheckColors.success
              : r.needsVerification
                  ? PackCheckColors.warning
                  : PackCheckColors.danger;
          final status = r.isDetected
              ? 'Found'
              : r.needsVerification
                  ? 'Needs Verification'
                  : 'Not Found';
          final symbol = r.isDetected
              ? '✓'
              : r.needsVerification
                  ? '⚠️'
                  : '✗';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                Text(
                  symbol,
                  style: TextStyle(fontSize: 15, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.rule.declaration,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: PackCheckColors.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.isDetected ? 'Detected' : 'Not detected',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _evidenceCard() {
    final normalizedBoxes = widget.ocrLines
        .where((line) =>
            line.x != null &&
            line.y != null &&
            line.width != null &&
            line.height != null &&
            line.x! >= 0 &&
            line.y! >= 0 &&
            line.x! <= 1 &&
            line.y! <= 1 &&
            line.width! > 0 &&
            line.height! > 0 &&
            line.x! + line.width! <= 1.02 &&
            line.y! + line.height! <= 1.02)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1.1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.image.path.endsWith('http')
                      ? Image.network(widget.image.path, fit: BoxFit.contain)
                      : Image.file(File(widget.image.path), fit: BoxFit.contain),
                  if (normalizedBoxes.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: normalizedBoxes
                              .map((line) => Positioned(
                                    left: line.x! * constraints.maxWidth,
                                    top: line.y! * constraints.maxHeight,
                                    width: line.width! * constraints.maxWidth,
                                    height:
                                        line.height! * constraints.maxHeight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: PackCheckColors.success,
                                          width: 2,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _evidenceRow('Barcode / QR',
                  widget.barcode ?? widget.barcodeNote ?? 'Not scanned'),
              _evidenceRow('Product', _productName()),
              _evidenceRow('MRP', _mrp()),
              _evidenceRow('Net Quantity', _netQuantity()),
              _evidenceRow('Manufacturer', _manufacturer()),
            ],
          ),
          if (normalizedBoxes.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Bounding-box coordinates were not returned by the backend, so '
              'only the original image is shown.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _evidenceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PackCheckColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalRequirementCard(ComplianceResult result) {
    final rule = result.rule;
    final color = result.isViolation
        ? PackCheckColors.danger
        : PackCheckColors.warning;
    final status = result.isViolation ? 'Not detected' : 'Needs verification';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rule.declaration,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: PackCheckColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Status: ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rule.whyItMatters.isEmpty
                ? 'General compliance requirement'
                : rule.whyItMatters,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          if (rule.legalReference.isNotEmpty)
            Text(
              rule.legalReference,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: PackCheckColors.info,
              ),
            ),
        ],
      ),
    );
  }

  Widget _legalPassNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PackCheckColors.successTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: PackCheckColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'All applicable mandatory declarations for this category were '
              'detected. No legal requirement is flagged.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ocrTextCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PackCheckColors.dark,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: PackCheckColors.dark,
          collapsedBackgroundColor: PackCheckColors.dark,
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          title: const Text(
            'Show raw OCR text',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  widget.extractedText.trim().isEmpty
                      ? 'No text detected.'
                      : widget.extractedText,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readabilityBlock(ReadabilityAnalysis readability) {
    final Color sectionColor =
        readability.concernCount > 0 ? PackCheckColors.warning : PackCheckColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sectionColor.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      ? '${readability.concernCount} item(s) need verification'
                      : 'Overall readable and well placed',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (readability.placementFindings.isNotEmpty) ...[
            const Text(
              'Placement',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...readability.placementFindings.map(_readabilityFindingCard),
            const SizedBox(height: 10),
          ],
          if (readability.readabilityFindings.isNotEmpty) ...[
            const Text(
              'Readability',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...readability.readabilityFindings.map(_readabilityFindingCard),
            const SizedBox(height: 10),
          ],
          if (readability.fontSizeFindings.isNotEmpty) ...[
            const Text(
              'Font Size',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...readability.fontSizeFindings.map(_readabilityFindingCard),
          ],
        ],
      ),
    );
  }

  Widget _readabilityFindingCard(ReadabilityFinding finding) {
    final Color color;
    switch (finding.status) {
      case 'PASS':
        color = PackCheckColors.success;
        break;
      case 'POTENTIAL VIOLATION':
        color = PackCheckColors.danger;
        break;
      default:
        color = PackCheckColors.warning;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            finding.explanation,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons({
    required ExtractedProductData product,
    required List<ComplianceResult> results,
    required int score,
    required int issues,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            onPressed: _saving
                ? null
                : () => _saveToScans(product: product, score: score, issues: issues),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bookmark_add_outlined),
            label: Text(_saving ? 'SAVING...' : 'SAVE TO RECENT SCANS'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.tonalIcon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OfficerVerificationScreen(
                    image: widget.image,
                    initialProduct: product,
                    results: results,
                    extractedText: widget.extractedText,
                    barcode: widget.barcode,
                    barcodeNote: widget.barcodeNote,
                    category: widget.category,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('OFFICER VERIFICATION'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ReportService.generateReport(
                        product: product,
                        results: results,
                        extractedText: widget.extractedText,
                        imagePath: widget.image.path,
                        barcode: widget.barcode,
                        barcodeNote: widget.barcodeNote,
                        category: widget.category.label,
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('PDF export failed: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ReportService.generateEditableCsv(
                        product: product,
                        results: results,
                        extractedText: widget.extractedText,
                        imagePath: widget.image.path,
                        barcode: widget.barcode,
                        barcodeNote: widget.barcodeNote,
                        category: widget.category.label,
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('CSV export failed: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('CSV'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Small helpers reading real extracted fields for the evidence row.
  String _productName() {
    final analysis = ComplianceEngine.analyzeFull(
      widget.extractedText,
      category: widget.category,
    );
    return analysis.product.productName;
  }

  String _mrp() {
    final analysis = ComplianceEngine.analyzeFull(
      widget.extractedText,
      category: widget.category,
    );
    return analysis.product.mrp;
  }

  String _netQuantity() {
    final analysis = ComplianceEngine.analyzeFull(
      widget.extractedText,
      category: widget.category,
    );
    return analysis.product.netQuantity;
  }

  String _manufacturer() {
    final analysis = ComplianceEngine.analyzeFull(
      widget.extractedText,
      category: widget.category,
    );
    return analysis.product.manufacturer;
  }
}
