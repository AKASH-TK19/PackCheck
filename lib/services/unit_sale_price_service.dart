class UnitSalePriceResult {
  final bool applicable;
  final bool detected;
  final bool calculationPossible;
  final bool consistent;
  final String expectedUnit;
  final double? calculatedUnitPrice;
  final double? detectedUnitPrice;
  final String status;
  final String explanation;

  const UnitSalePriceResult({
    required this.applicable,
    required this.detected,
    required this.calculationPossible,
    required this.consistent,
    required this.expectedUnit,
    required this.calculatedUnitPrice,
    required this.detectedUnitPrice,
    required this.status,
    required this.explanation,
  });
}

class UnitSalePriceService {
  /// Implements the unit-selection logic from Rule 6(11) of the
  /// Legal Metrology (Packaged Commodities) Rules, 2011 as amended
  /// by the 2022 amendment, which came into force on 1 July 2023
  /// after subsequent commencement-date amendments.
  ///
  /// This is a screening/calculation aid, not a legal certification.
  static UnitSalePriceResult evaluate({
    required String netQuantity,
    required String mrp,
    String? printedUnitSalePrice,
    bool unitSalePriceNotRequired = false,
  }) {
    if (unitSalePriceNotRequired) {
      return const UnitSalePriceResult(
        applicable: false,
        detected: false,
        calculationPossible: false,
        consistent: true,
        expectedUnit: 'N/A',
        calculatedUnitPrice: null,
        detectedUnitPrice: null,
        status: 'NOT REQUIRED / VERIFY',
        explanation:
            'The package may fall under an exception. Officer verification is required.',
      );
    }

    final quantity = _parseQuantity(netQuantity);
    final price = _parseMoney(mrp);

    if (quantity == null || price == null) {
      return const UnitSalePriceResult(
        applicable: true,
        detected: false,
        calculationPossible: false,
        consistent: false,
        expectedUnit: 'VERIFY',
        calculatedUnitPrice: null,
        detectedUnitPrice: null,
        status: 'VERIFY',
        explanation:
            'Net quantity and MRP must both be reliably detected before '
            'the unit sale price can be calculated.',
      );
    }

    final unit = _selectUnit(quantity.value, quantity.unit);
    if (unit == null) {
      return const UnitSalePriceResult(
        applicable: true,
        detected: false,
        calculationPossible: false,
        consistent: false,
        expectedUnit: 'VERIFY',
        calculatedUnitPrice: null,
        detectedUnitPrice: null,
        status: 'VERIFY',
        explanation:
            'The quantity unit is not supported by the current unit-sale-price calculator.',
      );
    }

    final quantityInDeclaredUnit = quantity.value;
    final denominator = unit.denominator(quantityInDeclaredUnit, quantity.unit);

    if (denominator == null || denominator <= 0) {
      return UnitSalePriceResult(
        applicable: true,
        detected: false,
        calculationPossible: false,
        consistent: false,
        expectedUnit: unit.label,
        calculatedUnitPrice: null,
        detectedUnitPrice: null,
        status: 'VERIFY',
        explanation:
            'Quantity conversion for ${unit.label} could not be completed.',
      );
    }

    final calculated = _round2(price.value / denominator);

    final detected = _parsePrintedUnitPrice(printedUnitSalePrice);

    if (detected == null) {
      return UnitSalePriceResult(
        applicable: true,
        detected: false,
        calculationPossible: true,
        consistent: false,
        expectedUnit: unit.label,
        calculatedUnitPrice: calculated,
        detectedUnitPrice: null,
        status: 'MISSING / VERIFY',
        explanation:
            'Expected unit sale price is ₹${calculated.toStringAsFixed(2)} '
            'per ${unit.label}. No readable printed unit-sale-price value was supplied.',
      );
    }

    final consistent = _round2(detected.value) == calculated &&
        _compatibleUnit(detected.unit, unit.label);

    return UnitSalePriceResult(
      applicable: true,
      detected: true,
      calculationPossible: true,
      consistent: consistent,
      expectedUnit: unit.label,
      calculatedUnitPrice: calculated,
      detectedUnitPrice: detected.value,
      status: consistent ? 'PASS' : 'POTENTIAL VIOLATION',
      explanation: consistent
          ? 'Printed unit sale price matches the calculated value after rounding '
              'to two decimal places.'
          : 'Printed unit sale price does not match the calculated value '
              'or uses an inconsistent unit. Officer verification is required.',
    );
  }

  static _Quantity? _parseQuantity(String input) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(mg|g|kg|ml|l|litre|litres|liter|liters|'
      r'cm|m|mm|number|numbers|no\.?|nos\.?|pcs?|pieces?|units?)\b',
      caseSensitive: false,
    ).firstMatch(input);

    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    if (value == null || value <= 0) return null;

    final rawUnit = match.group(2)!.toLowerCase().replaceAll('.', '');

    String unit;
    switch (rawUnit) {
      case 'mg':
        unit = 'mg';
        break;
      case 'g':
        unit = 'g';
        break;
      case 'kg':
        unit = 'kg';
        break;
      case 'ml':
        unit = 'ml';
        break;
      case 'l':
      case 'litre':
      case 'litres':
      case 'liter':
      case 'liters':
        unit = 'l';
        break;
      case 'mm':
        unit = 'mm';
        break;
      case 'cm':
        unit = 'cm';
        break;
      case 'm':
        unit = 'm';
        break;
      default:
        unit = 'number';
    }

    return _Quantity(value, unit);
  }

  static _SaleUnit? _selectUnit(double value, String unit) {
    switch (unit) {
      case 'mg':
      case 'g':
      case 'kg':
        final grams = unit == 'mg'
            ? value / 1000.0
            : unit == 'kg'
                ? value * 1000.0
                : value;

        // Rule 6(11): per gram below 1 kg, per kg above 1 kg.
        if (grams < 1000) {
          return _SaleUnit(
            'g',
            (v, original) {
              if (original == 'mg') return v / 1000.0;
              if (original == 'kg') return v * 1000.0;
              return v;
            },
          );
        }

        return _SaleUnit(
          'kg',
          (v, original) {
            if (original == 'mg') return v / 1000000.0;
            if (original == 'g') return v / 1000.0;
            return v;
          },
        );

      case 'cm':
      case 'mm':
      case 'm':
        final metres = unit == 'mm'
            ? value / 1000.0
            : unit == 'cm'
                ? value / 100.0
                : value;

        // Rule 6(11): per centimetre below 1 m, per metre above 1 m.
        if (metres < 1) {
          return _SaleUnit(
            'cm',
            (v, original) {
              if (original == 'mm') return v / 10.0;
              if (original == 'm') return v * 100.0;
              return v;
            },
          );
        }

        return _SaleUnit(
          'm',
          (v, original) {
            if (original == 'mm') return v / 1000.0;
            if (original == 'cm') return v / 100.0;
            return v;
          },
        );

      case 'ml':
      case 'l':
        final litres = unit == 'ml' ? value / 1000.0 : value;

        // Rule 6(11): per ml below 1 litre, per litre above 1 litre.
        if (litres < 1) {
          return _SaleUnit(
            'ml',
            (v, original) {
              if (original == 'l') return v * 1000.0;
              return v;
            },
          );
        }

        return _SaleUnit(
          'litre',
          (v, original) {
            if (original == 'ml') return v / 1000.0;
            return v;
          },
        );

      case 'number':
        return _SaleUnit(
          'number',
          (v, original) => v,
        );
    }

    return null;
  }

  static _Money? _parseMoney(String input) {
    final match = RegExp(
      r'(?:₹|rs\.?|inr)?\s*(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(input);

    if (match == null) return null;

    final value = double.tryParse(
      match.group(1)!.replaceAll(',', ''),
    );

    if (value == null || value < 0) return null;
    return _Money(value);
  }

  static _PrintedUnitPrice? _parsePrintedUnitPrice(String? input) {
    if (input == null || input.trim().isEmpty) return null;

    final match = RegExp(
      r'(?:₹|rs\.?|inr)?\s*(\d+(?:\.\d{1,2})?)\s*'
      r'(?:per\s*)?(g|kg|ml|l|litre|liter|cm|m|number|unit)\b',
      caseSensitive: false,
    ).firstMatch(input);

    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;

    var unit = match.group(2)!.toLowerCase();

    if (unit == 'l' || unit == 'liter') unit = 'litre';
    if (unit == 'unit') unit = 'number';

    return _PrintedUnitPrice(value, unit);
  }

  static bool _compatibleUnit(String a, String b) {
    final x = a == 'l' ? 'litre' : a;
    final y = b == 'l' ? 'litre' : b;
    return x == y;
  }

  static double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class _Quantity {
  final double value;
  final String unit;

  const _Quantity(this.value, this.unit);
}

class _Money {
  final double value;

  const _Money(this.value);
}

class _PrintedUnitPrice {
  final double value;
  final String unit;

  const _PrintedUnitPrice(this.value, this.unit);
}

class _SaleUnit {
  final String label;
  final double? Function(double value, String originalUnit) denominator;

  const _SaleUnit(this.label, this.denominator);
}
