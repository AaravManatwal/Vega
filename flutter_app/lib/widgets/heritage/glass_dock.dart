import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'heritage_palette.dart';

class DockItem {
  const DockItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Floating frosted pill with a few destinations. The selected one is a saffron pill that
/// slides (spring) behind the item. Blur is applied once to the static pill, never animated.
class GlassDock extends StatelessWidget {
  const GlassDock({super.key, required this.items, this.selected = 0});

  final List<DockItem> items;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: p.panel.withValues(alpha: p.dark ? 0.72 : 0.86),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < items.length; i++)
                  Semantics(
                    button: true,
                    selected: i == selected,
                    label: items[i].label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        items[i].onTap();
                      },
                      child: AnimatedContainer(
                        duration: still ? Duration.zero : const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                        padding: EdgeInsets.symmetric(horizontal: i == selected ? 20 : 12),
                        decoration: BoxDecoration(
                          color: i == selected ? const Color(0xFFD96B08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(items[i].icon,
                                size: 24, color: i == selected ? Colors.white : p.textMuted),
                            if (i == selected) ...[
                              const SizedBox(width: 8),
                              Text(items[i].label,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
