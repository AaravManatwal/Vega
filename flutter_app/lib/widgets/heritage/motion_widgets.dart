import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'heritage_palette.dart';

/// Fade + small upward slide for list items. 20 ms per item, capped at 150 ms, so
/// a long list never makes people wait. Plays once when the item is first built.
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delayMs = (index * 20).clamp(0, 150);
    const totalMs = 150 + 220;
    final start = delayMs / totalMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: totalMs),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: c),
      ),
      child: child,
    );
  }
}

/// Transfer finished: a check mark that springs in, a soft ring that pulses out, and a
/// confirming vibration.
class CompletionBurst extends StatefulWidget {
  const CompletionBurst({super.key, this.size = 200});
  final double size;

  @override
  State<CompletionBurst> createState() => _CompletionBurstState();
}

class _CompletionBurstState extends State<CompletionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) _c.value = 1;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final pop = Curves.elasticOut.transform((t * 1.4).clamp(0.0, 1.0));
          final pulse = Curves.easeOut.transform(t);
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - pulse).clamp(0.0, 1.0) * 0.7,
                child: Container(
                  width: widget.size * (0.55 + 0.45 * pulse),
                  height: widget.size * (0.55 + 0.45 * pulse),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: p.accentText, width: 3),
                  ),
                ),
              ),
              Transform.scale(
                scale: pop,
                child: Container(
                  width: widget.size * 0.5,
                  height: widget.size * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Icon(Icons.check_rounded,
                      color: Colors.white, size: widget.size * 0.3),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
