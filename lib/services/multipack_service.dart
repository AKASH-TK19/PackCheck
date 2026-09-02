class MultiPackResult {
  final bool detected;
  final int? numberOfUnits;
  final double? quantityPerUnit;
  final String? unit;
  final double? totalQuantity;
  final String? totalUnit;
  final String status;
  final String explanation;

  const MultiPackResult({
    required this.detected,
    required this.numberOfUnits,
    required this.quantityPerUnit,
    required this.unit,
    required this.totalQuantity,
    required this.totalUnit,
    required this.status,
    required this.explanation,
  });
}

class MultiPackService {
  /// Detects common multi-pack expressions such as:
  /// 5 x 100 g, 3 x 500 ml, 10 x 1 kg.
  ///
  /// This is a screening aid. The officer should verify the package
  /// physically and against the applicable legal requirements.

  static MultiPackResult analyze(String text) {
    final normalized = text
        .replaceAll('×', 'x')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final match = RegExp(
      r'\b(\d+)\s*x\s*(\d+(?:\.\d+)?)\s*'
      r'(mg|g|kg|ml|l|litre|litres|liter|liters|'
      r'number|numbers|no\.?|nos\.?|pcs?|pieces?|units?)\b',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (match == null) {
      return const MultiPackResult(
        detected: false,
        numberOfUnits: null,
        quantityPerUnit: null,
        unit: null,
        totalQuantity: null,
        totalUnit: null,
        status: 'NOT DETECTED',
        explanation: 'No multi-pack quantity expression was detected.',
      );
    }

    final count = int.tryParse(match.group(1)!);
    final quantity = double.tryParse(match.group(2)!);

    if (count == null || quantity == null || count <= 0 || quantity <= 0) {
      return const MultiPackResult(
        detected: true,
        numberOfUnits: null,
        quantityPerUnit: null,
        unit: null,
        totalQuantity: null,
        totalUnit: null,
        status: 'VERIFY',
        explanation:
            'A multi-pack expression was detected, but its quantities could not be reliably calculated.',
      );
    }

    final unit = _normalizeUnit(match.group(3)!);
    final total = _calculateTotal(count, quantity, unit);

    return MultiPackResult(
      detected: true,
      numberOfUnits: count,
      quantityPerUnit: quantity,
      unit: unit,
      totalQuantity: total.value,
      totalUnit: total.unit,
      status: 'DETECTED',
      explanation:
          '$count units × ${_format(quantity)} $unit = '
          '${_format(total.value)} ${total.unit} total quantity.',
    );
  }

  static String _normalizeUnit(String input) {
    final unit = input.toLowerCase().replaceAll('.', '').trim();

    switch (unit) {
      case 'milligram':
      case 'milligrams':
      case 'mg':
        return 'mg';
      case 'gram':
      case 'grams':
      case 'g':
        return 'g';
      case 'kilogram':
      case 'kilograms':
      case 'kg':
        return 'kg';
      case 'millilitre':
      case 'millilitres':
      case 'milliliter':
      case 'milliliters':
      case 'ml':
        return 'ml';
      case 'litre':
      case 'litres':
      case 'liter':
      case 'liters':
      case 'l':
        return 'l';
      default:
        return 'number';
    }
  }

  static _Total _calculateTotal(
    int count,
    double quantity,
    String unit,
  ) {
    final total = count * quantity;

    if (unit == 'mg' && total >= 1000) {
      return _Total(total / 1000, 'g');
    }

    if (unit == 'g' && total >= 1000) {
      return _Total(total / 1000, 'kg');
    }

    if (unit == 'ml' && total >= 1000) {
      return _Total(total / 1000, 'l');
    }

    return _Total(total, unit);
  }

  static String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _Total {
  final double value;
  final String unit;

  const _Total(this.value, this.unit);
}
