import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VegaLogo extends StatelessWidget {
  final double size;
  final bool showBorder;

  const VegaLogo({
    super.key,
    this.size = 36,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VegaLogoPainter(showBorder: showBorder),
      ),
    );
  }
}

class _VegaLogoPainter extends CustomPainter {
  final bool showBorder;

  const _VegaLogoPainter({required this.showBorder});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = w * 0.27;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.save();
    canvas.clipRRect(rrect);

    // Deep Navy -> Midnight Blue background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          VegaColors.deepNavy,
          VegaColors.midnightBlue,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Electric Blue S-Wave
    final crest = Path()
      ..moveTo(0, h * 0.72)
      ..cubicTo(
        w * 0.34,
        h * 0.72,
        w * 0.66,
        h * 0.62,
        w,
        h * 0.40,
      );
    final wave = Path.from(crest)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [VegaColors.electricBlue, Color(0xFF004BB5)],
        ).createShader(rect),
    );

    // Gold-Leaf #C5A059 ridge
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.028).clamp(1.0, 3.0)
        ..color = VegaColors.sandstoneGold.withValues(alpha: 0.78),
    );

    // Subtle Jharokha Arch Crown
    final arch = Path()
      ..moveTo(w * 0.25, h * 0.265)
      ..quadraticBezierTo(w * 0.38, h * 0.17, w * 0.50, h * 0.13)
      ..quadraticBezierTo(w * 0.62, h * 0.17, w * 0.75, h * 0.265);
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.022).clamp(0.9, 2.2)
        ..strokeCap = StrokeCap.round
        ..color = VegaColors.sandstoneGold.withValues(alpha: 0.55),
    );

    // Left Wing: Crisp White velocity blade
    final leftWing = Path()
      ..moveTo(w * 0.23, h * 0.29)
      ..lineTo(w * 0.39, h * 0.29)
      ..lineTo(w * 0.53, h * 0.675)
      ..lineTo(w * 0.50, h * 0.745)
      ..quadraticBezierTo(w * 0.46, h * 0.745, w * 0.44, h * 0.703)
      ..close();

    canvas.drawPath(
      leftWing,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFDBEAFE)],
        ).createShader(rect),
    );

    // Right Wing + Integrated Speed Arrowhead: Gold-Leaf #C5A059
    final rightWing = Path()
      ..moveTo(w * 0.50, h * 0.745)
      ..quadraticBezierTo(w * 0.47, h * 0.745, w * 0.45, h * 0.695)
      ..lineTo(w * 0.62, h * 0.32)
      ..lineTo(w * 0.566, h * 0.273)
      ..lineTo(w * 0.777, h * 0.238)
      ..lineTo(w * 0.742, h * 0.437)
      ..lineTo(w * 0.691, h * 0.387)
      ..lineTo(w * 0.551, h * 0.699)
      ..quadraticBezierTo(w * 0.53, h * 0.745, w * 0.50, h * 0.745)
      ..close();

    canvas.drawPath(
      rightWing,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            VegaColors.sandstoneGold,
            VegaColors.goldHighlight,
            Color(0xFFF5DFAA),
          ],
        ).createShader(rect),
    );

    // Electric Blue + White Apex Core
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.71),
      w * 0.042,
      Paint()..color = VegaColors.deepNavy,
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.71),
      w * 0.028,
      Paint()..color = VegaColors.electricBlue,
    );

    canvas.restore();

    if (showBorder) {
      canvas.drawRRect(
        rrect.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = VegaColors.sandstoneGold.withValues(alpha: 0.62),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VegaLogoPainter oldDelegate) =>
      oldDelegate.showBorder != showBorder;
}
