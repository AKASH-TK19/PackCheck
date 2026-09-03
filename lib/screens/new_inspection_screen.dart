import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product_category.dart';
import '../services/image_quality_service.dart';
import '../theme/app_theme.dart';
import 'analysis_loading_screen.dart';
import 'barcode_scanner_screen.dart';
import 'image_quality_screen.dart';
import 'inspection_result_screen.dart';

class NewInspectionScreen extends StatefulWidget {
  final ProductCategoryInfo category;

  const NewInspectionScreen({
    super.key,
    required this.category,
  });

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  final ImagePicker _picker = ImagePicker();

  // The selected value is the number of physical package sides the
  // officer wants to document. Empty slots are optional.
  int packageSides = 2;
  bool customSides = false;
  int customSideCount = 8;

  final Map<int, XFile> sideImages = <int, XFile>{};
  final List<XFile> extraEvidence = <XFile>[];

  bool analyzing = false;
  String? scannedBarcode;

  // Set to "No barcode/QR detected" when an automatic image scan ran but found
  // nothing, so the result screen can distinguish an empty scan from one that
  // was never attempted.
  String? barcodeNote;

  int get totalSides => customSides ? customSideCount : packageSides;

  List<XFile> get allImages {
    final result = <XFile>[];

    for (var i = 0; i < totalSides; i++) {
      final image = sideImages[i];
      if (image != null) result.add(image);
    }

    result.addAll(extraEvidence);
    return result;
  }

  /// Captures / picks a photo for a package side.
  ///
  /// Returns true when a photo was stored for [sideIndex]. During the quality
  /// retake loop ([allowDuringAnalysis] true) it is permitted to run while
  /// `analyzing` is active, so the officer can replace only the failed photo.
  Future<bool> _chooseImageForSide(
    int sideIndex, {
    bool allowDuringAnalysis = false,
  }) async {
    if (analyzing && !allowDuringAnalysis) return false;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.camera,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.gallery,
              ),
            ),
          ],
        ),
      ),
    );

    if (source == null) return false;

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 3000,
        maxHeight: 3000,
      );

      if (!mounted || image == null) return false;

      setState(() {
        sideImages[sideIndex] = image;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not capture photo: $e')),
      );
      return false;
    }
  }

  Future<void> _addExtraEvidence() async {
    if (analyzing) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Additional Photo'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.camera,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose Additional Photo'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.gallery,
              ),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 3000,
        maxHeight: 3000,
      );

      if (!mounted || image == null) return;

      setState(() {
        extraEvidence.add(image);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add photo: $e')),
      );
    }
  }

  /// Builds the ordered list of captured photos to screen for quality.
  ///
  /// Package-side photos are listed first (each with its 1-based "Package Side"
  /// label and its 0-based [sideImages] index), followed by any optional
  /// extra-evidence photos (which carry no side index and never gate OCR).
  List<QualityPhoto> _buildPhotoInputs() {
    final list = <QualityPhoto>[];
    for (var i = 0; i < totalSides; i++) {
      final image = sideImages[i];
      if (image != null) {
        list.add(
          QualityPhoto(
            file: File(image.path),
            label: 'Package Side ${i + 1}',
            sideIndex: i,
          ),
        );
      }
    }
    for (var e = 0; e < extraEvidence.length; e++) {
      list.add(
        QualityPhoto(
          file: File(extraEvidence[e].path),
          label: 'Additional Photo ${e + 1}',
          sideIndex: null,
        ),
      );
    }
    return list;
  }

  Future<void> scanBarcode() async {
    if (analyzing) return;

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }

    setState(() {
      scannedBarcode = result.trim();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product code detected: ${result.trim()}'),
      ),
    );
  }

  Future<void> analyze() async {
    if (allImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture at least one package photo first.'),
        ),
      );
      return;
    }

    // Guard against duplicate submissions while an analysis is running.
    if (analyzing) return;

    setState(() {
      analyzing = true;
    });

    try {
      // Re-quality-screen and re-OCR until every required photo passes. Each
      // retake replaces only the failed photo, and the whole set is re-checked
      // before OCR runs.
      var photoInputs = _buildPhotoInputs();

      while (true) {
        // 1) Per-photo image-quality gate — a real, on-device pixel analysis
        //    (brightness, blur, resolution, glare) runs on EVERY captured photo
        //    BEFORE OCR. Only clearly unsuitable photos trigger a retake.
        final qualityResults = <ImageQualityResult>[];
        for (final photo in photoInputs) {
          qualityResults.add(await ImageQualityService.analyze(photo.file));
        }

        if (!mounted) return;

        final qualityDecision = await Navigator.push<QualityDecision>(
          context,
          MaterialPageRoute(
            builder: (_) => ImageQualityScreen(
              photos: photoInputs,
              category: widget.category,
              initialResults: qualityResults,
            ),
          ),
        );

        if (!mounted) return;

        // Officer cancelled the quality screen — drop back to capture.
        if (qualityDecision == null) {
          setState(() {
            analyzing = false;
          });
          return;
        }

        // Every required photo passed → proceed to OCR.
        if (qualityDecision.continueScan) {
          final imageFiles = photoInputs.map((p) => p.file).toList();

          // If any photo couldn't be measured or is clearly low quality, tell
          // the compliance stage to prefer "needs verification" over confirmed
          // violations, rather than fabricating a result from a poor capture.
          final ocrLowConfidence = qualityResults.any(
            (r) => r.notMeasurable || r.isLowQuality,
          );

          // 2) Push the polished, animated analysis flow. It runs the REAL
          // PackCheck pipeline (NVIDIA OCR + on-device barcode detection) and
          // returns the extracted text + barcode outcome.
          final outcome = await Navigator.push<AnalysisOutcome>(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysisLoadingScreen(
                imageFiles: imageFiles,
                category: widget.category,
                initialBarcode: scannedBarcode,
                initialBarcodeNote: barcodeNote,
                ocrLowConfidence: ocrLowConfidence,
              ),
            ),
          );

          if (!mounted) return;

          // Player pressed "Back to scan" (cancelled) — reset the button.
          if (outcome == null) {
            setState(() {
              analyzing = false;
            });
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InspectionResultScreen(
                image: allImages.first,
                extractedText: outcome.text,
                ocrLines: outcome.ocrLines,
                barcode: outcome.barcode,
                barcodeNote: outcome.barcodeNote,
                category: widget.category,
                ocrLowConfidence: outcome.ocrLowConfidence,
              ),
            ),
          );

          if (mounted) {
            setState(() {
              analyzing = false;
            });
          }
          return;
        }

        // Officer chose to retake ONLY the failed photo.
        final retakeIndex = qualityDecision.retakeIndex;
        if (retakeIndex == null) {
          setState(() {
            analyzing = false;
          });
          return;
        }

        final replaced =
            await _chooseImageForSide(retakeIndex, allowDuringAnalysis: true);
        if (!mounted) return;

        if (!replaced) {
          // Officer backed out of the picker without replacing the photo.
          setState(() {
            analyzing = false;
          });
          return;
        }

        // Rebuild the set and re-check every photo before OCR.
        photoInputs = _buildPhotoInputs();
        if (photoInputs.isEmpty) {
          setState(() {
            analyzing = false;
          });
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        analyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis error: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _preview(XFile image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: kIsWeb
          ? Image.network(
              image.path,
              fit: BoxFit.cover,
            )
          : Image.file(
              File(image.path),
              fit: BoxFit.cover,
            ),
    );
  }

  Widget _sideCard(int index) {
    final image = sideImages[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: image == null
              ? Colors.grey.shade300
              : Colors.indigo.withValues(alpha: .35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.indigo.withValues(alpha: .1),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Package Side ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                image == null ? 'Optional' : 'Captured',
                style: TextStyle(
                  color: image == null
                      ? Colors.grey.shade600
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (image != null) ...[
            SizedBox(
              height: 150,
              width: double.infinity,
              child: _preview(image),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _chooseImageForSide(index),
                  icon: Icon(
                    image == null
                        ? Icons.camera_alt_outlined
                        : Icons.refresh,
                  ),
                  label: Text(
                    image == null ? 'ADD PHOTO' : 'RETAKE',
                  ),
                ),
              ),
              if (image != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove photo',
                  onPressed: analyzing
                      ? null
                      : () {
                          setState(() {
                            sideImages.remove(index);
                          });
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectSideCount() async {
    if (analyzing) return;

    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'How many package sides?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final count in [2, 4, 6])
              ListTile(
                leading: Icon(
                  count == totalSides
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Colors.indigo,
                ),
                title: Text('$count Sides'),
                onTap: () => Navigator.pop(sheetContext, count),
              ),
            ListTile(
              leading: Icon(
                customSides
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: Colors.indigo,
              ),
              title: const Text('Other'),
              subtitle: const Text('Choose another number of sides'),
              onTap: () => Navigator.pop(sheetContext, -1),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == -1) {
      final controller = TextEditingController(
        text: customSides ? '$customSideCount' : '8',
      );

      final value = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Number of package sides'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Sides',
              hintText: 'Example: 8',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value != null && value >= 1 && value <= 20) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('USE'),
            ),
          ],
        ),
      );

      controller.dispose();

      if (!mounted || value == null) return;

      setState(() {
        customSides = true;
        customSideCount = value;
        sideImages.removeWhere((key, _) => key >= value);
      });
      return;
    }

    setState(() {
      customSides = false;
      packageSides = choice;
      sideImages.removeWhere((key, _) => key >= choice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final capturedCount = allImages.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Package'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: widget.category.color.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.category.color,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.category.icon,
                      color: widget.category.color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECTED CATEGORY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.category.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A2B4C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: PackCheckColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PACKAGE EVIDENCE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Capture the package',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Take or upload photos of the package sides. PackCheck '
                      'scans them and checks required declarations.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.view_in_ar_outlined,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Package sides',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '2, 4, 6 or another number',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _selectSideCount,
                      child: Text('$totalSides'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Capture Evidence',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Every side is optional. Add only the photos that are '
                'useful or available during the inspection.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 14),

              for (var i = 0; i < totalSides; i++) _sideCard(i),

              const SizedBox(height: 4),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: analyzing ? null : _addExtraEvidence,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('ADD EXTRA EVIDENCE PHOTO'),
                ),
              ),

              if (extraEvidence.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Additional Evidence',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < extraEvidence.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 58,
                            height: 58,
                            child: _preview(extraEvidence[i]),
                          ),
                          title: Text(
                            'Additional photo ${i + 1}',
                          ),
                          trailing: IconButton(
                            onPressed: analyzing
                                ? null
                                : () {
                                    setState(() {
                                      extraEvidence.removeAt(i);
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.indigo.withValues(alpha: .12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$capturedCount photo${capturedCount == 1 ? '' : 's'} '
                        'captured out of $totalSides package sides',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: analyzing ? null : scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(
                    scannedBarcode == null
                        ? 'SCAN QR / BARCODE'
                        : 'CODE: $scannedBarcode',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: capturedCount == 0 || analyzing ? null : analyze,
                  icon: analyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(
                    analyzing
                        ? 'ANALYSING...'
                        : capturedCount == 0
                            ? 'ADD AT LEAST ONE PHOTO'
                            : 'RUN PACKCHECK',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Tip: For a chips packet, choose 2 sides and capture '
                'the front and/or back. For boxes or other packages, '
                'choose 4 or 6 sides as appropriate. Empty slots are '
                'allowed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
