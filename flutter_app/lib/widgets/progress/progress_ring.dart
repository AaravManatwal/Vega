import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../models/transfer_models.dart';
import '../../theme/app_theme.dart';

/// Round progress: blue-to-gold arc with a travelling highlight, and the percentage,
/// speed and time left in the middle.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    this.hindi = false,
    super.key,
    required this.progress,
    required this.speedBytesPerSec,
    required this.remaining,
    this.done = false,
    this.size = 240,
  });

  final bool hindi;
  final double progress;
  final double speedBytesPerSec;

  /// Estimated time left, or null when unknown.
  final Duration? remaining;
  final bool done;
  final double size;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: VegaMotion.ambient);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static String _eta(Duration? d, bool hi) {
    if (d == null) return hi ? 'समय का अनुमान लग रहा है' : 'estimating time';
    final s = d.inSeconds;
    if (s < 60) return hi ? 'लगभग $s सेकंड बाकी' : 'about $s s left';
    final m = (s / 60).ceil();
    return hi ? 'लगभग $m मिनट बाकी' : 'about $m min left';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pct = (widget.progress * 100).floor();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gold = dark ? VegaColors.goldHighlight : cs.tertiary;

    return Semantics(
      label: widget.done
          ? (widget.hindi ? 'ट्रांसफ़र पूरा हुआ' : 'Transfer complete')
          : '$pct%, ${formatSpeed(widget.speedBytesPerSec)}, ${_eta(widget.remaining, widget.hindi)}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: widget.progress),
            duration: VegaMotion.medium,
            curve: VegaMotion.decelerate,
            builder: (context, p, _) => AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _RingPainter(
                  progress: p,
                  t: _c.value,
                  track: cs.surfaceContainerHighest,
                  done: widget.done,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.done ? '100%' : '$pct%',
                        style: text.displaySmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        formatSpeed(widget.speedBytesPerSec),
                        style: text.titleMedium?.copyWith(color: gold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.done ? (widget.hindi ? 'पूरा हो गया' : 'Complete') : _eta(widget.remaining, widget.hindi),
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.t,
    required this.track,
    required this.done,
  });

  final double progress;
  final double t;
  final Color track;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * (14 / 240);
    final radius = size.width / 2 - stroke / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    // inner slow-rotating dotted ring
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 2 * math.pi * 0.2);
    final dotted = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF5AA2FF).withValues(alpha: 0.25);
    final r2 = radius * 0.8;
    for (int i = 0; i < 48; i++) {
      final a = i / 48 * 2 * math.pi;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r2), a, 0.03, false, dotted);
    }
    canvas.restore();

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    final sweep = 2 * math.pi * (done ? 1.0 : progress);
    if (sweep > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: done
              ? const [Color(0xFF4ADE80), Color(0xFF4ADE80)]
              : const [Color(0xFF5AA2FF), VegaColors.goldHighlight],
          transform: const GradientRotation(start),
        ).createShader(rect);
      canvas.drawArc(rect, start, sweep, false, arcPaint);

      // soft glow under the arc
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..color = (done ? const Color(0xFF4ADE80) : const Color(0xFF5AA2FF))
              .withValues(alpha: 0.18),
      );

      // highlight that runs along the filled part
      if (!done) {
        final hl = start + sweep * t;
        canvas.drawArc(
          rect,
          hl,
          0.04,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.t != t || old.track != track || old.done != done;
}
