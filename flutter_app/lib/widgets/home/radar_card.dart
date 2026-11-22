import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/transfer_models.dart';
import '../../theme/app_theme.dart';

/// Animated radar of nearby devices: rings travel outwards from the Vega mark and
/// every device found on the network appears as a pulsing dot with its name.
class RadarCard extends StatefulWidget {
  const RadarCard({super.key, required this.peers, this.onTap});

  final List<PeerDevice> peers;
  final VoidCallback? onTap;

  @override
  State<RadarCard> createState() => _RadarCardState();
}

class _RadarCardState extends State<RadarCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0.2;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _summary {
    final n = widget.peers.length;
    if (n == 0) return 'Aas-paas koi device nahi mila';
    return 'Aas-paas: $n device';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = widget.peers.map((p) => p.name).join(', ');
    return Semantics(
      button: widget.onTap != null,
      label: widget.peers.isEmpty ? _summary : '$_summary: $names',
      child: Material(
        color: cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: AspectRatio(
            aspectRatio: _RadarPainter.w / _RadarPainter.h,
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _RadarPainter(
                    t: _c.value,
                    peers: widget.peers,
                    summary: _summary,
                    nodeFill: cs.surfaceContainerHigh,
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

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.t,
    required this.peers,
    required this.summary,
    required this.nodeFill,
  });

  static const double w = 350;
  static const double h = 220;
  static const double loopSeconds = 6;
  static const Offset _c = Offset(175, 120);
  static const List<Color> _dots = [
    Color(0xFF4ADE80),
    Color(0xFF5AA2FF),
    Color(0xFFE4C788),
    Color(0xFFC4A5FF),
    Color(0xFFFF9E80),
  ];

  final double t;
  final List<PeerDevice> peers;
  final String summary;
  final Color nodeFill;

  double get _sec => t * loopSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final s = size.width / w;
    canvas.scale(s, s);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF5AA2FF).withValues(alpha: 0.16);
    canvas.drawCircle(_c, 60, ring);
    canvas.drawCircle(_c, 95, ring);

    // three expanding sonar rings, 1 s apart, 3 s each
    for (int i = 0; i < 3; i++) {
      final phase = ((_sec - i) / 3.0) % 1.0;
      canvas.drawCircle(
        _c,
        30 + 80 * phase,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF5AA2FF).withValues(alpha: 0.6 * (1 - phase)),
      );
    }

    // sweeping beam
    final sweep = _sec / loopSeconds * 2 * math.pi;
    canvas.save();
    canvas.translate(_c.dx, _c.dy);
    canvas.rotate(sweep);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 100),
      -0.6,
      0.6,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: -0.6,
          endAngle: 0,
          colors: [
            const Color(0xFF5AA2FF).withValues(alpha: 0),
            const Color(0xFF5AA2FF).withValues(alpha: 0.22),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 100)),
    );
    canvas.restore();

    _centerMark(canvas);
    _peerDots(canvas);

    _text(canvas, summary, const Offset(16, 20),
        const Color(0xFFB7C6E4), 12, FontWeight.w600, 240, left: true);
    canvas.restore();
  }

  void _centerMark(Canvas canvas) {
    canvas.drawCircle(_c, 24, Paint()..color = nodeFill);
    canvas.drawCircle(
      _c,
      24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = VegaColors.goldHighlight,
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    double a(double phase) {
      final x = (_sec / 1.4 - phase) % 1.0;
      final tri = x < 0.5 ? x * 2 : (1 - x) * 2;
      return 0.25 + 0.75 * tri;
    }

    p.color = VegaColors.goldHighlight.withValues(alpha: a(0));
    canvas.drawPath(
      Path()
        ..moveTo(_c.dx - 7, _c.dy - 8)
        ..lineTo(_c.dx + 1, _c.dy)
        ..lineTo(_c.dx - 7, _c.dy + 8),
      p,
    );
    p.color = VegaColors.goldHighlight.withValues(alpha: a(0.21));
    canvas.drawPath(
      Path()
        ..moveTo(_c.dx + 2, _c.dy - 8)
        ..lineTo(_c.dx + 10, _c.dy)
        ..lineTo(_c.dx + 2, _c.dy + 8),
      p,
    );
  }

  void _peerDots(Canvas canvas) {
    final shown = peers.take(5).toList();
    for (int i = 0; i < shown.length; i++) {
      final angle = -2.5 + i * 1.3; // spread around the centre
      final radius = i.isEven ? 60.0 : 80.0;
      final pos = Offset(
        _c.dx + radius * math.cos(angle) * 1.6,
        _c.dy + radius * math.sin(angle) * 0.82,
      );
      final color = _dots[i % _dots.length];
      final pulse = 9 + 2 * math.sin(2 * math.pi * (_sec / 2.4 + i * 0.3));
      canvas.drawCircle(pos, pulse + 5, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(pos, pulse, Paint()..color = color);
      _text(canvas, shown[i].name, pos.translate(0, -22),
          const Color(0xFFF1F5FF), 12, FontWeight.w600, 90);
      _text(canvas, shown[i].platform, pos.translate(0, 22),
          const Color(0xFFB7C6E4), 11, FontWeight.w400, 90);
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color, double size,
      FontWeight weight, double maxW,
      {bool left = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW);
    final dx = left ? at.dx : at.dx - tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.t != t || old.peers != peers || old.summary != summary || old.nodeFill != nodeFill;
}
