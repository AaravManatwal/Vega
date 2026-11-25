import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'heritage_palette.dart';

/// Scalloped (flower-like) badge that holds an icon. Slowly turns; bounces when tapped.
class ScallopBadge extends StatefulWidget {
  const ScallopBadge({
    super.key,
    required this.icon,
    this.size = 48,
    this.petals = 12,
    this.color,
    this.iconColor,
    this.spin = false,
  });

  final IconData icon;
  final double size;
  final int petals;
  final Color? color;
  final Color? iconColor;
  final bool spin;

  @override
  State<ScallopBadge> createState() => _ScallopBadgeState();
}

class _ScallopBadgeState extends State<ScallopBadge> with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));
  late final AnimationController _bounce = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.spin && !MediaQuery.disableAnimationsOf(context)) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _tap() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _bounce.value = 0.82;
    _bounce.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 320, damping: 9),
      0.82,
      1,
      0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final color = widget.color ?? p.accentText.withValues(alpha: 0.18);
    final iconColor = widget.iconColor ?? p.accentText;
    return GestureDetector(
      onTap: _tap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _bounce]),
        builder: (_, __) => Transform.scale(
          scale: _bounce.value,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _spin.value * 2 * math.pi,
                  child: CustomPaint(
                    size: Size.square(widget.size),
                    painter: _ScallopPainter(widget.petals, color),
                  ),
                ),
                Icon(widget.icon, size: widget.size * 0.46, color: iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScallopPainter extends CustomPainter {
  _ScallopPainter(this.petals, this.color);
  final int petals;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path();
    for (int i = 0; i <= 360; i += 2) {
      final a = i * math.pi / 180;
      final rr = r * (0.88 + 0.12 * math.cos(petals * a));
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScallopPainter o) => o.petals != petals || o.color != color;
}
