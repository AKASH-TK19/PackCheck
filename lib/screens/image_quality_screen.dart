import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product_category.dart';
import '../services/image_quality_service.dart';
import '../theme/app_theme.dart';

/// What the caller should do after the quality screen is dismissed.
///
/// [continueScan] is set (and [retakeIndex] is null) when every required photo
/// passed and the caller should proceed to OCR. [retakeIndex] is set (and
/// [continueScan] is false) when the officer chose to retake the photo captured
/// for a specific package side.
class QualityDecision {
  final bool continueScan;
  final int? retakeIndex;

  const QualityDecision._(this.continueScan, this.retakeIndex);

  /// Every required photo passed → proceed to OCR.
  static const QualityDecision proceed = QualityDecision._(true, null);

  /// The officer chose to retake the photo for this package side (0-based).
  const QualityDecision.retake(int this.retakeIndex) : continueScan = false;
}

/// One captured package photo together with the label shown in the quality list
/// and the 0-based package-side index it belongs to. [sideIndex] is null for
/// optional extra-evidence photos, which never gate OCR.
class QualityPhoto {
  final File file;
  final String label;
  final int? sideIndex;

  const QualityPhoto({
    required this.file,
    required this.label,
    this.sideIndex,
  });
}

/// The three quality tiers surfaced to the officer.
enum _QualityTier { good, fair, low }

/// Full-screen "Image Quality" step shown after capture/upload and before OCR.
///
/// Runs a real, on-device pixel analysis (brightness, blur, resolution, glare)
/// on **every** captured photo and shows the status of each one. A photo is
/// "required" when it belongs to a package side; optional extra-evidence photos
/// are shown but never block OCR. The flow:
///   - every required photo good  → auto-continues to OCR;
///   - a required photo fair      → soft warning, officer may continue or retake;
///   - a required photo low       → blocks and asks the officer to retake only
///                                  that photo (with an explicit continue escape).
class ImageQualityScreen extends StatefulWidget {
  const ImageQualityScreen({
    super.key,
    required this.photos,
    required this.category,
    this.initialResults,
  });

  final List<QualityPhoto> photos;
  final ProductCategoryInfo category;

  /// Pre-computed quality results supplied by the caller (same length as
  /// [photos]). When null, the screen analyses the photos itself.
  final List<ImageQualityResult>? initialResults;

  @override
  State<ImageQualityScreen> createState() => _ImageQualityScreenState();
}

class _ImageQualityScreenState extends State<ImageQualityScreen> {
  List<ImageQualityResult> _results = const [];
  bool _analyzing = true;
  Timer? _autoContinueTimer;

  @override
  void initState() {
    super.initState();
    final precomputed = widget.initialResults;
    if (precomputed != null) {
      _results = precomputed;
      _analyzing = false;
      _maybeAutoContinue();
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
    final results = <ImageQualityResult>[];
    for (final photo in widget.photos) {
      results.add(await ImageQualityService.analyze(photo.file));
      if (!mounted) return;
    }

    if (!mounted) return;

    setState(() {
      _results = results;
      _analyzing = false;
    });

    _maybeAutoContinue();
  }

  /// Good screens (every required photo acceptable) should not block — ramp
  /// briefly to show the card, then auto-continue to OCR.
  void _maybeAutoContinue() {
    if (_overallTier() == _QualityTier.good) {
      _autoContinueTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        _finish(continueScan: true);
      });
    }
  }

  _QualityTier _tier(ImageQualityResult result) {
    if (result.notMeasurable) return _QualityTier.good;
    if (result.isLowQuality) return _QualityTier.low;
    if (result.isModerate) return _QualityTier.fair;
    return _QualityTier.good;
  }

  /// Whether a photo is "required": it belongs to a package side. Optional
  /// extra-evidence photos ([QualityPhoto.sideIndex] == null) never gate OCR.
  bool _isRequired(int index) => widget.photos[index].sideIndex != null;

  /// Aggregate tier: any required photo "low" → low; any required photo "fair"
  /// (or an optional photo low/fair) → fair; otherwise good.
  _QualityTier _overallTier() {
    var anyFair = false;
    for (var i = 0; i < widget.photos.length; i++) {
      final t = _tier(_results[i]);
      if (_isRequired(i)) {
        if (t == _QualityTier.low) return _QualityTier.low;
        if (t == _QualityTier.fair) anyFair = true;
      } else if (t == _QualityTier.low || t == _QualityTier.fair) {
        anyFair = true;
      }
    }
    return anyFair ? _QualityTier.fair : _QualityTier.good;
  }

  /// The package-side index of the first required photo that failed, if any.
  int? _firstFailedRequiredIndex() {
    for (var i = 0; i < widget.photos.length; i++) {
      if (_isRequired(i) && _tier(_results[i]) == _QualityTier.low) {
        return widget.photos[i].sideIndex;
      }
    }
    return null;
  }

  /// The package-side index of the first required photo, used to give the
  /// officer a "retake" target in the fair tier.
  int? _firstRequiredIndex() {
    for (var i = 0; i < widget.photos.length; i++) {
      if (_isRequired(i)) return widget.photos[i].sideIndex;
    }
    return null;
  }

  void _finish({bool continueScan = false, int? retakeIndex}) {
    Navigator.of(context).pop(
      continueScan
          ? QualityDecision.proceed
          : QualityDecision.retake(retakeIndex!),
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
    final count = widget.photos.length;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Checking $count image${count == 1 ? '' : 's'}...',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final tier = _overallTier();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

            // Per-photo status list.
            ...List.generate(widget.photos.length, _photoCard),

            const SizedBox(height: 18),

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

  Widget _photoCard(int index) {
    final photo = widget.photos[index];
    final result = _results[index];
    final t = _tier(result);
    final number = index + 1;
    final required = _isRequired(index);

    final (Color statusColor, String statusText) = switch (t) {
      _QualityTier.good => (PackCheckColors.success, '✅ Good'),
      _QualityTier.fair => (PackCheckColors.warning, '🟡 Fair'),
      _QualityTier.low => (PackCheckColors.danger, '❌ Low quality — Retake'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Photo $number – ${photo.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (!required)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OPTIONAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (result.width > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${result.width} × ${result.height}px',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          if (t == _QualityTier.low && required) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                onPressed: () => _finish(retakeIndex: photo.sideIndex),
                icon: const Icon(
                  Icons.photo_camera_back_outlined,
                  size: 18,
                ),
                label: Text(
                  'RETAKE PHOTO ${photo.sideIndex! + 1}',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: PackCheckColors.danger,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLowWarning() {
    final failedIndex = _firstFailedRequiredIndex();
    final canRetake = failedIndex != null;

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
                  'SOME IMAGES ARE LOW QUALITY',
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
            'A package side may not be fully readable. Retake only the '
            'failed photo for a more reliable compliance check.',
            style: TextStyle(
              color: Colors.black87,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          if (canRetake) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _finish(retakeIndex: failedIndex),
                icon: const Icon(Icons.photo_camera_back_outlined),
                label: const Text('RETAKE FAILED PHOTO'),
              ),
            ),
          ],
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
    final retakeTarget = _firstRequiredIndex();

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
                  'SOME IMAGES ARE FAIR',
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
            'The images are usable but slightly blurry, dark or reflective. '
            'You can continue, or retake the relevant photo for a more reliable '
            'result.',
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
          if (retakeTarget != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _finish(retakeIndex: retakeTarget),
                icon: const Icon(Icons.photo_camera_back_outlined),
                label: const Text('RETAKE PHOTO'),
              ),
            ),
          ],
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
              'All photos pass quality checks — continuing to OCR…',
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
