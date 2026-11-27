import 'package:flutter/material.dart';
import 'heritage_palette.dart';
import 'jali_background.dart';

/// Screen frame of the web design: gradient + jali + arch, a round back button,
/// serif title with a small subtitle, and an optional action on the right.
class HeritagePage extends StatelessWidget {
  const HeritagePage({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.showBack = true,
    this.arch = false,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 20),
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;
  final bool arch;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: p.pageGradient.first,
      body: JaliBackground(
        arch: arch,
        child: SafeArea(
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (showBack) ...[
                      HeritageRoundButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge?.copyWith(
                              color: p.text,
                              fontSize: 21,
                              letterSpacing: 0.4,
                              height: 1.15,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: p.dark ? p.textMuted : const Color(0xFF7A633C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round 44 px button with a gold ring (back, menu, theme toggle).
class HeritageRoundButton extends StatelessWidget {
  const HeritageRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 44,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: p.dark ? const Color(0xFF0F2752) : const Color(0xF2FFFFFF),
        shape: CircleBorder(
          side: BorderSide(color: const Color(0xFFC5A059).withValues(alpha: 0.7)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.45,
              color: iconColor ?? (p.dark ? const Color(0xFFE4C788) : const Color(0xFF0A1F44)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small gold-outlined pill used for filters and toggles. [selected] fills it saffron.
class HeritagePill extends StatelessWidget {
  const HeritagePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final fg = selected ? Colors.white : (p.dark ? const Color(0xFFDBEAFE) : const Color(0xFF5B4D38));
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: selected
                ? const LinearGradient(colors: [Color(0xFFD96B08), Color(0xFFB84E00)])
                : null,
            color: selected ? null : (p.dark ? const Color(0xD90D2148) : const Color(0xD9FFFFFF)),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF5D08A).withValues(alpha: 0.8)
                  : const Color(0xFFC5A059).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
