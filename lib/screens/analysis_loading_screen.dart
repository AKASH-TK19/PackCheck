import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product_category.dart';
import '../services/barcode_service.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';

/// Outcome of a successful analysis pass, handed back to the caller so it can
/// open the result screen. Kept in a tiny value object so this screen never has
/// to depend on [main.dart], avoiding a circular import.
class AnalysisOutcome {
  final String text;
  final List<OcrLine> ocrLines;
  final String? barcode;
  final String? barcodeNote;

  /// True when the captured image failed the quality check and the officer
  /// chose to continue anyway, so the engine treats missing declarations as
  /// needing verification rather than confirmed violations.
  final bool ocrLowConfidence;

  const AnalysisOutcome({
    required this.text,
    this.ocrLines = const [],
    this.barcode,
    this.barcodeNote,
    this.ocrLowConfidence = false,
  });
}

/// Full-screen animated analysis flow.
///
/// Runs the **real** PackCheck pipeline — NVIDIA OCR on the captured package
/// images plus on-device barcode/QR auto-detection — in the background while a
/// polished, staged progress animation plays. The OCR text is never fabricated:
/// the actual backend result flows through to [AnalysisOutcome].
class AnalysisLoadingScreen extends StatefulWidget {
  const AnalysisLoadingScreen({
    super.key,
    required this.imageFiles,
    required this.category,
    this.initialBarcode,
    this.initialBarcodeNote,
    this.ocrLowConfidence = false,
  });

  final List<File> imageFiles;
  final ProductCategoryInfo category;
  final String? initialBarcode;
  final String? initialBarcodeNote;

  /// When true, the captured image failed the quality check but the officer
  /// chose to continue anyway. Passed through to the compliance stage so that
  /// unresolved declarations are shown as needing verification.
  final bool ocrLowConfidence;

  @override
  State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen> {
  static const _stages = <(String, IconData)>[
    ('Image received', Icons.photo_outlined),
    ('Detecting text', Icons.search),
    ('Extracting product information', Icons.psychology_outlined),
    ('Checking compliance requirements', Icons.balance_outlined),
    ('Comparing required vs detected declarations', Icons.compare_arrows),
    ('Analysis complete', Icons.check_circle_outline),
  ];

  int _activeStage = 0;
  bool _error = false;
  String _errorMessage = '';
  Timer? _stageTimer;
  final _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _manualController.dispose();
    super.dispose();
  }

  // Advances the animated stage list on a timer, purely as a progress
  // indication. The completion of each real pipeline step snaps the last two
  // stages so the result is always driven by actual work, not by timing alone.
  void _startStageAnimation() {
    _stageTimer?.cancel();
    _activeStage = 0;
    _stageTimer = Timer.periodic(const Duration(milliseconds: 750), (timer) {
      if (!mounted) return;
      if (_activeStage < _stages.length - 3) {
        setState(() => _activeStage++);
      }
    });
  }

  Future<void> _run() async {
    setState(() {
      _error = false;
      _errorMessage = '';
    });
    _startStageAnimation();

    try {
      final ocr = await OcrService.analyzeImages(widget.imageFiles);

      if (!mounted) return;

      // Barcode auto-detection is independent of OCR and never fails the run.
      final barcodeOutcome =
          await BarcodeService.detectFromImages(widget.imageFiles);

      if (!mounted) return;

      // A completed real pass snaps the animation to its final stages.
      _stageTimer?.cancel();
      setState(() => _activeStage = _stages.length - 2);
      await Future<void>.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;
      setState(() => _activeStage = _stages.length - 1);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      Navigator.of(context).pop(_buildOutcome(ocr, barcodeOutcome));
    } on OcrServiceException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('An unexpected error occurred while analysing the package.\n($e)');
    }
  }

  AnalysisOutcome _buildOutcome(
    OcrResult ocr,
    BarcodeScanOutcome barcodeOutcome,
  ) {
    String? barcode = widget.initialBarcode;
    String? barcodeNote = widget.initialBarcodeNote;

    if (barcodeOutcome.detected) {
      final unique = <String>{...barcodeOutcome.values};
      if (barcode != null && barcode.isNotEmpty) {
        unique.add(barcode);
      }

      if (unique.length == 1) {
        barcode = unique.first;
        barcodeNote = null;
      } else {
        // Multiple codes: leave the officer-chosen/live-scanned value; the
        // result screen can surface the note. We keep the first detected value.
        barcode = barcode ?? barcodeOutcome.values.first;
        barcodeNote = '${unique.length} codes detected on the package.';
      }
    } else {
      barcodeNote ??= 'No barcode/QR detected';
    }

    return AnalysisOutcome(
      text: ocr.text,
      ocrLines: ocr.lines,
      barcode: barcode,
      barcodeNote: barcodeNote,
      ocrLowConfidence: widget.ocrLowConfidence,
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    _stageTimer?.cancel();
    setState(() {
      _error = true;
      _errorMessage = message;
    });
  }

  Future<void> _enterTextManually() async {
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter label text manually'),
        content: TextField(
          controller: _manualController,
          maxLines: 8,
          autofocus: true,
          decoration: const InputDecoration(
            hintText:
                'e.g. MRP: Rs 50\nNet Qty: 100 g\nManufactured by: ...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _manualController.text.trim(),
            ),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );

    if (!mounted || text == null || text.trim().isEmpty) return;

    Navigator.of(context).pop(
      AnalysisOutcome(text: text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PackCheckColors.background,
      body: SafeArea(
        child: _error ? _buildError() : _buildProgress(),
      ),
    );
  }

  Widget _buildProgress() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: PackCheckColors.brandGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Analysing your package',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: PackCheckColors.dark,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.category.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.category.icon,
                        size: 16, color: widget.category.color),
                    const SizedBox(width: 6),
                    Text(
                      widget.category.label,
                      style: TextStyle(
                        color: widget.category.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              ...List.generate(_stages.length, (index) {
                final (label, icon) = _stages[index];
                final done = index < _activeStage;
                final active = index == _activeStage;
                return _StageRow(
                  label: label,
                  icon: icon,
                  done: done,
                  active: active,
                );
              }),
              const SizedBox(height: 26),
              const Text(
                'Running OCR + barcode detection + compliance checks',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: PackCheckColors.danger.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_outlined,
                      color: PackCheckColors.danger,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Unable to analyze the package',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: PackCheckColors.dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PackCheck could not connect to the analysis service. '
                    'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PackCheckColors.warning.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _run,
                      icon: const Icon(Icons.refresh),
                      label: const Text('TRY AGAIN'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _enterTextManually,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('ENTER TEXT MANUALLY'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('BACK TO SCAN'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.icon,
    required this.done,
    required this.active,
  });

  final String label;
  final IconData icon;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData trailingIcon;
    if (done) {
      color = PackCheckColors.success;
      trailingIcon = Icons.check_circle;
    } else if (active) {
      color = PackCheckColors.primary;
      trailingIcon = Icons.radio_button_checked;
    } else {
      color = Colors.grey.shade400;
      trailingIcon = Icons.circle_outlined;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: active
            ? PackCheckColors.primary.withValues(alpha: .07)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? PackCheckColors.primary.withValues(alpha: .4)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done
                  ? PackCheckColors.success.withValues(alpha: .12)
                  : active
                      ? PackCheckColors.primary.withValues(alpha: .12)
                      : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight:
                    done || active ? FontWeight.w700 : FontWeight.w500,
                color: done || active ? PackCheckColors.dark : Colors.grey,
              ),
            ),
          ),
          if (active)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(trailingIcon, size: 20, color: color),
        ],
      ),
    );
  }
}
