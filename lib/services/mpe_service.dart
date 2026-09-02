class MpeResult {
  final bool applicable;
  final bool withinTolerance;
  final String status;
  final String explanation;

  const MpeResult({
    required this.applicable,
    required this.withinTolerance,
    required this.status,
    required this.explanation,
  });
}

class MpeService {
  /// Preliminary reference table for the demo.
  ///
  /// IMPORTANT:
  /// This is not a legal certification engine. Actual permissible
  /// errors depend on the commodity, declared quantity and applicable
  /// government schedule/standard.
  static const Map<String, double> percentageTolerance = {
    'rice': 1.0,
    'wheat': 1.0,
    'flour': 1.0,
    'atta': 1.0,
    'sugar': 1.0,
    'salt': 1.0,
    'dal': 1.0,
    'pulses': 1.0,
    'spices': 1.0,
  };

  static MpeResult evaluate({
    required String productName,
    required String declaredQuantity,
    double? observedQuantity,
  }) {
    final product = productName.toLowerCase().trim();

    if (observedQuantity == null) {
      return MpeResult(
        applicable: false,
        withinTolerance: false,
        status: 'VERIFY',
        explanation:
            'Declared quantity detected, but an observed/measured quantity '
            'was not provided. Physical verification is required for MPE.',
      );
    }

    final tolerance = _findTolerance(product);

    if (tolerance == null) {
      return MpeResult(
        applicable: false,
        withinTolerance: false,
        status: 'VERIFY',
        explanation:
            'No commodity-specific tolerance is configured for this product. '
            'Officer should verify the applicable government schedule.',
      );
    }

    final declared = _extractNumber(declaredQuantity);

    if (declared == null || declared <= 0) {
      return MpeResult(
        applicable: false,
        withinTolerance: false,
        status: 'VERIFY',
        explanation:
            'Declared quantity could not be reliably converted into a '
            'numeric value.',
      );
    }

    final difference = (observedQuantity - declared).abs();
    final allowedError = declared * tolerance / 100.0;

    final within = difference <= allowedError;

    return MpeResult(
      applicable: true,
      withinTolerance: within,
      status: within ? 'PASS' : 'POTENTIAL VIOLATION',
      explanation: within
          ? 'Observed quantity is within the configured preliminary '
              'tolerance of ${tolerance.toStringAsFixed(2)}%.'
          : 'Observed quantity exceeds the configured preliminary '
              'tolerance of ${tolerance.toStringAsFixed(2)}%. '
              'Officer verification is required.',
    );
  }

  static double? _findTolerance(String product) {
    for (final entry in percentageTolerance.entries) {
      if (product.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  static double? _extractNumber(String value) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)',
    ).firstMatch(value);

    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(1)!);
  }
}