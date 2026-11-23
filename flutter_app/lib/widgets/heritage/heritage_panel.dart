import 'package:flutter/material.dart';
import 'heritage_palette.dart';

/// Rounded panel with the thin gold border used for cards on every screen.
class HeritagePanel extends StatelessWidget {
  const HeritagePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.tile = false,
    this.highlight = false,
    this.dashed = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Slightly lighter fill used for small tiles.
  final bool tile;

  /// Selected state: orange border.
  final bool highlight;
  final bool dashed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final fill = highlight
        ? (p.dark ? const Color(0xF21E1B24) : const Color(0xFFFFF5E6))
        : (tile ? p.tile : p.panel);
    final borderColor = highlight
        ? (p.dark ? const Color(0xFFE4C788) : const Color(0xFFC85A00))
        : (tile ? p.softBorder : p.border);

    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: highlight ? 1.4 : 1),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: box,
      ),
    );
  }
}
