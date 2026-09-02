class ComplianceRule {
  final String id;
  final String declaration;
  final String description;
  final String legalReference;
  final String severity;
  final bool conditional;

  const ComplianceRule({
    required this.id,
    required this.declaration,
    required this.description,
    required this.legalReference,
    required this.severity,
    this.conditional = false,
  });
}

class ComplianceResult {
  final ComplianceRule rule;
  final bool detected;
  final String evidence;
  final String status;

  const ComplianceResult({
    required this.rule,
    required this.detected,
    required this.evidence,
    required this.status,
  });
}