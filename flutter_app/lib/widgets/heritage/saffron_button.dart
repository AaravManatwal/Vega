import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// The main call-to-action of the web design: saffron gradient pill with a pale gold
/// edge and a warm glow.
class SaffronButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
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
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: expand ? 20 : 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
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
                borderRadius: BorderRadius.circular(height),
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
