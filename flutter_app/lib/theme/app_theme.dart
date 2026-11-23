import 'package:flutter/material.dart';
import 'vega_colors.dart';
import 'vega_components.dart';
import 'vega_scheme.dart';

// Existing screens import VegaColors from here, so keep it reachable.
export 'vega_colors.dart';
export 'vega_motion.dart';

/// Material 3 theme for Vega: brand-seeded ColorScheme + component themes.
///
/// Pass [dynamicScheme] later to follow the wallpaper colors on Android 13+.
/// It is off by default so Vega keeps its navy and gold identity.
class AppTheme {
  static ThemeData light({ColorScheme? dynamicScheme}) {
    final cs = dynamicScheme ?? VegaScheme.light();
    return VegaComponents.apply(
      ThemeData(useMaterial3: true, colorScheme: cs, brightness: Brightness.light, fontFamily: 'Outfit', fontFamilyFallback: const ['NotoSansDevanagari']),
      cs,
      dark: false,
    );
  }

  static ThemeData dark({ColorScheme? dynamicScheme}) {
    final cs = dynamicScheme ?? VegaScheme.dark();
    return VegaComponents.apply(
      ThemeData(useMaterial3: true, colorScheme: cs, brightness: Brightness.dark, fontFamily: 'Outfit', fontFamilyFallback: const ['NotoSansDevanagari']),
      cs,
      dark: true,
    );
  }
}
