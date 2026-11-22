import 'package:flutter/material.dart';

/// Primary (filled, with a light sweep) and secondary (outlined) buttons.
/// Leave [primaryLabel] null to show only the secondary one.
class ActionBar extends StatefulWidget {
  const ActionBar({
    super.key,
    this.primaryLabel,
    required this.secondaryLabel,
    this.onPrimary,
    required this.onSecondary,
  });

  final String? primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onSecondary;

  @override
  State<ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<ActionBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

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
    final primary = widget.primaryLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (primary != null) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FilledButton(onPressed: widget.onPrimary, child: Text(primary)),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) => CustomPaint(painter: _SweepPainter(_c.value)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: widget.onSecondary,
            child: Text(widget.secondaryLabel),
          ),
        ),
      ],
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final bandW = size.width * (90 / 350);
    final x = -bandW * 1.3 + (size.width + bandW * 2.6) * t;
    final rect = Rect.fromLTWH(x, 0, bandW, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.t != t;
}
