import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'heritage_palette.dart';

/// Painter for the Home stage: diagonal sandstone/navy wave between Send and Receive,
/// its gold edge lines, and the jharokha arch frame (shapes taken from the web design).
class HomeStagePainter extends CustomPainter {
  HomeStagePainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 800;
    final sy = size.height / 640;
    Offset o(double x, double y) => Offset(x * sx, y * sy);

    final fill = Path()
      ..moveTo(o(0, 385).dx, o(0, 385).dy)
      ..cubicTo(o(250, 385).dx, o(250, 385).dy, o(545, 330).dx, o(545, 330).dy, o(800, 215).dx, o(800, 215).dy)
      ..lineTo(o(800, 640).dx, o(800, 640).dy)
      ..lineTo(o(0, 640).dx, o(0, 640).dy)
      ..close();
    final rect = Offset.zero & size;
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xF20D2654), Color(0xFA14326B)]
              : const [Color(0xEBF4E6C8), Color(0xF5E6CC96)],
        ).createShader(rect),
    );

    final under = Path()
      ..moveTo(o(0, 400).dx, o(0, 400).dy)
      ..cubicTo(o(265, 396).dx, o(265, 396).dy, o(555, 342).dx, o(555, 342).dy, o(800, 230).dx, o(800, 230).dy);
    canvas.drawPath(
      under,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = (dark ? VegaColors.saffron : VegaColors.sandstoneGold).withValues(alpha: 0.24),
    );
    final edge = Path()
      ..moveTo(o(0, 385).dx, o(0, 385).dy)
      ..cubicTo(o(250, 385).dx, o(250, 385).dy, o(545, 330).dx, o(545, 330).dy, o(800, 215).dx, o(800, 215).dy);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = VegaColors.sandstoneGold.withValues(alpha: dark ? 0.68 : 0.82),
    );

    // Arch frame (viewBox 800 x 640 in the web design).
    Offset a(double x, double y) => Offset(x * sx, y * sy);
    final arch = Path()
      ..moveTo(a(22, 618).dx, a(22, 618).dy)
      ..lineTo(a(22, 98).dx, a(22, 98).dy)
      ..cubicTo(a(22, 58).dx, a(22, 58).dy, a(108, 44).dx, a(108, 44).dy, a(225, 44).dx, a(225, 44).dy)
      ..cubicTo(a(315, 44).dx, a(315, 44).dy, a(362, 28).dx, a(362, 28).dy, a(400, 10).dx, a(400, 10).dy)
      ..cubicTo(a(438, 28).dx, a(438, 28).dy, a(485, 44).dx, a(485, 44).dy, a(575, 44).dx, a(575, 44).dy)
      ..cubicTo(a(692, 44).dx, a(692, 44).dy, a(778, 58).dx, a(778, 58).dy, a(778, 98).dx, a(778, 98).dy)
      ..lineTo(a(778, 618).dx, a(778, 618).dy);
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = VegaColors.sandstoneGold.withValues(alpha: dark ? 0.34 : 0.45),
    );
  }

  @override
  bool shouldRepaint(HomeStagePainter old) => old.dark != dark;
}

/// The stage itself: rounded gold-bordered panel with the wave and arch drawn inside.
class HomeStage extends StatelessWidget {
  const HomeStage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: p.dark ? const Color(0xB3081A3E) : const Color(0xBFFFFDF8),
        border: Border.all(
          color: VegaColors.sandstoneGold.withValues(alpha: p.dark ? 0.35 : 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: HomeStagePainter(dark: p.dark)),
          ),
          Positioned(left: 12, bottom: 12, child: _Diamond()),
          Positioned(right: 12, bottom: 12, child: _Diamond()),
          child,
        ],
      ),
    );
  }
}

class _Diamond extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: math.pi / 4,
        child: Container(width: 8, height: 8, color: VegaColors.sandstoneGold),
      );
}

enum MedallionKind { send, receive }

/// Big round Send / Receive button: dotted ring, inner gold ring, gradient disc.
class MedallionButton extends StatefulWidget {
  const MedallionButton({
    super.key,
    required this.kind,
    required this.label,
    required this.onTap,
  });

  final MedallionKind kind;
  final String label;
  final VoidCallback onTap;

  @override
  State<MedallionButton> createState() => _MedallionButtonState();
}

class _MedallionButtonState extends State<MedallionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final send = widget.kind == MedallionKind.send;

    final disc = SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _spin,
            child: CustomPaint(
              size: const Size(100, 100),
              painter: _RingsPainter(send: send, dark: p.dark),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: send
                  ? (p.dark ? const Color(0xE6221712) : const Color(0xF2FFF5E6))
                  : (p.dark ? const Color(0xE608224D) : const Color(0xE6FFFFFF)),
              border: Border.all(color: VegaColors.sandstoneGold.withValues(alpha: 0.85)),
              boxShadow: [
                BoxShadow(
                  color: (send ? VegaColors.saffronDeep : VegaColors.deepNavy)
                      .withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: send
                      ? const [Color(0xFFE06D06), Color(0xFFB84E00)]
                      : const [Color(0xFF0F2D5E), Color(0xFF071836)],
                ),
                border: Border.all(
                  color: (send ? VegaColors.goldBorder : VegaColors.sandstoneGold)
                      .withValues(alpha: 0.85),
                ),
              ),
              child: Icon(
                send ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 28,
                color: send ? Colors.white : VegaColors.goldHighlight,
              ),
            ),
          ),
        ],
      ),
    );

    final label = Text(
      widget.label,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: p.text,
            fontSize: 26,
            letterSpacing: 0.6,
          ),
    );

    return Semantics(
      button: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: send
                  ? [disc, const SizedBox(width: 14), label]
                  : [label, const SizedBox(width: 14), disc],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.send, required this.dark});
  final bool send;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final k = size.width / 120;
    final main = send ? const Color(0xFFD96B08) : const Color(0xFFC5A059);
    final accent = send ? const Color(0xFFC5A059) : (dark ? const Color(0xFF93C5FD) : const Color(0xFF0A1F44));

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * k
      ..color = main.withValues(alpha: 0.5);
    final r = 55 * k;
    final circ = 2 * math.pi * r;
    final n = (circ / (8 * k)).floor();
    for (var i = 0; i < n; i++) {
      final a0 = i / n * 2 * math.pi;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a0, 2 * math.pi / n / 2, false, dash);
    }
    canvas.drawCircle(
      c,
      49 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * k
        ..color = accent.withValues(alpha: 0.38),
    );
    for (var deg = 0; deg < 360; deg += 45) {
      final rad = deg * math.pi / 180;
      final major = deg % 90 == 0;
      canvas.drawCircle(
        c + Offset(math.cos(rad), math.sin(rad)) * r,
        (major ? 2.4 : 1.5) * k,
        Paint()..color = main.withValues(alpha: major ? 0.92 : 0.62),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.send != send || old.dark != dark;
}
