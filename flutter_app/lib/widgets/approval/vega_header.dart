import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Logo mark (two chevrons pulsing one after the other, "speed") + wordmark + mode chip.
class VegaHeader extends StatefulWidget {
  const VegaHeader({super.key, required this.mode});
  final String mode;

  @override
  State<VegaHeader> createState() => _VegaHeaderState();
}

class _VegaHeaderState extends State<VegaHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  size: const Size(30, 22),
                  painter: _ChevronPainter(_c.value, VegaColors.goldHighlight),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'VEGA · वेग',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: VegaColors.goldHighlight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
            ),
          ],
        ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            widget.mode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          ),
        ),
      ],
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.t, this.color);
  final double t;
  final Color color;

  double _alpha(double phase) {
    // .25 -> 1 -> .25 over one cycle
    final x = (t - phase) % 1.0;
    final tri = x < 0.5 ? x * 2 : (1 - x) * 2;
    return lerpDouble(0.25, 1.0, tri)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    paint.color = color.withValues(alpha: _alpha(0));
    canvas.drawPath(
      Path()
        ..moveTo(4, 3)
        ..lineTo(12, 11)
        ..lineTo(4, 19),
      paint,
    );
    paint.color = color.withValues(alpha: _alpha(0.21));
    canvas.drawPath(
      Path()
        ..moveTo(16, 3)
        ..lineTo(24, 11)
        ..lineTo(16, 19),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.t != t || old.color != color;
}
