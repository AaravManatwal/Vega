import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

enum ActionTileStyle { filled, outlined }

/// Big tappable tile (Send / Receive). Presses in slightly, like a physical key.
class ActionTile extends StatefulWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.style = ActionTileStyle.filled,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final ActionTileStyle style;

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final filled = widget.style == ActionTileStyle.filled;
    final fg = filled ? Colors.white : cs.onSurface;
    final sub = filled ? const Color(0xFFE3EEFF) : cs.onSurfaceVariant;
    final iconColor = filled
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
            ? VegaColors.goldHighlight
            : cs.tertiary);

    return AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: VegaMotion.short,
      curve: VegaMotion.standard,
      child: Material(
        color: filled ? cs.primary : cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: filled
              ? BorderSide.none
              : BorderSide(color: VegaColors.sandstoneGold.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onHighlightChanged: (v) => setState(() => _down = v),
          child: SizedBox(
            height: 132,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(widget.icon, size: 32, color: iconColor),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: text.titleLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: sub),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
