import 'package:flutter/material.dart';

/// Central PackCheck brand + design tokens.
///
/// A single source of truth for the app's colours, typography and reusable
/// visual atoms (status chips, section headers, score ring, brand logo).
/// Keeping these here means every screen stays visually consistent without
/// duplicating magic colour values.
class PackCheckColors {
  PackCheckColors._();

  /// Primary brand indigo used for CTAs, headers and focus states.
  static const Color primary = Color(0xFF4F46E5);

  /// Deep navy used for brand headers and dark surfaces.
  static const Color dark = Color(0xFF1E1B4B);

  /// Cyan accent for highlights and secondary branding.
  static const Color accent = Color(0xFF06B6D4);

  /// App background.
  static const Color background = Color(0xFFF4F6FB);

  /// Card / surface.
  static const Color surface = Colors.white;

  // Status colours (semantically consistent across the app).
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  /// Reuses [success] scaled as a light tint background.
  static Color successTint = success.withValues(alpha: .08);
  static Color warningTint = warning.withValues(alpha: .10);
  static Color dangerTint = danger.withValues(alpha: .08);
  static Color infoTint = info.withValues(alpha: .08);
  static Color primaryTint = primary.withValues(alpha: .08);

  /// The brand gradient used on hero headers and primary buttons.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );
}

/// Builds the Material 3 theme applied app-wide by [App].
ThemeData buildPackCheckTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: PackCheckColors.primary,
    scaffoldBackgroundColor: PackCheckColors.background,
  );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: PackCheckColors.primary,
    primary: PackCheckColors.primary,
    brightness: Brightness.light,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: PackCheckColors.dark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: PackCheckColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PackCheckColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PackCheckColors.dark,
        side: BorderSide(color: PackCheckColors.dark.withValues(alpha: .4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PackCheckColors.primary, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PackCheckColors.primary,
    ),
  );
}

/// A small branded PackCheck logo block: an icon inside a rounded gradient
/// tile with an optional wordmark underneath.
class PackCheckLogo extends StatelessWidget {
  const PackCheckLogo({super.key, this.size = 68, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: PackCheckColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: PackCheckColors.primary.withValues(alpha: .35),
                blurRadius: size * 0.25,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
          child: Icon(
            Icons.fact_check_outlined,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        if (showWordmark) ...[
          SizedBox(height: size * 0.18),
          const Text(
            'PACKCHECK',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
          ),
        ],
      ],
    );
  }
}

/// A pill-shaped status chip with an icon, label and semantic colour.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.background,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section heading used consistently across result/home screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? PackCheckColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: PackCheckColors.dark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A circular compliance-score gauge drawn with a custom painter.
///
/// [score] should be 0..100. The ring colour follows the green / amber / red
/// verdict bands used across the app.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.size = 180,
    this.label,
    this.color,
  });

  final double score;
  final double size;
  final String? label;
  final Color? color;

  Color get _color {
    if (color != null) return color!;
    if (score >= 80) return PackCheckColors.success;
    if (score >= 50) return PackCheckColors.warning;
    return PackCheckColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          progress: (score / 100).clamp(0.0, 1.0),
          color: _color,
          trackColor: _color.withValues(alpha: .15),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.round()}',
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w900,
                  color: PackCheckColors.dark,
                  height: 1,
                ),
              ),
              Text(
                '/ 100',
                style: TextStyle(
                  fontSize: size * 0.13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (label != null) ...[
                SizedBox(height: size * 0.06),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size * 0.10,
                    fontWeight: FontWeight.w800,
                    color: _color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, -90 * (3.141592653589793 / 180), progress * 2 * 3.141592653589793, false, arc);
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
