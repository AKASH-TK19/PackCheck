import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product_category.dart';
import '../services/image_quality_service.dart';
import '../theme/app_theme.dart';

/// What the caller should do after the quality screen is dismissed.
enum QualityDecision {
  /// Proceed to OCR with the captured image.
  continueScan,

  /// Drop back to the capture screen so the officer can retake the photo.
  retakeImage,
}

/// The three quality tiers surfaced to the officer.
enum _QualityTier { good, fair, low }

/// Full-screen "Image Quality" step shown after capture/upload and before OCR.
///
/// Runs a real, on-device pixel analysis (brightness, blur, resolution, glare)
/// and displays a compact quality card. According to the tier:
///   - good  → auto-continues to OCR (never blocks a normal photo);
///   - fair  → shows a soft warning but lets the officer continue;
///   - low   → asks the officer to retake (with a "continue anyway" escape).
/// The existing OCR pipeline is never unnecessarily delayed.
class ImageQualityScreen extends StatefulWidget {
  const ImageQualityScreen({
    super.key,
    required this.imageFiles,
    required this.category,
    this.initialResult,
  });

  final List<File> imageFiles;
  final ProductCategoryInfo category;

  /// Pre-computed quality result supplied by the caller (e.g. [main.dart] runs
  /// the pixel analysis once and passes it through so it can also derive
  /// low-confidence OCR). When null, the screen analyses the image itself.
  final ImageQualityResult? initialResult;

  @override
  State<ImageQualityScreen> createState() => _ImageQualityScreenState();
}

class _ImageQualityScreenState extends State<ImageQualityScreen> {
  ImageQualityResult? _result;
  bool _analyzing = true;
  Timer? _autoContinueTimer;

  @override
  void initState() {
    super.initState();
    final precomputed = widget.initialResult;
    if (precomputed != null) {
      _result = precomputed;
      _analyzing = false;
      _maybeAutoContinue(precomputed);
    } else {
      _run();
    }
  }

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    final result = await ImageQualityService.analyze(widget.imageFiles.first);

    if (!mounted) return;

    setState(() {
      _result = result;
      _analyzing = false;
    });

    _maybeAutoContinue(result);
  }

  /// Good (and unmeasurable) images should not block the flow — ramp briefly to
  /// show the card, then auto-continue to OCR. Fair ("moderate"/slightly blurry
  /// or dark) and low images keep the card visible so the officer can choose
  /// between retaking and continuing anyway.
  void _maybeAutoContinue(ImageQualityResult result) {
    if (_tier(result) == _QualityTier.good) {
      _autoContinueTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        _finish(continueScan: true);
      });
    }
  }

  /// Maps a quality result to its three-tier outcome for the UI.
  _QualityTier _tier(ImageQualityResult result) {
    if (result.notMeasurable) return _QualityTier.good;
    if (result.isLowQuality) return _QualityTier.low;
    if (result.isModerate) return _QualityTier.fair;
    return _QualityTier.good;
  }

  void _finish({required bool continueScan}) {
    Navigator.of(context).pop(
      continueScan ? QualityDecision.continueScan : QualityDecision.retakeImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PackCheckColors.background,
      appBar: AppBar(
        title: const Text('Image Quality'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _analyzing ? _buildLoading() : _buildCard(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Checking image quality...',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final result = _result!;
    final tier = _tier(result);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header.
            const Text(
              'IMAGE QUALITY',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: PackCheckColors.dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.category.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: PackCheckColors.dark,
              ),
            ),
            const SizedBox(height: 20),

            // Metric card.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tier == _QualityTier.low
                      ? PackCheckColors.danger.withValues(alpha: .3)
                      : tier == _QualityTier.fair
                          ? PackCheckColors.warning.withValues(alpha: .35)
                          : PackCheckColors.success.withValues(alpha: .2),
                ),
              ),
              child: Column(
                children: [
                  ...result.metrics.map(_metricRow),
                  if (result.notMeasurable) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Could not fully analyse this image. It will still be '
                      'sent for OCR.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _overallRow(result),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Quality feedback: severe → retake prompt, fair → soft warning,
            // good → auto-continue note.
            if (tier == _QualityTier.low)
              _buildLowWarning()
            else if (tier == _QualityTier.fair)
              _buildFairWarning()
            else
              _buildAutoNote(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(ImageQualityMetric metric) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              metric.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PackCheckColors.dark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            metric.detail,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 10),
          Text(
            metric.verdict.emoji,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _overallRow(ImageQualityResult result) {
    final tier = _tier(result);
    final good = tier == _QualityTier.good;
    final Color color;
    final String label;
    if (result.notMeasurable) {
      color = PackCheckColors.success;
      label = 'Overall: PROCEEDING';
    } else if (tier == _QualityTier.low) {
      color = PackCheckColors.danger;
      label = 'Overall: LOW';
    } else if (tier == _QualityTier.fair) {
      color = PackCheckColors.warning;
      label = 'Overall: FAIR — usable but imperfect';
    } else {
      color = PackCheckColors.success;
      label = 'Overall: GOOD — Suitable for scanning';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          good
              ? Icons.check_circle_outline
              : tier == _QualityTier.fair
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLowWarning() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PackCheckColors.dangerTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PackCheckColors.danger.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: PackCheckColors.danger),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'IMAGE QUALITY IS LOW',
                  style: TextStyle(
                    color: PackCheckColors.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Some package text may not be readable. For a more reliable '
            'compliance check, retake the image.',
            style: TextStyle(
              color: Colors.black87,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _finish(continueScan: false),
              icon: const Icon(Icons.photo_camera_back_outlined),
              label: const Text('RETACK IMAGE'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _finish(continueScan: true),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('CONTINUE ANYWAY'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFairWarning() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PackCheckColors.warningTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PackCheckColors.warning.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: PackCheckColors.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'IMAGE QUALITY IS FAIR',
                  style: TextStyle(
                    color: PackCheckColors.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'The image is usable but slightly blurry, dark or reflective. '
            'You can continue, or retake it for a more reliable result.',
            style: TextStyle(
              color: Colors.black87,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _finish(continueScan: true),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('CONTINUE ANYWAY'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _finish(continueScan: false),
              icon: const Icon(Icons.photo_camera_back_outlined),
              label: const Text('RETACK IMAGE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PackCheckColors.successTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PackCheckColors.success.withValues(alpha: .3),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'Quality is acceptable — continuing to OCR…',
              style: TextStyle(
                color: PackCheckColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
