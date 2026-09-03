import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:packcheck/models/compliance_rule.dart';
import 'package:packcheck/services/compliance_engine.dart';
import 'package:packcheck/services/ocr_service.dart';

void main() {
  setUp(OcrService.resetAnalysisCache);

  // A representative, fully-declared food label. The exact declarations do not
  // matter for the determinism guarantees below — only that running the engine
  // twice on the SAME text produces the SAME result.
  const compliantLabel = '''
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

  group('Deterministic compliance engine', () {
    test('identical OCR text produces identical score, verdict and violations',
        () {
      final a = ComplianceEngine.analyzeFull(compliantLabel);
      final b = ComplianceEngine.analyzeFull(compliantLabel);

      expect(ComplianceEngine.score(a.results), ComplianceEngine.score(b.results));
      expect(
        ComplianceEngine.verdict(ComplianceEngine.score(a.results)),
        ComplianceEngine.verdict(ComplianceEngine.score(b.results)),
      );
      expect(_violationIds(a.results), _violationIds(b.results));
      expect(_detectedIds(a.results), _detectedIds(b.results));
      expect(_productSignature(a), _productSignature(b));
    });

    test('a genuinely different label is scored differently (not hardcoded)',
        () {
      const sparseLabel = '''
PRODUCT NAME: Loose Salt
NET QUANTITY: 200 g
MANUFACTURER / PACKER / IMPORTER: Sol Foods Ltd
''';

      final compliant = ComplianceEngine.analyzeFull(compliantLabel);
      final sparse = ComplianceEngine.analyzeFull(sparseLabel);

      expect(
        ComplianceEngine.score(sparse.results),
        isNot(ComplianceEngine.score(compliant.results)),
      );
    });
  });

  group('Deterministic OCR caching for identical photos', () {
    test('identical photo content reuses the cached OCR result (one backend call)',
        () async {
      final dir = Directory.systemTemp.createTempSync('packcheck_det_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      // Two different file paths with identical bytes.
      final photo1 = File('${dir.path}/front.png');
      final photo2 = File('${dir.path}/front_copy.png');
      const bytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
      ];
      photo1.writeAsBytesSync(bytes);
      photo2.writeAsBytesSync(bytes);

      var backendCalls = 0;
      final backendResult = OcrResult(
        text: compliantLabel,
        rawText: compliantLabel,
        lines: const [],
      );

      Future<OcrResult> fetch(List<File> images) async {
        backendCalls++;
        return backendResult;
      }

      // First call: different file path, identical bytes. Should hit the backend.
      final first = await OcrService.analyzeImagesCached([photo1], fetch: fetch);
      // Second call: a different file path with the SAME bytes. Content-hash must
      // match, so the cached result is reused without another backend call.
      final second = await OcrService.analyzeImagesCached([photo2], fetch: fetch);

      expect(backendCalls, 1,
          reason: 'identical photos must not hit the variable backend twice');
      expect(first.text, second.text);
      expect(first.text, compliantLabel);

      // The reused OCR text feeds a deterministic compliance result.
      final a = ComplianceEngine.analyzeFull(first.text);
      final b = ComplianceEngine.analyzeFull(second.text);
      expect(ComplianceEngine.score(a.results), ComplianceEngine.score(b.results));
      expect(_violationIds(a.results), _violationIds(b.results));
    });
  });
}

List<String> _violationIds(List<ComplianceResult> results) =>
    results.where((r) => r.isViolation).map((r) => r.rule.id).toList()..sort();

List<String> _detectedIds(List<ComplianceResult> results) =>
    results.where((r) => r.isDetected).map((r) => r.rule.id).toList()..sort();

String _productSignature(ComplianceAnalysis a) =>
    [a.product.productName, a.product.mrp, a.product.unitSalePrice, a.product.netQuantity]
        .map((s) => s.trim().toLowerCase())
        .join('|');
