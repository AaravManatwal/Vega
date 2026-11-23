import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The Vega web design colors for one brightness. Screens ask this instead of
/// repeating hex values, so Light and Dark stay in step.
class HeritagePalette {
  const HeritagePalette._({
    required this.dark,
    required this.pageGradient,
    required this.text,
    required this.textMuted,
    required this.accentText,
    required this.panel,
    required this.tile,
    required this.field,
    required this.border,
    required this.softBorder,
  });

  final bool dark;
  final List<Color> pageGradient;
  final Color text;
  final Color textMuted;

  /// Gold on dark, deep orange on light (links, small labels).
  final Color accentText;
  final Color panel;
  final Color tile;
  final Color field;
  final Color border;
  final Color softBorder;

  static HeritagePalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const HeritagePalette _dark = HeritagePalette._(
    dark: true,
    pageGradient: [Color(0xFF0A1F44), Color(0xFF07193B), Color(0xFF04122B)],
    text: Colors.white,
    textMuted: VegaColors.skyText,
    accentText: VegaColors.goldHighlight,
    panel: Color(0xF20D2148),
    tile: Color(0xE60E2550),
    field: Color(0xFF06132B),
    border: Color(0x73C5A059),
    softBorder: Color(0x4DC5A059),
  );

  static const HeritagePalette _light = HeritagePalette._(
    dark: false,
    pageGradient: [VegaColors.ivory, VegaColors.ivorySand, VegaColors.ivoryDeep],
    text: VegaColors.deepNavy,
    textMuted: VegaColors.brownText,
    accentText: VegaColors.saffronDark,
    panel: Color(0xF2FFFFFF),
    tile: Color(0xE6FFFFFF),
    field: VegaColors.parchment,
    border: Color(0xB3C5A059),
    softBorder: Color(0x73C5A059),
  );
}
