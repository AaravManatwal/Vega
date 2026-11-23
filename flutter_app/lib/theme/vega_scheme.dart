import 'package:flutter/material.dart';
import 'vega_colors.dart';

/// Material 3 color schemes for Vega.
///
/// `ColorScheme.fromSeed` builds the full tonal palette (primary, secondary, tertiary,
/// surface containers, error) so every Material 3 widget gets a consistent color.
/// Only the brand slots are then pinned to Vega's navy, blue and gold.
class VegaScheme {
  static ColorScheme dark() {
    final base = ColorScheme.fromSeed(
      seedColor: VegaColors.saffron,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      primary: VegaColors.actionBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF4A2A0C),
      onPrimaryContainer: VegaColors.goldPale,
      tertiary: VegaColors.goldHighlight,
      onTertiary: VegaColors.deepCanvas,
      tertiaryContainer: const Color(0xFF3A2E12),
      onTertiaryContainer: VegaColors.goldHighlight,
      surface: VegaColors.deepCanvas,
      onSurface: VegaColors.onNavy,
      onSurfaceVariant: VegaColors.onNavyMuted,
      surfaceContainerLowest: VegaColors.deepCanvas,
      surfaceContainerLow: VegaColors.deepNavy,
      surfaceContainer: VegaColors.deepNavy,
      surfaceContainerHigh: VegaColors.cardMidnight,
      surfaceContainerHighest: const Color(0xFF12306A),
      outline: const Color(0xFF5877B0),
      outlineVariant: VegaColors.borderMidnight,
    );
  }

  static ColorScheme light() {
    final base = ColorScheme.fromSeed(
      seedColor: VegaColors.saffron,
      brightness: Brightness.light,
    );
    return base.copyWith(
      primary: VegaColors.actionBlue,
      onPrimary: Colors.white,
      primaryContainer: VegaColors.cream,
      onPrimaryContainer: const Color(0xFF6B3200),
      tertiary: const Color(0xFF8A6A1F), // gold dark enough for text on white
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFF6E7C1),
      onTertiaryContainer: const Color(0xFF3A2E12),
      surface: VegaColors.lightSurface,
      onSurface: VegaColors.deepNavy,
      surfaceContainerLowest: VegaColors.lightSurface,
      surfaceContainerLow: VegaColors.lightBackground,
      surfaceContainer: const Color(0xFFEFECE3),
      surfaceContainerHigh: const Color(0xFFE8E4D8),
      surfaceContainerHighest: const Color(0xFFE0DBCC),
      outlineVariant: const Color(0xFFD9D2BE),
    );
  }
}
