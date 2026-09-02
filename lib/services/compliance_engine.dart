import '../data/compliance_rules.dart';
import '../models/compliance_rule.dart';
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
  static ComplianceAnalysis analyzeFull(String text) {
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

    return ComplianceAnalysis(
      product: product,
      results: _validate(lower, product),
    );
  }

  static List<ComplianceResult> analyze(String text) {
    return analyzeFull(text).results;
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
      final sameLine = amount.firstMatch(
        lines[i].substring(
          mrpLabel.firstMatch(lines[i])!.end,
        ),
      );
      if (sameLine != null) {
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
        if (match != null) {
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
          return _cleanLine(match.group(1)!);
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

    return collapsed == null
        ? 'Not detected'
        : _cleanLine(collapsed.group(1)!);
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
      if (match != null) return _cleanDeclaration(match.group(1)!);
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

  static List<ComplianceResult> _validate(
    String text,
    ExtractedProductData product,
  ) {
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

    for (final rule in ComplianceRules.rules) {
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

        default:
          detected = false;
          evidence = 'Rule requires officer verification.';
      }

      final status = detected
          ? 'DETECTED'
          : rule.conditional
              ? 'VERIFY'
              : 'POTENTIAL VIOLATION';

      results.add(
        ComplianceResult(
          rule: rule,
          detected: detected,
          evidence: evidence,
          status: status,
        ),
      );
    }

    return results;
  }
}
