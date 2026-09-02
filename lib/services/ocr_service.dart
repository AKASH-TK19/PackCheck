import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A single recognised text line together with its approximate bounding
/// box. The backend populates these when it can, otherwise the list is empty
/// and the readability module degrades to text-only heuristics.
class OcrLine {
  final String text;
  final double? x;
  final double? y;
  final double? width;
  final double? height;

  const OcrLine({
    required this.text,
    this.x,
    this.y,
    this.width,
    this.height,
  });
}

/// Result of the OCR pass: the PackCheck-normalised labelled text, the raw
/// model output and any per-line geometry that was returned.
class OcrResult {
  final String text;
  final String rawText;
  final List<OcrLine> lines;

  const OcrResult({
    required this.text,
    required this.rawText,
    required this.lines,
  });
}

/// Raised when the OCR backend is unavailable or returns an error. The UI
/// can catch this type to offer a manual text-entry fallback.
class OcrServiceException implements Exception {
  final String message;

  const OcrServiceException(this.message);

  @override
  String toString() => message;
}

class OcrService {
  // Override at build/run time with:
  //   flutter run --dart-define=PACKCHECK_OCR_URL=http://<host>:8000/analyze
  static const String backendUrl = String.fromEnvironment(
    'PACKCHECK_OCR_URL',
    defaultValue: 'http://10.213.187.219:8000/analyze',
  );

  static Future<OcrResult> analyzeImages(
    List<File> images,
  ) async {
    if (images.isEmpty) {
      throw const OcrServiceException(
        'No inspection photos selected.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(backendUrl),
    );

    for (final image in images) {
      if (await image.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            image.path,
          ),
        );
      }
    }

    if (request.files.isEmpty) {
      throw const OcrServiceException(
        'No valid inspection photos found.',
      );
    }

    http.Response response;
    try {
      final streamedResponse = await request.send();
      response = await http.Response.fromStream(
        streamedResponse,
      );
    } catch (e) {
      throw OcrServiceException(
        'OCR backend is unreachable. '
        'Please check the network connection and try again, or '
        'enter the label text manually.\n\n($e)',
      );
    }

    if (response.statusCode != 200) {
      throw OcrServiceException(
        'OCR backend error ${response.statusCode}: '
        '${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const OcrServiceException(
        'Invalid OCR backend response.',
      );
    }

    final raw = decoded['result'];

    if (raw is! String || raw.trim().isEmpty) {
      throw const OcrServiceException(
        'OCR backend returned no readable result.',
      );
    }

    final lines = _parseLines(decoded);

    return OcrResult(
      text: _convertToPackCheckText(raw),
      rawText: raw,
      lines: lines,
    );
  }

  static List<OcrLine> _parseLines(
    Map<String, dynamic> decoded,
  ) {
    final result = <OcrLine>[];

    final rawBoxes = decoded['boxes'];

    if (rawBoxes is! List) {
      return result;
    }

    for (final entry in rawBoxes) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final text = (entry['text'] ?? '').toString().trim();

      if (text.isEmpty) {
        continue;
      }

      result.add(
        OcrLine(
          text: text,
          x: _asDouble(entry['x']),
          y: _asDouble(entry['y']),
          width: _asDouble(entry['width']),
          height: _asDouble(entry['height']),
        ),
      );
    }

    return result;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value');
  }

  static String _convertToPackCheckText(String raw) {
    var text = raw.trim();

    // Remove Markdown JSON fences.
    if (text.startsWith('```json')) {
      text = text.substring(7);
    } else if (text.startsWith('```')) {
      text = text.substring(3);
    }

    if (text.endsWith('```')) {
      text = text.substring(
        0,
        text.length - 3,
      );
    }

    text = text.trim();

    try {
      final decoded = jsonDecode(text);

      if (decoded is Map<String, dynamic>) {
        final buffer = StringBuffer();

        void add(String label, dynamic value) {
          final valueText = value?.toString().trim() ?? '';

          if (valueText.isNotEmpty) {
            buffer.writeln('$label: $valueText');
          }
        }

        add('PRODUCT NAME', decoded['productName']);
        add('MRP', decoded['mrp']);
        add('UNIT SALE PRICE', decoded['unitSalePrice']);
        add('NET QUANTITY', decoded['netQuantity']);
        add('MANUFACTURER / PACKER / IMPORTER',
            decoded['manufacturer']);
        add('COUNTRY OF ORIGIN',
            decoded['countryOfOrigin']);
        add('MANUFACTURE / PACKING DATE',
            decoded['manufactureDate']);
        add('BEST BEFORE / USE BY / EXPIRY',
            decoded['expiryDate']);
        add('CONSUMER CARE',
            decoded['consumerCare']);

        final rawRelevant =
            decoded['rawRelevantText']?.toString().trim();

        if (rawRelevant != null &&
            rawRelevant.isNotEmpty) {
          buffer.writeln();
          buffer.writeln('RAW VISUAL EVIDENCE:');
          buffer.writeln(rawRelevant);
        }

        return buffer.toString().trim();
      }
    } catch (_) {
      // If NVIDIA returned ordinary text instead of JSON,
      // keep that text so PackCheck can still inspect it.
    }

    return text;
  }
}