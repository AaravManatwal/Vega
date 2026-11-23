import 'package:flutter/material.dart';
import '../../l10n/vega_strings.dart';
import '../../theme/app_theme.dart';
import '../vega_logo.dart';
import 'heritage_palette.dart';
import 'jali_background.dart';

class DrawerEntry {
  const DrawerEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
}

/// Side menu of the web design: logo header, two labelled groups, active item in saffron.
class HeritageDrawer extends StatelessWidget {
  const HeritageDrawer({
    super.key,
    required this.strings,
    required this.sharing,
    required this.files,
  });

  final VegaStrings strings;
  final List<DrawerEntry> sharing;
  final List<DrawerEntry> files;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final s = strings;

    Widget group(String title, List<DrawerEntry> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Text(
                title,
                style: TextStyle(
                  color: p.dark ? VegaColors.goldHighlight : VegaColors.saffronDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final e in items) _item(context, p, e),
          ],
        );

    return Drawer(
      width: 300,
      backgroundColor: p.pageGradient.first,
      child: JaliBackground(
        arch: false,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    const VegaLogo(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vega',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: p.text,
                                  fontSize: 20,
                                ),
                          ),
                          Text(
                            s.t('Offline Sharing', 'वेग · ऑफ़लाइन शेयरिंग'),
                            style: TextStyle(
                              color: p.dark ? VegaColors.goldHighlight : VegaColors.brownMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: s.t('Close menu', 'मेन्यू बंद करें'),
                      icon: Icon(Icons.close_rounded, color: p.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: VegaColors.sandstoneGold.withValues(alpha: 0.35)),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    group(s.t('File Sharing', 'फ़ाइल शेयरिंग'), sharing),
                    group(s.t('Files & Settings', 'फ़ाइलें और सेटिंग्स'), files),
                  ],
                ),
              ),
              Divider(height: 1, color: VegaColors.sandstoneGold.withValues(alpha: 0.35)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vega (वेग)\n${s.t('Simple & Offline File Sharing', 'सरल और ऑफ़लाइन फ़ाइल शेयरिंग')}',
                    style: TextStyle(
                      color: p.dark ? VegaColors.skyText : VegaColors.brownText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, HeritagePalette p, DrawerEntry e) {
    final fg = e.active ? Colors.white : p.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pop();
            e.onTap();
          },
          child: Ink(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: e.active
                  ? const LinearGradient(
                      colors: [VegaColors.saffron, VegaColors.saffronDark],
                    )
                  : null,
              border: e.active
                  ? Border.all(color: VegaColors.goldBorder.withValues(alpha: 0.7))
                  : null,
            ),
            child: Row(
              children: [
                Icon(e.icon, size: 20, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    e.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14.5,
                      fontWeight: e.active ? FontWeight.w700 : FontWeight.w500,
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
