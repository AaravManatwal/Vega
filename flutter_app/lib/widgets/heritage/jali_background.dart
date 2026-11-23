import 'package:flutter/material.dart';
import 'heritage_palette.dart';

/// Page background: warm/navy gradient, Rajasthani jali lattice and (optionally)
/// the cusped jharokha arch outline used on every screen of the web design.
class JaliBackground extends StatelessWidget {
  const JaliBackground({super.key, this.arch = true, this.child});

  final bool arch;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.pageGradient,
        ),
      ),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _JaliPainter(dark: p.dark, arch: arch),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// The arch outline path, scaled to [size]. Shared with the Home card.
Path jharokhaArchPath(Size size) {
  final sx = size.width / 800;
  final sy = size.height / 900;
  Offset o(double x, double y) => Offset(x * sx, y * sy);
  final path = Path()..moveTo(o(24, 874).dx, o(24, 874).dy);
  path.lineTo(o(24, 116).dx, o(24, 116).dy);
  path.cubicTo(o(24, 72).dx, o(24, 72).dy, o(110, 56).dx, o(110, 56).dy, o(225, 56).dx, o(225, 56).dy);
  path.cubicTo(o(315, 56).dx, o(315, 56).dy, o(362, 36).dx, o(362, 36).dy, o(400, 14).dx, o(400, 14).dy);
  path.cubicTo(o(438, 36).dx, o(438, 36).dy, o(485, 56).dx, o(485, 56).dy, o(575, 56).dx, o(575, 56).dy);
  path.cubicTo(o(690, 56).dx, o(690, 56).dy, o(776, 72).dx, o(776, 72).dy, o(776, 116).dx, o(776, 116).dy);
  path.lineTo(o(776, 874).dx, o(776, 874).dy);
  return path;
}

class _JaliPainter extends CustomPainter {
  _JaliPainter({required this.dark, required this.arch});
  final bool dark;
  final bool arch;

  @override
  void paint(Canvas canvas, Size size) {
    const tile = 48.0;
    final gold = const Color(0xFFC5A059);
    final diamond = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gold.withValues(alpha: dark ? 0.09 : 0.15);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF007AFF).withValues(alpha: 0.08);
    final dot = Paint()..color = gold.withValues(alpha: dark ? 0.12 : 0.18);

    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        canvas.drawPath(
          Path()
            ..moveTo(x + 24, y + 2)
            ..lineTo(x + 46, y + 24)
            ..lineTo(x + 24, y + 46)
            ..lineTo(x + 2, y + 24)
            ..close(),
          diamond,
        );
        if (dark) {
          canvas.drawPath(
            Path()
              ..moveTo(x + 24, y + 11)
              ..lineTo(x + 37, y + 24)
              ..lineTo(x + 24, y + 37)
              ..lineTo(x + 11, y + 24)
              ..close(),
            inner,
          );
        }
        canvas.drawCircle(Offset(x + 24, y + 24), dark ? 2 : 1.8, dot);
      }
    }

    if (arch) {
      canvas.drawPath(
        jharokhaArchPath(size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = gold.withValues(alpha: dark ? 0.28 : 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(_JaliPainter old) => old.dark != dark || old.arch != arch;
}
