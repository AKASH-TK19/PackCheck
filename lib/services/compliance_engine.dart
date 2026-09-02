import '../data/compliance_rules.dart';
import '../models/compliance_rule.dart';
import '../models/product_category.dart';
import 'unit_sale_price_service.dart';

class ExtractedProductData {
  final String productName;
  final String mrp;
  final String unitSalePrice;
  final String netQuantity;
  final String manufacturer;
  final String countryOfOrigin;
  final String manufactureDate;
  final String expiryDate;
  final String consumerCare;

  const ExtractedProductData({
    required this.productName,
    required this.mrp,
    required this.unitSalePrice,
    required this.netQuantity,
    required this.manufacturer,
    required this.countryOfOrigin,
    required this.manufactureDate,
    required this.expiryDate,
    required this.consumerCare,
  });
}

class ComplianceAnalysis {
  final ExtractedProductData product;
  final List<ComplianceResult> results;

  const ComplianceAnalysis({
    required this.product,
    required this.results,
  });
}

class ComplianceEngine {
  /// Runs the compliance engine for a category (or with no category context).
  ///
  /// When [category] is provided, only the rules applicable to that category are
  /// evaluated — food-specific checks are NOT applied to non-food categories
  /// (garments, electronics, cosmetics, etc.). This keeps the engine as a
  /// multi-category packaged-product compliance scanner.
  ///
  /// [ocrReliable] indicates whether the OCR/image evidence was good enough to
  /// be confident about the absence of a declaration. When false (or when the
  /// OCR text is trivially sparse), undetected mandatory declarations are
  /// reported as *needs verification* rather than confirmed violations. This
  /// prevents a low-quality capture from being automatically flagged.
  static ComplianceAnalysis analyzeFull(
    String text, {
    ProductCategoryInfo? category,
    bool ocrReliable = true,
  }) {
    final normalized = text
        .replaceAll('\r', '\n')
        .replaceAll('\u00A0', ' ')
        .trim();

    final lower = normalized.toLowerCase();

    final productName = _extractProductName(normalized);
    final mrp = _extractMRP(normalized);
    final unitSalePrice = _extractUnitSalePrice(normalized);
    final quantity = _extractQuantity(normalized);
    final manufacturer = _extractManufacturer(normalized);
    final origin = _extractOrigin(normalized);
    final manufactureDate = _extractManufactureDate(normalized);
    final expiryDate = _extractExpiry(normalized);
    final consumerCare = _extractConsumerCare(normalized);

    final product = ExtractedProductData(
      productName: productName,
      mrp: mrp,
      unitSalePrice: unitSalePrice,
      netQuantity: quantity,
      manufacturer: manufacturer,
      countryOfOrigin: origin,
      manufactureDate: manufactureDate,
      expiryDate: expiryDate,
      consumerCare: consumerCare,
    );

    final rules = ComplianceRules.rulesForCategory(category);

    // If the OCR produced almost nothing meaningful, we cannot trust the
    // absence of a declaration. This is a safe, non-fabricating fallback.
    final confidence = ocrReliable && !_isTooSparse(lower);

    return ComplianceAnalysis(
      product: product,
      results: _validate(lower, product, rules, ocrReliable: confidence),
    );
  }

  /// Heuristic: fewer than a handful of meaningful tokens means the OCR text is
  /// too sparse to reliably conclude a declaration is missing.
  static bool _isTooSparse(String lowerText) {
    final meaningful = lowerText
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .length;

    return meaningful < 4;
  }

  static List<ComplianceResult> analyze(String text) {
    return analyzeFull(text).results;
  }

  /// Number of checks that were positively detected (passed).
  static int passedCount(List<ComplianceResult> results) =>
      results.where((r) => r.isDetected).length;

  /// Number of non-detected checks (violations + needs-verification).
  static int issueCount(List<ComplianceResult> results) =>
      results.where((r) => !r.isDetected).length;

  /// Severity-aware score out of 100.
  ///
  /// Each check is weighted by its declared severity so a missing HIGH-priority
  /// declaration (e.g. MRP, net quantity) dents the score far more than a minor
  /// MEDIUM gap. A HIGH check weighs 3x a MEDIUM check. Returns 0 for an empty
  /// list.
  static int score(List<ComplianceResult> results) {
    if (results.isEmpty) return 0;

    var detectedWeight = 0;
    var totalWeight = 0;
    for (final result in results) {
      final weight = _severityWeight(result.rule.severity);
      totalWeight += weight;
      if (result.isDetected) detectedWeight += weight;
    }

    if (totalWeight == 0) return 0;
    return ((detectedWeight / totalWeight) * 100).round();
  }

  /// Relative importance of a rule's severity string. HIGH outranks MEDIUM.
  static int _severityWeight(String severity) {
    switch (severity) {
      case 'HIGH':
        return 3;
      case 'MEDIUM':
        return 1;
      default:
        return 1;
    }
  }

  /// Maps 0..100 score to the green / amber / red verdict band.
  static ComplianceVerdict verdict(int score) {
    if (score >= 80) return ComplianceVerdict.compliant;
    if (score >= 50) return ComplianceVerdict.needsReview;
    return ComplianceVerdict.actionRequired;
  }

  static String _extractProductName(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) return 'Unknown Product';

    final reject = RegExp(
      r'(?:^---\s*evidence\s*photo|^photo\s*\d+|'
      r'\b(?:mrp|m\.r\.p|maximum\s+retail\s+price|'
      r'net\s*(?:quantity|qty|weight|wt)|'
      r'manufactured?\s*by|manufacturer|manufacturing|'
      r'packed\s*by|packer|packing|imported\s*by|importer|'
      r'marketed\s*by|customer\s*care|consumer\s*care|'
      r'best\s*before|use\s*by|expiry|expires?|'
      r'country\s*of\s*origin|made\s*in|product\s*of|'
      r'ingredients?|nutrition|nutritional|energy|protein|'
      r'carbohydrate|fat|sugar|allergen|'
      r'barcode|scan|batch|lot|fssai|license|'
      r'inclusive\s+of\s+all\s+taxes|incl\.?\s*of\s*all\s+taxes)\b)',
      caseSensitive: false,
    );

    final numberOnly = RegExp(
      r'^[\d\s₹$€£.,:/%+\-x×]+$',
      caseSensitive: false,
    );

    final dateOrPrice = RegExp(
      r'(?:₹|rs\.?|inr|\b(?:mfg|mfd|pkd|exp|mrp)\b)|'
      r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b|'
      r'\b\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',
      caseSensitive: false,
    );

    String? best;
    var bestScore = -999;

    for (var i = 0; i < lines.length; i++) {
      final line = _cleanLine(lines[i]);

      if (line.length < 3 || line.length > 80) continue;
      if (reject.hasMatch(line)) continue;
      if (numberOnly.hasMatch(line)) continue;
      if (dateOrPrice.hasMatch(line)) continue;

      final words = RegExp(r"[A-Za-zÀ-ÿ]+").allMatches(line).length;
      if (words < 1) continue;

      var score = 0;

      // Product names are commonly short, word-based lines on the front.
      if (words >= 2) score += 5;
      if (words <= 6) score += 3;
      if (line.length <= 45) score += 2;

      // Prefer earlier evidence lines, but don't force the first OCR line.
      score += (8 - i).clamp(0, 8);

      // Brand/product lines often have capitalization and little punctuation.
      if (RegExp(r"^[A-Za-z0-9][A-Za-z0-9 &+\-''().]{2,79}$")
          .hasMatch(line)) {
        score += 2;
      }

      if (score > bestScore) {
        bestScore = score;
        best = line;
      }
    }

    return best == null ? 'Unknown Product' : _cleanLine(best);
  }


  static String _extractMRP(String text) {
    final lines = text
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // IMPORTANT: never use a generic "₹number" fallback first. A package
    // may print Unit Sale Price immediately after MRP, and that would cause
    // the wrong number to be reported as MRP.
    final mrpLabel = RegExp(
      r'\b(?:m\.?\s*r\.?\s*p\.?|maximum\s+retail\s+price)\b',
      caseSensitive: false,
    );

    final amount = RegExp(
      r'(?:₹|rs\.?|inr)?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      if (!mrpLabel.hasMatch(lines[i])) continue;

      // The value may be on the same line, immediately after MRP.
      final remainder = lines[i].substring(
        mrpLabel.firstMatch(lines[i])!.end,
      );
      final sameLine = amount.firstMatch(remainder);
      if (sameLine != null &&
          !_amountFollowedByNonPrice(remainder.substring(sameLine.end))) {
        return '₹${sameLine.group(1)}';
      }

      // OCR sometimes produces:
      // MRP:
      // ₹169
      // Check only the next two lines.
      for (var j = i + 1; j <= i + 2 && j < lines.length; j++) {
        final next = lines[j];

        // Don't cross into another labelled price field.
        if (RegExp(
          r'\b(?:unit\s*(?:sale|selling)?\s*price|selling\s*price)\b',
          caseSensitive: false,
        ).hasMatch(next)) {
          break;
        }

        final match = amount.firstMatch(next);
        if (match != null &&
            !_amountFollowedByNonPrice(next.substring(match.end))) {
          return '₹${match.group(1)}';
        }
      }
    }

    return 'Not detected';
  }


  static String _extractUnitSalePrice(String text) {
    final lines = text
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final label = RegExp(
      r'\b(?:unit\s*(?:sale|selling)\s*price|'
      r'sale\s*price\s*per\s*(?:kg|g|l|ml|unit|piece)|'
      r'unit\s*price)\b',
      caseSensitive: false,
    );

    final amount = RegExp(
      r'(?:₹|rs\.?|inr)?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      if (!label.hasMatch(lines[i])) continue;

      final labelMatch = label.firstMatch(lines[i])!;
      final remainder = lines[i].substring(labelMatch.end);

      final sameLine = amount.firstMatch(remainder);
      if (sameLine != null) {
        return '₹${sameLine.group(1)}';
      }

      for (var j = i + 1; j <= i + 2 && j < lines.length; j++) {
        final match = amount.firstMatch(lines[j]);
        if (match != null) {
          return '₹${match.group(1)}';
        }
      }
    }

    return 'Not detected';
  }

  static String _extractQuantity(String text) {
    final patterns = [
      RegExp(
        r'(?:net\s*(?:quantity|qty|wt|weight|volume|content))'
        r'\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*'
        r'(mg|g|kg|ml|l|litre|liter|cm|m|'
        r'number|numbers|no\.?|nos\.?|pcs?|pieces?|units?)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(\d+(?:\.\d+)?)\s*'
        r'(mg|g|kg|ml|l|litre|liter|cm|m|'
        r'pcs?|pieces?|units?)\b',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return '${match.group(1)} ${_normalizeUnit(match.group(2)!)}';
      }
    }

    return 'Not detected';
  }

  static String _extractManufacturer(String text) {
    final match = RegExp(
      r'(?:manufactured\s*by|manufacturer|mfg\.?\s*by|'
      r'packed\s*by|packer|packed\s*at|imported\s*by|'
      r'marketed\s*by|marketed\s*at)'
      r'\s*[:\-]?\s*(.{3,160})',
      caseSensitive: false,
    ).firstMatch(text);

    return match == null
        ? 'Not detected'
        : _cleanDeclaration(match.group(1)!);
  }

  static String _extractOrigin(String text) {
    final match = RegExp(
      r'(?:country\s*of\s*origin|country\s*of\s*manufacture|'
      r'made\s*in|product\s*of|origin)'
      r'\s*[:\-]?\s*(.{2,60})',
      caseSensitive: false,
    ).firstMatch(text);

    return match == null
        ? 'Not detected'
        : _cleanDeclaration(match.group(1)!);
  }

  static String _extractManufactureDate(String text) {
    final datePattern = RegExp(
      r'(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}|'
      r'\d{1,2}[\/\-.]\d{2,4}|'
      r'(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|'
      r'jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|'
      r'oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)'
      r'\s*[-\/]?\s*\d{2,4})',
      caseSensitive: false,
    );

    final lines = text
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final label = RegExp(
      r'\b(?:pkd|pkd\.|mfg|mfg\.|mfd|mfd\.|'
      r'manufactured|manufacturing|packed|packing)\b|'
      r'\bdate\s*of\s*(?:mfg|manufacture|packing)\b',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      if (!label.hasMatch(lines[i])) continue;

      // Handles both:
      // PKD: 29 APR 2026
      // and:
      // PKD:
      // 29 APR 2026
      for (var j = i; j <= i + 3 && j < lines.length; j++) {
        final match = datePattern.firstMatch(lines[j]);
        if (match != null) {
          final value = _cleanLine(match.group(1)!);
          if (_plausibleDate(value)) return value;
        }
      }
    }

    // Fallback for OCR that collapsed the label and date into one line.
    final collapsed = RegExp(
      r'(?:pkd|mfg|mfd|manufactured|manufacturing|packed|packing)'
      r'[\s:;\-]*'
      r'(\d{1,2}\s+'
      r'(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|'
      r'jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|'
      r'oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)'
      r'\s+\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);

    if (collapsed == null) return 'Not detected';
    final collapsedValue = _cleanLine(collapsed.group(1)!);
    return _plausibleDate(collapsedValue) ? collapsedValue : 'Not detected';
  }


  static String _extractExpiry(String text) {
    final patterns = [
      RegExp(
        r'(?:best\s*before|use\s*by|expiry|exp\.?|expires)\s*[:\-]?\s*'
        r'((?:\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4})|'
        r'(?:\d{1,2}[\/\-.]\d{2,4})|'
        r'(?:\d{2}[\/\-.]\d{4})|'
        r'(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|'
        r'may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|'
        r'oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s*[-\/]?\s*\d{2,4})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:best\s*before|use\s*by|expiry|exp\.?|expires)'
        r'\s*[:\-]?\s*(.{1,60})',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = _cleanDeclaration(match.group(1)!);
        if (_plausibleDate(value)) return value;
      }
    }

    return 'Not detected';
  }

  static String _extractConsumerCare(String text) {
    final phone = RegExp(r'(?:\+?91[\s\-]?)?[6-9]\d{9}').firstMatch(text);
    final email = RegExp(
      r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
      caseSensitive: false,
    ).firstMatch(text);
    final careLine = RegExp(
      r'(?:customer\s*care|consumer\s*care|helpline|toll\s*free|contact\s*us).{0,140}',
      caseSensitive: false,
    ).firstMatch(text);

    if (careLine != null) return _cleanDeclaration(careLine.group(0)!);
    if (phone != null) return 'Phone: ${phone.group(0)}';
    if (email != null) return 'Email: ${email.group(0)}';

    return 'Not detected';
  }

  static String _normalizeUnit(String unit) {
    switch (unit.toLowerCase().replaceAll('.', '').trim()) {
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
      case 'centimetre':
      case 'centimetres':
      case 'cm':
        return 'cm';
      case 'metre':
      case 'metres':
      case 'meter':
      case 'meters':
      case 'm':
        return 'm';
      default:
        return 'number';
    }
  }

  static String _cleanDeclaration(String value) {
    var cleaned = value
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    cleaned = cleaned.replaceFirst(
      RegExp(
        r'\s+(?:mrp|net\s*(?:quantity|qty)|country\s*of\s*origin|'
        r'customer\s*care|consumer\s*care|best\s*before|use\s*by)\b.*$',
        caseSensitive: false,
      ),
      '',
    );

    return cleaned.trim();
  }

  static String _cleanLine(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Rejects a captured amount when the text right after the number looks like a
  /// quantity/unit/date rather than a price (e.g. "200 g", "20/12/2025").
  static bool _amountFollowedByNonPrice(String afterNumber) {
    final tail = afterNumber.trimLeft();
    if (tail.isEmpty) return false;
    if (RegExp(r'^(?:mg|g|kg|ml|l|litre|liter|cm|m|pcs?|pieces?|nos\.?|numbers?|units?)\b',
        caseSensitive: false).hasMatch(tail)) {
      return true;
    }
    if (RegExp(r'^[\/\-.]\s*\d{1,4}|^(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',
        caseSensitive: false).hasMatch(tail)) {
      return true;
    }
    return false;
  }

  /// Coarse sanity check for an extracted date string. Rejects plainly
  /// impossible values (day > 31, month > 12) while never rejecting the
  /// "Best before 12 months" style non-date phrasing. `fullMatch` anchors both
  /// ends, so an embedded `$` anchor is not required.
  static bool _plausibleDate(String value) {
    final v = value.trim();

    final numeric = RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.]\d{2,4}').firstMatch(v);
    if (numeric != null && numeric.start == 0 && numeric.end == v.length) {
      final day = int.tryParse(numeric.group(1)!) ?? -1;
      final month = int.tryParse(numeric.group(2)!) ?? -1;
      return day >= 1 && day <= 31 && month >= 1 && month <= 12;
    }

    final monthName = RegExp(
        r'(\d{1,2})\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|'
        r'jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{2,4})',
        caseSensitive: false).firstMatch(v);
    if (monthName != null && monthName.start == 0 && monthName.end == v.length) {
      final day = int.tryParse(monthName.group(1)!) ?? -1;
      return day >= 1 && day <= 31;
    }

    return true;
  }

  static List<ComplianceResult> _validate(
    String text,
    ExtractedProductData product,
    List<ComplianceRule> rules, {
    bool ocrReliable = true,
  }) {
    final results = <ComplianceResult>[];

    final importedContext = RegExp(
      r'\b(imported|importer|country\s*of\s*origin|made\s*in)\b',
      caseSensitive: false,
    ).hasMatch(text);

    final hasInclusiveTaxWording = RegExp(
      r'(inclusive\s+of\s+all\s+taxes|incl\.?\s*(?:of\s*)?all\s+taxes|'
      r'all\s+taxes\s+included)',
      caseSensitive: false,
    ).hasMatch(text);

    for (final rule in rules) {
      bool detected = false;
      String evidence = '';

      switch (rule.id) {
        case 'LM-01':
          detected = product.manufacturer != 'Not detected';
          evidence = detected
              ? 'Detected declaration: ${product.manufacturer}'
              : 'Manufacturer / packer / importer declaration not detected.';
          break;

        case 'LM-02':
          detected = product.countryOfOrigin != 'Not detected';
          evidence = detected
              ? 'Detected: ${product.countryOfOrigin}'
              : importedContext
                  ? 'Imported-product context detected, but country of origin was not detected.'
                  : 'Country of origin not detected; verify applicability to the package.';
          break;

        case 'LM-03':
          detected = product.productName != 'Unknown Product';
          evidence = detected
              ? 'Product identification: ${product.productName}'
              : 'Common/generic product name could not be identified.';
          break;

        case 'LM-04':
          detected = product.netQuantity != 'Not detected';
          evidence = detected
              ? 'Detected net quantity: ${product.netQuantity}. '
                  'MPE requires commodity-specific reference data and/or physical verification.'
              : 'Net quantity and prescribed unit not detected.';
          break;

        case 'LM-05':
          detected = product.manufactureDate != 'Not detected';
          evidence = detected
              ? 'Detected manufacture/packing date: ${product.manufactureDate}'
              : 'Manufacture/packing/import date information not detected.';
          break;

        case 'LM-06':
          detected = product.expiryDate != 'Not detected';
          evidence = detected
              ? 'Detected best-before/use-by/expiry information: ${product.expiryDate}'
              : 'Best-before/use-by information not detected; verify applicability.';
          break;

        case 'LM-07':
          detected = product.mrp != 'Not detected';
          evidence = !detected
              ? 'MRP / retail sale price not detected.'
              : hasInclusiveTaxWording
                  ? 'Detected MRP ${product.mrp} with wording indicating inclusion of all taxes.'
                  : 'Detected MRP ${product.mrp}; inclusive-of-all-taxes wording was not detected, so officer verification is required.';
          break;

        case 'LM-08':
          detected = product.consumerCare != 'Not detected';
          evidence = detected
              ? 'Detected consumer-care information: ${product.consumerCare}'
              : 'Consumer-care information not detected.';
          break;

        case 'LM-09':
          detected = RegExp(
            r'(\d+(?:\.\d+)?\s?[x×]\s?\d+(?:\.\d+)?|\d+(?:\.\d+)?\s?cm\b|\d+(?:\.\d+)?\s?mm\b|\d+(?:\.\d+)?\s?(?:m|meter|metre)\b|\bsize\s*(?:s|m|l|xl|xxl|xxxl)\b)',
            caseSensitive: false,
          ).hasMatch(text);

          evidence = detected
              ? 'Possible size/dimension information detected.'
              : 'Size/dimension declaration not detected; verify applicability.';
          break;

        case 'LM-10':
          final unitPrice = UnitSalePriceService.evaluate(
            netQuantity: product.netQuantity,
            mrp: product.mrp,
          );

          detected = unitPrice.detected;
          evidence = unitPrice.explanation;
          break;

        // ===== Readymade Garments / Hosiery =====
        case 'CAT-GAR-01':
          detected = RegExp(
            r'\b(size|fit)\b.{0,24}\b(s|m|l|xl|xxl|xxxl|\d{1,3})\b'
            r'|\b(s|m|l|xl|xxl|xxxl)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Size / fit declaration detected on the garment label.'
              : 'Size / fit declaration not detected on the garment label.';
          break;

        case 'CAT-GAR-02':
          detected = RegExp(
            r'\b(?:cotton|polyester|nylon|wool|silk|rayon|viscose|'
            r'elastane|spandex|linen|blend|composition|fiber|fibre)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Fiber composition / material content detected.'
              : 'Fiber composition / material content not detected.';
          break;

        case 'CAT-GAR-03':
          detected = RegExp(
            r'\b(?:wash\s*(?:care|ing)?|machine\s*wash|do\s+not\s+bleach|'
            r'iron|cool\s+iron|dry\s+clean|cold\s+wash|hand\s+wash)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Washing / care instructions detected.'
              : 'Washing / care instructions not detected.';
          break;

        // ===== Electronics =====
        case 'CAT-ELC-01':
          detected = RegExp(
            r'\b(model|serial|s/n|s\.n\.|part\s+no)\b.{0,24}[A-Za-z0-9\-]{2,}',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Model / serial number detected.'
              : 'Model / serial number not detected.';
          break;

        case 'CAT-ELC-02':
        case 'CAT-ELE-03':
          detected = RegExp(
            r'\b(warrant(y|ies)|guarantee|guaranty)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Warranty / guarantee declaration detected.'
              : 'Warranty / guarantee declaration not detected.';
          break;

        case 'CAT-ELC-03':
          detected = RegExp(
            r'\b(imported\s*by|marketed\s*by|authorized\s*re|'
            r'authorised\s*re|importer)\b.{0,60}',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Importer / authorised representative detail detected.'
              : 'Importer / authorised representative detail not detected.';
          break;

        // ===== Electrical =====
        case 'CAT-ELE-01':
          detected = RegExp(
            r'\b(\d{1,3}\s*v|voltage|volts|watt|wattage|\d+\s*w|\d+\s*amps|'
            r'hz|amp)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Voltage / rating declaration detected.'
              : 'Voltage / rating declaration not detected.';
          break;

        case 'CAT-ELE-02':
          detected = RegExp(
            r'\b(isi[^a-z]|is\s*(?:mark|certified)|certification\s*mark|'
            r'\bis\s*\d{4,}\b)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Safety / certification mark detected.'
              : 'Safety / certification mark not detected; verify applicability.';
          break;

        // ===== Cosmetics / Personal Care =====
        case 'CAT-COS-01':
          detected = RegExp(
            r'\b(ingredients?|composition|aqua|paraben|glycer|'
            r'alcohol|sodium|glycol)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Ingredients / composition declaration detected.'
              : 'Ingredients / composition declaration not detected.';
          break;

        case 'CAT-COS-02':
          detected = product.manufactureDate != 'Not detected' ||
              product.expiryDate != 'Not detected';
          evidence = detected
              ? 'Manufacture and/or expiry (shelf-life) declaration detected '
                  '(mfg: ${product.manufactureDate}, expiry: ${product.expiryDate}).'
              : 'Manufacture and/or expiry (shelf-life) declaration not detected.';
          break;

        case 'CAT-COS-03':
          detected = RegExp(
            r'\b(?:cosmetic\s*license|license\s*no|lic\s*no|'
            r'bo\s*no|batch\s*no|mfg[\s.:-]*lic|approval\s*no|'
            r'cdsco|iso\s*\d{4,})\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Manufacturing license / regulatory authority detected.'
              : 'Manufacturing license / regulatory authority not detected; verify applicability.';
          break;

        // ===== Household Products =====
        case 'CAT-HSE-01':
          detected = RegExp(
            r'\b(usage|instructions?|how\s*to\s*use|directions?|'
            r'dosage|application)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Usage / handling instructions detected.'
              : 'Usage / handling instructions not detected.';
          break;

        case 'CAT-HSE-02':
          detected = RegExp(
            r'\b(caution|warning|keep\s*out|harmful|poison|'
            r'corrosive|flammable|first\s*aid)\b',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Caution / safety warning detected.'
              : 'Caution / safety warning not detected; verify applicability.';
          break;

        case 'CAT-HSE-03':
          detected = RegExp(
            r'\b(batch\s*no|lot\s*no|batch\s*number|lot\s*number|'
            r'b\.\s*no)\b.{0,24}[A-Za-z0-9\-]{2,}',
            caseSensitive: false,
          ).hasMatch(text);
          evidence = detected
              ? 'Batch / lot number detected.'
              : 'Batch / lot number declaration not detected.';
          break;

        default:
          detected = false;
          evidence = 'Rule requires officer verification.';
      }

      // When the OCR evidence is unreliable, a non-detected declaration is NOT
      // a confirmed violation — it needs officer verification instead.
      final uncertain = !detected && !ocrReliable;

      final status = detected
          ? 'DETECTED'
          : (rule.conditional || uncertain)
              ? 'VERIFY'
              : 'POTENTIAL VIOLATION';

      results.add(
        ComplianceResult(
          rule: rule,
          detected: detected,
          // When the check could not be reliably resolved, surface a clear
          // reason instead of a generic "not detected" claim. This explains the
          // uncertainty without inventing any field value — it only points at
          // the insufficient image/OCR evidence.
          evidence: uncertain
              ? 'Could not reliably verify — the image/OCR result was '
                  'insufficient to confidently identify the '
                  '${rule.declaration.toLowerCase()}. ($evidence)'
              : evidence,
          status: status,
          uncertain: uncertain,
        ),
      );
    }

    return results;
  }
}
