import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum LinkOrbitMode { check, verified, waiting }

/// Animated graphic of the two phones: a comet runs along the handshake arc, a data
/// lane flows underneath and a shield in the middle shows the trust state.
class LinkOrbit extends StatefulWidget {
  const LinkOrbit({
    super.key,
    required this.mode,
    required this.fromName,
    required this.toName,
  });

  final LinkOrbitMode mode;
  final String fromName;
  final String toName;

  @override
  State<LinkOrbit> createState() => _LinkOrbitState();
}

class _LinkOrbitState extends State<LinkOrbit> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: VegaMotion.ambient);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0.3; // still frame
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color get _accent {
    switch (widget.mode) {
      case LinkOrbitMode.check:
        return VegaColors.goldHighlight;
      case LinkOrbitMode.verified:
        return const Color(0xFF4ADE80);
      case LinkOrbitMode.waiting:
        return const Color(0xFF5AA2FF);
    }
  }

  String get _semantics {
    final state = switch (widget.mode) {
      LinkOrbitMode.check => 'code match karna baaki',
      LinkOrbitMode.verified => 'device pehchaana gaya',
      LinkOrbitMode.waiting => 'jawab ka intezaar',
    };
    return '${widget.fromName} se ${widget.toName} tak surakshit link, $state';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semantics,
      image: true,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: _OrbitPainter.w / _OrbitPainter.h,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _OrbitPainter(
                t: _c.value,
                accent: _accent,
                verified: widget.mode == LinkOrbitMode.verified,
                fromName: widget.fromName,
                toName: widget.toName,
                nodeFill: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.t,
    required this.accent,
    required this.verified,
    required this.fromName,
    required this.toName,
    required this.nodeFill,
  });

  // Drawing space (same numbers as the approved mockup).
  static const double w = 350;
  static const double h = 150;
  static const double loopSeconds = 2.6;

  final double t;
  final Color accent;
  final bool verified;
  final String fromName;
  final String toName;
  final Color nodeFill;

  static const Offset _left = Offset(50, 95);
  static const Offset _right = Offset(300, 95);
  static const Offset _shield = Offset(175, 50);
  static const Color _blue = Color(0xFF5AA2FF);
  static const Color _glyph = Color(0xFFD5E2FA);

  double get _sec => t * loopSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final s = size.width / w;
    canvas.scale(s, s);

    _lane(canvas);
    final arc = Path()
      ..moveTo(_left.dx, _left.dy)
      ..quadraticBezierTo(175, 5, _right.dx, _right.dy);
    _dashed(
      canvas,
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.4),
      4,
      6,
    );
    _comet(canvas, arc);
    _ping(canvas, _left, _blue, _sec / 2.2);
    _ping(canvas, _right, accent, (_sec - 1.1) / 2.2);
    _node(canvas, _left, _blue);
    _node(canvas, _right, accent);
    _shieldBadge(canvas);
    _label(canvas, fromName, const Offset(50, 143));
    _label(canvas, toName, const Offset(300, 143));
    canvas.restore();
  }

  void _lane(Canvas canvas) {
    const x0 = 78.0;
    const x1 = 272.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        const Offset(x0, 0),
        const Offset(x1, 0),
        [accent.withValues(alpha: 0), accent, accent.withValues(alpha: 0)],
        [0, 0.5, 1],
      );
    const period = 15.0;
    final shift = (_sec * 50) % period;
    for (double x = x0 - period + shift; x < x1; x += period) {
      if (x < x0 - 3) continue;
      canvas.drawLine(Offset(x, _left.dy), Offset(x + 3, _left.dy), paint);
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  void _comet(Canvas canvas, Path arc) {
    final metric = arc.computeMetrics().first;
    // head, then two fading followers 0.12 s apart
    final parts = <(double, double, double)>[
      (0.0, 5.0, 1.0),
      (0.12 / loopSeconds, 3.5, 0.6),
      (0.24 / loopSeconds, 2.5, 0.35),
    ];
    for (final (lag, radius, alpha) in parts) {
      final p = (t - lag) % 1.0;
      final tan = metric.getTangentForOffset(metric.length * p);
      if (tan == null) continue;
      canvas.drawCircle(tan.position, radius, Paint()..color = accent.withValues(alpha: alpha));
    }
  }

  void _ping(Canvas canvas, Offset c, Color color, double rawPhase) {
    final phase = rawPhase % 1.0;
    canvas.drawCircle(
      c,
      24 + 18 * phase,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.6 * (1 - phase)),
    );
  }

  void _node(Canvas canvas, Offset c, Color ring) {
    canvas.drawCircle(c, 24, Paint()..color = nodeFill);
    canvas.drawCircle(
      c,
      24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
    final glyph = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = _glyph;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 14, height: 24),
        const Radius.circular(3),
      ),
      glyph,
    );
    canvas.drawLine(c + const Offset(-2.5, 8), c + const Offset(2.5, 8), glyph);
  }

  void _shieldBadge(Canvas canvas) {
    final phase = (_sec / 2.0) % 1.0;
    canvas.drawCircle(
      _shield,
      17 + 15 * phase,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.7 * (1 - phase)),
    );
    canvas.drawCircle(_shield, 17, Paint()..color = nodeFill);
    canvas.drawCircle(
      _shield,
      17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );

    canvas.save();
    canvas.translate(_shield.dx - 12, _shield.dy - 12); // 24x24 icon box
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent;
    final shield = Path()
      ..moveTo(12, 3)
      ..lineTo(4, 6)
      ..lineTo(4, 12)
      ..cubicTo(4, 16.5, 7.2, 19.8, 12, 21)
      ..cubicTo(16.8, 19.8, 20, 16.5, 20, 12)
      ..lineTo(20, 6)
      ..close();
    canvas.drawPath(shield, line);
    if (verified) {
      canvas.drawPath(
        Path()
          ..moveTo(8.5, 12)
          ..lineTo(11, 14.5)
          ..lineTo(15.5, 9.5),
        line,
      );
    } else {
      final a = 0.65 + 0.35 * math.cos(2 * math.pi * _sec / 1.6);
      canvas.drawCircle(
        const Offset(12, 11.5),
        1.6,
        Paint()..color = accent.withValues(alpha: a),
      );
    }
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _glyph,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 90);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 - 1));
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.verified != verified ||
      old.fromName != fromName ||
      old.toName != toName ||
      old.nodeFill != nodeFill;
}
