import 'ocr_service.dart';

/// A single assessment produced by the readability / placement / font-size
/// analysis. Always advisory: final determination requires officer
/// verification, matching the rest of the application.
class ReadabilityFinding {
  final String title;
  final String status; // PASS | VERIFY | POTENTIAL VIOLATION
  final String explanation;
  final bool concern;

  const ReadabilityFinding({
    required this.title,
    required this.status,
    required this.explanation,
    required this.concern,
  });
}

class ReadabilityAnalysis {
  final List<ReadabilityFinding> placementFindings;
  final List<ReadabilityFinding> readabilityFindings;
  final List<ReadabilityFinding> fontSizeFindings;
  final int readabilityScore;

  const ReadabilityAnalysis({
    required this.placementFindings,
    required this.readabilityFindings,
    required this.fontSizeFindings,
    required this.readabilityScore,
  });

  int get totalFindings =>
      placementFindings.length +
      readabilityFindings.length +
      fontSizeFindings.length;

  int get concernCount =>
      placementFindings.where((f) => f.concern).length +
      readabilityFindings.where((f) => f.concern).length +
      fontSizeFindings.where((f) => f.concern).length;
}

/// Heuristic screening aid for the "Font size and readability" and
/// "Placement of declarations" requirements of the SIH problem statement.
///
/// The service works from the OCR text (and, when available, per-line
/// bounding boxes returned by the backend). Where geometry is absent it
/// degrades to text-only heuristics. It is deliberately conservative and
/// labels uncertain results as VERIFY rather than asserting a violation.
class ReadabilityService {
  /// Mandatory declarations that Rules require to be prominent/legible.
  static const List<Map<String, String>> _mandatory = [
    {
      'title': 'Maximum Retail Price (MRP)',
      'pattern': r'\b(m\.?\s*r\.?\s*p\.?|maximum\s+retail\s+price)\b',
    },
    {
      'title': 'Net Quantity',
      'pattern': r'(net\s*(?:quantity|qty|wt|weight|volume|content))',
    },
    {
      'title': 'Manufacturer / Packer / Importer',
      'pattern':
          r'(manufactured\s*by|manufacturer|mfg\.?\s*by|packed\s*by|packer|imported\s*by|marketed\s*by)',
    },
    {
      'title': 'Month / Year of Manufacture',
      'pattern':
          r'(mfg\.?\s*date|mfd|manufactured|manufacture\s*date|packed|packing\s*date|mfg|pkd)',
    },
    {
      'title': 'Consumer Care Details',
      'pattern': r'(consumer\s*care|customer\s*care|cust\.?\s*care|toll\s*free)',
    },
    {
      'title': 'Country of Origin',
      'pattern':
          r'(country\s*of\s*origin|country\s*of\s*manufacture|made\s*in|product\s*of)',
    },
    {
      'title': 'Unit Sale Price',
      'pattern': r'(unit\s*(?:sale|selling)?\s*price|unit\s*price)',
    },
  ];

  /// Lines that are (almost) certainly not part of a product declaration.
  static final List<RegExp> _noiseLines = [
    RegExp(r'^photo\s*\d+$', caseSensitive: false),
    RegExp(r'^[-\s@#/*_=+]+$'),
    RegExp(r'^scanned\s*(?:on|at|date|time).*', caseSensitive: false),
  ];

  static ReadabilityAnalysis analyze(
    String text, {
    List<OcrLine> lines = const [],
  }) {
    final placement = _checkPlacement(text);
    final readability = _checkReadability(text, lines);
    final fontSize = _checkFontSize(text, lines);

    return ReadabilityAnalysis(
      placementFindings: placement,
      readabilityFindings: readability,
      fontSizeFindings: fontSize,
      readabilityScore: _readabilityScore(text),
    );
  }

  // ---------------------------------------------------------------
  // Placement
  // ---------------------------------------------------------------
  static List<ReadabilityFinding> _checkPlacement(String text) {
    final findings = <ReadabilityFinding>[];
    final normalized = text.replaceAll('\r', '\n').toLowerCase();

    for (final rule in _mandatory) {
      final present = RegExp(
        rule['pattern']!,
        caseSensitive: false,
      ).hasMatch(normalized);

      findings.add(
        ReadabilityFinding(
          title: '${rule['title']} placement',
          status: present ? 'PASS' : 'VERIFY',
          explanation: present
              ? 'Declaration text is present in the captured evidence.'
              : 'Declaration text was not identified in the captured evidence. '
                  'Confirm whether it is missing, illegible or not captured.',
          concern: !present,
        ),
      );
    }

    return findings;
  }

  // ---------------------------------------------------------------
  // Readability
  // ---------------------------------------------------------------
  static List<ReadabilityFinding> _checkReadability(
    String text,
    List<OcrLine> lines,
  ) {
    final findings = <ReadabilityFinding>[];

    final cleanedLines = _meaningfulLines(text);

    if (cleanedLines.isEmpty) {
      findings.add(
        const ReadabilityFinding(
          title: 'Readable text present',
          status: 'VERIFY',
          explanation:
              'No meaningful text was detected. Verify that the package label '
              'is legible and was captured clearly.',
          concern: true,
        ),
      );
      return findings;
    }

    // Detect "gibberish" lines: a high density of non-alphabetic characters
    // or many very short fragments suggests poor OCR or a low-contrast label.
    var lowQualityLines = 0;

    for (final line in cleanedLines) {
      final letters =
          RegExp(r'[A-Za-z]').allMatches(line).length;
      final length = line.length;

      if (length >= 6 &&
          letters >= 2 &&
          (letters / length) < 0.45) {
        lowQualityLines++;
      }
    }

    final ratio =
        cleanedLines.isEmpty ? 0.0 : lowQualityLines / cleanedLines.length;

    findings.add(
      ReadabilityFinding(
        title: 'Legibility screening',
        status: ratio > 0.4 ? 'VERIFY' : 'PASS',
        explanation: ratio > 0.4
            ? 'A large share of the captured text appears to be partial or '
                'noisy, which can indicate a low-contrast or small-font label. '
                'Verify against the physical package.'
            : 'The captured text is generally well structured and readable.',
        concern: ratio > 0.4,
      ),
    );

    return findings;
  }

  // ---------------------------------------------------------------
  // Font size
  // ---------------------------------------------------------------
  static List<ReadabilityFinding> _checkFontSize(
    String text,
    List<OcrLine> lines,
  ) {
    // Preferred path: use the line geometry when the backend supplied it.
    if (lines.isNotEmpty) {
      final heights = lines
          .where((l) => l.height != null && l.height! > 0)
          .map((l) => l.height!)
          .toList();

      if (heights.isEmpty) {
        return _fontSizeByTextHeuristic(text);
      }

      heights.sort();
      final median = heights[heights.length ~/ 2];

      final smallText = <String>[];

      for (final rule in _mandatory) {
        final label = rule['title']!;
        final found = lines.where(
          (l) => RegExp(
            rule['pattern']!,
            caseSensitive: false,
          ).hasMatch(l.text),
        );

        final matched =
            found.where((l) => l.height != null && l.height! > 0);

        if (matched.isEmpty) continue;

        if (matched.every((l) => l.height! < median * 0.7)) {
          smallText.add(label);
        }
      }

      final findings = <ReadabilityFinding>[
        ReadabilityFinding(
          title: 'Font-size screening',
          status: smallText.isEmpty ? 'PASS' : 'VERIFY',
          explanation: smallText.isEmpty
              ? 'Detected declaration text is comparable in size to the '
                  'typical caption height on this label.'
              : 'The following mandatory declarations appear notably smaller '
                  'than the dominant caption height and may not meet the '
                  'prescribed prominence: ${smallText.join(', ')}. Verify '
                  'against the physical package.',
          concern: smallText.isNotEmpty,
        ),
      ];

      return findings;
    }

    return _fontSizeByTextHeuristic(text);
  }

  static List<ReadabilityFinding> _fontSizeByTextHeuristic(
    String text,
  ) {
    final findings = <ReadabilityFinding>[];
    final concerns = <String>[];

    final lines = text
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final rule in _mandatory) {
      final regex = RegExp(
        rule['pattern']!,
        caseSensitive: false,
      );

      for (final line in lines) {
        if (regex.hasMatch(line)) {
          // A declaration that shares a line with a very short fragment is
          // often abbreviated or clipped. Flag as a verify-worthy concern.
          final remainder = regex.firstMatch(line)!.group(0)!.length;
          final readArea = line.length - remainder;

          if (readArea <= 4) {
            concerns.add(rule['title']!);
          }
          break;
        }
      }
    }

    findings.add(
      ReadabilityFinding(
        title: 'Font-size screening',
        status: concerns.isEmpty ? 'PASS' : 'VERIFY',
        explanation: concerns.isEmpty
            ? 'Mandatory declarations appear on adequately sized text lines '
                'and are likely legible. Confirm against the physical package.'
            : 'The following declarations appear on very short/abbreviated '
                'line fragments and may be printed too small or clipped: '
                '${concerns.join(', ')}. Verify against the physical package.',
        concern: concerns.isNotEmpty,
      ),
    );

    return findings;
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------
  static List<String> _meaningfulLines(String text) {
    return text
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) {
          final line = e;

          if (line.isEmpty) return false;

          if (_noiseLines.any((n) => n.hasMatch(line))) {
            return false;
          }

          // Require at least two letters or a digit+word combination.
          final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
          final digits = RegExp(r'\d').allMatches(line).length;

          return letters >= 2 || (digits >= 1 && letters >= 1);
        })
        .toList();
  }

  static int _readabilityScore(String text) {
    final lines = _meaningfulLines(text);

    if (lines.isEmpty) return 0;

    final totalLetters =
        lines.fold<int>(0, (sum, l) => sum + l.length);
    final totalWords = lines.fold<int>(
      0,
      (sum, l) =>
          sum + RegExp(r'[A-Za-z0-9]+').allMatches(l).length,
    );

    // Length-based legibility proxy: longer structured lines score higher,
    // with a cap at 100. Noise-heavy inputs score close to 0.
    var score = (totalLetters / (lines.length * 30.0) * 80).clamp(0, 80);

    if (totalWords > 0) {
      score += 20;
    }

    return score.round().clamp(0, 100);
  }
}
