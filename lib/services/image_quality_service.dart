import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A single quality metric's verdict: good / moderate / low.
///
/// Thresholds are deliberately lenient so that a moderately imperfect package
/// photo is never blocked from scanning — only a *clearly* bad image triggers
/// the retake prompt.
enum ImageQualityVerdict { good, moderate, low }

extension ImageQualityVerdictX on ImageQualityVerdict {
  bool get isLow => this == ImageQualityVerdict.low;
  bool get isGood => this == ImageQualityVerdict.good;

  /// Emoji used in the quality card.
  String get emoji {
    switch (this) {
      case ImageQualityVerdict.good:
        return '🟢';
      case ImageQualityVerdict.moderate:
        return '🟡';
      case ImageQualityVerdict.low:
        return '🔴';
    }
  }

  String get label {
    switch (this) {
      case ImageQualityVerdict.good:
        return 'Good';
      case ImageQualityVerdict.moderate:
        return 'Moderate';
      case ImageQualityVerdict.low:
        return 'Low';
    }
  }
}

/// A named quality check plus its verdict.
class ImageQualityMetric {
  final String name;
  final ImageQualityVerdict verdict;
  final String detail;

  const ImageQualityMetric({
    required this.name,
    required this.verdict,
    this.detail = '',
  });
}

/// Result of analysing a captured package photo for readability.
class ImageQualityResult {
  /// Original decoded dimensions (px).
  final int width;
  final int height;

  final List<ImageQualityMetric> metrics;

  /// True when the image is clearly unsuitable for reliable OCR — this is the
  /// only tier that triggers the "retake" prompt. Driven only by *obvious*
  /// problems: too-low resolution, severe blur, extreme darkness/over-exposure
  /// or heavy glare. Normal mobile-camera photos never land here.
  final bool isLowQuality;

  /// True when the image is usable but imperfect (a little blurry, slightly dark
  /// or mildly reflective). Shown as a soft warning, but the officer can continue.
  final bool isModerate;

  /// True when a metric could not be reliably computed (e.g. decode failed).
  final bool notMeasurable;

  const ImageQualityResult({
    required this.width,
    required this.height,
    required this.metrics,
    required this.isLowQuality,
    this.isModerate = false,
    this.notMeasurable = false,
  });

  /// A normal, perfectly acceptable image — quality gates let it continue.
  bool get isGood => !notMeasurable && !isLowQuality && !isModerate;

  String get overallLabel {
    if (notMeasurable) return 'NO QUALITY DATA';
    if (isLowQuality) return 'LOW';
    if (isModerate) return 'FAIR';
    return 'GOOD';
  }

  ImageQualityMetric? metric(String name) {
    for (final m in metrics) {
      if (m.name == name) return m;
    }
    return null;
  }
}

class ImageQualityService {
  ImageQualityService._();

  // ---- Thresholds (sample-space; generous to avoid false blocks) ----

  /// Mean luminance below this (0..1) is considered extremely dark — severe.
  static const double _brightnessLowThreshold = 0.22;

  /// Mean luminance above this (0..1) is considered blown-out / over-exposed.
  static const double _brightnessHighThreshold = 0.94;

  /// A slightly-dark band (0.22–0.28) is "fair", not severe — still scannable.
  static const double _brightnessModerateLow = 0.28;

  /// A slightly-bright band (0.90–0.94) is "fair", not severe.
  static const double _brightnessModerateHigh = 0.90;

  /// Laplacian variance below this is considered blurry.
  static const double _sharpnessLowThreshold = 12.0;

  /// Minimum acceptable image dimensions (width × height). An image passes
  /// only when BOTH dimensions meet these thresholds.
  static const int _resolutionMinWidth = 640;
  static const int _resolutionMinHeight = 480;

  /// Fraction of pixels above the over-exposure ceiling considered glare.
  static const double _glareLowThreshold = 0.18;

  /// Luminance (0..1) above which a pixel counts as "over-exposed" (glare).
  static const double _glarePixelCeiling = 0.955;

  // Ensures pixel-level samples are bounded (max rows * cols) regardless of
  // how large the uploaded photo is, so analysis always runs quickly.
  static const int _maxSampleRows = 240;
  static const int _maxSampleCols = 240;

  static Future<ImageQualityResult> analyze(File file) async {
    List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return _unmeasurable();
    }

    return analyzeBytes(bytes);
  }

  static Future<ImageQualityResult> analyzeBytes(List<int> data) async {
    try {
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(data),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width;
      final height = image.height;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      // Release the decoded image promptly.
      image.dispose();

      if (byteData == null) {
        return _unmeasurable();
      }

      final pixels = byteData.buffer.asUint8List();
      final sampled = _sampleLuminance(pixels, width, height);

      final brightness = _scoreBrightness(sampled.avgLuminance);
      final sharpness = _scoreSharpness(sampled.varLuminance);
      final resolution = _scoreResolution(width, height);
      final glare = _scoreGlare(sampled.glareFraction);

      final metrics = <ImageQualityMetric>[
        ImageQualityMetric(
          name: 'Sharpness',
          verdict: sharpness,
          detail: _blurDetail(sampled.varLuminance),
        ),
        ImageQualityMetric(
          name: 'Brightness',
          verdict: brightness,
          detail: _brightnessDetail(sampled.avgLuminance),
        ),
        ImageQualityMetric(
          name: 'Resolution',
          verdict: resolution,
          detail: '$width × $height px',
        ),
        ImageQualityMetric(
          name: 'Glare',
          verdict: glare,
          detail: _glareDetail(sampled.glareFraction),
        ),
      ];

      // Toleration-first tiering. Only *obvious* problems trigger the retake
      // prompt: too-small resolution, severe blur, extreme darkness/over-exposure
      // or heavy glare. A plain mobile-camera photo never fails these.
      // Slightly-blurry / slightly-dark images fall into the "fair" (moderate)
      // band — shown as a soft warning that the officer can continue past.
      final isLow = resolution.isLow ||
          sharpness.isLow ||
          brightness.isLow ||
          glare.isLow;

      final isModerate = !isLow &&
          (resolution == ImageQualityVerdict.moderate ||
              sharpness == ImageQualityVerdict.moderate ||
              brightness == ImageQualityVerdict.moderate ||
              glare == ImageQualityVerdict.moderate);

      return ImageQualityResult(
        width: width,
        height: height,
        metrics: metrics,
        isLowQuality: isLow,
        isModerate: isModerate,
      );
    } catch (_) {
      return _unmeasurable();
    }
  }

  static ImageQualityResult _unmeasurable() {
    return const ImageQualityResult(
      width: 0,
      height: 0,
      metrics: [],
      isLowQuality: false,
      notMeasurable: true,
    );
  }

  // ---------------------------------------------------------------
  // Sampling
  // ---------------------------------------------------------------

  static _SampleStats _sampleLuminance(
    Uint8List rgba,
    int width,
    int height,
  ) {
    final maxRows = _maxSampleRows < height ? _maxSampleRows : height;
    final maxCols = _maxSampleCols < width ? _maxSampleCols : width;

    final rowStep = (height / maxRows).ceil().clamp(1, 1 << 30);
    final colStep = (width / maxCols).ceil().clamp(1, 1 << 30);

    final luminances = <double>[];
    var glareCount = 0;
    var sampleCount = 0;

    for (var y = 0; y < height; y += rowStep) {
      for (var x = 0; x < width; x += colStep) {
        final i = (y * width + x) * 4;
        if (i + 3 >= rgba.length) continue;

        final r = rgba[i] / 255.0;
        final g = rgba[i + 1] / 255.0;
        final b = rgba[i + 2] / 255.0;

        // Rec. 601 luma.
        final luma = 0.299 * r + 0.587 * g + 0.114 * b;
        luminances.add(luma);

        if (luma > _glarePixelCeiling) glareCount++;
        sampleCount++;
      }
    }

    if (luminances.isEmpty) {
      return const _SampleStats(
        avgLuminance: 0.5,
        varLuminance: 0,
        glareFraction: 0,
      );
    }

    final mean = luminances.reduce((a, b) => a + b) / luminances.length;

    // Variance — a rough proxy for local contrast / detail. A near-flat (blurry
    // or blank) label has very low variance.
    var variance = 0.0;
    for (final l in luminances) {
      final d = l - mean;
      variance += d * d;
    }
    variance /= luminances.length;

    return _SampleStats(
      avgLuminance: mean,
      varLuminance: variance,
      glareFraction: sampleCount == 0 ? 0 : glareCount / sampleCount,
    );
  }

  // ---------------------------------------------------------------
  // Scoring
  // ---------------------------------------------------------------

  static ImageQualityVerdict _scoreBrightness(double avg) {
    if (avg < _brightnessLowThreshold || avg > _brightnessHighThreshold) {
      return ImageQualityVerdict.low;
    }
    // Slightly dark or bright still scans fine — warn, but never block.
    if (avg < _brightnessModerateLow || avg > _brightnessModerateHigh) {
      return ImageQualityVerdict.moderate;
    }
    return ImageQualityVerdict.good;
  }

  static ImageQualityVerdict _scoreSharpness(double variance) {
    if (variance < _sharpnessLowThreshold) {
      return ImageQualityVerdict.low;
    }
    // Generous: only clearly flat/out-of-focus frames fail.
    if (variance < _sharpnessLowThreshold * 2.5) {
      return ImageQualityVerdict.moderate;
    }
    return ImageQualityVerdict.good;
  }

  static ImageQualityVerdict _scoreResolution(int width, int height) {
    if (width <= 0 || height <= 0) return ImageQualityVerdict.low;
    // Accept when the image is at least 640 px wide AND 480 px tall.
    if (width < _resolutionMinWidth || height < _resolutionMinHeight) {
      return ImageQualityVerdict.low;
    }
    return ImageQualityVerdict.good;
  }

  static ImageQualityVerdict _scoreGlare(double fraction) {
    if (fraction > _glareLowThreshold) return ImageQualityVerdict.low;
    if (fraction > _glareLowThreshold * 0.5) {
      return ImageQualityVerdict.moderate;
    }
    return ImageQualityVerdict.good;
  }

  // ---------------------------------------------------------------
  // Detail strings
  // ---------------------------------------------------------------

  static String _blurDetail(double variance) {
    if (variance < _sharpnessLowThreshold) {
      return 'Low detail — text may be blurred';
    }
    if (variance < _sharpnessLowThreshold * 2.5) {
      return 'Some softness present';
    }
    return 'Text appears sharp';
  }

  static String _brightnessDetail(double avg) {
    if (avg < _brightnessLowThreshold) {
      return 'Too dark';
    }
    if (avg > _brightnessHighThreshold) {
      return 'Over-exposed';
    }
    return 'Evenly lit';
  }

  static String _glareDetail(double fraction) {
    if (fraction > _glareLowThreshold) {
      return 'High glare / reflection';
    }
    if (fraction > _glareLowThreshold * 0.5) {
      return 'Some reflection';
    }
    return 'No significant glare';
  }
}

class _SampleStats {
  final double avgLuminance;
  final double varLuminance;
  final double glareFraction;

  const _SampleStats({
    required this.avgLuminance,
    required this.varLuminance,
    required this.glareFraction,
  });
}
