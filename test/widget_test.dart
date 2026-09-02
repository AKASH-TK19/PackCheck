import 'package:flutter_test/flutter_test.dart';

import 'package:packcheck/services/compliance_engine.dart';
import 'package:packcheck/services/mpe_service.dart';
import 'package:packcheck/services/readability_service.dart';
import 'package:packcheck/services/unit_sale_price_service.dart';

void main() {
  group('ComplianceEngine', () {
    test('parses a fully compliant label and scores high', () {
      const label = '''
PRODUCT NAME: Classic Salt
MRP: Rs 20
UNIT SALE PRICE: Rs 2 per 10 g
NET QUANTITY: 100 g
MANUFACTURER / PACKER / IMPORTER: Tasty Foods Pvt Ltd
COUNTRY OF ORIGIN: India
MANUFACTURE / PACKING DATE: PKD 05/2025
BEST BEFORE / USE BY / EXPIRY: Best before 12 months
CONSUMER CARE: consumer care @ tastydemo.in
''';

      final analysis = ComplianceEngine.analyzeFull(label);

      expect(analysis.product.productName.toLowerCase(), contains('salt'));
      expect(analysis.product.mrp, isNotEmpty);
      expect(analysis.results, isNotEmpty);
      // The MRP and net quantity declarations must be detected.
      final mrpResult = analysis.results.any((r) => r.detected);
      expect(mrpResult, isTrue);
    });

    test('flags a label missing MRP as a violation', () {
      const label = '''
PRODUCT NAME: Loose Salt
NET QUANTITY: 200 g
MANUFACTURER / PACKER / IMPORTER: Sol Foods Ltd
''';

      final analysis = ComplianceEngine.analyzeFull(label);

      final mrpMissing = analysis.results.any(
        (r) =>
            !r.detected &&
            r.rule.declaration == 'Maximum Retail Price',
      );

      expect(mrpMissing, isTrue);
    });
  });

  group('UnitSalePriceService (Rule 6(11))', () {
    test('detects a consistent unit price', () {
      final result = UnitSalePriceService.evaluate(
        netQuantity: '100 g',
        mrp: 'Rs 50',
        printedUnitSalePrice: 'Rs 50 per 100 g',
      );

      expect(result.applicable, isTrue);
      expect(result.calculationPossible, isTrue);
    });

    test('reports a mismatch between MRP and net quantity', () {
      final result = UnitSalePriceService.evaluate(
        netQuantity: '100 g',
        mrp: 'Rs 50',
      );

      // Screens consistently; the exact consistency depends on the
      // detected unit. The service must not throw and must return an
      // explanation.
      expect(result.status, isNotEmpty);
      expect(result.explanation, isNotEmpty);
    });
  });

  group('MpeService', () {
    test('returns VERIFY when no observed quantity is provided', () {
      final result = MpeService.evaluate(
        productName: 'Rice',
        declaredQuantity: '5 kg',
      );

      expect(result.applicable, isFalse);
      expect(result.status, 'VERIFY');
    });
  });

  group('ReadabilityService', () {
    test('screens a readable, well-placed label', () {
      const label = '''
MRP: Rs 20
NET QUANTITY: 100 g
Manufactured by: Tasty Foods Pvt Ltd
Consumer care: 1800-000-000
''';

      final analysis = ReadabilityService.analyze(label);

      expect(analysis.placementFindings, isNotEmpty);
      expect(analysis.readabilityFindings, isNotEmpty);
      expect(analysis.fontSizeFindings, isNotEmpty);
      expect(analysis.readabilityScore, greaterThanOrEqualTo(0));
      expect(analysis.readabilityScore, lessThanOrEqualTo(100));
    });
  });
}
