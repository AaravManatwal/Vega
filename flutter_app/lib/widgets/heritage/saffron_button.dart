import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// The main call-to-action of the web design: saffron gradient pill with a pale gold
/// edge and a warm glow.
class SaffronButton extends StatefulWidget {
  const SaffronButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.expand = true,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;
  final double fontSize;

  @override
  State<SaffronButton> createState() => _SaffronButtonState();
}

class _SaffronButtonState extends State<SaffronButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final onPressed = widget.onPressed;
    final icon = widget.icon;
    final height = widget.height;
    final expand = widget.expand;
    final fontSize = widget.fontSize;
    final enabled = onPressed != null;
    final still = MediaQuery.disableAnimationsOf(context);
    final radius = (_down && !still) ? 18.0 : height;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 8),
          Icon(icon, size: fontSize + 2, color: VegaColors.goldPale),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: expand ? 20 : 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: const LinearGradient(
                colors: [
                  VegaColors.saffronDeep,
                  VegaColors.saffron,
                  VegaColors.saffronDark,
                ],
              ),
              border: Border.all(color: VegaColors.goldBorder.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: VegaColors.saffronDeep.withValues(alpha: 0.32),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onHighlightChanged: (v) => setState(() => _down = v),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
