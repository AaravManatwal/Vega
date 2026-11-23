import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../heritage/heritage_palette.dart';

enum CodeTone { gold, green }

/// The 6-digit match code. Digits rise in one by one, then an underline opens up.
class CodeDigits extends StatefulWidget {
  const CodeDigits({
    super.key,
    required this.digits,
    required this.caption,
    this.tone = CodeTone.gold,
    this.compact = false,
  });

  final String digits;
  final String caption;
  final CodeTone tone;
  final bool compact;

  @override
  State<CodeDigits> createState() => _CodeDigitsState();
}

class _CodeDigitsState extends State<CodeDigits> with SingleTickerProviderStateMixin {
  static const double _totalSec = 1.4;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  String get _six {
    final d = widget.digits.replaceAll(RegExp(r'\D'), '');
    return d.padRight(6, '0').substring(0, 6);
  }

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _c.value = 1;
  }

  @override
  void didUpdateWidget(CodeDigits old) {
    super.didUpdateWidget(old);
    if (old.digits != widget.digits && !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _step(double startSec, double durSec) => CurvedAnimation(
        parent: _c,
        curve: Interval(
          (startSec / _totalSec).clamp(0.0, 1.0),
          ((startSec + durSec) / _totalSec).clamp(0.0, 1.0),
          curve: VegaMotion.decelerate,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pal = HeritagePalette.of(context);
    final color = widget.tone == CodeTone.green
        ? VegaColors.successOnDark
        : pal.accentText;
    final size = widget.compact ? 32.0 : 46.0;
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontFamily: 'serif',
      height: 1.1,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final six = _six;

    Widget digit(int i) {
      final a = _step(i * 0.12, 0.35);
      return AnimatedBuilder(
        animation: a,
        builder: (context, _) => Opacity(
          opacity: a.value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - a.value)),
            child: Text(six[i], style: style),
          ),
        ),
      );
    }

    Widget group(int from) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = from; i < from + 3; i++) ...[
              digit(i),
              if (i < from + 2) SizedBox(width: size * 0.22),
            ],
          ],
        );

    final underline = _step(0.9, 0.5);

    return Semantics(
      label: 'Match code ${six.substring(0, 3)} ${six.substring(3)}. ${widget.caption}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: widget.compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: pal.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: pal.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shrinks the code a little on very narrow screens or large fonts instead of overflowing.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [group(0), SizedBox(width: size * 0.6), group(3)],
              ),
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: underline,
              builder: (context, _) => FractionallySizedBox(
                widthFactor: 0.8 * underline.value,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.caption,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: pal.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
