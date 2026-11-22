import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum TrustVariant { warning, verified, waiting }

/// Strip that tells the user how far the other device can be trusted.
class TrustBanner extends StatelessWidget {
  const TrustBanner({
    super.key,
    required this.variant,
    required this.title,
    required this.text,
  });

  final TrustVariant variant;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = _Tone.of(variant, dark, cs);

    return Semantics(
      container: true,
      label: '$title. $text',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tone.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: _icon(tone.icon),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: tone.title,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: tone.text, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(Color color) {
    switch (variant) {
      case TrustVariant.warning:
        return Icon(Icons.warning_amber_rounded, color: color, size: 24);
      case TrustVariant.verified:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: VegaMotion.long + const Duration(milliseconds: 400),
          curve: VegaMotion.emphasized,
          builder: (context, v, _) => CustomPaint(painter: _ShieldTickPainter(v, color)),
        );
      case TrustVariant.waiting:
        return Padding(
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
        );
    }
  }
}

class _Tone {
  const _Tone(this.bg, this.border, this.icon, this.title, this.text);
  final Color bg;
  final Color border;
  final Color icon;
  final Color title;
  final Color text;

  static _Tone of(TrustVariant v, bool dark, ColorScheme cs) {
    switch (v) {
      case TrustVariant.warning:
        return dark
            ? _Tone(
                VegaColors.warning.withValues(alpha: 0.12),
                VegaColors.warning.withValues(alpha: 0.5),
                VegaColors.warningOnDark,
                const Color(0xFFFBD38A),
                const Color(0xFFF6D9A0),
              )
            : _Tone(
                const Color(0xFFFEF3DC),
                const Color(0xFFE9B861),
                const Color(0xFF8A5A00),
                const Color(0xFF6B4300),
                const Color(0xFF6B4300),
              );
      case TrustVariant.verified:
        return dark
            ? _Tone(
                VegaColors.success.withValues(alpha: 0.14),
                const Color(0xFF4ADE80).withValues(alpha: 0.55),
                VegaColors.successOnDark,
                const Color(0xFFB8F5CF),
                const Color(0xFF9FD9B5),
              )
            : _Tone(
                const Color(0xFFE4F6EA),
                const Color(0xFF8AD4A6),
                const Color(0xFF0F7B3F),
                const Color(0xFF0B5A2E),
                const Color(0xFF0B5A2E),
              );
      case TrustVariant.waiting:
        return _Tone(
          cs.surfaceContainer,
          cs.outlineVariant,
          dark ? const Color(0xFF7DB7FF) : cs.primary,
          cs.onSurface,
          cs.onSurfaceVariant,
        );
    }
  }
}

/// Shield outline with the tick drawn on progressively.
class _ShieldTickPainter extends CustomPainter {
  _ShieldTickPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final k = size.width / 24;
    canvas.scale(k, k);
    final shield = Path()
      ..moveTo(12, 3)
      ..lineTo(4, 6)
      ..lineTo(4, 12)
      ..cubicTo(4, 16.5, 7.2, 19.8, 12, 21)
      ..cubicTo(16.8, 19.8, 20, 16.5, 20, 12)
      ..lineTo(20, 6)
      ..close();
    canvas.drawPath(shield, paint);
    final tick = Path()
      ..moveTo(8.5, 12)
      ..lineTo(11, 14.5)
      ..lineTo(15.5, 9.5);
    final tickProgress = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    for (final m in tick.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * tickProgress), paint);
    }
  }

  @override
  bool shouldRepaint(_ShieldTickPainter old) =>
      old.progress != progress || old.color != color;
}
