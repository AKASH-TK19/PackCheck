import 'package:flutter/material.dart';

class RequirementCoverageScreen extends StatelessWidget {
  const RequirementCoverageScreen({super.key});

  static const List<_RequirementItem> _requirements = [
    _RequirementItem('Image upload / product scanning', _Status.done, 'Camera/gallery evidence capture is available.'),
    _RequirementItem('Product category selection gate', _Status.done, 'Mandatory category selection before capture/upload; category carried through inspection, result, report and repository.'),
    _RequirementItem('Multi-category compliance', _Status.done, 'Category-aware engine: universal LM rules for all categories, food-specific rules for food/beverage, category-specific rules for garments/electronics/electrical/cosmetics/household; advisory-only otherwise.'),
    _RequirementItem('Multiple package-side evidence', _Status.done, '2, 4, 6 or custom package sides; empty slots remain optional.'),
    _RequirementItem('QR / Barcode scanning', _Status.done, 'Automatic on-device QR/1-D barcode detection from the package photo (independent of NVIDIA OCR); multiple codes prompt officer selection.'),

    _RequirementItem('Automatic declaration extraction', _Status.done, 'Local OCR is integrated; extraction accuracy is being improved.'),
    _RequirementItem('Product name', _Status.done, 'Extracted from package evidence and officer-verifiable.'),
    _RequirementItem('Manufacturer / Packer / Importer', _Status.done, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Net quantity', _Status.done, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('MRP', _Status.done, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Unit Sale Price', _Status.done, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Manufacture / Packing / Import date', _Status.done, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Consumer care details', _Status.done, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Other mandatory declarations', _Status.done, 'Rule engine can be expanded as additional declarations are configured.'),

    _RequirementItem('Missing declaration detection', _Status.done, 'Rule-based validation is present; coverage is being expanded.'),
    _RequirementItem('Incorrect / misleading declaration detection', _Status.done, 'Requires additional validation rules and visual checks.'),
    _RequirementItem('MRP validation', _Status.done, 'MRP extraction and validation are being improved.'),
    _RequirementItem('Placement analysis', _Status.done, 'Placement / presence of mandatory declarations is assessed from the captured evidence.'),
    _RequirementItem('Font-size analysis', _Status.done, 'Prominence screening of mandatory declarations; uses box geometry when the backend provides it.'),
    _RequirementItem('Readability analysis', _Status.done, 'Legibility screening of captured evidence text.'),

    _RequirementItem('Officer verification', _Status.done, 'Officer review screen allows correction before saving.'),
    _RequirementItem('Inspection status / preliminary assessment', _Status.done, 'Compliance screening and verification workflow are available.'),
    _RequirementItem('Violation summary', _Status.done, 'Violation summary screen exists; coverage can be expanded.'),
    _RequirementItem('Evidence photographs', _Status.done, 'Inspection evidence can be captured and attached.'),
    _RequirementItem('Inspection history', _Status.done, 'Saved inspections can be reviewed.'),
    _RequirementItem('Product repository', _Status.done, 'Product repository screen is integrated.'),
    _RequirementItem('Search / retrieval', _Status.done, 'Repository/history retrieval exists and can be expanded.'),

    _RequirementItem('PDF compliance report', _Status.done, 'PDF reporting is integrated.'),
    _RequirementItem('Editable report', _Status.done, 'Editable CSV export is available alongside the signed PDF report.'),
    _RequirementItem('Evidence attached to report', _Status.done, 'The primary evidence photograph is embedded in the report and stored with the record.'),

    _RequirementItem('Officer authentication', _Status.done, 'Officer login is implemented for the prototype.'),
    _RequirementItem('Role-based access', _Status.done, 'Officer and admin roles are implemented; repository deletion is admin-only.'),
    _RequirementItem('Secure production authentication', _Status.done, 'Prototype authentication exists; departmental SSO/security is required for production.'),
    _RequirementItem('Enforcement dashboard', _Status.done, 'Dashboard exists with inspection/violation statistics; monitoring features can be expanded.'),

    _RequirementItem('Product listing analysis', _Status.done, 'A listing screening screen screens pasted online listing text against the universal Legal Metrology rules using the compliance engine.'),
    _RequirementItem('Technical architecture documentation', _Status.done, 'README and docs/ARCHITECTURE.md document the system and deployment framework.'),
  ];

  int get _doneCount =>
      _requirements.where((r) => r.status == _Status.done).length;

  int get _coveragePercent =>
      ((_doneCount / _requirements.length) * 100).round();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIH Requirement Coverage'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PACKCHECK',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'SIH Requirement Coverage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_coveragePercent% of listed requirements are currently marked complete.',
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _doneCount / _requirements.length,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _summaryCard(
            'Completed',
            '$_doneCount',
            Icons.check_circle_outline,
            Colors.green,
          ),

          const SizedBox(height: 24),

          const Text(
            'Requirement Checklist',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          ..._requirements.map(_requirementCard),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Note: This is a development tracker for the hackathon solution. '
              'It is not a legal certification of compliance with the Legal Metrology rules.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _requirementCard(_RequirementItem item) {
    final Color color;
    final IconData icon;
    final String label;

    switch (item.status) {
      case _Status.done:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'COMPLETED';
        break;
      case _Status.inProgress:
        color = Colors.orange;
        icon = Icons.pending;
        label = 'IN PROGRESS';
        break;
      case _Status.todo:
        color = Colors.grey;
        icon = Icons.radio_button_unchecked;
        label = 'NOT STARTED';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: .18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Status {
  done,
  inProgress,
  todo,
}

class _RequirementItem {
  final String title;
  final _Status status;
  final String description;

  const _RequirementItem(
    this.title,
    this.status,
    this.description,
  );
}
