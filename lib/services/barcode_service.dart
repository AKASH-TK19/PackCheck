import 'dart:io';

import 'package:mobile_scanner/mobile_scanner.dart';

/// Outcome of automatically scanning one or more captured package photos for
/// QR codes and common 1-D product barcodes.
///
/// This runs entirely on-device (ML Kit / VisionKit / ZXing) and is completely
/// independent of the NVIDIA OCR backend, so barcode detection still works when
/// the NVIDIA API is unavailable.
class BarcodeScanOutcome {
  /// The unique decoded values, in detection order.
  final List<String> values;

  /// A human-readable format label per value (e.g. EAN-13, QR CODE, OTHER).
  final Map<String, String> types;

  /// The officer-selected value, if any (null when none detected).
  final String? selected;

  /// A short summary line for the UI.
  final String message;

  const BarcodeScanOutcome({
    required this.values,
    required this.types,
    required this.selected,
    required this.message,
  });

  bool get detected => values.isNotEmpty;

  /// A "nothing found" outcome so callers never have to catch an exception.
  static const BarcodeScanOutcome empty = BarcodeScanOutcome(
    values: <String>[],
    types: <String, String>{},
    selected: null,
    message: 'No barcode/QR detected',
  );
}

/// Result of validating a single scanned product identifier (from the manual
/// live-camera scanner).
class BarcodeResult {
  final bool detected;
  final String? value;
  final String type;
  final String message;

  const BarcodeResult({
    required this.detected,
    required this.value,
    required this.type,
    required this.message,
  });
}

class BarcodeService {
  /// Validates a scanned product identifier.
  ///
  /// The identifier can later be connected to an official
  /// departmental/product master database.
  static BarcodeResult process(String rawValue) {
    final value = rawValue.trim();

    if (value.isEmpty) {
      return const BarcodeResult(
        detected: false,
        value: null,
        type: 'UNKNOWN',
        message: 'No barcode or QR value detected.',
      );
    }

    final digitsOnly = RegExp(r'^\d+$').hasMatch(value);

    if (digitsOnly && value.length == 13) {
      return BarcodeResult(
        detected: true,
        value: value,
        type: 'EAN-13',
        message: 'EAN-13 product identifier detected.',
      );
    }

    if (digitsOnly && value.length == 12) {
      return BarcodeResult(
        detected: true,
        value: value,
        type: 'UPC-A',
        message: 'UPC-A product identifier detected.',
      );
    }

    if (digitsOnly && value.length == 8) {
      return BarcodeResult(
        detected: true,
        value: value,
        type: 'EAN-8',
        message: 'EAN-8 product identifier detected.',
      );
    }

    return BarcodeResult(
      detected: true,
      value: value,
      type: 'QR / OTHER',
      message:
          'Code detected. Product-master verification can be performed '
          'when the identifier is connected to an authorised reference database.',
    );
  }

  /// Scan the supplied package photos on-device for QR codes and common 1-D
  /// product barcodes (EAN-13 / EAN-8 / UPC-A / Code 128 / Code 39 / QR). This
  /// is independent of the NVIDIA OCR backend and never throws: any failure is
  /// converted into an empty [BarcodeScanOutcome] so the assessment continues.
  ///
  /// The platform barcode engine already tolerates codes photographed at an
  /// angle or not perfectly centred.
  static Future<BarcodeScanOutcome> detectFromImages(
    List<File> images,
  ) async {
    if (images.isEmpty) {
      return BarcodeScanOutcome.empty;
    }

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.itf14,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.codabar,
      ],
    );

    final values = <String>[];
    final types = <String, String>{};

    try {
      // analyzeImage does not require the camera controller to be started.
      for (final image in images) {
        try {
          final capture = await controller.analyzeImage(
            image.path,
          );

          if (capture == null) continue;

          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue?.trim();

            if (value == null || value.isEmpty) continue;
            if (values.contains(value)) continue;

            values.add(value);
            types[value] = _formatForBarcode(barcode);
          }
        } catch (_) {
          // Ignore unreadable images / unsupported platform; keep scanning.
        }
      }

      if (values.isEmpty) {
        return BarcodeScanOutcome.empty;
      }

      return BarcodeScanOutcome(
        values: values,
        types: types,
        selected: values.length == 1 ? values.first : null,
        message: values.length == 1
            ? '1 code detected'
            : '${values.length} codes detected',
      );
    } catch (_) {
      return BarcodeScanOutcome.empty;
    } finally {
      try {
        await controller.dispose();
      } catch (_) {
        // Dispose is best-effort.
      }
    }
  }

  static String _formatForBarcode(Barcode barcode) {
    switch (barcode.format) {
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.code128:
        return 'CODE-128';
      case BarcodeFormat.code39:
        return 'CODE-39';
      case BarcodeFormat.code93:
        return 'CODE-93';
      case BarcodeFormat.itf14:
        return 'ITF-14';
      case BarcodeFormat.codabar:
        return 'CODABAR';
      case BarcodeFormat.qrCode:
        return 'QR CODE';
      default:
        return 'OTHER';
    }
  }
}