class ComplianceRule {
  final String id;
  final String declaration;
  final String description;
  final String legalReference;
  final String severity;
  final bool conditional;

  /// What the declaration should look like when present (used in the
  /// "What should be present?" explanation).
  final String prescribedDeclaration;

  /// Plain-language explanation of why this declaration matters legally or
  /// for consumer safety. Falls back to a generic label when an exact rule is
  /// not confidently identified (never invent legal section numbers).
  final String whyItMatters;

  /// Actionable guidance shown for a missing / verification-needed check.
  final String howToFix;

  const ComplianceRule({
    required this.id,
    required this.declaration,
    required this.description,
    required this.legalReference,
    required this.severity,
    this.conditional = false,
    this.prescribedDeclaration = '',
    this.whyItMatters = 'General compliance requirement',
    this.howToFix = '',
  });
}

class ComplianceResult {
  final ComplianceRule rule;
  final bool detected;
  final String evidence;
  final String status;

  /// Whether the check could not be reliably determined because the image/OCR
  /// evidence was insufficient (e.g. low image quality, sparse OCR). When true,
  /// a non-detected mandatory declaration is reported as *needs verification*
  /// rather than a confirmed violation. Never invented — only set when the
  /// caller flags low-confidence OCR.
  final bool uncertain;

  const ComplianceResult({
    required this.rule,
    required this.detected,
    required this.evidence,
    required this.status,
    this.uncertain = false,
  });

  /// True when the declaration was actually found in the OCR text.
  bool get isDetected => detected;

  /// True when the system cannot confidently confirm or rule out this
  /// declaration (conditional rule that was not detected, or low-confidence OCR
  /// meant the absence of the declaration is not proof of a violation).
  bool get needsVerification => !detected && (rule.conditional || uncertain);

  /// True when the check is a hard, confirmed violation (missing, not
  /// conditional, and the OCR evidence was reliable enough to be confident).
  bool get isViolation => !detected && !rule.conditional && !uncertain;

  /// The tri-state outcome surfaced in the UI and reports.
  ComplianceState get state {
    if (detected) return ComplianceState.verified;
    if (needsVerification) return ComplianceState.needsVerification;
    return ComplianceState.violation;
  }
}

/// The tri-state outcome for a single compliance check. Kept consistent across
/// the result screen, the report and the violation summary.
enum ComplianceState {
  verified,
  violation,
  needsVerification;

  String get label {
    switch (this) {
      case ComplianceState.verified:
        return 'DETECTED';
      case ComplianceState.violation:
        return 'POTENTIAL VIOLATION';
      case ComplianceState.needsVerification:
        return 'NEEDS VERIFICATION';
    }
  }

  String get emoji {
    switch (this) {
      case ComplianceState.verified:
        return '✅';
      case ComplianceState.violation:
        return '❌';
      case ComplianceState.needsVerification:
        return '⚠️';
    }
  }
}

/// Overall verdict bands mapped from a 0..100 compliance score.
enum ComplianceVerdict {
  compliant,
  needsReview,
  actionRequired;

  String get label {
    switch (this) {
      case ComplianceVerdict.compliant:
        // Advisory, not a definitive legal determination: an AI-assisted
        // screening that points to compliance still requires officer review.
        return 'LIKELY COMPLIANT';
      case ComplianceVerdict.needsReview:
        return 'NEEDS REVIEW';
      case ComplianceVerdict.actionRequired:
        return 'ACTION REQUIRED';
    }
  }

  String get emoji {
    switch (this) {
      case ComplianceVerdict.compliant:
        return '🟢';
      case ComplianceVerdict.needsReview:
        return '🟡';
      case ComplianceVerdict.actionRequired:
        return '🔴';
    }
  }
}