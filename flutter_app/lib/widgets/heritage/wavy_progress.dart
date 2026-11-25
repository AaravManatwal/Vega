import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'heritage_palette.dart';

/// Material 3 Expressive style progress line: the finished part is a gently moving
/// wave, the rest is a straight track. Waves stand still if the user turned off animations.
class WavyProgress extends StatefulWidget {
  const WavyProgress({super.key, required this.value, this.height = 14, this.color});

  /// 0..1
  final double value;
  final double height;
  final Color? color;

  @override
  State<WavyProgress> createState() => _WavyProgressState();
}

class _WavyProgressState extends State<WavyProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

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

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final color = widget.color ?? p.accentText;
    return Semantics(
      label: '${(widget.value * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: _WavyPainter(
                value: widget.value.clamp(0.0, 1.0),
                phase: _c.value * 2 * math.pi,
                color: color,
                track: p.softBorder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  _WavyPainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.track,
  });

  final double value;
  final double phase;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final amp = size.height * 0.28;
    const waveLen = 22.0;
    final stroke = size.height * 0.3;
    final endX = size.width * value;

    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = stroke * 0.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (endX < size.width) {
      canvas.drawLine(Offset(math.max(endX, 0) + stroke, midY), Offset(size.width - stroke * 0.4, midY), trackPaint);
    }

    if (endX <= 0) return;
    final path = Path()..moveTo(stroke / 2, midY);
    for (double x = stroke / 2; x <= endX; x += 2) {
      final y = midY + amp * math.sin((x / waveLen) * 2 * math.pi - phase);
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_WavyPainter o) =>
      o.value != value || o.phase != phase || o.color != color || o.track != track;
}
