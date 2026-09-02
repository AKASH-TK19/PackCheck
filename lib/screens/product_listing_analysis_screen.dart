import 'package:flutter/material.dart';

import '../models/compliance_rule.dart';
import '../services/compliance_engine.dart';

/// Online / e-commerce listing analysis.
///
/// An officer pastes the textual listing information for a product being sold
/// on an e-commerce platform. The screen reuses the category-aware compliance
/// engine (with universal Legal Metrology rules) to extract the mandatory
/// product declarations and screen them for missing or incorrect information,
/// mirroring the on-package inspection workflow.
class ProductListingAnalysisScreen extends StatefulWidget {
  const ProductListingAnalysisScreen({super.key});

  @override
  State<ProductListingAnalysisScreen> createState() =>
      _ProductListingAnalysisScreenState();
}

class _ProductListingAnalysisScreenState
    extends State<ProductListingAnalysisScreen> {
  final TextEditingController _listingController = TextEditingController();
  ComplianceAnalysis? _analysis;
  bool _analyzing = false;

  @override
  void dispose() {
    _listingController.dispose();
    super.dispose();
  }

  Future<void> _analyse() async {
    final text = _listingController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste the product listing text first.'),
        ),
      );
      return;
    }

    setState(() => _analyzing = true);
    // Universal (non-category-specific) rules apply to any online listing.
    final analysis = ComplianceEngine.analyzeFull(text);
    if (!mounted) return;
    setState(() {
      _analysis = analysis;
      _analyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    final score =
        analysis == null ? 0 : ComplianceEngine.score(analysis.results);
    final verdict = ComplianceEngine.verdict(score);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Listing Analysis'),
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
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ONLINE / E-COMMERCE LISTING',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Listing Compliance Screening',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Paste the textual product listing details as shown online. '
                    'Mandatory declarations are extracted and screened against the '
                    'universal Legal Metrology rules.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Listing text',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _listingController,
                    maxLines: 8,
                    minLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. "Classic Salt 100g, MRP Rs 20, '
                          'Manufactured by Tasty Foods Pvt Ltd, '
                          'Country of Origin: India..."',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _analyzing ? null : _analyse,
                      icon: _analyzing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.analytics_outlined),
                      label: Text(
                        _analyzing ? 'ANALYSING...' : 'ANALYSE LISTING',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (analysis != null) ...[
              const SizedBox(height: 18),

              // Overall verdict card.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _verdictColor(verdict).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Text(
                      verdict.emoji,
                      style: const TextStyle(fontSize: 34),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${verdict.label} · Score $score',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: _verdictColor(verdict),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${analysis.results.where((r) => r.isDetected).length} '
                            'of ${analysis.results.length} checks detected.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Extracted Declarations',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _declarationCard('Product name', analysis.product.productName),
              _declarationCard('MRP', analysis.product.mrp),
              _declarationCard('Net quantity', analysis.product.netQuantity),
              _declarationCard('Unit sale price', analysis.product.unitSalePrice),
              _declarationCard(
                'Manufacturer / Packer / Importer',
                analysis.product.manufacturer,
              ),
              _declarationCard(
                'Country of origin',
                analysis.product.countryOfOrigin,
              ),
              _declarationCard(
                'Manufacture / packing date',
                analysis.product.manufactureDate,
              ),
              _declarationCard('Best-before / expiry', analysis.product.expiryDate),
              _declarationCard('Consumer care', analysis.product.consumerCare),

              const SizedBox(height: 18),

              const Text(
                'Rule-by-Rule Screening',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...analysis.results.map(_resultCard),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Screening is advisory. A listed claim still requires '
                  'verification against the actual package and a decision by an '
                  'authorised officer.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _verdictColor(ComplianceVerdict verdict) {
    switch (verdict) {
      case ComplianceVerdict.compliant:
        return Colors.green;
      case ComplianceVerdict.needsReview:
        return Colors.orange;
      case ComplianceVerdict.actionRequired:
        return Colors.red;
    }
  }

  Color _stateColor(ComplianceState state) {
    switch (state) {
      case ComplianceState.verified:
        return Colors.green;
      case ComplianceState.violation:
        return Colors.red;
      case ComplianceState.needsVerification:
        return Colors.orange;
    }
  }

  String _severityLabel(String severity) {
    final s = severity.toUpperCase();
    switch (s) {
      case 'HIGH':
        return 'HIGH';
      case 'MEDIUM':
        return 'MEDIUM';
      default:
        return s;
    }
  }

  Widget _declarationCard(String label, String value) {
    final isDetected = value.isNotEmpty && value != 'Not detected' &&
        value != 'Unknown Product';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDetected ? Icons.check_circle_outline : Icons.help_outline,
            color: isDetected ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(ComplianceResult result) {
    final color = _stateColor(result.state);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.state.emoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.rule.declaration,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      _severityLabel(result.rule.severity),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.evidence,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
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
}
